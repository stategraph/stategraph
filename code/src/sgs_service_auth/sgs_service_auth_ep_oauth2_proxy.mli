(** OAuth2 Proxy Endpoint

    This endpoint proxies requests to the oauth2-proxy instance. *)

(** Run the proxy endpoint, forwarding the request to oauth2-proxy. [provider] is the OAuth provider
    name from the URL (currently unused when proxying). [endpoint] is the endpoint name (e.g.,
    "start", "callback"). *)
val run : provider:string -> Sgs_service_auth_oauth2_proxy.t -> string -> Brtl_rtng.Handler.t
