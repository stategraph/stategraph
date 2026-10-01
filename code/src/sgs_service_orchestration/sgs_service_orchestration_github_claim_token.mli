(** Signed, short-lived tokens for the GitHub identity claim flow (#1795).

    Both tokens are JWTs signed RS256 with the session signing key and verified against every RSA
    key that still verifies sessions, so forging one is as hard as forging a session, and a key
    rotation affects them exactly as it affects sessions. Each kind of token holds its payload under
    a claim of its own, so a state token, a proof token and a session JWT are never accepted in
    place of one another. Everything here is pure: [~now] is a parameter, so expiry is testable
    without waiting. *)

(** Why a token was refused. [`Malformed_err]: it is not a JWT. [`Bad_signature_err]: no verifier
    accepts its signature, which includes a token signed under another algorithm.
    [`Bad_payload_err]: it is signed but does not hold this kind of token's payload. [`Expired_err]:
    its expiry is before [now]. *)
type verify_err =
  [ `Malformed_err
  | `Bad_signature_err
  | `Bad_payload_err
  | `Expired_err
  ]
[@@deriving show]

(** Seconds a state token stays valid: one trip through GitHub's consent screen. *)
val state_ttl : float

(** Seconds a proof token stays valid: long enough to pick an installation on the return screen. *)
val proof_ttl : float

(** Seconds a manifest state stays valid: the hour GitHub keeps the code of a created App. *)
val manifest_ttl : float

(** The OAuth [state] parameter. Binds the handshake to the user and tenant that started it, so the
    callback takes neither from the query string. *)
module State : sig
  type t = {
    user_id : string;
    tenant_id : string;
    rd : string option;
    exp : float;
  }

  val mint :
    signer:Jwt.Signer.t ->
    now:float ->
    user_id:string ->
    tenant_id:string ->
    rd:string option ->
    unit ->
    string

  val verify : verifiers:Jwt.Verifier.t list -> now:float -> string -> (t, [> verify_err ]) result
end

(** The callback's assertion that this user proved administrative control of these installations at
    this instant. The claim endpoint accepts it in place of an instance-admin grant. *)
module Proof : sig
  type t = {
    user_id : string;
    tenant_id : string;
    installation_core_ids : string list;
    exp : float;
  }

  val mint :
    signer:Jwt.Signer.t ->
    now:float ->
    user_id:string ->
    tenant_id:string ->
    installation_core_ids:string list ->
    unit ->
    string

  val verify : verifiers:Jwt.Verifier.t list -> now:float -> string -> (t, [> verify_err ]) result

  (** [covers t ~installation_core_id] is [`Covered] when the proof names that installation. The
      token proves control of a set, not of whatever a request asks for, so check this before
      writing. *)
  val covers : t -> installation_core_id:string -> [ `Covered | `Not_covered ]
end

(** The [state] of the GitHub App manifest flow. Binds the code GitHub returns to the instance admin
    who asked for the manifest. *)
module Manifest : sig
  type t = {
    user_id : string;
    replace : bool;  (** the operator asked to replace an App this server already has *)
    rd : string option;  (** the console page to return to *)
    exp : float;
  }

  val mint :
    signer:Jwt.Signer.t ->
    now:float ->
    user_id:string ->
    replace:bool ->
    rd:string option ->
    unit ->
    string

  val verify : verifiers:Jwt.Verifier.t list -> now:float -> string -> (t, [> verify_err ]) result
end
