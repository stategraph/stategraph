let src = Logs.Src.create "ep_set_instance_admin"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc
module Common = Sgs_service_users_common
module Members = Sgs_service_tenants_members_common

let run' db target_user_id is_instance_admin =
  let open Fc.Infix_result_monad in
  let desired_admin_status = if is_instance_admin then `Instance_admin else `No_admin in
  Sgs_user.set_instance_admin desired_admin_status ~f:Fc.return_ok db target_user_id
  >>| fun () ->
  let response =
    {
      Sgs_api_components_user_set_instance_admin_response.id = Uuidm.to_string target_user_id;
      is_instance_admin;
    }
  in
  Yojson.Safe.to_string @@ Sgs_api_components_user_set_instance_admin_response.to_yojson response

let run _config storage target_user_id =
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.admin_instance ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let body = Brtl_ctx.body ctx in
          match
            Sgs_api_components_user_set_instance_admin_request.of_yojson
              (Yojson.Safe.from_string body)
          with
          (* Revoking your own grant locks you out of the screen you would need to undo it, so it
             is refused outright rather than allowed while another administrator remains -- the
             same rule [/tenants/{id}/members/set-role] applies to a self-demotion. Nothing about
             it needs the database, so it is answered before a connection is taken. *)
          | Ok { Sgs_api_components_user_set_instance_admin_request.is_instance_admin = false }
            when Uuidm.equal (Sgs_user.id user) target_user_id ->
              Logs.warn (fun m ->
                  m
                    "%s : SELF_DEMOTION_REFUSED : Refused user %s revoking their own installation \
                     admin grant"
                    (Brtl_ctx.token ctx)
                    (Uuidm.to_string target_user_id));
              Abb.Future.return
                (Members.respond_error
                   ctx
                   (`Cannot_act_on_self "You cannot remove your own installation admin grant"))
          | Ok { Sgs_api_components_user_set_instance_admin_request.is_instance_admin } -> (
              Pgsql_pool.with_conn storage ~f:(fun db -> run' db target_user_id is_instance_admin)
              >>= function
              | Ok body ->
                  Logs.info (fun m ->
                      m
                        "%s : ADMIN_STATUS_CHANGED : Set installation admin for user %s to %b"
                        (Brtl_ctx.token ctx)
                        (Uuidm.to_string target_user_id)
                        is_instance_admin);
                  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
              | Error `Would_remove_last_instance_admin_err ->
                  Logs.warn (fun m ->
                      m
                        "%s : LAST_ADMIN_PROTECTED : Refused to demote the last installation admin \
                         %s"
                        (Brtl_ctx.token ctx)
                        (Uuidm.to_string target_user_id));
                  Abb.Future.return (Common.respond_last_admin_protected ~action:Common.Demote ctx)
              | Error `Not_found_user_err -> Abb.Future.return (Common.respond_user_not_found ctx)
              | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
                  Abb.Future.return
                    (Sgs_eplib.respond_db_err
                       ~src
                       ~body:
                         (Sgs_eplib.error_response_body
                            ~id:"INTERNAL_SERVER_ERROR"
                            ~data:"Failed to set installation admin")
                       ctx
                       err))
          | Error err ->
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"INVALID_REQUEST_BODY"
                   ~data:err
                   ctx)))
