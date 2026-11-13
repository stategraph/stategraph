let src = Logs.Src.create "oauth2_htp_github"

module Logs = (val Logs.src_log src : Logs.LOG)
module Json = Oauth2_htp_json

type err =
  [ Oauth2_htp_requests.err
  | `Provider_err of string
  | `Unverified_email of string
  ]
[@@deriving show]

let scope = "read:user user:email read:org"

type t = {
  client_id : string;
  client_secret : string;
  web_base : string;
  api_base : string;
  orgs : string Sln_list.Non_empty.t;
}

module Endpoints = struct
  type t = {
    web_base : string;
    api_base : string;
  }
end

let make ~client_id ~client_secret ~endpoints ~orgs =
  let { Endpoints.web_base; api_base } = endpoints in
  let base = CCString.rdrop_while (Char.equal '/') in
  { client_id; client_secret; web_base = base web_base; api_base = base api_base; orgs }

let login_url t = t.web_base ^ "/login/oauth/authorize"

(* GitHub refuses an API request that has no User-Agent. *)
let user_agent = ("User-Agent", "Stategraph")

(* The parts of GitHub's answers that a sign-in reads. *)

module Token_response = struct
  type t = {
    access_token : string option; [@default None]
    error : string option; [@default None]
    error_description : string option; [@default None]
  }
  [@@deriving of_yojson { strict = false }]
end

module User = struct
  type t = {
    id : int;
    avatar_url : string;
  }
  [@@deriving of_yojson { strict = false }]
end

module Email = struct
  type t = {
    email : string;
    primary : bool;
    verified : bool;
  }
  [@@deriving of_yojson { strict = false }]
end

module Membership = struct
  module Organization = struct
    type t = { login : string } [@@deriving of_yojson { strict = false }]
  end

  type t = {
    state : string;
    organization : Organization.t;
  }
  [@@deriving of_yojson { strict = false }]
end

let decode what of_yojson json =
  CCResult.map_err
    (fun msg -> `Provider_err (Printf.sprintf "%s: unexpected GitHub answer: %s" what msg))
    (of_yojson json)

(* Without [Accept: application/json] the token endpoint answers with a form encoded body. A code it
   refuses gets a 200 with an [error] and no [access_token]. *)
let access_token ~redirect_uri ~code t =
  let open Abbs_fc.Infix_result_monad in
  Oauth2_htp_requests.post_form
    ~headers:[ ("Accept", "application/json"); user_agent ]
    (t.web_base ^ "/login/oauth/access_token")
    [
      ("client_id", [ t.client_id ]);
      ("client_secret", [ t.client_secret ]);
      ("code", [ code ]);
      ("redirect_uri", [ redirect_uri ]);
    ]
  >>? fun json ->
  CCResult.flat_map
    (function
      | { Token_response.access_token = Some access_token; error = _; error_description = _ }
        when Sln_string.is_non_empty access_token -> Ok access_token
      | { Token_response.access_token = _; error = Some error; error_description } ->
          let description = CCOption.map_or ~default:"" (fun d -> " " ^ d) error_description in
          Error (`Provider_err (Printf.sprintf "GitHub refused the code: %s%s" error description))
      | { Token_response.access_token = _; error = None; error_description = _ } ->
          Error
            (`Provider_err
               "GitHub answered the token request with neither an access token nor an error"))
    (decode "/login/oauth/access_token" Token_response.of_yojson json)

let get ~access_token t path params =
  let suffix =
    match params with
    | [] -> ""
    | params -> "?" ^ Oauth2_htp_values.encode params
  in
  Oauth2_htp_requests.unmarshal
    ~headers:
      [
        ("Authorization", "Bearer " ^ access_token);
        ("Accept", "application/vnd.github+json");
        user_agent;
      ]
    (t.api_base ^ path ^ suffix)

let per_page = 100

(* The items of a list endpoint, read with [of_yojson] page by page until a page is not full. *)
let get_all ~access_token ~of_yojson t path params =
  let open Abbs_fc.Infix_result_monad in
  let rec fetch acc page =
    get
      ~access_token
      t
      path
      (params @ [ ("per_page", [ CCInt.to_string per_page ]); ("page", [ CCInt.to_string page ]) ])
    >>= fun json ->
    match Json.list json with
    | Some items -> (
        match CCResult.map_l (decode path of_yojson) items with
        | Ok decoded when CCList.length items < per_page -> Abb.Future.return (Ok (acc @ decoded))
        | Ok decoded -> fetch (acc @ decoded) (page + 1)
        | Error _ as err -> Abb.Future.return err)
    | None -> Abb.Future.return (Error (`Provider_err (path ^ ": GitHub did not answer a list")))
  in
  fetch [] 1

(* The user's numeric id and avatar URL. *)
let user_profile ~access_token t =
  let open Abbs_fc.Infix_result_monad in
  get ~access_token t "/user" []
  >>? fun json ->
  CCResult.map
    (fun { User.id; avatar_url } ->
      (CCInt.to_string id, CCOption.filter Sln_string.is_non_empty (Some avatar_url)))
    (decode "/user" User.of_yojson json)

let primary_email ~access_token t =
  let open Abbs_fc.Infix_result_monad in
  get_all ~access_token ~of_yojson:Email.of_yojson t "/user/emails" []
  >>? fun emails ->
  match CCList.find_opt (fun email -> email.Email.primary) emails with
  | Some { Email.email; primary = _; verified = true } -> Ok email
  | Some { Email.email; primary = _; verified = false } -> Error (`Unverified_email email)
  | None -> Error (`Provider_err "the GitHub user has no primary email")

(* [state=active] leaves out pending invitations. The state is checked again on each membership, so
   an invitation is never counted as a membership. *)
let org_logins ~access_token t =
  let open Abbs_fc.Infix_result_monad in
  get_all
    ~access_token
    ~of_yojson:Membership.of_yojson
    t
    "/user/memberships/orgs"
    [ ("state", [ "active" ]) ]
  >>| CCList.filter_map (function
    | { Membership.state = "active"; organization = { Membership.Organization.login } } ->
        Some login
    | { Membership.state = _; organization = _ } -> None)

let redeem ~redirect_uri ~code t =
  let open Abbs_fc.Infix_result_monad in
  access_token ~redirect_uri ~code t
  >>= fun access_token ->
  user_profile ~access_token t
  >>= fun (user, avatar_url) ->
  primary_email ~access_token t
  >>= fun email ->
  let open Abb.Future.Infix_monad in
  org_logins ~access_token t
  >>| fun groups ->
  Ok
    {
      Oauth2_htp_session.user;
      email;
      groups =
        (match groups with
        | Ok groups -> Some groups
        | Error err ->
            Logs.err (fun m ->
                m "Failed to read the GitHub organizations of %s: %a" email pp_err err);
            None);
      avatar_url;
      access_token;
    }

let authorize t session =
  let orgs = Sln_list.Non_empty.to_list t.orgs in
  let member groups org = CCList.mem ~eq:CCString.equal_caseless org groups in
  match session.Oauth2_htp_session.groups with
  | Some groups when CCList.exists (member groups) orgs -> true
  | Some _ ->
      Logs.warn (fun m ->
          m
            "%s is not an active member of %s. An organization that restricts OAuth App access \
             shows its members only after an owner of the organization approves the OAuth App"
            session.Oauth2_htp_session.email
            (CCString.concat ", " orgs));
      false
  | None -> false
