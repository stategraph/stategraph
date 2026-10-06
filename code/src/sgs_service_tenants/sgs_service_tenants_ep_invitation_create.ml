let src = Logs.Src.create "ep_invitation_create"

module Logs = (val Logs.src_log src : Logs.LOG)
module Common = Sgs_service_tenants_invitation_common
module Members = Sgs_service_tenants_members_common
module Invitation = Sgs_service_tenants_invitation

(* Deliberately loose: the authoritative check is the recipient's mail server, and a stricter pattern
   rejects addresses that are perfectly valid.  This only catches the obvious typo before a row is
   created for something that could never be delivered. *)
let valid_email email =
  let email = CCString.trim email in
  match CCString.Split.left ~by:"@" email with
  | Some (local, domain) ->
      (not (CCString.is_empty local))
      && CCString.contains domain '.'
      && (not (CCString.contains email ' '))
      && CCString.length email <= 320
  | None -> false

(* Creation is transactional.  Delivery is not, and deliberately happens after the commit: holding a
   transaction open across an HTTP call to the control plane would pin a pooled connection for the
   length of a third-party round trip. *)
let create config storage tenant user email role =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          Sgs_tenant.enforce_user user tenant db
          >>= fun () ->
          Sgs_tenant.fetch tenant db
          >>= function
          | None -> Abbs_fc.return_err (`Tenant_not_found_err (Sgs_tenant.id tenant))
          | Some stored ->
              Common.check_rate_limits
                ~invited_by:(Sgs_user.id user)
                ~tenant_id:(Sgs_tenant.id tenant)
                db
              >>= fun () ->
              Invitation.create
                ~ttl_hours:(Sgs_config.invitation_ttl_hours config)
                ~email
                ~role
                ~invited_by:(Sgs_user.id user)
                ~tenant_id:(Sgs_tenant.id tenant)
                db
              >>| fun created -> (created, Sgs_tenant.name stored)))

module Make (Cloud : Sgs_cloud.S) = struct
  module Sender = Common.Make_sender (Cloud)

  (* The creation proper: make the invitation, then deliver its link best-effort and answer.  Runs
   once the caller has been authorized and the address has passed its sanity check. *)
  let run' config storage tenant user email role ctx =
    let open Abb.Future.Infix_monad in
    create config storage tenant user email role
    >>= function
    | Ok (created, tenant_name) -> (
        let { Invitation.created_id; created_token; created_at; created_expires_at } = created in
        let accept_url =
          Common.accept_url ~console_base:(Sgs_config.ui_base config) ~token:created_token
        in
        Logs.info (fun m ->
            m
              "%s : INVITATION_CREATED : invitation=%a tenant=%a role=%s by=%a"
              (Brtl_ctx.token ctx)
              Uuidm.pp
              created_id
              Uuidm.pp
              (Sgs_tenant.id tenant)
              (Invitation.Role.to_string role)
              Uuidm.pp
              (Sgs_user.id user));
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Sender.deliver
              ~config
              ~request_token:(Brtl_ctx.token ctx)
              ~inviter:user
              ~invitation_id:created_id
              ~email
              ~tenant_name
              ~accept_url
              ~expires_at:created_expires_at
              db)
        >>= function
        | Ok delivery ->
            (* 201 even when the message did not go out.  The invitation exists and its link works
             either way, and [invite_url] is what lets the inviter pass it on themselves.  Failing
             here instead would discard a perfectly good invitation because a third-party mailer was
             unavailable. *)
            let invitation =
              {
                Sgs_api_components_tenant_invitation.id = Uuidm.to_string created_id;
                email;
                role = Common.api_role role;
                status = `Pending;
                created_at;
                expires_at = created_expires_at;
                delivered = Common.Delivery.delivered delivery;
                send_count = 1;
                invited_by_name = Sgs_user.name user;
              }
            in
            let body =
              Yojson.Safe.to_string
              @@ Sgs_api_components_invitation_create_response.to_yojson
                   {
                     Sgs_api_components_invitation_create_response.invitation;
                     invite_url = accept_url;
                     delivery = Common.Delivery.to_api delivery;
                   }
            in
            Abb.Future.return (Common.respond_json ~status:`Created body ctx)
        | Error (#Pgsql_pool.err as err) ->
            (* Recording the send attempt failed.  The invitation itself is committed, so this is a
             bookkeeping fault, not a reason to withhold the link. *)
            Logs.err (fun m -> m "%s : DB_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
            Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "%s : DB_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
            Abb.Future.return (Sgs_eplib.respond_internal_error ctx))
    | Error `Already_pending ->
        Abb.Future.return
          (Sgs_eplib.respond_error
             ~status:`Conflict
             ~id:"INVITATION_ALREADY_PENDING"
             ~data:
               "There is already a live invitation for that address. Resend it, or generate a new \
                link."
             ctx)
    | Error (`Rate_limited window) ->
        Logs.warn (fun m ->
            m
              "%s : INVITATION_REJECTED_RATE_LIMIT : by=%a window=%s"
              (Brtl_ctx.token ctx)
              Uuidm.pp
              (Sgs_user.id user)
              window);
        Abb.Future.return
          (Sgs_eplib.respond_error
             ~status:`Too_many_requests
             ~id:"INVITATION_RATE_LIMITED"
             ~data:("Too many invitations " ^ window)
             ctx)
    | Error (`Tenant_not_found_err id) ->
        Logs.warn (fun m -> m "%s : TENANT_NOT_FOUND : tenant=%a" (Brtl_ctx.token ctx) Uuidm.pp id);
        Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
    | Error (#Sgs_eplib.tenant_access_err as err) ->
        Abb.Future.return (Sgs_eplib.respond_tenant_access_err ctx err)

  let run config storage tenant body =
    let { Sgs_api_components_invitation_create_request.email; tenant_admin } = body in
    let email = CCString.trim email in
    let role = Common.role_of_admin_flag tenant_admin in
    (* The invitation is a grant made now and redeemed later, so the authority to make it is checked
     here: To create an invitation handing out right X, you should have right X yourself. *)
    let caps =
      match role with
      | Invitation.Role.Admin -> Members.grant_to_caps tenant `Admin
      | Invitation.Role.Member ->
          Sgs_user_session.Caps.manages_tenant_members (Uuidm.to_string (Sgs_tenant.id tenant))
    in
    Sgs_user_session.with_user ~caps ~f:(fun user ->
        Brtl_ep.run_json ~f:(fun ctx ->
            if not (valid_email email) then
              Abb.Future.return
                (Sgs_eplib.respond_error
                   ~status:`Bad_request
                   ~id:"INVALID_EMAIL"
                   ~data:"That does not look like an email address"
                   ctx)
            else run' config storage tenant user email role ctx))
end
