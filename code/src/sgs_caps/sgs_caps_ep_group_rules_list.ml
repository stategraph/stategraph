let src = Logs.Src.create "ep_group_rules_list"

module Logs = (val Logs.src_log src : Logs.LOG)
module Common = Sgs_caps_group_rule_common

let run _config storage tenant =
  let tenant_id = Sgs_tenant.id tenant in
  Sgs_user_session.with_user ~caps:(Common.manage_caps tenant) ~f:(fun _user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Sgs_caps_rules.list_alive_by_tenant ~tenant_id db)
          >>= function
          | Ok rules ->
              Logs.info (fun m ->
                  m "%s : GROUP_RULES_LISTED : %d" (Brtl_ctx.token ctx) (CCList.length rules));
              let body =
                Yojson.Safe.to_string
                @@ Sgs_api_components_caps_group_rule_list_response.to_yojson
                     {
                       Sgs_api_components_caps_group_rule_list_response.rules =
                         CCList.map Common.to_api rules;
                     }
              in
              Abb.Future.return (Common.respond_json ~status:`OK body ctx)
          | Error ((#Pgsql_pool.err | #Pgsql_io.err) as err) ->
              Abb.Future.return (Sgs_eplib.respond_db_err ~src ctx err)))
