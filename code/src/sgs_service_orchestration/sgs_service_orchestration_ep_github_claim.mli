(** POST /api/v1/tenants/{tenant_id}/vcs-installations/github/claim

    Links an installation the caller proved control of to this tenant (#1795). Requires the proof
    cookie, refuses installations the proof does not name (403), and refuses installations linked to
    another tenant (409): a self-serve claim may create a link, never move one. An installation this
    tenant already holds answers 200 with its link, so a retried or doubled claim is not reported as
    lost. *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_tenant.minted Sgs_tenant.t ->
  Sgs_api_components.Github_claim_request.t ->
  Brtl_rtng.Handler.t
