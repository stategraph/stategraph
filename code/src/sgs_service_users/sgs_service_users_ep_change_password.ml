let src = Logs.Src.create "ep_change_password"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc
module Common = Sgs_service_users_common

module Sql = struct
  let select_user_password_hash () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.(option text)
      /^ [%blob "./sql/select_user_password_hash.sql"]
      /% Var.uuid "user_id")

  let update_user_password () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ [%blob "./sql/update_user_password.sql"]
      /% Var.uuid "user_id"
      /% Var.text "password_hash")
end

let run' db ~actor_caps user target_user_id current_password new_password =
  let open Fc.Infix_result_monad in
  let is_self = Uuidm.equal (Sgs_user.id user) target_user_id in
  Common.unless_self ~user target_user_id (fun () ->
      Common.authority_over ~actor:actor_caps db target_user_id)
  >>= fun () ->
  (* Get current password hash *)
  Pgsql_io.Prepared_stmt.fetch db (Sql.select_user_password_hash ()) ~f:CCFun.id target_user_id
  >>= function
  | [] -> Abbs_fc.return_err `Not_found_user_err
  | Some _hash :: _ -> (
      (* Replacing someone else's password takes no old password: the point of the authority
         checked above is that you do not have theirs. So the two cases are exactly [is_self]. *)
      when_ is_self (fun () ->
          match current_password with
          | None -> Abbs_fc.return_err `Bad_request_current_password_required_err
          | Some current_pwd -> (
              Pgsql_io.Prepared_stmt.fetch
                db
                (Sql.select_user_password_hash ())
                ~f:CCFun.id
                target_user_id
              >>? function
              | Some hash :: _ ->
                  if Sgs_user_password.verify current_pwd hash then Ok ()
                  else Error `Bad_request_current_password_incorrect_err
              | _ -> Error `Internal_password_verification_failed_err))
      >>= fun () ->
      (* Validate and hash new password *)
      (match Sgs_user_password.validate_strength new_password with
        | Ok () ->
            let new_hash = Sgs_user_password.hash new_password in
            Abbs_fc.return_ok new_hash
        | Error msg -> Abbs_fc.return_err (`Msg msg))
      >>= fun new_hash ->
      (* Update password *)
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.update_user_password ())
        ~f:CCFun.id
        target_user_id
        new_hash
      >>? function
      | [] -> Error `Not_found_user_err
      | id :: _ ->
          let response =
            {
              Sgs_api_components_user_change_password_response.id = Uuidm.to_string id;
              password_changed = true;
            }
          in
          let body =
            Yojson.Safe.to_string
            @@ Sgs_api_components_user_change_password_response.to_yojson response
          in
          Ok body)
  | None :: _ -> Abbs_fc.return_err `Bad_request_no_password_auth_err

let respond_bad_request ~id ~data ctx =
  Logs.warn (fun m -> m "%s : %s : %s" (Brtl_ctx.token ctx) id data);
  Abb.Future.return (Sgs_eplib.respond_error ~status:`Bad_request ~id ~data ctx)

let run _config storage target_user_id =
  (* The gate decides only that the caller is either the subject or holds authority over users
     somewhere. Which users that authority reaches is a database question, so this is a pre-filter
     and the decision is in [run']. *)
  Sgs_user_session.with_session
    ~caps:Sgs_user_session.Caps.(or_ users_manage_some (is_user target_user_id))
    ~f:(fun session ->
      let user = Sgs_user_session.Session.user session in
      let actor_caps = Sgs_user_session.Session.capabilities session in
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let body = Brtl_ctx.body ctx in
          match
            Sgs_api_components_user_change_password_request.of_yojson (Yojson.Safe.from_string body)
          with
          | Ok { Sgs_api_components_user_change_password_request.current_password; new_password }
            -> (
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  run' db ~actor_caps user target_user_id current_password new_password)
              >>= function
              | Ok body ->
                  Logs.info (fun m ->
                      m
                        "%s : PASSWORD_CHANGED Changed password for user %s"
                        (Brtl_ctx.token ctx)
                        (Uuidm.to_string target_user_id));
                  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
              | Error (`Msg msg) ->
                  respond_bad_request ~id:"PASSWORD_VALIDATION_FAILED" ~data:msg ctx
              | Error `Bad_request_current_password_required_err ->
                  respond_bad_request
                    ~id:"CURRENT_PASSWORD_REQUIRED"
                    ~data:"Current password required"
                    ctx
              | Error `Bad_request_current_password_incorrect_err ->
                  respond_bad_request
                    ~id:"CURRENT_PASSWORD_INCORRECT"
                    ~data:"Current password is incorrect"
                    ctx
              | Error `Bad_request_no_password_auth_err ->
                  respond_bad_request
                    ~id:"USER_NO_PASSWORD_AUTH"
                    ~data:"User does not use password authentication"
                    ctx
              | Error ((`Forbidden_peer_or_greater_err | `Forbidden_tenant_scope_err) as err) ->
                  Logs.warn (fun m ->
                      m
                        "%s : USER_AUTHORITY_DENIED : Refused to change the password of user %s"
                        (Brtl_ctx.token ctx)
                        (Uuidm.to_string target_user_id));
                  Abb.Future.return (Common.respond_no_authority ~err ctx)
              | Error `Not_found_user_err -> Abb.Future.return (Common.respond_user_not_found ctx)
              | Error `Internal_password_verification_failed_err ->
                  Logs.err (fun m ->
                      m
                        "%s : PASSWORD_VERIFICATION_FAILED Failed to verify current password"
                        (Brtl_ctx.token ctx));
                  Abb.Future.return
                    (Common.respond_internal_error ~data:"Failed to change password" ctx)
              | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                  Abb.Future.return
                    (Sgs_eplib.respond_db_err
                       ~src
                       ~body:
                         (Sgs_eplib.error_response_body
                            ~id:"INTERNAL_SERVER_ERROR"
                            ~data:"Failed to change password")
                       ctx
                       err))
          | Error err -> respond_bad_request ~id:"INVALID_REQUEST_BODY" ~data:err ctx))
