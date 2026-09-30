module Http = Abb_curl.Make (Abb)

module Stored = struct
  type t = {
    id : int64;
    slug : string;
    client_id : string;
    client_secret : string;
    html_url : string;
    loaded : bool;
  }
end

module Created = struct
  type t = {
    id : int64;
    slug : string;
    pem : string;
    client_id : string;
    client_secret : string;
    webhook_secret : string;
    html_url : string;
  }
end

type status = {
  configured : bool;
  ready : bool;
}

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_app () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.bigint
      //
      (* slug *)
      Ret.text
      //
      (* client_id *)
      Ret.text
      //
      (* client_secret *)
      Ret.text
      //
      (* html_url *)
      Ret.text
      //
      (* loaded *)
      Ret.boolean
      /^ read [%blob "sql/select_github_app.sql"])

  let insert_app () =
    Pgsql_io.Typed_sql.(
      sql
      /^ read [%blob "sql/insert_github_app.sql"]
      /% Var.bigint "id"
      /% Var.text "slug"
      /% Var.text "pem"
      /% Var.text "client_id"
      /% Var.text "client_secret"
      /% Var.text "webhook_secret"
      /% Var.text "html_url")
end

(* The environment wins, so an App named there closes the channel: creating one
   from the console would store an App the engine ignores, and reading the row
   would answer a question the environment has already answered.

   A deployment that supplies the App itself for every tenant closes it too, so
   that a stored App is never a second App nobody asked for. *)
let channel_available config =
  CCOption.is_none (Sgs_config.github_app_id config)
  && (not (Sgs_config.github_app_managed config))
  && Sgs_config.orchestration_enabled config
  && CCOption.is_some (Sgs_config.fdw_provisioner_password config)

let select db =
  let open Abb.Future.Infix_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_app ())
    ~f:(fun id slug client_id client_secret html_url loaded ->
      { Stored.id; slug; client_id; client_secret; html_url; loaded })
  >>| function
  | Ok [] -> Ok None
  | Ok (stored :: _) -> Ok (Some stored)
  | Error (#Pgsql_io.err as err) -> Error err

type insert_err =
  [ Pgsql_io.err
  | `Already_created_err
  ]
[@@deriving show]

let insert created db =
  let open Abb.Future.Infix_monad in
  let { Created.id; slug; pem; client_id; client_secret; webhook_secret; html_url } = created in
  Pgsql_io.Prepared_stmt.execute
    db
    (Sql.insert_app ())
    id
    slug
    pem
    client_id
    client_secret
    webhook_secret
    html_url
  >>| function
  | Ok () -> Ok ()
  | Error (`Unique_violation_err _) -> Error `Already_created_err
  | Error (#Pgsql_io.err as err) -> Error err

let status_of ~env_app_id ~stored =
  match (env_app_id, stored) with
  | Some _, _ -> { configured = true; ready = true }
  | None, Some { Stored.loaded; _ } -> { configured = true; ready = loaded }
  | None, None -> { configured = false; ready = false }

let app_url_of ~env_app_url ~stored =
  CCOption.or_ ~else_:(CCOption.map (fun { Stored.html_url; _ } -> html_url) stored) env_app_url

let oauth_of config ~stored =
  CCOption.or_
    ~else_:
      (CCOption.map
         (fun { Stored.client_id; client_secret; _ } ->
           Sgs_config.make_github_oauth config ~client_id ~client_secret)
         stored)
    (Sgs_config.github_oauth config)

let stored config db = if channel_available config then select db else Abb.Future.return (Ok None)

let oauth config db =
  let open Abb.Future.Infix_monad in
  stored config db >>| CCResult.map (fun stored -> oauth_of config ~stored)

(* GitHub is told this path when the App is created, and the claim handshake
   sends the browser to it, so a move of the route moves both. *)
let claim_callback_path = "/api/v1/vcs-installations/github/claim/callback"

module Manifest = struct
  module Hook = struct
    type t = {
      url : string;
      active : bool;
    }
    [@@deriving to_yojson]
  end

  module Permissions = struct
    type t = {
      actions : string;
      checks : string;
      contents : string;
      emails : string;
      issues : string;
      members : string;
      metadata : string;
      pull_requests : string;
      secrets : string;
      statuses : string;
      workflows : string;
    }
    [@@deriving to_yojson]
  end

  type t = {
    callback_urls : string list;
    default_events : string list;
    default_permissions : Permissions.t;
    description : string;
    hook_attributes : Hook.t;
    name : string;
    public : bool;
    redirect_url : string;
    request_oauth_on_install : bool;
    setup_url : string;
    url : string;
  }
  [@@deriving to_yojson]

  type form = {
    action_url : string;
    manifest : string;
  }

  (* The setup container's orchestration/setup/app.yml asks GitHub for the same
     permissions and events; code/tests/sgs_github_app asserts they agree. *)
  let events =
    [
      "issue_comment";
      "issues";
      "pull_request";
      "pull_request_review";
      "pull_request_review_comment";
      "push";
      "workflow_job";
      "workflow_run";
    ]

  let permissions =
    {
      Permissions.actions = "write";
      checks = "read";
      contents = "write";
      emails = "read";
      issues = "write";
      members = "read";
      metadata = "read";
      pull_requests = "write";
      secrets = "write";
      statuses = "write";
      workflows = "write";
    }

  let description =
    "Stategraph Orchestration is the flexible GitOps orchestration engine for Terraform, OpenTofu, \
     CDKTF, Terragrunt, and Pulumi."

  (* GitHub limits an App name to 34 characters. *)
  let name_max = 34

  let is_login_char = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' -> true
    | _ -> false

  let validate ~name ~organization =
    let name = CCString.trim name in
    let organization =
      CCOption.map CCString.trim organization
      |> CCOption.filter (fun s -> not (CCString.is_empty s))
    in
    if CCString.is_empty name || CCString.length name > name_max then Error `Bad_name_err
    else
      match organization with
      | Some org when not (CCString.for_all is_login_char org) -> Error `Bad_organization_err
      | Some _ | None -> Ok (name, organization)

  let build ~ui_base ~terrat_api_base ~redirect_base ~web_base ~name ~organization ~state =
    let claim_callback = redirect_base ^ claim_callback_path in
    let manifest =
      {
        callback_urls = [ claim_callback; terrat_api_base ^ "/github/v1/callback" ];
        default_events = events;
        default_permissions = permissions;
        description;
        hook_attributes = { Hook.url = terrat_api_base ^ "/github/v1/events"; active = true };
        name;
        public = false;
        redirect_url = redirect_base ^ "/api/v1/setup/github-app/callback";
        request_oauth_on_install = true;
        setup_url = claim_callback;
        url = ui_base;
      }
    in
    let path =
      match organization with
      | None -> "/settings/apps/new"
      | Some org ->
          Printf.sprintf "/organizations/%s/settings/apps/new" (Uri.pct_encode ~component:`Path org)
    in
    {
      action_url =
        Printf.sprintf "%s%s?state=%s" web_base path (Uri.pct_encode ~component:`Query_value state);
      manifest = Yojson.Safe.to_string (to_yojson manifest);
    }
end

type convert_err =
  [ `Conversion_failed_err of int
  | `Conversion_bad_response_err
  | Http.request_err
  ]
[@@deriving show]

(* The engine decodes the PEM at boot, and a row it cannot decode makes it exit
   non-zero on every start; the row is a singleton, so nothing could replace it.
   So the key is decoded here, before it is stored. *)
let rsa_pem pem =
  match X509.Private_key.decode_pem pem with
  | Ok (`RSA _) -> true
  | Ok _ | Error (`Msg _) -> false

let user_agent = "Stategraph"

(* The conversion takes no authentication: the code is the credential. The
   body is dropped on a failure because it can echo the code. *)
let convert ~api_base code =
  let open Abb.Future.Infix_monad in
  let headers =
    Http.Headers.of_list
      [
        ("user-agent", user_agent);
        ("accept", "application/vnd.github+json");
        ("content-type", "application/json");
      ]
  in
  let uri =
    Uri.of_string
      (Printf.sprintf
         "%s/app-manifests/%s/conversions"
         api_base
         (Uri.pct_encode ~component:`Path code))
  in
  Http.post ~headers ~body:"" uri
  >>| function
  | Ok (resp, body) when Http.Status.is_success (Http.Response.status resp) -> (
      let module Created_resp = Githubc2_apps.Create_from_manifest.Responses.Created in
      match Created_resp.of_yojson (Yojson.Safe.from_string body) with
      | Ok v -> (
          let p = v.Created_resp.T.primary in
          let open Created_resp.T.Primary in
          match (p.slug, p.webhook_secret) with
          | Some slug, Some webhook_secret when rsa_pem p.pem ->
              Ok
                {
                  Created.id = Int64.of_int p.id;
                  slug;
                  pem = p.pem;
                  client_id = p.client_id;
                  client_secret = p.client_secret;
                  webhook_secret;
                  html_url = p.html_url;
                }
          | Some _, Some _ | None, _ | _, None -> Error `Conversion_bad_response_err)
      | Error _ | (exception Yojson.Json_error _) -> Error `Conversion_bad_response_err)
  | Ok (resp, _) -> Error (`Conversion_failed_err (Http.Status.to_int (Http.Response.status resp)))
  | Error (#Http.request_err as err) -> Error err

type created = {
  user_id : string;
  app_id : int64;
  slug : string;
}

type create_err =
  [ `Bad_state_err of Sgs_service_orchestration_github_claim_token.verify_err
  | `Convert_err of convert_err
  | insert_err
  ]
[@@deriving show]

let create_from_code ~convert ~keys ~now ~state ~code db =
  let open Abb.Future.Infix_monad in
  match
    Sgs_service_orchestration_github_claim_token.Manifest.verify
      ~verifiers:(Sgs_user_session.Session.Keys.rs256_verifiers keys)
      ~now
      state
  with
  | Error (#Sgs_service_orchestration_github_claim_token.verify_err as err) ->
      Abb.Future.return (Error (`Bad_state_err err))
  | Ok { Sgs_service_orchestration_github_claim_token.Manifest.user_id; exp = _ } -> (
      convert code
      >>= function
      | Error (#convert_err as err) -> Abb.Future.return (Error (`Convert_err err))
      | Ok created -> (
          insert created db
          >>| function
          | Ok () -> Ok { user_id; app_id = created.Created.id; slug = created.Created.slug }
          | Error (#insert_err as err) -> Error err))
