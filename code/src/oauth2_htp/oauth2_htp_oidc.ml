let src = Logs.Src.create "oauth2_htp_oidc"

module Logs = (val Logs.src_log src : Logs.LOG)
module J = Oauth2_htp_json

type err =
  [ Oauth2_htp_requests.err
  | `Issuer_mismatch of string * string
  | `Jwks_err
  | `Missing_id_token
  | `Malformed_token
  | `Token_expired of float
  | `Token_not_yet_valid of float
  | `Unsupported_signing_alg of string
  | `No_supported_signing_alg of string list
  | `Unknown_key_id of string
  | `Signature_verification_failed
  | `Invalid_audience of string list
  | `Unverified_email of string
  | `Missing_email
  ]
[@@deriving show]

type t = {
  issuer : string;
  client_id : string;
  client_secret : string;
  auth_url : string;
  token_url : string;
  jwks_url : string;
  userinfo_url : string;
  signing_algs : string list;
}

(* The algorithms an ID token may be signed with. *)
let supported_algs =
  [ "RS256"; "RS384"; "RS512"; "ES256"; "ES384"; "ES512"; "PS256"; "PS384"; "PS512"; "EdDSA" ]

let discover ~issuer_url ~client_id ~client_secret =
  let open Abbs_fc.Infix_result_monad in
  Logs.info (fun m -> m "Performing OIDC Discovery...");
  Oauth2_htp_requests.unmarshal
    (CCString.rdrop_while (Char.equal '/') issuer_url ^ "/.well-known/openid-configuration")
  >>= fun json ->
  let signing_algs = J.string_list (J.member "id_token_signing_alg_values_supported" json) in
  match J.must_string (J.member "issuer" json) with
  | issuer when not (CCString.equal issuer issuer_url) ->
      Abb.Future.return (Error (`Issuer_mismatch (issuer_url, issuer)))
  | _
    when (not (CCList.is_empty signing_algs))
         && not (CCList.exists (fun alg -> Sln_list.String.mem alg supported_algs) signing_algs) ->
      Abb.Future.return (Error (`No_supported_signing_alg signing_algs))
  | _ ->
      Abb.Future.return
        (Ok
           {
             issuer = issuer_url;
             client_id;
             client_secret;
             auth_url = J.must_string (J.member "authorization_endpoint" json);
             token_url = J.must_string (J.member "token_endpoint" json);
             jwks_url = J.must_string (J.member "jwks_uri" json);
             userinfo_url = J.must_string (J.member "userinfo_endpoint" json);
             signing_algs;
           })

let login_url t = t.auth_url

let verifier_of_key ~alg key =
  let open CCOption.Infix in
  let get name = Jwk.Key.get name key in
  let rsa f = get "n" >>= fun n -> get "e" >>= fun e -> Jwt.Verifier.Pub_key.create ~e ~n >|= f in
  let ec f =
    get "crv"
    >>= fun crv -> get "x" >>= fun x -> Jwt.Verifier.Ec_pub_key.create ~crv ~x ~y:(get "y") >|= f
  in
  match alg with
  | "RS256" -> rsa (fun k -> Jwt.Verifier.RS256 k)
  | "RS384" -> rsa (fun k -> Jwt.Verifier.RS384 k)
  | "RS512" -> rsa (fun k -> Jwt.Verifier.RS512 k)
  | "PS256" -> rsa (fun k -> Jwt.Verifier.PS256 k)
  | "PS384" -> rsa (fun k -> Jwt.Verifier.PS384 k)
  | "PS512" -> rsa (fun k -> Jwt.Verifier.PS512 k)
  | "ES256" -> ec (fun k -> Jwt.Verifier.ES256 k)
  | "ES384" -> ec (fun k -> Jwt.Verifier.ES384 k)
  | "ES512" -> ec (fun k -> Jwt.Verifier.ES512 k)
  | "EdDSA" -> ec (fun k -> Jwt.Verifier.EdDSA k)
  | _ -> None

(* The token must verify with a JWKS key the token names, or with any key when it names none.  Keys
   are fetched for each token: a sign-in is rare enough that this costs nothing, and a rotated key is
   picked up at once. *)
let verify_signature t ~alg token =
  let open Abbs_fc.Infix_result_monad in
  let kid =
    match Jwt.Header.get "kid" (Jwt.header token) with
    | Some "" | None -> None
    | Some kid -> Some kid
  in
  Oauth2_htp_requests.do_ t.jwks_url
  >>= fun result ->
  match
    ( Oauth2_htp_requests.Result.status_code result,
      Jwk.of_string (Oauth2_htp_requests.Result.body result) )
  with
  | 200, Some jwk -> (
      let keys =
        match kid with
        | None -> Jwk.keys jwk
        | Some kid ->
            CCList.filter
              (fun key -> CCOption.equal CCString.equal (Some kid) (Jwk.Key.get "kid" key))
              (Jwk.keys jwk)
      in
      let verifies key =
        CCOption.is_some
          (CCOption.flat_map (fun verifier -> Jwt.verify verifier token) (verifier_of_key ~alg key))
      in
      match (kid, keys) with
      | Some kid, [] -> Abb.Future.return (Error (`Unknown_key_id kid))
      | _, keys when CCList.exists verifies keys -> Abb.Future.return (Ok ())
      | _, _ -> Abb.Future.return (Error `Signature_verification_failed))
  | _, _ -> Abb.Future.return (Error `Jwks_err)

(* Google's ID tokens may name the issuer without its scheme. *)
let issuer_matches t issuer =
  CCString.equal issuer t.issuer
  || CCString.equal t.issuer "https://accounts.google.com"
     && CCString.equal issuer "accounts.google.com"

(* How far ahead of [nbf] the clock may be. *)
let nbf_leeway = 300.

let verify ~now t token =
  let open Abbs_fc.Infix_result_monad in
  let claims = Jwt.Payload.to_json (Jwt.payload token) in
  (* [Jwt.Header.algorithm] raises when the header has no [alg]. *)
  let alg = CCOption.get_or ~default:"" (Jwt.Header.get "alg" (Jwt.header token)) in
  let signing_algs =
    match t.signing_algs with
    | [] -> [ "RS256" ]
    | algs -> algs
  in
  match Sln_list.String.mem alg signing_algs with
  | false -> Abb.Future.return (Error (`Unsupported_signing_alg alg))
  | true -> (
      verify_signature t ~alg token
      >>= fun () ->
      let audience = J.string_list (J.member "aud" claims) in
      (* A token without [exp] has expired. *)
      let expiry = J.must_number (J.member "exp" claims) in
      let not_before = J.member "nbf" claims in
      match J.must_string (J.member "iss" claims) with
      | issuer when not (issuer_matches t issuer) ->
          Abb.Future.return (Error (`Issuer_mismatch (t.issuer, issuer)))
      | _ when not (Sln_list.String.mem t.client_id audience) ->
          Abb.Future.return (Error (`Invalid_audience audience))
      | _ when expiry < now -> Abb.Future.return (Error (`Token_expired expiry))
      | _ when (not (J.is_null not_before)) && now +. nbf_leeway < J.must_number not_before ->
          Abb.Future.return (Error (`Token_not_yet_valid (J.must_number not_before)))
      | _ -> Abb.Future.return (Ok claims))

(* Coerce a claim into a string.  A non-string is rendered as JSON. *)
let claim_string = function
  | `String s -> s
  | `Null -> ""
  | (`Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _) as value ->
      Yojson.Safe.to_string value

let claim_string_list = function
  | `Null -> []
  | `List values -> CCList.map claim_string values
  | (`Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `String _) as value ->
      [ claim_string value ]

(* Anything that does not read as true is false. *)
let claim_bool = function
  | `Bool b -> b
  | `Int i -> i <> 0
  | `Float f -> not (CCFloat.equal f 0.)
  | `String ("1" | "t" | "T" | "TRUE" | "true" | "True") -> true
  | `String _ -> false
  | `Assoc _ | `Intlit _ | `List _ | `Null -> false

let session_claims = [ "sub"; "email"; "groups"; "preferred_username"; "email_verified" ]

(* The userinfo claims, fetched only when the ID token lacks one of [session_claims]. *)
let profile_claims ~access_token t claims =
  match
    CCList.exists (fun claim -> J.is_null (J.member claim claims)) session_claims
    && (not (CCString.is_empty t.userinfo_url))
    && not (CCString.is_empty access_token)
  with
  | false -> Abb.Future.return (Ok (`Assoc []))
  | true ->
      Oauth2_htp_requests.unmarshal
        ~headers:[ ("Authorization", "Bearer " ^ access_token); ("Accept", "application/json") ]
        t.userinfo_url

let session_of_claims ~access_token t claims =
  let open Abbs_fc.Infix_result_monad in
  profile_claims ~access_token t claims
  >>= fun profile ->
  let claim name =
    match J.member name claims with
    | `Null -> J.member name profile
    | value -> value
  in
  let session =
    {
      Oauth2_htp_session.user = claim_string (claim "sub");
      email = claim_string (claim "email");
      groups = Some (claim_string_list (claim "groups"));
      access_token;
    }
  in
  (* [email_verified] must be present and explicitly false to be considered unverified. *)
  match (session.Oauth2_htp_session.email, claim "email_verified") with
  | "", _ -> Abb.Future.return (Error `Missing_email)
  | email, verified when (not (J.is_null verified)) && not (claim_bool verified) ->
      Abb.Future.return (Error (`Unverified_email email))
  | _, _ -> Abb.Future.return (Ok session)

(* The client authenticates with HTTP Basic, and on any failure, again with its credentials in the
   form. *)
let redeem_code ~redirect_uri ~code t =
  let open Abb.Future.Infix_monad in
  let params =
    [
      ("grant_type", [ "authorization_code" ]);
      ("code", [ code ]);
      ("redirect_uri", [ redirect_uri ]);
    ]
  in
  let basic =
    Base64.encode_string
      (Form_urlencode.encode t.client_id ^ ":" ^ Form_urlencode.encode t.client_secret)
  in
  let has_access_token json =
    not (CCString.is_empty (J.must_string (J.member "access_token" json)))
  in
  Oauth2_htp_requests.post_form ~headers:[ ("Authorization", "Basic " ^ basic) ] t.token_url params
  >>= function
  | Ok json when has_access_token json -> Abb.Future.return (Ok json)
  | Ok _ | Error _ ->
      Logs.debug (fun m -> m "Token request with HTTP Basic failed, retrying with form credentials");
      Oauth2_htp_requests.post_form
        t.token_url
        (params
        @ CCList.filter_map
            (function
              | _, "" -> None
              | k, v -> Some (k, [ v ]))
            [ ("client_id", t.client_id); ("client_secret", t.client_secret) ])

let redeem ~now ~redirect_uri ~code t =
  let open Abbs_fc.Infix_result_monad in
  redeem_code ~redirect_uri ~code t
  >>= fun json ->
  match J.must_string (J.member "id_token" json) with
  | "" -> Abb.Future.return (Error `Missing_id_token)
  | id_token -> (
      match Jwt.of_token id_token with
      | None -> Abb.Future.return (Error `Malformed_token)
      | Some id_token ->
          verify ~now t id_token
          >>= fun claims ->
          session_of_claims ~access_token:(J.must_string (J.member "access_token" json)) t claims)
