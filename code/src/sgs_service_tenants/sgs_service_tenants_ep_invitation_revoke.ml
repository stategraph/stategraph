let src = Logs.Src.create "ep_invitation_revoke"

module Logs = (val Logs.src_log src : Logs.LOG)
module Common = Sgs_service_tenants_invitation_common

let run _config storage tenant id_str =
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.manages_tenant_members (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          match Uuidm.of_string id_str with
          | None ->
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"INVALID_REQUEST"
                   ~data:"id is not a uuid"
                   ctx)
          | Some id -> (
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  Pgsql_io.tx db ~f:(fun () ->
                      let open Abbs_fc.Infix_result_monad in
                      Sgs_tenant.enforce_user user tenant db
                      >>= fun () ->
                      Sgs_service_tenants_invitation.revoke
                        ~id
                        ~tenant_id:(Sgs_tenant.id tenant)
                        ~user_id:(Sgs_user.id user)
                        db))
              >>= function
              | Ok () ->
                  Logs.info (fun m ->
                      m
                        "%s : INVITATION_REVOKED : invitation=%a by=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        id
                        Uuidm.pp
                        (Sgs_user.id user));
                  Abb.Future.return
                    (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`No_content "") ctx)
              | Error `Not_found -> Abb.Future.return (Common.respond_act_err ctx `Not_found)
              | Error (#Sgs_eplib.tenant_access_err as err) ->
                  Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err))))
