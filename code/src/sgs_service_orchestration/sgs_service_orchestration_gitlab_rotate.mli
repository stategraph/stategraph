(** Same-tenant credential rotation for a provisioned GitLab installation: a new access token
    (write-only) and/or a regenerated webhook secret (returned exactly once, like provisioning).

    Ownership is checked against the local tenant<->installation link before any write goes through
    the admin FDW channel, and a group linked to another tenant is indistinguishable from an
    unprovisioned one ([`Not_found_err]), so another tenant's installations do not leak. *)

(** Abstract, so the plaintext webhook secret it carries cannot be printed through it. It leaves
    only via {!to_api}, whose generated response type is the one place the secret becomes printable;
    that value must never be logged, to preserve "returned exactly once". The secret is present only
    when the rotation regenerated it. *)
type t

type rotate_err =
  [ Pgsql_io.err
  | `Not_found_err  (** the group is not provisioned, or is linked to a different tenant *)
  | `Rotated_row_missing_err
    (** the secret update or the read-back after the updates returned no row, so the remote side is
        not the schema this module assumes; the transaction is rolled back *)
  ]

(** Rotate a provisioned GitLab installation's credentials, only when the group is linked to
    [tenant_id]: optionally set a new access token and/or regenerate the webhook secret (returned
    exactly once). *)
val rotate :
  tenant_id:Uuidm.t ->
  group_id:int ->
  access_token:string option ->
  webhook_secret:[ `Keep | `Regenerate ] ->
  Pgsql_io.t ->
  (t, [> rotate_err ]) result Abb.Future.t

val to_api : t -> Sgs_api_components.Gitlab_rotate_response.t
