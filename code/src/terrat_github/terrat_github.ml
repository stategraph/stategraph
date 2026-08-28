let src = Logs.Src.create "terrat_github"

module Logs = (val Logs.src_log src : Logs.LOG)

let thirty_seconds = Duration.(to_f (of_sec 30))
let three_minutes = Duration.(to_f (of_min 3))
let terrateam_workflow_name = "Terrateam Workflow"
let terrateam_workflow_path = ".github/workflows/terrateam.yml"
let installation_expiration_sec = three_minutes

module Metrics = struct
  module Call_retry_wait_histograph = Prmths.Histogram (struct
    let spec = Prmths.Histogram_spec.of_exponential ~start:30.0 ~factor:1.2 ~count:20
  end)

  module Rate_limit_remaining_histograph = Prmths.Histogram (struct
    let spec =
      Prmths.Histogram_spec.of_list
        [ 100.0; 500.0; 1000.0; 2000.0; 3000.0; 4000.0; 5000.0; 6000.0; 10000.0 ]
  end)

  let namespace = "terrat"
  let subsystem = "github"

  let call_retries_total =
    let help = "Number of retries in a call" in
    Prmths.Counter.v ~help ~namespace ~subsystem "call_retries_total"

  let rate_limit_retry_wait_seconds =
    let help = "Number of seconds a call has spent waiting due to rate limit" in
    Call_retry_wait_histograph.v ~help ~namespace ~subsystem "rate_limit_retry_wait_seconds"

  let rate_limit_remaining_count =
    let help = "Number of calls remaining in the rate limit window." in
    Rate_limit_remaining_histograph.v ~help ~namespace ~subsystem "rate_limit_remaining_count"

  let fn_call_total =
    let help = "Number of calls of a function" in
    Prmths.Counter.v_label ~label_name:"fn" ~help ~namespace ~subsystem "fn_call_total"
end

type user_err =
  [ Githubc2_abb.call_err
  | `Unauthorized of Githubc2_components.Basic_error.t
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_modified
  | `Unauthorized of Githubc2_components.Basic_error.t
  ]
[@@deriving show]

type get_installation_access_token_err =
  [ Githubc2_abb.call_err
  | `Unauthorized of Githubc2_components.Basic_error.t
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_found of Githubc2_components.Basic_error.t
  | `Unprocessable_entity of Githubc2_components.Validation_error.t
  ]
[@@deriving show]

type get_user_installations_err =
  [ Githubc2_abb.call_err
  | `Unauthorized of Githubc2_components.Basic_error.t
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_modified
  ]
[@@deriving show]

type get_installation_repos_err =
  [ Githubc2_abb.call_err
  | `Not_modified
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_found of Githubc2_components.Basic_error.t
  | `Unauthorized of Githubc2_components.Basic_error.t
  ]
[@@deriving show]

type fetch_file_err =
  [ Githubc2_abb.call_err
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Found
  | `Not_file
  | `Not_modified
  ]
[@@deriving show]

type fetch_pull_request_err =
  [ Githubc2_abb.call_err
  | `Not_modified
  | `Not_found of Githubc2_components.Basic_error.t
  | `Not_acceptable of Githubc2_components.Basic_error.t
  | `Internal_server_error of Githubc2_components.Basic_error.t
  | `Service_unavailable of Githubc2_pulls.Get.Responses.Service_unavailable.t
  ]
[@@deriving show]

type fetch_diff_files_err =
  [ Githubc2_abb.call_err
  | `Not_found of Githubc2_components.Basic_error.t
  | `Internal_server_error of Githubc2_components.Basic_error.t
  ]
[@@deriving show]

type fetch_repo_err =
  [ Githubc2_abb.call_err
  | `Moved_permanently of Githubc2_repos.Get.Responses.Moved_permanently.t
  | `Forbidden of Githubc2_repos.Get.Responses.Forbidden.t
  | `Not_found of Githubc2_repos.Get.Responses.Not_found.t
  ]
[@@deriving show]

type fetch_branch_err =
  [ Githubc2_abb.call_err
  | `Moved_permanently of Githubc2_repos.Get_branch.Responses.Moved_permanently.t
  | `Not_found of Githubc2_repos.Get_branch.Responses.Not_found.t
  ]
[@@deriving show]

type publish_comment_err =
  [ Githubc2_abb.call_err
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_found of Githubc2_components.Basic_error.t
  | `Gone of Githubc2_components.Basic_error.t
  | `Unprocessable_entity of Githubc2_components.Validation_error.t
  ]
[@@deriving show]

type delete_comment_err = Githubc2_abb.call_err [@@deriving show]

type minimize_comment_err =
  [ Githubc2_abb.call_err
  | `Not_found
  ]
[@@deriving show]

type fetch_pull_request_review_decision_err =
  [ Githubc2_abb.call_err
  | `Graphql_err of string list
  | `Not_found
  ]
[@@deriving show]

type publish_reaction_err =
  [ Githubc2_abb.call_err
  | `Unprocessable_entity of Githubc2_components.Validation_error.t
  ]
[@@deriving show]

type get_tree_err =
  [ Githubc2_abb.call_err
  | `Not_found of Githubc2_components.Basic_error.t
  | `Unprocessable_entity of Githubc2_components.Validation_error.t
  | `Conflict of Githubc2_components.Basic_error.t
  ]
[@@deriving show]

type get_team_membership_in_org_err = Githubc2_abb.call_err [@@deriving show]
type get_repo_collaborator_permission_err = Githubc2_abb.call_err [@@deriving show]
type get_org_membership_err = Githubc2_abb.call_err [@@deriving show]

let max_get_tree_chunks = 20

let is_secondary_rate_limit_error resp =
  let headers = Openapi.Response.headers resp in
  let get k = CCList.Assoc.get ~eq:CCString.equal_caseless k headers in
  Openapi.Response.status resp = 403
  &&
  match (get "retry-after", get "x-ratelimit-remaining", get "x-ratelimit-reset") with
  | Some _, _, _ | None, Some "0", Some _ -> true
  | _, _, _ -> false

let rate_limit_wait resp =
  let headers = Openapi.Response.headers resp in
  let get k = CCList.Assoc.get ~eq:CCString.equal_caseless k headers in
  if Openapi.Response.status resp = 403 then
    match (get "retry-after", get "x-ratelimit-remaining", get "x-ratelimit-reset") with
    | (Some ra as retry_after), _, _ ->
        Logs.debug (fun m -> m "RATE_LIMIT : RETRY_AFTER : %s" ra);
        Abb.Future.return
          (CCOption.map_or
             ~default:(Some thirty_seconds)
             CCFun.(CCInt.of_string %> CCOption.map CCFloat.of_int)
             retry_after)
    | None, Some "0", Some retry_time -> (
        Logs.debug (fun m -> m "RATE_LIMIT : RETRY_TIME : %s" retry_time);
        match CCFloat.of_string_opt retry_time with
        | Some retry_time ->
            let open Abb.Future.Infix_monad in
            Abb.Sys.time ()
            >>= fun now ->
            (* Make sure we wait at least one minute before retrying *)
            Abb.Future.return (Some (retry_time -. now))
        | None -> Abb.Future.return (Some thirty_seconds))
    | _, _, _ -> Abb.Future.return None
  else Abb.Future.return None

let get_rate_limit_remaining resp =
  let headers = Openapi.Response.headers resp in
  let get k = CCList.Assoc.get ~eq:CCString.equal_caseless k headers in
  CCOption.map CCFloat.of_int @@ CCOption.flat_map CCInt.of_string @@ get "x-ratelimit-remaining"

let create config auth =
  Githubc2_abb.create
    ~base_url:(Terrat_config.Github.api_base_url config)
    ~user_agent:"Terrateam"
    ~call_timeout:(Terrat_config.Github.call_timeout config)
    auth

let with_client config auth f =
  let client = create config auth in
  f client

let retry_wait default_wait resp =
  let open Abb.Future.Infix_monad in
  (* Get the retry determined by the header *)
  rate_limit_wait resp
  >>= function
  | Some retry_after ->
      Metrics.Call_retry_wait_histograph.observe Metrics.rate_limit_retry_wait_seconds retry_after;
      (* But, we don't want to wait forever, so even though [retry_limit_wait]
         gives us back whatever the API says, we want to put a cap on how long
         we will wait so that we don't hold the system up forever.  If we have
         to wait an hour for the rate limit, then this operation is done
         anyways, so just move on. *)
      Abb.Future.return (CCFloat.min thirty_seconds retry_after)
  | None -> Abb.Future.return default_wait

let call ?(tries = 3) t req =
  Abbs_future_combinators.retry
    ~f:(fun () ->
      let open Abbs_future_combinators.Infix_result_monad in
      Githubc2_abb.call t req
      >>| fun resp ->
      CCOption.iter (fun remaining ->
          Metrics.Rate_limit_remaining_histograph.observe
            Metrics.rate_limit_remaining_count
            remaining)
      @@ get_rate_limit_remaining resp;
      resp)
    ~while_:
      (Abbs_future_combinators.finite_tries tries (function
        | Error _ -> true
        | Ok resp -> Openapi.Response.status resp >= 500 || is_secondary_rate_limit_error resp))
    ~betwixt:
      (Abbs_future_combinators.series ~start:1.5 ~step:(( *. ) 1.5) (fun n resp ->
           Prmths.Counter.inc_one Metrics.call_retries_total;
           (* If it's a rate limit error, sleep until GitHub says we can try
              again *)
           match resp with
           | Error (`Missing_response resp) ->
               let open Abb.Future.Infix_monad in
               retry_wait n resp >>= Abb.Sys.sleep
           | Ok resp ->
               let open Abb.Future.Infix_monad in
               retry_wait n resp >>= Abb.Sys.sleep
           | Error _ -> Abb.Sys.sleep n))

let user ~config ~access_token () =
  let open Abbs_future_combinators.Infix_result_monad in
  Prmths.Counter.inc_one (Metrics.fn_call_total "user");
  let client = create config (`Token access_token) in
  call client (Githubc2_users.Get_authenticated.make ())
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK user -> Ok user
  | (`Forbidden _ | `Not_modified | `Unauthorized _) as err -> Error err

let get_installation_access_token
    ?(expiration_sec = installation_expiration_sec)
    ?permissions
    config
    installation_id =
  Prmths.Counter.inc_one (Metrics.fn_call_total "get_installation_access_token");
  let open Abb.Future.Infix_monad in
  Abb.Sys.time ()
  >>= fun time ->
  let payload =
    let module P = Jwt.Payload in
    let module C = Jwt.Claim in
    P.empty
    |> P.add_claim C.iss (`String (Terrat_config.Github.app_id config))
    |> P.add_claim C.iat (`Int (Float.to_int (time -. expiration_sec)))
    |> P.add_claim C.exp (`Int (Float.to_int (time +. expiration_sec)))
  in
  let signer = Jwt.Signer.(RS256 (Priv_key.of_priv_key (Terrat_config.Github.app_pem config))) in
  let header = Jwt.Header.create (Jwt.Signer.to_string signer) in
  let jwt = Jwt.of_header_and_payload signer header payload in
  let token = Jwt.token jwt in
  let open Abbs_future_combinators.Infix_result_monad in
  let client = create config (`Bearer token) in
  call
    client
    Githubc2_apps.Create_installation_access_token.(
      make
        ~body:Request_body.(make Primary.(make ~permissions ()))
        (Parameters.make ~installation_id))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `Created token ->
      let installation_token = Githubc2_components.Installation_token.value token in
      Ok installation_token.Githubc2_components.Installation_token.Primary.token
  | (`Unauthorized _ | `Forbidden _ | `Not_found _ | `Unprocessable_entity _) as err -> Error err

let fetch_repo ~owner ~repo client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "fetch_repo");
  let open Abbs_future_combinators.Infix_result_monad in
  call client Githubc2_repos.Get.(make (Parameters.make ~owner ~repo))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK repo -> Ok repo
  | (`Forbidden _ | `Moved_permanently _ | `Not_found _) as err -> Error err

let fetch_branch ~owner ~repo ~branch client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "fetch_branch");
  let open Abbs_future_combinators.Infix_result_monad in
  call client Githubc2_repos.Get_branch.(make (Parameters.make ~branch ~owner ~repo))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK branch -> Ok branch
  | (`Moved_permanently _ | `Not_found _) as err -> Error err

let fetch_file ~owner ~repo ~ref_ ~path client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "fetch_file");
  let open Abbs_future_combinators.Infix_result_monad in
  call
    client
    Githubc2_repos.Get_content.(make (Parameters.make ~owner ~repo ~ref_:(Some ref_) ~path ()))
  >>? fun resp ->
  let module C = Githubc2_repos.Get_content.Responses.OK in
  match Openapi.Response.value resp with
  | `OK (C.Content_file file) -> Ok (Some file)
  | `OK _ -> Error `Not_file
  | `Not_found _ -> Ok None
  | (`Forbidden _ | `Found | `Not_modified) as err -> Error err

let fetch_pull_request_files ~owner ~repo ~pull_number client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "fetch_pull_request_files");
  Githubc2_abb.collect_all
    client
    Githubc2_pulls.List_files.(make (Parameters.make ~per_page:100 ~owner ~pull_number ~repo ()))

let fetch_diff_files ~owner ~repo ~base_ref ~branch_ref client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "fetch_diff_files");
  Githubc2_abb.fold
    client
    ~init:[]
    ~f:(fun acc resp ->
      let module C = Githubc2_components.Commit_comparison in
      match Openapi.Response.value resp with
      | `OK { C.primary = { C.Primary.files; _ }; _ } ->
          Abbs_future_combinators.return_ok (CCOption.get_or ~default:[] files @ acc)
      | (`Not_found _ | `Internal_server_error _) as err -> Abbs_future_combinators.return_err err)
    Githubc2_repos.Compare_commits.(
      make Parameters.(make ~owner ~repo ~base:base_ref ~head:branch_ref ~per_page:250 ()))

let fetch_pull_request ~owner ~repo ~pull_number client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "fetch_pull_request");
  let open Abbs_future_combinators.Infix_result_monad in
  call client Githubc2_pulls.Get.(make Parameters.(make ~owner ~repo ~pull_number))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK v -> Ok v
  | ( `Not_modified
    | `Not_found _
    | `Not_acceptable _
    | `Internal_server_error _
    | `Service_unavailable _ ) as err -> Error err

let get_user_installations client =
  let open Abbs_future_combinators.Infix_result_monad in
  let module R = Githubc2_apps.List_installations_for_authenticated_user.Responses in
  Prmths.Counter.inc_one (Metrics.fn_call_total "get_user_installations");
  call
    client
    Githubc2_apps.List_installations_for_authenticated_user.(
      make Parameters.(make ~per_page:100 ()))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK R.OK.{ primary = Primary.{ installations; _ }; _ } -> Ok installations
  | (`Forbidden _ | `Not_modified | `Unauthorized _) as err -> Error err

let get_installation_repos client =
  let module R = Githubc2_apps.List_repos_accessible_to_installation.Responses in
  Prmths.Counter.inc_one (Metrics.fn_call_total "get_installation_repos");
  Githubc2_abb.fold
    client
    ~init:[]
    ~f:(fun acc resp ->
      match Openapi.Response.value resp with
      | `OK { R.OK.primary = { R.OK.Primary.repositories; _ }; _ } ->
          Abbs_future_combinators.return_ok (acc @ repositories)
      | (`Forbidden _ | `Not_found _ | `Not_modified | `Unauthorized _) as err ->
          Abbs_future_combinators.return_err err)
    Githubc2_apps.List_repos_accessible_to_installation.(make Parameters.(make ()))

let list_workflows ~owner ~repo client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "list_workflow");
  Githubc2_abb.fold
    client
    ~init:[]
    ~f:(fun acc resp ->
      let module Lrwr = Githubc2_actions.List_repo_workflows.Responses.OK in
      match Openapi.Response.value resp with
      | `OK { Lrwr.primary = { Lrwr.Primary.workflows; _ }; _ } ->
          let module Workflow = Githubc2_components.Workflow in
          let workflows =
            CCList.map
              (fun { Workflow.primary; _ } ->
                let id = primary.Workflow.Primary.id in
                let name = primary.Workflow.Primary.name in
                let path = primary.Workflow.Primary.path in
                (id, name, path))
              workflows
          in
          Abbs_future_combinators.return_ok (workflows @ acc))
    Githubc2_actions.List_repo_workflows.(make (Parameters.make ~per_page:100 ~owner ~repo ()))

let find_workflow_file ~owner ~repo client =
  Abbs_future_combinators.retry
    ~f:(fun () ->
      let open Abbs_future_combinators.Infix_result_monad in
      list_workflows ~owner ~repo client
      >>| fun workflows ->
      match
        CCList.filter
          (fun (_, name, path) ->
            CCString.equal name terrateam_workflow_name
            || CCString.equal path terrateam_workflow_path)
          workflows
      with
      | (_, _, path) :: _ -> Some path
      | [] -> None)
    ~while_:
      (Abbs_future_combinators.finite_tries 3 (function
        | Ok (Some _) -> false
        | Ok None | Error _ -> true))
    ~betwixt:
      (Abbs_future_combinators.series ~start:1.5 ~step:(( *. ) 1.5) (fun n _ ->
           Prmths.Counter.inc_one Metrics.call_retries_total;
           Abb.Sys.sleep n))

let load_workflow ?override_path ~owner ~repo client =
  Abbs_future_combinators.retry
    ~f:(fun () ->
      let open Abbs_future_combinators.Infix_result_monad in
      list_workflows ~owner ~repo client
      >>| fun workflows ->
      match
        CCList.filter
          (fun (_, name, path) ->
            (* If override path is specified, choose it, or if override_path is
               none, then match against the default *)
            CCOption.map_or ~default:false (CCString.equal path) override_path
            || CCOption.is_none override_path
               && (CCString.equal name terrateam_workflow_name
                  || CCString.equal path terrateam_workflow_path))
          workflows
      with
      | (id, _, _) :: _ -> Some id
      | [] -> None)
    ~while_:
      (Abbs_future_combinators.finite_tries 3 (function
        | Ok (Some _) -> false
        | Ok None | Error _ -> true))
    ~betwixt:
      (Abbs_future_combinators.series ~start:1.5 ~step:(( *. ) 1.5) (fun n _ ->
           Prmths.Counter.inc_one Metrics.call_retries_total;
           Abb.Sys.sleep n))

let publish_comment ~owner ~repo ~pull_number ~body client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "publish_comment");
  let open Abbs_future_combinators.Infix_result_monad in
  call
    client
    Githubc2_issues.Create_comment.(
      make
        ~body:Request_body.(make Primary.{ body })
        Parameters.(make ~issue_number:pull_number ~owner ~repo))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `Created c ->
      let module P = Githubc2_components.Issue_comment.Primary in
      let cm = Githubc2_components.Issue_comment.value c in
      let id = CCInt64.to_int cm.P.id in
      Ok id
  | (`Forbidden _ | `Not_found _ | `Gone _ | `Unprocessable_entity _) as err -> Error err

let delete_comment ~owner ~repo ~comment_id client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "delete_comment");
  let open Abb.Future.Infix_monad in
  call
    client
    Githubc2_issues.Delete_comment.(
      make Parameters.(make ~comment_id:(CCInt64.of_int comment_id) ~owner ~repo))
  >>= function
  | Ok resp -> (
      match Openapi.Response.value resp with
      | `No_content -> Abbs_future_combinators.return_ok ())
  | Error _err ->
      (* TODO #561: Handle this properly later *)
      Abbs_future_combinators.return_ok ()

let minimize_comment ~owner ~repo ~comment_id client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "minimize_comment");
  let module C = Githubc2_components.Issue_comment in
  let open Abbs_future_combinators.Infix_result_monad in
  let module Body = struct
    type t = { query : string } [@@deriving to_yojson]
  end in
  let create_minimize_request url node_id =
    let content =
      Printf.sprintf
        {|
        mutation MinCom {
            minimizeComment(input: {subjectId: "%s", classifier: OUTDATED}) {
                clientMutationId,
                minimizedComment {
                isMinimized
                }
            }
        }
      |}
    in
    let body = { Body.query = content node_id } in
    Openapi.Request.make
      ~body:(Body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:[ ("200", fun _ -> Ok `OK); ("404", fun _ -> Ok `Not_found) ]
      `Post
  in
  call
    client
    Githubc2_issues.Get_comment.(
      make Parameters.(make ~comment_id:(CCInt64.of_int comment_id) ~owner ~repo))
  >>= fun resp ->
  match Openapi.Response.value resp with
  | `OK { C.primary = { C.Primary.node_id; _ }; _ } -> (
      let url = "/graphql" in
      let request = create_minimize_request url node_id in
      call client request
      >>= fun resp ->
      match Openapi.Response.value resp with
      | `OK -> Abbs_future_combinators.return_ok ()
      | `Not_found -> (
          let url = "/api/graphql" in
          let request = create_minimize_request url node_id in
          call client request
          >>? fun resp ->
          match Openapi.Response.value resp with
          | `OK -> Ok ()
          | `Not_found -> Error `Not_found))
  | `Not_found _ -> Abbs_future_combinators.return_err `Not_found

(* [reviewDecision] is GitHub's own verdict on whether the pull request
   satisfies the target branch's required-review rule, including CODEOWNERS
   matching.  There is no REST equivalent, so this has to go through GraphQL.
   The value is [null] when the branch has no rule requiring reviews at all,
   which is why the result is an option. *)
let fetch_pull_request_review_decision ~owner ~repo ~pull_number client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "fetch_pull_request_review_decision");
  let open Abbs_future_combinators.Infix_result_monad in
  let module Body = struct
    module Variables = struct
      type t = {
        owner : string;
        repo : string;
        pull_number : int;
      }
      [@@deriving to_yojson]
    end

    type t = {
      query : string;
      variables : Variables.t;
    }
    [@@deriving to_yojson]
  end in
  let module Resp = struct
    module Err = struct
      type t = { message : string } [@@deriving of_yojson { strict = false }, show]
    end

    module Pull_request = struct
      type t = { review_decision : string option [@key "reviewDecision"] [@default None] }
      [@@deriving of_yojson { strict = false }]
    end

    module Repository = struct
      type t = { pull_request : Pull_request.t option [@key "pullRequest"] [@default None] }
      [@@deriving of_yojson { strict = false }]
    end

    module Data = struct
      type t = { repository : Repository.t option [@default None] }
      [@@deriving of_yojson { strict = false }]
    end

    type t = {
      data : Data.t option; [@default None]
      errors : Err.t list option; [@default None]
    }
    [@@deriving of_yojson { strict = false }]
  end in
  let create_review_decision_request url =
    let query =
      {|
        query($owner: String!, $repo: String!, $pull_number: Int!) {
            repository(owner: $owner, name: $repo) {
                pullRequest(number: $pull_number) {
                reviewDecision
                }
            }
        }
      |}
    in
    let body = { Body.query; variables = { Body.Variables.owner; repo; pull_number } } in
    Openapi.Request.make
      ~body:(Body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:
        [
          ("200", Openapi.of_json_body (fun r -> `OK r) Resp.of_yojson);
          ("404", fun _ -> Ok `Not_found);
        ]
      `Post
  in
  (* A GraphQL error comes back as a 200 with an [errors] array, so it has to be
     pulled apart rather than relying on the status code. *)
  let decision = function
    | { Resp.errors = Some (_ :: _ as errs); _ } ->
        Abbs_future_combinators.return_err
          (`Graphql_err (CCList.map (fun { Resp.Err.message } -> message) errs))
    | {
        Resp.data =
          Some
            {
              Resp.Data.repository =
                Some { Resp.Repository.pull_request = Some { Resp.Pull_request.review_decision } };
            };
        _;
      } -> Abbs_future_combinators.return_ok review_decision
    | _ -> Abbs_future_combinators.return_err `Not_found
  in
  let url = "/graphql" in
  let request = create_review_decision_request url in
  call client request
  >>= fun resp ->
  match Openapi.Response.value resp with
  | `OK resp -> decision resp
  | `Not_found -> (
      let url = "/api/graphql" in
      let request = create_review_decision_request url in
      call client request
      >>= fun resp ->
      match Openapi.Response.value resp with
      | `OK resp -> decision resp
      | `Not_found -> Abbs_future_combinators.return_err `Not_found)

let react_to_comment ?(content = `Rocket) ~owner ~repo ~comment_id client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "react_to_comment");
  let open Abbs_future_combinators.Infix_result_monad in
  call
    client
    Githubc2_reactions.Create_for_issue_comment.(
      make
        ~body:Request_body.(make Primary.(make ~content))
        Parameters.(make ~comment_id:(CCInt64.of_int comment_id) ~owner ~repo))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK _ | `Created _ -> Ok ()
  | `Unprocessable_entity _ as err -> Error err

let rec get_tree ~owner ~repo ~sha client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "get_tree");
  let open Abbs_future_combinators.Infix_result_monad in
  call
    client
    Githubc2_git.Get_tree.(
      make Parameters.(make ~recursive:(Some "true") ~owner ~repo ~tree_sha:sha ()))
  >>= fun resp ->
  match Openapi.Response.value resp with
  | `OK tree when Githubc2_components_git_tree.(tree.primary.Primary.truncated) -> (
      call client Githubc2_git.Get_tree.(make Parameters.(make ~owner ~repo ~tree_sha:sha ()))
      >>= fun resp ->
      match Openapi.Response.value resp with
      | `OK tree -> (
          let open Abb.Future.Infix_monad in
          (* In the case that the response is truncated, we need to preform
             the recursive calls ourselves.  We will do that in parallel, with
             maximum number of concurrent lookups per level being
             [max_get_tree_chunks]. *)
          let num_items = CCList.length Githubc2_components_git_tree.(tree.primary.Primary.tree) in
          let num_per_chunk =
            match num_items / max_get_tree_chunks with
            | 0 -> num_items
            | n -> n
          in
          let items =
            CCList.chunks num_per_chunk Githubc2_components_git_tree.(tree.primary.Primary.tree)
          in
          Abbs_future_combinators.List.map_par
            ~f:(fun items ->
              let open Abbs_future_combinators.Infix_result_monad in
              Abbs_future_combinators.List_result.fold_left
                ~init:[]
                ~f:(fun files item ->
                  let module Items = Githubc2_components_git_tree.Primary.Tree.Items in
                  match item.Items.primary.Items.Primary.type_ with
                  | "tree" ->
                      get_tree ~owner ~repo ~sha:item.Items.primary.Items.Primary.sha client
                      >>| fun fs ->
                      let path = item.Items.primary.Items.Primary.path in
                      let fs = CCList.map (Filename.concat path) fs in
                      files @ fs
                  | "blob" ->
                      Abbs_future_combinators.return_ok
                        (item.Items.primary.Items.Primary.path :: files)
                  | typ ->
                      Logs.err (fun m -> m "GET_TREE : UNKNOWN_TYPE : %s" typ);
                      Abbs_future_combinators.return_ok files)
                items)
            items
          >>= fun res ->
          match CCResult.flatten_l res with
          | Ok files -> Abbs_future_combinators.return_ok (CCList.flatten files)
          | Error _ as err -> Abb.Future.return err)
      | `Not_found _ as err -> Abbs_future_combinators.return_err err
      | (`Unprocessable_entity _ | `Conflict _) as err -> Abbs_future_combinators.return_err err)
  | `OK tree ->
      let tree = Githubc2_components_git_tree.(tree.primary.Primary.tree) in
      let files =
        tree
        |> CCList.filter_map (fun item ->
            let module Items = Githubc2_components_git_tree.Primary.Tree.Items in
            match item.Items.primary.Items.Primary.type_ with
            | "blob" -> Some item.Items.primary.Items.Primary.path
            | _ -> None)
      in
      Abbs_future_combinators.return_ok files
  | `Not_found _ as err -> Abbs_future_combinators.return_err err
  | (`Unprocessable_entity _ | `Conflict _) as err -> Abbs_future_combinators.return_err err

let get_team_membership_in_org ~org ~team ~user client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "get_team_membership_in_org");
  let open Abbs_future_combinators.Infix_result_monad in
  let module Team = Githubc2_components.Team_membership in
  call
    client
    Githubc2_teams.Get_membership_for_user_in_org.(
      make Parameters.(make ~org ~team_slug:team ~username:user))
  >>| fun resp ->
  match Openapi.Response.value resp with
  | `Not_found -> false
  | `OK Team.{ primary = Primary.{ state; _ }; _ } -> state = `Active

let get_repo_collaborator_permission ~org ~repo ~user client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "get_repo_collaborator_permission");
  let open Abbs_future_combinators.Infix_result_monad in
  let module Permission = Githubc2_components.Repository_collaborator_permission in
  call
    client
    Githubc2_repos.Get_collaborator_permission_level.(
      make Parameters.(make ~owner:org ~repo ~username:user))
  >>| fun resp ->
  match Openapi.Response.value resp with
  | `Not_found _ -> None
  | `OK Permission.{ primary = Primary.{ role_name; _ }; _ } -> Some role_name

let get_org_membership ~org ~user client =
  Prmths.Counter.inc_one (Metrics.fn_call_total "get_org_membership");
  let open Abbs_future_combinators.Infix_result_monad in
  let module Membership = Githubc2_components.Org_membership in
  call client Githubc2_orgs.Get_membership_for_user.(make Parameters.(make ~org ~username:user))
  >>| fun resp ->
  match Openapi.Response.value resp with
  | `Not_found _ -> None
  | `Forbidden _ -> None
  | `OK Membership.{ primary = Primary.{ role; state; _ }; _ } ->
      if state = `Active then Some (if role = `Admin then `Admin else `User) else None

module Commit_status = struct
  type create_err = Githubc2_abb.call_err [@@deriving show]

  type list_err =
    [ Githubc2_abb.call_err
    | `Error
    | `Moved_permanently of Githubc2_components.Basic_error.t
    ]
  [@@deriving show]

  module Create = struct
    module T = struct
      type t = {
        target_url : string option;
        description : string option;
        context : string option;
        state : Githubc2_repos.Create_commit_status.Request_body.Primary.State.t;
      }
      [@@deriving show]

      let make ?target_url ?description ?context ~state () =
        { target_url; description; context; state }
    end

    type t = T.t list
  end

  let create ~owner ~repo ~sha ~creates client =
    let max_parallel = 10 in
    let open Abb.Future.Infix_monad in
    Abbs_future_combinators.List.map_par
      ~f:(fun creates ->
        Abbs_future_combinators.List_result.iter
          ~f:(fun Create.T.{ target_url; description; context; state } ->
            Prmths.Counter.inc_one (Metrics.fn_call_total "commit_status_create");
            let open Abbs_future_combinators.Infix_result_monad in
            call
              client
              Githubc2_repos.Create_commit_status.(
                make
                  ~body:
                    Request_body.(make Primary.(make ?context ~description ~state ~target_url ()))
                  Parameters.(make ~owner ~repo ~sha))
            >>| fun _ -> ())
          creates)
      (CCList.chunks (CCInt.max 1 (CCList.length creates / max_parallel)) creates)
    >>= fun res ->
    match CCResult.flatten_l res with
    | Ok _ -> Abbs_future_combinators.return_ok ()
    | Error _ as err -> Abb.Future.return err

  let list ~owner ~repo ~sha client =
    Prmths.Counter.inc_one (Metrics.fn_call_total "commit_status_list");
    let open Abb.Future.Infix_monad in
    Abbs_future_combinators.retry
      ~f:(fun () ->
        Githubc2_abb.collect_all
          client
          Githubc2_repos.List_commit_statuses_for_ref.(
            make Parameters.(make ~per_page:100 ~owner ~repo ~ref_:sha ())))
      ~while_:(Abbs_future_combinators.finite_tries 3 CCResult.is_error)
      ~betwixt:
        (Abbs_future_combinators.series ~start:1.5 ~step:(( *. ) 1.5) (fun n _ ->
             Prmths.Counter.inc_one Metrics.call_retries_total;
             Abb.Sys.sleep n))
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error #list_err as err -> Abb.Future.return err
end

module Status_check = struct
  type list_err = Githubc2_abb.call_err [@@deriving show]

  let list ~owner ~repo ~ref_ client =
    Prmths.Counter.inc_one (Metrics.fn_call_total "status_check_list");
    let open Abb.Future.Infix_monad in
    call
      client
      Githubc2_checks.List_for_ref.(make Parameters.(make ~per_page:100 ~owner ~repo ~ref_ ()))
    >>= function
    | Ok resp ->
        let module OK = Githubc2_checks.List_for_ref.Responses.OK in
        let (`OK OK.{ primary = Primary.{ check_runs; _ }; _ }) = Openapi.Response.value resp in
        Abbs_future_combinators.return_ok check_runs
    | Error _ as err -> Abb.Future.return err
end

module Pull_request_reviews = struct
  type list_err =
    [ `Error
    | Githubc2_abb.call_err
    ]
  [@@deriving show]

  let list ~owner ~repo ~pull_number client =
    Prmths.Counter.inc_one (Metrics.fn_call_total "pull_request_reviews_list");
    Githubc2_abb.collect_all
      client
      Githubc2_pulls.List_reviews.(
        make Parameters.(make ~per_page:100 ~owner ~repo ~pull_number ()))
end

module Oauth = struct
  module Http = Abb_curl.Make (Abb)

  type authorize_err =
    [ `Authorize_err of string
    | Http.request_err
    ]
  [@@deriving show]

  type refresh_err =
    [ `Refresh_err of string
    | `Bad_refresh_token
    | Http.request_err
    ]
  [@@deriving show]

  module Response = struct
    type t = {
      access_token : string;
      scope : string;
      token_type : string;
      refresh_token : string option; [@default None]
      refresh_token_expires_in : int option; [@default None]
      expires_in : int option; [@default None]
    }
    [@@deriving of_yojson { strict = false }, show]
  end

  module Response_err = struct
    type t = {
      error : string;
      error_description : string;
    }
    [@@deriving of_yojson { strict = false }, show]
  end

  let authorize ~config code =
    let open Abb.Future.Infix_monad in
    let headers =
      Http.Headers.of_list
        [
          ("user-agent", "Terrateam");
          ("content-type", "application/json");
          ("accept", "application/vnd.github.v3+json");
        ]
    in
    let uri =
      Uri.of_string
        (Printf.sprintf
           "%s/login/oauth/access_token"
           (Uri.to_string (Terrat_config.Github.web_base_url config)))
    in
    let body =
      Yojson.Safe.to_string
        (`Assoc
           [
             ("client_id", `String (Terrat_config.Github.app_client_id config));
             ("client_secret", `String (Terrat_config.Github.app_client_secret config));
             ("code", `String code);
           ])
    in
    Http.post ~headers ~body uri
    >>| function
    | Ok (resp, body) when Http.Status.is_success (Http.Response.status resp) -> (
        match Response.of_yojson (Yojson.Safe.from_string body) with
        | Ok value -> Ok value
        | Error _ -> Error (`Authorize_err body))
    | Ok (_resp, body) -> Error (`Authorize_err body)
    | Error err -> Error err

  let refresh ~config refresh_token =
    let open Abb.Future.Infix_monad in
    let headers =
      Http.Headers.of_list
        [
          ("user-agent", "Terrateam");
          ("accept", "application/json");
          ("content-type", "application/json");
        ]
    in
    let uri =
      Uri.of_string
        (Printf.sprintf
           "%s/login/oauth/access_token"
           (Uri.to_string (Terrat_config.Github.web_base_url config)))
    in
    let body =
      Yojson.Safe.to_string
        (`Assoc
           [
             ("client_id", `String (Terrat_config.Github.app_client_id config));
             ("client_secret", `String (Terrat_config.Github.app_client_secret config));
             ("grant_type", `String "refresh_token");
             ("refresh_token", `String refresh_token);
           ])
    in
    Http.post ~headers ~body uri
    >>| function
    | Ok (resp, body) when Http.Status.is_success (Http.Response.status resp) -> (
        match Response.of_yojson (Yojson.Safe.from_string body) with
        | Ok value -> Ok value
        | Error _ -> (
            match Response_err.of_yojson (Yojson.Safe.from_string body) with
            | Ok { Response_err.error = "bad_refresh_token"; _ } -> Error `Bad_refresh_token
            | _ -> Error (`Refresh_err body)))
    | Ok (_resp, body) -> Error (`Refresh_err body)
    | Error err -> Error err
end
