(** The authentication service: sign-in (OAuth2 through oauth2-proxy, or password), sign-out, the
    session cookie, and who is signed in. It runs oauth2-proxy when OAuth is configured, from its
    start to its stop, and serves the session storage oauth2-proxy calls back into. Every edition
    runs it. [Make] takes the Cloud abstraction, which a first sign-in reports to. *)

module Make (_ : Sgs_cloud.S) : Sgs_service.S
