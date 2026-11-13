let src = Logs.Src.create "oauth2_htp_oidc"

module Logs = (val Logs.src_log src : Logs.LOG)
module Json = Oauth2_htp_json

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
  | `Missing_access_token
  | `Invalid_discovery of string
  | `Missing_claim of string
  | `Invalid_claim of string
  ]
[@@deriving show]

type t = {
  issuer : string;
  client_id : string;
  client_secret : string;
  auth_url : string;
  token_url : string;
  jwks_url : string;
  userinfo_url : string option;
  signing_algs : string list;
}

(* The algorithms an ID token may be signed with. *)
let supported_algs =
  [ "RS256"; "RS384"; "RS512"; "ES256"; "ES384"; "ES512"; "PS256"; "PS384"; "PS512"; "EdDSA" ]

(* The value of a key, a [null] value counting as absent. *)
let present name json =
  match Json.member name json with
  | Some `Null | None -> None
  | Some ((`Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `String _) as value) ->
      Some value

let string_array value =
  CCOption.Infix.(
    Json.list value >>= fun values -> CCOption.sequence_l (CCList.map Json.string values))

(* A string, or an array of strings. *)
let strings = function
  | `String s -> Some [ s ]
  | (`Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null) as value ->
      string_array value

(* The parts of the provider's answers that a sign-in reads. *)

module Discovery = struct
  type t = {
    issuer : string;
    authorization_endpoint : string;
    token_endpoint : string;
    jwks_uri : string;
    userinfo_endpoint : string option; [@default None]
    id_token_signing_alg_values_supported : string list option; [@default None]
  }
  [@@deriving of_yojson { strict = false }]
end

module Token_response = struct
  type t = {
    id_token : string option; [@default None]
    access_token : string option; [@default None]
  }
  [@@deriving of_yojson { strict = false }]
end

let discover ~issuer_url ~client_id ~client_secret =
  let open Abbs_fc.Infix_result_monad in
  Logs.info (fun m -> m "Performing OIDC Discovery...");
  Oauth2_htp_requests.unmarshal
    (CCString.rdrop_while (Char.equal '/') issuer_url ^ "/.well-known/openid-configuration")
  >>? fun json ->
  CCResult.flat_map
    (fun {
           Discovery.issuer;
           authorization_endpoint;
           token_endpoint;
           jwks_uri;
           userinfo_endpoint;
           id_token_signing_alg_values_supported;
         }
       ->
      (* Without the list, the provider signs its ID tokens with RS256. *)
      let signing_algs = CCOption.get_or ~default:[] id_token_signing_alg_values_supported in
      match issuer with
      | issuer when not (CCString.equal issuer issuer_url) ->
          Error (`Issuer_mismatch (issuer_url, issuer))
      | _
        when (not (CCList.is_empty signing_algs))
             && not (CCList.exists (fun alg -> Sln_list.String.mem alg supported_algs) signing_algs)
        -> Error (`No_supported_signing_alg signing_algs)
      | _ ->
          Ok
            {
              issuer = issuer_url;
              client_id;
              client_secret;
              auth_url = authorization_endpoint;
              token_url = token_endpoint;
              jwks_url = jwks_uri;
              userinfo_url = userinfo_endpoint;
              signing_algs;
            })
    (CCResult.map_err (fun msg -> `Invalid_discovery msg) (Discovery.of_yojson json))

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

(* A claim the token must have, read with [read]. *)
let required_claim read name claims =
  match present name claims with
  | None -> Error (`Missing_claim name)
  | Some value -> CCOption.to_result (`Invalid_claim name) (read value)

(* A claim the token may have, read with [read]. *)
let optional_claim read name claims =
  match present name claims with
  | None -> Ok None
  | Some value ->
      CCOption.to_result (`Invalid_claim name) (CCOption.map CCOption.return (read value))

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
      >>? fun () ->
      let open CCResult.Infix in
      (* [aud] is a string, or an array of strings. *)
      required_claim strings "aud" claims
      >>= fun audience ->
      required_claim Json.number "exp" claims
      >>= fun expiry ->
      optional_claim Json.number "nbf" claims
      >>= fun not_before ->
      required_claim Json.string "iss" claims
      >>= function
      | issuer when not (issuer_matches t issuer) -> Error (`Issuer_mismatch (t.issuer, issuer))
      | _ when not (Sln_list.String.mem t.client_id audience) -> Error (`Invalid_audience audience)
      | _ when expiry < now -> Error (`Token_expired expiry)
      | _ -> (
          match not_before with
          | Some not_before when now +. nbf_leeway < not_before ->
              Error (`Token_not_yet_valid not_before)
          | Some _ | None -> Ok claims))

let session_claims = [ "sub"; "email"; "groups"; "preferred_username"; "email_verified" ]

(* The userinfo claims, fetched only when the ID token lacks one of [session_claims]. *)
let profile_claims ~access_token t claims =
  match
    ( t.userinfo_url,
      CCList.exists (fun claim -> CCOption.is_none (present claim claims)) session_claims )
  with
  | Some userinfo_url, true ->
      Oauth2_htp_requests.unmarshal
        ~headers:[ ("Authorization", "Bearer " ^ access_token); ("Accept", "application/json") ]
        userinfo_url
  | Some _, false | None, (true | false) -> Abb.Future.return (Ok (`Assoc []))

let session_of_claims ~access_token t claims =
  let open Abbs_fc.Infix_result_monad in
  profile_claims ~access_token t claims
  >>? fun profile ->
  let open CCResult.Infix in
  let claim name = CCOption.or_ ~else_:(present name profile) (present name claims) in
  (match claim "sub" with
    | Some (`String sub) when Sln_string.is_non_empty sub -> Ok sub
    (* Some providers send a numeric [sub]. *)
    | Some (`Int sub) -> Ok (CCInt.to_string sub)
    | Some (`Intlit sub) -> Ok sub
    | Some (`String _ | `Assoc _ | `Bool _ | `Float _ | `List _ | `Null) ->
        Error (`Invalid_claim "sub")
    | None -> Error (`Missing_claim "sub"))
  >>= fun user ->
  (match claim "email" with
    | Some (`String email) when Sln_string.is_non_empty email -> Ok email
    | Some (`String _) | None -> Error `Missing_email
    | Some (`Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null) ->
        Error (`Invalid_claim "email"))
  >>= fun email ->
  (* An absent [email_verified] counts as verified. Some providers send it as a string. *)
  (match claim "email_verified" with
    | None | Some (`Bool true | `String "true") -> Ok ()
    | Some (`Bool false | `String "false") -> Error (`Unverified_email email)
    | Some (`String _ | `Assoc _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null) ->
        Error (`Invalid_claim "email_verified"))
  >>= fun () ->
  (* [groups] is a string, or an array of strings. Without it the user is in no group. *)
  (match claim "groups" with
    | None -> Ok []
    | Some groups -> CCOption.to_result (`Invalid_claim "groups") (strings groups))
  >|= fun groups ->
  { Oauth2_htp_session.user; email; groups = Some groups; avatar_url = None; access_token }

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
    CCResult.to_opt (Token_response.of_yojson json)
    |> CCOption.flat_map (fun response -> response.Token_response.access_token)
    |> CCOption.exists Sln_string.is_non_empty
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
  match Token_response.of_yojson json with
  | Error msg -> Abb.Future.return (Error (`Json_err msg))
  | Ok { Token_response.id_token; access_token } -> (
      let non_empty = CCOption.filter Sln_string.is_non_empty in
      match (non_empty id_token, non_empty access_token) with
      | None, (Some _ | None) -> Abb.Future.return (Error `Missing_id_token)
      | Some _, None -> Abb.Future.return (Error `Missing_access_token)
      | Some id_token, Some access_token -> (
          match Jwt.of_token id_token with
          | None -> Abb.Future.return (Error `Malformed_token)
          | Some id_token ->
              verify ~now t id_token >>= fun claims -> session_of_claims ~access_token t claims))
