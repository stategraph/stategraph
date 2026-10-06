(** Password Login Endpoint

    Authenticates users with email and password when OAuth is not configured. *)

(** POST /api/v1/login/password - Authenticate with email/password *)
val run : Sgs_config.t -> Sgs_storage.t -> Brtl_rtng.Handler.t
