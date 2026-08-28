type err =
  [ Pgsql_io.err
  | Pgsql_pool.err
  | Terrat_github.Oauth.refresh_err
  ]
[@@deriving show]

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_user_token () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* token *)
      Ret.text
      //
      (* expired *)
      Ret.boolean
      //
      (* refresh_token *)
      Ret.text
      /^ read [%blob "sql/select_github_user2_tokens.sql"]
      /% Var.uuid "user_id")

  let update_github_user2_tokens () =
    Pgsql_io.Typed_sql.(
      sql
      /^ read [%blob "sql/update_github_user2_tokens.sql"]
      /% Var.uuid "user_id"
      /% Var.text "token"
      /% Var.(option (timestamptz "expiration"))
      /% Var.(option (text "refresh_token"))
      /% Var.(option (timestamptz "refresh_expiration")))

  let select_user_installation () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* installation_id *)
      Ret.bigint
      /^ read [%blob "sql/select_user_installation.sql"]
      /% Var.uuid "user_id"
      /% Var.bigint "installation_id")
end

let get_token config storage user =
  let open Abbs_future_combinators.Infix_result_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_user_token ())
        ~f:(fun token expired refresh_token -> (token, expired, refresh_token))
        (Terrat_user.id user))
  >>= function
  | [] -> assert false
  | (_, true, refresh_token) :: _ ->
      let module Oauth = Terrat_github.Oauth.Response in
      Terrat_github.Oauth.refresh
        ~config:(Terrat_vcs_service_github_provider.Api.Config.vcs_config config)
        refresh_token
      >>= fun oauth ->
      Abbs_future_combinators.to_result (Abb.Sys.time ())
      >>= fun now ->
      let expiration =
        CCOption.map
          (fun exp -> ISO8601.Permissive.string_of_datetime (now +. CCFloat.of_int exp))
          oauth.Oauth.expires_in
      in
      let refresh_expiration =
        CCOption.map
          (fun exp -> ISO8601.Permissive.string_of_datetime (now +. CCFloat.of_int exp))
          oauth.Oauth.refresh_token_expires_in
      in
      Pgsql_pool.with_conn storage ~f:(fun db ->
          Pgsql_io.Prepared_stmt.execute
            db
            (Sql.update_github_user2_tokens ())
            (Terrat_user.id user)
            oauth.Oauth.access_token
            expiration
            oauth.Oauth.refresh_token
            refresh_expiration
          >>| fun () -> oauth.Oauth.access_token)
  | (token, false, _) :: _ -> Abbs_future_combinators.return_ok token

let enforce_installation_access storage user installation_id ctx =
  if
    Terrat_user.has_capability
      (Terrat_user.Capability.Installation_id (CCInt.to_string installation_id))
      user
  then Abbs_future_combinators.return_ok ()
  else
    let open Abb.Future.Infix_monad in
    Pgsql_pool.with_conn storage ~f:(fun db ->
        Pgsql_io.Prepared_stmt.fetch
          db
          (Sql.select_user_installation ())
          ~f:CCFun.id
          (Terrat_user.id user)
          (CCInt64.of_int installation_id))
    >>= function
    | Ok (_ :: _) -> Abbs_future_combinators.return_ok ()
    | Ok [] -> Abbs_future_combinators.return_err (Brtl_ctx.set_response `Forbidden ctx)
    | Error (#Pgsql_pool.err as err) ->
        Logs.err (fun m ->
            m
              "ENFORCE_INSTALLATION_ACCESS : %s : ERROR : %a"
              (Brtl_ctx.token ctx)
              Pgsql_pool.pp_err
              err);
        Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx)
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m ->
            m
              "ENFORCE_INSTALLATION_ACCESS : %s : ERROR : %a"
              (Brtl_ctx.token ctx)
              Pgsql_io.pp_err
              err);
        Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx)
