let src = Logs.Src.create "ep_default_get"

module Logs = (val Logs.src_log src : Logs.LOG)

let run _config storage =
  Sgs_user_session.with_session
  (* You need to be an admin to see the default cap, maybe a bit overzealous? *)
    ~caps:Sgs_user_session.Caps.admin_instance
    ~f:(fun _session ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          Pgsql_pool.with_conn storage ~f:(fun db -> Sgs_user.default_user_caps db)
          >>= function
          | Ok capabilities ->
              let body =
                Yojson.Safe.to_string
                @@ Sgs_api_components_caps_default_response.to_yojson
                     {
                       Sgs_api_components_caps_default_response.capabilities =
                         Sg_caps_json.to_wire capabilities;
                     }
              in
              Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m -> m "%s : DB_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
              Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
          | Error (#Pgsql_io.err as err) ->
              Logs.err (fun m -> m "%s : DB_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
              Abb.Future.return (Sgs_eplib.respond_internal_error ctx)))
