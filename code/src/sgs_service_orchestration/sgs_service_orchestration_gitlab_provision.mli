(** GitLab group provisioning through the narrow admin FDW write channel.

    Inserts a GitLab installation into the terrateam database, reads back the trigger-generated
    core_id, and links it to the tenant — all in one remote transaction. The webhook secret is
    generated terrateam-side and returned exactly once; it is never persisted in or readable from
    stategraph state. *)

(** Abstract, so the plaintext webhook secret it carries cannot be printed through it. It leaves
    only via {!to_api}, whose generated response type is the one place the secret becomes printable;
    that value must never be logged, to preserve "returned exactly once". *)
type t

type provision_err =
  [ Pgsql_io.err
  | `Already_provisioned_err  (** the group id already has an installation *)
  | `Tenant_not_found_err  (** the tenant vanished between the capability check and the link *)
  | `Provisioned_row_missing_err
    (** the read-back after the insert returned no row, so the remote side is not the schema this
        module assumes (the map trigger did not fire, say); the transaction is rolled back *)
  ]

val provision :
  tenant_id:Uuidm.t ->
  group_id:int ->
  name:string ->
  access_token:string ->
  Pgsql_io.t ->
  (t, [> provision_err ]) result Abb.Future.t

val to_api : t -> Sgs_api_components.Gitlab_provision_response.t
