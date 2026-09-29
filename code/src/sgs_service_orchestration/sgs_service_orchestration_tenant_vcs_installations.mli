(** Terrateam VCS installation -> tenant mapping (see the tenant_vcs_installations migration).
    [upsert] links an installation to a tenant, moving it if it was linked elsewhere (the primary
    key is (provider, installation_core_id), so an installation belongs to exactly one tenant). All
    operations take the tenant explicitly; the endpoints own capability checks. The
    installation_core_id is deliberately NOT validated against the terrateam *_installations_map
    foreign tables: the FDW bridge may be unconfigured or unreachable, and a mapping created before
    the installation's first sync must be allowed. *)

type t = {
  tenant_id : Uuidm.t;
  provider : string;
  installation_core_id : Uuidm.t;
  created_at : string;
  updated_at : string;
}

(** The orchestration engine's VCS providers: github or gitlab (matching the
    tenant_vcs_installations CHECK constraint and the terrateam catalog). *)
val valid_vcs_provider : string -> bool

val list_by_tenant :
  tenant_id:Uuidm.t -> Pgsql_io.t -> (t list, [> Pgsql_io.err ]) result Abb.Future.t

(** [`Linked (t, moved_from)] carries the previous owner when the upsert moved the installation from
    another tenant. [`Tenant_not_found] means the tenant does not exist; the upsert detects this by
    driving the insert off a [tenants] lookup rather than tripping the foreign key, so it is safe
    inside an enclosing transaction (a violation would abort it). *)
val upsert :
  tenant_id:Uuidm.t ->
  provider:string ->
  installation_core_id:Uuidm.t ->
  Pgsql_io.t ->
  ([ `Linked of t * Uuidm.t option | `Tenant_not_found ], [> Pgsql_io.err ]) result Abb.Future.t

(** [link_if_unlinked] links the installation only when it belongs to no tenant. When it is already
    linked it writes nothing: [`Already_linked_here] carries the existing link when this tenant
    holds it, so a retried or doubled claim gets back the link it made, and [`Linked_elsewhere]
    means another tenant holds it. Unlike {!upsert} it never moves an installation: proving control
    of an unclaimed installation says nothing about the tenant currently holding it, so a self-serve
    claim may create a link but never move one. The check and the write are one statement, so
    concurrent claims cannot both succeed. *)
val link_if_unlinked :
  tenant_id:Uuidm.t ->
  provider:string ->
  installation_core_id:Uuidm.t ->
  Pgsql_io.t ->
  ([ `Linked of t | `Already_linked_here of t | `Linked_elsewhere ], [> Pgsql_io.err ]) result
  Abb.Future.t

(** [delete] returns [`Not_found] when no row matched the tenant + provider + core id. *)
val delete :
  tenant_id:Uuidm.t ->
  provider:string ->
  installation_core_id:Uuidm.t ->
  Pgsql_io.t ->
  ([ `Deleted | `Not_found ], [> Pgsql_io.err ]) result Abb.Future.t

val to_api : t -> Sgs_api_components.Vcs_installation.t

(** [to_body t] is the [vcs-installation] JSON response body for [t]. *)
val to_body : t -> string
