(** Read side of GitHub installations over the terrateam read FDW. *)

(** A GitHub installation linked to no tenant, as both the unclaimed and the claimable listings
    return it. *)
type installation = {
  installation_core_id : Uuidm.t;
  github_id : int;
  login : string;
  target_type : string;
  state : string;
  created_at : string;
}

(** GitHub installations linked to no tenant — the set an admin can claim — newest first, at most
    [limit] of them.

    [cursor] is the [(created_at, installation_core_id)] of the last row of the previous page, as
    {!Sgs_eplib.Cursor} encodes it; [None] starts at the newest. Keyset, not offset, so a page
    boundary stays correct while installations are being claimed underneath the walk. The caller
    knows there is another page when it gets [limit] rows back. *)
val list_unclaimed :
  cursor:(string * Uuidm.t) option ->
  limit:int ->
  Pgsql_io.t ->
  (installation list, [> Pgsql_io.err ]) result Abb.Future.t

val to_api : installation -> Sgs_api_components.Github_unclaimed_installation.t

(** [list_claimable ~github_installation_ids db] narrows the ids GitHub said this caller administers
    to the ones still linked to no tenant. The id list is the caller's own proof, so this is a
    lookup, not a browse. *)
val list_claimable :
  github_installation_ids:int list ->
  Pgsql_io.t ->
  (installation list, [> Pgsql_io.err ]) result Abb.Future.t

(** [list_claimable_by_core_ids ~installation_core_ids db] is the same narrowing keyed by the core
    ids a proof names, so a listing and the claim that follows it talk about the same identifiers.
    Re-checks the link table: another tenant may have claimed one since the proof was minted. *)
val list_claimable_by_core_ids :
  installation_core_ids:Uuidm.t list ->
  Pgsql_io.t ->
  (installation list, [> Pgsql_io.err ]) result Abb.Future.t
