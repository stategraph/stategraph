(* Helpers shared by the installation-wide /api/v1/users endpoints.

   The generic status/id/detail pairing lives in Sgs_common; what remains here is only what is
   specific to this family. *)

let respond_internal_error ~data ctx =
  Sgs_eplib.respond_error ~status:`Internal_server_error ~id:"INTERNAL_SERVER_ERROR" ~data ctx

let respond_user_not_found ctx =
  Sgs_eplib.respond_error ~status:`Not_found ~id:"USER_NOT_FOUND" ~data:"User not found" ctx

type last_admin_action =
  | Demote
  | Delete

let respond_last_admin_protected ~action ctx =
  let id, data =
    match action with
    | Demote -> ("CANNOT_REMOVE_LAST_ADMIN", "Cannot remove admin from the last admin user")
    | Delete -> ("CANNOT_DELETE_LAST_ADMIN", "Cannot delete the last admin user")
  in
  Sgs_eplib.respond_error ~status:`Bad_request ~id ~data ctx

let instance_admin_check session =
  Sgs_user_session.Caps.admin_instance
    (Sgs_user_session.Session.capabilities session)
    (Sgs_user_session.Session.user session)

let tenant_ids_of db user_id =
  let open Abbs_fc.Infix_result_monad in
  Sgs_tenant.list_by_user (Sgs_user.make ~id:user_id ()) db
  >>| CCList.map (fun t -> Uuidm.to_string (Sgs_tenant.id t))

let authority_over ~actor db target_user_id =
  let open Abbs_fc.Infix_result_monad in
  match Sg_caps_ops.is_instance_admin actor with
  (* The exemption changes exactly one answer: [Sg_caps_ops.authority_over] already says
     [Dominates] for an installation admin against every target but another installation admin. *)
  | true -> Abbs_fc.return_ok ()
  | false -> (
      Sgs_user.capabilities_of db target_user_id
      >>= function
      | None -> Abbs_fc.return_err `Not_found_user_err
      | Some target -> (
          tenant_ids_of db target_user_id
          >>= fun target_tenants ->
          Abb.Future.return
          @@
          match Sg_caps_ops.authority_over ~actor ~target ~target_tenants with
          | Sg_caps_ops.Dominates -> Ok ()
          | Sg_caps_ops.Peer_or_greater -> Error `Forbidden_peer_or_greater_err
          | Sg_caps_ops.Tenant_out_of_scope _ -> Error `Forbidden_tenant_scope_err))

let unless_self ~user target_user_id check =
  match Uuidm.equal (Sgs_user.id user) target_user_id with
  | true -> Abbs_fc.return_ok ()
  | false -> check ()

let reaches_user ~actor db target_user_id =
  let open Abbs_fc.Infix_result_monad in
  tenant_ids_of db target_user_id
  >>= fun target_tenants ->
  Abb.Future.return
  @@
  match Sg_caps_ops.unreached_tenant ~actor ~target_tenants with
  | None -> Ok ()
  | Some _ -> Error `Forbidden_tenant_scope_err

let respond_no_authority ~err ctx =
  let detail =
    match err with
    | `Forbidden_peer_or_greater_err ->
        "requires authority strictly greater than the target user's; a peer or a superior cannot \
         be acted on"
    | `Forbidden_tenant_scope_err ->
        "requires a grant covering every tenant the target user belongs to"
    | `Forbidden_no_tenant_in_scope_err ->
        "requires membership of a tenant the grant reaches, so that the new user has one to join"
  in
  Brtl_ctx.set_response
    (Brtl_rspnc.create
       ~status:`Forbidden
       (Sgs_user_session.Caps.denied_body
          [ { Sgs_user_session.Caps.kind = `Users_manage; detail } ]))
    ctx

let admin_rights capabilities =
  {
    Sgs_api_components_admin_rights.is_instance_admin = Sg_caps_ops.is_instance_admin capabilities;
    is_tenant_admin = Sg_caps_ops.is_some_tenants_admin capabilities;
  }
