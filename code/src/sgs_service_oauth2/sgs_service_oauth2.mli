(** The OAuth2 sign-in service: the Google or OIDC provider in {!Sgs_config.oauth2}, set up at
    start.

    Without an OAuth configuration the service starts with no provider. An OAuth configuration that
    is not valid refuses with [`Start_fatal_err]. A setup that fails at the provider, such as an
    unreachable OIDC issuer or a Google service account the Admin SDK refuses, refuses with
    [`Start_err], so the manager retries it.

    The service adds no routes. *)

module Provider = Sgs_service_oauth2_provider
include Sgs_service.S with type opt = Sgs_svc_mngr.t

(** Names this service in a match on {!Sgs_service.ty}. *)
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

(** The configured provider, or [None] without an OAuth configuration. *)
val provider : t -> Provider.t option
