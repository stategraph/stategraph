(** The authentication service: sign-in (OAuth2 or password), sign-out, the session cookie, and who
    is signed in. It serves the OAuth2 sign-in flow with the provider of {!Sgs_service_oauth2},
    which it finds through the service manager. Every edition runs it. [Make] takes the Cloud
    abstraction, which a first sign-in reports to. *)

module Make (_ : Sgs_cloud.S) : Sgs_service.S with type opt = Sgs_svc_mngr.t
