let src = Logs.Src.create "oauth2_htp_github"

module Logs = (val Logs.src_log src : Logs.LOG)
module Json = Oauth2_htp_json

type err =
  [ Oauth2_htp_requests.err
  | `Provider_err of string
  | `Unverified_email of string
  ]
[@@deriving show]

let scope = [ "read:user"; "user:email"; "read:org" ]

type t = {
  client_id : string;
  client_secret : string;
  web_base : string;
  api_base : string;
  authorized_orgs : string Sln_list.Non_empty.t;
}

module Endpoints = struct
  type t = {
    web_base : string;
    api_base : string;
  }
end

let base = CCString.rdrop_while (Char.equal '/')

let make ~client_id ~client_secret ~endpoints ~authorized_orgs =
  let { Endpoints.web_base; api_base } = endpoints in
  { client_id; client_secret; web_base = base web_base; api_base = base api_base; authorized_orgs }

let login_url t = t.web_base ^ "/login/oauth/authorize"

(* GitHub refuses an API request that has no User-Agent. *)
let user_agent = ("User-Agent", "Stategraph")

(* The parts of GitHub's answers that a sign-in reads. *)

module Wire = struct
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

  module Organization = struct
    type t = { login : string } [@@deriving of_yojson { strict = false }]
  end

  module Membership = struct
    type t = {
      state : string;
      organization : Organization.t;
    }
    [@@deriving of_yojson { strict = false }]
  end

  module Team = struct
    module Parent = struct
      type t = { slug : string } [@@deriving of_yojson { strict = false }]
    end

    type t = {
      slug : string;
      organization : Organization.t;
      parent : Parent.t option; [@default None]
    }
    [@@deriving of_yojson { strict = false }]
  end
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
      | { Wire.Token_response.access_token = Some access_token; error = _; error_description = _ }
        when Sln_string.is_non_empty access_token -> Ok access_token
      | { Wire.Token_response.access_token = _; error = Some error; error_description } ->
          let description = CCOption.map_or ~default:"" (fun d -> " " ^ d) error_description in
          Error (`Provider_err (Printf.sprintf "GitHub refused the code: %s%s" error description))
      | { Wire.Token_response.access_token = _; error = None; error_description = _ } ->
          Error
            (`Provider_err
               "GitHub answered the token request with neither an access token nor an error"))
    (decode "/login/oauth/access_token" Wire.Token_response.of_yojson json)

let github_error_message body =
  match Yojson.Safe.from_string body with
  | `Assoc _ as json -> (
      match Yojson.Safe.Util.member "message" json with
      | `String message -> message
      | _ -> body)
  | _ -> body
  | exception Yojson.Json_error _ -> body

let get ~access_token ~api_base path params =
  let open Abb.Future.Infix_monad in
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
    (api_base ^ path ^ suffix)
  >>| CCResult.map_err (function
    | `Unexpected_status (status, body) ->
        let message = github_error_message body in
        let detail = if message = "" then "" else ": " ^ message in
        `Provider_err (Printf.sprintf "GitHub API request %s returned HTTP %d%s" path status detail)
    | #Oauth2_htp_requests.err as err -> err)

let per_page = 100

(* The items of a list endpoint, read with [of_yojson] page by page until a page is not full. *)
let get_all ~access_token ~api_base ~of_yojson path params =
  let open Abbs_fc.Infix_result_monad in
  let rec fetch acc page =
    get
      ~access_token
      ~api_base
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
  get ~access_token ~api_base:t.api_base "/user" []
  >>? fun json ->
  CCResult.map
    (fun { Wire.User.id; avatar_url } ->
      (CCInt.to_string id, CCOption.filter Sln_string.is_non_empty (Some avatar_url)))
    (decode "/user" Wire.User.of_yojson json)

let primary_email ~access_token t =
  let open Abbs_fc.Infix_result_monad in
  get_all ~access_token ~api_base:t.api_base ~of_yojson:Wire.Email.of_yojson "/user/emails" []
  >>? fun emails ->
  match CCList.find_opt (fun email -> email.Wire.Email.primary) emails with
  | Some { Wire.Email.email; primary = _; verified = true } -> Ok email
  | Some { Wire.Email.email; primary = _; verified = false } -> Error (`Unverified_email email)
  | None -> Error (`Provider_err "the GitHub user has no primary email")

module Groups = struct
  module Team = struct
    type t = {
      org : string;
      slug : string;
    }

    let compare { org; slug } { org = org'; slug = slug' } =
      match CCString.compare org org' with
      | 0 -> CCString.compare slug slug'
      | order -> order
  end

  type t = {
    organizations : string list;
    teams : Team.t list;
  }

  (* The prefix tells a GitHub group from the groups of another provider in a group rule. *)
  let prefix = "github:"

  let to_github_prefixed_list { organizations; teams } =
    CCList.map (fun org -> prefix ^ org) organizations
    @ CCList.map (fun { Team.org; slug } -> prefix ^ org ^ "/" ^ slug) teams
end

module Team_set = CCSet.Make (Groups.Team)

(* [state=active] leaves out pending invitations. The state is checked again on each membership, so
   an invitation is never counted as a membership. *)
let org_logins ~access_token ~api_base =
  let open Abbs_fc.Infix_result_monad in
  get_all
    ~access_token
    ~api_base
    ~of_yojson:Wire.Membership.of_yojson
    "/user/memberships/orgs"
    [ ("state", [ "active" ]) ]
  >>| CCList.filter_map (function
    | { Wire.Membership.state = "active"; organization = { Wire.Organization.login } } -> Some login
    | { Wire.Membership.state = _; organization = _ } -> None)

let team_of_answer { Wire.Team.slug; organization = { Wire.Organization.login }; parent = _ } =
  { Groups.Team.org = login; slug }

(* A team and its parent belong to the same organization, and GitHub reports the parent without it. *)
let parent_of_answer = function
  | {
      Wire.Team.slug = _;
      organization = { Wire.Organization.login };
      parent = Some { Wire.Team.Parent.slug };
    } -> Some { Groups.Team.org = login; slug }
  | { Wire.Team.slug = _; organization = _; parent = None } -> None

(* [/user/teams] lists the teams the user is a direct member of, and each with its parent only, not
   the parent of the parent. So the walk goes one level per round: it reads the parents that are not
   in [seen], adds them to [seen] so that no team is read twice, and stops when a round has no parent
   left to read. *)
let rec with_ancestors ~access_token ~api_base ~seen answers =
  let open Abbs_fc.Infix_result_monad in
  let unseen = Team_set.diff (Team_set.of_list (CCList.filter_map parent_of_answer answers)) seen in
  match Team_set.to_list unseen with
  | [] -> Abb.Future.return (Ok seen)
  | parents ->
      Abbs_fc.List_result.map
        ~f:(fun { Groups.Team.org; slug } ->
          let path = Printf.sprintf "/orgs/%s/teams/%s" org slug in
          get ~access_token ~api_base path [] >>? decode path Wire.Team.of_yojson)
        parents
      >>= with_ancestors ~access_token ~api_base ~seen:(Team_set.union seen unseen)

let user_teams ~access_token ~api_base ~authorized_orgs =
  let open Abbs_fc.Infix_result_monad in
  let orgs_list = Sln_list.Non_empty.to_list authorized_orgs in
  let allowed { Wire.Team.slug = _; organization = { Wire.Organization.login }; parent = _ } =
    CCList.mem ~eq:CCString.equal_caseless login orgs_list
  in
  get_all ~access_token ~api_base ~of_yojson:Wire.Team.of_yojson "/user/teams" []
  >>= fun answers ->
  let answers = CCList.filter allowed answers in
  let seen = Team_set.of_list (CCList.map team_of_answer answers) in
  with_ancestors ~access_token ~api_base ~seen answers >>| Team_set.to_list

let groups ~access_token ~api_base ~authorized_orgs ~user =
  let open Abbs_fc.Infix_result_monad in
  let api_base = base api_base in
  org_logins ~access_token ~api_base
  >>= fun organizations ->
  let open Abb.Future.Infix_monad in
  user_teams ~access_token ~api_base ~authorized_orgs
  >>= fun teams ->
  Abbs_fc.when_err
    (fun err ->
      Logs.err (fun m ->
          m
            "Failed to read the GitHub teams for %s, so the groups are the organizations only: %a"
            user
            pp_err
            err);
      Abb.Future.return ())
    teams
  >>| fun () -> Ok { Groups.organizations; teams = CCResult.get_or ~default:[] teams }

module Redeemed = struct
  type t = {
    user : string;
    email : string;
    groups : Groups.t option;
    avatar_url : string option;
    access_token : string;
  }
end

let redeem ~redirect_uri ~code t =
  let open Abbs_fc.Infix_result_monad in
  access_token ~redirect_uri ~code t
  >>= fun access_token ->
  user_profile ~access_token t
  >>= fun (user, avatar_url) ->
  primary_email ~access_token t
  >>= fun email ->
  let open Abb.Future.Infix_monad in
  groups ~access_token ~api_base:t.api_base ~authorized_orgs:t.authorized_orgs ~user:email
  >>| fun groups ->
  Ok
    {
      Redeemed.user;
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

let authorize t { Redeemed.user = _; email; groups; avatar_url = _; access_token = _ } =
  let authorized_orgs = Sln_list.Non_empty.to_list t.authorized_orgs in
  let member organizations org = CCList.mem ~eq:CCString.equal_caseless org organizations in
  match groups with
  | Some { Groups.organizations; teams = _ }
    when CCList.exists (member organizations) authorized_orgs -> true
  | Some _ ->
      Logs.warn (fun m ->
          m
            "%s is not an active member of %s. An organization that restricts OAuth App access \
             shows its members only after an owner of the organization approves the OAuth App"
            email
            (CCString.concat ", " authorized_orgs));
      false
  | None -> false

let session { Redeemed.user; email; groups; avatar_url; access_token } =
  {
    Oauth2_htp_session.user;
    email;
    groups = CCOption.map Groups.to_github_prefixed_list groups;
    avatar_url;
    access_token;
  }

(* Constructors that only a test needs; the provider builds its values from GitHub's answers. *)
module Tests = struct
  let team ~org ~slug = { Groups.Team.org; slug }
end
