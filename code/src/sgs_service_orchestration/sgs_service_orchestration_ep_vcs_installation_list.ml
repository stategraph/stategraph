let src = Logs.Src.create "service_orchestration_ep_vcs_installation_list"

let run _config storage tenant =
  (* Capability-only, no tenant-membership check: instance admins are not
     tenant members, and the actor who links an installation (instance admin)
     must be able to read the result back. A tenant-scoped admin grant is
     authority over this tenant by itself. *)
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.admin_tenant (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Sgs_service_orchestration_tenant_vcs_installations.list_by_tenant
                ~tenant_id:(Sgs_tenant.id tenant)
                db)
          >>= function
          | Ok installations ->
              let body =
                Yojson.Safe.to_string
                @@ Sgs_api_components.Vcs_installation_list_response.to_yojson
                     {
                       Sgs_api_components.Vcs_installation_list_response.results =
                         CCList.map
                           Sgs_service_orchestration_tenant_vcs_installations.to_api
                           installations;
                     }
              in
              Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
          | Error ((#Pgsql_io.err | #Pgsql_pool.err) as err) ->
              Abb.Future.return (Sgs_eplib.respond_db_err ~src ctx err)))
