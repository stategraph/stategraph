(** GET /oauth2/\{provider\}/start - Send the browser to the provider's sign-in page. The [rd] query
    parameter is where the browser lands after sign-in. *)
val run : Sgs_service_oauth2.Provider.t -> string -> Brtl_rtng.Handler.t
