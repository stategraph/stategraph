(** POST /api/v1/setup/github-app/manifest: the GitHub App manifest of this deployment and the form
    the console posts to GitHub. Instance admin only. *)

val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_api_components_github_app_manifest_request.t ->
  Brtl_rtng.Handler.t
