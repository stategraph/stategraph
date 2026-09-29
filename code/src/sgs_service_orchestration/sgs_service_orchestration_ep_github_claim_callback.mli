(** GET /api/v1/vcs-installations/github/claim/callback

    Where GitHub returns the user after they authorize (#1795). Verifies the signed state, proves
    which installations the caller administers, sets a short-lived proof cookie, and redirects back
    to the console with a [github_claim] result. Deliberately links nothing: the write happens on an
    explicit request, so a link a user never chose cannot be forced by a navigation.

    Both query parameters are optional. GitHub lands the user here after an app installation as
    well, carrying [installation_id] and [setup_action] but no state; that navigation is redirected
    back to the claim screen instead of 404ing, and any code riding along is ignored, since without
    a state it is bound to no user or tenant. *)
val run : Sgs_config.t -> Sgs_storage.t -> string option -> string option -> Brtl_rtng.Handler.t
