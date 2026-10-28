let src = Logs.Src.create "session"

module Logs = (val Logs.src_log src : Logs.LOG)

exception Session_store_failed

let key : Terrat_user.t Brtl_mw_session.Value.t Hmap.key = Brtl_mw_session.create_key ()

module Cookie = struct
  module Sql = struct
    let load_sql = Mql_sql.read "select user_id from user_sessions2 where token = $token"

    let load () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ load_sql
        /% Var.uuid "token")

    let store_sql =
      Mql_sql.read
        "insert into user_sessions2 (user_id, user_agent) values ($user_id, $user_agent) returning \
         token"

    let store () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* token *)
        Ret.uuid
        /^ store_sql
        /% Var.uuid "user_id"
        /% Var.text "user_agent")

    let delete_sql = Mql_sql.read "delete from user_sessions2 where token = $token"
    let delete = Pgsql_io.Typed_sql.(sql /^ delete_sql /% Var.uuid "token")
  end

  let default_caps = Terrat_user.Capability.[ Access_token_create; Kv_store_read; Kv_store_write ]

  let load storage id =
    match Uuidm.of_string id with
    | Some uuid -> (
        let load =
          let open Abbs_fc.Infix_result_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Pgsql_io.Prepared_stmt.fetch
                db
                (Sql.load ())
                ~f:(fun id ->
                  Terrat_user.make ~access_token_id:uuid ~capabilities:default_caps ~id ())
                uuid
              >>| function
              | [] -> None
              | user :: _ -> Some user)
        in
        let open Abb.Future.Infix_monad in
        load
        >>= function
        | Ok r -> Abb.Future.return r
        | Error `Pgsql_pool_error ->
            Logs.err (fun m -> m "Pool error");
            Abb.Future.return None
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "%a" Pgsql_io.pp_err err);
            Abb.Future.return None)
    | None -> Abb.Future.return None

  let store storage id_opt user ctx =
    match id_opt with
    | Some id ->
        (* If there already is an id, do nothing *)
        Abb.Future.return id
    | None -> (
        let open Abb.Future.Infix_monad in
        let user_agent =
          ctx
          |> Brtl_ctx.request
          |> Brtl_ctx.Request.headers
          |> CCFun.flip Cohttp.Header.get "user-agent"
          |> CCOption.get_or ~default:"Unknown"
        in
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.fetch
              db
              (Sql.store ())
              ~f:CCFun.id
              (Terrat_user.id user)
              user_agent)
        >>= function
        | Ok (token :: _) -> Abb.Future.return (Uuidm.to_string token)
        | Ok [] ->
            Logs.err (fun m -> m "Failure storing session: the insert returned no token");
            raise Session_store_failed
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "Failure storing session %s" (Pgsql_io.show_err err));
            raise Session_store_failed
        | Error `Pgsql_pool_error ->
            Logs.err (fun m -> m "Failed to acquire a pool connection");
            raise Session_store_failed)
end

module Bearer = struct
  module Sql = struct
    let select_access_token_id_sql =
      Mql_sql.read
        "select id from access_tokens where id = $id union all select id from work_manifests where \
         id = $id and state in ('queued', 'running')"

    (* An access token is an entry in the access tokens table OR a work manifest
       (many API calls use the work manifest id). *)
    let select_access_token_id () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ select_access_token_id_sql
        /% Var.uuid "id")
  end

  let load storage keys token =
    let open Abb.Future.Infix_monad in
    Abb.Sys.time ()
    >>= fun now ->
    match Terrat_user.Token.of_token' ~now ~keys token with
    | Ok user -> (
        match Terrat_user.access_token_id user with
        | Some access_token_id -> (
            Pgsql_pool.with_conn storage ~f:(fun db ->
                Pgsql_io.Prepared_stmt.fetch
                  db
                  (Sql.select_access_token_id ())
                  ~f:CCFun.id
                  access_token_id)
            >>= function
            | Ok [] -> Abb.Future.return None
            | Ok (_ :: _) -> Abb.Future.return (Some user)
            | Error (#Pgsql_io.err as err) ->
                Logs.err (fun m -> m "%a" Pgsql_io.pp_err err);
                Abb.Future.return None
            | Error (#Pgsql_pool.err as err) ->
                Logs.err (fun m -> m "%a" Pgsql_pool.pp_err err);
                Abb.Future.return None)
        | None -> Abb.Future.return (Some user))
    | Error (`Expired_token_err _) -> Abb.Future.return None
    | Error (#Terrat_user.Token.of_token_err as err) ->
        Logs.err (fun m -> m "%a" Terrat_user.Token.pp_of_token_err err);
        Abb.Future.return None

  let store _storage _keys _ = raise (Failure "nyi")
end

module Sql = struct
  let select_encryption_keys_sql =
    Mql_sql.read "select encode(data, 'hex') from encryption_keys order by rank"

  let select_encryption_keys () =
    (* The hex conversion is so that there are no issues with escaping
         the string *)
    Pgsql_io.Typed_sql.(
      sql
      //
      (* data *)
      Ret.u Ret.text CCFun.(Cstruct.of_hex %> Cstruct.to_string %> CCOption.return)
      /^ select_encryption_keys_sql)
end

type err =
  [ `No_encryption_keys_err
  | Pgsql_pool.err
  | Pgsql_io.err
  ]

let show_err = function
  | `No_encryption_keys_err -> "the terrateam database has no encryption keys: run the migrations"
  | #Pgsql_pool.err as err -> Pgsql_pool.show_err err
  | #Pgsql_io.err as err -> Pgsql_io.show_err err

(* The session's configuration needs the keys of the [encryption_keys] table. *)
let try_config ~cookie_name storage =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.fetch db (Sql.select_encryption_keys ()) ~f:CCFun.id)
  >>| function
  | Ok [] -> Error `No_encryption_keys_err
  | Error _ as err -> err
  | Ok keys ->
      let config =
        {
          Brtl_mw_session.Config.key;
          cookie =
            Some
              {
                Brtl_mw_session.Config.Cookie.name = cookie_name;
                expiration = `Session;
                domain = None;
                path = Some "/";
                secure = true;
                load = Cookie.load storage;
                store = Cookie.store storage;
              };
          bearer =
            Some
              {
                Brtl_mw_session.Config.Bearer.load = Bearer.load storage keys;
                store = Bearer.store storage keys;
              };
        }
      in
      Ok config

let try_create ~cookie_name storage =
  Abb.Future.map (CCResult.map Brtl_mw_session.create) (try_config ~cookie_name storage)

let try_create_wrapper ~cookie_name storage =
  Abb.Future.map (CCResult.map Brtl_mw_session.wrap) (try_config ~cookie_name storage)

let get_session ctx = Brtl_mw_session.get_session_value key ctx

(* let get_session_exn ctx = CCOption.get_exn_or "get_session" (get_session ctx) *)

let set_session t ctx = Brtl_mw_session.set_session_value key (Brtl_mw_session.Auth.Cookie t) ctx

let rem_session ~cookie_name storage ctx =
  let f =
    match Brtl_mw_session.get_session_key cookie_name ctx with
    | Some token ->
        let open Abbs_fc.Infix_result_monad in
        let token = CCOption.get_exn_or ("token: " ^ token) (Uuidm.of_string token) in
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.execute db Cookie.Sql.delete token)
        >>| fun () -> Brtl_mw_session.rem_session_value key ctx
    | None -> Abbs_fc.return_ok ctx
  in
  let open Abb.Future.Infix_monad in
  f
  >>= function
  | Ok ctx -> Abbs_fc.return_ok ctx
  | Error (#Pgsql_pool.err | #Pgsql_io.err) as err -> Abb.Future.return err

let create_user_session user ctx = set_session user ctx

let with_session ?caps ctx =
  match get_session ctx with
  | Some (Brtl_mw_session.Auth.Cookie session) | Some (Brtl_mw_session.Auth.Bearer session) -> (
      match caps with
      | Some caps ->
          if CCList.for_all CCFun.(flip Terrat_user.has_capability session) caps then
            Abbs_fc.return_ok session
          else Abbs_fc.return_err (Brtl_ctx.set_response `Forbidden ctx)
      | None -> Abbs_fc.return_ok session)
  | None -> Abbs_fc.return_err (Brtl_ctx.set_response `Forbidden ctx)
