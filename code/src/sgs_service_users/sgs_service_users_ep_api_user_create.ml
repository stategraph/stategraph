let src = Logs.Src.create "ep_api_user_create"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc

let run' storage tenant name =
  let open Fc.Infix_result_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Sgs_user.store ~name ~type_:Sgs_user.Type_.Api db
      >>= fun user ->
      Sgs_tenant.add_user tenant user db
      >>= fun () ->
      (* Root token for a freshly created user: grant the new user's own capabilities. *)
      Sgs_user_access_token.store ~name ~capabilities:(Sgs_user.capabilities user) user db
      >>= fun access_token ->
      let token_session =
        Sgs_user_session.Session.create
          ~expiration:
            (Sgs_user_session.Session.Expiration.Access_token
               (Sgs_user_access_token.id access_token))
          (Sgs_user.to_minted user)
      in
      Sgs_user_session.Session.fetch_key db
      >>= fun key ->
      Fc.to_result @@ Sgs_user_session.Session.to_token ~key token_session
      >>| fun jwt_token -> (Sgs_user.id user, jwt_token))

let bad_request ctx =
  Abb.Future.return
    (Sgs_eplib.respond_error
       ~status:`Bad_request
       ~id:"INVALID_REQUEST"
       ~data:"tenant_id is not a uuid"
       ctx)

let run _config storage body =
  let { Sgs_api_components_api_user_create_request.name; tenant_id } = body in
  match Uuidm.of_string tenant_id with
  | None ->
      (* Still behind a session, so a bad uuid is not an unauthenticated probe; but the tenant
         cannot be resolved to authorize against, so it is a request error. *)
      Sgs_user_session.with_session ~caps:Sgs_user_session.Caps.allow_all ~f:(fun _session ->
          Brtl_ep.run_json ~f:bad_request)
  | Some tenant_uuid ->
      let tenant = Sgs_tenant.make ~id:tenant_uuid () in
      (* Creating an API user makes it a member of this tenant and returns a token for it. The
         authority to do so is administering the tenant (a tenant-scoped or installation-wide admin
         grant, both of which satisfy [admin_tenant]) or holding [users-manage] scoped to it --
         exactly the membership-management gate. Without it, [with_session ~caps:allow_all] let any
         authenticated user join, and mint a token for, any tenant by uuid. *)
      Sgs_user_session.with_user
        ~caps:
          (Sgs_user_session.Caps.manages_tenant_members (Uuidm.to_string (Sgs_tenant.id tenant)))
        ~f:(fun user ->
          Brtl_ep.run_json ~f:(fun ctx ->
              let open Abb.Future.Infix_monad in
              run' storage tenant name
              >>= function
              | Ok (user_id, token) ->
                  Logs.info (fun m ->
                      m
                        "%s : API_USER_CREATED : tenant=%a user=%a by=%a"
                        (Brtl_ctx.token ctx)
                        Uuidm.pp
                        tenant_uuid
                        Uuidm.pp
                        user_id
                        Uuidm.pp
                        (Sgs_user.id user));
                  let body =
                    Yojson.Safe.to_string
                    @@ Sgs_api_components_api_user_create_response.to_yojson
                         {
                           Sgs_api_components_api_user_create_response.user_id =
                             Uuidm.to_string user_id;
                           token;
                         }
                  in
                  Abb.Future.return
                    (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Created body) ctx)
              | Error (#Sgs_user_session.Session.fetch_key_err as err) ->
                  Logs.err (fun m ->
                      m "%s : %a" (Brtl_ctx.token ctx) Sgs_user_session.Session.pp_fetch_key_err err);
                  Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
              | Error (#Pgsql_pool.err as err) ->
                  Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
                  Abb.Future.return (Sgs_eplib.respond_internal_error ctx)))
