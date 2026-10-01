(** PUT /api/v1/setup/github-app/credentials: replace the stored App's private key, OAuth client
    secret or webhook secret with the ones the operator rotated on GitHub, which shows each of them
    one time only. The orchestration engine restarts on them. Instance admin only. *)

val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_api_components_github_app_credentials_request.t ->
  Brtl_rtng.Handler.t
