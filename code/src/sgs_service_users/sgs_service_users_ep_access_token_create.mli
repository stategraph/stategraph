(** Access Token Create Endpoint

    Creates a personal API access token for the authenticated user. *)

(** POST /api/v1/user/access-tokens - Create a personal API token *)
val run :
  Sgs_config.t ->
  Sgs_storage.t ->
  Sgs_api_components_access_token_create_request.t ->
  Brtl_rtng.Handler.t
