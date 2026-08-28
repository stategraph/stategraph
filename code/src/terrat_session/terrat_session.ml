let src = Logs.Src.create "session"

module Logs = (val Logs.src_log src : Logs.LOG)

exception Session_store_failed

let key : Terrat_user.t Brtl_mw_session.Value.t Hmap.key = Brtl_mw_session.create_key ()

module Cookie = struct
  module Sql = struct
    let load () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ "select user_id from user_sessions2 where token = $token"
        /% Var.uuid "token")

    let store () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* token *)
        Ret.uuid
        /^ "insert into user_sessions2 (user_id, user_agent) values ($user_id, $user_agent) \
            returning token"
        /% Var.uuid "user_id"
        /% Var.text "user_agent")

    let delete =
      Pgsql_io.Typed_sql.(
        sql /^ "delete from user_sessions2 where token = $token" /% Var.uuid "token")
  end

  let default_caps = Terrat_user.Capability.[ Access_token_create; Kv_store_read; Kv_store_write ]
  let cookie_name = "session"

  let load storage id =
    match Uuidm.of_string id with
    | Some uuid -> (
        let load =
          let open Abbs_future_combinators.Infix_result_monad in
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
        | Ok [] -> assert false
        | Ok (token :: _) -> Abb.Future.return (Uuidm.to_string token)
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "Failure storing session %s" (Pgsql_io.show_err err));
            raise Session_store_failed
        | Error `Pgsql_pool_error ->
            Logs.err (fun m -> m "Failed to acquire a pool connection");
            raise Session_store_failed)
end

module Bearer = struct
  module Sql = struct
    (* An access token is an entry in the access tokens table OR a work manifest
       (many API calls use the work manifest id). *)
    let select_access_token_id () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ "select id from access_tokens where id = $id union all select id from work_manifests \
            where id = $id and state in ('queued', 'running')"
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
  let select_encryption_keys () =
    (* The hex conversion is so that there are no issues with escaping
         the string *)
    Pgsql_io.Typed_sql.(
      sql
      //
      (* data *)
      Ret.u Ret.text CCFun.(Cstruct.of_hex %> Cstruct.to_string %> CCOption.return)
      /^ "select encode(data, 'hex') from encryption_keys order by rank")
end

let create storage =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.fetch db (Sql.select_encryption_keys ()) ~f:CCFun.id)
  >>= function
  | Ok [] -> assert false
  | Error _ -> assert false
  | Ok keys ->
      let config =
        {
          Brtl_mw_session.Config.key;
          cookie =
            Some
              {
                Brtl_mw_session.Config.Cookie.name = Cookie.cookie_name;
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
      Abb.Future.return @@ Brtl_mw_session.create config

let get_session ctx = Brtl_mw_session.get_session_value key ctx

(* let get_session_exn ctx = CCOption.get_exn_or "get_session" (get_session ctx) *)

let set_session t ctx = Brtl_mw_session.set_session_value key (Brtl_mw_session.Auth.Cookie t) ctx

let rem_session storage ctx =
  let f =
    match Brtl_mw_session.get_session_key Cookie.cookie_name ctx with
    | Some token ->
        let open Abbs_future_combinators.Infix_result_monad in
        let token = CCOption.get_exn_or ("token: " ^ token) (Uuidm.of_string token) in
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.execute db Cookie.Sql.delete token)
        >>| fun () -> Brtl_mw_session.rem_session_value key ctx
    | None -> Abbs_future_combinators.return_ok ctx
  in
  let open Abb.Future.Infix_monad in
  f
  >>= function
  | Ok ctx -> Abbs_future_combinators.return_ok ctx
  | Error (#Pgsql_pool.err | #Pgsql_io.err) as err -> Abb.Future.return err

let create_user_session user ctx = set_session user ctx

let with_session ?caps ctx =
  match get_session ctx with
  | Some (Brtl_mw_session.Auth.Cookie session) | Some (Brtl_mw_session.Auth.Bearer session) -> (
      match caps with
      | Some caps ->
          if CCList.for_all CCFun.(flip Terrat_user.has_capability session) caps then
            Abbs_future_combinators.return_ok session
          else Abbs_future_combinators.return_err (Brtl_ctx.set_response `Forbidden ctx)
      | None -> Abbs_future_combinators.return_ok session)
  | None -> Abbs_future_combinators.return_err (Brtl_ctx.set_response `Forbidden ctx)
