(** The CSRF cookie: it binds the [state] of a sign-in to the browser that started it. The cookie
    carries a random nonce, encrypted and signed with the cookie secret; the [state] sent to the IdP
    carries its hash. *)

type err =
  [ Oauth2_htp_encryption.err
  | `Cookie_not_found
  | `Cookie_failed_validation
  | `Malformed_cookie of string
  ]
[@@deriving show]

type t

val cookie_name : string

(** A fresh CSRF with a random nonce. *)
val create : unit -> t

(** The hashed nonce, for the [state] parameter. *)
val hashed_state : t -> string

(** Whether [hashed] is this CSRF's {!hashed_state}. *)
val check_state : t -> string -> bool

val set_cookie :
  now:float -> secret:string -> secure:bool -> t -> (Oauth2_htp_cookie.t, [> err ]) result

(** The CSRF from the request's cookie, which must have been set in the last 15 minutes. *)
val load : now:float -> secret:string -> Oauth2_htp_request.t -> (t, [> err ]) result

(** A cookie that expires the CSRF cookie. *)
val clear : secure:bool -> Oauth2_htp_cookie.t
