(** Shared pieces of the tenant membership endpoints: the capability gate, the [tenant-member]
    projection, and the failure vocabulary they answer with. *)

(** [wider_grant member] is a grant of [member] that covers more than the tenant it was read for, if
    there is one. Such a grant is not a tenant-scoped endpoint's to change: narrowing it would
    rewrite authority the caller does not own, and an installation-wide [admin] grant would be
    demoted without the guard that keeps the last administrator of the installation. *)
val wider_grant : Sgs_tenant.Member.t -> Sg_caps_ops.tenant_grant option

(** A refusal that is specific to membership management, as opposed to a capability denial (which
    {!Sgs_user_session.with_user} answers with [403]) or a database fault. [`Member_not_found] and
    [`User_not_found] are distinct: the first is a real user who is not in this tenant, the second
    is no user at all. *)
type err =
  [ `Cannot_act_on_self of string
  | `Member_not_found
  | `User_not_found
  | `Last_tenant_admin
  | `Wider_grant of Sg_caps_ops.tenant_grant
  | `Unrepresentable_grant of Sg_caps_ops.tenant_grant
  | `Caps_limit
  ]

(** [grant_to_caps tenant grant] is what a caller must hold to confer [grant] over [tenant]: the
    grant itself. No one may hand out a right they lack, so an endpoint whose request body chooses
    the grant must require this rather than {!Sgs_user_session.Caps.manages_tenant_members}, which
    [users-manage] alone satisfies — otherwise a member-manager can mint tenant-administrator rights
    for anyone, themselves included. Use it in [~caps] by selecting on the requested grant, so a
    refusal is still the standard [403] capability denial. *)
val grant_to_caps : 'a Sgs_tenant.t -> Sg_caps_ops.tenant_grant -> Sgs_user_session.Caps.t

(** Project a member onto the API type. Carries no status of its own — see {!respond_member}. The
    coverage of each grant is reported as-is rather than flattened to a boolean, so the UI can
    disable demote and remove for a member whose grant reaches beyond this tenant. *)
val member_to_api : Sgs_tenant.Member.t -> Sgs_api_components_tenant_member.t

(** Answer with a member: {!member_to_api}, serialised, at [status] -- [`Created] ([201]) when an
    add created the membership, [`OK] ([200]) when the member was already there or an edit returned
    them. *)
val respond_member :
  status:Cohttp.Code.status_code ->
  ('a, 'b) Brtl_ctx.t ->
  Sgs_tenant.Member.t ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Answer [400] [INVALID_REQUEST] for a path or body [user_id] that is not a uuid. *)
val respond_invalid_user_id : ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Answer an {!err} with the status and error id the API conventions call for:

    - [400] [CANNOT_ACT_ON_SELF] — [`Cannot_act_on_self]
    - [400] [CAPABILITY_LIMIT_EXCEEDED] — [`Caps_limit]
    - [404] [MEMBER_NOT_FOUND] — [`Member_not_found]
    - [404] [USER_NOT_FOUND] — [`User_not_found]
    - [409] [LAST_TENANT_ADMIN] — [`Last_tenant_admin]
    - [409] [MEMBER_HAS_WIDER_GRANT] — [`Wider_grant]
    - [409] [MEMBER_GRANT_NOT_EDITABLE] — [`Unrepresentable_grant] *)
val respond_error : ('a, 'b) Brtl_ctx.t -> err -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Log a tenant grant failure. Emits no response: the caller decides what to answer, which for a
    [`Wider_grant_err] / [`Unrepresentable_grant_err] is the matching {!err} through
    {!respond_error}, and otherwise a [500]. *)
val log_tenant_grant_err : ('a, 'b) Brtl_ctx.t -> Sgs_user.tenant_grant_err -> unit
