let src = Logs.Src.create "members_common"

module Logs = (val Logs.src_log src : Logs.LOG)
module Scope = Sg_caps_ops.Tenant_scope

(* A caller may confer only rights they hold themselves, so the capability required of them is the
   very one being granted. *)
let grant_to_caps tenant grant =
  let tenant_id = Uuidm.to_string (Sgs_tenant.id tenant) in
  match grant with
  | `Admin -> Sgs_user_session.Caps.admin_tenant tenant_id
  | `Users_manage -> Sgs_user_session.Caps.users_manage_tenant tenant_id

(* The coverage a member's grant has over this tenant, as the API reports it.  [wider] is surfaced
   rather than flattened into [tenant] because the UI has to disable demote and remove for those
   members: their grant reaches beyond this tenant, so editing it from here is refused. *)
let api_scope = function
  | Scope.Not_covered -> `None
  | Scope.Exact -> `Tenant
  | Scope.Wider -> `Wider

let member_to_api member =
  let module M = Sgs_tenant.Member in
  {
    Sgs_api_components_tenant_member.user_id = Uuidm.to_string member.M.id;
    name = member.M.name;
    email = member.M.email;
    type_ = Sgs_user.Type_.to_string member.M.type_;
    avatar_url = member.M.avatar_url;
    joined_at = member.M.joined_at;
    admin_scope = api_scope member.M.admin;
    users_manage_scope = api_scope member.M.users_manage;
  }

(* Every membership endpoint that answers with the member sends the same body; only the status
   differs -- [`Created] when the add put the row there, [`OK] when an edit returned it. *)
let respond_member ~status ctx member =
  let body =
    Yojson.Safe.to_string @@ Sgs_api_components_tenant_member.to_yojson (member_to_api member)
  in
  Brtl_ctx.set_response (Brtl_rspnc.create ~status body) ctx

type err =
  [ `Cannot_act_on_self of string
  | `Member_not_found
  | `User_not_found
  | `Last_tenant_admin
  | `Wider_grant of Sg_caps_ops.tenant_grant
  | `Unrepresentable_grant of Sg_caps_ops.tenant_grant
  | `Caps_limit
  ]

(* The first grant of [member] that covers more than this tenant, if any. Such a grant is not a
   tenant-scoped endpoint's to change: narrowing it would rewrite authority the caller does not own,
   and an installation-wide admin grant would be demoted without the guard that keeps the last
   administrator of the installation. *)
let wider_grant member =
  let module Scope = Sg_caps_ops.Tenant_scope in
  let wider grant coverage =
    match coverage with
    | Scope.Wider -> Some grant
    | Scope.Exact | Scope.Not_covered -> None
  in
  CCOption.or_
    ~else_:(wider `Users_manage member.Sgs_tenant.Member.users_manage)
    (wider `Admin member.Sgs_tenant.Member.admin)

(* The membership endpoints share a failure vocabulary.  Statuses follow the API conventions: a
   refusal the caller could have avoided by asking differently is 400, a target that is not a member
   is 404, and a conflict with the tenant's current state -- the last administrator, or a grant whose
   scope this endpoint may not edit -- is 409. *)
let respond_error ctx = function
  | `Cannot_act_on_self detail ->
      Sgs_eplib.respond_error ~status:`Bad_request ~id:"CANNOT_ACT_ON_SELF" ~data:detail ctx
  | `Member_not_found ->
      Sgs_eplib.respond_error
        ~status:`Not_found
        ~id:"MEMBER_NOT_FOUND"
        ~data:"That user is not a member of this tenant"
        ctx
  (* Distinct from [`Member_not_found]: there is no such user account at all, so "add them to this
     tenant" has no subject, whereas a non-member is a real user the caller could still add. *)
  | `User_not_found ->
      Sgs_eplib.respond_error
        ~status:`Not_found
        ~id:"USER_NOT_FOUND"
        ~data:"No such active user"
        ctx
  | `Last_tenant_admin ->
      Sgs_eplib.respond_error
        ~status:`Conflict
        ~id:"LAST_TENANT_ADMIN"
        ~data:"A tenant must keep at least one administrator. Promote someone else first."
        ctx
  | `Wider_grant grant ->
      Sgs_eplib.respond_error
        ~status:`Conflict
        ~id:"MEMBER_HAS_WIDER_GRANT"
        ~data:
          (Printf.sprintf
             "That member's %s grant covers more than this tenant and cannot be changed from here"
             (Sg_caps_ops.show_tenant_grant grant))
        ctx
  | `Unrepresentable_grant grant ->
      Sgs_eplib.respond_error
        ~status:`Conflict
        ~id:"MEMBER_GRANT_NOT_EDITABLE"
        ~data:
          (Printf.sprintf
             "That member's %s grant uses a pattern this change cannot express"
             (Sg_caps_ops.show_tenant_grant grant))
        ctx
  | `Caps_limit ->
      Sgs_eplib.respond_error
        ~status:`Bad_request
        ~id:"CAPABILITY_LIMIT_EXCEEDED"
        ~data:"That user belongs to too many tenants to grant another"
        ctx

(* [`User_not_found_err] is reachable here only if the user row disappears between the membership
   read and the capability write, inside one transaction -- so it is an internal fault, not a 404. *)
let log_tenant_grant_err ctx err =
  Logs.err (fun m ->
      m "%s : TENANT_GRANT_ERROR : %a" (Brtl_ctx.token ctx) Sgs_user.pp_tenant_grant_err err)

let respond_invalid_user_id ctx =
  Sgs_eplib.respond_error
    ~status:`Bad_request
    ~id:"INVALID_REQUEST"
    ~data:"user_id is not a uuid"
    ctx

(* [Sgs_tenant.enforce_user_err] includes [Pgsql_io.err], and subsuming it is what had a deadlock or
   a statement timeout answered as a denial. Naming the refusal by its own constructor rather than
   matching [#Sgs_tenant.enforce_user_err] leaves the three arms disjoint, so nothing here depends on
   their order -- widen that last arm and it does again, with the database errors having to come
   first. *)
