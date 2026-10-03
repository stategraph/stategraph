let src = Logs.Src.create "ep_group_rule_get"

module Logs = (val Logs.src_log src : Logs.LOG)
module Common = Sgs_service_caps_group_rule_common

let run _config storage tenant id =
  let tenant_id = Sgs_tenant.id tenant in
  Sgs_user_session.with_user ~caps:(Common.manage_caps tenant) ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Sgs_caps_rules.get_alive_by_tenant ~tenant_id id db)
          >>= function
          | Ok (Some rule) ->
              Logs.info (fun m -> m "%s : GROUP_RULE_READ : %a" (Brtl_ctx.token ctx) Uuidm.pp id);
              let body =
                Yojson.Safe.to_string
                @@ Sgs_api_components_caps_group_rule.to_yojson (Common.to_api rule)
              in
              Abb.Future.return (Common.respond_json ~status:`OK body ctx)
          | Ok None ->
              Logs.warn (fun m ->
                  m "%s : GROUP_RULE_NOT_FOUND : %a" (Brtl_ctx.token ctx) Uuidm.pp id);
              Abb.Future.return (Common.respond_json ~status:`Not_found "" ctx)
          | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
              Abb.Future.return (Sgs_eplib.respond_db_err ~src ctx err)))
