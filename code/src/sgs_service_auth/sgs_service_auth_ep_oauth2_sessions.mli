(** OAuth2 Session Storage Endpoints

    These endpoints implement the HTTP session storage API for oauth2-proxy. They allow oauth2-proxy
    to store, retrieve, and delete session data during the OAuth flow.

    Endpoints:
    - [PUT /internal/oauth2-sessions/{namespace}/sessions/{key}]
    - [GET /internal/oauth2-sessions/{namespace}/sessions/{key}]
    - [DELETE /internal/oauth2-sessions/{namespace}/sessions/{key}]
    - [GET /internal/oauth2-sessions/{namespace}/health] *)

module Put_request : sig
  type t = {
    data : string;
    ttl_seconds : int;
  }

  val of_yojson : Yojson.Safe.t -> (t, string) result
end

module Put : sig
  val run : Sgs_config.t -> Pgsql_pool.t -> string -> string -> Put_request.t -> Brtl_rtng.Handler.t
end

module Get : sig
  val run : Sgs_config.t -> Pgsql_pool.t -> string -> string -> Brtl_rtng.Handler.t
end

module Delete : sig
  val run : Sgs_config.t -> Pgsql_pool.t -> string -> string -> Brtl_rtng.Handler.t
end

module Health : sig
  val run : Sgs_config.t -> Pgsql_pool.t -> string -> Brtl_rtng.Handler.t
end
