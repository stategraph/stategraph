module Irm = Abbs_fc.Infix_result_monad
module Ee2_fc = Terrat_vcs_event_evaluator2_fc
module P2 = Terrat_vcs_provider2
module Msg = P2.Msg

module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) =
struct
  let src = Logs.Src.create ("vcs_event_evaluator2_wm_sm_tf_op." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module Builder = Terrat_vcs_event_evaluator2_builder.Make (S)
  module Tasks_base = Terrat_vcs_event_evaluator2_tasks_base.Make (S) (Keys)

  let time_it s l f =
    Abbs_time_it.run (fun time -> Logs.info (fun m -> l m (Builder.log_id s) time)) f

  module Bs = Builder.Bs
  module Wm_sm = Terrat_vcs_event_evaluator2_wm_sm.Make (S) (Keys)
  module Wm = Terrat_work_manifest3
  module Wmr = Terrat_api_components.Work_manifest_result

  let result_version = 2
  let protocol_version = 1

  (* Which notifications setting governs the per-dirspace checks of a step: an unsafe apply is an
     apply, and a step with no setting of its own is [`Other]. *)
  let notifications_run = function
    | Wm.Step.Apply | Wm.Step.Unsafe_apply -> `Apply
    | Wm.Step.Plan -> `Plan
    | Wm.Step.Build_config | Wm.Step.Build_tree | Wm.Step.Index -> `Other

  let publish_comment' f msg = Tasks_base.publish_comment' f msg

  let create_commit_checks' f branch_ref checks =
    Tasks_base.create_commit_checks' f branch_ref checks

  let match_tag_queries ~accessor ~changes queries =
    CCList.map
      (fun change ->
        ( change,
          CCList.find_idx
            (fun q -> Terrat_change_match3.match_tag_query ~tag_query:(accessor q) change)
            queries ))
      changes

  let replace_stack_vars vars s = Str_template.apply (CCFun.flip Sln_map.String.find_opt vars) s

  let apply_stack_vars_to_workflow stack workflow =
    let module R = Terrat_base_repo_config_v1 in
    let module E = R.Workflows.Entry in
    let module S = R.Stacks.Stack in
    let {
      E.apply = _;
      engine = _;
      environment;
      integrations = _;
      lock_policy = _;
      plan = _;
      runs_on = _;
      storage = _;
      tag_query = _;
    } =
      workflow
    in
    let open CCResult.Infix in
    CCResult.opt_map (replace_stack_vars stack.S.variables) environment
    >>= fun environment -> Ok { workflow with E.environment }

  let dirspaceflows_of_changes_with_branch_target repo_config changes =
    let module R = Terrat_base_repo_config_v1 in
    let module S = R.Stacks in
    let workflows = R.workflows repo_config in
    CCResult.map_l
      (fun ( {
               Terrat_change_match3.Dirspace_config.dirspace;
               lock_branch_target;
               stack_config = { S.Stack.variables; _ } as stack_config;
               _;
             },
             workflow )
         ->
        let open CCResult.Infix in
        let module Dsf = Terrat_change.Dirspaceflow in
        CCResult.opt_map
          (fun (idx, workflow) ->
            let open CCResult.Infix in
            apply_stack_vars_to_workflow stack_config workflow
            >>= fun workflow -> Ok { Dsf.Workflow.idx; workflow })
          workflow
        >>= fun workflow ->
        Ok { Dsf.dirspace; workflow = (lock_branch_target, workflow); variables = Some variables })
      (match_tag_queries
         ~accessor:(fun { R.Workflows.Entry.tag_query; _ } -> tag_query)
         ~changes
         workflows)

  let strip_lock_branch_target dsfs =
    let module Dsf = Terrat_change.Dirspaceflow in
    CCList.map (fun ({ Dsf.workflow = _, workflow; _ } as dsf) -> { dsf with Dsf.workflow }) dsfs

  let dirspaceflows_of_changes repo_config changes =
    let open CCResult.Infix in
    dirspaceflows_of_changes_with_branch_target repo_config changes
    >>= fun dirspaceflows -> Ok (strip_lock_branch_target dirspaceflows)

  let partition_by_run_params = Terrat_vcs_event_evaluator2_batch.partition_by_run_params

  (* The commit checks for an operation on a work manifest.  Separate from creating them so that
     callers operating on many work manifests can collect the checks and create them in one call.

     Only the per-dirspace checks, and only when [status_checks_enabled] allows them.  A run
     reported two checks of its own as well, "terrateam <op> pre-hooks" and "terrateam <op>
     post-hooks"; they said nothing the run's comment does not say, and every repository paid for
     them on every pull request, so they are not created any more.  The check that holds a pull
     request until it is applied, "terrateam apply", is made elsewhere and is unaffected. *)
  let op_commit_checks status_checks_enabled config account repo work_manifest description status =
    let module Wm = Terrat_work_manifest3 in
    match work_manifest.Wm.changes with
    | [] -> []
    | dirspaces ->
        let step =
          match CCList.rev work_manifest.Wm.steps with
          | [] -> assert false
          | step :: _ -> step
        in
        let run_type = Wm.Step.to_string step in
        if status_checks_enabled ~run:(notifications_run step) then
          let module Dsf = Terrat_change.Dirspaceflow in
          CCList.map
            (fun { Dsf.dirspace; _ } ->
              S.Commit_check.make_dirspace
                ~config
                ~description
                ~run_type
                ~dirspace
                ~status
                ~work_manifest
                ~repo
                ~account
                ())
            dirspaces
        else []

  let create_op_commit_checks
      create_commit_checks
      status_checks_enabled
      config
      account
      repo
      ref_
      work_manifest
      description
      status =
    create_commit_checks'
      create_commit_checks
      ref_
      (op_commit_checks status_checks_enabled config account repo work_manifest description status)

  (* [stale] is the commit and the dirspaces whose checks go to that commit instead of [ref_]: the
     dirspaces whose result is stale.  A stale result is not valid (RFD 2356, Stale results
     considered invalid), thus a stale dirspace that succeeded gets a failed check with a stale
     description, and the dirspace must be planned again.  A dirspace that failed stays failed.
     The threshold counts every dirspace of the result, as one set of checks would. *)
  let create_op_commit_checks_of_result
      ?stale
      create_commit_checks
      status_checks_enabled
      config
      account
      repo
      ref_
      work_manifest
      result =
    let module Wm = Terrat_work_manifest3 in
    let module Wmr = Terrat_vcs_provider2.Work_manifest_result in
    let stale_dirspaces =
      CCOption.map_or
        ~default:Terrat_data.Dirspace_set.empty
        (fun (_, dirspaces) -> dirspaces)
        stale
    in
    let status_of dirspace success =
      match (success, Terrat_data.Dirspace_set.mem dirspace stale_dirspaces) with
      | true, false -> (Terrat_commit_check.Status.Completed, "Completed")
      | true, true -> (Terrat_commit_check.Status.Failed, "Stale: commits moved during the run")
      | false, (true | false) -> (Terrat_commit_check.Status.Failed, "Failed")
    in
    let step =
      match CCList.rev work_manifest.Wm.steps with
      | [] -> assert false
      | step :: _ -> step
    in
    let run_type = Wm.Step.to_string step in
    let dirspace_checks =
      if status_checks_enabled ~run:(notifications_run step) then
        CCList.map
          (fun (dirspace, success) ->
            let status, description = status_of dirspace success in
            S.Commit_check.make_dirspace
              ~config
              ~description
              ~run_type
              ~dirspace
              ~status
              ?resource_summary:
                (CCList.assoc_opt
                   ~eq:Terrat_change.Dirspace.equal
                   dirspace
                   result.Wmr.dirspaces_resource_summary)
              ~work_manifest
              ~repo
              ~account
              ())
          result.Wmr.dirspaces_success
        |> CCList.combine (CCList.map fst result.Wmr.dirspaces_success)
      else []
    in
    let open Irm in
    CCOption.map_lazy
      (fun () -> create_commit_checks' create_commit_checks ref_ (CCList.map snd dirspace_checks))
      (fun (stale_ref, stale_dirspaces) ->
        let stale_checks, fresh_checks =
          CCList.partition
            (fun (dirspace, _) -> Terrat_data.Dirspace_set.mem dirspace stale_dirspaces)
            dirspace_checks
        in
        create_commit_checks' create_commit_checks ref_ (CCList.map snd fresh_checks)
        >>= fun () ->
        create_commit_checks' create_commit_checks stale_ref (CCList.map snd stale_checks))
      stale

  let maybe_create_pending_apply_commit_checks
      create_commit_checks
      status_checks_enabled
      config
      account
      repo
      ref_
      all_matches
      apply_requirements
      commit_checks =
    let module Ar = Terrat_base_repo_config_v1.Apply_requirements in
    if apply_requirements.Ar.create_pending_apply_check then
      let commit_check_titles =
        commit_checks
        |> CCList.map (fun Terrat_commit_check.{ title; _ } -> title)
        |> Sln_set.String.of_list
      in
      let missing_commit_checks =
        if not (status_checks_enabled ~run:`Apply) then []
        else
          all_matches
          |> CCList.filter_map
               (fun
                 {
                   Terrat_change_match3.Dirspace_config.dirspace;
                   when_modified = { Terrat_base_repo_config_v1.When_modified.autoapply; _ };
                   _;
                 }
               ->
                 let name = S.Commit_check.make_dirspace_title ~run_type:"apply" dirspace in
                 if (not autoapply) && not (Sln_set.String.mem name commit_check_titles) then
                   Some
                     (S.Commit_check.make_dirspace
                        ~config
                        ~description:"Waiting"
                        ~run_type:"apply"
                        ~dirspace
                        ~status:Terrat_commit_check.Status.Queued
                        ~repo
                        ~account
                        ())
                 else None)
      in
      let missing_apply_check =
        Tasks_base.pending_apply_check
          ~config
          ~account
          ~repo
          ~apply_requirements
          ~commit_checks
          all_matches
      in
      create_commit_checks' create_commit_checks ref_ (missing_apply_check @ missing_commit_checks)
    else Abbs_fc.return_ok ()

  let changed_dirspaces config changes =
    let module Tcm = Terrat_change_match3 in
    let module S = Terrat_base_repo_config_v1.Stacks in
    let module Tc = Terrat_change in
    let module Dsf = Tc.Dirspaceflow in
    CCList.map
      (fun Tc.{ Dsf.dirspace = { Dirspace.dir; workspace } as dirspace; workflow; _ } ->
        let { Tcm.Dirspace_config.stack_name; stack_config = { S.Stack.variables; _ }; _ } =
          CCOption.get_exn_or "changed_dirspaces" @@ Tcm.of_dirspace config dirspace
        in
        (* TODO: Remove rank, it is deprecated *)
        Terrat_api_components.Work_manifest_dir.
          {
            path = dir;
            workspace;
            workflow;
            rank = 0;
            variables = Some (Variables.make ~additional:variables Json_schema.Empty_obj.t);
            stack_name;
          })
      changes

  let create ~dest_branch_ref ~branch_ref ~branch op s { Bs.Fetcher.fetch } =
    let open Irm in
    fetch Keys.account
    >>= fun account ->
    fetch Keys.repo
    >>= fun repo ->
    fetch Keys.initiator
    >>= fun _initiator ->
    fetch Keys.target
    >>= fun _target ->
    fetch Keys.repo_config
    >>= fun repo_config ->
    fetch Keys.matches
    >>= fun matches ->
    fetch Keys.status_checks_enabled
    >>= fun status_checks_enabled ->
    fetch
      (match op with
      | `Plan -> Keys.access_control_eval_plan
      | `Apply -> Keys.access_control_eval_apply)
    >>= fun access_control_results ->
    Abb.Future.return
      (let module R = Terrat_access_control2.R in
       (access_control_results
         : (R.t, Terrat_access_control2.err) result
         :> (R.t, [> Terrat_access_control2.err ]) result))
    >>= fun access_control_results ->
    let { Terrat_access_control2.R.pass = passed_dirspaces; deny = denied_dirspaces } =
      access_control_results
    in
    Abb.Future.return
      (dirspaceflows_of_changes_with_branch_target
         repo_config
         (CCList.flatten matches.Keys.Matches.all_matches))
    >>= fun all_dirspaceflows ->
    Builder.run_db s ~f:(fun db ->
        time_it
          s
          (fun m log_id time -> m "%s : STORE_DIRSPACEFLOWS : time=%f" log_id time)
          (fun () ->
            S.Db.store_dirspaceflows
              ~request_id:(Builder.log_id s)
              ~base_ref:dest_branch_ref
              ~branch_ref
              ~lock_policy:(Terrat_base_repo_config_v1.lock_policy repo_config)
              db
              repo
              all_dirspaceflows))
    >>= fun () ->
    Abb.Future.return (dirspaceflows_of_changes repo_config passed_dirspaces)
    >>= fun dirspaceflows ->
    let denied_dirspaces =
      let module Ac = Terrat_access_control2 in
      let module Dc = Terrat_change_match3.Dirspace_config in
      CCList.map
        (fun { Ac.R.Deny.change_match = { Dc.dirspace; _ }; policy } ->
          { Wm.Deny.dirspace; policy })
        denied_dirspaces
    in
    let module V1 = Terrat_base_repo_config_v1 in
    let max_workspaces_per_batch =
      if (V1.batch_runs repo_config).V1.Batch_runs.enabled then
        (V1.batch_runs repo_config).V1.Batch_runs.max_workspaces_per_batch
      else CCInt.max_int
    in
    let dirspaceflows_by_run_params =
      partition_by_run_params ~max_workspaces_per_batch dirspaceflows
    in
    let batch_sizes = CCList.map CCFun.(snd %> CCList.length) dirspaceflows_by_run_params in
    Logs.info (fun m ->
        m
          "%s : WORK_MANIFEST : BATCHES : num_batches=%d : num_dirspaces=%d : max_batch=%d : \
           min_batch=%d : max_workspaces_per_batch=%d"
          (Builder.log_id s)
          (CCList.length dirspaceflows_by_run_params)
          (CCList.fold_left ( + ) 0 batch_sizes)
          (CCList.fold_left CCInt.max 0 batch_sizes)
          (CCList.fold_left
             CCInt.min
             (CCOption.get_or ~default:0 (CCList.head_opt batch_sizes))
             batch_sizes)
          max_workspaces_per_batch);
    fetch Keys.target
    >>= fun target ->
    fetch Keys.initiator
    >>= fun initiator ->
    fetch Keys.job
    >>= fun job ->
    let tag_query =
      let module Tjc = Terrat_job_context in
      let module T = Tjc.Job.Type_ in
      match job.Tjc.Job.type_ with
      | T.Plan { tag_query; kind = _ } | T.Apply { tag_query; kind = _; force = _ } -> tag_query
      | T.Autoapply | T.Autoplan -> Terrat_tag_query.any
      | T.Gate_approval _ | T.Help | T.Index | T.Repo_config | T.Unlock _ | T.Push -> assert false
    in
    Abbs_fc.List_result.map
      ~f:(fun ((environment, runs_on), dirspaceflows) ->
        let changes =
          let module Dsf = Terrat_change.Dirspaceflow in
          CCList.map
            (fun ({ Dsf.workflow; _ } as dsf) ->
              { dsf with Dsf.workflow = CCOption.map (fun Dsf.Workflow.{ idx; _ } -> idx) workflow })
            dirspaceflows
        in
        let work_manifest =
          {
            Wm.account;
            base_ref = S.Api.Ref.to_string dest_branch_ref;
            branch = Some (S.Api.Ref.to_string branch);
            branch_ref = S.Api.Ref.to_string branch_ref;
            changes;
            completed_at = None;
            created_at = ();
            denied_dirspaces;
            environment;
            id = ();
            initiator;
            run_id = ();
            runs_on;
            state = ();
            steps =
              [
                (match op with
                | `Plan -> Wm.Step.Plan
                | `Apply -> Wm.Step.Apply);
              ];
            tag_query;
            target;
          }
        in
        Builder.run_db s ~f:(fun db ->
            time_it
              s
              (fun m log_id time -> m "%s : WORK_MANIFEST : CREATE : time=%f" log_id time)
              (fun () -> S.Work_manifest.create ~request_id:(Builder.log_id s) db work_manifest)
            >>= fun work_manifest ->
            (* The apply commits the plans of its dirspaces that apply in parallel: hold them from
               now on, so that no other commit overlaps them between this check and the commit. *)
            (match (op, target) with
              | `Apply, P2.Target.Pr pull_request ->
                  Tasks_base.reserve_stategraph_plans
                    ~request_id:(Builder.log_id s)
                    db
                    pull_request
                    work_manifest.Wm.id
                    (Tasks_base.stategraph_parallel_apply_dirspaces_of_work_manifest
                       repo_config
                       changes)
              | `Apply, P2.Target.Drift _ | `Plan, _ -> Abb.Future.return ())
            |> Abb.Future.map (fun () -> Ok work_manifest))
        >>| fun work_manifest ->
        ( work_manifest,
          op_commit_checks
            status_checks_enabled
            (Builder.State.config s)
            account
            repo
            work_manifest
            "Queued"
            Terrat_commit_check.Status.Queued ))
      dirspaceflows_by_run_params
    >>= fun work_manifests_and_checks ->
    let work_manifests = CCList.map fst work_manifests_and_checks in
    fetch Keys.branch_ref
    >>= fun branch_ref ->
    fetch Keys.create_commit_checks
    >>= fun create_commit_checks ->
    (* Create the checks for every work manifest in one call.  Creating them per work manifest
       dirties the commit checks between each one, and the fetch below would then have to be
       performed once per work manifest rather than once. *)
    create_commit_checks'
      create_commit_checks
      branch_ref
      (CCList.flat_map snd work_manifests_and_checks)
    >>= fun () ->
    (* Does not depend on any one work manifest, so it is performed once, after the checks above
       have been created, rather than once per work manifest. *)
    fetch Keys.commit_checks
    >>= fun commit_checks ->
    maybe_create_pending_apply_commit_checks
      create_commit_checks
      status_checks_enabled
      (Builder.State.config s)
      account
      repo
      branch_ref
      (CCList.flatten matches.Keys.Matches.all_matches)
      (Terrat_base_repo_config_v1.apply_requirements repo_config)
      commit_checks
    >>| fun () -> work_manifests

  module Staleness = Terrat_vcs_event_evaluator2_staleness

  let dirspaces_of_wm wm =
    CCList.map (fun change -> change.Terrat_change.Dirspaceflow.dirspace) wm.Wm.changes

  (* The head of [branch] of [repo], read from the forge.  [`Cached] can give a head a few seconds
     old, which a caller uses only where an older head errs on the safe side. *)
  let fetch_branch_head ~read s { Bs.Fetcher.fetch } repo branch =
    let open Irm in
    fetch Keys.client
    >>= fun client ->
    time_it
      s
      (fun m log_id time ->
        m
          "%s : FETCH_BRANCH_SHA : repo = %s : branch = %s : time=%f"
          log_id
          (S.Api.Repo.to_string repo)
          (S.Api.Ref.to_string branch)
          time)
      (fun () ->
        match read with
        | `Live -> S.Api.fetch_branch_sha ~request_id:(Builder.log_id s) client repo branch
        | `Cached -> S.Api.fetch_branch_sha_cached ~request_id:(Builder.log_id s) client repo branch)

  (* The head of the branch that a run operates on.  The refs of the evaluation of an event of a
     run name the commits of that run, thus this reads the forge: the head of an open pull request
     comes with the pull request that this event read, and the head of the destination of a merged
     pull request or of the branch of a drift is read from the branch, as [read] says. *)
  let current_head ~read s ({ Bs.Fetcher.fetch } as fetcher) work_manifest =
    let open Irm in
    match work_manifest.Wm.target with
    | P2.Target.Pr _ -> (
        fetch Keys.pull_request
        >>= fun pull_request ->
        match S.Api.Pull_request.state pull_request with
        | Terrat_pull_request.State.(Open | Closed) ->
            Abbs_fc.return_ok (Some (S.Api.Pull_request.branch_ref pull_request))
        | Terrat_pull_request.State.Merged _ ->
            fetch Keys.repo
            >>= fun repo ->
            fetch_branch_head
              ~read
              s
              fetcher
              repo
              (S.Api.Pull_request.base_branch_name pull_request))
    | P2.Target.Drift { repo; branch } ->
        fetch_branch_head ~read s fetcher repo (S.Api.Ref.of_string branch)

  (* The head of the destination branch of an open pull request, read now.  The runner merges it
     when the operation starts, thus it is a commit of the run too.  A merged pull request runs at
     the destination, whose head is [current_head], and a drift has no destination. *)
  let current_dest_head ~read s ({ Bs.Fetcher.fetch } as fetcher) work_manifest =
    let open Irm in
    match work_manifest.Wm.target with
    | P2.Target.Pr _ -> (
        fetch Keys.pull_request
        >>= fun pull_request ->
        match S.Api.Pull_request.state pull_request with
        | Terrat_pull_request.State.(Open | Closed) ->
            fetch Keys.repo
            >>= fun repo ->
            fetch_branch_head
              ~read
              s
              fetcher
              repo
              (S.Api.Pull_request.base_branch_name pull_request)
        | Terrat_pull_request.State.Merged _ -> Abbs_fc.return_ok None)
    | P2.Target.Drift _ -> Abbs_fc.return_ok None

  (* The config that names the dirspaces is the one of this evaluation, and not one of either
     commit: a dirspace that only one of them names is not found, which errs on the side of the
     old config the run used. *)
  let impact_since s { Bs.Fetcher.fetch } ~from_ref ~to_ref work_manifest =
    let open Irm in
    Ee2_fc.all4
      (fetch Keys.client)
      (fetch Keys.account)
      (fetch Keys.repo)
      (fetch Keys.synthesized_config)
    >>= fun (client, account, repo, config) ->
    fetch Keys.repo_config_raw'
    >>= fun (_, repo_config_raw) ->
    Tasks_base.changed_between
      s
      ~missing_tree:(`Fetch (client, repo))
      ~config
      ~repo_config_raw
      ~account
      ~from_ref
      ~to_ref
    >>| fun changed ->
    let impact = Staleness.decide ~changed (dirspaces_of_wm work_manifest) in
    Logs.info (fun m ->
        m
          "%s : STALENESS : wm=%a : from_ref=%s : to_ref=%s : impact=%a"
          (Builder.log_id s)
          Uuidm.pp
          work_manifest.Wm.id
          (S.Api.Ref.to_string from_ref)
          (S.Api.Ref.to_string to_ref)
          Staleness.pp
          impact);
    impact

  (* A start compares two ranges of commits, and restarts when the files of the run changed in one
     of them.  The runner operates on the commit that it checked out, [sha], thus the first range is
     from the commit of the work manifest to [sha]: a push and its revert give the commit of the work
     manifest again at the head, but the runner can have checked out the commit between them.
     Nothing ran yet, thus the second range is from [sha] to the head of now: a push after the
     dispatch restarts the run at the new head, and an apply of an older commit does not happen.

     The head is read from the cache, to save a call to the forge.  A cached head that is not [sha]
     is read again live: it can be older than [sha], and a start must not restart on a move that did
     not happen.  The destination head is read from the cache too: the runner merges the destination
     head of now, which the server cannot know exactly.  An older destination head makes the
     recorded start older, which widens the range that the result compares. *)
  let start ~sha work_manifest s fetcher =
    let open Irm in
    current_head ~read:`Cached s fetcher work_manifest
    >>= (fun head ->
    if CCOption.exists (fun head -> not (S.Api.Ref.equal head sha)) head then
      current_head ~read:`Live s fetcher work_manifest
    else Abbs_fc.return_ok head)
    >>= fun head ->
    impact_since
      s
      fetcher
      ~from_ref:(S.Api.Ref.of_string work_manifest.Wm.branch_ref)
      ~to_ref:sha
      work_manifest
    >>= fun checked_out ->
    CCOption.map_or
      ~default:(Abbs_fc.return_ok Staleness.Not_impacted)
      (fun head -> impact_since s fetcher ~from_ref:sha ~to_ref:head work_manifest)
      head
    >>= fun moved ->
    match Staleness.Start.decide (Staleness.union checked_out moved) with
    | Staleness.Start.Run ->
        current_dest_head ~read:`Cached s fetcher work_manifest
        >>| fun dest_head -> Wm_sm.Run { head = Some sha; dest_head }
    | Staleness.Start.Restart -> Abbs_fc.return_ok Wm_sm.Restart

  (* The heads that a result is compared with: the head of the branch of the run and, for an open
     pull request, the head of the destination branch, both read now. *)
  let result_heads s fetcher work_manifest =
    let open Irm in
    current_head ~read:`Live s fetcher work_manifest
    >>= fun head ->
    current_dest_head ~read:`Live s fetcher work_manifest >>| fun dest_head -> (head, dest_head)

  (* The commits that a result is compared from and to: the branch of the run, and the destination
     branch of an open pull request.  [None] is a commit that the server does not know. *)
  type compared = {
    from_ref : S.Api.Ref.t;
    head : S.Api.Ref.t option;
    from_dest_ref : S.Api.Ref.t option;
    dest_head : S.Api.Ref.t option;
  }

  (* A result is compared from the commits its run started on to the heads now: the branch of the
     run and, for an open pull request, the destination branch that the runner merged.  A work
     manifest that started before the server recorded the start has only the commit it was made at,
     and no destination commit, thus only its branch is compared. *)
  let result_impact s fetcher work_manifest ~head ~dest_head =
    let open Irm in
    Builder.run_db s ~f:(fun db ->
        S.Work_manifest.query_start_refs ~request_id:(Builder.log_id s) db work_manifest.Wm.id)
    >>= fun (start_sha, start_dest_sha) ->
    let from_ref =
      CCOption.get_or ~default:(S.Api.Ref.of_string work_manifest.Wm.branch_ref) start_sha
    in
    CCOption.map_or
      ~default:(Abbs_fc.return_ok Staleness.Unknown)
      (fun head -> impact_since s fetcher ~from_ref ~to_ref:head work_manifest)
      head
    >>= fun branch_impact ->
    CCOption.map_or
      ~default:(Abbs_fc.return_ok Staleness.Not_impacted)
      (fun start_dest_sha ->
        CCOption.map_or
          ~default:(Abbs_fc.return_ok Staleness.Unknown)
          (fun dest_head ->
            impact_since s fetcher ~from_ref:start_dest_sha ~to_ref:dest_head work_manifest)
          dest_head)
      start_dest_sha
    >>| fun dest_impact ->
    ( Staleness.union branch_impact dest_impact,
      { from_ref; head; from_dest_ref = start_dest_sha; dest_head } )

  (* A step of the report of a result whose error must not stop the report: it gives [default].
     The output of a result is posted after the server reads the heads and compares the files, and
     the caller makes a [default] there stale.  The steps after the output only show the result or
     follow it, and an error there would roll back the stored result with them.  A [`Suspend_eval]
     is an error here too, because a result never waits for data.  An error of an SQL statement is
     not kept out this way: PostgreSQL aborts the transaction, thus the next statement fails and the
     result is handled as an error. *)
  let or_default s work_manifest ~what ~default fut =
    let open Abb.Future.Infix_monad in
    fut
    >>= function
    | Ok _ as r -> Abb.Future.return r
    | Error err ->
        Logs.err (fun m ->
            m
              "%s : RESULT : %s : wm=%a : %a"
              (Builder.log_id s)
              what
              Uuidm.pp
              work_manifest.Wm.id
              Builder.pp_err
              err);
        Abbs_fc.return_ok default

  (* A head that cannot be read is [None], which makes the result unknown. *)
  let record_result_heads s fetcher work_manifest =
    let open Irm in
    or_default
      s
      work_manifest
      ~what:"RESULT_HEADS_ERR"
      ~default:(None, None)
      (result_heads s fetcher work_manifest)
    >>= fun (head, dest_head) ->
    Builder.run_db s ~f:(fun db ->
        S.Work_manifest.update_result_refs
          ~request_id:(Builder.log_id s)
          db
          work_manifest.Wm.id
          ~result_sha:head
          ~result_dest_sha:dest_head)
    >>| fun () -> (head, dest_head)

  let result_staleness s fetcher work_manifest =
    let open Irm in
    record_result_heads s fetcher work_manifest
    >>= fun (head, dest_head) ->
    or_default
      s
      work_manifest
      ~what:"STALENESS_ERR"
      ~default:
        ( Staleness.Unknown,
          {
            from_ref = S.Api.Ref.of_string work_manifest.Wm.branch_ref;
            head;
            from_dest_ref = None;
            dest_head;
          } )
      (result_impact s fetcher work_manifest ~head ~dest_head)

  (* The commit whose checks show the state of a run now: the head of the pull request.  The refs of
     the evaluation of an event of a run name the commit of that run, thus the head is read from
     the pull request, which is read live.  A drift has no pull request: its checks go to the commit
     of its run. *)
  let live_check_ref { Bs.Fetcher.fetch } work_manifest =
    let open Irm in
    match work_manifest.Wm.target with
    | P2.Target.Pr _ -> fetch Keys.pull_request >>| S.Api.Pull_request.branch_ref
    | P2.Target.Drift _ -> fetch Keys.branch_ref

  (* Where the checks of a result go: the live head for the fresh dirspaces, and a commit for the
     stale ones.  The stale checks of an open pull request go to [run_ref], the commit the run
     started on, where the start posted the running checks: when a push moved the head, a stale
     check must not land on the new head, which gets its own checks from the push; when only the
     destination moved, that commit is the head.  A merged pull request has a head that never moves,
     thus its stale checks go to the head.  A drift has no stale checks. *)
  let check_refs ({ Bs.Fetcher.fetch } as fetcher) work_manifest ~run_ref decision =
    let open Irm in
    live_check_ref fetcher work_manifest
    >>= fun head ->
    match work_manifest.Wm.target with
    | P2.Target.Drift _ -> Abbs_fc.return_ok (head, None)
    | P2.Target.Pr _ -> (
        fetch Keys.pull_request
        >>| fun pull_request ->
        let stale = Staleness.Pr_result.stale_dirspaces decision (dirspaces_of_wm work_manifest) in
        match S.Api.Pull_request.state pull_request with
        | Terrat_pull_request.State.(Open | Closed) -> (head, Some (run_ref, stale))
        | Terrat_pull_request.State.Merged _ -> (head, Some (head, stale)))

  let stale_report
      ~is_layered_run
      { from_ref; head; from_dest_ref; dest_head }
      work_manifest
      decision =
    let module St = P2.Work_manifest_stale in
    (* A branch that did not move, or whose head is not known, has no move to name. *)
    let move from_ref to_ref =
      CCOption.map2
        (fun from_ref to_ref ->
          CCOption.return_if
            (not (S.Api.Ref.equal from_ref to_ref))
            { St.Move.from_sha = S.Api.Ref.to_string from_ref; to_sha = S.Api.Ref.to_string to_ref })
        from_ref
        to_ref
      |> CCOption.flatten
    in
    let dirspaces, files_unknown =
      match decision with
      | Staleness.Pr_result.Fresh -> ([], false)
      | Staleness.Pr_result.Stale_files_changed dirspaces -> (dirspaces, false)
      | Staleness.Pr_result.Stale_files_unknown -> ([], true)
    in
    {
      St.is_plan =
        CCOption.exists (Wm.Step.equal Wm.Step.Plan) (CCList.last_opt work_manifest.Wm.steps);
      files_unknown;
      run_sha = S.Api.Ref.to_string from_ref;
      branch_move = move (Some from_ref) head;
      dest_branch_move = move from_dest_ref dest_head;
      dirspaces =
        CCList.map
          (fun { Terrat_dirspace.dir; workspace } -> { St.Dirspace.dir; workspace })
          dirspaces;
      is_layered_run;
      replan_dirs =
        Staleness.Pr_result.stale_dirspaces decision (dirspaces_of_wm work_manifest)
        |> Terrat_data.Dirspace_set.to_list
        |> CCList.map (fun dirspace -> dirspace.Terrat_dirspace.dir)
        |> CCList.sort_uniq ~cmp:CCString.compare;
    }

  (* A drift reconcile whose files changed while it ran reconciles again with a new drift plan job
     at the new head (RFD 2356).  The job is only made here, in the evaluation of the result, which
     works on the commit of the work manifest; [run_next_layer] runs it in an evaluation of its own
     that reads the branch again.  A result can be handled twice, thus a job that already has its
     restart gets no second one.  Two deliveries of one result do not both make a restart: the
     transaction of each result locks the compute node of the work manifest, thus the second one
     reads the restart that the first one made. *)
  let restart_drift s { Bs.Fetcher.fetch } =
    let module Tjc = Terrat_job_context in
    let open Irm in
    fetch Keys.job
    >>= fun {
              Tjc.Job.id = job_id;
              context;
              initiator;
              type_;
              completed_at = _;
              created_at = _;
              state = _;
              updated_at = _;
            }
          ->
    match type_ with
    | Tjc.Job.Type_.(
        ( Plan { tag_query; kind = Some (Kind.Drift { restart_on_change; reconcile = _ }) as kind }
        | Apply
            {
              tag_query;
              kind = Some (Kind.Drift { restart_on_change; reconcile = _ }) as kind;
              force = _;
            } )) -> (
        Builder.run_db s ~f:(fun db ->
            S.Db.query_job_restart ~request_id:(Builder.log_id s) ~job_id db
            >>= fun restart ->
            if CCOption.is_some restart then Abbs_fc.return_ok `Exists
            else
              S.Db.query_job_restart_depth ~request_id:(Builder.log_id s) ~job_id db
              >>| fun restarts -> `Restarts restarts)
        >>= function
        | `Exists -> Abbs_fc.return_ok ()
        | `Restarts restarts -> (
            match Staleness.Drift_result.restart ~restart_on_change ~restarts with
            | Staleness.Drift_result.Disabled ->
                Logs.info (fun m ->
                    m "%s : DRIFT : RESTART_DISABLED : restarts=%d" (Builder.log_id s) restarts);
                Abbs_fc.return_ok ()
            | Staleness.Drift_result.Limit_reached ->
                Logs.info (fun m ->
                    m "%s : DRIFT : RESTART_LIMIT : restarts=%d" (Builder.log_id s) restarts);
                Abbs_fc.return_ok ()
            | Staleness.Drift_result.Restart ->
                Builder.run_db s ~f:(fun db ->
                    S.Job_context.Job.create
                      ~request_id:(Builder.log_id s)
                      db
                      Tjc.Job.Type_.(Plan { tag_query; kind })
                      context
                      initiator
                    >>= fun restart ->
                    S.Db.set_job_restart_of
                      ~request_id:(Builder.log_id s)
                      ~job_id:restart.Tjc.Job.id
                      ~restart_of:job_id
                      db
                    >>| fun () ->
                    Logs.info (fun m ->
                        m
                          "%s : DRIFT : RESTART : new_job=%a : restarts=%d"
                          (Builder.log_id s)
                          Uuidm.pp
                          restart.Tjc.Job.id
                          (restarts + 1)))))
    | Tjc.Job.Type_.(
        ( Plan { kind = None; tag_query = _ }
        | Apply { kind = None; tag_query = _; force = _ }
        | Autoapply | Autoplan | Gate_approval _ | Help | Index | Push | Repo_config | Unlock _ ))
      -> Abbs_fc.return_ok ()

  let plan_superseded aborted s { Bs.Fetcher.fetch } =
    let open Irm in
    fetch Keys.job
    >>= fun job ->
    Builder.run_db s ~f:(fun db ->
        Abbs_fc.List_result.fold_left
          ~init:true
          ~f:(fun superseded wm ->
            if not superseded then Abbs_fc.return_ok false
            else
              S.Db.query_plan_superseded
                ~request_id:(Builder.log_id s)
                ~job_id:job.Terrat_job_context.Job.id
                ~work_manifest_id:wm.Wm.id
                db)
          aborted)

  let never_superseded _ _ _ = Abbs_fc.return_ok false

  module Plan = struct
    let create ~dest_branch_ref ~branch_ref ~branch s ({ Bs.Fetcher.fetch } as fetcher) =
      let open Irm in
      fetch Keys.can_run_plan
      >>= fun () -> create ~dest_branch_ref ~branch_ref ~branch `Plan s fetcher

    let initiate work_manifest s ({ Bs.Fetcher.fetch } as fetcher) =
      let id = work_manifest.Wm.id in
      let open Irm in
      fetch Keys.account
      >>= fun account ->
      fetch Keys.repo
      >>= fun repo ->
      fetch Keys.client
      >>= fun _client ->
      live_check_ref fetcher work_manifest
      >>= fun branch_ref ->
      fetch Keys.create_commit_checks
      >>= fun create_commit_checks ->
      fetch Keys.status_checks_enabled
      >>= fun status_checks_enabled ->
      let module Status = Terrat_commit_check.Status in
      create_op_commit_checks
        create_commit_checks
        status_checks_enabled
        (Builder.State.config s)
        account
        repo
        branch_ref
        work_manifest
        "Running"
        Status.Running
      >>= fun () ->
      Abbs_fc.return_ok ()
      >>= fun () ->
      let { Wm.base_ref = _; branch_ref = _; changes; target; _ } = work_manifest in
      let run_kind =
        match target with
        | P2.Target.Pr pr -> `Pull_request pr
        | P2.Target.Drift _ -> `Drift
      in
      let run_kind_str =
        match run_kind with
        | `Pull_request _ -> "pr"
        | `Drift -> "drift"
      in
      let run_kind_data =
        let module Rkd = Terrat_api_components.Work_manifest_plan.Run_kind_data in
        let module Rkdpr = Terrat_api_components.Run_kind_data_pull_request in
        match run_kind with
        | `Pull_request pr ->
            Some
              (Rkd.Run_kind_data_pull_request
                 { Rkdpr.id = S.Api.Pull_request.Id.to_string (S.Api.Pull_request.id pr) })
        | `Drift -> None
      in
      fetch Keys.derived_repo_config
      >>= fun (_, repo_config) ->
      (* Publish the unified summary comment now, before the run can produce
         any result comment, so the summary is always the first comment of the
         run.  Best effort: the implementation swallows and logs its errors. *)
      Builder.run_db s ~f:(fun db ->
          S.Comment.publish_unified_comment_at_start
            ~request_id:(Builder.log_id s)
            ~fetch_brand:(S.Repo_config.fetch_brand ~request_id:(Builder.log_id s))
            ~repo_config
            (Builder.State.config s)
            db
            id)
      >>= fun () ->
      fetch Keys.synthesized_config
      >>= fun synthesized_config ->
      fetch Keys.dest_branch_name
      >>= fun dest_branch_name ->
      Ee2_fc.Infix_result_app.(
        (fun branch_dirspaces dest_branch_dirspaces -> (branch_dirspaces, dest_branch_dirspaces))
        <$> fetch Keys.branch_dirspaces
        <*> fetch Keys.dest_branch_dirspaces)
      >>= fun (dirspaces, base_dirspaces) ->
      Builder.run_db s ~f:(fun db ->
          time_it
            s
            (fun m log_id time -> m "%s : CREATE_TOKEN : wm=%a : time=%f" log_id Uuidm.pp id time)
            (fun () ->
              Wm_sm.create_token' ~log_id:(Builder.log_id s) (S.Api.Account.id account) id db))
      >>| fun token ->
      let response =
        Terrat_api_components.(
          Work_manifest.Work_manifest_plan
            {
              Work_manifest_plan.token;
              id = Some (Uuidm.to_string id);
              api_base_url = Terrat_config.api_base @@ S.Api.Config.config @@ Builder.State.config s;
              installation_id = S.Api.Account.Id.to_string @@ S.Api.Account.id account;
              base_dirspaces;
              base_ref = S.Api.Ref.to_string dest_branch_name;
              changed_dirspaces = changed_dirspaces synthesized_config changes;
              dirspaces;
              run_kind = run_kind_str;
              run_kind_data;
              type_ = `Plan;
              result_version;
              protocol_version = Some protocol_version;
              config =
                repo_config
                |> Terrat_base_repo_config_v1.to_version_1
                |> Terrat_repo_config.Version_1.to_yojson;
              capabilities = [ "tenv" ];
            })
      in
      response

    let fail work_manifest s ({ Bs.Fetcher.fetch } as fetcher) =
      let open Irm in
      fetch Keys.account
      >>= fun account ->
      fetch Keys.repo
      >>= fun repo ->
      fetch Keys.client
      >>= fun _client ->
      live_check_ref fetcher work_manifest
      >>= fun branch_ref ->
      fetch Keys.create_commit_checks
      >>= fun create_commit_checks ->
      fetch Keys.status_checks_enabled
      >>= fun status_checks_enabled ->
      let module Status = Terrat_commit_check.Status in
      create_op_commit_checks
        create_commit_checks
        status_checks_enabled
        (Builder.State.config s)
        account
        repo
        branch_ref
        work_manifest
        "Failed"
        Status.Failed

    (* Report a stored result: its comment and its checks (RFD 2356).

       The result is stored before this, in the same transaction.  A plan that newer plans of the
       pull request superseded is stored and not reported.  The heads and the comparison of the
       files come first, because the comment shows a warning when the result is stale.  An error
       there makes the result stale and cannot stop the comment.  An error in the summary of the
       dirspaces or in the restart of a drift, which follow the output, is logged and does not stop
       the report either, thus it does not roll back the stored result.  A report that must wait for data
       is given up and the work manifest completes: a work manifest that stays running is given to
       the runner again, which runs it again.  With the refs pinned to the commit of the run, a wait
       happens only when the data of that commit is gone. *)
    let report_result2 work_manifest result work_manifest_result s ({ Bs.Fetcher.fetch } as fetcher)
        =
      let superseded () =
        let open Irm in
        match (work_manifest.Wm.target, work_manifest.Wm.steps) with
        | P2.Target.Pr _, [ Wm.Step.Plan ] -> (
            fetch Keys.job
            >>= fun job ->
            Builder.run_db s ~f:(fun db ->
                S.Db.query_plan_superseded
                  ~request_id:(Builder.log_id s)
                  ~job_id:job.Terrat_job_context.Job.id
                  ~work_manifest_id:work_manifest.Wm.id
                  db)
            >>| function
            | true -> `Superseded
            | false -> `Current)
        | P2.Target.Pr _, ([] | _ :: _) | P2.Target.Drift _, _ -> Abbs_fc.return_ok `Current
      in
      let publish_output compared decision =
        let open Irm in
        fetch Keys.matches
        >>= fun matches ->
        fetch Keys.account_status
        >>= fun account_status ->
        (* TODO: HUGE HACK, redo this later *)
        let run =
          let open Irm in
          Ee2_fc.all3
            (fetch Keys.client)
            (fetch Keys.repo_config_with_provenance)
            (fetch Keys.repo_tree_branch)
          >>= fun (_client, (_provenance, repo_config), repo_tree) ->
          fetch Keys.dest_branch_name
          >>= fun dest_branch_name ->
          fetch Keys.branch_name
          >>= fun branch_name ->
          fetch Keys.repo_index_branch
          >>= fun index ->
          Abb.Thread.run (fun () ->
              Terrat_base_repo_config_v1.derive
                ~ctx:
                  (Terrat_base_repo_config_v1.Ctx.make
                     ~dest_branch:(S.Api.Ref.to_string dest_branch_name)
                     ~branch:(S.Api.Ref.to_string branch_name)
                     ())
                ~index
                ~file_list:repo_tree
                repo_config)
          >>= fun repo_config ->
          Abb.Future.return (Terrat_change_match3.synthesize_config ~index repo_config)
          >>| fun synthesized_config -> (repo_config, synthesized_config)
        in
        run
        >>= fun (repo_config, synthesized_config) ->
        (* The layer counts must be taken against the config that produced
           [matches].  [synthesized_config] above is a second synthesis, made
           here for the message; [Terrat_change_match3.apply_layers_of] looks
           its argument up in the config's dirspace map and raises if it is
           not there, so pairing the two would turn any drift between them
           into an exception on the comment path. *)
        fetch Keys.synthesized_config
        >>= fun matches_config ->
        (* TODO: HUGE HACK, redo this later *)
        fetch Keys.publish_comment
        >>= fun publish_comment ->
        let is_layered_run =
          CCList.length
            (Terrat_change_match3.apply_layers_of
               matches_config
               (CCList.flatten matches.Keys.Matches.all_matches))
          > 1
        in
        Builder.run_db s ~f:(fun db ->
            time_it
              s
              (fun m log_id time ->
                m
                  "%s : PUBLISH_COMMENT : TF_OP_RESULT2 : wm=%a : time=%f"
                  log_id
                  Uuidm.pp
                  work_manifest.Wm.id
                  time)
              (fun () ->
                publish_comment'
                  publish_comment
                  (Msg.Tf_op_result2
                     {
                       account_status;
                       config = Builder.State.config s;
                       db;
                       is_layered_run;
                       num_remaining_layers =
                         CCList.length
                           (Terrat_change_match3.apply_layers_of
                              matches_config
                              (CCList.flatten matches.Keys.Matches.all_unapplied_matches));
                       result;
                       repo_config;
                       stale =
                         (match decision with
                         | Staleness.Pr_result.Fresh -> None
                         | Staleness.Pr_result.(Stale_files_changed _ | Stale_files_unknown) ->
                             Some (stale_report ~is_layered_run compared work_manifest decision));
                       synthesized_config;
                       work_manifest;
                     })))
      in
      let report () =
        let open Irm in
        superseded ()
        >>= function
        | `Superseded ->
            Logs.info (fun m ->
                m
                  "%s : PLAN_RESULT_SUPERSEDED : wm=%a"
                  (Builder.log_id s)
                  Uuidm.pp
                  work_manifest.Wm.id);
            record_result_heads s fetcher work_manifest >>| fun _ -> ()
        | `Current -> (
            result_staleness s fetcher work_manifest
            >>= fun (impact, compared) ->
            let decision = Staleness.Pr_result.decide impact in
            (* A drift has no pull request to comment on. *)
            (match work_manifest.Wm.target with
              | P2.Target.Pr _ -> publish_output compared decision
              | P2.Target.Drift _ -> Abbs_fc.return_ok ())
            >>= fun () ->
            check_refs fetcher work_manifest ~run_ref:compared.from_ref decision
            >>= fun (check_ref, stale) ->
            fetch Keys.repo
            >>= fun repo ->
            fetch Keys.create_commit_checks
            >>= fun create_commit_checks ->
            fetch Keys.status_checks_enabled
            >>= fun status_checks_enabled ->
            create_op_commit_checks_of_result
              ?stale
              create_commit_checks
              status_checks_enabled
              (Builder.State.config s)
              work_manifest.Wm.account
              repo
              check_ref
              work_manifest
              work_manifest_result
            >>= fun () ->
            match work_manifest.Wm.target with
            | P2.Target.Pr _ ->
                (* The summary comment shows the result at the head of the pull request, where the
                   checks of the fresh dirspaces go.  A stale dirspace waits for a new plan. *)
                fetch Keys.context
                >>= fun context ->
                let stale =
                  Staleness.Pr_result.stale_dirspaces decision (dirspaces_of_wm work_manifest)
                in
                let run =
                  if
                    CCOption.exists
                      (function
                        | Wm.Step.(Apply | Unsafe_apply) -> true
                        | Wm.Step.(Build_config | Build_tree | Index | Plan) -> false)
                      (CCList.last_opt work_manifest.Wm.steps)
                  then `Apply
                  else `Plan
                in
                let module Wmr = P2.Work_manifest_result in
                (* The result is stored before the report, thus the most recent good plan of a
                   dirspace is the plan of this result, and it is the plan the selection reads. *)
                or_default s work_manifest ~what:"DIRSPACE_SUMMARIES_ERR" ~default:()
                @@ ((match run with
                      | `Apply -> Abbs_fc.return_ok Terrat_data.Dirspace_set.empty
                      | `Plan ->
                          Builder.run_db s ~f:(fun db ->
                              Tasks_base.query_dirspace_runs_for_context
                                s
                                db
                                context
                                (CCList.map fst work_manifest_result.Wmr.dirspaces_success))
                          >>| fun runs ->
                          runs
                          |> CCList.filter_map
                               (fun
                                 {
                                   P2.Dirspace_runs.state =
                                     {
                                       Terrat_intra_pr_hash.Dirspace_state.dirspace;
                                       last_plan;
                                       last_apply = _;
                                     };
                                   plan_failed = _;
                                   apply_failed = _;
                                   in_progress_plan = _;
                                 }
                               ->
                                 CCOption.return_if
                                   (CCOption.exists
                                      (fun { Terrat_intra_pr_hash.Plan.has_changes; run = _ } ->
                                        not has_changes)
                                      last_plan)
                                   dirspace)
                          |> Terrat_data.Dirspace_set.of_list)
                   >>= fun no_changes ->
                   Builder.run_db s ~f:(fun db ->
                       S.Db.store_dirspace_summaries
                         ~request_id:(Builder.log_id s)
                         db
                         context
                         ~sha:check_ref
                         ~work_manifest:(Some work_manifest.Wm.id)
                         (CCList.map
                            (fun (dirspace, success) ->
                              ( dirspace,
                                Staleness.Summary.of_result ~run ~stale ~no_changes dirspace success
                              ))
                            work_manifest_result.Wmr.dirspaces_success)))
            | P2.Target.Drift _ -> (
                let decision = Staleness.Drift_result.decide impact in
                Logs.info (fun m ->
                    m
                      "%s : DRIFT_RESULT : wm=%a : decision=%a"
                      (Builder.log_id s)
                      Uuidm.pp
                      work_manifest.Wm.id
                      Staleness.Drift_result.pp_decision
                      decision);
                match decision with
                | Staleness.Drift_result.Resolved -> Abbs_fc.return_ok ()
                | Staleness.Drift_result.Reconcile_again ->
                    or_default
                      s
                      work_manifest
                      ~what:"RESTART_DRIFT_ERR"
                      ~default:()
                      (restart_drift s fetcher)))
      in
      let open Abb.Future.Infix_monad in
      report ()
      >>= function
      | Ok () -> Abbs_fc.return_ok ()
      | Error (`Suspend_eval name) ->
          Logs.err (fun m ->
              m
                "%s : RESULT : REPORT_SUSPENDED : wm=%a : name=%s"
                (Builder.log_id s)
                Uuidm.pp
                work_manifest.Wm.id
                name);
          Abbs_fc.return_ok ()
      | Error _ as err -> Abb.Future.return err

    let result work_manifest result s ({ Bs.Fetcher.fetch } as fetcher) =
      let open Irm in
      match result with
      | Wmr.Work_manifest_tf_operation_result2 result ->
          let work_manifest_result = S.Work_manifest.result2 result in
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : STORE_TF_OPERATION_RESULT2 : wm=%a : time=%f"
                    log_id
                    Uuidm.pp
                    work_manifest.Wm.id
                    time)
                (fun () ->
                  S.Db.store_tf_operation_result2
                    ~request_id:(Builder.log_id s)
                    db
                    work_manifest.Wm.id
                    result))
          >>= fun () ->
          (* The heads go with the result, for every result that is stored, thus a later
             evaluation compares the same commits as this one.  The report records them after it
             posts the output. *)
          if work_manifest.Wm.state <> Wm.State.Aborted then
            (* In the case of an abort, we do not report back to the user, we
                just want to store the results. *)
            report_result2 work_manifest result work_manifest_result s fetcher
          else record_result_heads s fetcher work_manifest >>| fun _ -> ()
      | Wmr.Work_manifest_tf_operation_result result ->
          let open Irm in
          let work_manifest_result = S.Work_manifest.result result in
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : STORE_TF_OPERATION_RESULT : wm=%a : time=%f"
                    log_id
                    Uuidm.pp
                    work_manifest.Wm.id
                    time)
                (fun () ->
                  S.Db.store_tf_operation_result
                    ~request_id:(Builder.log_id s)
                    db
                    work_manifest.Wm.id
                    result))
          >>= fun () ->
          if work_manifest.Wm.state <> Wm.State.Aborted then
            fetch Keys.repo
            >>= fun repo ->
            fetch Keys.branch_ref
            >>= fun branch_ref ->
            fetch Keys.create_commit_checks
            >>= fun create_commit_checks ->
            fetch Keys.status_checks_enabled
            >>= fun status_checks_enabled ->
            create_op_commit_checks_of_result
              create_commit_checks
              status_checks_enabled
              (Builder.State.config s)
              work_manifest.Wm.account
              repo
              branch_ref
              work_manifest
              work_manifest_result
            >>| fun () -> ()
          else Abbs_fc.return_ok ()
      | Wmr.Work_manifest_index_result _ -> assert false
      | Wmr.Work_manifest_build_config_result _ -> assert false
      | Wmr.Work_manifest_build_result_failure _ -> assert false
      | Wmr.Work_manifest_build_tree_result _ -> assert false

    let run ~dest_branch_ref ~branch_ref ~branch ~name s fetcher =
      Wm_sm.run
        ~name
        ~membership:(Wm_sm.Steps { steps = [ Wm.Step.Plan ]; start; superseded = plan_superseded })
        ~dest_branch_ref
        ~branch_ref
        ~branch
        ~create
        ~initiate
        ~fail
        ~result
        s
        fetcher
  end

  module Apply = struct
    let maybe_comment_autoapply_running _s { Bs.Fetcher.fetch } =
      let module Tjc = Terrat_job_context in
      let open Irm in
      fetch Keys.context
      >>= function
      | { Tjc.Context.scope = Tjc.Context.Scope.Pull_request _; _ } -> (
          fetch Keys.job
          >>= function
          | { Tjc.Job.type_ = Tjc.Job.Type_.Autoapply; _ } -> (
              fetch Keys.pull_request
              >>= fun pull_request ->
              match S.Api.Pull_request.state pull_request with
              | Terrat_pull_request.State.Merged _ ->
                  fetch Keys.publish_comment
                  >>= fun publish_comment -> publish_comment' publish_comment Msg.Autoapply_running
              | _ -> Abbs_fc.return_ok ())
          | _ -> Abbs_fc.return_ok ())
      | _ -> Abbs_fc.return_ok ()

    (* The apply is created and queued, but the dispatcher does not start it
       while other work runs against its dirspaces.  Nothing downstream speaks
       again until that work finishes, so say what the apply waits for.  Without
       this the reaction on the comment is the only answer the user gets. *)
    let maybe_comment_queued_behind wms s { Bs.Fetcher.fetch } =
      let module Tjc = Terrat_job_context in
      let open Irm in
      let changes = CCList.flat_map (fun { Wm.changes; _ } -> changes) wms in
      let dirspaces = CCList.map Terrat_change.Dirspaceflow.to_dirspace changes in
      fetch Keys.repo_config
      >>= fun repo_config ->
      (* The applies are not yet tied to the job, thus the query cannot read
         their dirspaces and is given them. *)
      let stategraph_parallel_apply_dirspaces =
        Tasks_base.stategraph_parallel_apply_dirspaces_of_work_manifest repo_config changes
      in
      fetch Keys.context
      >>= function
      (* A drift apply has nowhere to publish, so there is nothing to say and no
         reason to ask the question. *)
      | { Tjc.Context.scope = Tjc.Context.Scope.Branch _; _ } -> Abbs_fc.return_ok ()
      | context -> (
          match dirspaces with
          | [] -> Abbs_fc.return_ok ()
          | dirspaces -> (
              fetch Keys.job
              >>= fun job ->
              Builder.run_db s ~f:(fun db ->
                  S.Db.query_blocking_work_manifests_in_repo_for_context
                    ~request_id:(Builder.log_id s)
                    ~job_id:job.Tjc.Job.id
                    db
                    context
                    dirspaces
                    ~stategraph_parallel_apply_dirspaces)
              >>= function
              | [] -> Abbs_fc.return_ok ()
              | blocking_wms ->
                  CCList.iter
                    (fun { Wm.id; _ } ->
                      Logs.info (fun m ->
                          m
                            "%s : APPLY_QUEUED_BEHIND_WORK_MANIFEST : id=%a"
                            (Builder.log_id s)
                            Uuidm.pp
                            id))
                    blocking_wms;
                  fetch Keys.publish_comment
                  >>= fun publish_comment ->
                  publish_comment'
                    publish_comment
                    (Msg.Apply_queued_behind_work_manifests blocking_wms)))

    let create ~dest_branch_ref ~branch_ref ~branch s ({ Bs.Fetcher.fetch } as fetcher) =
      let open Irm in
      fetch Keys.can_run_apply
      >>= fun () ->
      maybe_comment_autoapply_running s fetcher
      >>= fun () ->
      create ~dest_branch_ref ~branch_ref ~branch `Apply s fetcher
      >>= fun wms -> maybe_comment_queued_behind wms s fetcher >>| fun () -> wms

    let initiate work_manifest s ({ Bs.Fetcher.fetch } as fetcher) =
      let id = work_manifest.Wm.id in
      let open Irm in
      fetch Keys.account
      >>= fun account ->
      fetch Keys.repo
      >>= fun repo ->
      fetch Keys.client
      >>= fun _client ->
      live_check_ref fetcher work_manifest
      >>= fun branch_ref ->
      fetch Keys.create_commit_checks
      >>= fun create_commit_checks ->
      fetch Keys.status_checks_enabled
      >>= fun status_checks_enabled ->
      let module Status = Terrat_commit_check.Status in
      create_op_commit_checks
        create_commit_checks
        status_checks_enabled
        (Builder.State.config s)
        account
        repo
        branch_ref
        work_manifest
        "Running"
        Status.Running
      >>= fun () ->
      let { Wm.base_ref = _; branch_ref = _; changes; target; _ } = work_manifest in
      let run_kind =
        match target with
        | P2.Target.Pr pr -> `Pull_request pr
        | P2.Target.Drift _ -> `Drift
      in
      let run_kind_str =
        match run_kind with
        | `Pull_request _ -> "pr"
        | `Drift -> "drift"
      in
      let run_kind_data =
        let module Rkd = Terrat_api_components.Work_manifest_apply.Run_kind_data in
        let module Rkdpr = Terrat_api_components.Run_kind_data_pull_request in
        match run_kind with
        | `Pull_request pr ->
            Some
              (Rkd.Run_kind_data_pull_request
                 { Rkdpr.id = S.Api.Pull_request.Id.to_string (S.Api.Pull_request.id pr) })
        | `Drift -> None
      in
      fetch Keys.derived_repo_config
      >>= fun (_, repo_config) ->
      (* Publish the unified summary comment now, before the run can produce
         any result comment, so the summary is always the first comment of the
         run.  Best effort: the implementation swallows and logs its errors. *)
      Builder.run_db s ~f:(fun db ->
          S.Comment.publish_unified_comment_at_start
            ~request_id:(Builder.log_id s)
            ~fetch_brand:(S.Repo_config.fetch_brand ~request_id:(Builder.log_id s))
            ~repo_config
            (Builder.State.config s)
            db
            id)
      >>= fun () ->
      fetch Keys.synthesized_config
      >>= fun synthesized_config ->
      fetch Keys.dest_branch_name
      >>= fun dest_branch_name ->
      Builder.run_db s ~f:(fun db ->
          time_it
            s
            (fun m log_id time -> m "%s : CREATE_TOKEN : wm=%a : time=%f" log_id Uuidm.pp id time)
            (fun () ->
              Wm_sm.create_token' ~log_id:(Builder.log_id s) (S.Api.Account.id account) id db))
      >>| fun token ->
      let response =
        Terrat_api_components.(
          Work_manifest.Work_manifest_apply
            {
              Work_manifest_apply.token;
              id = Some (Uuidm.to_string id);
              api_base_url = Terrat_config.api_base @@ S.Api.Config.config @@ Builder.State.config s;
              installation_id = S.Api.Account.Id.to_string @@ S.Api.Account.id account;
              base_ref = S.Api.Ref.to_string dest_branch_name;
              changed_dirspaces = changed_dirspaces synthesized_config changes;
              run_kind = run_kind_str;
              run_kind_data;
              type_ = `Apply;
              result_version;
              protocol_version = Some protocol_version;
              config =
                repo_config
                |> Terrat_base_repo_config_v1.to_version_1
                |> Terrat_repo_config.Version_1.to_yojson;
              capabilities = [ "tenv" ];
            })
      in
      response

    (* A failed apply is normally aborted, and its job makes it again.  An apply that started and
       whose files changed while it ran is not made again at the new head (RFD 2356): it is
       completed, and the user is told that the commits moved and decides.  An apply that never
       started has no start commit and keeps the normal path.  An apply that is completed already
       told the user: a second failure event, for example of the action run after its result
       failed, posts nothing again. *)
    let complete_stale_failure work_manifest s ({ Bs.Fetcher.fetch } as fetcher) =
      let open Irm in
      match (work_manifest.Wm.target, work_manifest.Wm.state) with
      | P2.Target.Drift _, _ | P2.Target.Pr _, Wm.State.Completed -> Abbs_fc.return_ok ()
      | P2.Target.Pr _, Wm.State.(Queued | Running | Aborted) -> (
          Builder.run_db s ~f:(fun db ->
              S.Work_manifest.query_start_refs ~request_id:(Builder.log_id s) db work_manifest.Wm.id)
          >>= fun (start_sha, _) ->
          if CCOption.is_none start_sha then Abbs_fc.return_ok ()
          else
            result_heads s fetcher work_manifest
            >>= fun (head, dest_head) ->
            result_impact s fetcher work_manifest ~head ~dest_head
            >>= fun (impact, compared) ->
            match Staleness.Pr_result.decide impact with
            | Staleness.Pr_result.Fresh -> Abbs_fc.return_ok ()
            | Staleness.Pr_result.(Stale_files_changed _ | Stale_files_unknown) as decision ->
                Logs.info (fun m ->
                    m
                      "%s : APPLY_FAILED_STALE : wm=%a : completed"
                      (Builder.log_id s)
                      Uuidm.pp
                      work_manifest.Wm.id);
                Builder.run_db s ~f:(fun db ->
                    S.Work_manifest.update_state
                      ~request_id:(Builder.log_id s)
                      db
                      work_manifest.Wm.id
                      Wm.State.Completed)
                >>= fun () ->
                Abbs_fc.to_result
                  (Tasks_base.release_stategraph_reservation
                     ~request_id:(Builder.log_id s)
                     work_manifest.Wm.id)
                >>= fun () ->
                fetch Keys.publish_comment
                >>= fun publish_comment ->
                publish_comment'
                  publish_comment
                  (Msg.Work_manifest_stale
                     (stale_report ~is_layered_run:false compared work_manifest decision)))

    let fail work_manifest s ({ Bs.Fetcher.fetch } as fetcher) =
      let open Irm in
      fetch Keys.account
      >>= fun account ->
      fetch Keys.repo
      >>= fun repo ->
      live_check_ref fetcher work_manifest
      >>= fun branch_ref ->
      fetch Keys.create_commit_checks
      >>= fun create_commit_checks ->
      fetch Keys.status_checks_enabled
      >>= fun status_checks_enabled ->
      let module Status = Terrat_commit_check.Status in
      create_op_commit_checks
        create_commit_checks
        status_checks_enabled
        (Builder.State.config s)
        account
        repo
        branch_ref
        work_manifest
        "Failed"
        Status.Failed
      >>= fun () -> complete_stale_failure work_manifest s fetcher

    let result = Plan.result

    let run ~dest_branch_ref ~branch_ref ~branch ~name s fetcher =
      Wm_sm.run
        ~name
        ~membership:
          (Wm_sm.Steps { steps = [ Wm.Step.Apply ]; start; superseded = never_superseded })
        ~dest_branch_ref
        ~branch_ref
        ~branch
        ~create
        ~initiate
        ~fail
        ~result
        s
        fetcher
  end
end
