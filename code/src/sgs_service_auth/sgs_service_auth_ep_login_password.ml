let src = Logs.Src.create "ep_login_password"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc

module Sql = struct
  let find_user_by_email () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      // Ret.(option text)
      /^ [%blob "./sql/select_user_by_email_for_login.sql"]
      /% Var.text "email")
end

let run config storage =
  Brtl_ep.run_json ~f:(fun ctx ->
      let token = Brtl_ctx.token ctx in
      let open Abb.Future.Infix_monad in
      (* Check: Only allow if OAuth is NOT configured *)
      match Sgs_config.oauth2 config with
      | Some _ ->
          Logs.warn (fun m ->
              m "%s : OAUTH_MODE_ACTIVE Password login attempted in OAuth mode" token);
          let error_response =
            {
              Sgs_api_components_error_response.id = "OAUTH_MODE_ENABLED";
              data = Some "Password login not available when OAuth is configured";
            }
          in
          let body =
            Yojson.Safe.to_string @@ Sgs_api_components_error_response.to_yojson error_response
          in
          Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Forbidden body) ctx)
      | None -> (
          (* Parse request body *)
          let body = Brtl_ctx.body ctx in
          match
            Sgs_api_components_login_password_request.of_yojson (Yojson.Safe.from_string body)
          with
          | Error err ->
              Logs.warn (fun m -> m "%s : INVALID_REQUEST Invalid request body: %s" token err);
              let error_response =
                { Sgs_api_components_error_response.id = "INVALID_REQUEST_BODY"; data = Some err }
              in
              let body =
                Yojson.Safe.to_string @@ Sgs_api_components_error_response.to_yojson error_response
              in
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request body) ctx)
          | Ok { Sgs_api_components_login_password_request.email; password } -> (
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  Pgsql_io.tx db ~f:(fun () ->
                      let open Fc.Infix_result_monad in
                      (* Look up user by email (SQL already filters for active users) *)
                      Pgsql_io.Prepared_stmt.fetch
                        db
                        (Sql.find_user_by_email ())
                        ~f:(fun id password_hash -> (id, password_hash))
                        email
                      >>= function
                      | (user_id, Some password_hash) :: _
                        when Sgs_user_password.verify password password_hash ->
                          Logs.info (fun m ->
                              m "%s : LOGIN_SUCCESS User %a logged in" token Uuidm.pp user_id);
                          (* Fetch encryption key for session *)
                          Sgs_user_session.Session.fetch_key db
                          >>= fun key ->
                          (* Enrich the user so the session is granted the user's capabilities *)
                          Sgs_user.enrich (Sgs_user.make ~id:user_id ()) db
                          >>= fun user ->
                          (* DB-backed login session; capability changes revoke it. *)
                          Sgs_user_session.Session.create_login
                            ~capabilities:(Sgs_user.capabilities user)
                            (Sgs_user.to_minted user)
                            db
                          >>= fun session ->
                          Fc.to_result @@ Sgs_user_session.Session.to_token ~key session
                          >>| fun session_token -> Some session_token
                      | _ ->
                          (* User not found or invalid password - same error message to prevent
                             enumeration *)
                          Logs.warn (fun m ->
                              m "%s : LOGIN_FAILED Invalid email or password for %s" token email);
                          Abbs_fc.return_ok None))
              >>= function
              | Ok (Some session_token) ->
                  let response =
                    { Sgs_api_components_login_password_response.success = true; session_token }
                  in
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_login_password_response.to_yojson response
                  in
                  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
              | Ok None ->
                  (* Generic error message to prevent user enumeration *)
                  let error_response =
                    {
                      Sgs_api_components_error_response.id = "INVALID_CREDENTIALS";
                      data = Some "Invalid email or password";
                    }
                  in
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_error_response.to_yojson error_response
                  in
                  Abb.Future.return
                    (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Unauthorized body) ctx)
              | Error (`User_not_found_err user_id) ->
                  Logs.err (fun m ->
                      m "%s : DB_ERROR User %a not found while enriching" token Uuidm.pp user_id);
                  let error_response =
                    {
                      Sgs_api_components_error_response.id = "INTERNAL_SERVER_ERROR";
                      data = Some "Failed to process login";
                    }
                  in
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_error_response.to_yojson error_response
                  in
                  Abb.Future.return (Sgs_eplib.respond_internal_error ~body ctx)
              | Error ((`Bad_signing_key_err _ | `Key_not_found_err) as err) ->
                  Abb.Future.return
                    (Sgs_eplib.respond_signing_key_err
                       ~body:
                         (Sgs_eplib.error_response_body
                            ~id:"INTERNAL_SERVER_ERROR"
                            ~data:"Failed to process login")
                       ctx
                       err)
              | Error (#Pgsql_pool.err as err) ->
                  Logs.err (fun m -> m "%s : DB_ERROR Pool error: %a" token Pgsql_pool.pp_err err);
                  let error_response =
                    {
                      Sgs_api_components_error_response.id = "INTERNAL_SERVER_ERROR";
                      data = Some "Failed to process login";
                    }
                  in
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_error_response.to_yojson error_response
                  in
                  Abb.Future.return (Sgs_eplib.respond_internal_error ~body ctx)
              | Error (#Pgsql_io.err as err) ->
                  Logs.err (fun m -> m "%s : DB_ERROR Database error: %a" token Pgsql_io.pp_err err);
                  let error_response =
                    {
                      Sgs_api_components_error_response.id = "INTERNAL_SERVER_ERROR";
                      data = Some "Failed to process login";
                    }
                  in
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_error_response.to_yojson error_response
                  in
                  Abb.Future.return (Sgs_eplib.respond_internal_error ~body ctx))))
