let src = Logs.Src.create "vcs_service_github_ep_callback"

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

  let select_github_user2 () =
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
      /^ read [%blob "sql/select_github_user2.sql"]
      /% Var.text "username")

  let insert_github_user2 () =
    Pgsql_io.Typed_sql.(
      sql
      /^ read [%blob "sql/insert_github_user2.sql"]
      /% Var.(option (text "avatar_url"))
      /% Var.(option (text "email"))
      /% Var.(option (timestamptz "expiration"))
      /% Var.(option (text "name"))
      /% Var.(option (timestamptz "refresh_expiration"))
      /% Var.(option (text "refresh_token"))
      /% Var.text "token"
      /% Var.uuid "user_id"
      /% Var.text "username")

  let insert_github_user_email () =
    Pgsql_io.Typed_sql.(
      sql
      /^ "insert into github_user_emails (username, email, is_primary) values($username, $email, \
          $is_primary) on conflict (username, email) do update set is_primary = \
          excluded.is_primary"
      /% Var.text "username"
      /% Var.text "email"
      /% Var.boolean "is_primary")
end

let perform_auth request_id config storage code =
  let module Oauth = Terrat_github.Oauth.Response in
  let open Abbs_future_combinators.Infix_result_monad in
  Terrat_github.Oauth.authorize
    ~config:(Terrat_vcs_service_github_provider.Api.Config.vcs_config config)
    code
  >>= fun oauth ->
  let access_token = oauth.Oauth.access_token in
  Terrat_github.user
    ~config:(Terrat_vcs_service_github_provider.Api.Config.vcs_config config)
    ~access_token
    ()
  >>= fun current_user ->
  let c =
    Terrat_github.create
      (Terrat_vcs_service_github_provider.Api.Config.vcs_config config)
      (`Bearer access_token)
  in
  Githubc2_abb.call
    c
    Githubc2_users.List_emails_for_authenticated_user.(make (Parameters.make ~per_page:100 ()))
  >>= fun user_emails ->
  let emails =
    match Openapi.Response.value user_emails with
    | `OK emails ->
        CCList.map
          (fun Githubc2_components.
                 { Email.primary = { Email.Primary.email; primary = is_primary; _ }; _ }
             -> (email, is_primary))
          emails
    | _ -> []
  in
  Abbs_future_combinators.to_result (Abb.Sys.time ())
  >>= fun now ->
  let username, avatar_url, name, email =
    let module Gar = Githubc2_users.Get_authenticated.Responses.OK in
    let module Pr = Githubc2_components.Private_user in
    let module Pu = Githubc2_components.Public_user in
    match current_user with
    | Gar.Private_user Pr.{ primary = Primary.{ avatar_url; name; email; login; _ }; _ }
    | Gar.Public_user Pu.{ avatar_url; name; email; login; _ } -> (login, avatar_url, name, email)
  in
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
  Logs.info (fun m -> m "%s : CALLBACK : username=%s" request_id username);
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            (Sql.select_github_user2 ())
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
                    (Sql.insert_github_user2 ())
                    (Some avatar_url)
                    email
                    expiration
                    name
                    refresh_expiration
                    oauth.Oauth.refresh_token
                    oauth.Oauth.access_token
                    user_id
                    username
                  >>= fun () ->
                  Abbs_future_combinators.List_result.iter
                    ~f:(fun (email, is_primary) ->
                      Pgsql_io.Prepared_stmt.execute
                        db
                        (Sql.insert_github_user_email ())
                        username
                        email
                        is_primary)
                    emails
                  >>| fun () -> Terrat_user.make ~id:user_id ())
          | (user_id, _email, _name, _avatar_url) :: _ ->
              Pgsql_io.Prepared_stmt.execute
                db
                (Sql.insert_github_user2 ())
                (Some avatar_url)
                email
                expiration
                name
                refresh_expiration
                oauth.Oauth.refresh_token
                oauth.Oauth.access_token
                user_id
                username
              >>= fun () ->
              Abbs_future_combinators.List_result.iter
                ~f:(fun (email, is_primary) ->
                  Pgsql_io.Prepared_stmt.execute
                    db
                    (Sql.insert_github_user_email ())
                    username
                    email
                    is_primary)
                emails
              >>| fun () -> Terrat_user.make ~id:user_id ()))

let get config storage code installation_id_opt =
  let open Abb.Future.Infix_monad in
  Brtl_ep.run ~content_type:"text/plain" ~f:(fun ctx ->
      perform_auth (Brtl_ctx.token ctx) config storage code
      >>= function
      | Ok user ->
          let ctx = Terrat_session.create_user_session user ctx in
          let uri =
            ctx
            |> Brtl_ctx.uri_base
            |> CCFun.flip Uri.with_path "/"
            |> CCFun.flip
                 Uri.with_query
                 (CCOption.map_or
                    ~default:[]
                    (fun installation_id ->
                      [ ("installation_id", [ Int64.to_string installation_id ]) ])
                    installation_id_opt)
            |> Uri.to_string
          in
          let headers = Cohttp.Header.of_list [ ("location", uri) ] in
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~headers ~status:`See_other "") ctx)
      | Error (#Pgsql_pool.err as err) ->
          Logs.err (fun m -> m "FAIL : %s" (Pgsql_pool.show_err err));
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "FAIL : %s" (Pgsql_io.show_err err));
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (#Terrat_github.user_err as err) ->
          Logs.err (fun m -> m "FAIL : %s" (Terrat_github.show_user_err err));
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (#Terrat_github.Oauth.authorize_err as err) ->
          Logs.err (fun m -> m "FAIL : %a" Terrat_github.Oauth.pp_authorize_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx))
