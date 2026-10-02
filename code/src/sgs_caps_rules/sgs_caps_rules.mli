(** Group-rules engine: admin-managed rules mapping IdP group conditions to capability grants. A
    user's group-derived capabilities are the {e union} of the grant of every rule whose condition
    matches their groups. Composition is monotone: the combination is a {!Sg_caps.union}, so a
    matching rule only ever {e adds} -- it never reduces what the other matching rules (or, at the
    call site, the baseline) grant -- and there is no precedence or match-ordering (the condition
    language itself has no negation). An individual grant may still use ['!']-negations to bound its
    own scope (e.g. ["*"; "!root"] for "everyone except root"); under union that shapes only what
    that rule adds and never subtracts from another grant. The union is exact, commutative and
    associative, so the result does not depend on the order the rules come in, whatever the grants
    are. *)

(** A condition over a user's group names. [Group] is a leaf that holds for a user who is in some
    group matching the (prefix-glob) pattern; [Any]/[All] are boolean OR/AND over sub-conditions. *)
type cond =
  | Group of string
  | Any of cond list
  | All of cond list
[@@deriving show]

(** A stored rule: its identity/audit metadata, the [tenant_id] that owns it, the [condition] that
    selects users, and the [grant] it contributes to a matching user. [created_at] is an ISO-8601
    timestamp string. A rule belongs to one tenant -- its [grant] is bounded to that tenant and only
    that tenant's admins manage it -- but every alive rule is still evaluated at login regardless of
    tenant (see {!eval}). *)
type rule = {
  id : Uuidm.t;
  tenant_id : Uuidm.t;
  created_at : string;
  created_by : Uuidm.t;
  description : string option;
  condition : cond;
  grant : Sg_caps.t;
}

type err = Pgsql_io.err [@@deriving show]

(** [matches cond ~groups] is [true] when [cond] holds for a user whose group memberships are
    [groups]. A [Group p] leaf holds iff some group matches the prefix-glob [p] (via
    {!Sg_caps_match.matches}); [Any []] is [false] and [All []] is [true]. *)
val matches : cond -> groups:string list -> bool

(** [eval rules ~groups] is the join of the grants of every rule whose condition matches [groups];
    the empty capability set (grants nothing) if none match. The join allows exactly what some
    matching grant allows, and does not depend on the order the rules come in. *)
val eval : rule list -> groups:string list -> Sg_caps.t

(** JSON (de)serialization for {!cond} as single-operator-key objects: [{ "group": <pattern> }],
    [{ "any": [ <cond>, ... ] }], [{ "all": [ <cond>, ... ] }]. [cond_of_yojson] returns [Error]
    with a human-readable message for any other shape. *)
val cond_to_yojson : cond -> Yojson.Safe.t

val cond_of_yojson : Yojson.Safe.t -> (cond, string) result

(** [validate_cond cond] is [Ok ()] when every [Group] pattern in [cond] is a well-formed
    prefix-glob (via {!Sg_caps_match.is_valid_pattern}); otherwise [Error] naming the offending
    pattern. *)
val validate_cond : cond -> (unit, string) result

(** [list_alive db] reads every rule that has not been soft-deleted ([deleted_at is null]), across
    all tenants. This is the login recompute's view: a matching rule applies to a user whatever
    tenant owns it. *)
val list_alive : Pgsql_io.t -> (rule list, [> err ]) result Abb.Future.t

(** [list_alive_by_tenant ~tenant_id db] reads the alive rules owned by [tenant_id] -- the view a
    tenant's admins manage. *)
val list_alive_by_tenant :
  tenant_id:Uuidm.t -> Pgsql_io.t -> (rule list, [> err ]) result Abb.Future.t

(** [get_alive_by_tenant ~tenant_id id db] reads the alive rule [id] owned by [tenant_id]; [None]
    when no such rule exists (an unknown id, one owned by a different tenant, or one soft-deleted),
    so a tenant admin cannot reach another tenant's rule by id. *)
val get_alive_by_tenant :
  tenant_id:Uuidm.t -> Uuidm.t -> Pgsql_io.t -> (rule option, [> err ]) result Abb.Future.t

(** [add ~tenant_id ~created_by ~description ~condition ~grant db] inserts a rule owned by
    [tenant_id] (server-assigned id and [created_at]) and returns its id. The caller is expected to
    have run {!validate_cond} and confirmed the grant is scoped to [tenant_id] (see
    {!Sg_caps_ops.scoped_to_tenant}) first. *)
val add :
  tenant_id:Uuidm.t ->
  created_by:Uuidm.t ->
  description:string option ->
  condition:cond ->
  grant:Sg_caps.t ->
  Pgsql_io.t ->
  (Uuidm.t, [> err ]) result Abb.Future.t

(** [soft_delete ~tenant_id id db] marks the rule [id] deleted, keeping the row for audit, but only
    when it is owned by [tenant_id] -- a tenant admin cannot reach another tenant's rule by id.
    Returns [true] if a matching alive rule was found and marked deleted, [false] if none matched
    (an unknown id, one owned by a different tenant, or one already deleted). Idempotent in effect:
    a second call returns [false] but the rule stays deleted. *)
val soft_delete : tenant_id:Uuidm.t -> Uuidm.t -> Pgsql_io.t -> (bool, [> err ]) result Abb.Future.t
