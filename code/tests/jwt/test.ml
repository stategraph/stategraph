let jwt =
  "eyJhbGciOiJSUzI1NiIsImtpZCI6IjdkNjgwZDhjNzBkNDRlOTQ3MTMzY2JkNDk5ZWJjMWE2MWMzZDVhYmMiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJhY2NvdW50cy5nb29nbGUuY29tIiwiYXpwIjoiMTA1MDg3NTI2ODYwNi05ZmlnMGdpYjBxaDM4ZmZyZ3Y4bTFyamZtZHFqc2NpaS5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsImF1ZCI6IjEwNTA4NzUyNjg2MDYtOWZpZzBnaWIwcWgzOGZmcmd2OG0xcmpmbWRxanNjaWkuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDU5MjUyNDQ3OTczNTMxOTg4NDMiLCJlbWFpbCI6Im1tYXRhbGthQGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJhdF9oYXNoIjoidnF0eExPUXNNMDRKcDBxMmxjQmU1dyIsIm5hbWUiOiJNYWxjb2xtIE1hbHVya2EiLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDUuZ29vZ2xldXNlcmNvbnRlbnQuY29tLy1tM0hHRm8xQnk0by9BQUFBQUFBQUFBSS9BQUFBQUFBQUFFMC9pS1p0UThtTXMzQS9zOTYtYy9waG90by5qcGciLCJnaXZlbl9uYW1lIjoiTWFsY29sbSIsImZhbWlseV9uYW1lIjoiTWFsdXJrYSIsImxvY2FsZSI6ImVuLUdCIiwiaWF0IjoxNTUwNTE0MTIyLCJleHAiOjE1NTA1MTc3MjIsImp0aSI6IjU3ODI4MmViN2QzZjQwNmQ1NjMyNmFkMzFlYTJmODVmODNkOWI1ZDgifQ.vcF9xydjFJRyjE8j9ljZP-TNWBWYZhYAurMKxIXT67SqgMDfGQrons2PgogMNsynIsEOCvSJFANrkDkSZR4eubAn7F1lYjXfR_1--gcRyuMOff1H4BfoxWrNyHlN5B9S9UBoBTXVLnbbQLrz1CJ6i23KA-IEtGk_aV1LEFpR34J4ugBdNZ-_FheZwxdTsM8oZAW4_bjP5aiIzJPKrYf-cQ7PWTi6q6OuhFi0VmjL8bF_dScGKwcoB38yxD2Z4dulE3WCFUyDpG9E7jKNiPiHn0qlPDvDTY7wRc6nkqc6uvxN99ZMkOo-UC7XmKn0h4QcvZNnF42w4BDdCMZ0-wDnZA"

let e = "AQAB"

let n =
  "2K7epoJWl_B68lRUi1txaa0kEuIK4WHiHpi1yC4kPyu48d046yLlrwuvbQMbog2YTOZdVoG1D4zlWKHuVY00O80U1ocFmBl3fKVrUMakvHru0C0mAcEUQo7ItyEX7rpOVYtxlrVk6G8PY4EK61EB-Xe35P0zb2AMZn7Tvm9-tLcccqYlrYBO4SWOwd5uBSqc_WcNJXgnQ-9sYEZ0JUMhKZelEMrpX72hslmduiz-LMsXCnbS7jDGcUuSjHXVLM9tb1SQynx5Xz9xyGeN4rQLnFIKvgwpiqnvLpbMo6grhJwrz67d1X6MwpKtAcqZ2V2v4rQsjbblNH7GzF8ZsfOaqw"

let basic_jwt =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

let basic_secret = "your-256-bit-secret"

let public_key =
  "-----BEGIN PUBLIC KEY-----\n\
   MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv\n\
   vkTtwlvBsaJq7S5wA+kzeVOVpVWwkWdVha4s38XM/pa/yr47av7+z3VTmvDRyAHc\n\
   aT92whREFpLv9cj5lTeJSibyr/Mrm/YtjCZVWgaOYIhwrXwKLqPr/11inWsAkfIy\n\
   tvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0\n\
   e+lf4s4OxQawWD79J9/5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb\n\
   V6L11BWkpzGXSW4Hv43qa+GSYOD2QU68Mb59oSk2OB+BtOLpJofmbGEGgvmwyCI9\n\
   MwIDAQAB\n\
   -----END PUBLIC KEY-----"

let private_key =
  "-----BEGIN RSA PRIVATE KEY-----\n\
   MIIEogIBAAKCAQEAnzyis1ZjfNB0bBgKFMSvvkTtwlvBsaJq7S5wA+kzeVOVpVWw\n\
   kWdVha4s38XM/pa/yr47av7+z3VTmvDRyAHcaT92whREFpLv9cj5lTeJSibyr/Mr\n\
   m/YtjCZVWgaOYIhwrXwKLqPr/11inWsAkfIytvHWTxZYEcXLgAXFuUuaS3uF9gEi\n\
   NQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0e+lf4s4OxQawWD79J9/5d3Ry0vbV\n\
   3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWbV6L11BWkpzGXSW4Hv43qa+GSYOD2\n\
   QU68Mb59oSk2OB+BtOLpJofmbGEGgvmwyCI9MwIDAQABAoIBACiARq2wkltjtcjs\n\
   kFvZ7w1JAORHbEufEO1Eu27zOIlqbgyAcAl7q+/1bip4Z/x1IVES84/yTaM8p0go\n\
   amMhvgry/mS8vNi1BN2SAZEnb/7xSxbflb70bX9RHLJqKnp5GZe2jexw+wyXlwaM\n\
   +bclUCrh9e1ltH7IvUrRrQnFJfh+is1fRon9Co9Li0GwoN0x0byrrngU8Ak3Y6D9\n\
   D8GjQA4Elm94ST3izJv8iCOLSDBmzsPsXfcCUZfmTfZ5DbUDMbMxRnSo3nQeoKGC\n\
   0Lj9FkWcfmLcpGlSXTO+Ww1L7EGq+PT3NtRae1FZPwjddQ1/4V905kyQFLamAA5Y\n\
   lSpE2wkCgYEAy1OPLQcZt4NQnQzPz2SBJqQN2P5u3vXl+zNVKP8w4eBv0vWuJJF+\n\
   hkGNnSxXQrTkvDOIUddSKOzHHgSg4nY6K02ecyT0PPm/UZvtRpWrnBjcEVtHEJNp\n\
   bU9pLD5iZ0J9sbzPU/LxPmuAP2Bs8JmTn6aFRspFrP7W0s1Nmk2jsm0CgYEAyH0X\n\
   +jpoqxj4efZfkUrg5GbSEhf+dZglf0tTOA5bVg8IYwtmNk/pniLG/zI7c+GlTc9B\n\
   BwfMr59EzBq/eFMI7+LgXaVUsM/sS4Ry+yeK6SJx/otIMWtDfqxsLD8CPMCRvecC\n\
   2Pip4uSgrl0MOebl9XKp57GoaUWRWRHqwV4Y6h8CgYAZhI4mh4qZtnhKjY4TKDjx\n\
   QYufXSdLAi9v3FxmvchDwOgn4L+PRVdMwDNms2bsL0m5uPn104EzM6w1vzz1zwKz\n\
   5pTpPI0OjgWN13Tq8+PKvm/4Ga2MjgOgPWQkslulO/oMcXbPwWC3hcRdr9tcQtn9\n\
   Imf9n2spL/6EDFId+Hp/7QKBgAqlWdiXsWckdE1Fn91/NGHsc8syKvjjk1onDcw0\n\
   NvVi5vcba9oGdElJX3e9mxqUKMrw7msJJv1MX8LWyMQC5L6YNYHDfbPF1q5L4i8j\n\
   8mRex97UVokJQRRA452V2vCO6S5ETgpnad36de3MUxHgCOX3qL382Qx9/THVmbma\n\
   3YfRAoGAUxL/Eu5yvMK8SAt/dJK6FedngcM3JEFNplmtLYVLWhkIlNRGDwkg3I5K\n\
   y18Ae9n7dHVueyslrb6weq7dTkYDi3iOYRW8HRkIQh06wEdbxt0shTzAJvvCQfrB\n\
   jg/3747WSsf/zBTcHihTRBdAv6OmdhV4/dD5YBfLAkLrd+mX7iE=\n\
   -----END RSA PRIVATE KEY-----"

let test_decode =
  Oth.test ~desc:"Decode JWT" ~name:"Decode" (fun _ -> Oth.Assert.true_ (None <> Jwt.of_token jwt))

let test_algo =
  Oth.test ~desc:"Verify algorithm" ~name:"Algo" (fun _ ->
      let t = CCOption.get_exn_or "jwt_of_token" (Jwt.of_token jwt) in
      let header = Jwt.header t in
      Oth.Assert.true_ (Some "RS256" = Jwt.Header.algorithm header))

let test_kid =
  Oth.test ~desc:"kid matches expected kid" ~name:"kid match" (fun _ ->
      let t = CCOption.get_exn_or "jwt_of_token" (Jwt.of_token jwt) in
      let header = Jwt.header t in
      let kid = CCOption.get_exn_or "jwt_header_get" (Jwt.Header.get "kid" header) in
      Oth.Assert.true_ ("7d680d8c70d44e947133cbd499ebc1a61c3d5abc" = kid))

let test_verify =
  Oth.test ~desc:"Verify signature" ~name:"Verify signature" (fun _ ->
      let t = CCOption.get_exn_or "jwt_of_token" (Jwt.of_token jwt) in
      let pub_key =
        CCOption.get_exn_or "jwt_verifier_pub_key_create" (Jwt.Verifier.Pub_key.create ~e ~n)
      in
      let verifier = Jwt.Verifier.RS256 pub_key in
      let verified = Jwt.verify verifier t in
      Oth.Assert.true_ (None <> verified))

let test_basic_decode =
  Oth.test ~desc:"Decode Basic JWT" ~name:"Decode basic" (fun _ ->
      Oth.Assert.true_ (None <> Jwt.of_token basic_jwt))

let test_basic_verify =
  Oth.test ~desc:"Verify basic signature" ~name:"Verify basic signature" (fun _ ->
      let t = CCOption.get_exn_or "jwt_of_token" (Jwt.of_token basic_jwt) in
      let verifier = Jwt.Verifier.HS256 basic_secret in
      let verified = Jwt.verify verifier t in
      Oth.Assert.true_ (None <> verified))

let test_sign_hs256 =
  Oth.test ~name:"Sign HS256" (fun _ ->
      let header = Jwt.Header.create ~typ:"JWT" "HS256" in
      let payload =
        Jwt.Payload.(
          empty
          |> add_claim Jwt.Claim.sub (`String "1234567890")
          |> add_claim Jwt.Claim.iat (`Int 1516239022)
          |> add_claim "name" (`String "John Doe"))
      in
      let signer = Jwt.Signer.HS256 basic_secret in
      let verified = Jwt.of_header_and_payload signer header payload in
      let t = CCOption.get_exn_or "jwt_of_token" (Jwt.of_token (Jwt.token verified)) in
      let verifier = Jwt.Verifier.HS256 basic_secret in
      let verified = Jwt.verify verifier t in
      Oth.Assert.true_ (None <> verified))

let test_sign_hs512 =
  Oth.test ~name:"Sign HS512" (fun _ ->
      let header = Jwt.Header.create ~typ:"JWT" "HS512" in
      let payload =
        Jwt.Payload.(
          empty
          |> add_claim Jwt.Claim.sub (`String "1234567890")
          |> add_claim Jwt.Claim.iat (`Int 1516239022)
          |> add_claim "name" (`String "John Doe"))
      in
      let signer = Jwt.Signer.HS512 basic_secret in
      let verified = Jwt.of_header_and_payload signer header payload in
      let t = CCOption.get_exn_or "jwt_of_token" (Jwt.of_token (Jwt.token verified)) in
      let verifier = Jwt.Verifier.HS512 basic_secret in
      let verified = Jwt.verify verifier t in
      Oth.Assert.true_ (None <> verified))

let test_sign_rs256 =
  Oth.test ~name:"Sign RS256" (fun _ ->
      let private_key =
        match CCResult.get_exn (X509.Private_key.decode_pem private_key) with
        | `RSA priv_key -> priv_key
        | _ -> Oth.Assert.false_ "Sign RS256: unexpected value"
      in
      let public_key =
        match CCResult.get_exn (X509.Public_key.decode_pem public_key) with
        | `RSA pub_key -> pub_key
        | _ -> Oth.Assert.false_ "Sign RS256: unexpected value"
      in
      let header = Jwt.Header.create ~typ:"JWT" "RS256" in
      let payload =
        Jwt.Payload.(
          empty
          |> add_claim Jwt.Claim.sub (`String "1234567890")
          |> add_claim Jwt.Claim.iat (`Int 1516239022)
          |> add_claim "name" (`String "John Doe"))
      in
      let signer = Jwt.Signer.(RS256 (Priv_key.of_priv_key private_key)) in
      let verified = Jwt.of_header_and_payload signer header payload in
      let t = CCOption.get_exn_or "jwt_of_token" (Jwt.of_token (Jwt.token verified)) in
      let verifier = Jwt.Verifier.(RS256 (Pub_key.of_pub_key public_key)) in
      let verified = Jwt.verify verifier t in
      Oth.Assert.true_ (None <> verified))

(* A verifier sits on an unauthenticated path, so it has to answer for any
   string an attacker can put in the signature slot. Mirage_crypto raises
   Invalid_argument on a degenerate RSA signature -- an all-zero block, or one
   wider than the modulus -- and an uncaught raise here closes the connection
   with no response instead of rejecting the token. *)
let test_rs256_degenerate_signature =
  Oth.test ~name:"RS256 verify answers rather than raises on a degenerate signature" (fun _ ->
      let private_key =
        match CCResult.get_exn (X509.Private_key.decode_pem private_key) with
        | `RSA priv_key -> priv_key
        | _ -> Oth.Assert.false_ "unexpected key type"
      in
      let public_key =
        match CCResult.get_exn (X509.Public_key.decode_pem public_key) with
        | `RSA pub_key -> pub_key
        | _ -> Oth.Assert.false_ "unexpected key type"
      in
      let header = Jwt.Header.create ~typ:"JWT" "RS256" in
      let payload = Jwt.Payload.(empty |> add_claim Jwt.Claim.sub (`String "1234567890")) in
      let signer = Jwt.Signer.(RS256 (Priv_key.of_priv_key private_key)) in
      let signed = Jwt.token (Jwt.of_header_and_payload signer header payload) in
      let hp =
        match CCString.split_on_char '.' signed with
        | header :: payload :: _ -> header ^ "." ^ payload
        | _ -> Oth.Assert.false_ "signed token is not three parts"
      in
      let verifier = Jwt.Verifier.(RS256 (Pub_key.of_pub_key public_key)) in
      let b64 s = Base64.encode_string ~pad:false ~alphabet:Base64.uri_safe_alphabet s in
      CCList.iter
        (fun (name, signature) ->
          let t = CCOption.get_exn_or name (Jwt.of_token (hp ^ "." ^ b64 signature)) in
          Oth.Assert.true_ (CCOption.is_none (Jwt.verify verifier t)))
        [
          ("all-zero signature", CCString.make 256 '\000');
          ("empty signature", "");
          ("signature wider than the modulus", CCString.make 512 '\255');
        ])

(* A header carrying no "alg" at all, or the "none" algorithm, arrives on the same
   unauthenticated path as a degenerate signature: the session cookie. Verification has to
   answer for it rather than raise. *)
let test_header_without_algorithm =
  Oth.test ~name:"verify answers rather than raises on a header with no alg" (fun _ ->
      let public_key =
        match CCResult.get_exn (X509.Public_key.decode_pem public_key) with
        | `RSA pub_key -> pub_key
        | _ -> Oth.Assert.false_ "unexpected key type"
      in
      let verifier = Jwt.Verifier.(RS256 (Pub_key.of_pub_key public_key)) in
      let b64 s = Base64.encode_string ~pad:false ~alphabet:Base64.uri_safe_alphabet s in
      CCList.iter
        (fun (name, header_json) ->
          let token = b64 header_json ^ "." ^ b64 "{}" ^ "." in
          let t = CCOption.get_exn_or name (Jwt.of_token token) in
          Oth.Assert.true_ (CCOption.is_none (Jwt.verify verifier t)))
        [
          ("header with no alg", "{}");
          ("alg none", {|{"alg":"none"}|});
          ("alg HS256", {|{"alg":"HS256"}|});
        ];
      ())

let b64 s = Base64.encode_string ~pad:false ~alphabet:Base64.uri_safe_alphabet s

(* A token for [alg], signed over its header and payload by [sign]. *)
let signed_token alg sign =
  let hp = b64 (Printf.sprintf {|{"alg":"%s","typ":"JWT"}|} alg) ^ "." ^ b64 {|{"sub":"1"}|} in
  hp ^ "." ^ b64 (sign hp)

let tampered token =
  match CCString.split_on_char '.' token with
  | [ h; p; sg ] ->
      let sg = Base64.decode_exn ~pad:false ~alphabet:Base64.uri_safe_alphabet sg in
      let flipped = Bytes.of_string sg in
      Bytes.set flipped 0 (Char.chr (Char.code (Bytes.get flipped 0) lxor 1));
      h ^ "." ^ p ^ "." ^ b64 (Bytes.to_string flipped)
  | _ -> token

let verifies verifier token =
  CCOption.is_some (Jwt.verify verifier (CCOption.get_exn_or "of_token" (Jwt.of_token token)))

(* An uncompressed point is [0x04 || x || y]; a JWK carries [x] and [y] apart. *)
let ec_key ~crv octets =
  let n = (CCString.length octets - 1) / 2 in
  CCOption.get_exn_or
    crv
    (Jwt.Verifier.Ec_pub_key.create
       ~crv
       ~x:(b64 (CCString.sub octets 1 n))
       ~y:(Some (b64 (CCString.sub octets (1 + n) n))))

let rsa_keys () =
  let priv =
    match CCResult.get_exn (X509.Private_key.decode_pem private_key) with
    | `RSA priv -> priv
    | _ -> Oth.Assert.false_ "unexpected key type"
  in
  (priv, Jwt.Verifier.Pub_key.of_pub_key (Mirage_crypto_pk.Rsa.pub_of_priv priv))

let assert_verifies verifier token =
  Oth.Assert.true_ (verifies verifier token);
  Oth.Assert.not_true (verifies verifier (tampered token))

let test_rsa_algorithms =
  Oth.test ~name:"Verify RS384, RS512, PS256, PS384 and PS512" (fun _ ->
      let priv, pub = rsa_keys () in
      let pkcs1 hash hp = Mirage_crypto_pk.Rsa.PKCS1.sign ~hash ~key:priv (`Message hp) in
      let pss (module H : Digestif.S) hp =
        let module Pss = Mirage_crypto_pk.Rsa.PSS (H) in
        Pss.sign ~key:priv (`Message hp)
      in
      CCList.iter
        (fun (alg, verifier, sign) -> assert_verifies verifier (signed_token alg sign))
        Jwt.Verifier.
          [
            ("RS384", RS384 pub, pkcs1 `SHA384);
            ("RS512", RS512 pub, pkcs1 `SHA512);
            ("PS256", PS256 pub, pss (module Digestif.SHA256));
            ("PS384", PS384 pub, pss (module Digestif.SHA384));
            ("PS512", PS512 pub, pss (module Digestif.SHA512));
          ])

let test_ec_algorithms =
  Oth.test ~name:"Verify ES256, ES384, ES512 and EdDSA" (fun _ ->
      let module Ec = Mirage_crypto_ec in
      let digest (module H : Digestif.S) hp = H.(to_raw_string (digest_string hp)) in
      let p256, p256_pub = Ec.P256.Dsa.generate () in
      let p384, p384_pub = Ec.P384.Dsa.generate () in
      let p521, p521_pub = Ec.P521.Dsa.generate () in
      let ed, ed_pub = Ec.Ed25519.generate () in
      let rs (r, s) = r ^ s in
      let p256_key = ec_key ~crv:"P-256" (Ec.P256.Dsa.pub_to_octets p256_pub) in
      let p384_key = ec_key ~crv:"P-384" (Ec.P384.Dsa.pub_to_octets p384_pub) in
      let es256 =
        signed_token "ES256" (fun hp ->
            rs (Ec.P256.Dsa.sign ~key:p256 (digest (module Digestif.SHA256) hp)))
      in
      CCList.iter
        (fun (_, verifier, token) -> assert_verifies verifier token)
        Jwt.Verifier.
          [
            ("ES256", ES256 p256_key, es256);
            ( "ES384",
              ES384 p384_key,
              signed_token "ES384" (fun hp ->
                  rs (Ec.P384.Dsa.sign ~key:p384 (digest (module Digestif.SHA384) hp))) );
            ( "ES512",
              ES512 (ec_key ~crv:"P-521" (Ec.P521.Dsa.pub_to_octets p521_pub)),
              signed_token "ES512" (fun hp ->
                  rs (Ec.P521.Dsa.sign ~key:p521 (digest (module Digestif.SHA512) hp))) );
            ( "EdDSA",
              EdDSA
                (CCOption.get_exn_or
                   "Ed25519"
                   (Jwt.Verifier.Ec_pub_key.create
                      ~crv:"Ed25519"
                      ~x:(b64 (Ec.Ed25519.pub_to_octets ed_pub))
                      ~y:None)),
              signed_token "EdDSA" (fun hp -> Ec.Ed25519.sign ~key:ed hp) );
          ];
      (* A key on another curve, or a verifier for another alg, does not verify. *)
      Oth.Assert.not_true (verifies (Jwt.Verifier.ES256 p384_key) es256);
      Oth.Assert.not_true (verifies (Jwt.Verifier.ES384 p256_key) es256);
      Oth.Assert.true_
        (CCOption.is_none (Jwt.Verifier.Ec_pub_key.create ~crv:"secp256k1" ~x:"AA" ~y:(Some "AA")));
      Oth.Assert.true_
        (CCOption.is_none
           (Jwt.Verifier.Ec_pub_key.create ~crv:"P-256" ~x:(b64 "x") ~y:(Some (b64 "y")))))

let test =
  Oth.parallel
    [
      test_rs256_degenerate_signature;
      test_header_without_algorithm;
      test_decode;
      test_algo;
      test_kid;
      test_verify;
      test_basic_decode;
      test_basic_verify;
      test_sign_hs256;
      test_sign_hs512;
      test_sign_rs256;
      test_rsa_algorithms;
      test_ec_algorithms;
    ]

let () =
  Mirage_crypto_rng_unix.use_default ();
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
