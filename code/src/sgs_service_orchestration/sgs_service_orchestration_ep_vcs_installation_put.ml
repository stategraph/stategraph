let src = Logs.Src.create "service_orchestration_ep_vcs_installation_put"

module Logs = (val Logs.src_log src : Logs.LOG)

let run _config storage tenant provider installation_core_id =
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.admin_instance ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          Abbs_fc.Infix_result_monad.(
            Abb.Future.return (Sgs_service_orchestration_common.check_provider provider)
            >>= fun () ->
            Pgsql_pool.with_conn storage ~f:(fun db ->
                Sgs_service_orchestration_tenant_vcs_installations.upsert
                  ~tenant_id:(Sgs_tenant.id tenant)
                  ~provider
                  ~installation_core_id
                  db))
          >>= function
          | Ok (`Linked (installation, moved_from)) ->
              (* Linking decides which tenant sees the installation's
                 orchestration data; when it moves, the losing tenant
                 belongs in the audit line. *)
              (match moved_from with
              | Some prev when not (Uuidm.equal prev (Sgs_tenant.id tenant)) ->
                  Logs.info (fun m ->
                      m
                        "%s : VCS_INSTALLATION_MOVED : tenant=%a provider=%s core_id=%a \
                         moved_from=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        (Sgs_tenant.id tenant)
                        provider
                        Uuidm.pp
                        installation_core_id
                        Uuidm.pp
                        prev)
              | Some _ | None ->
                  Logs.info (fun m ->
                      m
                        "%s : VCS_INSTALLATION_LINKED : tenant=%a provider=%s core_id=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        (Sgs_tenant.id tenant)
                        provider
                        Uuidm.pp
                        installation_core_id));
              Abb.Future.return
                (Sgs_service_orchestration_common.respond_installation ctx installation)
          | Ok `Tenant_not_found ->
              Logs.warn (fun m ->
                  m
                    "%s : VCS_INSTALLATION_TENANT_NOT_FOUND : tenant=%a"
                    (Brtl_ctx.token ctx)
                    Uuidm.pp
                    (Sgs_tenant.id tenant));
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
          | Error `Invalid_provider_err ->
              Abb.Future.return
                (Sgs_service_orchestration_common.respond_invalid_provider ~src ~provider ctx)
          | Error ((#Pgsql_io.err | #Pgsql_pool.err) as err) ->
              Abb.Future.return (Sgs_eplib.respond_db_err ~src ctx err)))
