module Http = Abb_curl.Make (Abb)

module Stored = struct
  type t = {
    id : int64;
    slug : string;
    client_id : string;
    client_secret : string;
    html_url : string;
    created_at : string;
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
      (* created_at *)
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

  let delete_app () =
    Pgsql_io.Typed_sql.(sql /^ read [%blob "sql/delete_github_app.sql"] /% Var.bigint "app_id")

  let delete_any () = Pgsql_io.Typed_sql.(sql /^ read [%blob "sql/delete_any_github_app.sql"])

  let update_pem () =
    Pgsql_io.Typed_sql.(
      sql /^ read [%blob "sql/update_github_app_pem.sql"] /% Var.text "pem" /% Var.bigint "app_id")

  let update_client_secret () =
    Pgsql_io.Typed_sql.(
      sql
      /^ read [%blob "sql/update_github_app_client_secret.sql"]
      /% Var.text "client_secret"
      /% Var.bigint "app_id")

  let update_webhook_secret () =
    Pgsql_io.Typed_sql.(
      sql
      /^ read [%blob "sql/update_github_app_webhook_secret.sql"]
      /% Var.text "webhook_secret"
      /% Var.bigint "app_id")
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
    ~f:(fun id slug client_id client_secret html_url created_at loaded ->
      { Stored.id; slug; client_id; client_secret; html_url; created_at; loaded })
  >>| function
  | Ok [] -> Ok None
  | Ok (stored :: _) -> Ok (Some stored)
  | Error (#Pgsql_io.err as err) -> Error err

(* A key the engine cannot decode leaves it with no GitHub service, so the key
   is decoded here, before it is stored. *)
let rsa_pem pem =
  match X509.Private_key.decode_pem pem with
  | Ok (`RSA _) -> true
  | Ok _ | Error (`Msg _) -> false

type write_err =
  [ Pgsql_io.err
  | `Conflict_err
  ]
[@@deriving show]

type credentials = {
  pem : string option;
  client_secret : string option;
  webhook_secret : string option;
}

type credentials_err =
  [ Pgsql_io.err
  | `Bad_pem_err
  | `No_credential_err
  ]
[@@deriving show]

(* Delete then insert, in one transaction: postgres_fdw opens one remote session
   per (server, mapping), so both statements share one remote transaction and no
   reader sees the table empty. It has to be atomic. GitHub shows a private key
   once, so a replace that deleted and then failed to insert would lose the key
   for good. ON CONFLICT is not supported on a foreign table, which is why this
   is not an upsert.

   Two callbacks can still race: the second delete does not see the first
   insert, and the singleton index then refuses the second insert. That is
   [`Conflict_err], and the loser changes nothing. *)
let replace created db =
  let open Abb.Future.Infix_monad in
  let { Created.id; slug; pem; client_id; client_secret; webhook_secret; html_url } = created in
  Pgsql_io.tx db ~f:(fun () ->
      let open Abbs_fc.Infix_result_monad in
      Pgsql_io.Prepared_stmt.execute db (Sql.delete_any ())
      >>= fun () ->
      Pgsql_io.Prepared_stmt.execute
        db
        (Sql.insert_app ())
        id
        slug
        pem
        client_id
        client_secret
        webhook_secret
        html_url)
  >>| function
  | Ok () -> Ok ()
  | Error (`Unique_violation_err _) -> Error `Conflict_err
  | Error (#Pgsql_io.err as err) -> Error err

(* Every write the console makes to one App reads it first, in the same
   transaction, and the write itself names the id: the read decides whether this
   is the App the operator confirmed, and the bound means a replace landing in
   between is not the row written. Both live here so neither endpoint can hold
   half the invariant. *)
type on_app =
  [ `Written
  | `Not_found
  | `Mismatch
  ]

let on_app ~app_id ~f db =
  let open Abb.Future.Infix_monad in
  Pgsql_io.tx db ~f:(fun () ->
      let open Abbs_fc.Infix_result_monad in
      select db
      >>= function
      | None -> Abb.Future.return (Ok `Not_found)
      | Some
          {
            Stored.id;
            slug = _;
            client_id = _;
            client_secret = _;
            html_url = _;
            created_at = _;
            loaded = _;
          }
        when not (Int64.equal id app_id) -> Abb.Future.return (Ok `Mismatch)
      | Some _ -> f () >>| fun () -> `Written)
  >>| function
  | Ok outcome -> Ok outcome
  | Error (#Pgsql_io.err as err) -> Error err

let delete ~app_id db =
  on_app ~app_id db ~f:(fun () -> Pgsql_io.Prepared_stmt.execute db (Sql.delete_app ()) app_id)

(* One UPDATE per supplied field, each assigning a constant, which keeps
   postgres_fdw on its direct-modify path: the other path issues a SELECT FOR
   UPDATE over every declared column, and the provisioner role reads neither the
   key nor the webhook secret. [on_app] runs them in one transaction, and
   postgres_fdw carries that to one remote transaction, so the row takes all of
   them or none. Clearing loaded_at is what stops the console claiming the engine
   holds credentials it has not read yet. *)
let update_credentials ~app_id ~credentials db =
  let { pem; client_secret; webhook_secret } = credentials in
  match (pem, client_secret, webhook_secret) with
  | None, None, None -> Abb.Future.return (Error `No_credential_err)
  | Some pem, _, _ when not (rsa_pem pem) -> Abb.Future.return (Error `Bad_pem_err)
  | _ ->
      on_app ~app_id db ~f:(fun () ->
          let open Abbs_fc.Infix_result_monad in
          let write stmt = function
            | None -> Abb.Future.return (Ok ())
            | Some value -> Pgsql_io.Prepared_stmt.execute db stmt value app_id
          in
          write (Sql.update_pem ()) pem
          >>= fun () ->
          write (Sql.update_client_secret ()) client_secret
          >>= fun () -> write (Sql.update_webhook_secret ()) webhook_secret)

let status_of ~env_app_id ~stored =
  match (env_app_id, stored) with
  | Some _, _ -> { configured = true; ready = true }
  | None, Some { Stored.loaded; _ } -> { configured = true; ready = loaded }
  | None, None -> { configured = false; ready = false }

let source_of ~env_app_id ~readable ~stored =
  match (env_app_id, stored) with
  | Some _, _ -> `Environment
  | None, Some _ -> `Stored
  (* No row and no way to read one are different answers. The engine may be
     serving an App this server can no longer see, so saying "none" would send
     the operator off to create a second one. *)
  | None, None -> if readable then `None else `Unknown

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
  rd : string option;
}

type create_err =
  [ `Bad_state_err of Sgs_service_orchestration_github_claim_token.verify_err
  | `Convert_err of convert_err
  | write_err
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
  | Ok
      {
        Sgs_service_orchestration_github_claim_token.Manifest.user_id;
        replace = may_replace;
        rd;
        exp = _;
      } -> (
      (* The token says whether the operator meant to replace. A state minted
         when this server had no App must not overwrite one stored since, which
         would destroy a key GitHub shows once. Checked before the code is
         converted, so a refusal also leaves no App stranded on GitHub. *)
      select db
      >>= function
      | Error (#Pgsql_io.err as err) -> Abb.Future.return (Error err)
      | Ok (Some _) when not may_replace -> Abb.Future.return (Error `Conflict_err)
      | Ok _ -> (
          convert code
          >>= function
          | Error (#convert_err as err) -> Abb.Future.return (Error (`Convert_err err))
          | Ok created -> (
              replace created db
              >>| function
              | Ok () ->
                  Ok { user_id; app_id = created.Created.id; slug = created.Created.slug; rd }
              | Error (#write_err as err) -> Error err)))
