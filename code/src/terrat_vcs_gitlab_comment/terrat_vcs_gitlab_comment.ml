module Api = Terrat_vcs_api_gitlab
module Publisher_tools = Terrat_vcs_gitlab_comment_publishers.Publisher_tools
module Scope = Terrat_scope.Scope

let src = Logs.Src.create "vcs_gitlab_comment"

module Logs = (val Logs.src_log src : Logs.LOG)

module S = struct
  type t = {
    account_status : Terrat_vcs_provider2.Account_status.t;
    tier_runs : Terrat_tier.Check.runs_per_month option;
    client : Api.Client.t;
    config : Api.Config.t;
    db : Pgsql_io.t;
    (* gates : Terrat_gate.t list; *)
    is_layered_run : bool;
    hooks : (Scope.t * Terrat_api_components_workflow_step_output.t list) list;
    pull_request : unit Api.Pull_request.t;
    request_id : string;
    remaining_layers : Terrat_change_match3.Dirspace_config.t list list;
    result : Terrat_api_components_work_manifest_tf_operation_result2.t;
    repo_config : Terrat_base_repo_config_v1.derived Terrat_base_repo_config_v1.t;
    synthesized_config : Terrat_change_match3.Config.t;
    work_manifest : (Api.Account.t, unit) Terrat_work_manifest3.Existing.t;
  }

  type el = {
    compact : bool;
    dirspace : Terrat_dirspace.t;
    steps : Terrat_api_components_workflow_step_output.t list;
    strategy : Terrat_vcs_comment.Strategy.t;
  }
  [@@deriving show]

  type comment_id = Api.Comment.Id.t [@@deriving ord, show]

  module Cmp = struct
    type t = bool * bool * Terrat_dirspace.t [@@deriving ord]
  end

  let create_el _t dirspace steps =
    (* TODO: Once proper tables for GitLab exist, replace this function
       with a similar implementation that is used in GITLAB *)
    let module St = Terrat_vcs_comment.Strategy in
    let compact = false in
    let strategy = St.Append in
    Some { dirspace; steps; strategy; compact }

  let query_comment_id _t _el = raise (Failure "nyi")
  let query_els_for_comment_id _t _cid = raise (Failure "nyi")
  let upsert_comment_id _t _els _cid = Abbs_future_combinators.return_ok ()
  let delete_comment _t _comment_id = raise (Failure "nyi")
  let minimize_comment _t _comment_id = raise (Failure "nyi")
  let pull_number t = Some (Api.Pull_request.id t.pull_request)

  (* GitLab has no Console run pages (see [Ui.run_url]) and does not yet track a
     per-dirspace work manifest id, so there are no per-dirspace run links. *)
  let dirspace_run_urls _t _els = []

  let summary_enabled t =
    let module N = Terrat_base_repo_config_v1.Notifications in
    N.Summary.enabled (Terrat_base_repo_config_v1.notifications t.repo_config).N.summary

  let post_comment t els =
    let open Abb.Future.Infix_monad in
    let module R2 = Terrat_api_components.Work_manifest_tf_operation_result2 in
    (* TODO: Stop using the result, move gates to to t *)
    let gates = t.result.R2.gates in
    let summary = summary_enabled t in
    let pull_number = pull_number t in
    let dirspace_run_urls = dirspace_run_urls t els in
    let by_dirspace = CCList.map (fun el -> (Scope.Dirspace el.dirspace, el.steps)) els in
    let by_scope = t.hooks @ by_dirspace in
    let compact = CCList.exists (fun { compact; _ } -> compact) els in
    (* Only the elements that are themselves oversized lose their step output. Previously any single
       oversized element forced the compact view on the whole comment, so a large plan diff on one
       dirspace erased the error text on every other one (#1540). *)
    let compacted_dirspaces =
      CCList.filter_map
        (fun { compact; dirspace; _ } -> if compact then Some dirspace else None)
        els
    in
    let body =
      Publisher_tools.create_run_output
        ~view:(if compact then `Compact else `Full)
        ~compacted_dirspaces
        ~summary
        ~pull_number
        ~dirspace_run_urls
        t.request_id
        t.account_status
        t.tier_runs
        t.config
        t.is_layered_run
        t.remaining_layers
        by_scope
        gates
        t.work_manifest
    in
    let content_length = CCString.length body in
    Logs.info (fun m ->
        m "%s : RENDERED_LENGTH %i : COMPACTED %b" t.request_id content_length compact);
    let request_id = t.request_id in
    Api.comment_on_pull_request ~request_id t.client t.pull_request body
    >>= function
    | Ok comment_id -> Abbs_future_combinators.return_ok comment_id
    (* A body the VCS never answered for is not a body that is too big, so
       rendering a smaller one buys nothing but another call timeout. *)
    | Error (`Vcs_api_timeout_err _) -> Abbs_future_combinators.return_err `Error
    | Error `Error -> (
        let body =
          Publisher_tools.create_run_output
            ~view:`Compact
            ~compacted_dirspaces:(CCList.map (fun { dirspace; _ } -> dirspace) els)
            ~summary
            ~pull_number
            ~dirspace_run_urls
            t.request_id
            t.account_status
            t.tier_runs
            t.config
            t.is_layered_run
            t.remaining_layers
            by_scope
            gates
            t.work_manifest
        in
        let content_length = CCString.length body in
        Logs.info (fun m ->
            m "%s : RENDERED_LENGTH %i : COMPACTED %b" t.request_id content_length compact);
        Api.comment_on_pull_request ~request_id t.client t.pull_request body
        >>= function
        | Ok comment_id -> Abbs_future_combinators.return_ok comment_id
        | Error (`Vcs_api_timeout_err _) -> Abbs_future_combinators.return_err `Error
        | Error `Error ->
            let by_scope = [] in
            let body =
              Publisher_tools.create_run_output
                ~view:`Compact
                ~compacted_dirspaces:(CCList.map (fun { dirspace; _ } -> dirspace) els)
                ~summary
                ~pull_number
                ~dirspace_run_urls
                t.request_id
                t.account_status
                t.tier_runs
                t.config
                t.is_layered_run
                t.remaining_layers
                by_scope
                gates
                t.work_manifest
            in
            let content_length = CCString.length body in
            Logs.info (fun m ->
                m "%s : RENDERED_LENGTH %i : COMPACTED %b" t.request_id content_length compact);
            Terrat_vcs_api.collapse_call_err (fun () ->
                Api.comment_on_pull_request ~request_id t.client t.pull_request body))

  let rendered_length t els =
    let module R2 = Terrat_api_components.Work_manifest_tf_operation_result2 in
    let gates = t.result.R2.gates in
    let summary = summary_enabled t in
    let pull_number = pull_number t in
    let dirspace_run_urls = dirspace_run_urls t els in
    let by_dirspace = CCList.map (fun el -> (Scope.Dirspace el.dirspace, el.steps)) els in
    let by_scope = t.hooks @ by_dirspace in
    let compact = CCList.exists (fun { compact; _ } -> compact) els in
    (* Only the elements that are themselves oversized lose their step output. Previously any single
       oversized element forced the compact view on the whole comment, so a large plan diff on one
       dirspace erased the error text on every other one (#1540). *)
    let compacted_dirspaces =
      CCList.filter_map
        (fun { compact; dirspace; _ } -> if compact then Some dirspace else None)
        els
    in
    let body =
      Publisher_tools.create_run_output
        ~view:(if compact then `Compact else `Full)
        ~compacted_dirspaces
        ~summary
        ~pull_number
        ~dirspace_run_urls
        t.request_id
        t.account_status
        t.tier_runs
        t.config
        t.is_layered_run
        t.remaining_layers
        by_scope
        gates
        t.work_manifest
    in
    CCString.length @@ Yojson.Safe.to_string @@ `String body

  let dirspace el = el.dirspace

  (* TODO: Remove this once proper GitLab migrations are also merged *)
  let strategy _el = Terrat_vcs_comment.Strategy.Append
  let compact el = { el with compact = true }

  let compare_el el1 el2 =
    let module P = Terrat_vcs_gitlab_comment_publishers in
    P.dirspace_compare (el1.dirspace, el1.steps) (el2.dirspace, el2.steps)

  (* Gitlab Limits it to either 1MB or 10^6 characters
     https://docs.gitlab.com/administration/instance_limits/#size-of-comments-and-descriptions-of-issues-merge-requests-and-epics
     I set it to a smaller value *)
  let max_comment_length = 1000000 / 2
end
