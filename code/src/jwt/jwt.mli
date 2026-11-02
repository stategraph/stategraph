(** Implement parsing and verifying JSON Web Tokens (JWTs). A JWT starts out as a string, then is
    decoded, and from there it can be verified against the correct verifier, at which point it
    becomes verified. *)

(** Used to verify the signature of a JWT. *)
module Verifier : sig
  module Pub_key : sig
    type t

    (** [e] and [n] are encoded as they would show up in a JWK. *)
    val create : e:string -> n:string -> t option

    val of_pub_key : Mirage_crypto_pk.Rsa.pub -> t
  end

  (** An elliptic-curve or Edwards-curve public key. *)
  module Ec_pub_key : sig
    type t

    (** [crv] is the JWK curve: [P-256], [P-384], [P-521] or [Ed25519]. [x] and [y] are encoded as
        they would show up in a JWK; [Ed25519] has no [y]. *)
    val create : crv:string -> x:string -> y:string option -> t option
  end

  (** An [ES*] verifier only verifies with a key on its curve: [P-256], [P-384] and [P-521] for
      [ES256], [ES384] and [ES512]. [EdDSA] verifies with an [Ed25519] key. *)
  type t =
    | HS256 of string
    | HS512 of string
    | RS256 of Pub_key.t
    | RS384 of Pub_key.t
    | RS512 of Pub_key.t
    | PS256 of Pub_key.t
    | PS384 of Pub_key.t
    | PS512 of Pub_key.t
    | ES256 of Ec_pub_key.t
    | ES384 of Ec_pub_key.t
    | ES512 of Ec_pub_key.t
    | EdDSA of Ec_pub_key.t

  val to_string : t -> string
end

(** Sign a JWT *)
module Signer : sig
  module Priv_key : sig
    type t

    val of_priv_key : Mirage_crypto_pk.Rsa.priv -> t
  end

  type t =
    | HS256 of string
    | HS512 of string
    | RS256 of Priv_key.t

  val to_string : t -> string
end

module Header : sig
  type t

  (** Create a header with the algorithm and type *)
  val create : ?rest:(string * string) list -> ?typ:string -> string -> t

  (** [algorithm t] is the ["alg"] value, or [None] when the header carries none. A header arrives
      on an unauthenticated path, so the lookup has to be total. *)
  val algorithm : t -> string option

  val typ : t -> string
  val get : string -> t -> string option
  val to_string : t -> string
  val to_json : t -> Yojson.Safe.t
  val of_string : string -> t option
  val of_json : Yojson.Safe.t -> t option
end

module Claim : sig
  type t = string

  val iss : t
  val sub : t
  val aud : t
  val exp : t
  val nbf : t
  val iat : t
  val jti : t
  val ctyp : t
  val auth_time : t
  val nonce : t
  val acr : t
  val amr : t
  val azp : t
end

module Payload : sig
  type typs = Yojson.Safe.t
  type t

  val empty : t
  val add_claim : Claim.t -> typs -> t -> t
  val find_claim : Claim.t -> t -> typs option
  val find_claim_string : Claim.t -> t -> string option
  val find_claim_bool : Claim.t -> t -> bool option
  val find_claim_float : Claim.t -> t -> float option
  val find_claim_int : Claim.t -> t -> int option
  val of_json : Yojson.Safe.t -> t option
  val to_json : t -> Yojson.Safe.t
  val to_string : t -> string
  val of_string : string -> t option
end

(** A decoded JWT has just been successfully parsed. *)
type decoded

(** A verified JWT means that the signature has been verified against the content. *)
type verified

type 'a t

(** Create a verified token. This may throw an exception if the random number generator has not been
    initialized. To initialize it, run [Mirage_crypto_rng_unix.initialize] or
    [Mirage_crypto_rng_lwt.initialize] *)
val of_header_and_payload : Signer.t -> Header.t -> Payload.t -> verified t

val header : 'a t -> Header.t
val payload : 'a t -> Payload.t
val signature : verified t -> string

(** Convert the JWT into the string representation. Only a verified token can be converted to a
    string. *)
val token : verified t -> string

(** Convert a string representing a JWT into a decoded, but unverified, value. This can further be
    verified using {!verify}. *)
val of_token : string -> decoded t option

(** Verify a decoded JWT against a particular verifier. The alg in the JWT must match that of the
    verifier. This is verified against the un-parse JWT. *)
val verify : Verifier.t -> decoded t -> verified t option
