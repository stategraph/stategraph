let src = Logs.Src.create "ep_closed_tenants"

module Logs = (val Logs.src_log src : Logs.LOG)

let run _config storage =
  Sgs_user_session.with_user ~caps:Sgs_user_session.Caps.allow_all ~f:(fun user ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          Pgsql_pool.with_conn storage ~f:(Sgs_tenant.list_closed_by_user user)
          >>= function
          | Ok tenants ->
              let module U = Sgs_api_components.User_closed_tenants in
              let module T = Sgs_api_components.Closed_tenant in
              let body =
                tenants
                |> CCList.map (fun (id, name, ended_at) ->
                    { T.id = Uuidm.to_string id; name; ended_at })
                |> (fun results -> { U.results })
                |> U.to_yojson
                |> Yojson.Safe.to_string
              in
              Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
          | Error (#Sgs_tenant.err as err) ->
              Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Sgs_tenant.pp_err err);
              Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
              Abb.Future.return (Sgs_eplib.respond_internal_error ctx)))
