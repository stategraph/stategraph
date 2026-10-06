let src = Logs.Src.create "ep_access_token_create"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc

let run' storage session name capabilities =
  let open Fc.Infix_result_monad in
  let user = Sgs_user_session.Session.user session in
  (* A token can never exceed its creator: mask the requested capabilities by the resolved
     capabilities of the creating session. When the request omits capabilities, the token
     inherits the full session capabilities. *)
  let ceiling = Sgs_user_session.Session.capabilities session in
  match CCOption.map_or ~default:(Ok ceiling) Sg_caps_json.of_wire capabilities with
  | Error (#Sg_caps_json.read_err as err) ->
      Abbs_fc.return_err (`Invalid_capabilities (Sg_caps_json.read_err_to_string err))
  | Ok requested ->
      let capabilities = Sg_caps.inter ceiling requested in
      Pgsql_pool.with_conn storage ~f:(fun db ->
          Sgs_user_access_token.store ~name ~capabilities user db
          >>= fun access_token ->
          let token_session =
            Sgs_user_session.Session.create
              ~expiration:
                (Sgs_user_session.Session.Expiration.Access_token
                   (Sgs_user_access_token.id access_token))
              (Sgs_user.to_minted user)
          in
          Sgs_user_session.Session.fetch_key db
          >>= fun key -> Fc.to_result @@ Sgs_user_session.Session.to_token ~key token_session)

let run _config storage body =
  let { Sgs_api_components_access_token_create_request.name; capabilities } = body in
  Sgs_user_session.with_session
    ~caps:Sgs_user_session.Caps.(satisfies Sg_caps.{ empty with access_token_create = true })
    ~f:(fun session ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          run' storage session name capabilities
          >>= function
          | Ok token ->
              let body =
                Yojson.Safe.to_string
                @@ Sgs_api_components_access_token_create_response.to_yojson
                     { Sgs_api_components_access_token_create_response.token }
              in
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Created body) ctx)
          | Error (`Invalid_capabilities err) ->
              let msg = Printf.sprintf "invalid capability pattern %S" err in
              Logs.warn (fun m -> m "%s : VALIDATION_FAILED %s" (Brtl_ctx.token ctx) msg);
              let error_response =
                { Sgs_api_components_error_response.id = "INVALID_REQUEST_BODY"; data = Some msg }
              in
              let body =
                Yojson.Safe.to_string @@ Sgs_api_components_error_response.to_yojson error_response
              in
              Abb.Future.return
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request body) ctx)
          | Error (#Sgs_user_access_token.store_err as err) ->
              Logs.err (fun m ->
                  m "%s : %a" (Brtl_ctx.token ctx) Sgs_user_access_token.pp_store_err err);
              Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
          | Error (#Sgs_user_session.Session.fetch_key_err as err) ->
              Logs.err (fun m ->
                  m "%s : %a" (Brtl_ctx.token ctx) Sgs_user_session.Session.pp_fetch_key_err err);
              Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
              Abb.Future.return (Sgs_eplib.respond_internal_error ctx)))
