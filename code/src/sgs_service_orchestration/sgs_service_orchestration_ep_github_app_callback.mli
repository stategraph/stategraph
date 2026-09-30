(** GET /api/v1/setup/github-app/callback: GitHub's return after the App is created from the
    manifest. Converts the code, stores the App, and redirects to the console getting-started page
    with [github_app] set to [created], [expired], [exists] or [error]. *)

val run : Sgs_config.t -> Sgs_storage.t -> string option -> string option -> Brtl_rtng.Handler.t
