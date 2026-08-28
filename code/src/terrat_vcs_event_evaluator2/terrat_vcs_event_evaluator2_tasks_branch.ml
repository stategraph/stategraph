module Irm = Abbs_future_combinators.Infix_result_monad
module Ee2_fc = Terrat_vcs_event_evaluator2_fc
module Tjc = Terrat_job_context
module P2 = Terrat_vcs_provider2

module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) =
struct
  let src = Logs.Src.create ("vcs_event_evaluator2_tasks_branch." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module Hmap = Keys.Hmap
  module Builder = Terrat_vcs_event_evaluator2_builder.Make (S)
  module Bs = Builder.Bs
  module Tasks_base = Terrat_vcs_event_evaluator2_tasks_base.Make (S) (Keys)

  let time_it s l f =
    Abbs_time_it.run (fun time -> Logs.info (fun m -> l m (Builder.log_id s) time)) f

  module Tasks = struct
    let run = Tasks_base.run

    let branch_name =
      run ~name:"branch_name" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.context
          >>= function
          | { Tjc.Context.scope = Tjc.Context.Scope.Branch (branch_name, _); _ } ->
              Abbs_future_combinators.return_ok branch_name
          | _ -> assert false)

    let branch_ref =
      run ~name:"branch_ref" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.branch_name
          >>= fun branch_name ->
          fetch Keys.client
          >>= fun client ->
          fetch Keys.repo
          >>= fun repo ->
          time_it
            s
            (fun m log_id time ->
              m
                "%s : FETCH_BRANCH_SHA : repo = %s : branch = %s : time=%f"
                log_id
                (S.Api.Repo.to_string repo)
                (S.Api.Ref.to_string branch_name)
                time)
            (fun () ->
              S.Api.fetch_branch_sha ~request_id:(Builder.log_id s) client repo branch_name)
          >>? function
          | Some ref_ -> Ok ref_
          | None -> Error (`Branch_not_found_err (S.Api.Ref.to_string branch_name)))

    (* Is this the right choice?  Returning the branch anme if the dest branch
       name doesn't exist?  For now, yes.  We eventually want to have better
       support for this, but right now to be compatible with a lot of the code
       base, always return a dest branch and then in places in the code where we
       care if the dest branch adn the branch name are the same, it just checks
       there and does the right thing. *)
    let dest_branch_name =
      run ~name:"dest_branch_name" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.context
          >>= function
          | { Tjc.Context.scope = Tjc.Context.Scope.Branch (_, Some dest_branch_name); _ } ->
              Abbs_future_combinators.return_ok dest_branch_name
          | { Tjc.Context.scope = Tjc.Context.Scope.Branch (branch_name, None); _ } ->
              Abbs_future_combinators.return_ok branch_name
          | _ -> assert false)

    let dest_branch_ref =
      run ~name:"dest_branch_ref" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.dest_branch_name
          >>= fun dest_branch_name ->
          fetch Keys.client
          >>= fun client ->
          fetch Keys.repo
          >>= fun repo ->
          time_it
            s
            (fun m log_id time ->
              m
                "%s : FETCH_BRANCH_SHA : repo = %s : branch = %s : time=%f"
                log_id
                (S.Api.Repo.to_string repo)
                (S.Api.Ref.to_string dest_branch_name)
                time)
            (fun () ->
              S.Api.fetch_branch_sha ~request_id:(Builder.log_id s) client repo dest_branch_name)
          >>? function
          | Some ref_ -> Ok ref_
          | None -> Error (`Branch_not_found_err (S.Api.Ref.to_string dest_branch_name)))

    let working_dest_branch_ref =
      run ~name:"working_dest_branch_ref" (fun _ { Bs.Fetcher.fetch } -> fetch Keys.dest_branch_ref)

    let working_branch_ref =
      run ~name:"working_branch_ref" (fun _s { Bs.Fetcher.fetch } -> fetch Keys.branch_ref)

    let working_branch_name =
      run ~name:"working_branch_name" (fun _s { Bs.Fetcher.fetch } -> fetch Keys.branch_name)

    let out_of_change_applies =
      run ~name:"out_of_change_applies" (fun _ _ -> Abbs_future_combinators.return_ok [])

    let changes =
      run ~name:"changes" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          let go () =
            Ee2_fc.all2 (fetch Keys.dest_branch_name) (fetch Keys.branch_name)
            >>= function
            | dest_branch_name, branch_name when S.Api.Ref.equal dest_branch_name branch_name ->
                fetch Keys.repo_tree_branch
                >>| fun tree ->
                CCList.map (fun filename -> Terrat_change.Diff.Change { filename }) tree
            | dest_branch_name, branch_name ->
                fetch Keys.client
                >>= fun client ->
                fetch Keys.repo
                >>= fun repo ->
                time_it
                  s
                  (fun m log_id time ->
                    m
                      "%s : FETCH_DIFF_FILES : repo = %s : base_branch = %s : branch = %s : time=%f"
                      log_id
                      (S.Api.Repo.to_string repo)
                      (S.Api.Ref.to_string dest_branch_name)
                      (S.Api.Ref.to_string branch_name)
                      time)
                  (fun () ->
                    S.Api.fetch_diff_files
                      ~request_id:(Builder.log_id s)
                      ~base_ref:dest_branch_name
                      ~branch_ref:branch_name
                      repo
                      client)
          in
          go ()
          >>| fun diff ->
          Logs.info (fun m -> m "%s : CHANGES : %d" (Builder.log_id s) (CCList.length diff));
          diff)

    let missing_autoplan_matches =
      run ~name:"missing_autoplan_matches" (fun _ _ ->
          Abbs_future_combinators.return_ok (fun matches ->
              Abbs_future_combinators.return_ok matches))

    let is_draft_pr =
      run ~name:"is_draft_pr" (fun _s { Bs.Fetcher.fetch = _ } ->
          Abbs_future_combinators.return_ok false)

    let check_conflicting_apply_work_manifests =
      run ~name:"check_conflicting_apply_work_manifests" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.working_set_matches
          >>= fun working_set_matches ->
          fetch Keys.context
          >>= fun context ->
          fetch Keys.job
          >>= fun job ->
          let dirspaces =
            CCList.map
              (fun { Terrat_change_match3.Dirspace_config.dirspace; _ } -> dirspace)
              working_set_matches
          in
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : QUERY_CONFLICTING_WORK_MANIFESTS : context_id = %a : time=%f"
                    log_id
                    Uuidm.pp
                    context.Tjc.Context.id
                    time)
                (fun () ->
                  S.Db.query_conflicting_work_manifests_in_repo_for_context
                    ~request_id:(Builder.log_id s)
                    ~job_id:job.Tjc.Job.id
                    db
                    context
                    dirspaces
                    `Apply))
          >>? function
          | None -> Ok ()
          | Some (P2.Conflicting_work_manifests.Conflicting _) -> Error `Noop
          | Some (P2.Conflicting_work_manifests.Maybe_stale _) -> Error `Noop)

    let can_run_plan =
      run ~name:"can_run_plan" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.all2 (fetch Keys.branch_dirspaces) (fetch Keys.dest_branch_dirspaces)
          >>| fun (_, _) -> ())

    let can_run_apply =
      run ~name:"can_run_apply" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.ignore
          @@ Ee2_fc.all3
               (fetch Keys.check_conflicting_apply_work_manifests)
               (fetch Keys.branch_dirspaces)
               (fetch Keys.dest_branch_dirspaces)
          >>| fun () -> ())

    let publish_comment =
      run ~name:"publish_comment" (fun _ _ ->
          Abbs_future_combinators.return_ok (fun _ -> Abbs_future_combinators.return_ok ()))

    let create_commit_checks =
      run ~name:"create_commit_checks" (fun _ _ ->
          Abbs_future_combinators.return_ok (fun _ _ -> Abbs_future_combinators.return_ok ()))

    let access_control_eval_apply =
      run ~name:"access_control_eval_apply" (fun _ { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.working_set_matches
          >>| fun working_set_matches ->
          let r = Terrat_access_control2.{ R.deny = []; pass = working_set_matches } in
          Ok r)

    let access_control_eval_plan =
      run ~name:"access_control_eval_plan" (fun _ { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.working_set_matches
          >>| fun working_set_matches ->
          let r = Terrat_access_control2.{ R.deny = []; pass = working_set_matches } in
          Ok r)

    let maybe_automerge =
      run ~name:"maybe_automerge" (fun _s _fetcher -> Abbs_future_combinators.return_ok ())
  end

  let tasks tasks =
    let coerce = Builder.coerce_to_task in
    tasks
    (* |> Hmap.add (coerce Keys.access_control_eval_apply) Tasks.access_control_eval_apply *)
    (* |> Hmap.add (coerce Keys.check_access_control_apply) Tasks.check_access_control_apply *)
    (* |> Hmap.add (coerce Keys.check_access_control_ci_change) Tasks.check_access_control_ci_change *)
    (* |> Hmap.add (coerce Keys.check_access_control_files) Tasks.check_access_control_files *)
    (* |> Hmap.add (coerce Keys.check_access_control_plan) Tasks.check_access_control_plan *)
    (* |> Hmap.add *)
    (*      (coerce Keys.check_access_control_repo_config) *)
    (*      Tasks.check_access_control_repo_config *)
    (* |> Hmap.add *)
    (*      (coerce Keys.check_conflicting_apply_work_manifests) *)
    (*      Tasks.check_conflicting_apply_work_manifests *)
    (* |> Hmap.add *)
    (*      (coerce Keys.check_conflicting_plan_work_manifests) *)
    (*      Tasks.check_conflicting_plan_work_manifests *)
    (* |> Hmap.add (coerce Keys.check_dirspaces_missing_plans) Tasks.check_dirspaces_missing_plans *)
    (* |> Hmap.add *)
    (*      (coerce Keys.check_dirspaces_owned_by_other_pull_requests) *)
    (*      Tasks.check_dirspaces_owned_by_other_pull_requests *)
    (* |> Hmap.add (coerce Keys.check_dirspaces_to_apply) Tasks.check_dirspaces_to_apply *)
    (* |> Hmap.add (coerce Keys.check_dirspaces_to_plan) Tasks.check_dirspaces_to_plan *)
    (* |> Hmap.add (coerce Keys.check_merge_conflict) Tasks.check_merge_conflict *)
    |> Hmap.add (coerce Keys.access_control_eval_apply) Tasks.access_control_eval_apply
    |> Hmap.add (coerce Keys.access_control_eval_plan) Tasks.access_control_eval_plan
    |> Hmap.add (coerce Keys.branch_name) Tasks.branch_name
    |> Hmap.add (coerce Keys.branch_ref) Tasks.branch_ref
    |> Hmap.add (coerce Keys.can_run_apply) Tasks.can_run_apply
    |> Hmap.add (coerce Keys.can_run_plan) Tasks.can_run_plan
    |> Hmap.add (coerce Keys.changes) Tasks.changes
    |> Hmap.add
         (coerce Keys.check_conflicting_apply_work_manifests)
         Tasks.check_conflicting_apply_work_manifests
    |> Hmap.add (coerce Keys.create_commit_checks) Tasks.create_commit_checks
    |> Hmap.add (coerce Keys.create_commit_checks) Tasks.create_commit_checks
    |> Hmap.add (coerce Keys.dest_branch_name) Tasks.dest_branch_name
    |> Hmap.add (coerce Keys.dest_branch_ref) Tasks.dest_branch_ref
    |> Hmap.add (coerce Keys.is_draft_pr) Tasks.is_draft_pr
    |> Hmap.add (coerce Keys.maybe_automerge) Tasks.maybe_automerge
    |> Hmap.add (coerce Keys.missing_autoplan_matches) Tasks.missing_autoplan_matches
    |> Hmap.add (coerce Keys.out_of_change_applies) Tasks.out_of_change_applies
    |> Hmap.add (coerce Keys.publish_comment) Tasks.publish_comment
    |> Hmap.add (coerce Keys.working_branch_name) Tasks.working_branch_name
    |> Hmap.add (coerce Keys.working_branch_ref) Tasks.working_branch_ref
    |> Hmap.add (coerce Keys.working_dest_branch_ref) Tasks.working_dest_branch_ref
end
