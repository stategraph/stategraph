let src = Logs.Src.create "service_orchestration_ep_gitlab_installation_state"

module Logs = (val Logs.src_log src : Logs.LOG)
module State = Sgs_service_orchestration_gitlab_installation_state

let op_name = function
  | `Uninstall -> "GITLAB_UNINSTALL"
  | `Restore -> "GITLAB_RESTORE"

let run op config storage tenant group_id =
  let op_name = op_name op in
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.admin_tenant (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          match Sgs_service_orchestration_common.provisioning_availability config with
          | (`Orchestration_disabled | `Provisioner_not_configured) as reason ->
              Abb.Future.return
                (Sgs_service_orchestration_common.respond_provisioning_unavailable ~src ctx reason)
          | `Available when group_id <= 0 ->
              Logs.warn (fun m -> m "%s : %s_INVALID" (Brtl_ctx.token ctx) op_name);
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:(op_name ^ "_INVALID")
                   ~data:"group_id must be a positive integer."
                   ctx)
          | `Available -> (
              Pgsql_pool.with_conn storage ~f:(fun db ->
                  let open Abbs_fc.Infix_result_monad in
                  Sgs_tenant.enforce_user user tenant db
                  >>= fun () ->
                  let tenant_id = Sgs_tenant.id tenant in
                  match op with
                  | `Uninstall ->
                      State.uninstall ~tenant_id ~group_id ~user_id:(Sgs_user.id user) db
                  | `Restore -> State.restore ~tenant_id ~group_id db)
              >>= function
              | Ok installation ->
                  Logs.info (fun m ->
                      m
                        "%s : %s_OK : group_id=%d : state=%s"
                        (Brtl_ctx.token ctx)
                        op_name
                        group_id
                        (State.to_api installation)
                          .Sgs_api_components.Gitlab_installation_state.state);
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components.Gitlab_installation_state.to_yojson
                    @@ State.to_api installation
                  in
                  Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
              | Error `Not_found_err ->
                  Logs.warn (fun m ->
                      m "%s : %s_NOT_FOUND : group_id=%d" (Brtl_ctx.token ctx) op_name group_id);
                  Abb.Future.return
                    (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
              | Error `Updated_row_missing_err ->
                  Logs.err (fun m ->
                      m
                        "%s : %s_UPDATED_ROW_MISSING : group_id=%d"
                        (Brtl_ctx.token ctx)
                        op_name
                        group_id);
                  Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
              | Error (#Sgs_eplib.tenant_access_err as err) ->
                  Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err))))

let uninstall config storage tenant group_id = run `Uninstall config storage tenant group_id
let restore config storage tenant group_id = run `Restore config storage tenant group_id
