(** API User Create Endpoint

    Creates a service account (API user) with an access token. *)

(** POST /api/v1/api-users - Create a service account *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_api_components_api_user_create_request.t ->
  Brtl_rtng.Handler.t
