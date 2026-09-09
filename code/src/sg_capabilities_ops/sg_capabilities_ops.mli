(** Pure operations on the capability lattice ({!Sgs_session_caps_capabilities.t}), extracted from
    [Sgs_session.Caps] so they can be reused and unit-tested without depending on [sgs]. *)

(** [state_resources v] interprets a [states] map entry value: a [null] resource list ([None]) means
    "all resources" in that state, i.e. ["*"]. Shared by {!mask} and [Sgs_session.Caps.satisfies];
    it lives here rather than on the (generated) {!Sgs_session_caps_states} module. *)
val state_resources : string list option -> string list

(** [mask ~mask input] restricts [input] by [mask]: a capability is granted in the result only if
    both [input] and [mask] grant it (capability intersection). The [None]-asymmetry mirrors
    [Sgs_session.Caps.satisfies]: for booleans and object-valued capabilities [None] means "not
    granted" (masking is a logical AND; an object is [Some] only when both sides are); for
    list-valued capabilities [None] and ["*"] both mean "all", and masking is intersection.
    Allow-list positives are intersected glob-aware (a value matched by both sides is kept), so the
    result is the exact intersection: it never out-grants either parent, and does not under-grant on
    differing globs. *)
val mask :
  mask:Sgs_session_caps_capabilities.t ->
  Sgs_session_caps_capabilities.t ->
  Sgs_session_caps_capabilities.t

(** [union a b] is the dual of {!mask}: a capability is granted in the result if [a] {e or} [b]
    grants it (booleans OR'd, an object present when either side has it, list scopes set-unioned
    with [None]/["*"] = "all" absorbing). Where {!mask} is the exact meet, [union] is the least
    sound {e upper} bound representable as a prefix-glob allow-list: it grants at least everything
    each parent does, and no more whenever the true join is representable (a side's negation is kept
    exactly where the other side grants nothing it denies). It can only over-grant in the
    irreducible cases where the join is a cone minus a sub-cone with a point re-granted inside it --
    a shape a flat allow-list cannot express (representing it exactly would require a decision-tree
    capability form). The result is re-normalized. *)
val union :
  Sgs_session_caps_capabilities.t ->
  Sgs_session_caps_capabilities.t ->
  Sgs_session_caps_capabilities.t

(** Adding and removing a single tenant from the [tenants] allow-list of a tenant-scoped capability
    ([admin], [users-manage]).

    The hard case is that an allow-list can cover a tenant without naming it: an absent list is
    installation-wide, and a glob or an all-negation list covers open-ended sets. An endpoint scoped
    to one tenant may only edit a grant that names {i exactly} that tenant -- editing anything
    broader would let an administrator of one tenant revoke authority they do not own (an
    installation admin's), and applying it partially would leave a membership row deleted while the
    capability still authorizes. So a wider grant is {i reported}, never edited, and the caller
    refuses the whole operation. *)
module Tenant_scope : sig
  (** How an allow-list covers one value.

      - [Not_covered]: the list does not permit it.
      - [Exact]: permitted, and removing the literal entry equal to it stops permitting it.
      - [Wider]: permitted by something broader -- an absent list, a glob, or a positive that
        survives removing the literal. *)
  type coverage =
    | Not_covered
    | Exact
    | Wider
  [@@deriving show, eq]

  (** [coverage ~list ~value] classifies how [list] covers [value]. [coverage ~list:None ~value] is
      [Wider]. *)
  val coverage : list:string list option -> value:string -> coverage

  (** [grant ~list ~value] returns a list that permits [value], or [`Unrepresentable_grant_err] when
      that cannot be expressed without also permitting something [list] denied.

      [grant ~list:None ~value] is [None]: the grant is already installation-wide and must not be
      narrowed to a one-element allow-list, so promoting someone within one tenant can never demote
      an installation admin. A list that already permits [value] is returned canonicalized and
      otherwise unchanged, for the same reason. A list that permits nothing becomes exactly
      [[value]].

      Otherwise some negation denies [value] and has to be dropped, which is sound only when that
      negation's cone is exactly [value]. A wider denial (["!a*"] blocking ["ab"], or the deny-all
      ["!*"] within a list that still grants something) makes the result -- a cone minus a sub-cone
      with one value re-granted inside it -- unrepresentable as a flat prefix-glob allow-list, the
      same irreducibility {!union} documents. It is refused rather than approximated, because both
      approximations are wrong: keeping the negation makes the grant a silent no-op, and dropping it
      grants authority nobody asked for.

      Postconditions: the result permits [value], and permits everything [list] permitted (it never
      narrows). *)
  val grant :
    list:string list option ->
    value:string ->
    (string list option, [> `Unrepresentable_grant_err ]) result

  (** [revoke ~list ~value] returns a list that does not permit [value], or [`Wider_grant_err] when
      [list] covers [value] by something broader than a literal entry (including [list = None]).

      [Not_covered] returns [list] unchanged, so revocation is idempotent. Emptying the positives
      yields ["!*"] (deny all), never ["*"] -- {!Sg_caps_match.canonicalize_list} is explicit about
      that, and inverting it would turn a demotion into an installation-wide promotion.

      Postcondition: the result never permits a value [list] did not already permit. *)
  val revoke :
    list:string list option -> value:string -> (string list option, [> `Wider_grant_err ]) result

  (** [grants_nothing list] is true when [list] permits no value at all. [None] is [false] -- an
      absent list is the installation-wide grant, not an empty one. *)
  val grants_nothing : string list option -> bool
end

(** Which tenant-scoped capability a grant operation applies to. *)
type tenant_grant =
  [ `Admin
  | `Users_manage
  ]

(** The capability's name as it appears in [session-capabilities.json] ([admin], [users-manage]), so
    log lines and error details match the stored JSON. *)
val show_tenant_grant : tenant_grant -> string

val pp_tenant_grant : Format.formatter -> tenant_grant -> unit

(** [is_instance_admin caps] is [true] when [caps] carries [admin] with either no [tenants] or a
    list containing ["*"] and no negation (e.g. granting access to every tenant, past, present, and
    future; for eternity). *)
val is_instance_admin : Sgs_session_caps_capabilities.t -> bool

(** [is_some_tenants_admin caps] is [true] when [caps] carries an [admin] grant that administers the
    tenants its allow-list names rather than the installation: the list permits something, but not
    everything.

    Mutually exclusive with {!is_instance_admin} by construction. *)
val is_some_tenants_admin : Sgs_session_caps_capabilities.t -> bool

(** The [admin] grant a write leaves a user holding. There is no tenant-scoped case: naming
    individual tenants is {!grant_tenant}'s and {!revoke_tenant}'s business, while this is the
    installation-wide authority, which either covers every tenant or is not there at all.

    - [`Instance_admin]: an unrestricted [admin], covering every tenant there is and every tenant
      there will be.
    - [`No_admin]: no [admin] key whatsoever. Deliberately not spelled "no instance admin": a
      tenant-scoped grant left behind would satisfy that name, and is removed too. *)
type instance_admin =
  [ `Instance_admin
  | `No_admin
  ]

(** [set_instance_admin admin caps] leaves [caps] holding exactly [admin]: [`Instance_admin] writes
    an unrestricted grant -- no [tenants] allow-list, so {!is_instance_admin} holds of the result --
    replacing whatever scope was there, and [`No_admin] removes the key entirely. Nothing else in
    [caps] is touched.

    It replaces rather than merges, unlike {!grant_tenant} and {!revoke_tenant}: those edit one
    entry of an allow-list because a tenant-scoped caller may only touch its own tenant, whereas
    this grant answers for every tenant at once and has no entry to edit. *)
val set_instance_admin :
  instance_admin -> Sgs_session_caps_capabilities.t -> Sgs_session_caps_capabilities.t

(** [tenant_coverage caps g tenant] is [Tenant_scope.Not_covered] when [caps] has no [g] grant at
    all, otherwise the coverage of that grant's [tenants] list. *)
val tenant_coverage :
  Sgs_session_caps_capabilities.t -> tenant_grant -> string -> Tenant_scope.coverage

(** [grant_tenant ~grants ~tenant caps] adds [tenant] to each capability in [grants], creating the
    capability object scoped to [tenant] alone when it is absent. Fails with the first capability
    whose allow-list cannot express the grant (see {!Tenant_scope.grant}); nothing is modified in
    that case. The result is re-normalized.

    This is the only sound way to write a tenant grant onto an existing capability set: it unions
    rather than replaces. Overwriting would strip a shared-instance user's grant over their own
    personal tenant, silently revoking authority over their own workspace. *)
val grant_tenant :
  grants:tenant_grant list ->
  tenant:string ->
  Sgs_session_caps_capabilities.t ->
  (Sgs_session_caps_capabilities.t, [> `Unrepresentable_grant_err of tenant_grant ]) result

(** [revoke_tenant ~grants ~tenant caps] removes [tenant] from each capability in [grants]. A
    capability absent from [caps] is left absent, and one whose allow-list ends up permitting
    nothing is removed entirely rather than left as an empty object -- every API that reports a
    user's role derives it from the key's presence. Fails with the first capability whose grant
    covers [tenant] more widely than a literal entry; nothing is modified in that case. The result
    is re-normalized. *)
val revoke_tenant :
  grants:tenant_grant list ->
  tenant:string ->
  Sgs_session_caps_capabilities.t ->
  (Sgs_session_caps_capabilities.t, [> `Wider_grant_err of tenant_grant ]) result

(** Why a capability set is not confined to a single tenant.

    - [Instance_capability name]: an installation-level capability that has no tenant scope at all
      ([access-token-create], [access-token-refresh], [sudo]) is present.
    - [Grants_beyond_tenant name]: a tenant-scopable capability ([admin], [users-manage], [commit],
      [preview]) reaches past the tenant -- an absent/glob/other-tenant [tenants] list, or a
      [commit]/[preview] left unbounded on both the tenant and state axes. *)
type tenant_scope_err =
  | Instance_capability of string
  | Grants_beyond_tenant of string
[@@deriving show, eq]

(** A human-readable, admin-facing explanation of a {!tenant_scope_err}, suitable for an API error
    body. *)
val tenant_scope_err_to_string : tenant_scope_err -> string

(** [scoped_to_tenant ~tenant caps] decides whether [caps] grants nothing beyond [tenant], as
    required of a capability-group rule owned by that tenant.

    A grant is in scope when: no installation-level capability is present; [admin] and
    [users-manage] (when present) name exactly [tenant]; and each [commit]/[preview] grant is
    bounded to [tenant] either by a [tenants] list naming exactly it or by an explicit set of
    states. Because a state's tenant is not encoded in the capability JSON, this cannot itself
    confirm those states belong to [tenant]: on [Ok state_ids] it returns every state id the
    [commit]/[preview] grants name, which the caller must verify are owned by [tenant] (rejecting
    the grant otherwise). *)
val scoped_to_tenant :
  tenant:string -> Sgs_session_caps_capabilities.t -> (string list, tenant_scope_err) result
