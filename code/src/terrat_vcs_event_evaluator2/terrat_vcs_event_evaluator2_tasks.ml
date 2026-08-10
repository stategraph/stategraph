module Fc = Abbs_future_combinators
module Irm = Abbs_future_combinators.Infix_result_monad
module Tjc = Terrat_job_context
module Msg = Terrat_vcs_provider2.Msg

module Make
    (S : Terrat_vcs_provider2.S)
    (Keys : module type of Terrat_vcs_event_evaluator2_targets.Make (S)) =
struct
  let src = Logs.Src.create ("vcs_event_evaluator2_tasks." ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)
  module Repo_tree_wm = Terrat_vcs_event_evaluator2_wm_sm_repo_tree.Make (S) (Keys)
  module Build_config_wm = Terrat_vcs_event_evaluator2_wm_sm_build_config.Make (S) (Keys)
  module Indexer_wm = Terrat_vcs_event_evaluator2_wm_sm_indexer.Make (S) (Keys)
  module Tf_op_wm = Terrat_vcs_event_evaluator2_wm_sm_tf_op.Make (S) (Keys)
  module Hmap = Keys.Hmap
  module Builder = Terrat_vcs_event_evaluator2_builder.Make (S)
  module Bs = Builder.Bs
  module Tasks_base = Terrat_vcs_event_evaluator2_tasks_base.Make (S) (Keys)
  module Tasks_pr = Terrat_vcs_event_evaluator2_tasks_pr.Make (S) (Keys)
  module Tasks_branch = Terrat_vcs_event_evaluator2_tasks_branch.Make (S) (Keys)

  let time_it s l f =
    Abbs_time_it.run (fun time -> Logs.info (fun m -> l m (Builder.log_id s) time)) f

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

  let repo_config_cache_key account repo ref_ repo_config =
    S.Api.Account.to_string account
    ^ "."
    ^ S.Api.Repo.to_string repo
    ^ "."
    ^ S.Api.Ref.to_string ref_
    ^ ":"
    ^ repo_config_hash repo_config

  let update_job_state_completed s job_id db =
    time_it
      s
      (fun m log_id time ->
        m "%s : JOB : UPDATE_STATE : COMPLETED : job_id = %a : time=%f" log_id Uuidm.pp job_id time)
      (fun () ->
        S.Job_context.Job.update_state
          ~request_id:(Builder.log_id s)
          db
          ~job_id
          Tjc.Job.State.Completed)

  let update_job_state_failed s job_id db =
    time_it
      s
      (fun m log_id time ->
        m "%s : JOB : UPDATE_STATE : FAILED : job_id = %a : time=%f" log_id Uuidm.pp job_id time)
      (fun () ->
        S.Job_context.Job.update_state
          ~request_id:(Builder.log_id s)
          db
          ~job_id
          Tjc.Job.State.Failed)

  let add_work_manifest_keys work_manifest store =
    let module Wm = Terrat_work_manifest3 in
    let { Wm.id = _; account; target; _ } = work_manifest in
    match target with
    | Terrat_vcs_provider2.Target.Pr pr ->
        store
        |> Keys.Key.add Keys.account account
        |> Keys.Key.add Keys.pull_request_id (S.Api.Pull_request.id pr)
        |> Keys.Key.add Keys.repo (S.Api.Pull_request.repo pr)
    | Terrat_vcs_provider2.Target.Drift { repo; _ } ->
        store |> Keys.Key.add Keys.account account |> Keys.Key.add Keys.repo repo

  module H = struct
    let complete_job s job fut =
      let open Abb.Future.Infix_monad in
      fut
      >>= function
      | (Ok () | Error `Noop) as ret ->
          let open Irm in
          Builder.run_db s ~f:(fun db -> update_job_state_completed s job.Tjc.Job.id db)
          >>= fun () -> Abb.Future.return ret
      | Error (`Suspend_eval _) as err -> Abb.Future.return err
      | Error (#Builder.err as err) -> (
          Builder.run_db s ~f:(fun db -> update_job_state_failed s job.Tjc.Job.id db)
          >>= function
          | Ok () -> Abb.Future.return (Error err)
          | Error (#Builder.err as err2) ->
              Logs.err (fun m -> m "%s : %a" (Builder.log_id s) Builder.pp_err err2);
              Abb.Future.return (Error err))
  end

  module Cache = struct
    module Key = struct
      type t = string * string [@@deriving show]
    end

    let load ~cache_key db =
      let open Abb.Future.Infix_monad in
      let kv = { Terrat_kv_store.db; user_caps = [] } in
      Terrat_kv_store.get ~key:cache_key kv
      >>= function
      | Ok (Some record) -> (
          match Terrat_kv_store.Record.data record with
          | `String sha256_hex -> (
              let data_cache_key = (fst cache_key ^ ".data", sha256_hex) in
              Terrat_kv_store.get ~key:data_cache_key kv
              >>= function
              | Ok _ as r -> Abb.Future.return r
              | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err))
          | _ -> Abb.Future.return (Ok None))
      | Ok None -> Abb.Future.return (Ok None)
      | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err)

    let store ~cache_key v db =
      let open Abb.Future.Infix_monad in
      let kv = { Terrat_kv_store.db; user_caps = [] } in
      let json_str = Yojson.Safe.to_string (Yojson.Safe.sort v) in
      let sha256_hex = Sha256.(to_hex (string json_str)) in
      let data_cache_key = (fst cache_key ^ ".data", sha256_hex) in
      Terrat_kv_store.get ~key:data_cache_key kv
      >>= (function
      | Ok (Some _) -> Abb.Future.return (Ok ())
      | Ok None -> (
          Terrat_kv_store.set ~key:data_cache_key v kv
          >>= function
          | Ok _ -> Abb.Future.return (Ok ())
          | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err))
      | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err))
      >>= function
      | Ok () -> (
          Terrat_kv_store.set ~key:cache_key (`String sha256_hex) kv
          >>= function
          | Ok _ -> Abb.Future.return (Ok ())
          | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err))
      | Error _ as err -> Abb.Future.return err

    (* Persist the fully-derived config to the repo_configs history so it can be
       analyzed by org/repo/branch over time. Failures here must not fail the
       evaluation, so errors are logged and swallowed. *)
    let write_config_history ~account ~repo ~branch ~sha repo_config_json s =
      let open Abb.Future.Infix_monad in
      Builder.run_db s ~f:(fun db ->
          S.Db.store_repo_config_history
            ~request_id:(Builder.log_id s)
            db
            account
            repo
            ~branch
            ~sha
            repo_config_json)
      >>= function
      | Ok () | Error `Closed -> Abb.Future.return (Ok ())
      | Error (#Builder.err as err) ->
          Logs.err (fun m ->
              m "%s : RECORD_REPO_CONFIG_HISTORY : %a" (Builder.log_id s) Builder.pp_err err);
          Abb.Future.return (Ok ())

    (* [record_history] carries the (account, repo, branch) identity to snapshot
       the derived config under. It is [Some] only on the full-index derive
       paths, so an empty-index intermediate never overwrites the canonical
       config for a given (repo, branch, sha). *)
    let derive
        ~cache_key
        ~record_history
        ~dest_branch_name
        ~branch_name
        ~branch_ref
        ~index
        ~repo_tree
        ~repo_config_raw
        s =
      let open Irm in
      Abbs_time_it.run
        (fun t ->
          Logs.info (fun m ->
              m
                "%s : derived_repo_config : derive : ref = %s : time=%f"
                (Builder.log_id s)
                (S.Api.Ref.to_string branch_ref)
                t))
        (fun () ->
          Abbs_future_combinators.to_result
          @@ Abb.Thread.run (fun () ->
              Terrat_base_repo_config_v1.derive
                ~ctx:
                  (Terrat_base_repo_config_v1.Ctx.make
                     ~dest_branch:(S.Api.Ref.to_string dest_branch_name)
                     ~branch:(S.Api.Ref.to_string branch_name)
                     ())
                ~index
                ~file_list:repo_tree
                repo_config_raw))
      >>= fun repo_config ->
      let repo_config_json =
        Terrat_repo_config.Version_1.to_yojson
        @@ Terrat_base_repo_config_v1.to_version_1 repo_config
      in
      Builder.run_db s ~f:(store ~cache_key repo_config_json)
      >>= fun _ ->
      (match record_history with
        | Some (account, repo, branch) ->
            write_config_history ~account ~repo ~branch ~sha:branch_ref repo_config_json s
        | None -> Abb.Future.return (Ok ()))
      >>= fun () -> Abb.Future.return (Ok repo_config)

    let derived_repo_config
        ~cache_key
        ~record_history
        ~dest_branch_name
        ~branch_name
        ~branch_ref
        ~index
        ~repo_tree
        ~repo_config_raw
        s
        { Bs.Fetcher.fetch = _ } =
      let open Irm in
      Builder.run_db s ~f:(load ~cache_key)
      >>= function
      | Some repo_config_json -> (
          let module V1 = Terrat_base_repo_config_v1 in
          match V1.of_version_1_json_derived (Terrat_kv_store.Record.data repo_config_json) with
          | Ok repo_config -> Abb.Future.return (Ok repo_config)
          | Error (#V1.of_version_1_json_err as err) ->
              Logs.err (fun m ->
                  m
                    "%s : OF_VERSION_1_DERIVED : %a"
                    (Builder.log_id s)
                    V1.pp_of_version_1_json_err
                    err);
              derive
                ~cache_key
                ~record_history
                ~dest_branch_name
                ~branch_name
                ~branch_ref
                ~index
                ~repo_tree
                ~repo_config_raw
                s)
      | None ->
          derive
            ~cache_key
            ~record_history
            ~dest_branch_name
            ~branch_name
            ~branch_ref
            ~index
            ~repo_tree
            ~repo_config_raw
            s
  end

  module Tasks = struct
    let run = Tasks_base.run

    let account_status =
      run ~name:"account_status" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.account
          >>= fun account ->
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : QUERY_ACCOUNT_STATUS : account = %s : time=%f"
                    log_id
                    (S.Api.Account.to_string account)
                    time)
                (fun () -> S.Db.query_account_status ~request_id:(Builder.log_id s) db account)))

    (* Wrapper so that when we call [publish_comment] the error type lines up *)
    let publish_comment' f msg =
      let open Abb.Future.Infix_monad in
      f msg
      >>= function
      | Ok () -> Abb.Future.return (Ok ())
      | Error `Error -> Abb.Future.return (Error `Error)

    let create_commit_checks' f branch_ref checks =
      let open Abb.Future.Infix_monad in
      f branch_ref checks
      >>= function
      | Ok () -> Abb.Future.return (Ok ())
      | Error `Error -> Abb.Future.return (Error `Error)

    let missing_autoplan_matches' f matches =
      let open Abb.Future.Infix_monad in
      f matches
      >>= function
      | Ok _ as r -> Abb.Future.return r
      | Error #Builder.err as err -> Abb.Future.return err

    let target =
      run ~name:"target" (fun _s { Bs.Fetcher.fetch } ->
          let module C = Terrat_job_context.Context in
          let open Irm in
          fetch Keys.context
          >>= function
          | { C.scope = C.Scope.Pull_request _; _ } ->
              fetch Keys.pull_request
              >>= fun pull_request ->
              Abb.Future.return
                (Ok
                   (Terrat_vcs_provider2.Target.Pr
                      (Terrat_pull_request.set_diff ()
                      @@ Terrat_pull_request.set_checks ()
                      @@ pull_request)))
          | { C.scope = C.Scope.Branch (branch, _); _ } ->
              fetch Keys.repo
              >>= fun repo ->
              Abb.Future.return
                (Ok
                   (Terrat_vcs_provider2.Target.Drift { repo; branch = S.Api.Ref.to_string branch })))

    let initiator =
      run ~name:"initiator" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.job
          >>= function
          | { Tjc.Job.initiator = Some user; _ } ->
              Abb.Future.return
                (Ok (Terrat_work_manifest3.Initiator.User (S.Api.User.to_string user)))
          | { Tjc.Job.initiator = None; _ } ->
              Abb.Future.return (Ok Terrat_work_manifest3.Initiator.System))

    let user =
      run ~name:"user" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.job >>= fun { Tjc.Job.initiator; _ } -> Abb.Future.return (Ok initiator))

    let client =
      run ~name:"client" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.account
          >>= fun account ->
          Builder.run_db s ~f:(fun db ->
              S.Api.create_client ~request_id:(Builder.log_id s) (Builder.State.config s) account db))

    let commit_checks = run ~name:"commit_checks" (fun _s _ -> Abb.Future.return (Ok []))

    let context_id =
      run ~name:"context_id" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.job >>= fun job -> Abb.Future.return (Ok job.Tjc.Job.context.Tjc.Context.id))

    let context =
      run ~name:"context" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.context_id
          >>= fun context_id ->
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m "%s : QUERY_CONTEXT : context_id = %a : time=%f" log_id Uuidm.pp context_id time)
                (fun () -> S.Job_context.query ~request_id:(Builder.log_id s) db context_id))
          >>= function
          | Some context -> Abb.Future.return (Ok context)
          | None -> assert false)

    let work_manifest_event =
      run ~name:"work_manifest_event" (fun _s { Bs.Fetcher.fetch = _ } ->
          (* This is a default value in case no work manifest event is set in the store
             by the runner. *)
          Abb.Future.return (Ok None))

    let work_manifests_for_job =
      run ~name:"work_manifests_for_job" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.job
          >>= fun job ->
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : QUERY_WORK_MANIFESTS : job_id = %a : time=%f"
                    log_id
                    Uuidm.pp
                    job.Tjc.Job.id
                    time)
                (fun () ->
                  S.Job_context.Job.query_work_manifests
                    ~request_id:(Builder.log_id s)
                    db
                    ~job_id:job.Tjc.Job.id
                    ())))

    let default_branch_sha =
      run ~name:"default_branch_sha" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.client
          >>= fun client ->
          fetch Keys.repo
          >>= fun repo ->
          time_it
            s
            (fun m log_id time ->
              m
                "%s : FETCH_REMOTE_REPO : repo = %s : time=%f"
                log_id
                (S.Api.Repo.to_string repo)
                time)
            (fun () -> S.Api.fetch_remote_repo ~request_id:(Builder.log_id s) client repo)
          >>= fun remote_repo ->
          let default_branch = S.Api.Remote_repo.default_branch remote_repo in
          time_it
            s
            (fun m log_id time ->
              m
                "%s : FETCH_REMOTE_SHA : repo = %s : branch = %s : time=%f"
                log_id
                (S.Api.Repo.to_string repo)
                (S.Api.Ref.to_string default_branch)
                time)
            (fun () ->
              S.Api.fetch_branch_sha ~request_id:(Builder.log_id s) client repo default_branch)
          >>= function
          | Some branch_sha -> Abb.Future.return (Ok branch_sha)
          | None -> Abb.Future.return (Error `Error))

    let matches =
      run ~name:"matches" (fun s { Bs.Fetcher.fetch } ->
          let compute_matches
              ~repo_config:_
              ~tag_query
              ~out_of_change_applies
              ~applied_dirspaces
              ~diff
              ~repo_tree
              ~index:_
              () =
            let module Dc = Terrat_change_match3.Dirspace_config in
            let module Dir_set = CCSet.Make (CCString) in
            let open Irm in
            fetch Keys.synthesized_config
            >>= fun config ->
            fetch Keys.job
            >>= fun job ->
            let out_of_change_dirspace_configs =
              CCList.flat_map
                CCFun.(Terrat_change_match3.of_dirspace config %> CCOption.to_list)
                out_of_change_applies
            in
            let applied_dirspaces = Terrat_data.Dirspace_set.of_list applied_dirspaces in
            let all_matches =
              Terrat_change_match3.match_diff_list
                ~force_matches:out_of_change_dirspace_configs
                config
                diff
            in
            let dirs =
              all_matches
              |> CCList.flatten
              |> CCList.map
                   (fun
                     {
                       Terrat_change_match3.Dirspace_config.dirspace = { Terrat_dirspace.dir; _ };
                       _;
                     }
                   -> dir)
              |> Dir_set.of_list
            in
            let existing_dirs =
              Dir_set.filter
                (function
                  | "." ->
                      (* The root directory is always there, because...it
                     has to be. *)
                      true
                  | d ->
                      let d = d ^ "/" in
                      CCList.exists (CCString.prefix ~pre:d) repo_tree)
                dirs
            in
            (* Filter out any dirspaces that have been applied or refer to a
               directory that no longer exists. This could happen because of
               [out_of_change_applies], these may refer to directories that no
               longer exist, and thus we can't do much about them other than
               ignore them. *)
            let all_unapplied_matches =
              CCList.filter_map
                (fun layer ->
                  match
                    CCList.filter
                      (fun { Dc.dirspace = { Terrat_dirspace.dir; _ } as dirspace; _ } ->
                        (not (Terrat_data.Dirspace_set.mem dirspace applied_dirspaces))
                        && Dir_set.mem dir existing_dirs)
                      layer
                  with
                  | [] -> None
                  | layer -> Some layer)
                all_matches
            in
            let working_set_matches =
              match all_unapplied_matches with
              | layer :: _ -> (
                  match job.Tjc.Job.type_ with
                  | Tjc.Job.Type_.(Apply _ | Autoapply) ->
                      (* If it's an apply, we limit the working set to only
                         those that can be applied, based on stacks
                         configuration. *)
                      let module S = Terrat_base_repo_config_v1.Stacks.Stack in
                      let module Oc = Terrat_base_repo_config_v1.Stacks.Rules in
                      let flat_all_unapplied_matches = CCList.flatten all_unapplied_matches in
                      layer
                      |> CCList.filter (Terrat_change_match3.match_tag_query ~tag_query)
                      |> CCList.filter
                           (fun { Dc.stack_config = { S.rules = { Oc.apply_after; _ }; _ }; _ } ->
                             (* Filter this dirspace from the layer if its is meant to apply after
                                any other unapplied stack. *)
                             not
                               (CCList.exists
                                  (fun { Dc.stack_name; _ } ->
                                    CCList.mem ~eq:CCString.equal stack_name apply_after)
                                  flat_all_unapplied_matches))
                  | Tjc.Job.Type_.(Plan { tag_query = _; kind = Some (Tjc.Job.Type_.Kind.Drift _) })
                    ->
                      (* In the case that it is a plan for drift, then plan all
                         layers in one go.  We match against [all_matches]
                         because in the case of planning drift, we explicitly do
                         not care if any dirspace is considered applied.

                         Consider this scenario:

                         1. Drift run against [main], find no drift.

                         2. Nobody merges anything to [main].

                         3. Drift runs again.  It runs nothing.

                         The reason (3) happens is because we consider all
                         dirspaces in [main] as "applied" because their plans
                         came back with no changes.  This is what we would do in
                         a PR flow, but not what we want to do in a drift flow.
                         There could be drift between (1) and (2). So we ignore
                         anything considered "applied" in (3) and run everything
                         again.
                       *)
                      CCList.filter (Terrat_change_match3.match_tag_query ~tag_query)
                      @@ CCList.flatten all_matches
                  | Tjc.Job.Type_.Autoplan
                  | Tjc.Job.Type_.Plan _
                  | Tjc.Job.Type_.Gate_approval _
                  | Tjc.Job.Type_.Help
                  | Tjc.Job.Type_.Index
                  | Tjc.Job.Type_.Repo_config
                  | Tjc.Job.Type_.Unlock _
                  | Tjc.Job.Type_.Push ->
                      CCList.filter (Terrat_change_match3.match_tag_query ~tag_query) layer)
              | [] -> []
            in
            let all_tag_query_matches =
              CCList.map
                (CCList.filter (Terrat_change_match3.match_tag_query ~tag_query))
                all_matches
            in
            let unapplied_dirspaces =
              all_unapplied_matches
              |> CCList.flat_map (fun layer ->
                  CCList.map (fun { Dc.dirspace; _ } -> dirspace) layer)
              |> Terrat_data.Dirspace_set.of_list
            in
            let working_layer =
              all_matches
              |> CCList.filter (fun layer ->
                  CCList.exists
                    (fun { Dc.dirspace; _ } ->
                      Terrat_data.Dirspace_set.mem dirspace unapplied_dirspaces)
                    layer)
              |> CCList.head_opt
              |> CCOption.get_or ~default:[]
            in
            Abb.Future.return
              (Ok
                 ( working_set_matches,
                   all_matches,
                   all_tag_query_matches,
                   all_unapplied_matches,
                   working_layer ))
          in
          let go () =
            let module Tjc = Terrat_job_context in
            let open Irm in
            Fc.Result.all3
              (fetch Keys.repo_config)
              (fetch Keys.repo_tree_branch)
              (fetch Keys.repo_index_branch)
            >>= fun (_repo_config, repo_tree, _repo_index) ->
            fetch Keys.out_of_change_applies
            >>= fun out_of_change_applies ->
            fetch Keys.applied_dirspaces
            >>= fun applied_dirspaces ->
            fetch Keys.dest_branch_name
            >>= fun _dest_branch_name ->
            fetch Keys.branch_name
            >>= fun _branch_name ->
            fetch Keys.job
            >>= fun job ->
            let tag_query =
              let module T = Tjc.Job.Type_ in
              match job.Tjc.Job.type_ with
              | T.Apply { tag_query; kind = _; force = _ } | T.Plan { tag_query; kind = _ } ->
                  tag_query
              | T.Autoapply
              | T.Autoplan
              | T.Gate_approval _
              | T.Help
              | T.Index
              | T.Repo_config
              | T.Unlock _
              | T.Push -> Terrat_tag_query.any
            in
            fetch Keys.repo_index_branch
            >>= fun index ->
            fetch Keys.derived_repo_config
            >>= fun (_, repo_config) ->
            fetch Keys.changes
            >>= fun diff ->
            Abbs_time_it.run
              (fun t ->
                Logs.info (fun m -> m "%s : COMPUTE_APPROVED : time=%f" (Builder.log_id s) t))
              (fun () ->
                compute_matches
                  ~repo_config
                  ~tag_query
                  ~out_of_change_applies
                  ~applied_dirspaces
                  ~diff
                  ~repo_tree
                  ~index
                  ())
            >>= fun ( working_set_matches,
                      all_matches,
                      all_tag_query_matches,
                      all_unapplied_matches,
                      working_layer )
                  ->
            let module T = Tjc.Job.Type_ in
            match job.Tjc.Job.type_ with
            | T.Autoplan ->
                fetch Keys.is_draft_pr
                >>= fun is_draft_pr ->
                let working_set_matches =
                  CCList.filter
                    (fun {
                           Terrat_change_match3.Dirspace_config.when_modified =
                             {
                               Terrat_base_repo_config_v1.When_modified.autoplan;
                               autoplan_draft_pr;
                               _;
                             };
                           _;
                         }
                       -> autoplan && ((not is_draft_pr) || autoplan_draft_pr))
                    working_set_matches
                in
                let open Irm in
                fetch Keys.missing_autoplan_matches
                >>= fun missing_autoplan_matches ->
                missing_autoplan_matches' missing_autoplan_matches working_set_matches
                >>= fun working_set_matches ->
                Abb.Future.return
                  (Ok
                     {
                       Keys.Matches.working_set_matches;
                       all_matches;
                       all_tag_query_matches;
                       all_unapplied_matches;
                       working_layer;
                     })
            | T.Autoapply ->
                let module V1 = Terrat_base_repo_config_v1 in
                let module Tcm = Terrat_change_match3 in
                let module Dc = Tcm.Dirspace_config in
                let module S = V1.Stacks.Stack in
                let module Oc = V1.Stacks.Rules in
                let working_set_matches =
                  CCList.filter
                    (fun {
                           Dc.stack_config = { S.rules = { Oc.auto_apply; _ }; _ };
                           when_modified = { V1.When_modified.autoapply; _ };
                           _;
                         }
                       -> autoapply || CCOption.get_or ~default:false auto_apply)
                    working_set_matches
                in
                Abb.Future.return
                  (Ok
                     {
                       Keys.Matches.working_set_matches;
                       all_matches;
                       all_tag_query_matches;
                       all_unapplied_matches;
                       working_layer;
                     })
            | T.Apply _ | T.Plan _ ->
                Abb.Future.return
                  (Ok
                     {
                       Keys.Matches.working_set_matches;
                       all_matches;
                       all_tag_query_matches;
                       all_unapplied_matches;
                       working_layer;
                     })
            | T.Gate_approval _ | T.Help | T.Index | T.Repo_config | T.Unlock _ | T.Push ->
                assert false
          in
          let open Irm in
          let module M = Keys.Matches in
          go ()
          >>= fun ({
                     M.working_set_matches;
                     all_matches;
                     all_unapplied_matches;
                     all_tag_query_matches;
                     working_layer;
                   } as matches)
                ->
          let sum_layers = CCListLabels.fold_left ~init:0 ~f:(fun acc v -> acc + CCList.length v) in
          Logs.info (fun m ->
              m
                "%s : MATCHES : working_set_matches=%d"
                (Builder.log_id s)
                (CCList.length working_set_matches));
          Logs.info (fun m ->
              m "%s : MATCHES : all_matches=%d" (Builder.log_id s) (sum_layers all_matches));
          Logs.info (fun m ->
              m
                "%s : MATCHES : all_unapplied_matches=%d"
                (Builder.log_id s)
                (sum_layers all_unapplied_matches));
          Logs.info (fun m ->
              m
                "%s : MATCHES : all_tag_query_matches=%d"
                (Builder.log_id s)
                (sum_layers all_tag_query_matches));
          Logs.info (fun m ->
              m "%s : MATCHES : working_layer=%d" (Builder.log_id s) (CCList.length working_layer));
          Logs.info (fun m ->
              m "%s : MATCHES : num_layers=%d" (Builder.log_id s) (CCList.length all_matches));
          Abb.Future.return (Ok matches))

    let working_set_matches =
      run ~name:"working_set_matches" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.matches
          >>= fun { Keys.Matches.working_set_matches; _ } ->
          Abb.Future.return (Ok working_set_matches))

    let all_matches =
      run ~name:"all_matches" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.matches
          >>= fun { Keys.Matches.all_matches; _ } -> Abb.Future.return (Ok all_matches))

    let all_unapplied_matches =
      run ~name:"all_unapplied_matches" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.matches
          >>= fun { Keys.Matches.all_unapplied_matches; _ } ->
          Abb.Future.return (Ok all_unapplied_matches))

    let all_tag_query_matches =
      run ~name:"all_tag_query_matches" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.matches
          >>= fun { Keys.Matches.all_tag_query_matches; _ } ->
          Abb.Future.return (Ok all_tag_query_matches))

    let working_layer =
      run ~name:"working_layer" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.matches
          >>= fun { Keys.Matches.working_layer; _ } -> Abb.Future.return (Ok working_layer))

    let repo_tree_branch_wm_completed =
      run ~name:"repo_tree_branch_wm_completed" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.working_branch_ref
          >>= fun branch_ref ->
          fetch Keys.working_branch_name
          >>= fun branch ->
          Repo_tree_wm.run
            ~dest_branch_ref
            ~branch_ref
            ~branch
            ~name:"repo_tree_branch_wm"
            s
            fetcher)

    let built_repo_tree_branch =
      run ~name:"built_repo_tree_branch" (fun s { Bs.Fetcher.fetch } ->
          let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
          let open Irm in
          fetch Keys.account
          >>= fun account ->
          fetch Keys.branch_ref
          >>= fun branch_ref ->
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.repo_tree_branch_wm_completed
          >>= fun _ ->
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : QUERY_REPO_TREE : account = %s : branch_ref = %s : time=%f"
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
                    branch_ref))
          >>= function
          | Some tree -> Abb.Future.return (Ok (CCList.map (fun { I.path; _ } -> path) tree))
          | None ->
              Logs.err (fun m -> m "%s : EXPECTED_BUILT_REPO_TREE" (Builder.log_id s));
              Abb.Future.return (Error `Error))

    let built_repo_config_branch_wm_completed =
      run ~name:"built_repo_config_branch_wm_completed" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          (* Ensure the tree is accessible, building if necessary *)
          fetch Keys.repo_tree_branch
          >>= fun _ ->
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.working_branch_ref
          >>= fun branch_ref ->
          fetch Keys.repo_config_raw'
          >>= fun (_, repo_config_raw) ->
          let cache_ref = build_config_cache_ref branch_ref repo_config_raw in
          fetch Keys.working_branch_name
          >>= fun branch ->
          Build_config_wm.run
            ~cache_ref
            ~dest_branch_ref
            ~branch_ref
            ~branch
            ~name:"repo_build_config_branch_wm"
            s
            fetcher)

    let compute_data_cache_key tree =
      let sorted_tree = CCList.sort CCString.compare tree in
      let tree_str = CCString.concat "," sorted_tree in
      let sha256_hex = Sha256.(to_hex (string tree_str)) in
      (("cache2.repo_tree.data", sha256_hex), sha256_hex)

    let store_data_chunks ~chunk_size kv data_cache_key tree =
      let open Abb.Future.Infix_monad in
      let to_yojson = [%to_yojson: string list] in
      Terrat_kv_store.get ~key:data_cache_key kv
      >>= function
      | Ok (Some _) -> Abb.Future.return (Ok ())
      | Ok None ->
          let chunks = CCList.chunks chunk_size tree in
          Fc.List_result.iter
            ~f:(fun (idx, files) ->
              let json = to_yojson files in
              Fc.Result.ignore @@ Terrat_kv_store.set ~key:data_cache_key ~idx json kv
              >>= function
              | Ok _ as r -> Abb.Future.return r
              | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err))
            (CCList.combine (CCList.range' 0 (CCList.length chunks)) chunks)
      | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err)

    let store_ref_key kv cache_key sha256_hex =
      let open Abb.Future.Infix_monad in
      Fc.Result.ignore @@ Terrat_kv_store.set ~key:cache_key (`String sha256_hex) kv
      >>= function
      | Ok _ -> Abb.Future.return (Ok ())
      | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err)

    let load_data_chunks kv data_cache_key =
      let open Abb.Future.Infix_monad in
      Terrat_kv_store.iter ~prefix:true ~limit:100000 ~key:data_cache_key kv
      >>= function
      | Ok [] -> Abb.Future.return (Ok None)
      | Ok records ->
          Abb.Future.return
            (Ok
               (Some
                  (CCList.flat_map
                     (fun r ->
                       CCResult.get_or_failwith
                       @@ [%of_yojson: string list]
                       @@ Terrat_kv_store.Record.data r)
                     records)))
      | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err)

    let store_cache_repo_tree ~log_name ~chunk_size cache_key s tree =
      Builder.run_db s ~f:(fun db ->
          let open Abb.Future.Infix_monad in
          let data_cache_key, sha256_hex = compute_data_cache_key tree in
          Logs.info (fun m ->
              m
                "%s : %s : STORE : cache_key = %a : data_cache_key = %a : num_files=%d"
                (Builder.log_id s)
                log_name
                Cache.Key.pp
                cache_key
                Cache.Key.pp
                data_cache_key
                (CCList.length tree));
          let kv = { Terrat_kv_store.db; user_caps = [] } in
          store_data_chunks ~chunk_size kv data_cache_key tree
          >>= function
          | Ok () -> store_ref_key kv cache_key sha256_hex
          | Error _ as err -> Abb.Future.return err)

    let load_cache_repo_tree ~log_name cache_key s =
      let open Irm in
      Builder.run_db s ~f:(fun db ->
          let open Abb.Future.Infix_monad in
          let kv = { Terrat_kv_store.db; user_caps = [] } in
          Terrat_kv_store.get ~key:cache_key kv
          >>= function
          | Ok None -> Abb.Future.return (Ok None)
          | Ok (Some record) -> (
              match Terrat_kv_store.Record.data record with
              | `String sha256_hex ->
                  let data_cache_key = ("cache2.repo_tree.data", sha256_hex) in
                  load_data_chunks kv data_cache_key
              | _ -> Abb.Future.return (Ok None))
          | Error (#Terrat_kv_store.err as err) -> Abb.Future.return (Error err))
      >>= fun files ->
      Logs.info (fun m ->
          m
            "%s : %s : LOAD : cache_key = %a : num_files=%d"
            (Builder.log_id s)
            log_name
            Cache.Key.pp
            cache_key
            (CCOption.map_or ~default:0 CCList.length files));
      Abb.Future.return (Ok files)

    let repo_tree_branch =
      run ~name:"repo_tree_branch" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          let module V1 = Terrat_base_repo_config_v1 in
          fetch Keys.repo_config_raw'
          >>= fun (_, repo_config_raw) ->
          let tree_builder = V1.tree_builder repo_config_raw in
          if tree_builder.V1.Tree_builder.enabled then fetch Keys.built_repo_tree_branch
          else
            Fc.Result.all4
              (fetch Keys.client)
              (fetch Keys.account)
              (fetch Keys.repo)
              (fetch Keys.branch_ref)
            >>= fun (client, account, repo, branch_ref) ->
            let cache_key =
              ( "cache2.repo_tree",
                S.Api.Account.to_string account
                ^ "."
                ^ S.Api.Repo.to_string repo
                ^ "."
                ^ S.Api.Ref.to_string branch_ref )
            in
            time_it
              s
              (fun m log_id time ->
                m
                  "%s : LOAD_CACHE_REPO_TREE : repo = %s : branch = %s : time=%f"
                  log_id
                  (S.Api.Repo.to_string repo)
                  (S.Api.Ref.to_string branch_ref)
                  time)
              (fun () -> load_cache_repo_tree ~log_name:"CACHE_REPO_TREE" cache_key s)
            >>= function
            | Some repo_tree -> Abb.Future.return (Ok repo_tree)
            | None ->
                time_it
                  s
                  (fun m log_id time ->
                    m
                      "%s : FETCH_TREE : repo = %s : branch = %s : time=%f"
                      log_id
                      (S.Api.Repo.to_string repo)
                      (S.Api.Ref.to_string branch_ref)
                      time)
                  (fun () -> S.Api.fetch_tree ~request_id:(Builder.log_id s) client repo branch_ref)
                >>= fun repo_tree ->
                time_it
                  s
                  (fun m log_id time ->
                    m
                      "%s : STORE_REPO_TREE : repo = %s : branch = %s : time=%f"
                      log_id
                      (S.Api.Repo.to_string repo)
                      (S.Api.Ref.to_string branch_ref)
                      time)
                  (fun () ->
                    store_cache_repo_tree
                      ~log_name:"CACHE_REPO_TREE"
                      ~chunk_size:2000
                      cache_key
                      s
                      repo_tree)
                >>= fun () -> Abb.Future.return (Ok repo_tree))

    let repo_tree_dest_branch_wm_completed =
      run ~name:"repo_tree_dest_branch_wm_completed" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.dest_branch_name
          >>= fun branch ->
          Repo_tree_wm.run
            ~dest_branch_ref
            ~branch_ref:dest_branch_ref
            ~branch
            ~name:"repo_tree_dest_branch_wm"
            s
            fetcher)

    let built_repo_tree_dest_branch =
      run ~name:"built_repo_tree_dest_branch" (fun s { Bs.Fetcher.fetch } ->
          let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
          let open Irm in
          fetch Keys.account
          >>= fun account ->
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.repo_tree_dest_branch_wm_completed
          >>= fun _ ->
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : QUERY_REPO_TREE : account = %s : branch = %s : time=%f"
                    log_id
                    (S.Api.Account.to_string account)
                    (S.Api.Ref.to_string dest_branch_ref)
                    time)
                (fun () ->
                  S.Db.query_repo_tree ~request_id:(Builder.log_id s) db account dest_branch_ref))
          >>= function
          | Some tree -> Abb.Future.return (Ok (CCList.map (fun { I.path; _ } -> path) tree))
          | None ->
              Logs.err (fun m -> m "%s : EXPECTED_BUILT_REPO_TREE_DEST_BRANCH" (Builder.log_id s));
              Abb.Future.return (Error `Error))

    let built_repo_config_dest_branch_wm_completed =
      run
        ~name:"built_repo_config_dest_branch_wm_completed"
        (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          (* Ensure the tree is accessible, building if necessary *)
          fetch Keys.repo_tree_dest_branch
          >>= fun _ ->
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.repo_config_dest_branch_raw'
          >>= fun (_, repo_config_raw) ->
          let cache_ref = build_config_cache_ref dest_branch_ref repo_config_raw in
          fetch Keys.dest_branch_name
          >>= fun branch ->
          Build_config_wm.run
            ~cache_ref
            ~dest_branch_ref
            ~branch_ref:dest_branch_ref
            ~branch
            ~name:"repo_build_config_dest_branch_wm"
            s
            fetcher)

    let built_repo_config_dest_branch =
      run ~name:"built_repo_config_dest_branch" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          let module V1 = Terrat_base_repo_config_v1 in
          fetch Keys.account
          >>= fun account ->
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.repo_config_dest_branch_raw'
          >>= fun (_, repo_config_raw) ->
          let config_builder = V1.config_builder repo_config_raw in
          if config_builder.V1.Config_builder.enabled then
            let cache_ref = build_config_cache_ref dest_branch_ref repo_config_raw in
            fetch Keys.built_repo_config_dest_branch_wm_completed
            >>= fun _ ->
            Builder.run_db s ~f:(fun db ->
                time_it
                  s
                  (fun m log_id time ->
                    m
                      "%s : QUERY_REPO_CONFIG : account = %s : branch = %s : time=%f"
                      log_id
                      (S.Api.Account.to_string account)
                      (S.Api.Ref.to_string dest_branch_ref)
                      time)
                  (fun () ->
                    S.Db.query_repo_config_json ~request_id:(Builder.log_id s) db account cache_ref))
          else Abb.Future.return (Ok None))

    let repo_tree_dest_branch =
      run ~name:"repo_tree_dest_branch" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          let module V1 = Terrat_base_repo_config_v1 in
          fetch Keys.repo_config_dest_branch_raw'
          >>= fun (_, repo_config_raw) ->
          let tree_builder = V1.tree_builder repo_config_raw in
          if tree_builder.V1.Tree_builder.enabled then fetch Keys.built_repo_tree_dest_branch
          else
            Fc.Result.all4
              (fetch Keys.client)
              (fetch Keys.account)
              (fetch Keys.repo)
              (fetch Keys.dest_branch_ref)
            >>= fun (client, account, repo, dest_branch_ref) ->
            let cache_key =
              ( "cache2.repo_tree",
                S.Api.Account.to_string account
                ^ "."
                ^ S.Api.Repo.to_string repo
                ^ "."
                ^ S.Api.Ref.to_string dest_branch_ref )
            in
            time_it
              s
              (fun m log_id time ->
                m
                  "%s : LOAD_CACHE_REPO_TREE_DEST_BRANCH : repo = %s : branch = %s : time=%f"
                  log_id
                  (S.Api.Repo.to_string repo)
                  (S.Api.Ref.to_string dest_branch_ref)
                  time)
              (fun () -> load_cache_repo_tree ~log_name:"CACHE_REPO_TREE_DEST_BRANCH" cache_key s)
            >>= function
            | Some repo_tree -> Abb.Future.return (Ok repo_tree)
            | None ->
                time_it
                  s
                  (fun m log_id time ->
                    m
                      "%s : FETCH_TREE : repo = %s : branch = %s : time=%f"
                      log_id
                      (S.Api.Repo.to_string repo)
                      (S.Api.Ref.to_string dest_branch_ref)
                      time)
                  (fun () ->
                    S.Api.fetch_tree ~request_id:(Builder.log_id s) client repo dest_branch_ref)
                >>= fun repo_tree ->
                time_it
                  s
                  (fun m log_id time ->
                    m
                      "%s : STORE_REPO_TREE : repo = %s : branch = %s : time=%f"
                      log_id
                      (S.Api.Repo.to_string repo)
                      (S.Api.Ref.to_string dest_branch_ref)
                      time)
                  (fun () ->
                    store_cache_repo_tree
                      ~log_name:"CACHE_REPO_TREE_DEST_BRANCH"
                      ~chunk_size:2000
                      cache_key
                      s
                      repo_tree)
                >>= fun () -> Abb.Future.return (Ok repo_tree))

    let built_repo_config_branch =
      run ~name:"built_repo_config_branch" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          let module V1 = Terrat_base_repo_config_v1 in
          fetch Keys.account
          >>= fun account ->
          fetch Keys.branch_ref
          >>= fun branch_ref ->
          fetch Keys.repo_config_raw'
          >>= fun (_, repo_config_raw) ->
          let config_builder = V1.config_builder repo_config_raw in
          if config_builder.V1.Config_builder.enabled then
            let cache_ref = build_config_cache_ref branch_ref repo_config_raw in
            fetch Keys.built_repo_config_branch_wm_completed
            >>= fun _ ->
            Builder.run_db s ~f:(fun db ->
                time_it
                  s
                  (fun m log_id time ->
                    m
                      "%s : QUERY_REPO_CONFIG : account = %s : branch = %s : time=%f"
                      log_id
                      (S.Api.Account.to_string account)
                      (S.Api.Ref.to_string branch_ref)
                      time)
                  (fun () ->
                    S.Db.query_repo_config_json ~request_id:(Builder.log_id s) db account cache_ref))
          else Abb.Future.return (Ok None))

    let repo_config_system_defaults =
      run ~name:"repo_config_system_defaults" (fun s _ ->
          let module V1 = Terrat_base_repo_config_v1 in
          match Terrat_config.infracost @@ S.Api.Config.config @@ Builder.State.config s with
          | Some _ -> Abb.Future.return (Ok V1.default)
          | None ->
              let system_defaults =
                {
                  (V1.to_view V1.default) with
                  V1.View.cost_estimation = V1.Cost_estimation.make ~enabled:false ();
                }
              in
              Abb.Future.return (Ok (V1.of_view system_defaults)))

    let repo_config_raw' =
      run ~name:"repo_config_raw'" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Fc.Result.all4
            (fetch Keys.client)
            (fetch Keys.branch_ref)
            (fetch Keys.repo_config_system_defaults)
            (fetch Keys.repo)
          >>= fun (client, branch_ref, system_defaults, repo) ->
          time_it
            s
            (fun m log_id time ->
              m
                "%s : REPO_CONFIG : FETCH_WITH_PROVENANCE : repo = %s : branch = %s : time=%f"
                log_id
                (S.Api.Repo.to_string repo)
                (S.Api.Ref.to_string branch_ref)
                time)
            (fun () ->
              S.Repo_config.fetch_with_provenance
                ~system_defaults
                (Builder.log_id s)
                client
                repo
                branch_ref))

    let repo_config_raw =
      run ~name:"repo_config_raw" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Fc.Result.all5
            (fetch Keys.client)
            (fetch Keys.branch_ref)
            (fetch Keys.repo_config_system_defaults)
            (fetch Keys.repo)
            (fetch Keys.built_repo_config_branch)
          >>= fun (client, branch_ref, system_defaults, repo, built_config) ->
          time_it
            s
            (fun m log_id time ->
              m
                "%s : REPO_CONFIG : FETCH_WITH_PROVENANCE : repo = %s : branch = %s : time=%f"
                log_id
                (S.Api.Repo.to_string repo)
                (S.Api.Ref.to_string branch_ref)
                time)
            (fun () ->
              S.Repo_config.fetch_with_provenance
                ?built_config
                ~system_defaults
                (Builder.log_id s)
                client
                repo
                branch_ref))

    let derived_repo_config_empty_index =
      run ~name:"derived_repo_config_empty_index" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          Fc.Result.all2 (fetch Keys.repo_config_raw) (fetch Keys.repo_tree_branch)
          >>= fun ((provenance, repo_config_raw), repo_tree) ->
          fetch Keys.dest_branch_name
          >>= fun dest_branch_name ->
          fetch Keys.branch_name
          >>= fun branch_name ->
          fetch Keys.account
          >>= fun account ->
          fetch Keys.repo
          >>= fun repo ->
          fetch Keys.branch_ref
          >>= fun branch_ref ->
          let cache_key =
            ( "cache2.derived_repo_config_empty_index",
              repo_config_cache_key account repo branch_ref repo_config_raw )
          in
          Cache.derived_repo_config
            ~cache_key
            ~record_history:None
            ~dest_branch_name
            ~branch_name
            ~branch_ref
            ~index:Terrat_base_repo_config_v1.Index.empty
            ~repo_tree
            ~repo_config_raw
            s
            fetcher
          >>= fun repo_config -> Abb.Future.return (Ok (provenance, repo_config)))

    let derived_repo_config =
      run ~name:"derived_repo_config" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          Fc.Result.all2 (fetch Keys.repo_config_raw) (fetch Keys.repo_tree_branch)
          >>= fun ((provenance, repo_config_raw), repo_tree) ->
          fetch Keys.dest_branch_name
          >>= fun dest_branch_name ->
          fetch Keys.branch_name
          >>= fun branch_name ->
          fetch Keys.repo_index_branch
          >>= fun index ->
          fetch Keys.account
          >>= fun account ->
          fetch Keys.repo
          >>= fun repo ->
          fetch Keys.branch_ref
          >>= fun branch_ref ->
          let cache_key =
            ( "cache2.derived_repo_config",
              repo_config_cache_key account repo branch_ref repo_config_raw )
          in
          Cache.derived_repo_config
            ~cache_key
            ~record_history:(Some (account, repo, branch_name))
            ~dest_branch_name
            ~branch_name
            ~branch_ref
            ~index
            ~repo_tree
            ~repo_config_raw
            s
            fetcher
          >>= fun repo_config -> Abb.Future.return (Ok (provenance, repo_config)))

    let repo_config_with_provenance =
      run ~name:"repo_config_with_provenance" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.derived_repo_config
          >>= fun repo_config ->
          fetch Keys.synthesized_config >>= fun _ -> Abb.Future.return (Ok repo_config))

    let synthesized_config_empty_index =
      run ~name:"synthesized_config_empty_index" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.repo_tree_branch
          >>= fun _repo_tree ->
          fetch Keys.derived_repo_config_empty_index
          >>= fun (_provenance, repo_config) ->
          match
            Terrat_change_match3.synthesize_config
              ~index:Terrat_base_repo_config_v1.Index.empty
              repo_config
          with
          | Ok synthesized_config -> Abb.Future.return (Ok synthesized_config)
          | Error (#Terrat_change_match3.synthesize_config_err as err) ->
              Abb.Future.return (Error err))

    let synthesized_config =
      run ~name:"synthesized_config" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.repo_tree_branch
          >>= fun _repo_tree ->
          fetch Keys.repo_index_branch
          >>= fun index ->
          fetch Keys.derived_repo_config
          >>= fun (_provenance, repo_config) ->
          match Terrat_change_match3.synthesize_config ~index repo_config with
          | Ok synthesized_config -> Abb.Future.return (Ok synthesized_config)
          | Error (#Terrat_change_match3.synthesize_config_err as err) ->
              Abb.Future.return (Error err))

    let repo_config =
      run ~name:"repo_config" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.repo_config_with_provenance
          >>= fun (_, repo_config) -> Abb.Future.return (Ok repo_config))

    (* Repo config dest branch *)
    let repo_config_dest_branch_raw' =
      run ~name:"repo_config_dest_branch_raw'" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Fc.Result.all4
            (fetch Keys.client)
            (fetch Keys.dest_branch_ref)
            (fetch Keys.repo_config_system_defaults)
            (fetch Keys.repo)
          >>= fun (client, dest_branch_ref, system_defaults, repo) ->
          time_it
            s
            (fun m log_id time ->
              m
                "%s : REPO_CONFIG : FETCH_WITH_PROVENANCE : repo = %s : branch = %s : time=%f"
                log_id
                (S.Api.Repo.to_string repo)
                (S.Api.Ref.to_string dest_branch_ref)
                time)
            (fun () ->
              S.Repo_config.fetch_with_provenance
                ~system_defaults
                (Builder.log_id s)
                client
                repo
                dest_branch_ref))

    let repo_config_dest_branch_raw =
      run ~name:"repo_config_dest_branch_raw" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Fc.Result.all5
            (fetch Keys.client)
            (fetch Keys.dest_branch_ref)
            (fetch Keys.repo_config_system_defaults)
            (fetch Keys.repo)
            (fetch Keys.built_repo_config_dest_branch)
          >>= fun (client, dest_branch_ref, system_defaults, repo, built_config) ->
          time_it
            s
            (fun m log_id time ->
              m
                "%s : REPO_CONFIG : FETCH_WITH_PROVENANCE : repo = %s : branch = %s : time=%f"
                log_id
                (S.Api.Repo.to_string repo)
                (S.Api.Ref.to_string dest_branch_ref)
                time)
            (fun () ->
              S.Repo_config.fetch_with_provenance
                ?built_config
                ~system_defaults
                (Builder.log_id s)
                client
                repo
                dest_branch_ref))

    let derived_repo_config_dest_branch_empty_index =
      run
        ~name:"derived_repo_config_dest_branch_empty_index"
        (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          Fc.Result.all2 (fetch Keys.repo_config_dest_branch_raw) (fetch Keys.repo_tree_dest_branch)
          >>= fun ((provenance, repo_config_raw), repo_tree) ->
          fetch Keys.dest_branch_name
          >>= fun dest_branch_name ->
          fetch Keys.branch_name
          >>= fun branch_name ->
          fetch Keys.account
          >>= fun account ->
          fetch Keys.repo
          >>= fun repo ->
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          let cache_key =
            ( "cache2.repo_config_empty_index",
              repo_config_cache_key account repo dest_branch_ref repo_config_raw )
          in
          Cache.derived_repo_config
            ~cache_key
            ~record_history:None
            ~dest_branch_name
            ~branch_name
            ~branch_ref:dest_branch_ref
            ~index:Terrat_base_repo_config_v1.Index.empty
            ~repo_tree
            ~repo_config_raw
            s
            fetcher
          >>= fun repo_config -> Abb.Future.return (Ok (provenance, repo_config)))

    let derived_repo_config_dest_branch =
      run ~name:"derived_repo_config_dest_branch" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          Fc.Result.all2 (fetch Keys.repo_config_dest_branch_raw) (fetch Keys.repo_tree_dest_branch)
          >>= fun ((provenance, repo_config_raw), repo_tree) ->
          fetch Keys.dest_branch_name
          >>= fun dest_branch_name ->
          fetch Keys.branch_name
          >>= fun branch_name ->
          fetch Keys.repo_index_dest_branch
          >>= fun index ->
          fetch Keys.account
          >>= fun account ->
          fetch Keys.repo
          >>= fun repo ->
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          let cache_key =
            ( "cache2.repo_config_empty_index",
              repo_config_cache_key account repo dest_branch_ref repo_config_raw )
          in
          Cache.derived_repo_config
            ~cache_key
            ~record_history:(Some (account, repo, dest_branch_name))
            ~dest_branch_name
            ~branch_name
            ~branch_ref:dest_branch_ref
            ~index
            ~repo_tree
            ~repo_config_raw
            s
            fetcher
          >>= fun repo_config -> Abb.Future.return (Ok (provenance, repo_config)))

    let repo_config_dest_branch_with_provenance =
      run ~name:"repo_config_dest_branch_with_provenance" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.derived_repo_config_dest_branch
          >>= fun repo_config ->
          fetch Keys.synthesized_config_dest_branch >>= fun _ -> Abb.Future.return (Ok repo_config))

    let synthesized_config_dest_branch_empty_index =
      run ~name:"synthesized_config_dest_branch_empty_index" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.repo_tree_dest_branch
          >>= fun _repo_tree ->
          fetch Keys.derived_repo_config_dest_branch_empty_index
          >>= fun (_provenance, repo_config) ->
          match
            Terrat_change_match3.synthesize_config
              ~index:Terrat_base_repo_config_v1.Index.empty
              repo_config
          with
          | Ok synthesized_config -> Abb.Future.return (Ok synthesized_config)
          | Error (#Terrat_change_match3.synthesize_config_err as err) ->
              Abb.Future.return (Error err))

    let synthesized_config_dest_branch =
      run ~name:"synthesized_config_dest_branch" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.repo_tree_dest_branch
          >>= fun _repo_tree ->
          fetch Keys.repo_index_dest_branch
          >>= fun index ->
          fetch Keys.derived_repo_config_dest_branch
          >>= fun (_provenance, repo_config) ->
          match Terrat_change_match3.synthesize_config ~index repo_config with
          | Ok synthesized_config -> Abb.Future.return (Ok synthesized_config)
          | Error (#Terrat_change_match3.synthesize_config_err as err) ->
              Abb.Future.return (Error err))

    let repo_config_dest_branch =
      run ~name:"repo_config_dest_branch" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.repo_config_dest_branch_with_provenance
          >>= fun (_, repo_config) -> Abb.Future.return (Ok repo_config))

    let repo_index_branch_wm_completed =
      run ~name:"repo_index_branch_wm_completed" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.working_branch_ref
          >>= fun branch_ref ->
          fetch Keys.working_branch_name
          >>= fun branch ->
          Indexer_wm.run ~dest_branch_ref ~branch_ref ~branch ~name:"repo_index_branch_wm" s fetcher)

    let built_repo_index_branch =
      run ~name:"built_repo_index_branch" (fun s { Bs.Fetcher.fetch } ->
          (* TODO: Handle failed index *)
          let module I = Terrat_vcs_provider2.Index in
          let open Irm in
          fetch Keys.account
          >>= fun account ->
          fetch Keys.working_branch_ref
          >>= fun working_branch_ref ->
          fetch Keys.dest_branch_ref
          >>= fun _dest_branch_ref ->
          fetch Keys.branch_ref
          >>= fun _branch_ref ->
          Fc.Result.all3
            (fetch Keys.repo_config_raw)
            (fetch Keys.repo_tree_branch)
            (fetch Keys.synthesized_config_empty_index)
          >>= fun ((_, _repo_config_raw), repo_tree, config) ->
          Abbs_time_it.run
            (fun t -> Logs.info (fun m -> m "%s : MATCH_DIFF_LIST : time=%f" (Builder.log_id s) t))
            (fun () ->
              Abbs_future_combinators.to_result
              @@ Abb.Thread.run (fun () ->
                  CCList.filter
                    (Terrat_change_match3.match_tag_query ~tag_query:Terrat_tag_query.any)
                    (CCList.flatten
                       (Terrat_change_match3.match_diff_list
                          config
                          (CCList.map
                             (fun filename -> Terrat_change.Diff.(Change { filename }))
                             repo_tree)))))
          >>= function
          | [] -> Abb.Future.return (Ok Terrat_base_repo_config_v1.Index.empty)
          | _ -> (
              fetch Keys.repo_index_branch_wm_completed
              >>= fun _ ->
              Builder.run_db s ~f:(fun db ->
                  time_it
                    s
                    (fun m log_id time ->
                      m
                        "%s : QUERY_INDEX : account = %s ; branch = %s : time=%f"
                        log_id
                        (S.Api.Account.to_string account)
                        (S.Api.Ref.to_string working_branch_ref)
                        time)
                    (fun () ->
                      S.Db.query_index ~request_id:(Builder.log_id s) db account working_branch_ref))
              >>= function
              | Some { I.index; _ } -> Abb.Future.return (Ok index)
              | None ->
                  Abb.Future.return
                    (Error (`Msg_err "MISSING_REPO_CONFIG_INDEX_DESPITE_WM_COMPLETED"))))

    let repo_index_branch =
      run ~name:"repo_index_branch" (fun _s { Bs.Fetcher.fetch } ->
          let module V1 = Terrat_base_repo_config_v1 in
          let open Irm in
          fetch Keys.dest_branch_name
          >>= fun dest_branch_name ->
          fetch Keys.working_branch_name
          >>= fun working_branch_name ->
          if
            CCString.equal
              (S.Api.Ref.to_string dest_branch_name)
              (S.Api.Ref.to_string working_branch_name)
          then fetch Keys.repo_index_dest_branch
          else
            fetch Keys.repo_config_raw
            >>= fun (_, repo_config_raw) ->
            let indexer = V1.indexer repo_config_raw in
            if indexer.V1.Indexer.enabled then fetch Keys.built_repo_index_branch
            else Abb.Future.return (Ok V1.Index.empty))

    let repo_index_dest_branch_wm_completed =
      run ~name:"repo_index_dest_branch_wm_completed" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.dest_branch_name
          >>= fun branch ->
          Indexer_wm.run
            ~dest_branch_ref
            ~branch_ref:dest_branch_ref
            ~branch
            ~name:"repo_index_dest_branch_wm"
            s
            fetcher)

    let built_repo_index_dest_branch =
      run ~name:"built_repo_index_dest_branch" (fun s { Bs.Fetcher.fetch } ->
          (* TODO: Handle failed index *)
          let module I = Terrat_vcs_provider2.Index in
          let open Irm in
          fetch Keys.account
          >>= fun account ->
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          Fc.Result.all3
            (fetch Keys.repo_config_dest_branch_raw)
            (fetch Keys.repo_tree_dest_branch)
            (fetch Keys.synthesized_config_empty_index)
          >>= fun ((_, _repo_config_raw), repo_tree, config) ->
          Abbs_time_it.run
            (fun t -> Logs.info (fun m -> m "%s : MATCH_DIFF_LIST : time=%f" (Builder.log_id s) t))
            (fun () ->
              Abbs_future_combinators.to_result
              @@ Abb.Thread.run (fun () ->
                  CCList.filter
                    (Terrat_change_match3.match_tag_query ~tag_query:Terrat_tag_query.any)
                    (CCList.flatten
                       (Terrat_change_match3.match_diff_list
                          config
                          (CCList.map
                             (fun filename -> Terrat_change.Diff.(Change { filename }))
                             repo_tree)))))
          >>= function
          | [] -> Abb.Future.return (Ok Terrat_base_repo_config_v1.Index.empty)
          | _ -> (
              fetch Keys.repo_index_dest_branch_wm_completed
              >>= fun _ ->
              Builder.run_db s ~f:(fun db ->
                  time_it
                    s
                    (fun m log_id time ->
                      m
                        "%s : QUERY_INDEX : account = %s ; branch = %s : time=%f"
                        log_id
                        (S.Api.Account.to_string account)
                        (S.Api.Ref.to_string dest_branch_ref)
                        time)
                    (fun () ->
                      S.Db.query_index ~request_id:(Builder.log_id s) db account dest_branch_ref))
              >>= function
              | Some { I.index; _ } -> Abb.Future.return (Ok index)
              | None ->
                  Logs.err (fun m -> m "%s : EXPECTED_BUILT_INDEX_DEST_BRANCH" (Builder.log_id s));
                  Abb.Future.return (Error `Error)))

    let repo_index_dest_branch =
      run ~name:"repo_index_dest_branch" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          let module V1 = Terrat_base_repo_config_v1 in
          fetch Keys.repo_config_dest_branch_raw
          >>= fun (_, repo_config_raw) ->
          let indexer = V1.indexer repo_config_raw in
          if indexer.V1.Indexer.enabled then fetch Keys.built_repo_index_dest_branch
          else Abb.Future.return (Ok V1.Index.empty))

    (* Dirspaces *)
    let dest_branch_dirspaces =
      run ~name:"dest_branch_dirspaces" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Fc.Result.all3
            (fetch Keys.repo_config_dest_branch)
            (fetch Keys.synthesized_config_dest_branch)
            (fetch Keys.repo_tree_dest_branch)
          >>= fun (repo_config, config, repo_tree) ->
          Abbs_time_it.run
            (fun t -> Logs.info (fun m -> m "%s : MATCH_DIFF_LIST : time=%f" (Builder.log_id s) t))
            (fun () ->
              Abbs_future_combinators.to_result
              @@ Abb.Thread.run (fun () ->
                  CCList.flatten
                    (Terrat_change_match3.match_diff_list
                       config
                       (CCList.map
                          (fun filename -> Terrat_change.Diff.(Change { filename }))
                          repo_tree))))
          >>= fun matches ->
          let workflows = Terrat_base_repo_config_v1.workflows repo_config in
          let dirspaceflows =
            let module S = Terrat_base_repo_config_v1.Stacks in
            CCList.map
              (fun ({
                      Terrat_change_match3.Dirspace_config.dirspace;
                      stack_config = { S.Stack.variables; _ };
                      _;
                    } as change)
                 ->
                Terrat_change.Dirspaceflow.
                  {
                    dirspace;
                    workflow =
                      CCOption.map
                        (fun (idx, workflow) -> Workflow.{ idx; workflow })
                        (CCList.find_idx
                           (fun { Terrat_base_repo_config_v1.Workflows.Entry.tag_query; _ } ->
                             Terrat_change_match3.match_tag_query ~tag_query change)
                           workflows);
                    variables = Some variables;
                  })
              matches
          in
          Abb.Future.return
            (Ok
               (CCList.map
                  (fun Terrat_change.
                         {
                           Dirspaceflow.dirspace = { Dirspace.dir; workspace } as dirspace;
                           workflow;
                           variables;
                           _;
                         }
                     ->
                    let module Tcm = Terrat_change_match3 in
                    let module Wmd = Terrat_api_components.Work_manifest_dir in
                    let { Tcm.Dirspace_config.stack_name; _ } =
                      CCOption.get_exn_or "dirspaces" @@ Tcm.of_dirspace config dirspace
                    in
                    {
                      Wmd.path = dir;
                      workspace;
                      workflow =
                        CCOption.map
                          (fun Terrat_change.Dirspaceflow.Workflow.{ idx; _ } -> idx)
                          workflow;
                      rank = 0;
                      variables =
                        CCOption.map
                          (fun additional -> Wmd.Variables.make ~additional Json_schema.Empty_obj.t)
                          variables;
                      stack_name;
                    })
                  dirspaceflows)))

    let branch_dirspaces =
      run ~name:"branch_dirspaces" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Fc.Result.all3
            (fetch Keys.repo_config)
            (fetch Keys.synthesized_config)
            (fetch Keys.repo_tree_branch)
          >>= fun (repo_config, config, repo_tree) ->
          Abbs_time_it.run
            (fun t -> Logs.info (fun m -> m "%s : MATCH_DIFF_LIST : time=%f" (Builder.log_id s) t))
            (fun () ->
              Abbs_future_combinators.to_result
              @@ Abb.Thread.run (fun () ->
                  CCList.flatten
                    (Terrat_change_match3.match_diff_list
                       config
                       (CCList.map
                          (fun filename -> Terrat_change.Diff.(Change { filename }))
                          repo_tree))))
          >>= fun matches ->
          let workflows = Terrat_base_repo_config_v1.workflows repo_config in
          let dirspaceflows =
            let module S = Terrat_base_repo_config_v1.Stacks in
            CCList.map
              (fun ({
                      Terrat_change_match3.Dirspace_config.dirspace;
                      stack_config = { S.Stack.variables; _ };
                      _;
                    } as change)
                 ->
                Terrat_change.Dirspaceflow.
                  {
                    dirspace;
                    workflow =
                      CCOption.map
                        (fun (idx, workflow) -> Workflow.{ idx; workflow })
                        (CCList.find_idx
                           (fun { Terrat_base_repo_config_v1.Workflows.Entry.tag_query; _ } ->
                             Terrat_change_match3.match_tag_query ~tag_query change)
                           workflows);
                    variables = Some variables;
                  })
              matches
          in
          Abb.Future.return
            (Ok
               (CCList.map
                  (fun Terrat_change.
                         {
                           Dirspaceflow.dirspace = { Dirspace.dir; workspace } as dirspace;
                           workflow;
                           variables;
                           _;
                         }
                     ->
                    let module Tcm = Terrat_change_match3 in
                    let module Wmd = Terrat_api_components.Work_manifest_dir in
                    let { Tcm.Dirspace_config.stack_name; _ } =
                      CCOption.get_exn_or "dirspaces" @@ Tcm.of_dirspace config dirspace
                    in
                    {
                      Wmd.path = dir;
                      workspace;
                      workflow =
                        CCOption.map
                          (fun Terrat_change.Dirspaceflow.Workflow.{ idx; _ } -> idx)
                          workflow;
                      rank = 0;
                      variables =
                        CCOption.map
                          (fun additional -> Wmd.Variables.make ~additional Json_schema.Empty_obj.t)
                          variables;
                      stack_name;
                    })
                  dirspaceflows)))

    let compute_node =
      run ~name:"compute_node" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.compute_node_id
          >>= fun compute_node_id ->
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : COMPUTE_NODE : QUERY : id = %a : time=%f"
                    log_id
                    Uuidm.pp
                    compute_node_id
                    time)
                (fun () ->
                  S.Job_context.Compute_node.query
                    ~request_id:(Builder.log_id s)
                    ~compute_node_id
                    db))
          >>= function
          | Some compute_node -> Abb.Future.return (Ok compute_node)
          | None -> Abb.Future.return (Error (`Missing_dep_err "compute_node")))

    let access_control =
      run ~name:"access_control" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.user
          >>= function
          | Some user ->
              fetch Keys.repo_config
              >>= fun repo_config ->
              fetch Keys.client
              >>= fun client ->
              fetch Keys.repo
              >>= fun repo ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : FETCH_REMOTE_REPO : repo = %s : time=%f"
                    log_id
                    (S.Api.Repo.to_string repo)
                    time)
                (fun () -> S.Api.fetch_remote_repo ~request_id:(Builder.log_id s) client repo)
              >>= fun remote_repo ->
              let access_control = Terrat_base_repo_config_v1.access_control repo_config in
              Abb.Future.return
                (Ok
                   {
                     Keys.Access_control_engine.config = access_control;
                     ctx =
                       Keys.Access_control_engine.Access_control.Ctx.make
                         ~request_id:(Builder.log_id s)
                         ~client
                         ~config:(S.Api.Config.config (Builder.State.config s))
                         ~repo
                         ~user:(S.Api.User.to_string user)
                         ();
                     request_id = Builder.log_id s;
                     user = S.Api.User.to_string user;
                     policy_branch = S.Api.Remote_repo.default_branch remote_repo;
                   })
          | None -> assert false)

    let applied_dirspaces =
      run ~name:"applied_dirspaces" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.context
          >>= fun context ->
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : QUERY_APPLIED_DIRSPACES_FOR_CONTEXT : context = %a : time=%f"
                    log_id
                    Uuidm.pp
                    context.Tjc.Context.id
                    time)
                (fun () ->
                  S.Db.query_applied_dirspaces_for_context ~request_id:(Builder.log_id s) db context)))

    let check_account_tier =
      run ~name:"check_account_tier" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.user
          >>= function
          | Some user -> (
              fetch Keys.account
              >>= fun account ->
              Abbs_time_it.run
                (fun time ->
                  Logs.info (fun m ->
                      m
                        "%s : TIER_CHECK : account=%s : user=%s : time=%f"
                        (Builder.log_id s)
                        (S.Api.Account.Id.to_string @@ S.Api.Account.id account)
                        (S.Api.User.to_string user)
                        time))
                (fun () ->
                  Builder.run_db s ~f:(fun db ->
                      time_it
                        s
                        (fun m log_id time ->
                          m
                            "%s : TIER : CHECK : account = %s : time=%f"
                            log_id
                            (S.Api.Account.to_string account)
                            time)
                        (fun () -> S.Tier.check ~request_id:(Builder.log_id s) user account db)))
              >>= function
              | None -> Abb.Future.return (Ok ())
              | Some checks ->
                  fetch Keys.publish_comment
                  >>= fun publish_comment ->
                  publish_comment' publish_comment (Msg.Tier_check checks)
                  >>= fun () -> Abb.Future.return (Error `Noop))
          | None -> Abb.Future.return (Ok ()))

    let check_account_status_expired =
      run ~name:"check_account_status_expired" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.account
          >>= fun account ->
          Builder.run_db s ~f:(fun db ->
              S.Db.query_account_status ~request_id:(Builder.log_id s) db account)
          >>= function
          | `Active -> Abb.Future.return (Ok ())
          | `Trial_ending duration ->
              Logs.info (fun m ->
                  m
                    "EVALUATOR ; %s : TRIAL_ENDING : days=%d"
                    (Builder.log_id s)
                    (Duration.to_day duration));
              Abb.Future.return (Ok ())
          | `Expired | `Disabled ->
              Logs.info (fun m -> m "%s : ACCOUNT_EXPIRED" (Builder.log_id s));
              fetch Keys.publish_comment
              >>= fun publish_comment ->
              publish_comment' publish_comment Msg.Account_expired
              >>= fun () -> Abb.Future.return (Error `Noop))

    let publish_dest_branch_no_match =
      run ~name:"publish_dest_branch_no_match" (fun _s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.pull_request
          >>= fun pull_request ->
          fetch Keys.publish_comment
          >>= fun publish_comment ->
          publish_comment'
            publish_comment
            (Msg.Dest_branch_no_match
               (S.Api.Pull_request.set_checks () @@ S.Api.Pull_request.set_diff () pull_request)))

    let check_valid_destination_branch =
      run ~name:"check_valid_destination_branch" (fun s { Bs.Fetcher.fetch } ->
          (* Turn a glob into lua pattern for checking.  We escape all lua pattern
             special characters "().%+-?[^$", turn * into ".*", and wrap the whole thing
             in ^ and $ to make it a complete string match. *)
          let pattern_of_glob s =
            let len = CCString.length s in
            let b = Buffer.create len in
            Buffer.add_char b '^';
            for i = 0 to len - 1 do
              match CCString.get s i with
              | '*' -> Buffer.add_string b ".*"
              | ('(' | ')' | '.' | '%' | '+' | '-' | '?' | '[' | '^' | '$') as c ->
                  Buffer.add_char b '%';
                  Buffer.add_char b c
              | c -> Buffer.add_char b c
            done;
            Buffer.add_char b '$';
            let pattern = Buffer.contents b in
            CCOption.get_exn_or
              ("pattern_glob " ^ s ^ " " ^ pattern)
              (Lua_pattern.of_string pattern)
          in
          let rec eval_destination_branch_match dest_branch source_branch =
            let module Ds = Terrat_base_repo_config_v1.Destination_branches.Destination_branch in
            function
            | [] -> Error `No_matching_dest_branch
            | { Ds.branch; source_branches } :: valid_branches -> (
                let branch_glob = pattern_of_glob (CCString.lowercase_ascii branch) in
                match Lua_pattern.find dest_branch branch_glob with
                | Some _ ->
                    (* Partition the source branches into the not patterns and the
                   positive patterns. *)
                    let not_branches, branches =
                      CCList.partition (CCString.prefix ~pre:"!") source_branches
                    in
                    (* Remove the exclamation point from the beginning as it's not
                   actually part of the pattern. *)
                    let not_branch_globs =
                      CCList.map
                        CCFun.(CCString.drop 1 %> CCString.lowercase_ascii %> pattern_of_glob)
                        not_branches
                    in
                    let branch_globs =
                      let branches =
                        (* If there are not-branch globs, but branch globs is empty,
                       that implicitly means match anything on the positive branch.
                       If not-branches are empty then take what is in branches,
                       which could be nothing. *)
                        match (not_branch_globs, branches) with
                        | _ :: _, [] -> [ "*" ]
                        | _, branches -> branches
                      in
                      CCList.map CCFun.(CCString.lowercase_ascii %> pattern_of_glob) branches
                    in
                    (* The not patterns are an "and", as in success for the not patterns
                   is that all of them do not match.

                   The positive matches, however, are if any of them match. *)
                    if
                      CCList.for_all
                        CCFun.(Lua_pattern.find source_branch %> CCOption.is_none)
                        not_branch_globs
                      && CCList.exists
                           CCFun.(Lua_pattern.find source_branch %> CCOption.is_some)
                           branch_globs
                    then Ok ()
                    else Error `No_matching_source_branch
                | None ->
                    (* If the dest branch doesn't match this branch, then try the next *)
                    eval_destination_branch_match dest_branch source_branch valid_branches)
          in
          let module Rc = Terrat_base_repo_config_v1 in
          let module Ds = Rc.Destination_branches.Destination_branch in
          let open Irm in
          Fc.Result.all2 (fetch Keys.client) (fetch Keys.repo_config)
          >>= fun (client, repo_config) ->
          fetch Keys.repo
          >>= fun repo ->
          S.Api.fetch_remote_repo ~request_id:(Builder.log_id s) client repo
          >>= fun remote_repo ->
          let default_branch = S.Api.Remote_repo.default_branch remote_repo in
          fetch Keys.dest_branch_name
          >>= fun base_branch_name ->
          fetch Keys.branch_name
          >>= fun branch_name ->
          let valid_branches =
            match Rc.destination_branches repo_config with
            | [] -> [ Ds.make ~branch:(S.Api.Ref.to_string default_branch) () ]
            | ds -> ds
          in
          let dest_branch = CCString.lowercase_ascii (S.Api.Ref.to_string base_branch_name) in
          let source_branch = CCString.lowercase_ascii (S.Api.Ref.to_string branch_name) in
          match eval_destination_branch_match dest_branch source_branch valid_branches with
          | Ok () -> Abb.Future.return (Ok ())
          | Error `No_matching_dest_branch -> (
              fetch Keys.job
              >>= fun job ->
              let module T = Terrat_job_context.Job.Type_ in
              match job.Terrat_job_context.Job.type_ with
              | T.Autoplan | T.Autoapply ->
                  Logs.info (fun m ->
                      m
                        "%s : DEST_BRANCH_NOT_VALID : branch=%s"
                        (Builder.log_id s)
                        (S.Api.Ref.to_string base_branch_name));
                  Abb.Future.return (Error `Noop)
              | T.Plan _ | T.Apply _ ->
                  let open Irm in
                  Logs.info (fun m ->
                      m
                        "%s : DEST_BRANCH_NOT_VALID_BRANCH_EXPLICIT : branch=%s"
                        (Builder.log_id s)
                        (S.Api.Ref.to_string base_branch_name));
                  fetch Keys.publish_dest_branch_no_match
                  >>= fun () -> Abb.Future.return (Error `Error)
              | T.Gate_approval _ | T.Help | T.Index | T.Repo_config | T.Unlock _ | T.Push ->
                  assert false)
          | Error `No_matching_source_branch -> (
              fetch Keys.job
              >>= fun job ->
              let module T = Terrat_job_context.Job.Type_ in
              match job.Terrat_job_context.Job.type_ with
              | T.Autoplan | T.Autoapply ->
                  Logs.info (fun m ->
                      m
                        "%s : SOURCE_BRANCH_NOT_VALID : branch=%s"
                        (Builder.log_id s)
                        (S.Api.Ref.to_string branch_name));
                  Abb.Future.return (Error `Noop)
              | T.Plan _ | T.Apply _ ->
                  Logs.info (fun m ->
                      m
                        "%s : SOURCE_BRANCH_NOT_VALID_BRANCH_EXPLICIT : branch=%s"
                        (Builder.log_id s)
                        (S.Api.Ref.to_string branch_name));
                  fetch Keys.publish_dest_branch_no_match
                  >>= fun () -> Abb.Future.return (Error `Noop)
              | T.Gate_approval _ | T.Help | T.Index | T.Repo_config | T.Unlock _ | T.Push ->
                  assert false))

    let update_context_branch_hashes =
      run ~name:"update_context_branch_hashes" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          Fc.Result.all5
            (fetch Keys.repo)
            (fetch Keys.branch_name)
            (fetch Keys.branch_ref)
            (fetch Keys.dest_branch_name)
            (fetch Keys.dest_branch_ref)
          >>= fun (repo, branch_name, branch_ref, dest_branch_name, dest_branch_ref) ->
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : STORE_BRANCH_HASH : branch_name = %s : branch_ref = %s : time=%f"
                    log_id
                    (S.Api.Ref.to_string branch_name)
                    (S.Api.Ref.to_string branch_ref)
                    time)
                (fun () ->
                  S.Db.store_branch_hash
                    ~request_id:(Builder.log_id s)
                    ~branch_name
                    ~branch_ref
                    repo
                    db)
              >>= fun () ->
              time_it
                s
                (fun m log_id time ->
                  m
                    "%s : STORE_BRANCH_HASH : branch_name = %s : branch_ref = %s : time=%f"
                    log_id
                    (S.Api.Ref.to_string dest_branch_name)
                    (S.Api.Ref.to_string dest_branch_ref)
                    time)
                (fun () ->
                  S.Db.store_branch_hash
                    ~request_id:(Builder.log_id s)
                    ~branch_name:dest_branch_name
                    ~branch_ref:dest_branch_ref
                    repo
                    db)))

    let maybe_finalize_when_all_applied =
      let open Irm in
      fun s { Bs.Fetcher.fetch } ->
        fetch Keys.all_unapplied_matches
        >>= function
        | [] ->
            Logs.info (fun m -> m "%s : ALL_DIRSPACES_APPLIED" (Builder.log_id s));
            fetch Keys.finalize_unfinished_terrateam_checks
        | _ -> Abb.Future.return (Ok ())

    let run_plan =
      run ~name:"run_plan" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.working_branch_ref
          >>= fun branch_ref ->
          fetch Keys.working_branch_name
          >>= fun branch ->
          let open Abb.Future.Infix_monad in
          Tf_op_wm.Plan.run ~dest_branch_ref ~branch_ref ~branch ~name:"plan_wm" s fetcher
          >>= function
          | Ok _wms -> maybe_finalize_when_all_applied s fetcher
          | Error (#Str_template.err as err) ->
              let open Irm in
              fetch Keys.publish_comment
              >>= fun publish_comment -> publish_comment' publish_comment (Msg.Str_template_err err)
          | Error err -> Abb.Future.return (Error err))

    let run_apply =
      run ~name:"run_apply" (fun s ({ Bs.Fetcher.fetch } as fetcher) ->
          let open Irm in
          fetch Keys.dest_branch_ref
          >>= fun dest_branch_ref ->
          fetch Keys.working_branch_ref
          >>= fun branch_ref ->
          fetch Keys.working_branch_name
          >>= fun branch ->
          Tf_op_wm.Apply.run ~dest_branch_ref ~branch_ref ~branch ~name:"apply_wm" s fetcher
          >>= fun _wms -> maybe_finalize_when_all_applied s fetcher)

    let maybe_complete_job =
      run ~name:"maybe_complete_job" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.job
          >>= fun job ->
          (* Query from the database so we get the latest value and lock it *)
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m "%s : JOB : QUERY : job_id = %a : time=%f" log_id Uuidm.pp job.Tjc.Job.id time)
                (fun () ->
                  S.Job_context.Job.query ~request_id:(Builder.log_id s) ~job_id:job.Tjc.Job.id db))
          >>= function
          | Some { Tjc.Job.state = Tjc.Job.State.(Completed | Failed); _ } ->
              Logs.info (fun m ->
                  m "%s : JOB_COMPLETE : job_id= %a" (Builder.log_id s) Uuidm.pp job.Tjc.Job.id);
              Abb.Future.return (Error `Noop)
          | Some ({ Tjc.Job.state = Tjc.Job.State.Running; _ } as job) ->
              H.complete_job s job @@ fetch Keys.iter_job
          | None -> assert false)

    let maybe_complete_job_from_work_manifest_event =
      run ~name:"maybe_complete_job_from_work_manifest_event" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.work_manifest_event
          >>= function
          | Some event -> (
              let work_manifest =
                match event with
                | Keys.Work_manifest_event.(
                    ( Initiate { work_manifest; _ }
                    | Fail { work_manifest; _ }
                    | Result { work_manifest; _ } )) -> work_manifest
              in
              fetch Keys.work_manifest_event_job
              >>= function
              | None -> raise (Failure "nyi")
              | Some job ->
                  let log_id = Builder.mk_log_id ~request_id:(Builder.log_id s) job.Tjc.Job.id in
                  let context = job.Tjc.Job.context in
                  Logs.info (fun m ->
                      m
                        "%s : context_id=%a : log_id= %s : initiator=%s"
                        (Builder.log_id s)
                        Uuidm.pp
                        context.Tjc.Context.id
                        log_id
                        (CCOption.map_or ~default:"" S.Api.User.to_string job.Tjc.Job.initiator));
                  let s' =
                    s
                    |> Builder.State.orig_store
                    |> Keys.Key.add Keys.job job
                    |> Keys.Key.add Keys.context context
                    |> Keys.Key.add Keys.work_manifest_event None
                    |> Keys.Key.add Keys.user job.Tjc.Job.initiator
                    |> Tasks_base.forward_std_keys s
                    |> add_work_manifest_keys work_manifest
                    |> CCFun.flip Builder.State.set_orig_store s
                    |> Builder.State.set_log_id log_id
                  in
                  Builder.eval s' Keys.maybe_complete_job)
          | None -> assert false)

    let eval_compute_node_poll =
      let handle_sha_match s compute_node work_manifest offering =
        let module C = Tjc.Compute_node in
        let module Cw = Tjc.Compute_node_work in
        let module Offering = Terrat_api_components.Work_manifest_initiate in
        let module Wm = Terrat_work_manifest3 in
        let module Wmc = Terrat_api_components.Work_manifest in
        let module Wmd = Terrat_api_components.Work_manifest_done in
        let open Irm in
        (* If a work manifest response already exists for the compute node,
           then deliver it. *)
        Builder.run_db s ~f:(fun db ->
            time_it
              s
              (fun m log_id time ->
                m
                  "%s : COMPUTE_NODE : QUERY_WORK : compute_node_id = %a : time=%f"
                  log_id
                  Uuidm.pp
                  compute_node.C.id
                  time)
              (fun () ->
                S.Job_context.Compute_node.query_work
                  ~request_id:(Builder.log_id s)
                  ~compute_node_id:compute_node.C.id
                  db))
        >>= function
        | Some { Cw.work = wm_response; state = Cw.State.Created; _ } ->
            Abb.Future.return (Ok wm_response)
        | Some _ ->
            Builder.run_db s ~f:(fun db ->
                time_it
                  s
                  (fun m log_id time ->
                    m
                      "%s : COMPUTE_NODE : UPDATE_STATE : compute_node_id = %a : state = \
                       terminated : time=%f"
                      log_id
                      Uuidm.pp
                      compute_node.C.id
                      time)
                  (fun () ->
                    S.Job_context.Compute_node.update_state
                      ~request_id:(Builder.log_id s)
                      ~compute_node_id:compute_node.C.id
                      db
                      C.State.Terminated))
            >>= fun () -> Abb.Future.return (Ok (Wmc.Work_manifest_done { Wmd.type_ = `Done }))
        | None -> (
            match work_manifest with
            | { Wm.state = Wm.State.(Completed | Aborted); _ } ->
                Abb.Future.return (Ok (Wmc.Work_manifest_done { Wmd.type_ = `Done }))
            | work_manifest -> (
                let open Abb.Future.Infix_monad in
                let work_manifest_event =
                  Keys.Work_manifest_event.Initiate
                    { work_manifest; run_id = offering.Offering.run_id }
                in
                let s' =
                  s
                  |> Builder.State.orig_store
                  |> Keys.Key.add Keys.work_manifest_event (Some work_manifest_event)
                  |> Tasks_base.forward_std_keys s
                  |> CCFun.flip Builder.State.set_orig_store s
                in
                Builder.eval s' Keys.eval_work_manifest_event
                >>= function
                | Ok () | Error (`Suspend_eval _) -> (
                    let open Irm in
                    Builder.run_db s ~f:(fun db ->
                        time_it
                          s
                          (fun m log_id time ->
                            m
                              "%s : COMPUTE_NODE : QUERY_WORK : compute_node_id = %a : time=%f"
                              log_id
                              Uuidm.pp
                              compute_node.C.id
                              time)
                          (fun () ->
                            S.Job_context.Compute_node.query_work
                              ~request_id:(Builder.log_id s)
                              ~compute_node_id:compute_node.C.id
                              db))
                    >>= function
                    | Some { Cw.work = wm_response; _ } -> Abb.Future.return (Ok wm_response)
                    | None -> Abb.Future.return (Ok (Wmc.Work_manifest_done { Wmd.type_ = `Done })))
                | Error (#Builder.err as err) ->
                    (* If anything failed, be sure to return to the querying node to give up. *)
                    Logs.info (fun m -> m "%s : %a" (Builder.log_id s) Builder.pp_err err);
                    Abb.Future.return (Ok (Wmc.Work_manifest_done { Wmd.type_ = `Done }))))
      in
      let abort_work_manifest s db work_manifest_id run_id =
        let open Irm in
        time_it
          s
          (fun m log_id _time ->
            m
              "%s : WM : UPDATE_STATE : work_manifest_id = %a : run_id = %s : state = aborted"
              log_id
              Uuidm.pp
              work_manifest_id
              run_id)
          (fun () ->
            S.Work_manifest.update_run_id ~request_id:(Builder.log_id s) db work_manifest_id run_id
            >>= fun () ->
            S.Work_manifest.update_state
              ~request_id:(Builder.log_id s)
              db
              work_manifest_id
              Terrat_work_manifest3.State.Aborted)
      in
      let query_job_by_work_manifest s db work_manifest_id =
        time_it
          s
          (fun m log_id time ->
            m
              "%s : JOB : QUERY_BY_WORK_MANIFEST : work_manifest_id = %a : time=%f"
              log_id
              Uuidm.pp
              work_manifest_id
              time)
          (fun () ->
            S.Job_context.Job.query_by_work_manifest_id
              ~request_id:(Builder.log_id s)
              db
              ~work_manifest_id
              ())
      in
      let query_work_manifest s db work_manifest_id =
        time_it
          s
          (fun m log_id time ->
            m "%s : WORK_MANIFEST : QUERY : id = %a : time=%f" log_id Uuidm.pp work_manifest_id time)
          (fun () -> S.Work_manifest.query ~request_id:(Builder.log_id s) db work_manifest_id)
      in
      let handle_sha_mismatch s compute_node work_manifest_id offering =
        let module C = Tjc.Compute_node in
        let module Offering = Terrat_api_components.Work_manifest_initiate in
        let module Wmc = Terrat_api_components.Work_manifest in
        let module Wmd = Terrat_api_components.Work_manifest_done in
        let open Irm in
        (* We have received a poll from a compute node that has an
           offering that no longer matches anything we are looking for.

           We will kindly tell this compute node to exit, abort the
           work manifest, and then run another one to get the
           results we're actually interested in. *)
        Logs.info (fun m ->
            m
              "%s : COMPUTE_NODE_OFFERING_MISMATCH : compute_node_sha= %s : offering_sha= %s"
              (Builder.log_id s)
              compute_node.C.capabilities.C.Capabilities.sha
              offering.Offering.sha);
        Builder.run_db s ~f:(fun db ->
            abort_work_manifest s db work_manifest_id offering.Offering.run_id)
        >>= fun () ->
        Builder.run_db s ~f:(fun db -> query_job_by_work_manifest s db work_manifest_id)
        >>= function
        | Some job ->
            Builder.run_db s ~f:(fun db -> query_work_manifest s db work_manifest_id)
            >>= fun work_manifest ->
            let work_manifest = CCOption.get_exn_or "work_manifest" work_manifest in
            let context = job.Tjc.Job.context in
            let log_id = Builder.mk_log_id ~request_id:(Builder.log_id s) job.Tjc.Job.id in
            let s' =
              s
              |> Builder.State.orig_store
              |> Keys.Key.add Keys.job job
              |> Keys.Key.add Keys.context context
              |> Keys.Key.add Keys.user job.Tjc.Job.initiator
              |> Tasks_base.forward_std_keys s
              |> add_work_manifest_keys work_manifest
              |> CCFun.flip Builder.State.set_orig_store s
              |> Builder.State.set_log_id log_id
              |> Builder.State.set_tasks
                   (match context.Tjc.Context.scope with
                   | Tjc.Context.Scope.Pull_request _ -> Tasks_pr.tasks @@ Builder.State.tasks s
                   | Tjc.Context.Scope.Branch _ -> Tasks_branch.tasks @@ Builder.State.tasks s)
            in
            Logs.info (fun m ->
                m
                  "%s : context_id=%a : log_id= %s"
                  (Builder.log_id s)
                  Uuidm.pp
                  context.Tjc.Context.id
                  log_id);
            Fc.to_result @@ Fc.ignore @@ Builder.eval s' Keys.iter_job
            >>= fun () -> Abb.Future.return (Ok (Wmc.Work_manifest_done { Wmd.type_ = `Done }))
        | None ->
            Logs.err (fun m -> m "%s : JOB_NOT_FOUND" (Builder.log_id s));
            assert false
      in
      run ~name:"eval_compute_node_poll" (fun s { Bs.Fetcher.fetch } ->
          let module C = Tjc.Compute_node in
          let module Offering = Terrat_api_components.Work_manifest_initiate in
          let module Wm = Terrat_work_manifest3 in
          let module Wmc = Terrat_api_components.Work_manifest in
          let module Wmd = Terrat_api_components.Work_manifest_done in
          let open Irm in
          fetch Keys.compute_node
          >>= function
          | { C.state = C.State.Terminated; _ } ->
              Abb.Future.return (Ok (Wmc.Work_manifest_done { Wmd.type_ = `Done }))
          | compute_node -> (
              (* TODO: Decouple compute node id and work manifest id *)
              let work_manifest_id = compute_node.C.id in
              Builder.run_db s ~f:(fun db ->
                  time_it
                    s
                    (fun m log_id time ->
                      m
                        "%s : WORK_MANIFEST : QUERY : id = %a : time=%f"
                        log_id
                        Uuidm.pp
                        work_manifest_id
                        time)
                    (fun () ->
                      S.Work_manifest.query ~request_id:(Builder.log_id s) db work_manifest_id))
              >>= function
              | Some work_manifest ->
                  fetch Keys.compute_node_offering
                  >>= fun offering ->
                  (* Compare the sha that the runner is offering vs the sha that
                     the compute node is capable of operating against.

                     These should match, however it is possible they don't because:

                     1. There has been an update to this branch between evaluating
                        the job and running it.

                     2. This is a pull request and the destination branch has
                        been updated and this PR has not been rebased yet.  The
                        GitHub API always describes pull requests in terms of
                        the original commit they were created against and not
                        the latest commit of the base.  In this case, we will
                        ALWAYS make work manifests that reference the pull
                        requests base and not the actual base so we can't just
                        retry.

                     In case (1), we just want to fail this work manifest and
                     run another one, that will pick up the new references and
                     move on.

                     In case (2), however, we have to use this same work manifest.

                     We have two options of what we could do:

                     1. We could tell the runner to switch to the commit we
                        actually want to run against.

                     2. Determine if this is an operation against the
                        destination branch and validate it against the actual
                        destination branch ref and use it.

                     Despite (1) being the more correct answer, we cannot do it
                     it right now because it would require modifying the
                     protocol between the server and the runner and we aren't in
                     a position to change that right now, so we will do (2).

                     How do we determine if we can even apply situation (2)?
                     Again, to minimize changes to the code, and database right
                     now, we are going to use a heuristic.  In the work
                     manifest, if the base_ref and branch_ref are the same, we
                     will assume we are in (2) and run.
                   *)
                  if
                    compute_node.C.capabilities.C.Capabilities.sha = offering.Offering.sha
                    || CCString.equal work_manifest.Wm.base_ref work_manifest.Wm.branch_ref
                  then handle_sha_match s compute_node work_manifest offering
                  else handle_sha_mismatch s compute_node work_manifest_id offering
              | None ->
                  (* If anything failed, be sure to return to the querying node to give up. *)
                  Logs.info (fun m -> m "%s : UNKNOWN_WORK_MANIFEST" (Builder.log_id s));
                  Abb.Future.return (Ok (Wmc.Work_manifest_done { Wmd.type_ = `Done }))))

    let work_manifest_event_job =
      run ~name:"work_manifest_event_job" (fun s { Bs.Fetcher.fetch } ->
          let module Wm = Terrat_work_manifest3 in
          let open Irm in
          fetch Keys.work_manifest_event
          >>= function
          | Some event ->
              let work_manifest =
                match event with
                | Keys.Work_manifest_event.(
                    ( Initiate { work_manifest; _ }
                    | Fail { work_manifest; _ }
                    | Result { work_manifest; _ } )) -> work_manifest
              in
              Builder.run_db s ~f:(fun db ->
                  time_it
                    s
                    (fun m log_id time ->
                      m
                        "%s : JOB : QUERY_BY_WORK_MANIFEST : work_manifest_id = %a : time=%f"
                        log_id
                        Uuidm.pp
                        work_manifest.Wm.id
                        time)
                    (fun () ->
                      S.Job_context.Job.query_by_work_manifest_id
                        ~request_id:(Builder.log_id s)
                        db
                        ~work_manifest_id:work_manifest.Wm.id
                        ()))
          | None -> Abb.Future.return (Ok None))

    let eval_work_manifest_event =
      run ~name:"eval_work_manifest_event" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.work_manifest_event
          >>= function
          | Some event -> (
              let work_manifest, event_type =
                let module E = Keys.Work_manifest_event in
                match event with
                | E.Initiate { work_manifest; _ } -> (work_manifest, "INITIATE")
                | E.Fail { work_manifest; _ } -> (work_manifest, "FAIL")
                | E.Result { work_manifest; _ } -> (work_manifest, "RESULT")
              in
              fetch Keys.work_manifest_event_job
              >>= function
              | None -> raise (Failure "nyi")
              | Some { Tjc.Job.id; state = Tjc.Job.State.(Completed | Failed); _ } ->
                  Logs.info (fun m ->
                      m "%s : JOB_ALREADY_COMPLETED : job_id= %a" (Builder.log_id s) Uuidm.pp id);
                  Abb.Future.return (Error `Noop)
              | Some job ->
                  let log_id = Builder.mk_log_id ~request_id:(Builder.log_id s) job.Tjc.Job.id in
                  let context = job.Tjc.Job.context in
                  Logs.info (fun m ->
                      m
                        "%s : EVENT : WORK_MANIFEST : %s : context_id=%a : log_id= %s : \
                         initiator=%s"
                        (Builder.log_id s)
                        event_type
                        Uuidm.pp
                        context.Tjc.Context.id
                        log_id
                        (CCOption.map_or ~default:"" S.Api.User.to_string job.Tjc.Job.initiator));
                  let s' =
                    s
                    |> Builder.State.orig_store
                    |> Keys.Key.add Keys.job job
                    |> Keys.Key.add Keys.context context
                    |> Keys.Key.add Keys.work_manifest_event (Some event)
                    |> Keys.Key.add Keys.user job.Tjc.Job.initiator
                    |> Tasks_base.forward_std_keys s
                    |> add_work_manifest_keys work_manifest
                    |> CCFun.flip Builder.State.set_orig_store s
                    |> Builder.State.set_log_id log_id
                    |> Builder.State.set_tasks
                         (match context.Tjc.Context.scope with
                         | Tjc.Context.Scope.Pull_request _ ->
                             Tasks_pr.tasks @@ Builder.State.tasks s
                         | Tjc.Context.Scope.Branch _ -> Tasks_branch.tasks @@ Builder.State.tasks s)
                  in
                  Builder.eval s' Keys.iter_job)
          | None -> assert false)

    let iter_job =
      run ~name:"iter_job" (fun s { Bs.Fetcher.fetch } ->
          let maybe_publish_msg msg =
            let open Irm in
            fetch Keys.publish_comment
            >>= fun publish_comment -> publish_comment' publish_comment msg
          in
          let run =
            let open Irm in
            fetch Keys.repo_config_raw'
            >>= fun (_, repo_config) ->
            let module V1 = Terrat_base_repo_config_v1 in
            match V1.enabled repo_config with
            | true -> (
                fetch Keys.job
                >>= fun job ->
                match job.Tjc.Job.type_ with
                | Tjc.Job.Type_.Apply _ | Tjc.Job.Type_.Autoapply -> fetch Keys.run_apply
                | Tjc.Job.Type_.Autoplan | Tjc.Job.Type_.Plan _ ->
                    fetch Keys.run_plan
                    >>= fun () ->
                    let s' =
                      s
                      |> Builder.State.orig_store
                      |> Tasks_base.forward_std_keys s
                      |> CCFun.flip Builder.State.set_orig_store s
                    in
                    Builder.eval s' Keys.complete_no_change_dirspaces
                | Tjc.Job.Type_.Repo_config ->
                    H.complete_job s job @@ fetch Keys.publish_repo_config
                | Tjc.Job.Type_.Unlock _ -> H.complete_job s job @@ fetch Keys.publish_unlock
                | Tjc.Job.Type_.Index -> H.complete_job s job @@ fetch Keys.publish_index_complete
                | Tjc.Job.Type_.Help -> H.complete_job s job @@ fetch Keys.publish_help
                | Tjc.Job.Type_.Push -> fetch Keys.eval_push_event
                | Tjc.Job.Type_.Gate_approval _ ->
                    H.complete_job s job @@ fetch Keys.store_gate_approval)
            | false ->
                Logs.info (fun m -> m "%s : DISABLED" (Builder.log_id s));
                Abb.Future.return (Error `Noop)
          in
          let open Abb.Future.Infix_monad in
          run
          >>= function
          | Ok _ as r -> Abb.Future.return r
          | Error err ->
              let msg =
                match err with
                | #Terrat_base_repo_config_v1.of_version_1_err as err ->
                    Some (Msg.Repo_config_err err)
                | #Terrat_change_match3.synthesize_config_err as err ->
                    Some (Msg.Synthesize_config_err err)
                | `Json_decode_err (fname, err) | `Yaml_decode_err (fname, err) ->
                    Some (Msg.Repo_config_parse_failure (fname, err))
                | `Repo_config_schema_err (fname, err) ->
                    Some (Msg.Repo_config_schema_err (fname, err))
                | `Premium_feature_err feature -> Some (Msg.Premium_feature_err feature)
                | `Config_merge_err details -> Some (Msg.Repo_config_merge_err details)
                | #Terrat_vcs_provider2.fetch_repo_config_with_provenance_err ->
                    Some Msg.Unexpected_temporary_err
                | #Builder.err -> None
              in
              let open Irm in
              CCOption.map_or ~default:(Abb.Future.return (Ok ())) maybe_publish_msg msg
              >>= fun () -> Abb.Future.return (Error err))

    let eval_work_manifest_failure =
      let module Wm = Terrat_work_manifest3 in
      let query_work_manifest_by_run_id s run_id =
        Builder.run_db s ~f:(fun db ->
            time_it
              s
              (fun m log_id time ->
                m "%s : WORK_MANIFEST : QUERY_BY_RUN_ID : run_id = %s : time=%f" log_id run_id time)
              (fun () -> S.Work_manifest.query_by_run_id ~request_id:(Builder.log_id s) db run_id))
      in
      let query_job_by_work_manifest s work_manifest_id =
        Builder.run_db s ~f:(fun db ->
            time_it
              s
              (fun m log_id time ->
                m
                  "%s : JOB : QUERY_BY_WORK_MANIFEST : work_manifest_id = %a : time=%f"
                  log_id
                  Uuidm.pp
                  work_manifest_id
                  time)
              (fun () ->
                S.Job_context.Job.query_by_work_manifest_id
                  ~request_id:(Builder.log_id s)
                  db
                  ~work_manifest_id
                  ()))
      in
      let fail_running_job s work_manifest_id =
        let open Irm in
        query_job_by_work_manifest s work_manifest_id
        >>= function
        | Some { Tjc.Job.state = Tjc.Job.State.Running; id = job_id; _ } ->
            Builder.run_db s ~f:(fun db -> update_job_state_failed s job_id db)
        | Some _ | None -> Abb.Future.return (Ok ())
      in
      let bail_out_aborted s work_manifest_id run_id =
        let open Irm in
        Logs.info (fun m ->
            m
              "%s : WORK_MANIFEST_FAILURE_IGNORED_ABORTED : work_manifest_id = %a : run_id = %s"
              (Builder.log_id s)
              Uuidm.pp
              work_manifest_id
              run_id);
        fail_running_job s work_manifest_id >>= fun () -> Abb.Future.return (Error `Noop)
      in
      let dispatch_fail_event s work_manifest run_id =
        Logs.info (fun m ->
            m
              "%s : WORK_MANIFEST_FAILURE : work_manifest_id = %a"
              (Builder.log_id s)
              Uuidm.pp
              work_manifest.Wm.id);
        let s' =
          s
          |> Builder.State.orig_store
          |> Tasks_base.forward_std_keys s
          |> Keys.Key.add
               Keys.work_manifest_event
               (Some (Keys.Work_manifest_event.Fail { work_manifest; error = `Job_failed run_id }))
          |> CCFun.flip Builder.State.set_orig_store s
        in
        Builder.eval s' Keys.eval_work_manifest_event
      in
      run ~name:"eval_work_manifest_failure" (fun s { Bs.Fetcher.fetch } ->
          let open Irm in
          fetch Keys.run_id
          >>= fun run_id ->
          query_work_manifest_by_run_id s run_id
          >>= function
          | None ->
              Logs.info (fun m ->
                  m "%s : WORK_MANIFEST_NOT_FOUND : run_id = %s" (Builder.log_id s) run_id);
              Abb.Future.return (Error `Noop)
          | Some { Wm.state = Wm.State.Aborted; id = work_manifest_id; _ } ->
              bail_out_aborted s work_manifest_id run_id
          | Some work_manifest -> dispatch_fail_event s work_manifest run_id)

    let eval_push_event =
      run ~name:"eval_push_event" (fun s { Bs.Fetcher.fetch } ->
          let module V1 = Terrat_base_repo_config_v1 in
          let module D = Terrat_base_repo_config_v1.Drift in
          let open Irm in
          let run =
            fetch Keys.client
            >>= fun client ->
            fetch Keys.repo
            >>= fun repo ->
            time_it
              s
              (fun m log_id time ->
                m
                  "%s : FETCH_REMOTE_REPO : repo = %s : time=%f"
                  log_id
                  (S.Api.Repo.to_string repo)
                  time)
              (fun () -> S.Api.fetch_remote_repo ~request_id:(Builder.log_id s) client repo)
            >>= fun remote_repo ->
            let default_branch = S.Api.Remote_repo.default_branch remote_repo in
            fetch Keys.branch_name
            >>= fun branch_name ->
            if CCString.equal (S.Api.Ref.to_string branch_name) (S.Api.Ref.to_string default_branch)
            then (
              fetch Keys.repo_config
              >>= fun repo_config ->
              let ({ D.enabled; schedules } as drift) = V1.drift repo_config in
              CCList.iter
                (fun (name, { D.Schedule.tag_query; reconcile; schedule; window }) ->
                  Logs.info (fun m ->
                      m
                        "%s : DRIFT : UPDATE_SCHEDULE : name=%s : enabled=%B : repo=%s : \
                         schedule=%s : reconcile=%s : tag_query=%s : window=%s"
                        (Builder.log_id s)
                        name
                        enabled
                        (S.Api.Repo.to_string repo)
                        (D.Schedule.Sched.to_string schedule)
                        (Bool.to_string reconcile)
                        (Terrat_tag_query.to_string tag_query)
                        (CCOption.map_or
                           ~default:""
                           (fun { D.Window.start; end_ } -> start ^ "-" ^ end_)
                           window)))
                (Sln_map.String.to_list schedules);
              Builder.run_db s ~f:(fun db ->
                  time_it
                    s
                    (fun m log_id time ->
                      m
                        "%s : STORE_DRIFT_SCHEDULE : repo = %s : time=%f"
                        log_id
                        (S.Api.Repo.to_string repo)
                        time)
                    (fun () ->
                      S.Db.store_drift_schedule ~request_id:(Builder.log_id s) db repo drift)))
            else Abb.Future.return (Ok ())
          in
          fetch Keys.job >>= fun job -> H.complete_job s job @@ run)

    let run_missing_drift_schedules =
      run ~name:"run_missing_drift_schedules" (fun s { Bs.Fetcher.fetch = _ } ->
          let open Irm in
          Builder.run_db s ~f:(fun db ->
              time_it
                s
                (fun m log_id time ->
                  m "%s : QUERY_MISSING_DRIFT_SCHEDULED_RUNS : time=%f" log_id time)
                (fun () ->
                  S.Db.query_missing_drift_scheduled_runs ~request_id:(Builder.log_id s) db))
          >>= fun schedules ->
          let open Abb.Future.Infix_monad in
          Logs.info (fun m ->
              m
                "%s : MISSING_DRIFT_SCHEDULE_RUNS : count = %d"
                (Builder.log_id s)
                (CCList.length schedules));
          Abbs_future_combinators.List.iter
            ~f:(fun (name, account, repo, reconcile, tag_query, window) ->
              let run =
                let open Irm in
                Logs.info (fun m ->
                    m
                      "%s : DRIFT : RUN : name=%s : account=%s : repo=%s : reconcile=%s : \
                       tag_query=%s : window=%s"
                      (Builder.log_id s)
                      name
                      (S.Api.Account.to_string account)
                      (S.Api.Repo.to_string repo)
                      (Bool.to_string reconcile)
                      (Terrat_tag_query.to_string tag_query)
                      (CCOption.map_or
                         ~default:""
                         (fun (window_start, window_end) ->
                           Printf.sprintf "%s-%s" window_start window_end)
                         window));
                Builder.run_db s ~f:(fun db ->
                    S.Api.create_client
                      ~request_id:(Builder.log_id s)
                      (Builder.State.config s)
                      account
                      db)
                >>= fun client ->
                let open Abb.Future.Infix_monad in
                time_it
                  s
                  (fun m log_id time ->
                    m
                      "%s : FETCH_REMOTE_REPO : repo = %s : time=%f"
                      log_id
                      (S.Api.Repo.to_string repo)
                      time)
                  (fun () -> S.Api.fetch_remote_repo ~request_id:(Builder.log_id s) client repo)
                >>= function
                | Ok remote_repo when S.Api.Remote_repo.is_archived remote_repo ->
                    Logs.info (fun m ->
                        m
                          "%s : DRIFT : SKIP_ARCHIVED : repo = %s"
                          (Builder.log_id s)
                          (S.Api.Repo.to_string repo));
                    Abb.Future.return (Ok ())
                | Ok remote_repo -> (
                    let open Irm in
                    let default_branch = S.Api.Remote_repo.default_branch remote_repo in
                    Builder.run_db s ~f:(fun db ->
                        S.Job_context.create_or_get_for_branch
                          ~request_id:(Builder.log_id s)
                          db
                          account
                          repo
                          default_branch)
                    >>= fun context ->
                    Builder.run_db s ~f:(fun db ->
                        time_it
                          s
                          (fun m log_id time ->
                            m
                              "%s : JOB : CREATE : context_id = %a : time=%f"
                              log_id
                              Uuidm.pp
                              context.Tjc.Context.id
                              time)
                          (fun () ->
                            S.Job_context.Job.create
                              ~request_id:(Builder.log_id s)
                              db
                              (Tjc.Job.Type_.Plan
                                 { tag_query; kind = Some Tjc.Job.Type_.Kind.(Drift { reconcile }) })
                              context
                              None))
                    >>= fun job ->
                    let log_id = Builder.mk_log_id ~request_id:(Builder.log_id s) job.Tjc.Job.id in
                    Logs.info (fun m ->
                        m
                          "%s : target=%s : context_id=%a : log_id= %s : job_type=%a"
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
                      |> Keys.Key.add Keys.account account
                      |> Keys.Key.add Keys.repo repo
                      |> Keys.Key.add Keys.job job
                      |> CCFun.flip Builder.State.set_orig_store s
                      |> Builder.State.set_log_id log_id
                      |> Builder.State.set_tasks (Tasks_branch.tasks (Builder.State.tasks s))
                    in
                    let open Abb.Future.Infix_monad in
                    Builder.eval s' Keys.iter_job
                    >>= function
                    | (Ok _ | Error (`Noop | `Suspend_eval _)) as r -> Abb.Future.return r
                    | Error (#Builder.err as err) ->
                        Logs.err (fun m ->
                            m
                              "%s : RUN : DRIFT : account = %s : repo = %s : %a"
                              (Builder.log_id s)
                              (S.Api.Account.to_string account)
                              (S.Api.Repo.to_string repo)
                              Builder.pp_err
                              err);
                        Builder.run_db s ~f:(fun db ->
                            S.Db.store_drift_schedule
                              ~request_id:(Builder.log_id s)
                              db
                              repo
                              Terrat_base_repo_config_v1.
                                { Drift.enabled = false; schedules = Sln_map.String.empty })
                        >>= fun _ -> Abb.Future.return (Error err))
                | Error `Error ->
                    Logs.err (fun m ->
                        m
                          "%s : DRIFT : LOAD_REMOTE_REPO : account = %s : repo = %s"
                          (Builder.log_id s)
                          (S.Api.Account.to_string account)
                          (S.Api.Repo.to_string repo));
                    Builder.run_db s ~f:(fun db ->
                        S.Db.store_drift_schedule
                          ~request_id:(Builder.log_id s)
                          db
                          repo
                          Terrat_base_repo_config_v1.
                            { Drift.enabled = false; schedules = Sln_map.String.empty })
              in
              let open Abb.Future.Infix_monad in
              run
              >>= function
              | Ok () | Error `Noop | Error (`Suspend_eval _) -> Abb.Future.return ()
              | Error (#Builder.err as err) ->
                  Logs.info (fun m -> m "%s : %a" (Builder.log_id s) Builder.pp_err err);
                  Abb.Future.return ())
            schedules
          >>= fun () -> Abb.Future.return (Ok (CCList.length schedules)))

    let maybe_create_completed_apply_check =
      run ~name:"maybe_create_completed_apply_check" (fun s { Bs.Fetcher.fetch } ->
          let module R = Terrat_base_repo_config_v1 in
          let open Irm in
          fetch Keys.repo_config
          >>= fun repo_config ->
          let apply_requirements = R.apply_requirements repo_config in
          let create_completed_apply_check_on_noop =
            apply_requirements.R.Apply_requirements.create_completed_apply_check_on_noop
          in
          fetch Keys.all_matches
          >>= fun all_matches ->
          fetch Keys.all_unapplied_matches
          >>= fun all_unapplied_matches ->
          match (all_unapplied_matches, all_matches, create_completed_apply_check_on_noop) with
          | [], [], true | [], _, _ ->
              fetch Keys.account
              >>= fun account ->
              fetch Keys.repo
              >>= fun repo ->
              let checks =
                [
                  S.Commit_check.make_str
                    ~config:(Builder.State.config s)
                    ~description:"Completed"
                    ~status:Terrat_commit_check.Status.Completed
                    ~repo
                    ~account
                    "terrateam apply";
                ]
              in
              fetch Keys.branch_ref
              >>= fun branch_ref ->
              fetch Keys.create_commit_checks
              >>= fun create_commit_checks ->
              create_commit_checks' create_commit_checks branch_ref checks
          | _ -> Abb.Future.return (Ok ()))

    let finalize_unfinished_terrateam_checks =
      run ~name:"finalize_unfinished_terrateam_checks" (fun _s { Bs.Fetcher.fetch } ->
          let module Ch = Terrat_commit_check in
          let module Status = Ch.Status in
          let open Irm in
          fetch Keys.commit_checks
          >>= fun commit_checks ->
          let unfinished =
            CCList.filter_map
              (function
                | { Ch.status = Status.(Completed | Failed | Canceled); _ } -> None
                | { Ch.status = Status.(Queued | Running); title; _ } as c
                  when CCString.prefix ~pre:"terrateam plan" title
                       || CCString.prefix ~pre:"terrateam apply" title ->
                    Some { c with Ch.status = Status.Completed; description = "Completed" }
                | _ -> None)
              commit_checks
          in
          match unfinished with
          | [] -> Abb.Future.return (Ok ())
          | _ ->
              fetch Keys.branch_ref
              >>= fun branch_ref ->
              fetch Keys.create_commit_checks
              >>= fun create_commit_checks ->
              create_commit_checks' create_commit_checks branch_ref unfinished)

    let run_next_layer =
      run ~name:"run_next_layer" (fun s { Bs.Fetcher.fetch } ->
          let can_stack_auto_apply l =
            let module V1 = Terrat_base_repo_config_v1 in
            let module S = V1.Stacks in
            let module Dc = Terrat_change_match3.Dirspace_config in
            CCFun.tap (fun v ->
                Logs.info (fun m -> m "%s : CAN_STACK_AUTO_APPLY : %B" (Builder.log_id s) v))
            @@ CCList.exists
                 (fun { Dc.stack_config = { S.Stack.rules = { S.Rules.auto_apply; _ }; _ }; _ } ->
                   CCOption.get_or ~default:false auto_apply)
                 l
          in
          let module Wm = Terrat_work_manifest3 in
          let open Irm in
          fetch Keys.job
          >>= function
          | {
              Tjc.Job.type_ =
                Tjc.Job.Type_.Plan
                  { kind = Some (Tjc.Job.Type_.Kind.Drift { reconcile = true }) as kind; tag_query };
              context;
              initiator;
              _;
            } ->
              (* If we've just finished a drift plan with reconciliation on,
                 then time to run the apply *)
              Logs.info (fun m -> m "%s : DRIFT : RECONCILE" (Builder.log_id s));
              Builder.run_db s ~f:(fun db ->
                  S.Job_context.Job.create
                    ~request_id:(Builder.log_id s)
                    db
                    (Tjc.Job.Type_.Apply { tag_query; kind; force = false })
                    context
                    initiator)
              >>= fun job ->
              Logs.info (fun m ->
                  m "%s : CREATE_JOB : new_job= %a" (Builder.log_id s) Uuidm.pp job.Tjc.Job.id);
              let s' =
                s
                |> Builder.State.orig_store
                |> Keys.Key.add Keys.job job
                |> Keys.Key.add Keys.work_manifest_event None
                |> Builder.State.forward_store_value Keys.context s
                |> Tasks_base.forward_std_keys s
                |> CCFun.flip Builder.State.set_orig_store s
                |> Builder.State.set_log_id (Uuidm.to_string job.Tjc.Job.id)
              in
              Builder.eval s' Keys.run_apply
          | {
              Tjc.Job.type_ = Tjc.Job.Type_.Plan { kind = Some (Tjc.Job.Type_.Kind.Drift _); _ };
              _;
            } ->
              Logs.info (fun m -> m "%s : DRIFT_COMPLETE" (Builder.log_id s));
              Abb.Future.return (Ok ())
          | ( { Tjc.Job.type_ = Tjc.Job.Type_.Apply _; _ }
            | { Tjc.Job.type_ = Tjc.Job.Type_.Autoapply; _ }
            | { Tjc.Job.type_ = Tjc.Job.Type_.Autoplan; _ }
            | { Tjc.Job.type_ = Tjc.Job.Type_.Plan _; _ } ) as job -> (
              fetch Keys.all_unapplied_matches
              >>= function
              | [] ->
                  Logs.info (fun m -> m "%s : ALL_DIRSPACES_APPLIED" (Builder.log_id s));
                  fetch Keys.maybe_create_completed_apply_check
                  >>= fun () ->
                  fetch Keys.finalize_unfinished_terrateam_checks
                  >>= fun () -> fetch Keys.maybe_automerge
              | _ :: _ -> (
                  let module Dc = Terrat_change_match3.Dirspace_config in
                  fetch Keys.working_layer
                  >>= fun working_layer ->
                  let working_layer_dirspaces =
                    Terrat_data.Dirspace_set.of_list
                      (CCList.map (fun { Dc.dirspace; _ } -> dirspace) working_layer)
                  in
                  fetch Keys.work_manifests_for_job
                  >>= fun work_manifests ->
                  let changes =
                    Terrat_data.Dirspace_set.of_list
                    @@ CCList.flat_map
                         (fun { Wm.changes; _ } ->
                           CCList.map Terrat_change.Dirspaceflow.to_dirspace changes)
                         work_manifests
                  in
                  if Terrat_data.Dirspace_set.disjoint changes working_layer_dirspaces then (
                    (* If there is no overlap between the dirspaces that were
                       just ran as part of the work manifest and the remaining
                       unapplied dirspaces, that means we can safely try to run
                       the remaining layers.  If there is overlap then it means
                       we should not try to run another iteration because we'll
                       just operate on the same dirspaces we just did.  This
                       doesn't necessarily mean something went wrong.  For
                       example, planning a change means we'd come to this test
                       and if the plans had changes, they would be unapplied but
                       we would have just planned them so we would not want to
                       try to do another iteration of planning.  But we could
                       also get in to this situation through some unforseen
                       series of operations where we are not correctly
                       determining which changes have been applied (for example
                       things being merged in an order we did not anticipate) in
                       which case this also prevents us from getting into an
                       infinite loop. *)
                    let { Tjc.Job.context; initiator; type_; _ } = job in
                    let job_type =
                      match type_ with
                      | Tjc.Job.Type_.(
                          ( Plan { tag_query; kind = Some _ as kind }
                          | Apply { tag_query; kind = Some _ as kind; force = _ } )) ->
                          Tjc.Job.Type_.(Plan { tag_query; kind })
                      | Tjc.Job.Type_.Apply _
                      | Tjc.Job.Type_.Autoapply
                      | Tjc.Job.Type_.Autoplan
                      | Tjc.Job.Type_.Gate_approval _
                      | Tjc.Job.Type_.Help
                      | Tjc.Job.Type_.Index
                      | Tjc.Job.Type_.Plan _
                      | Tjc.Job.Type_.Push
                      | Tjc.Job.Type_.Repo_config
                      | Tjc.Job.Type_.Unlock _ -> Tjc.Job.Type_.Autoplan
                    in
                    Builder.run_db s ~f:(fun db ->
                        S.Job_context.Job.create
                          ~request_id:(Builder.log_id s)
                          db
                          job_type
                          context
                          initiator)
                    >>= fun job ->
                    Logs.info (fun m ->
                        m "%s : CREATE_JOB : new_job= %a" (Builder.log_id s) Uuidm.pp job.Tjc.Job.id);
                    let s' =
                      s
                      |> Builder.State.orig_store
                      |> Keys.Key.add Keys.job job
                      |> Keys.Key.add Keys.work_manifest_event None
                      |> Builder.State.forward_store_value Keys.context s
                      |> Tasks_base.forward_std_keys s
                      |> CCFun.flip Builder.State.set_orig_store s
                      |> Builder.State.set_log_id (Uuidm.to_string job.Tjc.Job.id)
                    in
                    Builder.eval s' Keys.run_plan)
                  else
                    match job with
                    | { Tjc.Job.type_ = Tjc.Job.Type_.Apply _; _ } -> Abb.Future.return (Ok ())
                    | { Tjc.Job.type_ = Tjc.Job.Type_.(Plan _ | Autoplan); _ }
                      when can_stack_auto_apply working_layer ->
                        let { Tjc.Job.context; initiator; _ } = job in
                        Builder.run_db s ~f:(fun db ->
                            S.Job_context.Job.create
                              ~request_id:(Builder.log_id s)
                              db
                              Tjc.Job.Type_.Autoapply
                              context
                              initiator)
                        >>= fun job ->
                        Logs.info (fun m ->
                            m
                              "%s : CREATE_JOB : new_job= %a"
                              (Builder.log_id s)
                              Uuidm.pp
                              job.Tjc.Job.id);
                        let s' =
                          s
                          |> Builder.State.orig_store
                          |> Keys.Key.add Keys.job job
                          |> Keys.Key.add Keys.work_manifest_event None
                          |> Builder.State.forward_store_value Keys.context s
                          |> Tasks_base.forward_std_keys s
                          |> CCFun.flip Builder.State.set_orig_store s
                          |> Builder.State.set_log_id (Uuidm.to_string job.Tjc.Job.id)
                        in
                        Builder.eval s' Keys.run_apply
                    | { Tjc.Job.type_ = Tjc.Job.Type_.(Plan _ | Autoplan); _ } ->
                        Abb.Future.return (Ok ())
                    | {
                     Tjc.Job.type_ =
                       Tjc.Job.Type_.(
                         Autoapply | Gate_approval _ | Help | Index | Repo_config | Unlock _ | Push);
                     _;
                    } -> Abb.Future.return (Ok ())))
          | { Tjc.Job.type_ = Tjc.Job.Type_.Gate_approval _; _ }
          | { Tjc.Job.type_ = Tjc.Job.Type_.Help; _ }
          | { Tjc.Job.type_ = Tjc.Job.Type_.Index; _ }
          | { Tjc.Job.type_ = Tjc.Job.Type_.Repo_config; _ }
          | { Tjc.Job.type_ = Tjc.Job.Type_.Unlock _; _ }
          | { Tjc.Job.type_ = Tjc.Job.Type_.Push; _ } -> Abb.Future.return (Ok ()))

    let complete_no_change_dirspaces =
      run ~name:"complete_no_change_dirspaces" (fun s { Bs.Fetcher.fetch } ->
          let module Wm = Terrat_work_manifest3 in
          let module Dc = Terrat_change_match3.Dirspace_config in
          let open Irm in
          fetch Keys.work_manifests_for_job
          >>= fun work_manifests ->
          let changes =
            CCList.flat_map
              (fun ({ Wm.changes; _ } as wm) ->
                CCList.map (fun c -> (wm, Terrat_change.Dirspaceflow.to_dirspace c)) changes)
              work_manifests
          in
          fetch Keys.all_unapplied_matches
          >>= fun all_unapplied_matches ->
          let unapplied_dirspaces =
            Terrat_data.Dirspace_set.of_list
              (CCList.map
                 (fun { Dc.dirspace; _ } -> dirspace)
                 (CCList.flatten all_unapplied_matches))
          in
          let applied_changes =
            CCList.filter
              (fun (_, dirspace) -> not (Terrat_data.Dirspace_set.mem dirspace unapplied_dirspaces))
              changes
          in
          fetch Keys.account
          >>= fun account ->
          fetch Keys.repo
          >>= fun repo ->
          let checks =
            CCList.map
              (fun (work_manifest, dirspace) ->
                S.Commit_check.make_dirspace
                  ~config:(Builder.State.config s)
                  ~description:"Completed"
                  ~run_type:(Wm.Step.to_string Wm.Step.Apply)
                  ~dirspace
                  ~status:Terrat_commit_check.Status.Completed
                  ~work_manifest
                  ~repo
                  ~account
                  ())
              applied_changes
          in
          fetch Keys.branch_ref
          >>= fun branch_ref ->
          fetch Keys.create_commit_checks
          >>= fun create_commit_checks ->
          create_commit_checks' create_commit_checks branch_ref checks)
  end

  let default_tasks () =
    let coerce = Builder.coerce_to_task in
    Hmap.empty
    |> Hmap.add (coerce Keys.access_control) Tasks.access_control
    |> Hmap.add (coerce Keys.account_status) Tasks.account_status
    |> Hmap.add (coerce Keys.all_matches) Tasks.all_matches
    |> Hmap.add (coerce Keys.all_tag_query_matches) Tasks.all_tag_query_matches
    |> Hmap.add (coerce Keys.all_unapplied_matches) Tasks.all_unapplied_matches
    |> Hmap.add (coerce Keys.applied_dirspaces) Tasks.applied_dirspaces
    |> Hmap.add (coerce Keys.branch_dirspaces) Tasks.branch_dirspaces
    |> Hmap.add (coerce Keys.built_repo_config_branch) Tasks.built_repo_config_branch
    |> Hmap.add
         (coerce Keys.built_repo_config_branch_wm_completed)
         Tasks.built_repo_config_branch_wm_completed
    |> Hmap.add (coerce Keys.built_repo_config_dest_branch) Tasks.built_repo_config_dest_branch
    |> Hmap.add
         (coerce Keys.built_repo_config_dest_branch_wm_completed)
         Tasks.built_repo_config_dest_branch_wm_completed
    |> Hmap.add (coerce Keys.built_repo_index_branch) Tasks.built_repo_index_branch
    |> Hmap.add (coerce Keys.built_repo_index_dest_branch) Tasks.built_repo_index_dest_branch
    |> Hmap.add (coerce Keys.built_repo_tree_branch) Tasks.built_repo_tree_branch
    |> Hmap.add (coerce Keys.built_repo_tree_dest_branch) Tasks.built_repo_tree_dest_branch
    |> Hmap.add (coerce Keys.check_account_status_expired) Tasks.check_account_status_expired
    |> Hmap.add (coerce Keys.check_account_tier) Tasks.check_account_tier
    |> Hmap.add (coerce Keys.check_valid_destination_branch) Tasks.check_valid_destination_branch
    |> Hmap.add (coerce Keys.client) Tasks.client
    |> Hmap.add (coerce Keys.commit_checks) Tasks.commit_checks
    |> Hmap.add (coerce Keys.complete_no_change_dirspaces) Tasks.complete_no_change_dirspaces
    |> Hmap.add (coerce Keys.compute_node) Tasks.compute_node
    |> Hmap.add (coerce Keys.context) Tasks.context
    |> Hmap.add (coerce Keys.context_id) Tasks.context_id
    |> Hmap.add (coerce Keys.default_branch_sha) Tasks.default_branch_sha
    |> Hmap.add (coerce Keys.derived_repo_config) Tasks.derived_repo_config
    |> Hmap.add (coerce Keys.derived_repo_config_dest_branch) Tasks.derived_repo_config_dest_branch
    |> Hmap.add
         (coerce Keys.derived_repo_config_dest_branch_empty_index)
         Tasks.derived_repo_config_dest_branch_empty_index
    |> Hmap.add (coerce Keys.derived_repo_config_empty_index) Tasks.derived_repo_config_empty_index
    |> Hmap.add (coerce Keys.dest_branch_dirspaces) Tasks.dest_branch_dirspaces
    |> Hmap.add (coerce Keys.eval_compute_node_poll) Tasks.eval_compute_node_poll
    |> Hmap.add (coerce Keys.eval_push_event) Tasks.eval_push_event
    |> Hmap.add (coerce Keys.eval_work_manifest_event) Tasks.eval_work_manifest_event
    |> Hmap.add (coerce Keys.eval_work_manifest_failure) Tasks.eval_work_manifest_failure
    |> Hmap.add
         (coerce Keys.finalize_unfinished_terrateam_checks)
         Tasks.finalize_unfinished_terrateam_checks
    |> Hmap.add (coerce Keys.initiator) Tasks.initiator
    |> Hmap.add (coerce Keys.iter_job) Tasks.iter_job
    |> Hmap.add (coerce Keys.matches) Tasks.matches
    |> Hmap.add (coerce Keys.maybe_complete_job) Tasks.maybe_complete_job
    |> Hmap.add
         (coerce Keys.maybe_complete_job_from_work_manifest_event)
         Tasks.maybe_complete_job_from_work_manifest_event
    |> Hmap.add
         (coerce Keys.maybe_create_completed_apply_check)
         Tasks.maybe_create_completed_apply_check
    |> Hmap.add (coerce Keys.publish_dest_branch_no_match) Tasks.publish_dest_branch_no_match
    |> Hmap.add (coerce Keys.repo_config) Tasks.repo_config
    |> Hmap.add (coerce Keys.repo_config_dest_branch) Tasks.repo_config_dest_branch
    |> Hmap.add (coerce Keys.repo_config_dest_branch_raw') Tasks.repo_config_dest_branch_raw'
    |> Hmap.add (coerce Keys.repo_config_dest_branch_raw) Tasks.repo_config_dest_branch_raw
    |> Hmap.add
         (coerce Keys.repo_config_dest_branch_with_provenance)
         Tasks.repo_config_dest_branch_with_provenance
    |> Hmap.add (coerce Keys.repo_config_raw') Tasks.repo_config_raw'
    |> Hmap.add (coerce Keys.repo_config_raw) Tasks.repo_config_raw
    |> Hmap.add (coerce Keys.repo_config_system_defaults) Tasks.repo_config_system_defaults
    |> Hmap.add (coerce Keys.repo_config_with_provenance) Tasks.repo_config_with_provenance
    |> Hmap.add (coerce Keys.repo_index_branch) Tasks.repo_index_branch
    |> Hmap.add (coerce Keys.repo_index_branch_wm_completed) Tasks.repo_index_branch_wm_completed
    |> Hmap.add (coerce Keys.repo_index_dest_branch) Tasks.repo_index_dest_branch
    |> Hmap.add
         (coerce Keys.repo_index_dest_branch_wm_completed)
         Tasks.repo_index_dest_branch_wm_completed
    |> Hmap.add (coerce Keys.repo_tree_branch) Tasks.repo_tree_branch
    |> Hmap.add (coerce Keys.repo_tree_branch_wm_completed) Tasks.repo_tree_branch_wm_completed
    |> Hmap.add (coerce Keys.repo_tree_dest_branch) Tasks.repo_tree_dest_branch
    |> Hmap.add
         (coerce Keys.repo_tree_dest_branch_wm_completed)
         Tasks.repo_tree_dest_branch_wm_completed
    |> Hmap.add (coerce Keys.run_apply) Tasks.run_apply
    |> Hmap.add (coerce Keys.run_missing_drift_schedules) Tasks.run_missing_drift_schedules
    |> Hmap.add (coerce Keys.run_next_layer) Tasks.run_next_layer
    |> Hmap.add (coerce Keys.run_plan) Tasks.run_plan
    |> Hmap.add (coerce Keys.synthesized_config) Tasks.synthesized_config
    |> Hmap.add (coerce Keys.synthesized_config_dest_branch) Tasks.synthesized_config_dest_branch
    |> Hmap.add
         (coerce Keys.synthesized_config_dest_branch_empty_index)
         Tasks.synthesized_config_dest_branch_empty_index
    |> Hmap.add (coerce Keys.synthesized_config_empty_index) Tasks.synthesized_config_empty_index
    |> Hmap.add (coerce Keys.target) Tasks.target
    |> Hmap.add (coerce Keys.update_context_branch_hashes) Tasks.update_context_branch_hashes
    |> Hmap.add (coerce Keys.user) Tasks.user
    |> Hmap.add (coerce Keys.work_manifest_event) Tasks.work_manifest_event
    |> Hmap.add (coerce Keys.work_manifest_event_job) Tasks.work_manifest_event_job
    |> Hmap.add (coerce Keys.work_manifests_for_job) Tasks.work_manifests_for_job
    |> Hmap.add (coerce Keys.working_layer) Tasks.working_layer
    |> Hmap.add (coerce Keys.working_set_matches) Tasks.working_set_matches
end
