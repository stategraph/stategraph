let src = Logs.Src.create "ep_close"

module Logs = (val Logs.src_log src : Logs.LOG)

let run _config storage tenant =
  Sgs_user_session.with_user
    ~caps:(Sgs_user_session.Caps.admin_tenant (Uuidm.to_string (Sgs_tenant.id tenant)))
    ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Pgsql_io.tx db ~f:(fun () ->
                  let open Abbs_fc.Infix_result_monad in
                  Sgs_tenant.enforce_member user tenant db >>= fun () -> Sgs_tenant.close tenant db))
          >>= function
          | Ok `Closed ->
              Logs.info (fun m ->
                  m
                    "%s : TENANT_CLOSED : tenant=%a by=%a"
                    (Brtl_ctx.token ctx)
                    Uuidm.pp
                    (Sgs_tenant.id tenant)
                    Uuidm.pp
                    (Sgs_user.id user));
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`No_content "") ctx)
          | Ok `Already_closed ->
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Conflict
                   ~id:"TENANT_CLOSED"
                   ~data:"the tenant is closed already"
                   ctx)
          | Error (#Sgs_eplib.tenant_access_err as err) ->
              Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err)))
