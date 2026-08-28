module Oauth = Terrat_vcs_service_gitlab_user.Oauth

let src = Logs.Src.create "vcs_service_gitlab_ep_callback"

module Logs = (val Logs.src_log src : Logs.LOG)

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let insert_user2 () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ read [%blob "sql/insert_user2.sql"])

  let select_gitlab_user () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* user_id *)
      Ret.uuid
      //
      (* email *)
      Ret.(option text)
      //
      (* name *)
      Ret.(option text)
      //
      (* avatar_url *)
      Ret.text
      /^ read [%blob "sql/select_gitlab_user2.sql"]
      /% Var.text "username")

  let insert_gitlab_user () =
    Pgsql_io.Typed_sql.(
      sql
      /^ read [%blob "sql/insert_gitlab_user2.sql"]
      /% Var.(option (text "avatar_url"))
      /% Var.(option (text "email"))
      /% Var.(option (timestamptz "expiration"))
      /% Var.(option (text "name"))
      /% Var.(option (timestamptz "refresh_expiration"))
      /% Var.(option (text "refresh_token"))
      /% Var.text "token"
      /% Var.uuid "user_id"
      /% Var.text "username"
      /% Var.bigint "gitlab_user_id")
end

let perform_auth config storage code =
  let open Abbs_future_combinators.Infix_result_monad in
  let c = Terrat_vcs_service_gitlab_provider.Api.Config.config config in
  let vcs_config = Terrat_vcs_service_gitlab_provider.Api.Config.vcs_config config in
  Oauth.authorize ~config:vcs_config ~server_api_base:(Terrat_config.api_base c) code
  >>= fun oauth ->
  let access_token = oauth.Oauth.Response.access_token in
  let client =
    Openapic_abb.create
      ~user_agent:"Terrateam"
      ~base_url:(Terrat_config.Gitlab.api_base_url vcs_config)
      (`Bearer access_token)
  in
  Openapic_abb.call client (Gitlabc_user.GetApiV3User.make ())
  >>= fun resp ->
  let module U = Gitlabc_components_api_entities_userpublic in
  let (`OK { U.avatar_url; email; id = gitlab_user_id; name; username; _ }) =
    Openapi.Response.value resp
  in
  Abbs_future_combinators.to_result (Abb.Sys.time ())
  >>= fun now ->
  let expiration =
    CCOption.map
      (fun exp -> ISO8601.Permissive.string_of_datetime (now +. CCFloat.of_int exp))
      oauth.Oauth.Response.expires_in
  in
  let refresh_expiration =
    CCOption.map
      (fun exp -> ISO8601.Permissive.string_of_datetime (now +. CCFloat.of_int exp))
      oauth.Oauth.Response.refresh_token_expires_in
  in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.select_gitlab_user ())
            ~f:(fun user_id email name avatar_url -> (user_id, email, name, avatar_url))
            username
          >>= function
          | [] -> (
              Pgsql_io.Prepared_stmt.fetch db (Sql.insert_user2 ()) ~f:CCFun.id
              >>= function
              | [] -> assert false
              | user_id :: _ ->
                  Pgsql_io.Prepared_stmt.execute
                    db
                    (Sql.insert_gitlab_user ())
                    avatar_url
                    email
                    expiration
                    name
                    refresh_expiration
                    oauth.Oauth.Response.refresh_token
                    oauth.Oauth.Response.access_token
                    user_id
                    username
                    (CCInt64.of_int gitlab_user_id)
                  >>| fun () -> Terrat_user.make ~id:user_id ())
          | (user_id, _email, _name, _avatar_url) :: _ ->
              Pgsql_io.Prepared_stmt.execute
                db
                (Sql.insert_gitlab_user ())
                avatar_url
                email
                expiration
                name
                refresh_expiration
                oauth.Oauth.Response.refresh_token
                oauth.Oauth.Response.access_token
                user_id
                username
                (CCInt64.of_int gitlab_user_id)
              >>| fun () -> Terrat_user.make ~id:user_id ()))

let get config storage code _state =
  let open Abb.Future.Infix_monad in
  Brtl_ep.run ~content_type:"text/plain" ~f:(fun ctx ->
      perform_auth config storage code
      >>= function
      | Ok user ->
          let ctx = Terrat_session.create_user_session user ctx in
          let uri = ctx |> Brtl_ctx.uri_base |> CCFun.flip Uri.with_path "/" |> Uri.to_string in
          let headers = Cohttp.Header.of_list [ ("location", uri) ] in
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~headers ~status:`See_other "") ctx)
      | Error (#Openapic_abb.call_err as err) ->
          Logs.err (fun m -> m "FAIL : %a" Openapic_abb.pp_call_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (#Oauth.authorize_err as err) ->
          Logs.err (fun m -> m "FAIL : %a" Oauth.pp_authorize_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (#Pgsql_pool.err as err) ->
          Logs.err (fun m -> m "FAIL : %a" Pgsql_pool.pp_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "FAIL : %a" Pgsql_io.pp_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx))
