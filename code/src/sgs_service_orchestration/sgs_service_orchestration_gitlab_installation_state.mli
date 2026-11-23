(** Uninstall and restore of a provisioned GitLab installation, through the admin FDW channel.

    Ownership is checked against the local tenant<->installation link before any write, and a group
    linked to another tenant is indistinguishable from an unprovisioned one ([`Not_found_err]). An
    uninstalled installation ignores its webhooks. Restore takes it back to [pending], and its next
    webhook verifies it again. *)

(** A GitLab installation after an uninstall or a restore: its group id, name, and state. It leaves
    only via {!to_api}. *)
type t

type state_err =
  [ Pgsql_io.err
  | `Not_found_err  (** the group is not provisioned, or is linked to a different tenant *)
  | `Updated_row_missing_err
    (** the update returned no row although the link exists, so the remote side is not the schema
        this module assumes; the transaction is rolled back *)
  ]

(** Mark the installation of [group_id] uninstalled by the Stategraph user [user_id], only when the
    group is linked to [tenant_id]. The installation records the user as [stategraph:<user_id>]. An
    installation that is already uninstalled keeps the time and the user of its uninstall. *)
val uninstall :
  tenant_id:Uuidm.t ->
  group_id:int ->
  user_id:Uuidm.t ->
  Pgsql_io.t ->
  (t, [> state_err ]) result Abb.Future.t

(** Take the uninstalled installation of [group_id] back to [pending], only when the group is linked
    to [tenant_id]. An installation in any other state is unchanged. *)
val restore :
  tenant_id:Uuidm.t -> group_id:int -> Pgsql_io.t -> (t, [> state_err ]) result Abb.Future.t

val to_api : t -> Sgs_api_components.Gitlab_installation_state.t
