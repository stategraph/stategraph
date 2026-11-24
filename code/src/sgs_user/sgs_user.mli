module Type_ : sig
  type t =
    | User
    | Api
    | System
  [@@deriving show]

  val to_string : t -> string

  (** Inverse of {!to_string}; [None] for any unrecognised string. *)
  val of_string : string -> t option

  val to_api : t -> Sgs_api_components.User_type.t
  val of_api : Sgs_api_components.User_type.t -> t
end

type enrich_err =
  [ `User_not_found_err of Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

type store_err = Pgsql_io.err [@@deriving show]
type store_access_token_err = Pgsql_io.err [@@deriving show]

(** A [minted] user is one where a user value has been created but it has not been read from the
    database. This means certain information is not available. *)
type minted [@@deriving show]

(** A [stored] user is one that was read from the database. It has been enriched with all database
    information. *)
type stored [@@deriving show]

(** The decoder for the [capability_trie] column. A row whose value does not decode fails the query
    rather than being skipped: the admin rights the responses report are read off this value rather
    than stored, so a capability nobody can read must not read as a capability nobody has. *)
val caps_ret : Sg_caps.t Pgsql_io.Typed_sql.Ret.t

type 'a t [@@deriving show]

(** Mint a user value, providing the ID for the user and optionally which access token in the
    database to use. *)
val make : id:Uuidm.t -> unit -> minted t

(** Downgrade any user value to a [minted] user, discarding enriched (database) fields and keeping
    only its id. Useful when a [stored] user must be handed to an API that expects a [minted] one.
*)
val to_minted : 'a t -> minted t

val id : 'a t -> Uuidm.t
val name : stored t -> string
val email : stored t -> string option
val type_ : stored t -> Type_.t
val avatar_url : stored t -> string option
val auth_origin : stored t -> string option

(** What this user is allowed to do (the [capability_trie] column on the user row). Admin status is
    derived from it: a user administers a whole installation when their [admin] scope reaches every
    tenant, and one tenant when it reaches that tenant. *)
val capabilities : stored t -> Sg_caps.t

val enrich : 'a t -> Pgsql_io.t -> (stored t, [> enrich_err ]) result Abb.Future.t

(** Recompute-and-persist the user's effective capabilities at login: overwrite the
    [capability_trie] column with [base_capability_trie] joined with [group_caps] (what the user's
    IdP group rules grant — nothing when there are none), and return the result to mint the session
    from. Login is the sole recompute point for the [capability_trie] column. [`User_not_found_err]
    if the user row is absent. *)
val recompute_login_capabilities :
  group_caps:Sg_caps.t -> Pgsql_io.t -> Uuidm.t -> (Sg_caps.t, [> enrich_err ]) result Abb.Future.t

(** Hardcoded default user capabilities, used as a fallback when the [default_user_caps] system
    setting is absent or unparseable. Matches the value seeded by the database migration. *)
val default_capabilities : Sg_caps.t

(** Load the system-wide default user capabilities from the [default_user_caps] [system_settings]
    entry, falling back to {!default_capabilities}. *)
val default_user_caps : Pgsql_io.t -> (Sg_caps.t, [> store_err ]) result Abb.Future.t

(** Replace the system-wide default user capabilities (the [default_user_caps] [system_settings]
    entry). Takes effect for users created afterwards. *)
val set_default_user_caps : Sg_caps.t -> Pgsql_io.t -> (unit, [> store_err ]) result Abb.Future.t

(** The scope of an administrative grant. [`Instance] is authority over the whole installation;
    [`Tenants ids] restricts it to those tenants. [`No] adds nothing and revokes nothing — whatever
    the default-caps setting grants is left alone. *)
type admin_scope =
  [ `No
  | `Instance
  | `Tenants of string list
  ]

(** Like {!default_user_caps}, but merges in an [admin] capability of the requested scope. *)
val caps_for : admin:admin_scope -> Pgsql_io.t -> (Sg_caps.t, [> store_err ]) result Abb.Future.t

(** Create a new user in the database. [admin] defaults to [`No]. [capabilities] defaults to
    {!caps_for} (the [default_user_caps] setting, with the [admin] capability merged in). Without
    [password_hash], the user cannot sign in with a password. *)
val store :
  ?email:string ->
  ?admin:admin_scope ->
  ?capabilities:Sg_caps.t ->
  ?password_hash:string ->
  name:string ->
  type_:Type_.t ->
  Pgsql_io.t ->
  (stored t, [> store_err ]) result Abb.Future.t

(** Which of the two tenant-scoped grants an edit is about. *)
type tenant_grant =
  [ `Admin
  | `Users_manage
  ]
[@@deriving show]

(** Whether a user administers the whole installation. [`No_admin] is the absence of that grant, not
    of a tenant-scoped one. *)
type instance_admin =
  [ `Instance_admin
  | `No_admin
  ]
[@@deriving show]

type tenant_grant_err =
  [ `User_not_found_err of Uuidm.t
  | Pgsql_io.err
  ]
[@@deriving show]

(** [revoke_login_sessions ?except user db] deletes every browser login session ([kind = 'login']
    row in [access_tokens]) the user holds, forcing a fresh sign-in. A login session snapshots the
    capabilities at sign-in, so any capability change makes the snapshot stale — {!grant_tenant} and
    {!revoke_tenant} call this themselves; callers that write [users.capabilities] directly must
    call it in the same transaction. API tokens are deliberately untouched: capabilities limit what
    tokens a user can create, not what an already-minted token can do.

    [except] keeps one login row, by id. Pass it only for a strictly widening change: the kept
    snapshot is then merely under-privileged until the next sign-in, and the acting user is not
    logged out mid-request for a change that only gave them something. *)
val revoke_login_sessions :
  ?except:Uuidm.t -> 'a t -> Pgsql_io.t -> (unit, [> Pgsql_io.err ]) result Abb.Future.t

(** [grant_tenant ~grants ~tenant_id user db] adds [tenant_id] to each of the user's named
    tenant-scoped capabilities, creating one scoped to that tenant alone when absent, and returns
    the stored result (the effective one, i.e. the one unioned with the groups rules).

    The row is locked for the read-modify-write, so this must run inside a transaction — together
    with the matching {!Sgs_tenant.add_user}. Membership and capability are the two halves of one
    authorization decision and must not drift.

    [except_login_session] is forwarded to {!revoke_login_sessions}: pass the acting user's own
    login-session id so the widening grant does not log them out. *)
val grant_tenant :
  ?except_login_session:Uuidm.t ->
  grants:tenant_grant list ->
  tenant_id:Uuidm.t ->
  'a t ->
  Pgsql_io.t ->
  (Sg_caps.t, [> tenant_grant_err ]) result Abb.Future.t

(** [revoke_tenant ~grants ~tenant_id user db] takes [tenant_id] out of each of the user's named
    tenant-scoped capabilities. A scope holds a refusal as readily as an allowance, so this always
    succeeds: taking one tenant out of an installation-wide grant leaves every other tenant in it.

    That is more than a tenant-scoped endpoint may ask for. Narrowing a grant that covers more than
    the tenant in hand rewrites authority the caller does not own, and demotes an installation
    administrator without the guard that keeps the last one — so the membership endpoints refuse it
    first, on {!Sgs_service_tenants_members_common.wider_grant}.

    There is deliberately no [except_login_session] escape hatch here, unlike {!grant_tenant}: the
    kept session would go on authorizing the right this call just took away. A caller revoking a
    right from themselves is logged out so that the revokation is visibly immediate.

    The effective (i.e. the one unioned with the group rules) updated capability is returned. *)
val revoke_tenant :
  grants:tenant_grant list ->
  tenant_id:Uuidm.t ->
  'a t ->
  Pgsql_io.t ->
  (Sg_caps.t, [> tenant_grant_err ]) result Abb.Future.t

(** The capabilities of the active user with this id, or [None] when no active user has it. *)
val capabilities_of :
  Pgsql_io.t -> Uuidm.t -> (Sg_caps.t option, [> Pgsql_io.err ]) result Abb.Future.t

(** How many active human users hold installation-wide admin. Counts people: ['api'] and ['system']
    rows are left out, because the question every caller is asking is whether anyone is left who can
    administer the installation. *)
val count_instance_admins : Pgsql_io.t -> (int, [> Pgsql_io.err ]) result Abb.Future.t

(** Whether the installation has at least one human user, whatever its state. ['api'] and ['system']
    rows are left out: a fresh installation already holds its ['system'] user. *)
val has_human_users : Pgsql_io.t -> (bool, [> Pgsql_io.err ]) result Abb.Future.t

(** [guard_last_instance_admin ~f db target_user_id] runs [f] — a write that ends [target_user_id]'s
    installation-wide [admin] grant — only if the installation is left with an administrator
    afterwards.

    Answers [`Would_remove_last_instance_admin_err] when [target_user_id] holds the only
    unrestricted grant, and [`Not_found_user_err] when no active user has that id. Only the
    unrestricted grant counts, on both sides: a tenant-scoped admin is not what is being protected.

    [f] runs inside the guard's transaction, holding the lock that serializes installation-admin
    mutations, so that the count and the write it authorizes cannot be separated — without it two
    demotions of two different administrators each read the other as their replacement and both
    commit, leaving zero. See [sql/lock_instance_admins.sql]. That transaction is this function's
    own: it must not be called from inside another, which {!Pgsql_io.tx} answers by raising. *)
val guard_last_instance_admin :
  f:
    (unit ->
    ( 'a,
      ([> Pgsql_io.err | `Not_found_user_err | `Would_remove_last_instance_admin_err ] as 'e) )
    result
    Abb.Future.t) ->
  Pgsql_io.t ->
  Uuidm.t ->
  ('a, 'e) result Abb.Future.t

(** [set_instance_admin admin ~f db target_user_id] writes [admin] to [target_user_id] and then runs
    [f] in the same transaction, so a caller writing more than the grant lands all of it or none of
    it, and reads the grant back through anything [f] does.

    [`Instance_admin] writes the unrestricted [admin] scope, replacing a tenant-scoped one.
    [`No_admin] clears the [admin] scope only when it is unrestricted: a tenant-scoped grant is left
    as it is, and on a user who holds no grant the write changes nothing.

    When the write changes either capability column, both are written and every login session the
    target holds is revoked (see {!revoke_login_sessions}). When it changes nothing, nothing is
    written and no session is revoked. Answers [`Not_found_user_err] when no active user has that
    id.

    The transaction is this function's own on both paths, so like {!guard_last_instance_admin} it
    must not be called from inside another one. *)
val set_instance_admin :
  instance_admin ->
  f:
    (unit ->
    ( 'a,
      ([> Pgsql_io.err | `Not_found_user_err | `Would_remove_last_instance_admin_err ] as 'e) )
    result
    Abb.Future.t) ->
  Pgsql_io.t ->
  Uuidm.t ->
  ('a, 'e) result Abb.Future.t
