module Api = Terrat_vcs_api_github
module Publisher_tools = Terrat_vcs_github_comment_publishers.Publisher_tools
module Scope = Terrat_scope.Scope
module Ui = Terrat_vcs_github_comment_ui.Ui

let src = Logs.Src.create "vcs_github_comment"

module Logs = (val Logs.src_log src : Logs.LOG)

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_comment_id =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* comment_id *)
      Ret.bigint
      /^ read [%blob "sql/select_comment_id.sql"]
      /% Var.uuid "work_manifest"
      /% Var.text "dir"
      /% Var.text "workspace")

  let select_comment_elements =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* work_manifest_id *)
      Ret.uuid
      //
      (* comment.dir *)
      Ret.text
      //
      (* comment.workspace *)
      Ret.text
      //
      (* work_manifest.run_type *)
      Ret.text
      //
      (* applied *)
      Ret.boolean
      //
      (* steps.ignore_errors *)
      Ret.boolean
      //
      (* steps.payload *)
      Ret.u
        Ret.json
        CCFun.(Terrat_api_components_workflow_step_output.Payload.of_yojson %> CCOption.of_result)
      //
      (* steps.scope *)
      Ret.u
        Ret.json
        CCFun.(Terrat_api_components_workflow_step_output_scope.of_yojson %> CCOption.of_result)
      //
      (* steps.success *)
      Ret.boolean
      //
      (* steps.step *)
      Ret.text
      /^ read [%blob "sql/select_comment_elements.sql"]
      /% Var.bigint "comment_id"
      /% Var.uuid "work_manifest")

  let upsert_github_work_manifest_comment =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* comment_id *)
      Ret.bigint
      /^ read [%blob "sql/upsert_github_work_manifest_comment.sql"]
      /% Var.bigint "comment_id"
      /% Var.uuid "work_manifest"
      /% Var.text "dir"
      /% Var.text "workspace")
end

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
    brand : Terrat_brand.t;
    num_remaining_layers : int;
    result : Terrat_api_components_work_manifest_tf_operation_result2.t;
    repo_config : Terrat_base_repo_config_v1.derived Terrat_base_repo_config_v1.t;
    synthesized_config : Terrat_change_match3.Config.t;
    (* Curr Work M that is finished! *)
    work_manifest : (Api.Account.t, unit) Terrat_work_manifest3.Existing.t;
  }

  type el = {
    (* This output was produced before its dirspace was applied, so it describes
       work that has already happened rather than work that is still pending. *)
    applied : bool;
    compact : bool;
    dirspace : Terrat_dirspace.t;
    steps : Terrat_api_components_workflow_step_output.t list;
    strategy : Terrat_vcs_comment.Strategy.t;
    work_manifest_id : Uuidm.t;
  }
  [@@deriving show]

  type comment_id = Api.Comment.Id.t [@@deriving ord, show]

  module Cmp = struct
    type t = bool * bool * Terrat_dirspace.t [@@deriving ord]
  end

  (* [applied] defaults to false because the common caller is the run that just
     finished, whose output is by definition not yet applied.  Only elements read
     back out of a previous comment can be stale. *)
  let create_el t ?(applied = false) ~work_manifest_id dirspace steps =
    let module St = Terrat_vcs_comment.Strategy in
    let module Cm3 = Terrat_change_match3 in
    let module N = Terrat_base_repo_config_v1.Notifications in
    let from_base_repo_policy_strategy st =
      match st with
      | N.Policy.Strategy.Append -> St.Append
      | N.Policy.Strategy.Minimize -> St.Minimize
      | N.Policy.Strategy.Delete -> St.Delete
    in
    let notification = Terrat_base_repo_config_v1.notifications t.repo_config in
    let policies = notification.N.policies in
    match Cm3.of_dirspace t.synthesized_config dirspace with
    | Some config ->
        let strategy =
          match
            CCList.find_opt
              (fun p -> Cm3.match_tag_query ~tag_query:p.N.Policy.tag_query config)
              policies
          with
          | Some { N.Policy.comment_strategy; _ } -> from_base_repo_policy_strategy comment_strategy
          | None -> Terrat_vcs_comment.Strategy.Minimize
        in
        (* I think it makes no sense dealing with this here, `terrat_vcs_comment`
           already knows how to handle that, so hardcoding may be fine *)
        let compact = false in
        Some { applied; work_manifest_id; dirspace; steps; strategy; compact }
    | _ -> None

  let query_comment_id t el =
    let open Abb.Future.Infix_monad in
    let work_manifest_id = t.work_manifest.Terrat_work_manifest3.id in
    let { Terrat_dirspace.dir; workspace } = el.dirspace in
    Pgsql_io.Prepared_stmt.fetch
      t.db
      Sql.select_comment_id
      ~f:CCFun.id
      work_manifest_id
      dir
      workspace
    >>= function
    | Ok r ->
        Abbs_future_combinators.return_ok
          (CCOption.of_list r
          |> CCOption.flat_map CCFun.(Int64.to_string %> Api.Comment.Id.of_string))
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : ERROR : %a" t.request_id Pgsql_io.pp_err err);
        Abbs_future_combinators.return_err `Error

  let query_els_for_comment_id t comment_id =
    let open Abb.Future.Infix_monad in
    let module D = Terrat_api_components_workflow_step_output_scope_dirspace in
    let module Step = Terrat_api_components_workflow_step_output in
    let module Scope = Terrat_api_components_workflow_step_output_scope in
    let cid = Api.Comment.Id.to_string comment_id |> Int64.of_string in
    let current_work_manifest = t.work_manifest.Terrat_work_manifest3.id in
    let module By_scope = Terrat_data.Group_by (struct
      type t = Uuidm.t * string * bool * Step.t
      type key = Uuidm.t * string * bool * Terrat_dirspace.t [@@deriving ord]

      let key (work_manifest_id, run_type, applied, step) =
        match step.Step.scope with
        | Scope.Workflow_step_output_scope_dirspace { D.dir; workspace; _ } ->
            let dirspace = { Terrat_dirspace.dir; workspace } in
            (work_manifest_id, run_type, applied, dirspace)
        | _ -> assert false

      let compare = compare_key
    end) in
    Pgsql_io.Prepared_stmt.fetch
      t.db
      Sql.select_comment_elements
      ~f:(fun wmid _ _ run_type applied ignore_errors payload scope success step ->
        (wmid, run_type, applied, { Step.ignore_errors; payload; scope; step; success }))
      cid
      current_work_manifest
    >>= function
    | Ok elements ->
        let groups = By_scope.group elements in
        let split =
          CCList.map
            (fun ((wid, run_type, applied, d), v) ->
              (wid, run_type, applied, d, CCList.map (fun (_, _, _, s) -> s) v))
            groups
        in
        let els =
          CCList.filter_map
            (fun (work_manifest_id, _, applied, dirspace, steps) ->
              create_el t ~applied ~work_manifest_id dirspace steps)
            split
        in
        Abbs_future_combinators.return_ok els
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : ERROR : %a" t.request_id Pgsql_io.pp_err err);
        Abbs_future_combinators.return_err `Error

  let upsert_comment_id t els comment_id =
    let open Abb.Future.Infix_monad in
    let cid = Api.Comment.Id.to_string comment_id |> Int64.of_string in
    Abbs_future_combinators.List_result.map
      ~f:(fun el ->
        let { Terrat_dirspace.dir; workspace } = el.dirspace in
        Pgsql_io.Prepared_stmt.fetch
          t.db
          Sql.upsert_github_work_manifest_comment
          ~f:(fun _ -> ())
          cid
          el.work_manifest_id
          dir
          workspace)
      els
    >>= function
    | Ok _ -> Abbs_future_combinators.return_ok ()
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : ERROR : %a" t.request_id Pgsql_io.pp_err err);
        Abbs_future_combinators.return_err `Error

  let delete_comment t comment_id =
    let request_id = t.request_id in
    Terrat_vcs_api.collapse_call_err (fun () ->
        Api.delete_pull_request_comment ~request_id t.client t.pull_request comment_id)

  let minimize_comment t comment_id =
    let request_id = t.request_id in
    Terrat_vcs_api.collapse_call_err (fun () ->
        Api.minimize_pull_request_comment ~request_id t.client t.pull_request comment_id)

  let summary_enabled t =
    let module N = Terrat_base_repo_config_v1.Notifications in
    N.Summary.enabled (Terrat_base_repo_config_v1.notifications t.repo_config).N.summary

  (* Whether the summary runs in pull_request mode: the unified comment carries the per-dirspace
     rollup, so the classic comment collapses its changes table into a details block whose summary
     line shows the totals. *)
  let summary_unified_enabled t =
    let module N = Terrat_base_repo_config_v1.Notifications in
    let { N.summary; policies = _; plan = _; apply = _ } =
      Terrat_base_repo_config_v1.notifications t.repo_config
    in
    let { N.Summary.enabled = _; mode; output_details = _ } = summary in
    N.Summary.enabled summary
    &&
    match mode with
    | N.Summary.Mode.Pull_request -> true
    | N.Summary.Mode.Header -> false

  (* Link to the PR-level runs page so the comment (which aggregates every work
     manifest for the pull request) points at all of them, not just the last one
     to post. *)
  let pull_number t = Some (Api.Pull_request.id t.pull_request)

  (* Per-dirspace deep links to the specific work manifest run that produced each
     dirspace's output. *)
  let dirspace_run_urls t els =
    CCList.filter_map
      (fun el ->
        match
          Ui.run_url t.config t.work_manifest.Terrat_work_manifest3.account el.work_manifest_id
        with
        | Some uri -> Some (el.dirspace, Uri.to_string uri)
        | None -> None)
      els

  (* Dirspaces whose output is being carried forward from before an apply.  Kept
     in the comment for the audit trail, but marked so it does not read as
     pending work. *)
  let dirspace_applied els =
    CCList.filter_map (fun el -> if el.applied then Some (el.dirspace, true) else None) els

  let post_comment t els =
    let open Abb.Future.Infix_monad in
    let module R2 = Terrat_api_components.Work_manifest_tf_operation_result2 in
    (* TODO: Stop using the result, move gates to to t *)
    let gates = t.result.R2.gates in
    let summary = summary_enabled t in
    let summary_unified = summary_unified_enabled t in
    let pull_number = pull_number t in
    let dirspace_run_urls = dirspace_run_urls t els in
    let dirspace_applied = dirspace_applied els in
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
        ~brand:t.brand
        ~view:(if compact then `Compact else `Full)
        ~compacted_dirspaces
        ~summary
        ~summary_unified
        ~pull_number
        ~dirspace_run_urls
        ~dirspace_applied
        t.request_id
        t.account_status
        t.tier_runs
        t.config
        t.is_layered_run
        t.num_remaining_layers
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
            ~brand:t.brand
            ~view:`Compact
            ~compacted_dirspaces:(CCList.map (fun { dirspace; _ } -> dirspace) els)
            ~summary
            ~summary_unified
            ~pull_number
            ~dirspace_run_urls
            ~dirspace_applied
            t.request_id
            t.account_status
            t.tier_runs
            t.config
            t.is_layered_run
            t.num_remaining_layers
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
                ~brand:t.brand
                ~view:`Compact
                ~compacted_dirspaces:(CCList.map (fun { dirspace; _ } -> dirspace) els)
                ~summary
                ~summary_unified
                ~pull_number
                ~dirspace_run_urls
                ~dirspace_applied
                t.request_id
                t.account_status
                t.tier_runs
                t.config
                t.is_layered_run
                t.num_remaining_layers
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
    let summary_unified = summary_unified_enabled t in
    let pull_number = pull_number t in
    let dirspace_run_urls = dirspace_run_urls t els in
    let dirspace_applied = dirspace_applied els in
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
        ~brand:t.brand
        ~view:(if compact then `Compact else `Full)
        ~compacted_dirspaces
        ~summary
        ~summary_unified
        ~pull_number
        ~dirspace_run_urls
        ~dirspace_applied
        t.request_id
        t.account_status
        t.tier_runs
        t.config
        t.is_layered_run
        t.num_remaining_layers
        by_scope
        gates
        t.work_manifest
    in
    CCString.length @@ Yojson.Safe.to_string @@ `String body

  let dirspace el = el.dirspace
  let strategy el = el.strategy
  let compact el = { el with compact = true }

  let compare_el el1 el2 =
    let module P = Terrat_vcs_github_comment_publishers in
    P.dirspace_compare (el1.dirspace, el1.steps) (el2.dirspace, el2.steps)

  (* Github Limits it to 2^16 = 65536
     https://github.com/mshick/add-pr-comment/issues/93#issuecomment-1531415467
     I set it to a smaller value *)
  let max_comment_length = 65536 / 2
end
