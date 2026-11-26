(** Users List Endpoint

    [GET /api/v1/users]: a page of the active users the caller manages, newest first, with optional
    filtering by type and by a search over name and email.

    The caller needs an [admin] or [users-manage] grant. One that reaches every tenant lists the
    whole installation, users in no tenant included; one scoped to tenants lists the members of the
    open tenants it reaches. A page that another page follows carries a [Link] header whose
    [rel="next"] URL asks for that page, and the body says the same with [has_more] and
    [next_cursor]; the last page has no [Link] header. *)

(** GET /api/v1/users - List users with cursor-based pagination *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_api_components.User_type.t option ->
  string option ->
  string option ->
  int ->
  Brtl_rtng.Handler.t

module Tests : sig
  (** [page ~caps ~type_ ~search ~cursor ~limit db] is the page that [run] answers a session holding
      [caps]: [run] without the session and the HTTP. *)
  val page :
    caps:Sg_caps.t ->
    type_:Sgs_user.Type_.t option ->
    search:string option ->
    cursor:(string * Uuidm.t) option ->
    limit:int ->
    Pgsql_io.t ->
    (Sgs_api_components_users_list_response.t, [> Pgsql_io.err ]) result Abb.Future.t
end
