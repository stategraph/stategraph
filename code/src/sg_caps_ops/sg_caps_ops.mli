(** The questions the endpoints ask of a capability set: who administers which tenant, who outranks
    whom over users, whether a grant a tenant's administrator writes stays inside that tenant, and
    what a transaction's resources are judged against.

    {!Sg_caps} answers what a capability set allows; this answers what the product does with that.
*)

module Tenant_scope : sig
  (** How much of a tenant a grant covers. [Wider] is a grant that reaches the tenant and more,
      which is what separates administering one tenant from administering an installation. *)
  type coverage =
    | Not_covered
    | Exact
    | Wider
  [@@deriving show, eq]

  (** [coverage scope tenant] is [Exact] when [scope] reaches that tenant and no other, [Wider] when
      it reaches more, and [Not_covered] when it does not reach it. *)
  val coverage : Sg_caps_trie_scope.t -> string -> coverage
end

(** The two grants that are scoped to tenants. *)
type tenant_grant =
  [ `Admin
  | `Users_manage
  ]
[@@deriving show, eq]

(** [tenant_coverage caps grant ~tenant] is how much of [tenant] that grant of [caps] covers. *)
val tenant_coverage : Sg_caps.t -> tenant_grant -> tenant:string -> Tenant_scope.coverage

(** [grants_tenant caps grant ~tenant] is true when that grant reaches that tenant. *)
val grants_tenant : Sg_caps.t -> tenant_grant -> tenant:string -> bool

(** True when the [admin] grant reaches every tenant, which is what administering an installation
    means. *)
val is_instance_admin : Sg_caps.t -> bool

(** True when the [admin] grant reaches some tenant but not every one. *)
val is_some_tenants_admin : Sg_caps.t -> bool

(** How two users rank against each other over user management. *)
type authority =
  | Dominates
  | Peer_or_greater
  | Tenant_out_of_scope of string
[@@deriving show, eq]

(** [authority_over ~actor ~target ~target_tenants] is [Dominates] when [actor] holds strictly more
    authority over users than [target] and reaches every tenant [target] belongs to,
    [Tenant_out_of_scope] when it holds more but does not reach one of them, and [Peer_or_greater]
    when [target] holds as much as [actor] does. An [admin] grant answers a [users-manage] question
    at the same scope, so a tenant's administrator outranks a users-manage holder confined to it. *)
val authority_over : actor:Sg_caps.t -> target:Sg_caps.t -> target_tenants:string list -> authority

(** [reaches_user_tenant ~actor ~tenant] is true when [actor] reaches that tenant's users, with
    either grant that answers user questions: [admin] or [users-manage]. *)
val reaches_user_tenant : actor:Sg_caps.t -> tenant:string -> bool

(** [unreached_tenant ~actor ~target_tenants] is a tenant of [target_tenants] that [actor] reaches
    with neither [admin] nor [users-manage], if there is one. A target in no tenant leaves no tenant
    unreached. *)
val unreached_tenant : actor:Sg_caps.t -> target_tenants:string list -> string option

(** Why a grant cannot be written by a tenant's administrator. *)
type tenant_scope_err =
  | Instance_capability of string
  | Grants_beyond_tenant of string
[@@deriving show, eq]

val tenant_scope_err_to_string : tenant_scope_err -> string

(** [scoped_to_tenant ~tenant caps] is the states whose tenant the caller must confirm for [caps] to
    be bounded to [tenant], or why it is not bounded to it at all. A capability that is not about
    tenants cannot be granted this way however narrow it looks.

    A preview or commit grant that names no tenant is bounded once the states it names are known to
    be this tenant's -- but only when everything it reaches beyond the tenant sits on states it
    names. A grant that also answers for the states it does not name reaches states of every other
    tenant, which no caller can confirm, and is refused. *)
val scoped_to_tenant : tenant:string -> Sg_caps.t -> (string list, tenant_scope_err) result

(** The two actions a transaction is judged for. *)
type action =
  [ `Commit
  | `Preview
  ]
[@@deriving show, eq]

(** [reach caps action axis] is what that action reaches along that axis once the [admin] grant is
    read into it: an administrator of a tenant answers for the action there, whatever the action
    grant says. *)
val reach : Sg_caps.t -> action -> [ `Modified | `Pulled_in ] -> Sg_caps_reach.t

(** Why one resource of a transaction is refused. *)
type states_denial =
  | State_not_granted
  | Resource_not_granted
[@@deriving show, eq]

(** [states_denial reach ~tenant ~state_id ~fq_address] is why that resource is refused, or [None]
    when it is not. A state that reaches no address at all is out of scope; one that reaches some
    but not this address refuses the resource. *)
val states_denial :
  Sg_caps_reach.t -> tenant:string -> state_id:string -> fq_address:string -> states_denial option

(** [reaches_tenant reach ~tenant] is true when [reach] reaches some address of some state of that
    tenant. A refusal is about the tenant itself when it does not. *)
val reaches_tenant : Sg_caps_reach.t -> tenant:string -> bool

(** [reaches_every_address reach ~tenant] is true when nothing of that tenant can be refused, which
    is what lets a check skip fetching the resources at all. *)
val reaches_every_address : Sg_caps_reach.t -> tenant:string -> bool

module Db_checks : sig
  (** One rule as the refusal queries take it: the state it applies to, whether it refuses, and the
      literal it compares an address against, as a prefix or in full. No character of [pat] means
      anything to the query -- ['*'] and ['!'] are gone by the time it gets there. *)
  type rule = {
    state : string;
    neg : bool;
    prefix : bool;
    pat : string;
  }
  [@@deriving show, eq]

  type caps = {
    governed : string list;
    rules : rule list;
  }
  [@@deriving show, eq]

  (** [encode reach ~tenant] is the state rules of that tenant, as the columns of the refusal
      queries. [governed] is the states that reach at least one address, which is what tells a
      refused resource from a state that is out of scope. It fails on a rule that names a family of
      states, which a query resolving a state by equality has no counterpart for. *)
  val encode :
    Sg_caps_reach.t -> tenant:string -> (caps, [> `Unencodable_state_err of string ]) result
end
