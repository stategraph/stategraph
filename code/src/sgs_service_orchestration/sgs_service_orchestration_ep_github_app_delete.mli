(** DELETE /api/v1/setup/github-app: remove the stored GitHub App, so the orchestration engine
    restarts with no GitHub service. Takes the App's id as confirmation, because this destroys the
    only copy of its private key. Instance admin only. *)

val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_api_components_github_app_delete_request.t ->
  Brtl_rtng.Handler.t
