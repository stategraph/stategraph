module Http = Abb_curl.Make (Abb)

type oauth_err =
  [ `Oauth_exchange_failed_err
  | `Oauth_bad_response_err
  | Http.request_err
  ]
[@@deriving show]

type api_err =
  [ `Github_call_err of Githubc2_abb.call_err
  | `Github_not_modified_err
  | `Forbidden_err
  ]
[@@deriving show]

type err =
  [ oauth_err
  | api_err
  ]
[@@deriving show]

module Access_token_request = struct
  type t = {
    client_id : string;
    client_secret : string;
    code : string;
  }
  [@@deriving to_yojson]
end

module Access_token = struct
  type t = { access_token : string } [@@deriving of_yojson { strict = false }]
end

(* An installation the caller can see, reduced to what the decision needs. *)
type installation = {
  github_id : int;
  target_id : int;
  target_type : string;
}

let user_agent = "Stategraph"

let client ~config token =
  Githubc2_abb.create
    ~user_agent
    ~base_url:(Uri.of_string (Sgs_config.github_oauth_api_base config))
    (`Token token)

(* Exchange the authorization code for a user-to-server token. Mirrors the
   engine's exchange (Terrat_github.Oauth.authorize) so both speak to GitHub the
   same way; asks for JSON explicitly rather than relying on the default. *)
let exchange_code ~config code =
  let open Abb.Future.Infix_monad in
  let headers =
    Http.Headers.of_list
      [
        ("user-agent", user_agent);
        ("content-type", "application/json");
        ("accept", "application/json");
      ]
  in
  let uri =
    Uri.of_string
      (Printf.sprintf "%s/login/oauth/access_token" (Sgs_config.github_oauth_web_base config))
  in
  let body =
    Yojson.Safe.to_string
      (Access_token_request.to_yojson
         {
           Access_token_request.client_id = Sgs_config.github_oauth_client_id config;
           client_secret = Sgs_config.github_oauth_client_secret config;
           code;
         })
  in
  Http.post ~headers ~body uri
  >>| function
  | Ok (resp, body) when Http.Status.is_success (Http.Response.status resp) -> (
      match Access_token.of_yojson (Yojson.Safe.from_string body) with
      | Ok { Access_token.access_token } -> Ok access_token
      (* GitHub answers 200 with {"error": ...} for a spent or wrong code, so a
         successful status is not a successful exchange. The body is dropped,
         because it can echo the code. *)
      | Error _ | (exception Yojson.Json_error _) -> Error `Oauth_bad_response_err)
  | Ok (_, _) -> Error `Oauth_exchange_failed_err
  | Error (#Http.request_err as err) -> Error err

let authenticated_user_id ~config token =
  let open Abb.Future.Infix_monad in
  Githubc2_abb.call (client ~config token) Githubc2_users.Get_authenticated.(make ())
  >>| function
  | Ok resp -> (
      match Openapi.Response.value resp with
      | `OK (Githubc2_users.Get_authenticated.Responses.OK.Private_user user) ->
          let open Githubc2_components.Private_user in
          Ok (CCInt64.to_int user.primary.Primary.id)
      | `OK (Githubc2_users.Get_authenticated.Responses.OK.Public_user user) ->
          let open Githubc2_components.Public_user in
          Ok (CCInt64.to_int user.id)
      | `Forbidden _ | `Unauthorized _ -> Error `Forbidden_err
      | `Not_modified -> Error `Github_not_modified_err)
  | Error (#Githubc2_abb.call_err as err) -> Error (`Github_call_err err)

(* Numeric ids of the organizations where this user is an ACTIVE ADMIN.

   Both filters carry weight: a pending invitation is not membership, and
   `Billing_manager` is rejected explicitly rather than by falling through a
   wildcard, because it is the role most easily mistaken for privileged. *)
let admin_org_ids ~config token =
  let open Abb.Future.Infix_monad in
  Githubc2_abb.collect_all
    (client ~config token)
    Githubc2_orgs.List_memberships_for_authenticated_user.(
      make Parameters.(make ~per_page:100 ~state:(Some `Active) ()))
  >>| function
  | Ok memberships ->
      Ok
        (CCList.filter_map
           (fun m ->
             let open Githubc2_components.Org_membership in
             match (m.primary.Primary.role, m.primary.Primary.state) with
             | `Admin, `Active ->
                 Some
                   m.primary.Primary.organization.Githubc2_components.Organization_simple.primary
                     .Githubc2_components.Organization_simple.Primary.id
             | `Admin, `Pending | `Billing_manager, _ | `Member, _ -> None)
           memberships)
  | Error `Error ->
      (* GitHub answered a page with a status other than 200. The App needs
         organization members:read for this call. Without it every org claim
         fails closed, which is the right direction but needs to be legible to
         an operator, so it gets its own error. *)
      Error `Forbidden_err
  | Error (#Githubc2_abb.call_err as err) -> Error (`Github_call_err err)

let user_installations ~config token =
  let open Abb.Future.Infix_monad in
  Githubc2_abb.fold
    (client ~config token)
    ~init:[]
    ~f:(fun acc resp ->
      match Openapi.Response.value resp with
      | `OK
          Githubc2_apps.List_installations_for_authenticated_user.Responses.OK.
            { primary = Primary.{ installations; total_count = _ }; additional = _ } ->
          Abb.Future.return
            (Ok
               (acc
               @ CCList.map
                   (fun i ->
                     let open Githubc2_components.Installation in
                     {
                       github_id = i.primary.Primary.id;
                       target_id = i.primary.Primary.target_id;
                       target_type = i.primary.Primary.target_type;
                     })
                   installations))
      | `Forbidden _ | `Unauthorized _ | `Not_modified -> Abb.Future.return (Error `Forbidden_err))
    Githubc2_apps.List_installations_for_authenticated_user.(
      make Parameters.(make ~per_page:100 ()))
  >>| function
  | Ok installations -> Ok installations
  | Error `Forbidden_err -> Error `Forbidden_err
  | Error (#Githubc2_abb.call_err as err) -> Error (`Github_call_err err)

(* The decision, kept pure so the security-relevant part is testable without a
   GitHub account. An installation is proven when it is on an organization the
   caller actively administers, or when it is the caller's own user account.
   Anything else -- including target types we do not understand, such as
   Enterprise -- is refused. *)
let provable_installation_ids ~user_id ~admin_org_ids installations =
  CCList.filter_map
    (fun { github_id; target_id; target_type } ->
      match target_type with
      | "Organization" when CCList.mem ~eq:CCInt.equal target_id admin_org_ids -> Some github_id
      | "User" when target_id = user_id -> Some github_id
      | "Organization" | "User" | _ -> None)
    installations

(* One round trip's worth of proof: exchange the code, then ask GitHub who this
   is and what they administer. The token is used and dropped; nothing about it
   is persisted. *)
let prove ~config code =
  let open Abbs_fc.Infix_result_monad in
  exchange_code ~config code
  >>= fun token ->
  authenticated_user_id ~config token
  >>= fun user_id ->
  admin_org_ids ~config token
  >>= fun admin_org_ids ->
  user_installations ~config token
  >>| fun installations -> provable_installation_ids ~user_id ~admin_org_ids installations

module Tests = struct
  let provable_installation_ids = provable_installation_ids
  let installation ~github_id ~target_id ~target_type = { github_id; target_id; target_type }
end
