(** Handles [GET /api/v1/capabilities]: what this server offers, as a single record the console
    reads once to decide which surfaces to show.

    [costs], [security] and [dedicated] carry [enabled], from [STATEGRAPH_COST_ENABLED],
    [STATEGRAPH_SECURITY] and [STATEGRAPH_DEDICATED_ENABLED]. [github_app_url] is the GitHub App
    install URL, absent when none is configured, which the getting-started wizard turns into an
    install link.

    Auth-gated. Every field is read from configuration, so answering costs no round-trip to the
    services being described. *)
val run : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t
