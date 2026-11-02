(** The encryption the CSRF cookie uses: AES-CFB, and the signed cookie value format. *)

type err =
  [ `Invalid_key_size of int
  | `Ciphertext_too_short of int
  ]
[@@deriving show]

(** The AES key a cookie secret stands for: the secret base64 decoded when that gives 16, 24 or 32
    bytes, the secret itself otherwise. *)
val secret_bytes : string -> string

(** Encrypt with AES-CFB under [secret_bytes secret], a random IV first. *)
val encrypt : secret:string -> string -> (string, [> err ]) result

val decrypt : secret:string -> string -> (string, [> err ]) result

(** [length] random bytes. *)
val nonce : int -> string

(** The URL-safe base64 SHA-256 of a nonce, which is what leaves the server. *)
val hash_nonce : string -> string

(** Whether [hashed] is the hash of [nonce], in constant time. *)
val check_nonce : string -> string -> bool

(** [value], timestamped with [now] and signed with an HMAC-SHA256 keyed by [seed] over [key], the
    value and the timestamp: [<base64 value>|<timestamp>|<signature>]. *)
val signed_value : seed:string -> key:string -> value:string -> now:float -> string

(** The value and timestamp of a {!signed_value} whose signature holds and whose timestamp falls in
    [(now - expiration, now + 5 minutes)]. *)
val validate :
  name:string ->
  value:string ->
  seed:string ->
  expiration:Duration.t ->
  now:float ->
  (string * float) option
