(** OAuth2 Callback Handler

    This endpoint is called after oauth2-proxy successfully authenticates a user. It creates/finds
    the user in StateGraph and generates a session cookie. *)

module Make (_ : Sgs_cloud.S) : sig
  (** Run the OAuth2 callback handler. [provider] is the OAuth provider name used as auth_origin.
      [rd] is the redirect destination after login (defaults to "/"). *)
  val run :
    Sgs_config.t ->
    Sgs_storage.t ->
    Sgs_service_auth_oauth2_proxy.t ->
    string ->
    string option ->
    Brtl_rtng.Handler.t
end
