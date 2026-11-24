(** Users List Endpoint

    Lists users with cursor-based pagination and optional filtering. Requires admin privileges. *)

(** GET /api/v1/users - List users with cursor-based pagination *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_api_components.User_type.t option ->
  string option ->
  string option ->
  int ->
  Brtl_rtng.Handler.t
