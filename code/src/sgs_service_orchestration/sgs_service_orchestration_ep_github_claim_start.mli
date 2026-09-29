(** GET /api/v1/tenants/{tenant_id}/vcs-installations/github/claim/start

    Begins the GitHub identity handshake so a tenant admin can claim an installation they
    administer, without the instance-admin grant the staff path requires (#1795). Redirects the
    browser to GitHub's authorization screen with a signed state binding the handshake to this user
    and tenant.

    The console reaches this by full-page navigation, so a claim that cannot start sends the browser
    back to [rd] with a [github_claim] result instead of an API error: [unavailable] when
    orchestration is disabled or no GitHub OAuth client is configured, [not_member] when the caller
    is not a member of the tenant, and [error] for a database or signing-key fault. Only the
    capability check still answers [401] or [403].

    [rd] is where the console is returned to once GitHub answers: a site-relative path, or an
    absolute URL on the console's own origin. Any other value is ignored, and the getting-started
    page is used instead. *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_tenant.minted Sgs_tenant.t ->
  string option ->
  Brtl_rtng.Handler.t
