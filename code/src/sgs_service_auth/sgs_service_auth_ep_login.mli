(** Login Endpoint

    Initiates the OAuth2 login flow. *)

(** GET /api/v1/login/options - List available OAuth providers *)
val options : Sgs_config.t -> Brtl_rtng.Handler.t

(** GET /api/v1/login/\{provider\} - Initiate OAuth2 login [provider] is the OAuth provider name.
    [rd] is the redirect destination after login (defaults to "/"). A [screen_hint] that
    {!Oauth2_htp.screen_hint} accepts is passed on to the OAuth2 start. *)
val run :
  Sgs_config.t ->
  Sgs_service_oauth2.Provider.t option ->
  string ->
  string option ->
  string option ->
  Brtl_rtng.Handler.t

(** GET /api/v1/logout - Clear session and redirect [rd] is the redirect destination after logout
    (defaults to "/login?prompt=1", the login page without the automatic forward to the IdP) *)
val logout : Sgs_config.t -> string option -> Brtl_rtng.Handler.t
