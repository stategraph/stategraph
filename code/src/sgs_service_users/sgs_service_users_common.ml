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

let authority ~actor ~target ~target_tenants =
  match Sg_caps_ops.is_instance_admin actor with
  (* The exemption changes exactly one answer: [Sg_caps_ops.authority_over] already says
     [Dominates] for an installation admin against every target but another installation admin. *)
  | true -> Ok ()
  | false -> (
      let target_tenants = CCList.map (fun t -> Uuidm.to_string (Sgs_tenant.id t)) target_tenants in
      match Sg_caps_ops.authority_over ~actor ~target ~target_tenants with
      | Sg_caps_ops.Dominates -> Ok ()
      | Sg_caps_ops.Peer_or_greater -> Error `Forbidden_peer_or_greater_err
      | Sg_caps_ops.Tenant_out_of_scope _ -> Error `Forbidden_tenant_scope_err)

let authority_over ~actor db target_user_id =
  let open Abbs_fc.Infix_result_monad in
  match Sg_caps_ops.is_instance_admin actor with
  (* [authority] lets an installation admin act on any target: the two reads would decide nothing. *)
  | true -> Abbs_fc.return_ok ()
  | false -> (
      Sgs_user.capabilities_of db target_user_id
      >>= function
      | None -> Abbs_fc.return_err `Not_found_user_err
      | Some target ->
          Sgs_tenant.list_by_user (Sgs_user.make ~id:target_user_id ()) db
          >>? fun target_tenants -> authority ~actor ~target ~target_tenants)

let unless_self ~user target_user_id check =
  match Uuidm.equal (Sgs_user.id user) target_user_id with
  | true -> Abbs_fc.return_ok ()
  | false -> check ()

type tenant_visibility =
  | Complete of Sgs_tenant.stored Sgs_tenant.t list
  | Partial of {
      visible : Sgs_tenant.stored Sgs_tenant.t list;
      withheld_count : int;
    }

let visible_tenants ~actor ~user db target_user_id =
  let open Abbs_fc.Infix_result_monad in
  Sgs_tenant.list_by_user (Sgs_user.make ~id:target_user_id ()) db
  >>= fun tenants ->
  match Uuidm.equal (Sgs_user.id user) target_user_id with
  | true -> Abbs_fc.return_ok (Complete tenants)
  | false -> (
      let visible =
        CCList.filter
          (fun t ->
            Sg_caps_ops.reaches_user_tenant ~actor ~tenant:(Uuidm.to_string (Sgs_tenant.id t)))
          tenants
      in
      (* A caller reaching none of the subject's tenants is refused; a subject in no tenant
         has no membership to hide, so the empty list answers whatever the caller reaches. *)
      let length_tenants = CCList.length tenants in
      let length_visible = CCList.length visible in
      match (tenants, visible) with
      | [], _ -> Abbs_fc.return_ok (Complete visible)
      | _, [] -> Abbs_fc.return_err `Forbidden_no_tenant_visible_err
      | _ :: _, _ :: _ when length_visible = length_tenants -> Abbs_fc.return_ok (Complete tenants)
      | _ :: _, _ :: _ ->
          Abbs_fc.return_ok (Partial { visible; withheld_count = length_tenants - length_visible }))

let respond_no_authority ~err ctx =
  let detail =
    match err with
    | `Forbidden_peer_or_greater_err ->
        "requires authority strictly greater than the target user's; a peer or a superior cannot \
         be acted on"
    | `Forbidden_tenant_scope_err ->
        "requires a grant covering every tenant the target user belongs to"
    | `Forbidden_no_tenant_visible_err ->
        "requires a grant reaching at least one tenant the target user belongs to"
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
