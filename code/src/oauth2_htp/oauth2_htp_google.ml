let src = Logs.Src.create "oauth2_htp_google"

module Logs = (val Logs.src_log src : Logs.LOG)
module J = Oauth2_htp_json

type err =
  [ Oauth2_htp_requests.err
  | `Provider_err of string
  | `Unverified_email of string
  ]
[@@deriving show]

module Group = struct
  type t = {
    groups : string list;
    admin_email : string;
    service_account_json : string;
  }
end

module Endpoints = struct
  type t = {
    login_url : string;
    token_url : string;
    admin_token_url : string;
    admin_directory_url : string;
  }

  let default =
    {
      login_url = "https://accounts.google.com/o/oauth2/auth";
      token_url = "https://www.googleapis.com/oauth2/v3/token";
      admin_token_url = "https://oauth2.googleapis.com/token";
      admin_directory_url = "https://admin.googleapis.com/admin/directory/v1";
    }
end

type t = {
  client_id : string;
  client_secret : string;
  group : Group.t option;
  endpoints : Endpoints.t;
}

let make ?(endpoints = Endpoints.default) ~client_id ~client_secret ~group () =
  { client_id; client_secret; group; endpoints }

let login_url t = t.endpoints.Endpoints.login_url

(* https://developers.google.com/admin-sdk/directory/reference/rest/v1/members/hasMember#authorization-scopes *)
let possible_scopes =
  [
    "https://www.googleapis.com/auth/admin.directory.group.member.readonly";
    "https://www.googleapis.com/auth/admin.directory.group.readonly";
    "https://www.googleapis.com/auth/admin.directory.group.member";
    "https://www.googleapis.com/auth/admin.directory.group";
  ]

(* The ID token comes straight from Google's token endpoint over TLS, so its claims are read as they
   are: its signature, [alg], [iss], [aud] and [exp] are not checked.
   https://developers.google.com/accounts/docs/OAuth2Login#obtainuserinfo *)
let claims_from_id_token id_token =
  match Jwt.of_token id_token with
  | None -> Error (`Provider_err "malformed id_token")
  | Some jwt -> (
      let claims = Jwt.Payload.to_json (Jwt.payload jwt) in
      match
        (J.must_string (J.member "email" claims), J.must_bool (J.member "email_verified" claims))
      with
      | "", _ -> Error (`Provider_err "missing email")
      | email, false -> Error (`Unverified_email email)
      | email, true -> Ok (J.must_string (J.member "sub" claims), email))

(* {2 Admin SDK access}

   A service account's key signs a JWT assertion that impersonates the admin; the token endpoint
   exchanges it for an access token. *)

let sign_assertion ~audience ~client_email ~private_key_pem ~scope ~subject ~now =
  match X509.Private_key.decode_pem private_key_pem with
  | Ok (`RSA priv) ->
      let payload =
        CCList.fold_left
          (fun payload (k, v) -> Jwt.Payload.add_claim k v payload)
          Jwt.Payload.empty
          [
            ("iss", `String client_email);
            ("scope", `String scope);
            ("aud", `String audience);
            ("exp", `Int (CCFloat.to_int now + 3600));
            ("iat", `Int (CCFloat.to_int now));
            ("sub", `String subject);
          ]
      in
      Ok
        (Jwt.token
           (Jwt.of_header_and_payload
              (Jwt.Signer.RS256 (Jwt.Signer.Priv_key.of_priv_key priv))
              (Jwt.Header.create ~typ:"JWT" "RS256")
              payload))
  | Ok (`ED25519 _ | `P256 _ | `P384 _ | `P521 _) ->
      Error (`Provider_err "google credentials private key is not an RSA key")
  | Error (`Msg msg) ->
      Error
        (`Provider_err (Printf.sprintf "can't decode the Google credentials private key: %s" msg))

let token_for_scope ~endpoints ~client_email ~private_key_pem ~admin_email ~now scope =
  let open Abbs_fc.Infix_result_monad in
  let audience = endpoints.Endpoints.admin_token_url in
  Abb.Future.return
    (sign_assertion ~audience ~client_email ~private_key_pem ~scope ~subject:admin_email ~now)
  >>= fun assertion ->
  Oauth2_htp_requests.post_form
    audience
    [
      ("grant_type", [ "urn:ietf:params:oauth:grant-type:jwt-bearer" ]); ("assertion", [ assertion ]);
    ]
  >>| fun json -> J.must_string (J.member "access_token" json)

(* The first of [possible_scopes] the credentials are authorized for. *)
let admin_token ~endpoints ~now group =
  let { Group.service_account_json; admin_email; groups = _ } = group in
  match Yojson.Safe.from_string service_account_json with
  | exception Yojson.Json_error msg ->
      Abb.Future.return (Error (`Provider_err ("can't read Google service account key: " ^ msg)))
  | creds ->
      let open Abb.Future.Infix_monad in
      let client_email = J.must_string (J.member "client_email" creds) in
      let private_key_pem = J.must_string (J.member "private_key" creds) in
      let insufficient =
        `Provider_err
          "google credentials do not have enough permissions to access the admin API scope"
      in
      Abbs_fc.List.fold_left
        ~f:(fun acc scope ->
          match acc with
          | Ok _ -> Abb.Future.return acc
          | Error _ ->
              token_for_scope ~endpoints ~client_email ~private_key_pem ~admin_email ~now scope
              >>| CCResult.map_err (fun _ -> insufficient))
        ~init:(Error insufficient)
        possible_scopes

(* Use the [hasMember] API to check for the user's presence in the group or its nested
   subgroups. *)
let user_in_group ~endpoints ~access_token group email =
  let open Abb.Future.Infix_monad in
  let headers = [ ("Authorization", "Bearer " ^ access_token) ] in
  let url api =
    Printf.sprintf
      "%s/groups/%s/%s/%s"
      endpoints.Endpoints.admin_directory_url
      (Form_urlencode.encode group)
      api
      (Form_urlencode.encode email)
  in
  Oauth2_htp_requests.unmarshal ~headers (url "hasMember")
  >>= function
  | Ok json -> Abb.Future.return (J.must_bool (J.member "isMember" json))
  | Error (`Unexpected_status (404, _)) ->
      Logs.err (fun m -> m "error checking membership in group %s: group does not exist" group);
      Abb.Future.return false
  | Error (`Unexpected_status (400, _)) -> (
      (* hasMember can say no for a member whose email is from a different domain than the group's.
         The member object answers for those. *)
      Oauth2_htp_requests.unmarshal ~headers (url "members")
      >>= function
      (* Only count the user as belonging to the group if they are ACTIVE. *)
      | Ok json ->
          Abb.Future.return (CCString.equal "ACTIVE" (J.must_string (J.member "status" json)))
      | Error _ ->
          Logs.err (fun m ->
              m
                "error using get API to check member %s of google group %s: user not in the group"
                email
                group);
          Abb.Future.return false)
  | Error err ->
      Logs.err (fun m ->
          m
            "error checking group membership: %a"
            Oauth2_htp_requests.pp_err
            (err :> Oauth2_htp_requests.err));
      Abb.Future.return false

(* Every group the user is a member of, read page by page. *)
let user_groups ~endpoints ~access_token email =
  let open Abbs_fc.Infix_result_monad in
  let headers = [ ("Authorization", "Bearer " ^ access_token) ] in
  let rec fetch acc page_token =
    let params =
      [ ("userKey", [ email ]); ("maxResults", [ "200" ]) ]
      @ CCOption.map_or ~default:[] (fun token -> [ ("pageToken", [ token ]) ]) page_token
    in
    Oauth2_htp_requests.unmarshal
      ~headers
      (endpoints.Endpoints.admin_directory_url ^ "/groups?" ^ Oauth2_htp_values.encode params)
    >>= fun json ->
    let acc =
      acc
      @ CCList.filter_map
          (fun group ->
            match J.must_string (J.member "email" group) with
            | "" -> None
            | email -> Some email)
          (match J.member "groups" json with
          | `List groups -> groups
          | `Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `Null | `String _ -> [])
    in
    match J.must_string (J.member "nextPageToken" json) with
    | "" -> Abb.Future.return (Ok acc)
    | token -> fetch acc (Some token)
  in
  fetch [] None

(* With groups configured, those the user is a member of. Without, every group the user is a
   member of, or [None] when they cannot be read. *)
let groups_of ~endpoints ~now group email =
  let open Abb.Future.Infix_monad in
  match group.Group.groups with
  | [] -> (
      admin_token ~endpoints ~now group
      >>= function
      | Error (`Provider_err msg) ->
          Logs.err (fun m -> m "Failed to get user groups for %s: %s" email msg);
          Abb.Future.return None
      | Ok access_token -> (
          user_groups ~endpoints ~access_token email
          >>| function
          | Ok groups -> Some groups
          | Error err ->
              Logs.err (fun m ->
                  m "Failed to get user groups for %s: %a" email Oauth2_htp_requests.pp_err err);
              None))
  | groups -> (
      admin_token ~endpoints ~now group
      >>= function
      | Error (`Provider_err msg) ->
          Logs.err (fun m -> m "unable to build the google admin service: %s" msg);
          Abb.Future.return (Some [])
      | Ok access_token ->
          Abbs_fc.List.filter
            ~f:(fun group -> user_in_group ~endpoints ~access_token group email)
            groups
          >>| CCOption.return)

let check_admin ~now t =
  match t.group with
  | None -> Abb.Future.return (Ok ())
  | Some group ->
      let open Abb.Future.Infix_monad in
      admin_token ~endpoints:t.endpoints ~now group >>| CCResult.map (fun _ -> ())

let redeem ~now ~redirect_uri ~code t =
  let open Abbs_fc.Infix_result_monad in
  Oauth2_htp_requests.post_form
    t.endpoints.Endpoints.token_url
    [
      ("redirect_uri", [ redirect_uri ]);
      ("client_id", [ t.client_id ]);
      ("client_secret", [ t.client_secret ]);
      ("code", [ code ]);
      ("grant_type", [ "authorization_code" ]);
    ]
  >>= fun json ->
  Abb.Future.return (claims_from_id_token (J.must_string (J.member "id_token" json)))
  >>= fun (user, email) ->
  let session =
    {
      Oauth2_htp_session.user;
      email;
      groups = Some [];
      access_token = J.must_string (J.member "access_token" json);
    }
  in
  match t.group with
  | None -> Abb.Future.return (Ok session)
  | Some group ->
      let open Abb.Future.Infix_monad in
      groups_of ~endpoints:t.endpoints ~now group email
      >>| fun groups -> Ok { session with Oauth2_htp_session.groups }

let authorize t session =
  match (t.group, session.Oauth2_htp_session.groups) with
  | None, _ | Some { Group.groups = []; _ }, _ -> true
  | Some _, Some (_ :: _) -> true
  | Some _, (Some [] | None) -> false
