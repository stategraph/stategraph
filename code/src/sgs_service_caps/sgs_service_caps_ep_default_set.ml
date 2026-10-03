let src = Logs.Src.create "ep_default_set"

module Logs = (val Logs.src_log src : Logs.LOG)

let bad_request id data ctx =
  let error_response = { Sgs_api_components_error_response.id; data = Some data } in
  let body = Yojson.Safe.to_string @@ Sgs_api_components_error_response.to_yojson error_response in
  Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request body) ctx

let run _config storage =
  Sgs_user_session.with_session (* You need to be an admin to change the default cap *)
    ~caps:Sgs_user_session.Caps.admin_instance
    ~f:(fun _session ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          let body = Brtl_ctx.body ctx in
          match
            Sgs_api_components_caps_default_request.of_yojson (Yojson.Safe.from_string body)
          with
          | Error err -> Abb.Future.return (bad_request "INVALID_REQUEST_BODY" err ctx)
          | Ok { Sgs_api_components_caps_default_request.capabilities } -> (
              match Sg_caps_json.of_wire capabilities with
              | Error (#Sg_caps_json.read_err as err) ->
                  let msg = Sg_caps_json.read_err_to_string err in
                  Logs.warn (fun m -> m "%s : VALIDATION_FAILED %s" (Brtl_ctx.token ctx) msg);
                  Abb.Future.return (bad_request "INVALID_REQUEST_BODY" msg ctx)
              | Ok capabilities -> (
                  Pgsql_pool.with_conn storage ~f:(fun db ->
                      Sgs_user.set_default_user_caps capabilities db)
                  >>= function
                  | Ok () ->
                      Logs.info (fun m -> m "%s : DEFAULT_CAPS_UPDATED" (Brtl_ctx.token ctx));
                      let body =
                        Yojson.Safe.to_string
                        @@ Sgs_api_components_caps_default_response.to_yojson
                             {
                               Sgs_api_components_caps_default_response.capabilities =
                                 Sg_caps_json.to_wire capabilities;
                             }
                      in
                      Abb.Future.return
                        (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
                  | Error (#Pgsql_pool.err as err) ->
                      Logs.err (fun m ->
                          m "%s : DB_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
                      Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
                  | Error (#Pgsql_io.err as err) ->
                      Logs.err (fun m ->
                          m "%s : DB_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
                      Abb.Future.return (Sgs_eplib.respond_internal_error ctx)))))
