module Token = Sgs_service_orchestration_github_claim_token

let () = Mirage_crypto_rng_unix.use_default ()

(* [signing_key] stands for the session signing key, [other_key] for a key the
   installation does not hold, or no longer verifies with. *)
let signing_key = Mirage_crypto_pk.Rsa.generate ~bits:2048 ()
let other_key = Mirage_crypto_pk.Rsa.generate ~bits:2048 ()
let signer_of key = Jwt.Signer.RS256 (Jwt.Signer.Priv_key.of_priv_key key)

let verifier_of key =
  Jwt.Verifier.RS256 (Jwt.Verifier.Pub_key.of_pub_key (Mirage_crypto_pk.Rsa.pub_of_priv key))

let signer = signer_of signing_key
let verifiers = [ verifier_of signing_key ]
let now = 1_000_000.

let state_token ?(user_id = "u-1") ?(tenant_id = "t-1") ?(rd = None) ?(now = now) () =
  Token.State.mint ~signer ~now ~user_id ~tenant_id ~rd ()

let proof_token
    ?(signer = signer)
    ?(user_id = "u-1")
    ?(tenant_id = "t-1")
    ?(ids = [ "i-1" ])
    ?(now = now)
    () =
  Token.Proof.mint ~signer ~now ~user_id ~tenant_id ~installation_core_ids:ids ()

let covered proof installation_core_id =
  match Token.Proof.covers proof ~installation_core_id with
  | `Covered -> true
  | `Not_covered -> false

let expect_err ~name expected = function
  | Ok _ -> Oth.Assert.false_ (name ^ ": token verified")
  | Error err ->
      Oth.Assert.Eq.string
        ~expected:(Token.show_verify_err expected)
        ~actual:(Token.show_verify_err err)

let b64_encode = Base64.encode_string ~alphabet:Base64.uri_safe_alphabet ~pad:false
let b64_decode s = CCResult.get_exn (Base64.decode ~alphabet:Base64.uri_safe_alphabet ~pad:false s)

let test_state_round_trip =
  Oth.test ~name:"state token round trips" (fun _ ->
      let { Token.State.user_id; tenant_id; rd; exp } =
        Oth.Assert.ok_pp
          ~pp:Token.pp_verify_err
          (Token.State.verify ~verifiers ~now (state_token ~rd:(Some "/getting-started") ()))
      in
      Oth.Assert.Eq.string ~expected:"u-1" ~actual:user_id;
      Oth.Assert.Eq.string ~expected:"t-1" ~actual:tenant_id;
      Oth.Assert.Eq.string_option ~expected:(Some "/getting-started") ~actual:rd;
      Oth.Assert.true_ (CCFloat.equal exp (now +. Token.state_ttl)))

let test_proof_round_trip =
  Oth.test ~name:"proof token round trips" (fun _ ->
      let ({ Token.Proof.user_id; tenant_id; installation_core_ids; exp = _ } as proof) =
        Oth.Assert.ok_pp
          ~pp:Token.pp_verify_err
          (Token.Proof.verify ~verifiers ~now (proof_token ~ids:[ "i-1"; "i-2" ] ()))
      in
      Oth.Assert.Eq.string ~expected:"u-1" ~actual:user_id;
      Oth.Assert.Eq.string ~expected:"t-1" ~actual:tenant_id;
      Oth.Assert.Eq.string_list ~expected:[ "i-1"; "i-2" ] ~actual:installation_core_ids;
      Oth.Assert.true_ (covered proof "i-2");
      Oth.Assert.not_true (covered proof "i-3"))

(* The whole point of the signature: a user cannot widen their own proof. *)
let test_tampered_payload_rejected =
  Oth.test ~name:"tampered payload is rejected" (fun _ ->
      match CCString.split_on_char '.' (proof_token ~ids:[ "i-1" ] ()) with
      | [ header_b64; payload_b64; signature_b64 ] ->
          let payload = b64_decode payload_b64 in
          let forged_payload = CCString.replace ~sub:"\"i-1\"" ~by:"\"i-1\",\"i-9\"" payload in
          Oth.Assert.true_ (not (CCString.equal forged_payload payload));
          expect_err
            ~name:"forged payload"
            `Bad_signature_err
            (Token.Proof.verify
               ~verifiers
               ~now
               (CCString.concat "." [ header_b64; b64_encode forged_payload; signature_b64 ]))
      | _ -> Oth.Assert.false_ "token was not header.payload.signature")

let test_wrong_key_rejected =
  Oth.test ~name:"a token signed with another key is rejected" (fun _ ->
      expect_err
        ~name:"foreign signature"
        `Bad_signature_err
        (Token.Proof.verify ~verifiers ~now (proof_token ~signer:(signer_of other_key) ())))

(* The tokens verify against the whole verifying set, as sessions do: a token
   signed by a key that no longer signs still verifies while that key verifies,
   and stops once the key is gone. *)
let test_key_rotation =
  Oth.test ~name:"a token outlives a rotation only while its key still verifies" (fun _ ->
      let token = proof_token ~signer:(signer_of other_key) () in
      ignore
        (Oth.Assert.ok_pp
           ~pp:Token.pp_verify_err
           (Token.Proof.verify
              ~verifiers:[ verifier_of signing_key; verifier_of other_key ]
              ~now
              token));
      expect_err ~name:"retired key" `Bad_signature_err (Token.Proof.verify ~verifiers ~now token))

let test_expiry =
  Oth.test ~name:"tokens expire" (fun _ ->
      let state = state_token () in
      let proof = proof_token () in
      ignore
        (Oth.Assert.ok_pp
           ~pp:Token.pp_verify_err
           (Token.State.verify ~verifiers ~now:(now +. Token.state_ttl -. 1.) state));
      expect_err
        ~name:"state just after expiry"
        `Expired_err
        (Token.State.verify ~verifiers ~now:(now +. Token.state_ttl +. 1.) state);
      ignore
        (Oth.Assert.ok_pp
           ~pp:Token.pp_verify_err
           (Token.Proof.verify ~verifiers ~now:(now +. Token.proof_ttl -. 1.) proof));
      expect_err
        ~name:"proof just after expiry"
        `Expired_err
        (Token.Proof.verify ~verifiers ~now:(now +. Token.proof_ttl +. 1.) proof))

let test_malformed =
  Oth.test ~name:"malformed tokens are rejected" (fun _ ->
      CCList.iter
        (fun token ->
          expect_err
            ~name:(Printf.sprintf "%S" token)
            `Malformed_err
            (Token.Proof.verify ~verifiers ~now token))
        [ ""; "nodot"; "a.b"; "a.b.c"; "!!!.!!!.!!!" ])

(* A state token is not a proof token: their payloads live under different
   claims, so one must not be accepted where the other is expected even though
   both are signed with the same key. *)
let test_tokens_are_not_interchangeable =
  Oth.test ~name:"a state token is not a proof token" (fun _ ->
      expect_err
        ~name:"state as proof"
        `Bad_payload_err
        (Token.Proof.verify ~verifiers ~now (state_token ()));
      expect_err
        ~name:"proof as state"
        `Bad_payload_err
        (Token.State.verify ~verifiers ~now (proof_token ())))

(* Session JWTs are signed with the same key, so a good signature does not make
   a token a claim token; the claim it holds does. *)
let test_session_jwt_is_not_a_claim_token =
  Oth.test ~name:"a session-shaped JWT from the same key is rejected" (fun _ ->
      let header = Jwt.Header.create (Jwt.Signer.to_string signer) in
      let payload =
        Jwt.Payload.add_claim "stategraph" (`Assoc [ ("user_id", `String "u-1") ]) Jwt.Payload.empty
      in
      let token = Jwt.token (Jwt.of_header_and_payload signer header payload) in
      expect_err
        ~name:"session as proof"
        `Bad_payload_err
        (Token.Proof.verify ~verifiers ~now token);
      expect_err
        ~name:"session as state"
        `Bad_payload_err
        (Token.State.verify ~verifiers ~now token))

let test_empty_proof_covers_nothing =
  Oth.test ~name:"a proof over no installations covers nothing" (fun _ ->
      let proof =
        Oth.Assert.ok_pp
          ~pp:Token.pp_verify_err
          (Token.Proof.verify ~verifiers ~now (proof_token ~ids:[] ()))
      in
      Oth.Assert.not_true (covered proof "i-1"))

let manifest_token ?(signer = signer) ?(user_id = "u-1") ?(now = now) () =
  Token.Manifest.mint ~signer ~now ~user_id ()

let test_manifest_round_trip =
  Oth.test ~name:"manifest state round trips" (fun _ ->
      let { Token.Manifest.user_id; exp } =
        Oth.Assert.ok_pp
          ~pp:Token.pp_verify_err
          (Token.Manifest.verify ~verifiers ~now (manifest_token ()))
      in
      Oth.Assert.Eq.string ~expected:"u-1" ~actual:user_id;
      Oth.Assert.true_ (CCFloat.equal exp (now +. Token.manifest_ttl));
      expect_err
        ~name:"manifest just after expiry"
        `Expired_err
        (Token.Manifest.verify
           ~verifiers
           ~now:(now +. Token.manifest_ttl +. 1.)
           (manifest_token ()));
      expect_err
        ~name:"manifest with a foreign signature"
        `Bad_signature_err
        (Token.Manifest.verify ~verifiers ~now (manifest_token ~signer:(signer_of other_key) ())))

let test_manifest_not_interchangeable =
  Oth.test ~name:"a manifest state is not a claim state, nor the reverse" (fun _ ->
      expect_err
        ~name:"manifest as claim state"
        `Bad_payload_err
        (Token.State.verify ~verifiers ~now (manifest_token ()));
      expect_err
        ~name:"claim state as manifest"
        `Bad_payload_err
        (Token.Manifest.verify ~verifiers ~now (state_token ())))

let test =
  Oth.parallel
    [
      test_state_round_trip;
      test_proof_round_trip;
      test_tampered_payload_rejected;
      test_wrong_key_rejected;
      test_key_rotation;
      test_expiry;
      test_malformed;
      test_tokens_are_not_interchangeable;
      test_session_jwt_is_not_a_claim_token;
      test_empty_proof_covers_nothing;
      test_manifest_round_trip;
      test_manifest_not_interchangeable;
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
