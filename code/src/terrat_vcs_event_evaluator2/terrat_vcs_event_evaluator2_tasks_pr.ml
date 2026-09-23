module Irm = Abbs_future_combinators.Infix_result_monad
module Ee2_fc = Terrat_vcs_event_evaluator2_fc
module Tjc = Terrat_job_context
module Msg = Terrat_vcs_provider2.Msg
module P2 = Terrat_vcs_provider2

module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) =
struct
  let src = Logs.Src.create ("vcs_event_evaluator2_tasks_pr." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module Access_control = Terrat_vcs_event_evaluator2_access_control.Make (S) (Keys)
  module Hmap = Keys.Hmap
  module Builder = Terrat_vcs_event_evaluator2_builder.Make (S)
  module Bs = Builder.Bs
  module Tasks_base = Terrat_vcs_event_evaluator2_tasks_base.Make (S) (Keys)

  module H = struct
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
  end

  let time_it s l f =
    Abbs_time_it.run (fun time -> Logs.info (fun m -> l m (Builder.log_id s) time)) f

  let publish_comment s client user pull_request msg =
    time_it
      s
      (fun m log_id time -> m "%s : PUBLISH_COMMENT : time=%f" log_id time)
      (fun () ->
        let open Abbs_future_combinators.Infix_result_monad in
        Terrat_vcs_api.collapse_call_err (fun () ->
            S.Repo_config.fetch_brand
              ~request_id:(Builder.log_id s)
              client
              (S.Api.Pull_request.repo pull_request))
        >>= fun brand ->
        S.Comment.publish_comment
          ~request_id:(Builder.log_id s)
          ~brand
          client
          (CCOption.map_or ~default:"" S.Api.User.to_string user)
          pull_request
          msg)

  let query_pull_request_out_of_change_applies s db pull_request =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : QUERY_PULL_REQUEST_OUT_OF_CHANGE_APPLIES : pull_request_id = %s : time=%f"
          log_id
          (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
          time)
      (fun () ->
        S.Db.query_pull_request_out_of_change_applies ~request_id:(Builder.log_id s) db pull_request)

  let query_dirspace_runs_for_context s db context dirspaces =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : QUERY_DIRSPACE_RUNS_FOR_CONTEXT : context = %a : dirspaces = %d : time=%f"
          log_id
          Uuidm.pp
          context.Terrat_job_context.Context.id
          (CCList.length dirspaces)
          time)
      (fun () ->
        S.Db.query_dirspace_runs_for_context ~request_id:(Builder.log_id s) db context dirspaces)

  let query_repo_tree_changes ~base_ref s db account branch_ref =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : QUERY_REPO_TREE_CHANGES : base_ref = %s : branch_ref = %s : time=%f"
          log_id
          (S.Api.Ref.to_string base_ref)
          (S.Api.Ref.to_string branch_ref)
          time)
      (fun () ->
        S.Db.query_repo_tree_changes ~request_id:(Builder.log_id s) ~base_ref db account branch_ref)

  let lock_repository s account repo db =
    time_it
      s
      (fun m log_id time ->
        m "%s : LOCK_REPOSITORY : repo=%s : time=%f" log_id (S.Api.Repo.to_string repo) time)
      (fun () -> S.Db.lock_repository ~request_id:(Builder.log_id s) db account repo)

  let query_dirspaces_without_valid_plans ~base_ref ~branch_ref s db pull_request dirspaces =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : QUERY_DIRSPACES_WITHOUT_VALID_PLANS : pull_request_id = %s : time=%f"
          log_id
          (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
          time)
      (fun () ->
        S.Db.query_dirspaces_without_valid_plans
          ~request_id:(Builder.log_id s)
          ~base_ref
          ~branch_ref
          db
          pull_request
          dirspaces)

  let query_index s db account branch_ref =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : QUERY_INDEX : account = %s : branch = %s : time=%f"
          log_id
          (S.Api.Account.to_string account)
          (S.Api.Ref.to_string branch_ref)
          time)
      (fun () -> S.Db.query_index ~request_id:(Builder.log_id s) db account branch_ref)

  let unlock s db repo unlock_ids =
    time_it
      s
      (fun m log_id time ->
        m "%s : UNLOCk : repo = %s : time=%f" log_id (S.Api.Repo.to_string repo) time)
      (fun () ->
        Abbs_future_combinators.List_result.iter
          ~f:(S.Db.unlock ~request_id:(Builder.log_id s) db repo)
          unlock_ids)

  let react_to_comment s client pull_request comment_id =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : REACT_TO_COMMENT : pull_request_id = %s : time=%f"
          log_id
          (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
          time)
      (fun () ->
        S.Api.react_to_comment ~request_id:(Builder.log_id s) client pull_request comment_id)

  let fetch_pull_request s account client repo pull_request_id =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : FETCH_PULL_REQUEST : repo = %s : pull_request_id = %s : time=%f"
          log_id
          (S.Api.Repo.to_string repo)
          (S.Api.Pull_request.Id.to_string pull_request_id)
          time)
      (fun () ->
        S.Api.fetch_pull_request ~request_id:(Builder.log_id s) account client repo pull_request_id)

  let query_repo_tree s db account branch_ref dest_branch_ref =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : QUERY_REPO_TREE : account = %s : branch = %s : time=%f"
          log_id
          (S.Api.Account.to_string account)
          (S.Api.Ref.to_string branch_ref)
          time)
      (fun () ->
        S.Db.query_repo_tree
          ~request_id:(Builder.log_id s)
          ~base_ref:dest_branch_ref
          db
          account
          branch_ref)

  let store_pull_request s db pull_request =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : STORE_PULL_REQUEST : pull_request_id = %s : time=%f"
          log_id
          (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
          time)
      (fun () -> S.Db.store_pull_request ~request_id:(Builder.log_id s) db pull_request)

  let query_conflicting_work_manifests s db ~job_id context dirspaces op =
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
          ~job_id
          db
          context
          dirspaces
          op)

  let fetch_pull_request_reviews s client repo pull_request =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : FETCH_PULL_REQUEST_REVIEWS : repo = %s : pull_request_id = %s : time=%f"
          log_id
          (S.Api.Repo.to_string repo)
          (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
          time)
      (fun () ->
        S.Api.fetch_pull_request_reviews
          ~request_id:(Builder.log_id s)
          repo
          (S.Api.Pull_request.id pull_request)
          client)

  let gate_eval s db client pull_request dirspaces =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : GATE : EVAL : pull_request_id = %s : time=%f"
          log_id
          (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
          time)
      (fun () -> S.Gate.eval ~request_id:(Builder.log_id s) client dirspaces pull_request db)

  let query_dirspaces_owned_by_other_pull_requests s db pull_request dirspaces =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : QUERY_DIRSPACES_OWNED_BY_OTHER_PULL_REQUESTS : pull_request_id = %s : time=%f"
          log_id
          (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
          time)
      (fun () ->
        S.Db.query_dirspaces_owned_by_other_pull_requests
          ~request_id:(Builder.log_id s)
          db
          pull_request
          dirspaces)

  let store_stacks s db account repo pull_request config =
    time_it
      s
      (fun m log_id time ->
        m
          "%s : STACKS : STORE : pull_request_id = %s : time=%f"
          log_id
          (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
          time)
      (fun () ->
        S.Stacks.store
          ~request_id:(Builder.log_id s)
          ~installation_id:(S.Api.Account.id account)
          ~repo_id:(S.Api.Repo.id repo)
          ~pull_request_id:(S.Api.Pull_request.id pull_request)
          config
          db)

  module Tasks = struct
    let run = Tasks_base.run

    (* Wrapper so that when we call [publish_comment] the error type lines up *)
    let publish_comment' f msg = Tasks_base.publish_comment' f msg

    let create_commit_checks' f branch_ref checks =
      Tasks_base.create_commit_checks' f branch_ref checks

    let publish_comment =
      run ~name:"publish_comment" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.client
          >>= fun client ->
          fetch Keys.pull_request
          >>= fun pull_request ->
          fetch Keys.user >>| fun user -> fun msg -> publish_comment s client user pull_request msg)

    let create_commit_checks =
      run ~name:"create_commit_checks" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.client
          >>= fun client ->
          fetch Keys.pull_request
          >>= fun _pull_request ->
          fetch Keys.repo
          >>| fun repo ->
          fun branch_ref checks ->
           (* When updating commit checks, mark the existing key as dirty. *)
           Builder.State.mark_dirty s Keys.commit_checks;
           let open Abbs_future_combinators.Infix_result_monad in
           S.Repo_config.fetch_brand ~request_id:(Builder.log_id s) client repo
           >>= fun brand ->
           S.Api.create_commit_checks
             ~request_id:(Builder.log_id s)
             ~brand
             client
             repo
             branch_ref
             checks)

    let commit_checks =
      run ~name:"commit_checks" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.client
          >>= fun client ->
          fetch Keys.repo
          >>= fun repo ->
          fetch Keys.branch_ref
          >>= fun branch_ref ->
          Logs.info (fun m ->
              m
                "%s : FETCH_COMMIT_CHECKS : repo = %s : branch = %s"
                (Builder.log_id s)
                (S.Api.Repo.to_string repo)
                (S.Api.Ref.to_string branch_ref));
          S.Api.fetch_commit_checks ~request_id:(Builder.log_id s) client repo branch_ref)

    let branch_name =
      run ~name:"branch_name" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>| fun pull_request -> S.Api.Pull_request.branch_name pull_request)

    let branch_ref =
      run ~name:"branch_ref" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request >>| fun pull_request -> S.Api.Pull_request.branch_ref pull_request)

    let dest_branch_name =
      run ~name:"dest_branch_name" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>| fun pull_request -> S.Api.Pull_request.base_branch_name pull_request)

    let dest_branch_ref =
      run ~name:"dest_branch_ref" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request >>| fun pull_request -> S.Api.Pull_request.base_ref pull_request)

    let working_dest_branch_ref =
      run ~name:"working_dest_branch_ref" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.client
          >>= fun client ->
          fetch Keys.repo
          >>= fun repo ->
          fetch Keys.dest_branch_name
          >>= fun dest_branch_name ->
          (* Fetch actual dest branch ref, in case it has changed.  For GitHub,
             we can only run actions against the branch and not an actual ref.
             That means if the dest branch is main, and another PR has been
             merged into main, we need to operate on main with the updated ref,
             not the one the PR API reports. *)
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

    let working_branch_ref =
      run ~name:"working_branch_ref" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>= fun pull_request ->
          match S.Api.Pull_request.state pull_request with
          | Terrat_pull_request.State.Open | Terrat_pull_request.State.Closed ->
              Abbs_future_combinators.return_ok (S.Api.Pull_request.branch_ref pull_request)
          | Terrat_pull_request.State.Merged _ -> fetch Keys.working_dest_branch_ref)

    let working_branch_name =
      run ~name:"working_branch_name" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>| fun pull_request ->
          match S.Api.Pull_request.state pull_request with
          | Terrat_pull_request.State.Open | Terrat_pull_request.State.Closed ->
              S.Api.Pull_request.branch_name pull_request
          | Terrat_pull_request.State.Merged _ -> S.Api.Pull_request.base_branch_name pull_request)

    let out_of_change_applies =
      run ~name:"out_of_change_applies" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>= fun pull_request ->
          Builder.run_db s ~f:(fun db -> query_pull_request_out_of_change_applies s db pull_request))

    let changes =
      run ~name:"changes" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request_diff
          >>| fun diff ->
          Logs.info (fun m -> m "%s : CHANGES : %d" (Builder.log_id s) (CCList.length diff));
          diff)

    let intra_pr_selection =
      run ~name:"intra_pr_selection" (fun s { Bs.Fetcher.fetch } ->
          let module Ipr = Terrat_intra_pr_hash in
          let module Mp = P2.Missing_plan in
          let open Irm in
          fetch Keys.context
          >>= fun context ->
          fetch Keys.account
          >>= fun account ->
          fetch Keys.synthesized_config
          >>= fun config ->
          fetch Keys.pull_request
          >>= fun pull_request ->
          fetch Keys.dest_branch_ref
          >>= fun base_ref ->
          fetch Keys.branch_ref
          >>| fun branch_ref ->
          (* The comparison of two trees is the expensive part of this rule: the database reads
             both trees whole, thus its cost follows the size of the repository and not the number
             of paths which moved.  The answer is a function of the two shas and of nothing else,
             and this closure carries one head, thus the sha of the run is the whole key.  The
             apply path asks for the selection a second time over the same layers, and without
             this cache it would pay for every comparison again.

             [None] is the tree of that sha which is not stored.  It cannot hold the dirspaces of
             that case, because which dirspaces those are is a question about [layers] and the
             cache outlives one call. *)
          let changed_cache = ref [] in
          fun ~layers ~force ->
            let dirspaces = CCList.flatten layers in
            Builder.run_db s ~f:(fun db -> query_dirspace_runs_for_context s db context dirspaces)
            >>= fun states ->
            (* Two things the file test cannot see, because no file of this branch moves for
              either of them, and the runs the selection is given carry neither.  The apply gate
              asks this query and refuses on both, thus the selection has to ask it too or the two
              answers disagree.  [Never_planned] is the third reason and it is not here: it says
              this pull request has no run to keep, which the rules find on their own. *)
            Builder.run_db s ~f:(fun db ->
                query_dirspaces_without_valid_plans
                  ~base_ref
                  ~branch_ref
                  s
                  db
                  pull_request
                  dirspaces)
            >>= fun missing_plans ->
            let superseded, last_run_failed =
              CCListLabels.fold_left
                ~init:(Terrat_data.Dirspace_set.empty, Terrat_data.Dirspace_set.empty)
                ~f:(fun (superseded, last_run_failed) { Mp.dirspace; reason } ->
                  match reason with
                  | Mp.Invalidated_by_pull_request _ ->
                      (Terrat_data.Dirspace_set.add dirspace superseded, last_run_failed)
                  | Mp.Last_run_failed ->
                      (superseded, Terrat_data.Dirspace_set.add dirspace last_run_failed)
                  | Mp.Never_planned -> (superseded, last_run_failed))
                missing_plans
            in
            Logs.info (fun m ->
                m
                  "%s : INTRA_PR_SELECTION : superseded=%d : last_run_failed=%d"
                  (Builder.log_id s)
                  (Terrat_data.Dirspace_set.cardinal superseded)
                  (Terrat_data.Dirspace_set.cardinal last_run_failed));
            Builder.run_db s ~f:(fun db ->
                S.Db.query_repo_tree_built ~request_id:(Builder.log_id s) db account branch_ref)
            >>= function
            | false ->
                (* The whole rule is a comparison against the tree of the head.  With no tree there
                  is nothing to compare, and a tree which is not there must mean "run it" and never
                  "skip it".

                  The task graph puts [repo_tree_branch] before the matches, and that task either
                  stores the tree it fetched or waits for the tree builder, thus this arm is not
                  reachable today.  It is here because the cost of being wrong is an apply of a
                  plan which no longer fits the files, and nothing else in this path would say
                  so. *)
                Logs.err (fun m ->
                    m
                      "%s : INTRA_PR_SELECTION : NO_REPO_TREE : branch_ref=%s"
                      (Builder.log_id s)
                      (S.Api.Ref.to_string branch_ref));
                Abbs_future_combinators.return_ok
                  (Ipr.select
                     ~changed_dirspaces:(fun _ -> Terrat_data.Dirspace_set.of_list dirspaces)
                     ~force
                     ~superseded
                     ~last_run_failed
                     ~layers
                     states)
            | true ->
                (* The same change match the pull request diff uses, thus a dirspace which names a
                  file of another directory in its file patterns is found, and so is a dirspace
                  which depends on one that changed. *)
                let dirspaces_of_paths paths =
                  paths
                  |> CCList.map (fun filename -> Terrat_change.Diff.Change { filename })
                  |> Terrat_change_match3.match_diff_list config
                  |> CCList.flatten
                  |> CCList.map (fun { Terrat_change_match3.Dirspace_config.dirspace; _ } ->
                      dirspace)
                  |> Terrat_data.Dirspace_set.of_list
                in
                (* [None] when the tree of that sha is not stored.  The comparison would answer the
                  same thing -- a tree which is not there must mean "run it" -- but it would do it
                  by giving back every path of the head and walking the whole repository through
                  the change match.  A pull request whose runs are older than this feature meets
                  this, and so does one whose trees the cleanup has removed. *)
                let changed_of_sha sha =
                  match Sln_list.String.assoc_opt sha !changed_cache with
                  | Some changed -> Abbs_future_combinators.return_ok changed
                  | None ->
                      let ref_ = S.Api.Ref.of_string sha in
                      Builder.run_db s ~f:(fun db ->
                          S.Db.query_repo_tree_built ~request_id:(Builder.log_id s) db account ref_)
                      >>= (function
                      | false ->
                          Logs.info (fun m ->
                              m
                                "%s : INTRA_PR_SELECTION : NO_RUN_TREE : sha=%s"
                                (Builder.log_id s)
                                sha);
                          Abbs_future_combinators.return_ok None
                      | true ->
                          Builder.run_db s ~f:(fun db ->
                              query_repo_tree_changes ~base_ref:ref_ s db account branch_ref)
                          >>| fun paths -> Some (dirspaces_of_paths paths))
                      >>| fun changed ->
                      changed_cache := (sha, changed) :: !changed_cache;
                      changed
                in
                (* The shas of the runs, and not the dirspaces: two dirspaces which ran together
                  share a sha, thus one comparison of trees answers for both of them. *)
                let shas =
                  states
                  |> CCList.flat_map
                       (fun { Ipr.Dirspace_state.dirspace = _; last_plan; last_apply } ->
                         CCList.filter_map
                           CCFun.id
                           [
                             CCOption.map
                               (fun {
                                      Ipr.Plan.run = { Ipr.Run.sha; created_at = _ };
                                      has_changes = _;
                                    }
                                  -> sha)
                               last_plan;
                             CCOption.map (fun { Ipr.Run.sha; created_at = _ } -> sha) last_apply;
                           ])
                  |> Sln_list.String.sort_uniq
                in
                Abbs_future_combinators.List_result.fold_left
                  ~init:[]
                  ~f:(fun acc sha -> changed_of_sha sha >>| fun changed -> (sha, changed) :: acc)
                  shas
                >>| fun changed ->
                let changed_dirspaces sha =
                  match Sln_list.String.assoc_opt sha changed with
                  | Some (Some changed) -> changed
                  | Some None -> Terrat_data.Dirspace_set.of_list dirspaces
                  | None -> Terrat_data.Dirspace_set.empty
                in
                Ipr.select ~changed_dirspaces ~force ~superseded ~last_run_failed ~layers states)

    let is_draft_pr =
      run ~name:"is_draft_pr" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>| fun pull_request -> S.Api.Pull_request.is_draft_pr pull_request)

    let publish_index_complete =
      run ~name:"publish_index_complete" (fun s { Bs.Fetcher.fetch } ->
          let module I = Terrat_vcs_provider2.Index in
          let open Irm in
          Ee2_fc.all2 (fetch Keys.repo_index_branch) (fetch Keys.repo_index_dest_branch)
          >>= fun (_, _) ->
          fetch Keys.account
          >>= fun account ->
          fetch Keys.branch_ref
          >>= fun branch_ref ->
          Logs.info (fun m -> m "%s : FETCHING_INDEX" (Builder.log_id s));
          Builder.run_db s ~f:(fun db -> query_index s db account branch_ref)
          >>= function
          | Some { I.success; failures; _ } ->
              (* TODO: Construct include base branch index information as well, if it was generated *)
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Index_complete
                   ( success,
                     CCList.map
                       (fun { I.Failure.file; line_num; error } -> (file, line_num, error))
                       failures ))
          | None ->
              Logs.info (fun m -> m "%s : INDEX_NOT_FOUND" (Builder.log_id s));
              Abbs_future_combinators.return_ok ())

    let publish_unlock =
      run ~name:"publish_unlock" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          let eval_access_control () =
            fetch Keys.repo_config
            >>= fun repo_config ->
            fetch Keys.access_control
            >>= fun access_control ->
            let module Ac = Terrat_base_repo_config_v1.Access_control in
            let ac_conf = Terrat_base_repo_config_v1.access_control repo_config in
            if ac_conf.Ac.enabled then
              let match_list = ac_conf.Ac.unlock in
              Access_control.eval_match_list access_control match_list
              >>| function
              | true -> None
              | false -> Some match_list
            else Abbs_future_combinators.return_ok None
          in
          let parse_unlock_ids pull_request_id = function
            | [] -> Ok [ S.Unlock_id.of_pull_request pull_request_id ]
            | unlock_ids ->
                CCResult.map_l
                  (function
                    | "drift" -> Ok (S.Unlock_id.drift ())
                    | s -> (
                        match S.Api.Pull_request.Id.of_string s with
                        | Some id -> Ok (S.Unlock_id.of_pull_request id)
                        | None -> Error (`Invalid_unlock_id s)))
                  unlock_ids
          in
          let run _client _pull_request unlock_ids =
            let open Irm in
            fetch Keys.repo
            >>= fun repo ->
            fetch Keys.access_control
            >>= fun access_control ->
            fetch Keys.publish_comment
            >>= fun publish_comment ->
            eval_access_control ()
            >>= function
            | None ->
                let open Irm in
                Builder.run_db s ~f:(fun db -> unlock s db repo unlock_ids)
                >>= fun () -> publish_comment' publish_comment Msg.Unlock_success
            | Some match_list ->
                publish_comment'
                  publish_comment
                  (Msg.Access_control_denied
                     ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                       `Unlock match_list ))
          in
          let open Irm in
          fetch Keys.client
          >>= fun client ->
          fetch Keys.job
          >>= fun job ->
          match job.Tjc.Job.type_ with
          | Tjc.Job.Type_.Unlock unlock_ids -> (
              fetch Keys.pull_request
              >>= fun pull_request ->
              let open Abb.Future.Infix_monad in
              Abb.Future.return @@ parse_unlock_ids (S.Api.Pull_request.id pull_request) unlock_ids
              >>= function
              | Ok unlock_ids -> run client pull_request unlock_ids
              | Error (`Invalid_unlock_id id) ->
                  let open Irm in
                  fetch Keys.publish_comment
                  >>= fun publish_comment ->
                  publish_comment' publish_comment (Msg.Invalid_unlock_id id))
          | _ -> assert false)

    let publish_repo_config =
      run ~name:"publish_repo_config" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.all2 (fetch Keys.repo_config_with_provenance) (fetch Keys.store_stacks)
          >>= fun (repo_config_with_provenance, ()) ->
          fetch Keys.publish_comment
          >>= fun publish_comment ->
          publish_comment' publish_comment (Msg.Repo_config repo_config_with_provenance))

    let publish_help =
      run ~name:"publish_help" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.publish_comment
          >>= fun publish_comment -> publish_comment' publish_comment Msg.Help)

    let comment_id =
      run ~name:"comment_id" (fun _s { Bs.Fetcher.fetch = _ } ->
          (* This is a default value in case no comment id is set in the store
             by the runner. *)
          Abbs_future_combinators.return_ok None)

    let react_to_comment =
      run ~name:"react_to_comment" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.comment_id
          >>= function
          | Some comment_id ->
              Ee2_fc.all2 (fetch Keys.pull_request) (fetch Keys.client)
              >>= fun (pull_request, client) -> react_to_comment s client pull_request comment_id
          | None -> Abbs_future_combinators.return_ok ())

    let pull_request =
      run ~name:"pull_request" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.all4
            (fetch Keys.account)
            (fetch Keys.repo)
            (fetch Keys.client)
            (fetch Keys.pull_request_id)
          >>= fun (account, repo, client, pull_request_id) ->
          fetch_pull_request s account client repo pull_request_id)

    let pull_request_diff =
      run ~name:"pull_request_diff" (fun s { Bs.Fetcher.fetch } ->
          let module V1 = Terrat_base_repo_config_v1 in
          let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
          let open Irm in
          fetch Keys.repo_config
          >>= fun repo_config ->
          fetch Keys.pull_request
          >>= fun pull_request ->
          let diff = S.Api.Pull_request.diff pull_request in
          let tree_builder = V1.tree_builder repo_config in
          if tree_builder.V1.Tree_builder.enabled then (
            let changed_files =
              Sln_set.String.of_list
              @@ CCList.flat_map
                   (function
                     | Terrat_change.Diff.Add { filename }
                     | Terrat_change.Diff.Change { filename }
                     | Terrat_change.Diff.Remove { filename } -> [ filename ]
                     | Terrat_change.Diff.Move { filename; previous_filename } ->
                         [ filename; previous_filename ])
                   diff
            in
            fetch Keys.repo_tree_branch
            >>= fun _ ->
            fetch Keys.account
            >>= fun account ->
            fetch Keys.branch_ref
            >>= fun branch_ref ->
            fetch Keys.dest_branch_ref
            >>= fun dest_branch_ref ->
            Ee2_fc.all2 (fetch Keys.repo_tree_branch) (fetch Keys.repo_tree_dest_branch)
            >>= fun (_, _) ->
            Builder.run_db s ~f:(fun db -> query_repo_tree s db account branch_ref dest_branch_ref)
            >>? function
            | Some repo_tree ->
                Ok
                  (CCList.filter_map
                     (function
                       | { I.path = filename; changed = Some true; _ } ->
                           Some (Terrat_change.Diff.Change { filename })
                       | { I.path = filename; changed = None; _ }
                         when Sln_set.String.mem filename changed_files ->
                           Some (Terrat_change.Diff.Change { filename })
                       | _ -> None)
                     repo_tree)
            | None ->
                Logs.err (fun m -> m "%s : EXPECTED_REPO_TREE" (Builder.log_id s));
                Error (`Msg_err "EXPECTED_REPO_TREE"))
          else Abbs_future_combinators.return_ok diff)

    let store_pull_request =
      run ~name:"store_pull_request" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>= fun pull_request ->
          Logs.info (fun m ->
              m
                "%s : STORE_PULL_REQUEST : pull_number=%s"
                (Builder.log_id s)
                (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request));
          Builder.run_db s ~f:(fun db -> store_pull_request s db pull_request))

    (* A precheck names itself in the log line that stops the work, because the answer is otherwise
       silent: a stopped autoplan writes no comment. *)
    let precheck_name =
      let module Pc = Terrat_base_repo_config_v1.When_modified.Precheck in
      function
      | Pc.User _ -> "user"
      | Pc.File_patterns _ -> "file_patterns"
      | Pc.Config_file_patterns _ -> "config_file_patterns"

    let eval_config_file_patterns s { Bs.Fetcher.fetch } ~files ~pull_request ~stale_config_min =
      let open Irm in
      (* A pull request that rewrites the configuration always continues: the configuration of the
         destination branch cannot describe one that the pull request changes. *)
      if Terrat_precheck.changes_repo_config files then Abbs_future_combinators.return_ok true
      else
        Ee2_fc.all3 (fetch Keys.account) (fetch Keys.repo) (fetch Keys.dest_branch_name)
        >>= fun (account, repo, dest_branch_name) ->
        fetch Keys.client
        >>= fun client ->
        let open Abb.Future.Infix_monad in
        (* The lineage of the destination branch decides which stored configuration to read. Without
           it the query can only take the newest row of the branch, and a branch that a pull request
           evaluation wrote against at a commit which a later rewrite removed is then not an earlier
           state of this branch at all. *)
        (let open Irm in
         S.Api.fetch_branch_commits ~request_id:(Builder.log_id s) client repo dest_branch_name
         >>= fun shas ->
         Builder.run_db s ~f:(fun db ->
             S.Db.query_recent_derived_repo_config
               ~request_id:(Builder.log_id s)
               db
               account
               repo
               ~branch:dest_branch_name
               ~shas
               ~stale_min:stale_config_min))
        >>= function
        | Error _ ->
            (* The error stops here. Every other task lets a failure end the job, which writes an
               internal error on the pull request, but a precheck that cannot get its data must
               pass: an opt-in hint must never make a pull request fail that would otherwise have
               run. *)
            Logs.info (fun m -> m "%s : PRECHECK_CONFIG_UNAVAILABLE" (Builder.log_id s));
            Abbs_future_combinators.return_ok true
        | Ok None -> Abbs_future_combinators.return_ok true
        | Ok (Some repo_config_json) -> (
            let diff = S.Api.Pull_request.diff pull_request in
            (* The parse and the dir match are real work on a repository with many dirs, thus they
               go off the event loop, as every other use of them in this evaluator does. *)
            Abb.Thread.run (fun () -> Terrat_precheck.match_derived_config ~diff repo_config_json)
            >>= function
            | Some matched -> Abbs_future_combinators.return_ok matched
            | None ->
                (* A stored configuration that does not parse gives [true], as an absent one does:
                   the answer comes from a cache, thus a cache that cannot be read must not stop a
                   pull request. *)
                Logs.err (fun m -> m "%s : PRECHECK_CONFIG_UNREADABLE" (Builder.log_id s));
                Abbs_future_combinators.return_ok true)

    let eval_precheck s fetcher ~files ~files_truncated ~pull_request =
      let module Pc = Terrat_base_repo_config_v1.When_modified.Precheck in
      function
      | Pc.User users ->
          Abbs_future_combinators.return_ok
            (Terrat_precheck.match_user ~users (S.Api.Pull_request.user pull_request))
      | Pc.File_patterns file_patterns ->
          if files_truncated then Abbs_future_combinators.return_ok true
          else
            Abbs_future_combinators.return_ok
              (Terrat_precheck.match_file_patterns ~files file_patterns)
      | Pc.Config_file_patterns { Pc.Config_file_patterns.stale_config_min } ->
          if files_truncated then Abbs_future_combinators.return_ok true
          else eval_config_file_patterns s fetcher ~files ~pull_request ~stale_config_min

    (* The checks are an "and", thus the first one that gives [false] is the answer and the rest
       need no work. *)
    let rec first_failed_precheck s fetcher ~files ~files_truncated ~pull_request = function
      | [] -> Abbs_future_combinators.return_ok None
      | precheck :: rest -> (
          let open Irm in
          eval_precheck s fetcher ~files ~files_truncated ~pull_request precheck
          >>= function
          | true -> first_failed_precheck s fetcher ~files ~files_truncated ~pull_request rest
          | false -> Abbs_future_combinators.return_ok (Some precheck))

    let check_prechecks =
      run ~name:"check_prechecks" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let module V1 = Terrat_base_repo_config_v1 in
          let open Irm in
          fetch Keys.job
          >>= fun ({ Tjc.Job.context; _ } as job) ->
          match job.Tjc.Job.type_ with
          | Tjc.Job.Type_.Autoplan -> (
              (* The static configuration, never the one that the config builder makes: a precheck
                 exists to stop that builder, thus a precheck it produced is too late to read. *)
              fetch Keys.repo_config_raw'
              >>= fun (_, repo_config) ->
              match (V1.when_modified repo_config).V1.When_modified.prechecks with
              | [] -> Abbs_future_combinators.return_ok ()
              | prechecks -> (
                  (* [iter_job] runs again for every work manifest event that the job owns, thus a
                     precheck that answers a second time could stop a job that already dispatched
                     work.  [config_file_patterns] can give a different answer on a later pass,
                     because the evaluation of this pull request itself records the configuration of
                     the destination branch that the check reads.  A job that owns a work manifest
                     has passed the prechecks already. *)
                  fetch Keys.work_manifests_for_job
                  >>= function
                  | _ :: _ -> Abbs_future_combinators.return_ok ()
                  | [] -> (
                      Builder.run_db s ~f:(fun db ->
                          S.Job_context.Job.query_explicit_plan_exists
                            ~request_id:(Builder.log_id s)
                            db
                            ~context_id:context.Tjc.Context.id
                            ())
                      >>= function
                      | true ->
                          Logs.info (fun m -> m "%s : PRECHECK_OVERRIDDEN" (Builder.log_id s));
                          Abbs_future_combinators.return_ok ()
                      | false -> (
                          fetch Keys.pull_request
                          >>= fun pull_request ->
                          (* The files the VCS reports, never [Keys.pull_request_diff].  That key
                             gives the verdict of the tree builder when the tree builder is
                             enabled, and to build it the tree builder must run.  A precheck
                             answers before the system does anything, thus it reads only what it
                             already has. *)
                          let diff = S.Api.Pull_request.diff pull_request in
                          (* A diff that the VCS cut short can hide the very file that a check
                             looks for, thus the checks that read files must treat it as no answer
                             rather than as an answer of "no match". *)
                          let files_truncated = Terrat_change.Diff.may_be_truncated diff in
                          let files =
                            CCList.flat_map
                              (function
                                | Terrat_change.Diff.Add { filename }
                                | Terrat_change.Diff.Change { filename }
                                | Terrat_change.Diff.Remove { filename } -> [ filename ]
                                | Terrat_change.Diff.Move { filename; previous_filename } ->
                                    [ filename; previous_filename ])
                              diff
                          in
                          first_failed_precheck
                            s
                            fetcher
                            ~files
                            ~files_truncated
                            ~pull_request
                            prechecks
                          >>= function
                          | None -> Abbs_future_combinators.return_ok ()
                          | Some precheck ->
                              Logs.info (fun m ->
                                  m
                                    "%s : PRECHECK_STOP : check=%s"
                                    (Builder.log_id s)
                                    (precheck_name precheck));
                              (* The pull request still has to be mergeable, thus the operator that
                             needs the apply check green to merge gets it, even though the
                             prechecks stopped every run. *)
                              let { V1.Apply_requirements.create_completed_apply_check_on_noop; _ }
                                  =
                                V1.apply_requirements repo_config
                              in
                              (if create_completed_apply_check_on_noop then
                                 Tasks_base.create_completed_apply_check s fetcher
                               else Abbs_future_combinators.return_ok ())
                              >>= fun () -> Abbs_future_combinators.return_err `Noop))))
          | Tjc.Job.Type_.Apply _
          | Tjc.Job.Type_.Autoapply
          | Tjc.Job.Type_.Gate_approval _
          | Tjc.Job.Type_.Help
          | Tjc.Job.Type_.Index
          | Tjc.Job.Type_.Plan _
          | Tjc.Job.Type_.Push
          | Tjc.Job.Type_.Repo_config
          | Tjc.Job.Type_.Unlock _ -> Abbs_future_combinators.return_ok ())

    let check_pull_request_state =
      run ~name:"check_pull_request_state" (fun s { Bs.Fetcher.fetch } ->
          let module Pr = Terrat_pull_request in
          let open Irm in
          fetch Keys.pull_request
          >>= fun pull_request ->
          match S.Api.Pull_request.state pull_request with
          | Pr.State.Closed ->
              Logs.info (fun m -> m "%s : NOOP : PR_CLOSED" (Builder.log_id s));
              fetch Keys.commit_checks
              >>= fun commit_checks ->
              fetch Keys.branch_ref
              >>= fun branch_ref ->
              let module Ch = Terrat_commit_check in
              let unfinished_checks =
                CCList.filter_map
                  (function
                    | { Ch.status = Ch.Status.(Completed | Failed | Canceled); _ } -> None
                    | { Ch.status = Ch.Status.(Queued | Running); _ } as c ->
                        Some { c with Ch.status = Ch.Status.Canceled })
                  commit_checks
              in
              fetch Keys.create_commit_checks
              >>= fun create_commit_checks ->
              create_commit_checks' create_commit_checks branch_ref unfinished_checks
              >>? fun () -> Error `Noop
          | Pr.State.(Open | Merged _) -> Abbs_future_combinators.return_ok ())

    let check_conflicting_plan_work_manifests =
      run ~name:"check_conflicting_plan_work_manifests" (fun s { Bs.Fetcher.fetch } ->
          let module R = Terrat_access_control2.R in
          let open Irm in
          fetch Keys.access_control_eval_plan
          >>= fun access_control_eval ->
          Abb.Future.return
            (access_control_eval
              : (R.t, Terrat_access_control2.err) result
              :> (R.t, [> Terrat_access_control2.err ]) result)
          >>= fun { R.pass = passed_dirspaces; _ } ->
          let dirspaces =
            CCList.map
              (fun { Terrat_change_match3.Dirspace_config.dirspace; _ } -> dirspace)
              passed_dirspaces
          in
          (* TODO: Do not depend on pull request *)
          fetch Keys.context
          >>= fun context ->
          fetch Keys.job
          >>= fun job ->
          Builder.run_db s ~f:(fun db ->
              query_conflicting_work_manifests s db ~job_id:job.Tjc.Job.id context dirspaces `Plan)
          >>= function
          | None -> Abbs_future_combinators.return_ok ()
          | Some (P2.Conflicting_work_manifests.Conflicting wms) ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment' publish_comment (Msg.Conflicting_work_manifests wms)
              >>? fun () -> Error `Noop
          | Some (P2.Conflicting_work_manifests.Maybe_stale wms) ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment' publish_comment (Msg.Maybe_stale_work_manifests wms)
              >>? fun () -> Error `Noop)

    let check_merge_conflict =
      run ~name:"check_merge_conflict" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>= fun pull_request ->
          match S.Api.Pull_request.state pull_request with
          | Terrat_pull_request.State.Open -> (
              (* The VCS calculates the merge in the background, so the verdict is its own
                 request.  The pull request does not carry it, thus the paths that do not ask
                 for it do not wait for it.  No verdict counts as a conflict, which is what the
                 derived state gave before. *)
              fetch Keys.client
              >>= fun client ->
              S.Api.fetch_pull_request_mergeable
                ~request_id:(Builder.log_id s)
                (S.Api.Pull_request.repo pull_request)
                (S.Api.Pull_request.id pull_request)
                client
              >>= function
              | Some true -> Abbs_future_combinators.return_ok ()
              | Some false | None -> (
                  fetch Keys.all_matches
                  >>= function
                  | [] -> Abbs_future_combinators.return_err `Noop
                  | _ :: _ ->
                      Logs.info (fun m -> m "%s : MERGE_CONFLICT" (Builder.log_id s));
                      fetch Keys.publish_comment
                      >>= fun publish_comment ->
                      publish_comment' publish_comment Msg.Pull_request_not_mergeable
                      >>? fun () -> Error `Noop))
          | Terrat_pull_request.State.Closed | Terrat_pull_request.State.Merged _ ->
              Abbs_future_combinators.return_ok ())

    let pull_request_reviews =
      run ~name:"pull_request_reviews" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.client
          >>= fun client ->
          fetch Keys.repo
          >>= fun repo ->
          fetch Keys.pull_request
          >>= fun pull_request -> fetch_pull_request_reviews s client repo pull_request)

    let access_control_eval_plan =
      run ~name:"access_control_eval_plan" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.access_control
          >>= fun access_control ->
          fetch Keys.working_set_matches
          >>= fun working_set_matches ->
          let open Abb.Future.Infix_monad in
          Access_control.eval_tf_operation access_control working_set_matches `Plan
          >>= fun ret -> Abbs_future_combinators.return_ok ret)

    let access_control_eval_apply =
      run ~name:"access_control_eval_apply" (fun _s { Bs.Fetcher.fetch } ->
          let module Rr = Terrat_pull_request_review in
          let open Irm in
          fetch Keys.access_control
          >>= fun access_control ->
          fetch Keys.working_set_matches
          >>= fun working_set_matches ->
          fetch Keys.client
          >>= fun _client ->
          fetch Keys.repo
          >>= fun _repo ->
          fetch Keys.pull_request_reviews
          >>= fun reviews ->
          let reviews =
            CCList.filter_map
              (function
                | { Rr.user; status = Rr.Status.Approved; _ } -> user
                | _ -> None)
              reviews
          in
          fetch Keys.job
          >>= fun job ->
          let op =
            match job with
            | {
             Tjc.Job.type_ =
               Tjc.Job.Type_.(Autoapply | Apply { tag_query = _; kind = _; force = false });
             _;
            } -> `Apply reviews
            | { Tjc.Job.type_ = Tjc.Job.Type_.Apply { tag_query = _; kind = _; force = true }; _ }
              -> `Apply_force
            | _ -> assert false
          in
          let open Abb.Future.Infix_monad in
          Access_control.eval_tf_operation access_control working_set_matches op
          >>= fun ret -> Abbs_future_combinators.return_ok ret)

    let check_access_control_plan =
      run ~name:"check_access_control_plan" (fun _s { Bs.Fetcher.fetch } ->
          let module R = Terrat_access_control2.R in
          let open Irm in
          fetch Keys.access_control
          >>= fun access_control ->
          fetch Keys.access_control_eval_plan
          >>= function
          | Ok { R.pass = []; deny = _ :: _ as deny }
            when not (Access_control.plan_require_all_dirspace_access access_control) ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `All_dirspaces deny ))
          | Ok { R.pass = _; deny }
            when CCList.is_empty deny
                 || not (Access_control.plan_require_all_dirspace_access access_control) ->
              Abbs_future_combinators.return_ok ()
          | Ok { R.deny; _ } ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `Dirspaces deny ))
              >>? fun () -> Error `Noop
          | Error `Error ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `Lookup_err ))
              >>? fun () -> Error `Noop)

    let check_apply_requirements =
      run ~name:"check_apply_requirements" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.all5
            (fetch Keys.client)
            (fetch Keys.repo_config)
            (fetch Keys.pull_request)
            (fetch Keys.working_set_matches)
            (fetch Keys.user)
          >>= fun (client, repo_config, pull_request, working_set_matches, user) ->
          match user with
          | Some user -> (
              S.Apply_requirements.eval
                ~request_id:(Builder.log_id s)
                (Builder.State.config s)
                user
                client
                repo_config
                pull_request
                working_set_matches
              >>= fun apply_requirements ->
              let passed_apply_requirements =
                S.Apply_requirements.Result.passed apply_requirements
              in
              fetch Keys.job
              >>= function
              | {
                  Tjc.Job.type_ = Tjc.Job.Type_.Apply { force = false; tag_query = _; kind = _ };
                  _;
                }
                when not passed_apply_requirements ->
                  Logs.info (fun m -> m "%s : PR_NOT_APPLIABLE" (Builder.log_id s));
                  fetch Keys.publish_comment
                  >>= fun publish_comment ->
                  publish_comment'
                    publish_comment
                    (Msg.Pull_request_not_appliable
                       (S.Api.Pull_request.set_diff () pull_request, apply_requirements))
                  >>? fun () -> Error `Noop
              | _ -> Abbs_future_combinators.return_ok apply_requirements)
          | None -> assert false)

    let check_access_control_apply =
      run ~name:"check_access_control_apply" (fun _s { Bs.Fetcher.fetch } ->
          let module R = Terrat_access_control2.R in
          let open Irm in
          fetch Keys.job
          >>= fun _job ->
          fetch Keys.check_apply_requirements
          >>= fun _apply_requirements ->
          Ee2_fc.all6
            (fetch Keys.access_control)
            (fetch Keys.matches)
            (fetch Keys.client)
            (fetch Keys.pull_request)
            (fetch Keys.access_control_eval_apply)
            (fetch Keys.user)
          >>= fun (access_control, _matches, _client, _pull_request, access_control_result, _user)
                ->
          Abb.Future.return
            (access_control_result
              : (R.t, Terrat_access_control2.err) result
              :> (R.t, [> Terrat_access_control2.err ]) result)
          >>= fun access_control_result ->
          match access_control_result with
          | { Terrat_access_control2.R.pass = []; deny = _ :: _ as deny }
            when not (Access_control.apply_require_all_dirspace_access access_control) ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `All_dirspaces deny ))
              >>? fun () -> Error `Noop
          | { Terrat_access_control2.R.pass = _; deny }
            when CCList.is_empty deny
                 || not (Access_control.apply_require_all_dirspace_access access_control) ->
              (* This is the success path *)
              Abbs_future_combinators.return_ok ()
          | { Terrat_access_control2.R.deny; _ } ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `Dirspaces deny ))
              >>? fun () -> Error `Noop)

    let check_conflicting_apply_work_manifests =
      run ~name:"check_conflicting_apply_work_manifests" (fun s { Bs.Fetcher.fetch } ->
          let module R = Terrat_access_control2.R in
          let open Irm in
          fetch Keys.pull_request
          >>= fun _pull_request ->
          fetch Keys.access_control_eval_apply
          >>= fun access_control_eval ->
          Abb.Future.return
            (access_control_eval
              : (R.t, Terrat_access_control2.err) result
              :> (R.t, [> Terrat_access_control2.err ]) result)
          >>= fun { R.pass = passed_dirspaces; _ } ->
          let dirspaces =
            CCList.map
              (fun { Terrat_change_match3.Dirspace_config.dirspace; _ } -> dirspace)
              passed_dirspaces
          in
          fetch Keys.context
          >>= fun context ->
          fetch Keys.job
          >>= fun job ->
          Builder.run_db s ~f:(fun db ->
              S.Db.query_conflicting_work_manifests_in_repo_for_context
                ~request_id:(Builder.log_id s)
                ~job_id:job.Tjc.Job.id
                db
                context
                dirspaces
                `Apply)
          >>= function
          | None -> Abbs_future_combinators.return_ok ()
          | Some (P2.Conflicting_work_manifests.Conflicting wms) ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment' publish_comment (Msg.Conflicting_work_manifests wms)
              >>? fun () -> Error `Noop
          | Some (P2.Conflicting_work_manifests.Maybe_stale wms) ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment' publish_comment (Msg.Maybe_stale_work_manifests wms)
              >>? fun () -> Error `Noop)

    let check_dirspaces_missing_plans =
      run ~name:"check_dirspaces_missing_plans" (fun s { Bs.Fetcher.fetch } ->
          let module Dc = Terrat_change_match3.Dirspace_config in
          let module Ipr = Terrat_intra_pr_hash in
          let module Mp = P2.Missing_plan in
          let module R = Terrat_access_control2.R in
          let open Irm in
          fetch Keys.pull_request
          >>= fun pull_request ->
          fetch Keys.dest_branch_ref
          >>= fun base_ref ->
          fetch Keys.branch_ref
          >>= fun branch_ref ->
          fetch Keys.access_control_eval_apply
          >>= fun access_control_result ->
          Abb.Future.return
            (access_control_result
              : (R.t, Terrat_access_control2.err) result
              :> (R.t, [> Terrat_access_control2.err ]) result)
          >>= fun { Terrat_access_control2.R.pass = working_set_matches; _ } ->
          Builder.run_db s ~f:(fun db ->
              query_dirspaces_without_valid_plans
                ~base_ref
                ~branch_ref
                s
                db
                pull_request
                (CCList.map (fun { Dc.dirspace; _ } -> dirspace) working_set_matches))
          >>= function
          | [] -> Abbs_future_combinators.return_ok ()
          | dirspaces -> (
              (* The query compares the refs of the run with the refs of the pull request now.
                 The intra-PR hash rule keeps a plan which an older sha made while the files of
                 that dirspace hold the same hashes, and that rule is what decides whether the
                 plan is re-run, so the gate has to ask it too or it refuses an apply that no
                 plan will ever come for.

                 Only [Never_planned] is cleared this way.  [Invalidated_by_pull_request] says
                 another pull request applied or merged this dirspace after this run, thus the
                 state the plan was built on is gone and no apply may run it.  The selection is
                 given the same rows, so such a dirspace is in [to_run] and the plan the user is
                 told to ask for does arrive.  [Last_run_failed] says the newest run of this pull
                 request produced no plan to apply. *)
              fetch Keys.all_matches
              >>= fun all_matches ->
              fetch Keys.intra_pr_selection
              >>= fun intra_pr_selection ->
              (* An empty force set makes [to_run] exactly the dirspaces which have no plan that
                 still stands.  This repeats the comparison of trees which the matches made,
                 because the selection is a function of the layers and the layers are not a key
                 of their own. *)
              intra_pr_selection
                ~layers:(CCList.map (CCList.map (fun { Dc.dirspace; _ } -> dirspace)) all_matches)
                ~force:Terrat_data.Dirspace_set.empty
              >>= fun { Ipr.Selection.to_run; applied = _ } ->
              let without_plan = Terrat_data.Dirspace_set.of_list to_run in
              let missing =
                CCList.filter
                  (fun { Mp.dirspace; reason } ->
                    match reason with
                    | Mp.Invalidated_by_pull_request _ | Mp.Last_run_failed -> true
                    | Mp.Never_planned -> Terrat_data.Dirspace_set.mem dirspace without_plan)
                  dirspaces
              in
              Logs.info (fun m ->
                  m
                    "%s : MISSING_PLANS : queried=%d : after_hash_rule=%d"
                    (Builder.log_id s)
                    (CCList.length dirspaces)
                    (CCList.length missing));
              match missing with
              | [] -> Abbs_future_combinators.return_ok ()
              | dirspaces -> (
                  fetch Keys.job
                  >>= function
                  | { Tjc.Job.type_ = Tjc.Job.Type_.Autoapply; _ } ->
                      (* If it's an autoapply, don't publish *)
                      Abbs_future_combinators.return_err `Noop
                  | _ ->
                      fetch Keys.publish_comment
                      >>= fun publish_comment ->
                      publish_comment' publish_comment (Msg.Missing_plans dirspaces)
                      >>? fun () -> Error `Noop)))

    let check_dirspaces_to_plan =
      run ~name:"check_dirspaces_to_plan" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.job
          >>= function
          | { Tjc.Job.type_ = Tjc.Job.Type_.Plan { tag_query; kind = _ }; _ } -> (
              (* [working_set_matches] is what a plan would actually run.  If it is
                 empty then nothing is going to happen, and the user who typed the
                 command has to be told which of the reasons it is.  Running the
                 plan anyway means a work manifest over no dirspaces and not a word
                 back, which is how a mistyped tag query used to disappear. *)
              fetch Keys.working_set_matches
              >>= function
              | [] ->
                  fetch Keys.all_matches
                  >>= fun all_matches ->
                  fetch Keys.all_tag_query_matches
                  >>= fun all_tag_query_matches ->
                  fetch Keys.all_unapplied_matches
                  >>= fun all_unapplied_matches ->
                  fetch Keys.already_planned_matches
                  >>= fun already_planned_matches ->
                  let unapplied_matching_query =
                    CCList.filter
                      (Terrat_change_match3.match_tag_query ~tag_query)
                      (CCList.flatten all_unapplied_matches)
                  in
                  let dirspaces_of =
                    CCList.map (fun { Terrat_change_match3.Dirspace_config.dirspace; _ } ->
                        dirspace)
                  in
                  fetch Keys.publish_comment
                  >>= fun publish_comment ->
                  let msg, all_changes_applied =
                    match
                      ( CCList.flatten all_matches,
                        CCList.flatten all_tag_query_matches,
                        already_planned_matches,
                        unapplied_matching_query )
                    with
                    | [], _, _, _ ->
                        (* Nothing in the pull request to plan in the first place. *)
                        (Msg.Plan_no_matching_dirspaces tag_query, false)
                    | _ :: _, [], _, _ ->
                        (* The query selected none of what is there.  This is where
                           the implicit and hint earns its keep. *)
                        (Msg.Plan_no_matching_dirspaces tag_query, false)
                    | _ :: _, _ :: _, (_ :: _ as planned), _ ->
                        (* The query selected dirspaces which run now, and the file
                           hashes are what took them out of the run.  This test
                           comes first: the layers and the applied state explain
                           the other cases, and neither of them explains this
                           one. *)
                        (Msg.Plan_already_planned (dirspaces_of planned), false)
                    | _ :: _, _ :: _, [], [] ->
                        (* The query selected something, and all of it has already
                           been applied. *)
                        (Msg.Plan_all_changes_applied, true)
                    | _ :: _, _ :: _, [], (_ :: _ as queued) ->
                        (* The query matches something unapplied, it is just not in
                           the layer that runs next.  Naming what it is waiting on
                           is the only answer that is not a riddle. *)
                        (Msg.Matches_in_later_layer (dirspaces_of queued), false)
                  in
                  Ee2_fc.all2
                    (fetch Keys.maybe_create_completed_apply_check)
                    (publish_comment' publish_comment msg)
                  >>= fun ((), ()) ->
                  (* Everything the query matched is applied, so automerge is the
                     only work left.  The completion path that usually runs it is
                     only reached by a job that had dirspaces to run, so without
                     this a pull request whose automerge failed once can never be
                     merged by any later command.  The no-match cases are left
                     alone: a mistyped tag query must not merge a pull request. *)
                  (if all_changes_applied then fetch Keys.maybe_automerge
                   else Abbs_future_combinators.return_ok ())
                  >>? fun () -> Error `Noop
              | _ :: _ -> (
                  fetch Keys.repo_config
                  >>= fun repo_config ->
                  let module R = Terrat_base_repo_config_v1 in
                  match R.apply_requirements repo_config with
                  | { R.Apply_requirements.create_pending_apply_check = false; _ } ->
                      Abbs_future_combinators.return_ok ()
                  | { R.Apply_requirements.create_pending_apply_check = true; _ } ->
                      fetch Keys.repo
                      >>= fun repo ->
                      fetch Keys.account
                      >>= fun account ->
                      (* The pending check goes on the pull request's head, which is
                         [branch_ref], because that is the ref the completed check and
                         [finalize_unfinished_terrateam_checks] later write to.
                         [working_branch_ref] is the destination branch once the pull
                         request is merged, so a later layer planned after the merge
                         used to leave a "Waiting" check on the destination branch
                         that nothing ever completed. *)
                      fetch Keys.branch_ref
                      >>= fun branch_ref ->
                      let checks =
                        [
                          S.Commit_check.make_str
                            ~config:(Builder.State.config s)
                            ~description:"Waiting"
                            ~status:Terrat_commit_check.Status.Queued
                            ~repo
                            ~account
                            "terrateam apply";
                        ]
                      in
                      fetch Keys.create_commit_checks
                      >>= fun create_commit_checks ->
                      create_commit_checks' create_commit_checks branch_ref checks))
          | _ -> Abbs_future_combinators.return_ok ())

    let check_dirspaces_to_apply =
      run ~name:"check_dirspaces_to_apply" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.job
          >>= function
          | { Tjc.Job.type_ = Tjc.Job.Type_.Autoapply; _ } -> (
              fetch Keys.working_set_matches
              >>? function
              | [] -> Error `Noop
              | _ :: _ -> Ok ())
          | { Tjc.Job.type_ = Tjc.Job.Type_.Apply { tag_query; kind = _; force = _ }; _ } -> (
              (* Same reasoning as [check_dirspaces_to_plan]: an empty working set
                 has several causes and the user is owed the one that applies to
                 them, not the same sentence for all of them. *)
              fetch Keys.working_set_matches
              >>= function
              | [] ->
                  fetch Keys.all_tag_query_matches
                  >>= fun all_tag_query_matches ->
                  fetch Keys.all_unapplied_matches
                  >>= fun all_unapplied_matches ->
                  let unapplied_matching_query =
                    CCList.filter
                      (Terrat_change_match3.match_tag_query ~tag_query)
                      (CCList.flatten all_unapplied_matches)
                  in
                  fetch Keys.publish_comment
                  >>= fun publish_comment ->
                  let msg, all_changes_applied =
                    match (CCList.flatten all_tag_query_matches, unapplied_matching_query) with
                    | [], _ ->
                        (* The query matched nothing, so there is nothing this
                           command could have applied. *)
                        (Msg.Apply_no_matching_dirspaces tag_query, false)
                    | _ :: _, [] ->
                        (* The query matched, and all of it is applied, which is
                           what this message says. *)
                        (Msg.Apply_no_matching_dirspaces tag_query, true)
                    | _ :: _, (_ :: _ as queued) ->
                        ( Msg.Matches_in_later_layer
                            (CCList.map
                               (fun { Terrat_change_match3.Dirspace_config.dirspace; _ } ->
                                 dirspace)
                               queued),
                          false )
                  in
                  publish_comment' publish_comment msg
                  >>= fun () ->
                  (* Same reason as [check_dirspaces_to_plan]: an explicit apply
                     over dirspaces that are all applied is how a user retries a
                     failed automerge, so it has to reach the automerge logic. *)
                  (if all_changes_applied then fetch Keys.maybe_automerge
                   else Abbs_future_combinators.return_ok ())
                  >>? fun () -> Error `Noop
              | _ :: _ -> Abbs_future_combinators.return_ok ())
          | _ -> Abbs_future_combinators.return_ok ())

    (* A tag query that selects some of what the user named and quietly drops the
       rest is the failure this whole change exists for.  When the query is a list
       of directories with an implicit [and] in it, run what matched and say which
       directories the [and] ate. *)
    let warn_tag_query_dropped_dirspaces =
      run ~name:"warn_tag_query_dropped_dirspaces" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.job
          >>= fun job ->
          let module T = Tjc.Job.Type_ in
          let command_and_query =
            match job.Tjc.Job.type_ with
            | T.Apply { tag_query; kind = _; force = _ } -> Some ("apply", tag_query)
            | T.Plan { tag_query; kind = _ } -> Some ("plan", tag_query)
            | T.Autoapply
            | T.Autoplan
            | T.Gate_approval _
            | T.Help
            | T.Index
            | T.Repo_config
            | T.Unlock _
            | T.Push -> None
          in
          match command_and_query with
          | Some (command, tag_query) -> (
              match Terrat_tag_query.warning tag_query with
              | Some (Terrat_tag_query.Implicit_and { suggestion = Some suggestion }) -> (
                  match Terrat_tag_query.of_string suggestion with
                  | Ok suggested_query -> (
                      fetch Keys.all_matches
                      >>= fun all_matches ->
                      let all_matches = CCList.flatten all_matches in
                      let selected =
                        Terrat_data.Dirspace_set.of_list
                          (CCList.filter_map
                             (fun ({ Terrat_change_match3.Dirspace_config.dirspace; _ } as change)
                                ->
                               if Terrat_change_match3.match_tag_query ~tag_query change then
                                 Some dirspace
                               else None)
                             all_matches)
                      in
                      let dropped =
                        CCList.filter_map
                          (fun ({ Terrat_change_match3.Dirspace_config.dirspace; _ } as change) ->
                            if
                              Terrat_change_match3.match_tag_query ~tag_query:suggested_query change
                              && not (Terrat_data.Dirspace_set.mem dirspace selected)
                            then Some dirspace
                            else None)
                          all_matches
                      in
                      match dropped with
                      | [] -> Abbs_future_combinators.return_ok ()
                      | _ :: _ ->
                          fetch Keys.publish_comment
                          >>= fun publish_comment ->
                          publish_comment'
                            publish_comment
                            (Msg.Tag_query_dropped_dirspaces
                               { command; suggestion; dirspaces = dropped })
                          >>| fun () -> ())
                  | Error _ -> Abbs_future_combinators.return_ok ())
              | Some (Terrat_tag_query.Implicit_and { suggestion = None }) | None ->
                  Abbs_future_combinators.return_ok ())
          | None -> Abbs_future_combinators.return_ok ())

    let check_gates =
      run ~name:"check_gates" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.all4
            (fetch Keys.client)
            (fetch Keys.pull_request)
            (fetch Keys.working_set_matches)
            (fetch Keys.job)
          >>= fun (client, pull_request, working_set_matches, job) ->
          match job with
          | { Tjc.Job.type_ = Tjc.Job.Type_.Apply { force = true; tag_query = _; kind = _ }; _ } ->
              Abbs_future_combinators.return_ok ()
          | _ -> (
              let module Dc = Terrat_change_match3.Dirspace_config in
              let dirspaces = CCList.map (fun { Dc.dirspace; _ } -> dirspace) working_set_matches in
              Builder.run_db s ~f:(fun db -> gate_eval s db client pull_request dirspaces)
              >>= function
              | [] -> Abbs_future_combinators.return_ok ()
              | denied ->
                  fetch Keys.publish_comment
                  >>= fun publish_comment ->
                  publish_comment' publish_comment (Msg.Gate_check_failure denied)
                  >>? fun () -> Error `Noop))

    let check_dirspaces_owned_by_other_pull_requests =
      run ~name:"check_dirspaces_owned_by_other_pull_requests" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.all3 (fetch Keys.repo_config) (fetch Keys.pull_request) (fetch Keys.all_matches)
          >>= fun (repo_config, pull_request, all_matches) ->
          Abb.Future.return (H.dirspaceflows_of_changes repo_config (CCList.flatten all_matches))
          >>= fun all_match_dirspaceflows ->
          Builder.run_db s ~f:(fun db ->
              query_dirspaces_owned_by_other_pull_requests
                s
                db
                pull_request
                (CCList.map Terrat_change.Dirspaceflow.to_dirspace all_match_dirspaceflows))
          >>= function
          | [] -> Abbs_future_combinators.return_ok ()
          | owned_dirspaces ->
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Dirspaces_owned_by_other_pull_request owned_dirspaces)
              >>? fun () -> Error `Noop)

    let check_access_control_repo_config =
      run ~name:"check_access_control_repo_config" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.all2 (fetch Keys.access_control) (fetch Keys.changes)
          >>= fun (access_control, diff) ->
          let open Abb.Future.Infix_monad in
          Access_control.eval_repo_config access_control diff
          >>= function
          | Ok None -> Abbs_future_combinators.return_ok ()
          | Ok (Some match_list) ->
              let open Irm in
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `Terrateam_config_update match_list ))
              >>? fun () -> Error `Noop
          | Error `Error ->
              let open Irm in
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `Lookup_err ))
              >>? fun () -> Error `Noop)

    let check_access_control_files =
      run ~name:"check_access_control_files" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.all2 (fetch Keys.access_control) (fetch Keys.changes)
          >>= fun (access_control, diff) ->
          let open Abb.Future.Infix_monad in
          Access_control.eval_files access_control diff
          >>= function
          | Ok None -> Abbs_future_combinators.return_ok ()
          | Ok (Some (fname, match_list)) ->
              let open Irm in
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `Files (fname, match_list) ))
              >>? fun () -> Error `Noop
          | Error `Error ->
              let open Irm in
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `Lookup_err ))
              >>? fun () -> Error `Noop)

    let check_access_control_ci_change =
      run ~name:"check_access_control_ci_change" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          Ee2_fc.all2 (fetch Keys.access_control) (fetch Keys.changes)
          >>= fun (access_control, diff) ->
          let open Abb.Future.Infix_monad in
          Access_control.eval_ci_change access_control diff
          >>= function
          | Ok None -> Abbs_future_combinators.return_ok ()
          | Ok (Some match_list) ->
              let open Irm in
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `Ci_config_update match_list ))
              >>? fun () -> Error `Noop
          | Error `Error ->
              let open Irm in
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment'
                publish_comment
                (Msg.Access_control_denied
                   ( S.Api.Ref.to_string access_control.Keys.Access_control_engine.policy_branch,
                     `Lookup_err ))
              >>? fun () -> Error `Noop)

    let store_stacks =
      run ~name:"store_stacks" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.synthesized_config
          >>= fun config ->
          fetch Keys.account
          >>= fun account ->
          fetch Keys.repo
          >>= fun repo ->
          fetch Keys.pull_request
          >>= fun pull_request ->
          Builder.run_db s ~f:(fun db -> store_stacks s db account repo pull_request config))

    let can_run_plan =
      run ~name:"can_run_plan" (fun _s { Bs.Fetcher.fetch } ->
          let maybe_publish_msg msg =
            let open Irm in
            fetch Keys.publish_comment
            >>= fun publish_comment -> publish_comment' publish_comment msg
          in
          let run =
            let open Irm in
            fetch Keys.check_pull_request_state
            >>= fun () ->
            (* Building these two happens to build all sorts of useful
               dependencies for us, so build those first so the rest can
               efficiently be done concurrently. *)
            Ee2_fc.all2 (fetch Keys.branch_dirspaces) (fetch Keys.dest_branch_dirspaces)
            >>= fun _ ->
            fetch Keys.store_stacks
            >>= fun () ->
            fetch Keys.check_dirspaces_to_plan
            >>= fun () ->
            fetch Keys.warn_tag_query_dropped_dirspaces
            >>= fun () ->
            Ee2_fc.Infix_result_app.(
              (fun () () () () () () () () () -> ())
              <$> fetch Keys.check_access_control_ci_change
              <*> fetch Keys.check_access_control_files
              <*> fetch Keys.check_access_control_repo_config
              <*> fetch Keys.check_valid_destination_branch
              <*> fetch Keys.check_access_control_plan
              <*> fetch Keys.check_account_status_expired
              <*> fetch Keys.check_account_tier
              <*> fetch Keys.check_merge_conflict
              <*> fetch Keys.check_conflicting_plan_work_manifests)
          in
          let open Abb.Future.Infix_monad in
          run
          >>= function
          | Ok _ as r -> Abb.Future.return r
          | Error err ->
              (* Publish best effort: failing to comment must not replace the
                 error that actually stopped the operation. *)
              CCOption.map_or
                ~default:(Abbs_future_combinators.return_ok ())
                maybe_publish_msg
                (Tasks_base.msg_of_err err)
              >>= fun _ -> Abbs_future_combinators.return_err err)

    let can_run_apply =
      run ~name:"can_run_apply" (fun s { Bs.Fetcher.fetch } ->
          let maybe_publish_msg msg =
            let open Irm in
            fetch Keys.publish_comment
            >>= fun publish_comment -> publish_comment' publish_comment msg
          in
          let run =
            let open Irm in
            fetch Keys.check_pull_request_state
            >>= fun () ->
            (* Lock the repository to serialize apply checks and prevent
               concurrent applies on the same repository. *)
            fetch Keys.account
            >>= fun account ->
            fetch Keys.repo
            >>= fun repo ->
            Builder.run_db s ~f:(lock_repository s account repo)
            >>= fun () ->
            (* Building these two happens to build all sorts of useful
               dependencies for us, so build those first so the rest can
               efficiently be done concurrently. *)
            Ee2_fc.all2 (fetch Keys.branch_dirspaces) (fetch Keys.dest_branch_dirspaces)
            >>= fun _ ->
            fetch Keys.check_dirspaces_to_apply
            >>= fun () ->
            fetch Keys.warn_tag_query_dropped_dirspaces
            >>= fun () ->
            Ee2_fc.Infix_result_app.(
              (fun () () () () () () () () () () () _ -> ())
              <$> fetch Keys.check_access_control_ci_change
              <*> fetch Keys.check_access_control_apply
              <*> fetch Keys.check_access_control_files
              <*> fetch Keys.check_access_control_repo_config
              <*> fetch Keys.check_account_status_expired
              <*> fetch Keys.check_account_tier
              <*> fetch Keys.check_conflicting_apply_work_manifests
              <*> fetch Keys.check_dirspaces_missing_plans
              <*> fetch Keys.check_dirspaces_owned_by_other_pull_requests
              <*> fetch Keys.check_gates
              <*> fetch Keys.check_merge_conflict
              <*> fetch Keys.check_apply_requirements)
          in
          let open Abb.Future.Infix_monad in
          run
          >>= function
          | Ok _ as r -> Abb.Future.return r
          | Error err ->
              (* Publish best effort: failing to comment must not replace the
                 error that actually stopped the operation. *)
              CCOption.map_or
                ~default:(Abbs_future_combinators.return_ok ())
                maybe_publish_msg
                (Tasks_base.msg_of_err err)
              >>= fun _ -> Abbs_future_combinators.return_err err)

    let get_context_for_pull_request =
      run ~name:"get_context_for_pull_request" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.account
          >>= fun account ->
          fetch Keys.repo
          >>= fun repo ->
          fetch Keys.pull_request_id
          >>= fun pull_request_id ->
          fetch Keys.store_pull_request
          >>= fun () ->
          Builder.run_db s ~f:(fun db ->
              S.Job_context.create_or_get_for_pull_request
                ~request_id:(Builder.log_id s)
                db
                account
                repo
                pull_request_id))

    let eval_pull_request_event =
      run ~name:"eval_pull_request_event" (fun s { Bs.Fetcher.fetch } ->
          let module E = Keys.Pull_request_event in
          let open Irm in
          fetch Keys.context
          >>= fun context ->
          fetch Keys.user
          >>= fun user ->
          fetch Keys.store_pull_request
          >>= fun () ->
          fetch Keys.pull_request_event
          >>= fun pull_request_event ->
          (match pull_request_event with
            | E.Comment { comment = Terrat_comment.Feedback feedback; _ } ->
                fetch Keys.account
                >>= fun account ->
                fetch Keys.repo
                >>= fun repo ->
                fetch Keys.pull_request_id
                >>| fun pull_request_id ->
                Logs.info (fun m ->
                    m
                      "%s : FEEDBACK : account=%s : repo=%s : pull_number=%s : user=%s : %s"
                      (Builder.log_id s)
                      (S.Api.Account.to_string account)
                      (S.Api.Repo.to_string repo)
                      (S.Api.Pull_request.Id.to_string pull_request_id)
                      (CCOption.map_or ~default:"" S.Api.User.to_string user)
                      feedback);
                None
            | E.Open | E.Sync | E.Ready_for_review ->
                Abbs_future_combinators.return_ok (Some Tjc.Job.Type_.Autoplan)
            | E.Close -> Abbs_future_combinators.return_ok (Some Tjc.Job.Type_.Autoapply)
            | E.Comment { comment_id = _; comment } -> (
                match comment with
                | Terrat_comment.Apply { tag_query } ->
                    Abbs_future_combinators.return_ok
                      (Some (Tjc.Job.Type_.Apply { tag_query; kind = None; force = false }))
                | Terrat_comment.Gate_approval { tokens } ->
                    Abbs_future_combinators.return_ok
                      (Some (Tjc.Job.Type_.Gate_approval { tokens }))
                | Terrat_comment.Plan { tag_query } ->
                    Abbs_future_combinators.return_ok
                      (Some (Tjc.Job.Type_.Plan { tag_query; kind = None }))
                | Terrat_comment.Apply_force { tag_query } ->
                    Abbs_future_combinators.return_ok
                      (Some (Tjc.Job.Type_.Apply { tag_query; kind = None; force = true }))
                | Terrat_comment.Repo_config ->
                    Abbs_future_combinators.return_ok (Some Tjc.Job.Type_.Repo_config)
                | Terrat_comment.Unlock unlocks ->
                    Abbs_future_combinators.return_ok
                      (Some (Tjc.Job.Type_.Unlock (Sln_list.String.sort_uniq unlocks)))
                | Terrat_comment.Index ->
                    Abbs_future_combinators.return_ok (Some Tjc.Job.Type_.Index)
                | Terrat_comment.Help -> Abbs_future_combinators.return_ok (Some Tjc.Job.Type_.Help)
                | Terrat_comment.Apply_autoapprove _ | Terrat_comment.Feedback _ ->
                    raise (Failure "nyi")))
          >>= fun job_type ->
          match job_type with
          | Some job_type ->
              let comment_id =
                match pull_request_event with
                | E.Comment { comment_id; _ } -> Some comment_id
                | _ -> None
              in
              Builder.run_db s ~f:(fun db ->
                  S.Job_context.Job.create ~request_id:(Builder.log_id s) db job_type context user)
              >>= fun job ->
              let log_id = Builder.mk_log_id ~request_id:(Builder.log_id s) job.Tjc.Job.id in
              Logs.info (fun m ->
                  m
                    "%s : EVENT : PULL_REQUEST : target=%s : context_id=%a : log_id= %s : \
                     job_type=%a"
                    (Builder.log_id s)
                    (Hmap.Key.info Keys.iter_job)
                    Uuidm.pp
                    context.Tjc.Context.id
                    log_id
                    Tjc.Job.Type_.pp
                    job.Tjc.Job.type_);
              let s' =
                s
                |> Builder.State.orig_store
                |> Keys.Key.add Keys.job job
                |> Keys.Key.add Keys.comment_id comment_id
                |> CCFun.flip Builder.State.set_orig_store s
                |> Builder.State.set_log_id log_id
              in
              Builder.eval s' Keys.react_to_comment >>| fun () -> job
          | None -> Abbs_future_combinators.return_err `Noop)

    let store_gate_approval =
      run ~name:"store_gate_approval" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>= fun pull_request ->
          fetch Keys.job
          >>= function
          | { Tjc.Job.type_ = Tjc.Job.Type_.Gate_approval { tokens }; _ } -> (
              fetch Keys.user
              >>= function
              | Some user ->
                  Builder.run_db s ~f:(fun db ->
                      Abbs_future_combinators.List_result.iter
                        ~f:(fun token ->
                          S.Gate.add_approval
                            ~request_id:(Builder.log_id s)
                            ~token
                            ~approver:(S.Api.User.to_string user)
                            pull_request
                            db)
                        tokens)
              | None -> assert false)
          | _ -> assert false)

    let maybe_automerge =
      run ~name:"maybe_automerge" (fun s { Bs.Fetcher.fetch } ->
          let module V1 = Terrat_base_repo_config_v1 in
          let module Am = V1.Automerge in
          let open Irm in
          fetch Keys.all_matches
          >>= function
          | [] -> Abbs_future_combinators.return_ok ()
          | _ :: _ ->
              fetch Keys.repo_config
              >>= fun repo_config ->
              let {
                Am.enabled;
                delete_branch = delete_branch';
                merge_strategy;
                require_explicit_apply;
                retain_pr_title;
              } =
                V1.automerge repo_config
              in
              fetch Keys.job
              >>= fun job ->
              let is_explicit_apply =
                match job.Tjc.Job.type_ with
                | Tjc.Job.Type_.Apply _ -> true
                | _ -> false
              in
              if
                enabled
                && ((require_explicit_apply && is_explicit_apply) || not require_explicit_apply)
              then (
                fetch Keys.client
                >>= fun client ->
                fetch Keys.user
                >>= fun _user ->
                fetch Keys.pull_request
                >>= fun pull_request ->
                let open Abb.Future.Infix_monad in
                Logs.info (fun m ->
                    m
                      "%s : MERGE_PULL_REQUEST : METHOD=%s"
                      (Builder.log_id s)
                      (Am.Merge_strategy.to_string merge_strategy));
                S.Api.merge_pull_request
                  ~request_id:(Builder.log_id s)
                  ~retain_pr_title
                  client
                  pull_request
                  merge_strategy
                >>= function
                | Ok () ->
                    if delete_branch' then (
                      let repo = S.Api.Pull_request.repo pull_request in
                      let branch =
                        S.Api.Ref.to_string (S.Api.Pull_request.branch_name pull_request)
                      in
                      Logs.info (fun m ->
                          m
                            "%s : DELETE_BRANCH : repo=%s : branch=%s"
                            (Builder.log_id s)
                            (S.Api.Repo.to_string repo)
                            branch);
                      S.Api.delete_branch ~request_id:(Builder.log_id s) client repo branch
                      >>= fun _ -> Abbs_future_combinators.return_ok ())
                    else Abbs_future_combinators.return_ok ()
                | Error (`Merge_err reason) ->
                    let open Irm in
                    fetch Keys.publish_comment
                    >>= fun publish_comment ->
                    publish_comment'
                      publish_comment
                      (Msg.Automerge_failure
                         (Terrat_pull_request.set_diff () @@ pull_request, reason))
                | Error (`Error | `Vcs_api_rate_limit_err _ | `Vcs_api_timeout_err _) as err ->
                    Abb.Future.return err)
              else Abbs_future_combinators.return_ok ())
  end

  let tasks tasks =
    let coerce = Builder.coerce_to_task in
    tasks
    |> Hmap.add (coerce Keys.access_control_eval_apply) Tasks.access_control_eval_apply
    |> Hmap.add (coerce Keys.access_control_eval_plan) Tasks.access_control_eval_plan
    |> Hmap.add (coerce Keys.branch_name) Tasks.branch_name
    |> Hmap.add (coerce Keys.branch_ref) Tasks.branch_ref
    |> Hmap.add (coerce Keys.can_run_apply) Tasks.can_run_apply
    |> Hmap.add (coerce Keys.can_run_plan) Tasks.can_run_plan
    |> Hmap.add (coerce Keys.changes) Tasks.changes
    |> Hmap.add (coerce Keys.check_access_control_apply) Tasks.check_access_control_apply
    |> Hmap.add (coerce Keys.check_access_control_ci_change) Tasks.check_access_control_ci_change
    |> Hmap.add (coerce Keys.check_access_control_files) Tasks.check_access_control_files
    |> Hmap.add (coerce Keys.check_access_control_plan) Tasks.check_access_control_plan
    |> Hmap.add
         (coerce Keys.check_access_control_repo_config)
         Tasks.check_access_control_repo_config
    |> Hmap.add (coerce Keys.check_apply_requirements) Tasks.check_apply_requirements
    |> Hmap.add
         (coerce Keys.check_conflicting_apply_work_manifests)
         Tasks.check_conflicting_apply_work_manifests
    |> Hmap.add
         (coerce Keys.check_conflicting_plan_work_manifests)
         Tasks.check_conflicting_plan_work_manifests
    |> Hmap.add (coerce Keys.check_dirspaces_missing_plans) Tasks.check_dirspaces_missing_plans
    |> Hmap.add
         (coerce Keys.check_dirspaces_owned_by_other_pull_requests)
         Tasks.check_dirspaces_owned_by_other_pull_requests
    |> Hmap.add (coerce Keys.check_dirspaces_to_apply) Tasks.check_dirspaces_to_apply
    |> Hmap.add (coerce Keys.check_dirspaces_to_plan) Tasks.check_dirspaces_to_plan
    |> Hmap.add (coerce Keys.check_gates) Tasks.check_gates
    |> Hmap.add
         (coerce Keys.warn_tag_query_dropped_dirspaces)
         Tasks.warn_tag_query_dropped_dirspaces
    |> Hmap.add (coerce Keys.check_merge_conflict) Tasks.check_merge_conflict
    |> Hmap.add (coerce Keys.check_prechecks) Tasks.check_prechecks
    |> Hmap.add (coerce Keys.check_pull_request_state) Tasks.check_pull_request_state
    |> Hmap.add (coerce Keys.comment_id) Tasks.comment_id
    |> Hmap.add (coerce Keys.commit_checks) Tasks.commit_checks
    |> Hmap.add (coerce Keys.create_commit_checks) Tasks.create_commit_checks
    |> Hmap.add (coerce Keys.dest_branch_name) Tasks.dest_branch_name
    |> Hmap.add (coerce Keys.dest_branch_ref) Tasks.dest_branch_ref
    |> Hmap.add (coerce Keys.eval_pull_request_event) Tasks.eval_pull_request_event
    |> Hmap.add (coerce Keys.get_context_for_pull_request) Tasks.get_context_for_pull_request
    |> Hmap.add (coerce Keys.is_draft_pr) Tasks.is_draft_pr
    |> Hmap.add (coerce Keys.maybe_automerge) Tasks.maybe_automerge
    |> Hmap.add (coerce Keys.intra_pr_selection) Tasks.intra_pr_selection
    |> Hmap.add (coerce Keys.out_of_change_applies) Tasks.out_of_change_applies
    |> Hmap.add (coerce Keys.publish_comment) Tasks.publish_comment
    |> Hmap.add (coerce Keys.publish_help) Tasks.publish_help
    |> Hmap.add (coerce Keys.publish_index_complete) Tasks.publish_index_complete
    |> Hmap.add (coerce Keys.publish_repo_config) Tasks.publish_repo_config
    |> Hmap.add (coerce Keys.publish_unlock) Tasks.publish_unlock
    |> Hmap.add (coerce Keys.pull_request) Tasks.pull_request
    |> Hmap.add (coerce Keys.pull_request_diff) Tasks.pull_request_diff
    |> Hmap.add (coerce Keys.pull_request_reviews) Tasks.pull_request_reviews
    |> Hmap.add (coerce Keys.react_to_comment) Tasks.react_to_comment
    |> Hmap.add (coerce Keys.store_gate_approval) Tasks.store_gate_approval
    |> Hmap.add (coerce Keys.store_pull_request) Tasks.store_pull_request
    |> Hmap.add (coerce Keys.store_stacks) Tasks.store_stacks
    |> Hmap.add (coerce Keys.working_branch_name) Tasks.working_branch_name
    |> Hmap.add (coerce Keys.working_branch_ref) Tasks.working_branch_ref
    |> Hmap.add (coerce Keys.working_dest_branch_ref) Tasks.working_dest_branch_ref
end
