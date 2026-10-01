module Payload = struct
  module State = struct
    type t = {
      user_id : string;
      tenant_id : string;
      rd : string option; [@default None]
      exp : float;
    }
    [@@deriving yojson { strict = false }]
  end

  module Manifest = struct
    type t = {
      user_id : string;
      (* Whether the operator asked to replace an App this server already has.
         The callback is what writes, so the permission travels with the
         state rather than being re-read from a request it cannot see. *)
      replace : bool; [@default false]
      rd : string option; [@default None]
      exp : float;
    }
    [@@deriving yojson { strict = false }]
  end

  (* The proof lives in a token rather than a table, so it cannot outlive its expiry, and there is
     no row to forge or to garbage-collect. *)
  module Proof = struct
    type t = {
      user_id : string;
      tenant_id : string;
      (* Installation core ids (the stategraph-side uuid), not GitHub's numeric
         installation id: the claim writes core ids and must compare what it
         writes. *)
      installation_core_ids : string list;
      exp : float;
    }
    [@@deriving yojson { strict = false }]
  end
end

type verify_err =
  [ `Malformed_err
  | `Bad_signature_err
  | `Bad_payload_err
  | `Expired_err
  ]
[@@deriving show]

(* A handshake is a round trip through GitHub's consent screen; five minutes is
   generous for that and short enough that a leaked redirect is inert by the
   time it is found in a log. *)
let state_ttl = 300.

(* The proof is spent by a claim the user makes immediately after returning, but
   they may pause on the pick screen. Fifteen minutes keeps that from becoming a
   dead end without letting a stale verdict linger. *)
let proof_ttl = 900.

(* GitHub keeps the code of a created App for one hour, and the operator may
   take that long on GitHub's form. *)
let manifest_ttl = 3600.

(* The session signs these tokens and its own JWTs with the same key. The claim
   name is what tells them apart: a session JWT holds its payload under
   "stategraph". *)
let state_claim = "stategraph_github_claim_state"
let proof_claim = "stategraph_github_claim_proof"
let manifest_claim = "stategraph_github_app_manifest"

let mint ~signer ~claim json =
  Sgs_user_session.Session.sign_token ~signer (Jwt.Payload.add_claim claim json Jwt.Payload.empty)

let verify ~verifiers ~now ~claim ~of_yojson ~exp token =
  let open CCResult.Infix in
  Sgs_user_session.Session.verify_token ~verifiers token
  >>= fun payload ->
  match CCOption.map of_yojson (Jwt.Payload.find_claim claim payload) with
  | Some (Ok v) when exp v < now -> Error `Expired_err
  | Some (Ok v) -> Ok v
  | Some (Error _) | None -> Error `Bad_payload_err

module State = struct
  type t = Payload.State.t = {
    user_id : string;
    tenant_id : string;
    rd : string option;
    exp : float;
  }

  let mint ~signer ~now ~user_id ~tenant_id ~rd () =
    mint
      ~signer
      ~claim:state_claim
      (Payload.State.to_yojson { Payload.State.user_id; tenant_id; rd; exp = now +. state_ttl })

  let verify ~verifiers ~now token =
    verify
      ~verifiers
      ~now
      ~claim:state_claim
      ~of_yojson:Payload.State.of_yojson
      ~exp:(fun { Payload.State.user_id = _; tenant_id = _; rd = _; exp } -> exp)
      token
end

module Proof = struct
  type t = Payload.Proof.t = {
    user_id : string;
    tenant_id : string;
    installation_core_ids : string list;
    exp : float;
  }

  let mint ~signer ~now ~user_id ~tenant_id ~installation_core_ids () =
    mint
      ~signer
      ~claim:proof_claim
      (Payload.Proof.to_yojson
         { Payload.Proof.user_id; tenant_id; installation_core_ids; exp = now +. proof_ttl })

  let verify ~verifiers ~now token =
    verify
      ~verifiers
      ~now
      ~claim:proof_claim
      ~of_yojson:Payload.Proof.of_yojson
      ~exp:(fun { Payload.Proof.user_id = _; tenant_id = _; installation_core_ids = _; exp } -> exp)
      token

  let covers { user_id = _; tenant_id = _; installation_core_ids; exp = _ } ~installation_core_id =
    if CCList.mem ~eq:CCString.equal installation_core_id installation_core_ids then `Covered
    else `Not_covered
end

module Manifest = struct
  type t = Payload.Manifest.t = {
    user_id : string;
    replace : bool;
    rd : string option;
    exp : float;
  }

  let mint ~signer ~now ~user_id ~replace ~rd () =
    mint
      ~signer
      ~claim:manifest_claim
      (Payload.Manifest.to_yojson
         { Payload.Manifest.user_id; replace; rd; exp = now +. manifest_ttl })

  let verify ~verifiers ~now token =
    verify
      ~verifiers
      ~now
      ~claim:manifest_claim
      ~of_yojson:Payload.Manifest.of_yojson
      ~exp:(fun { Payload.Manifest.user_id = _; replace = _; rd = _; exp } -> exp)
      token
end
