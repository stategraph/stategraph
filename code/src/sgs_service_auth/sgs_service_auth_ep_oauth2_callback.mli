(** OAuth2 Callback Handler

    GET /oauth2/\{provider\}/callback - The provider redirects here after the user signs in. It
    creates/finds the user in StateGraph, generates a session cookie and redirects to the
    destination the sign-in started with. *)

module Make (_ : Sgs_cloud.S) : sig
  (** Run the OAuth2 callback handler. The provider in the path is ignored: users are signed in with
      the configured provider's name as their auth_origin. *)
  val run :
    Sgs_config.t -> Sgs_storage.t -> Sgs_service_oauth2.Provider.t -> string -> Brtl_rtng.Handler.t
end
