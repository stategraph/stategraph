module Metrics = struct
  module Task_exec_duration = Prmths.Histogram (struct
    let spec = Prmths.Histogram_spec.of_list [ 0.0; 1.0; 2.0; 5.0; 10.0; 20.0; 50.0; 100.0 ]
  end)

  let namespace = "terrat"
  let subsystem = "vcs_event_evaluator2_task_base"

  let exec_duration =
    let help = "Time scheduler spends processing a task." in
    Task_exec_duration.v_label ~label_name:"task" ~help ~namespace ~subsystem "exec_duration"
end

module Msg = Terrat_vcs_provider2.Msg

module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) =
struct
  let src = Logs.Src.create ("vcs_event_evaluator2_tasks_base." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module Builder = Terrat_vcs_event_evaluator2_builder.Make (S)

  let run ~name f path s fetcher =
    Abb.Future.await_bind (function
      | `Det r -> Abb.Future.return r
      | `Exn (Buildsys.Error.Fetch_cycle_exn exn, bt_opt) ->
          Logs.err (fun m -> m "%s : %a" (Builder.log_id s) Buildsys.Error.pp exn);
          CCOption.iter
            (fun bt ->
              Logs.err (fun m ->
                  m "%s : BACKTRACE: %s" (Builder.log_id s) (Printexc.raw_backtrace_to_string bt)))
            bt_opt;
          Abbs_fc.return_err `Error
      | `Exn (exn, bt_opt) ->
          Logs.err (fun m -> m "%s : %s" (Builder.log_id s) (Printexc.to_string exn));
          CCOption.iter
            (fun bt ->
              Logs.err (fun m ->
                  m "%s : BACKTRACE: %s" (Builder.log_id s) (Printexc.raw_backtrace_to_string bt)))
            bt_opt;
          Abbs_fc.return_err `Error
      | `Aborted ->
          Logs.err (fun m -> m "%s : ABORTED" (Builder.log_id s));
          Abbs_fc.return_err `Error)
    @@ Abbs_time_it.run'
         (fun ret t ->
           Metrics.Task_exec_duration.observe (Metrics.exec_duration name) t;
           match ret with
           | Ok _ ->
               Logs.info (fun m ->
                   m "%s : TASK : END : SUCCESS : name=%s : time=%f" (Builder.log_id s) name t)
           | Error (`Suspend_eval _) ->
               Logs.info (fun m ->
                   m "%s : TASK : END: SUSPEND : name=%s : time=%f" (Builder.log_id s) name t)
           | Error `Noop ->
               Logs.info (fun m ->
                   m "%s : TASK : END: NOOP : name=%s : time=%f" (Builder.log_id s) name t)
           | Error (`Rerun _) ->
               (* Not a failure: the task committed something and asked for a
                  fresh transaction, so every task on the path back up would
                  otherwise read as FAIL. *)
               Logs.info (fun m ->
                   m "%s : TASK : END: RERUN : name=%s : time=%f" (Builder.log_id s) name t)
           | Error #Builder.err ->
               Logs.info (fun m ->
                   m "%s : TASK : END: FAIL : name=%s : time=%f" (Builder.log_id s) name t))
         (fun () ->
           Logs.info (fun m ->
               m
                 "%s : TASK : START : name=%s : path=[%s]"
                 (Builder.log_id s)
                 name
                 (CCString.concat ", " path));
           f (Builder.State.set_path path s) fetcher)

  (* Publishing a comment is the last thing we can do for a user.  If it fails,
     the failure is [`Silent_failure]: retrying the publish from an error
     handler would fail for the same reason and, if it did not, would publish a
     second comment. *)
  let publish_comment' f msg =
    let open Abb.Future.Infix_monad in
    f msg
    >>= function
    | Ok () -> Abbs_fc.return_ok ()
    | Error `Error -> Abbs_fc.return_err `Silent_failure

  (* Commit checks are not the user's only channel, so unlike [publish_comment']
     a failure here is worth a comment of its own.

     Creating no checks is a no-op: performing it would dirty the commit checks,
     forcing anyone that reads them afterwards to fetch them again for no
     benefit. *)
  let create_commit_checks' f branch_ref = function
    | [] -> Abbs_fc.return_ok ()
    | checks -> (
        let open Abb.Future.Infix_monad in
        f branch_ref checks
        >>= function
        | Ok () -> Abbs_fc.return_ok ()
        | Error ((`Vcs_api_rate_limit_err _ | `Vcs_api_timeout_err _) as err) ->
            Abbs_fc.return_err err
        | Error `Error -> Abbs_fc.return_err (`Vcs_api_err "CREATE_COMMIT_CHECKS"))

  let time_it s l f =
    Abbs_time_it.run (fun time -> Logs.info (fun m -> l m (Builder.log_id s) time)) f

  (* Publishing commit checks is the same work in the PR flow and in the branch flow: only the
     ref that receives the checks differs, and the ref is an argument of the returned function.
     Both flows register this task; a rule written twice drifts. *)
  let create_commit_checks =
    run ~name:"create_commit_checks" (fun s { Builder.Bs.Fetcher.fetch } ->
        let open Abbs_fc.Infix_result_monad in
        fetch Keys.client
        >>= fun client ->
        fetch Keys.repo
        >>| fun repo ->
        fun branch_ref checks ->
         (* When updating commit checks, mark the existing key as dirty. *)
         Builder.State.mark_dirty s Keys.commit_checks;
         let open Abbs_fc.Infix_result_monad in
         S.Repo_config.fetch_brand ~request_id:(Builder.log_id s) client repo
         >>= fun brand ->
         S.Api.create_commit_checks
           ~request_id:(Builder.log_id s)
           ~brand
           client
           repo
           branch_ref
           checks)

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

  let abort_work_manifest s db work_manifest_id run_id =
    let open Abbs_fc.Infix_result_monad in
    time_it
      s
      (fun m log_id time ->
        m
          "%s : WM : UPDATE_STATE : work_manifest_id = %a : run_id = %s : state = aborted : time=%f"
          log_id
          Uuidm.pp
          work_manifest_id
          run_id
          time)
      (fun () ->
        S.Work_manifest.update_run_id ~request_id:(Builder.log_id s) db work_manifest_id run_id
        >>= fun () ->
        S.Work_manifest.update_state
          ~request_id:(Builder.log_id s)
          db
          work_manifest_id
          Terrat_work_manifest3.State.Aborted)

  let repo_config_hash repo_config =
    let json_str =
      repo_config
      |> Terrat_base_repo_config_v1.to_version_1
      |> Terrat_repo_config.Version_1.to_yojson
      |> Yojson.Safe.sort
      |> Yojson.Safe.to_string
    in
    Sha256.(to_hex (string json_str))

  let build_config_cache_ref ref_ repo_config =
    S.Api.Ref.of_string (S.Api.Ref.to_string ref_ ^ ":" ^ repo_config_hash repo_config)

  let dirspaces_of_paths config paths =
    paths
    |> CCList.map (fun filename -> Terrat_change.Diff.Change { filename })
    |> Terrat_change_match3.match_diff_list config
    |> CCList.flatten
    |> CCList.map (fun dc -> dc.Terrat_change_match3.Dirspace_config.dirspace)
    |> Terrat_data.Dirspace_set.of_list

  let stategraph_parallel_apply repo_config workflow =
    let module R = Terrat_base_repo_config_v1 in
    let module E = R.Workflows.Entry in
    let engine =
      match workflow with
      | Some { E.engine; _ } -> engine
      | None -> R.engine repo_config
    in
    S.stategraph_parallel_applies
    &&
    match engine with
    | R.Engine.Stategraph _ -> true
    | R.Engine.(
        Cdktf _ | Custom _ | Fly _ | Opentofu _ | Other _ | Pulumi | Terraform _ | Terragrunt _) ->
        false

  let stategraph_parallel_apply_dirspaces repo_config dirspaceflows =
    let module Dsf = Terrat_change.Dirspaceflow in
    CCList.filter_map
      (fun { Dsf.dirspace; workflow; _ } ->
        if
          stategraph_parallel_apply
            repo_config
            (CCOption.map (fun { Dsf.Workflow.workflow; _ } -> workflow) workflow)
        then Some dirspace
        else None)
      dirspaceflows

  let stategraph_parallel_apply_dirspaces_of_work_manifest repo_config dirspaceflows =
    let module Dsf = Terrat_change.Dirspaceflow in
    let workflows = Terrat_base_repo_config_v1.workflows repo_config in
    CCList.filter_map
      (fun { Dsf.dirspace; workflow; _ } ->
        if
          stategraph_parallel_apply
            repo_config
            (CCOption.flat_map (CCList.nth_opt workflows) workflow)
        then Some dirspace
        else None)
      dirspaceflows

  (* What the two rules that order a plan against an apply are given, read from Stategraph through
     the reader for the overlap rows of our plans beside the applies of other pull requests: when
     the transaction of our plan of each dirspace opened, and when the transaction of each apply
     completed, by the apply's work manifest.  A transaction the reader does not know gives neither. *)
  let stategraph_moments_of_rows ~request_id ~installation rows =
    let module Pat = Terrat_vcs_provider2.Parallel_apply_tx in
    let module Sm = Terrat_vcs_provider2.Stategraph_moments in
    let module T = Terrat_stategraph.Transaction in
    let open Abbs_fc.Infix_result_monad in
    let txs =
      rows
      |> CCList.flat_map (fun { Pat.tx; other; _ } ->
          tx :: CCOption.map_or ~default:[] (fun { Pat.Other.tx; _ } -> [ tx ]) other)
      |> CCList.sort_uniq ~cmp:Uuidm.compare
    in
    S.Stategraph.transactions ~request_id ~installation ~txs
    >>| fun moments ->
    let find tx = Sln_map.Uuidm.find_opt tx moments in
    let planned_at =
      rows
      |> CCList.filter_map (fun { Pat.dirspace; tx; _ } ->
          CCOption.map (fun { T.created_at; _ } -> (dirspace, created_at)) (find tx))
      |> CCList.sort_uniq ~cmp:(fun (a, _) (b, _) -> Terrat_change.Dirspace.compare a b)
    in
    let committed_at =
      rows
      |> CCList.filter_map (fun { Pat.other; _ } ->
          CCOption.flat_map
            (fun { Pat.Other.work_manifest; tx; _ } ->
              CCOption.flat_map
                (fun { T.completed_at; _ } ->
                  CCOption.map (fun at -> (work_manifest, at)) completed_at)
                (find tx))
            other)
      |> CCList.sort_uniq ~cmp:(fun (a, _) (b, _) -> Uuidm.compare a b)
    in
    { Sm.planned_at; committed_at }

  (* The moments of the transactions of our plans of [dirspaces] and of the applies of other pull
     requests on them.  The reader failing is logged and leaves the rules to the bounds of the
     runs, which are safe; a database error is an error. *)
  let stategraph_moments ~request_id db pull_request dirspaces =
    let module Pat = Terrat_vcs_provider2.Parallel_apply_tx in
    let module Sm = Terrat_vcs_provider2.Stategraph_moments in
    match dirspaces with
    | [] -> Abbs_fc.return_ok Sm.empty
    | dirspaces -> (
        let open Abbs_fc.Infix_result_monad in
        S.Db.query_parallel_apply_transactions ~request_id db pull_request dirspaces
        >>= function
        | [] -> Abbs_fc.return_ok Sm.empty
        | { Pat.installation; _ } :: _ as rows -> (
            let open Abb.Future.Infix_monad in
            stategraph_moments_of_rows ~request_id ~installation rows
            >>= function
            | Ok _ as moments -> Abb.Future.return moments
            | Error `Error ->
                Logs.err (fun m -> m "%s : STATEGRAPH_MOMENTS_FAILED" request_id);
                Abbs_fc.return_ok Sm.empty))

  (* The reservation is the work manifest's: its id is the holder.  Both are best effort, because
     the commit decides on its own without them: a failure here is logged and the apply goes on. *)
  let reserve_stategraph_plans ~request_id db pull_request work_manifest_id dirspaces =
    match dirspaces with
    | [] -> Abb.Future.return ()
    | dirspaces -> (
        let module Pat = Terrat_vcs_provider2.Parallel_apply_tx in
        let open Abb.Future.Infix_monad in
        let run =
          let open Abbs_fc.Infix_result_monad in
          S.Db.query_parallel_apply_transactions ~request_id db pull_request dirspaces
          >>= function
          | [] -> Abbs_fc.return_ok ()
          | { Pat.installation; _ } :: _ as rows ->
              (* A dirspace gives one row per apply of another pull request on it: its plan's
                 transaction once. *)
              S.Stategraph.reserve
                ~request_id
                ~installation
                ~holder:(Uuidm.to_string work_manifest_id)
                ~txs:
                  (rows
                  |> CCList.map (fun { Pat.tx; _ } -> tx)
                  |> CCList.sort_uniq ~cmp:Uuidm.compare)
        in
        run
        >>| function
        | Ok () -> ()
        | Error `Error ->
            Logs.err (fun m ->
                m
                  "%s : STATEGRAPH_RESERVE_FAILED : work_manifest_id=%a"
                  request_id
                  Uuidm.pp
                  work_manifest_id))

  let release_stategraph_reservation ~request_id work_manifest_id =
    let open Abb.Future.Infix_monad in
    S.Stategraph.release ~request_id ~holder:(Uuidm.to_string work_manifest_id)
    >>| function
    | Ok () -> ()
    | Error `Error ->
        Logs.err (fun m ->
            m
              "%s : STATEGRAPH_RELEASE_FAILED : work_manifest_id=%a"
              request_id
              Uuidm.pp
              work_manifest_id)

  (* With the tree builder off, the server reads a tree from the forge and stores it, as the
     [repo_tree_branch] task does.  With it on, only a tree build work manifest stores a tree, and
     starting one here would make the caller wait, which it must not. *)
  let ensure_repo_tree s ~missing_tree ~tree_builder ~account ref_ =
    let open Abbs_fc.Infix_result_monad in
    Builder.run_db s ~f:(fun db ->
        S.Db.query_repo_tree_built
          ~request_id:(Builder.log_id s)
            (* With the tree builder on, the trees this comparison reads are the ones the script
             made, thus a tree read from the forge does not answer. *)
          ~script_only:tree_builder
          db
          account
          ref_)
    >>= function
    | true -> Abbs_fc.return_ok true
    | false -> (
        match missing_tree with
        | `Unknown -> Abbs_fc.return_ok false
        | `Fetch _ when tree_builder -> Abbs_fc.return_ok false
        | `Fetch (client, repo) ->
            time_it
              s
              (fun m log_id time ->
                m
                  "%s : STALENESS : FETCH_TREE : repo = %s : ref = %s : time=%f"
                  log_id
                  (S.Api.Repo.to_string repo)
                  (S.Api.Ref.to_string ref_)
                  time)
              (fun () -> S.Api.fetch_tree ~request_id:(Builder.log_id s) client repo ref_)
            >>= fun files ->
            Builder.run_db s ~f:(fun db ->
                S.Db.store_repo_tree
                  ~request_id:(Builder.log_id s)
                  ~built_by_script:false
                  db
                  account
                  ref_
                  files)
            >>| fun () -> true)

  (* The config is tested first, then both trees: [query_repo_tree_changes] against a tree that is
     not stored gives back every path of the other tree, which is a walk of the whole repository
     through the change match to reach an answer that is only "unknown". *)
  let changed_between s ~missing_tree ~config ~repo_config_raw ~account ~from_ref ~to_ref =
    let module V1 = Terrat_base_repo_config_v1 in
    let open Abbs_fc.Infix_result_monad in
    let tree_builder = (V1.tree_builder repo_config_raw).V1.Tree_builder.enabled in
    let config_builder = (V1.config_builder repo_config_raw).V1.Config_builder.enabled in
    if S.Api.Ref.equal from_ref to_ref then Abbs_fc.return_ok (Some Terrat_data.Dirspace_set.empty)
    else
      (if config_builder then
         Builder.run_db s ~f:(fun db ->
             S.Db.query_repo_config_json
               ~request_id:(Builder.log_id s)
               db
               account
               (build_config_cache_ref to_ref repo_config_raw))
         >>| CCOption.is_some
       else Abbs_fc.return_ok true)
      >>= fun config_built ->
      (if config_built then ensure_repo_tree s ~missing_tree ~tree_builder ~account from_ref
       else Abbs_fc.return_ok false)
      >>= fun from_stored ->
      (if from_stored then ensure_repo_tree s ~missing_tree ~tree_builder ~account to_ref
       else Abbs_fc.return_ok false)
      >>= fun to_stored ->
      if to_stored then
        Builder.run_db s ~f:(fun db ->
            query_repo_tree_changes ~base_ref:from_ref s db account to_ref)
        >>| fun paths -> Some (dirspaces_of_paths config paths)
      else (
        Logs.info (fun m ->
            m
              "%s : STALENESS : NOT_COMPARED : from_ref = %s : to_ref = %s : config_built = %b : \
               from_stored = %b"
              (Builder.log_id s)
              (S.Api.Ref.to_string from_ref)
              (S.Api.Ref.to_string to_ref)
              config_built
              from_stored);
        Abbs_fc.return_ok None)

  let pending_apply_check ~config ~account ~repo ~apply_requirements ~commit_checks matches =
    let module Ar = Terrat_base_repo_config_v1.Apply_requirements in
    let apply_check_exists =
      CCList.exists
        (fun check -> CCString.equal check.Terrat_commit_check.title "terrateam apply")
        commit_checks
    in
    match matches with
    | _ :: _ when apply_requirements.Ar.create_pending_apply_check && not apply_check_exists ->
        [
          S.Commit_check.make_str
            ~config
            ~description:"Waiting"
            ~status:Terrat_commit_check.Status.Queued
            ~repo
            ~account
            "terrateam apply";
        ]
    | [] | _ :: _ -> []

  let apply_check_description = function
    | `Changes | `Not_run -> "Completed"
    | `No_changes -> "No Changes"

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

  (* A precheck answers before the tree, the config and the index exist, and a
     read of the matches would build all three. *)
  let create_completed_apply_check ~description s { Builder.Bs.Fetcher.fetch } =
    let open Abbs_fc.Infix_result_monad in
    fetch Keys.account
    >>= fun account ->
    fetch Keys.repo
    >>= fun repo ->
    let checks =
      [
        S.Commit_check.make_str
          ~config:(Builder.State.config s)
          ~description
          ~status:Terrat_commit_check.Status.Completed
          ~repo
          ~account
          "terrateam apply";
      ]
    in
    fetch Keys.branch_ref
    >>= fun branch_ref ->
    fetch Keys.create_commit_checks
    >>= fun create_commit_checks -> create_commit_checks' create_commit_checks branch_ref checks

  (* The comment, if any, a user should see for an evaluation error.  [None]
     means say nothing: either nothing went wrong ([`Noop], [`Suspend_eval],
     [`Rerun]) or everything worth saying has already been said
     ([`Silent_failure]).

     Every constructor is listed rather than falling back on a [#Builder.err]
     catch-all, so that adding a member to [Keys.err] fails the build until
     someone decides what the user is told. *)
  let msg_of_err : Builder.err -> Keys.msg option = function
    | #Terrat_base_repo_config_v1.of_version_1_err as err -> Some (Msg.Repo_config_err err)
    | #Terrat_change_match3.synthesize_config_err as err -> Some (Msg.Synthesize_config_err err)
    | #Str_template.err as err -> Some (Msg.Str_template_err err)
    | `Json_decode_err (fname, err) | `Yaml_decode_err (fname, err) ->
        Some (Msg.Repo_config_parse_failure (fname, err))
    | `Repo_config_schema_err (fname, err) -> Some (Msg.Repo_config_schema_err (fname, err))
    | `Premium_feature_err feature -> Some (Msg.Premium_feature_err feature)
    | `Config_merge_err details -> Some (Msg.Repo_config_merge_err details)
    | `Branch_not_found_err branch -> Some (Msg.Operation_failed (`Branch_not_found_err branch))
    | `Compute_aborted_err num_aborts ->
        Some (Msg.Operation_failed (`Compute_aborted_err num_aborts))
    | `Vcs_api_err operation -> Some (Msg.Operation_failed (`Vcs_api_err operation))
    | `Vcs_api_rate_limit_err operation ->
        Some (Msg.Operation_failed (`Vcs_api_rate_limit_err operation))
    | `Vcs_api_timeout_err operation -> Some (Msg.Operation_failed (`Vcs_api_timeout_err operation))
    | `Closed | #Pgsql_io.err | #Pgsql_pool.err | `Mql_err _ -> Some (Msg.Operation_failed `Db_err)
    | `Missing_dep_err tag | `Msg_err tag | `Unexpected_err tag ->
        Some (Msg.Operation_failed (`Internal_err tag))
    | `No_matching_token_err token ->
        Some (Msg.Operation_failed (`Internal_err ("GATE_TOKEN:" ^ token)))
    | `Work_manifest_err id ->
        Some (Msg.Operation_failed (`Internal_err ("WORK_MANIFEST:" ^ Uuidm.to_string id)))
    | `Error -> Some (Msg.Operation_failed (`Internal_err "UNKNOWN"))
    | `Noop | `Suspend_eval _ | `Rerun _ | `Silent_failure -> None

  let forward_std_keys s store =
    store
    |> Builder.State.forward_store_value Keys.pull_request s
    |> Builder.State.forward_store_value Keys.repo s
    |> Builder.State.forward_store_value Keys.account s
    |> Builder.State.forward_store_value Keys.repo_config_system_defaults s
end
