(** Helpers shared by the [/api/v1/users] endpoints. *)

(** Answer [500] with the [INTERNAL_SERVER_ERROR] id. [data] names the operation that failed
    ("Failed to create user"): the status and id are fixed because every internal failure tells the
    caller the same thing, and only the log line above it differs. *)
val respond_internal_error : data:string -> ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Answer [404] for a user id that names no active user. *)
val respond_user_not_found : ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Which write {!Sgs_user.guard_last_instance_admin} refused. [Demote] is a write that ends the
    grant but leaves the user in place. [Delete] takes the whole user with it. *)
type last_admin_action =
  | Demote
  | Delete

(** Answer [400] for a write the last-admin guard refused. *)
val respond_last_admin_protected :
  action:last_admin_action -> ('a, 'b) Brtl_ctx.t -> ('a, Brtl_rspnc.t) Brtl_ctx.t

(** Why [session] may or may not write an installation-wide [admin] grant.

    Reaching one of these endpoints takes {!Sgs_user_session.Caps.users_manage_some}; touching the
    installation-wide [admin] grant takes {!Sgs_user_session.Caps.admin_instance} on top of it,
    whatever let the caller in. *)
val instance_admin_check :
  Sgs_user_session.Session.stored Sgs_user_session.Session.t -> Sgs_user_session.Caps.result

(** One session's authority over another user, as {!Sg_caps_ops.authority_over} defines it, against
    the target read from the database: the capabilities it holds and the tenants it belongs to. It
    takes those two reads, so it cannot live in a [~caps] predicate.

    Answers [`Not_found_user_err] when no active user has that id, and otherwise one of two
    refusals, kept apart so the denial can say which it was. *)
val authority_over :
  actor:Sg_caps.t ->
  Pgsql_io.t ->
  Uuidm.t ->
  ( unit,
    [> `Not_found_user_err
    | `Forbidden_peer_or_greater_err
    | `Forbidden_tenant_scope_err
    | Pgsql_io.err
    ] )
  result
  Abb.Future.t

(** [unless_self ~user target_user_id check] is [Ok ()] when [user] is the target, and [check ()]
    otherwise: a user may always reach its own record, whatever authority it holds over others. *)
val unless_self :
  user:'a Sgs_user.t ->
  Uuidm.t ->
  (unit -> (unit, 'err) result Abb.Future.t) ->
  (unit, 'err) result Abb.Future.t

(** Whether [actor] reaches every tenant the user belongs to — the membership half of
    {!authority_over} and nothing else, for reading a user rather than acting on one. Reading who
    someone is does not ask for the authority editing them does. *)
val reaches_user :
  actor:Sg_caps.t ->
  Pgsql_io.t ->
  Uuidm.t ->
  (unit, [> `Forbidden_tenant_scope_err | Pgsql_io.err ]) result Abb.Future.t

(** Answer [403] for a refusal {!authority_over} returned, in the shape a [~caps] denial takes. *)
val respond_no_authority :
  err:
    [ `Forbidden_peer_or_greater_err
    | `Forbidden_tenant_scope_err
    | `Forbidden_no_tenant_in_scope_err
    ] ->
  ('a, 'b) Brtl_ctx.t ->
  ('a, Brtl_rspnc.t) Brtl_ctx.t

(** The two admin scopes every user-shaped response reports, read off the [capabilities]. *)
val admin_rights : Sg_caps.t -> Sgs_api_components_admin_rights.t
