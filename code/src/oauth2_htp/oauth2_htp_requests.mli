(** The HTTP client every call to the IdP goes through. *)

type err =
  [ Abb_curl.Make(Abb).request_err
  | `Unexpected_status of int * string
  | `Json_err of string
  ]
[@@deriving show]

module Result : sig
  type t

  val status_code : t -> int
  val body : t -> string

  (** Parse the body as JSON. The response must have a 200 status, otherwise an error is returned.
  *)
  val unmarshal : t -> (Yojson.Safe.t, [> err ]) result
end

(** Request [endpoint]: a POST of [body] when one is given, a GET otherwise. A request that has not
    completed after 30 seconds fails. *)
val do_ :
  ?headers:(string * string) list ->
  ?body:string ->
  string ->
  (Result.t, [> err ]) result Abb.Future.t

(** {!do_} followed by {!Result.unmarshal}. *)
val unmarshal :
  ?headers:(string * string) list ->
  ?body:string ->
  string ->
  (Yojson.Safe.t, [> err ]) result Abb.Future.t

(** POST [params] as an [application/x-www-form-urlencoded] body and parse the JSON response, as a
    token endpoint is called. *)
val post_form :
  ?headers:(string * string) list ->
  string ->
  Oauth2_htp_values.t ->
  (Yojson.Safe.t, [> err ]) result Abb.Future.t
