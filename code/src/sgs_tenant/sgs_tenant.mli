type err = Pgsql_io.err [@@deriving show]

type enforce_user_err =
  [ `User_not_in_tenant_err of Uuidm.t * Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

type create_err =
  [ `Name_conflict_err
  | `Name_invalid_err
  | Pgsql_io.err
  ]
[@@deriving show]

type rename_err =
  [ `Name_conflict_err
  | `Name_invalid_err
  | `Tenant_not_found_err of Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

type minted
type stored
type 'a t

(** A tenant's membership row joined with the member's user row.

    [admin] and [users_manage] are not booleans but coverages: a grant may cover this tenant by
    naming it exactly, by reaching some other tenants too (by name, by prefix, or by excluding only
    some), or by covering every tenant. Only {!Sg_caps_ops.Tenant_scope.Exact} coverage can be
    revoked from a tenant-scoped endpoint. *)
module Member : sig
  type t = {
    id : Uuidm.t;
    name : string;
    email : string option;
    type_ : Sgs_user.Type_.t;
    avatar_url : string option;
    joined_at : string;
    admin : Sg_caps_ops.Tenant_scope.coverage;
    users_manage : Sg_caps_ops.Tenant_scope.coverage;
  }
  [@@deriving show]
end

(** The longest a tenant name may be. The column is unconstrained [text], so this is the endpoint's
    bound rather than the database's. *)
val max_name_length : int

val make : id:Uuidm.t -> unit -> minted t
val id : 'a t -> Uuidm.t
val name : stored t -> string

(** The generated API representation, shared by the endpoints that answer with a tenant so they
    cannot disagree about its shape. *)
val to_api : stored t -> Sgs_api_components.Tenant.t

val store : string -> Pgsql_io.t -> (stored t, [> err ]) result Abb.Future.t

(** [create name db] stores a new tenant, refusing a name another tenant already holds.

    Distinct from {!store}, which does none of this: [find_or_create] and the signup path need to
    write a name without first asking whether it is free. *)
val create : string -> Pgsql_io.t -> (stored t, [> create_err ]) result Abb.Future.t

val find_or_create : string -> Pgsql_io.t -> (stored t, [> err ]) result Abb.Future.t

(** Add a member. Fails on a duplicate — see {!add_user_idempotent} for the retry-safe variant. *)
val add_user : 'b t -> 'a Sgs_user.t -> Pgsql_io.t -> (unit, [> err ]) result Abb.Future.t

(** Like {!add_user}, but adding an existing member is a no-op rather than an error. For paths that
    must be safe to retry, such as accepting an invitation. *)
val add_user_idempotent :
  'b t -> 'a Sgs_user.t -> Pgsql_io.t -> (unit, [> err ]) result Abb.Future.t

(** Remove a member. Idempotent: removing a non-member succeeds.

    This revokes {i visibility} only, which does take effect immediately — {!enforce_user}, and so
    every tenant-scoped endpoint, consults the membership table on each request. But the user's
    capabilities may still name the tenant, and those are what every user-facing API reports as
    their role and what an access token is minted from. The caller must pair this with
    {!Sgs_user.revoke_tenant} in the same transaction, and must let that call's failure abort the
    transaction rather than proceeding — the half-applied state is the one that still authorizes. *)
val remove_user : 'b t -> 'a Sgs_user.t -> Pgsql_io.t -> (unit, [> err ]) result Abb.Future.t

val list_by_user : 'a Sgs_user.t -> Pgsql_io.t -> (stored t list, [> err ]) result Abb.Future.t

(** [list_users ?cursor ~limit t db] pages this tenant's active members, oldest membership first,
    and returns the page along with the tenant's total active member count.

    [cursor] is the [(joined_at, id)] of the last row of the previous page — the full sort key, so
    members who joined in the same instant are not skipped or repeated across a page boundary. *)
val list_users :
  ?cursor:string * Uuidm.t ->
  limit:int ->
  'a t ->
  Pgsql_io.t ->
  (Member.t list * int, [> err ]) result Abb.Future.t

(** [fetch t db] resolves a tenant reference into its stored form, chiefly to read its name — routes
    parse the path uuid into a [minted] tenant, which carries no name. [None] when no such tenant
    exists. *)
val fetch : 'a t -> Pgsql_io.t -> (stored t option, [> err ]) result Abb.Future.t

(** [find_member t user_id db] is that user's membership row, or [None] when they are not an active
    member of the tenant. *)
val find_member : 'a t -> Uuidm.t -> Pgsql_io.t -> (Member.t option, [> err ]) result Abb.Future.t

(** [count_admins t db] is the number of active members whose [admin] capability covers this tenant,
    by any coverage. Used to refuse the removal or demotion that would leave a tenant with nobody
    able to administer it.

    Locks the tenant row ([FOR UPDATE]) to avoid races. *)
val count_admins : 'a t -> Pgsql_io.t -> (int, [> err ]) result Abb.Future.t

(** [rename ~name t db] renames the tenant.

    [name] is trimmed, and must be non-blank and at most {!max_name_length} characters. It must not
    collide with another tenant's name: [tenants.name] carries no unique index, but
    {!find_or_create} resolves tenants by name, so a duplicate would make that lookup ambiguous. The
    existence check and the update run under a row lock. *)
val rename : name:string -> 'a t -> Pgsql_io.t -> (stored t, [> rename_err ]) result Abb.Future.t

(** Succeed if a user is part of a tenant. *)
val enforce_user :
  'a Sgs_user.t -> minted t -> Pgsql_io.t -> (unit, [> enforce_user_err ]) result Abb.Future.t
