module Msg = Terrat_vcs_provider2.Msg

let cache_capacity_mb_in_kb = ( * ) 1024
let kb_of_bytes b = CCInt.max 1 (b / 1024)
let result_version = 2
let protocol_version = 1

(* If the number of dirspaces are over this arbitrary threshold, do not create
   dirspace checks. *)
let dirspace_check_threshold = 50

module Metrics = struct
  module DefaultHistogram = Prmths.DefaultHistogram

  let namespace = "terrat"
  let subsystem = "evaluator"

  let op_on_account_disabled_total =
    let help = "Count of operations on a disabled account" in
    Prmths.Counter.v ~help ~namespace ~subsystem "op_on_account_disabled_total"

  let access_control_total =
    let help = "Count of access control calls" in
    let family =
      Prmths.Counter.v_labels
        ~label_names:[ "type"; "result" ]
        ~help
        ~namespace
        ~subsystem
        "access_control_total"
    in
    fun ~t ~r -> Prmths.Counter.labels family [ t; r ]

  let cache_dv_call_count =
    let help = "Count of cache calls by derived value with hit or miss or evict" in
    let family =
      Prmths.Counter.v_labels
        ~label_names:[ "v"; "type" ]
        ~help
        ~namespace
        ~subsystem
        "cache_dv_call_count"
    in
    fun ~v t -> Prmths.Counter.labels family [ v; t ]
end

module Comment = struct
  let to_yojson = CCFun.(Terrat_comment.to_string %> [%to_yojson: string])

  let of_yojson json =
    let open CCResult.Infix in
    [%of_yojson: string] json
    >>= fun comment -> CCResult.map_err Terrat_comment.show_err (Terrat_comment.parse comment)
end

module Tag_query = struct
  let to_yojson = CCFun.(Terrat_tag_query.to_string %> [%to_yojson: string])

  let of_yojson json =
    let open CCResult.Infix in
    [%of_yojson: string] json
    >>= fun tag_query ->
    CCResult.map_err Terrat_tag_query_ast.show_err (Terrat_tag_query.of_string tag_query)
end

module Make (S : Terrat_vcs_provider2.S) = struct
  let src = Logs.Src.create ("vcs_event_evaluator_" ^ S.name)

  module Logs = (val Logs.src_log src : Logs.LOG)

  (* Logging wrappers *)
  let log_time ?m request_id name t =
    Logs.info (fun m -> m "%s : %s : time=%f" request_id name t);
    match m with
    | Some m -> Metrics.DefaultHistogram.observe m t
    | None -> ()

  module Ctx = struct
    type 's t = {
      request_id : string;
      config : S.Api.Config.t;
      storage : 's;
    }

    let make ~request_id ~config ~storage () = { request_id; config; storage }
    let request_id t = t.request_id
    let config t = t.config
    let storage t = t.storage
    let set_request_id request_id t = { t with request_id }
    let set_storage storage t = { t with storage }
  end

  let create_client request_id config account =
    let open Abb.Future.Infix_monad in
    let terrat_config = S.Api.Config.config config in
    Abbs_time_it.run (log_time request_id "CREATE_CLIENT") (fun () ->
        Abbs_future_combinators.protect_finally
          ~setup:(fun () -> Terrat_storage.create terrat_config)
          (fun pool ->
            Pgsql_pool.with_conn pool ~f:(fun db ->
                S.Api.create_client ~request_id config account db))
          ~finally:Pgsql_pool.destroy)
    >>= function
    | Ok client -> Abb.Future.return (Ok client)
    | Error `Error -> Abb.Future.return (Error `Error)
    | Error (#Pgsql_pool.err as err) ->
        Logs.err (fun m -> m "%s : %a" request_id Pgsql_pool.pp_err err);
        Abb.Future.return (Error `Error)

  let store_account_repository request_id db account repo =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : STORE_ACCOUNT_REPOSITORY : account=%s : repo=%s : time=%f"
              request_id
              (S.Api.Account.to_string account)
              (S.Api.Repo.to_string repo)
              time))
      (fun () -> S.Db.store_account_repository ~request_id db account repo)

  let query_account_status request_id db account =
    Abbs_time_it.run (log_time request_id "QUERY_ACCOUNT_STATE") (fun () ->
        S.Db.query_account_status ~request_id db account)

  let store_pull_request request_id db pull_request =
    Abbs_time_it.run (log_time request_id "STORE_PULL_REQUEST") (fun () ->
        S.Db.store_pull_request ~request_id db pull_request)

  let fetch_branch_sha request_id client repo ref_ =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : FETCH_BRANCH_SHA : repo=%s : ref_=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              (S.Api.Ref.to_string ref_)
              time))
      (fun () -> S.Api.fetch_branch_sha ~request_id client repo ref_)

  let fetch_remote_repo request_id client repo =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : FETCH_REMOTE_REPO : repo=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              time))
      (fun () -> S.Api.fetch_remote_repo ~request_id client repo)

  let fetch_tree request_id client repo ref_ =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : FETCH_TREE : repo=%s : ref=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              (S.Api.Ref.to_string ref_)
              time))
      (fun () -> S.Api.fetch_tree ~request_id client repo ref_)

  let query_index request_id db account ref_ =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m "%s : QUERY_INDEX : ref=%s : time=%f" request_id (S.Api.Ref.to_string ref_) time))
      (fun () -> S.Db.query_index ~request_id db account ref_)

  let store_index request_id db work_manifest_id index =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m "%s : STORE_INDEX : id=%a : time=%f" request_id Uuidm.pp work_manifest_id time))
      (fun () -> S.Db.store_index ~request_id db work_manifest_id index)

  let store_index_result request_id db work_manifest_id result =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m "%s : STORE_INDEX_RESULT : id=%a : time=%f" request_id Uuidm.pp work_manifest_id time))
      (fun () -> S.Db.store_index_result ~request_id db work_manifest_id result)

  let query_repo_config_json request_id db account ref_ =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : QUERY_REPO_CONFIG : account=%s : ref=%s : time=%f"
              request_id
              (S.Api.Account.to_string account)
              (S.Api.Ref.to_string ref_)
              time))
      (fun () -> S.Db.query_repo_config_json ~request_id db account ref_)

  let query_repo_tree request_id db account ref_ base_ref =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : QUERY_REPO_TREE : account=%s : base_ref=%s : ref=%s : time=%f"
              request_id
              (S.Api.Account.to_string account)
              (CCOption.map_or ~default:"" S.Api.Ref.to_string base_ref)
              (S.Api.Ref.to_string ref_)
              time))
      (fun () -> S.Db.query_repo_tree ~request_id ?base_ref db account ref_)

  let store_repo_config_json request_id db account ref_ repo_config =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : STORE_REPO_CONFIG : account=%s : ref=%s : time=%f"
              request_id
              (S.Api.Account.to_string account)
              (S.Api.Ref.to_string ref_)
              time))
      (fun () -> S.Db.store_repo_config_json ~request_id db account ref_ repo_config)

  let store_repo_tree request_id db account ref_ files =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : STORE_REPO_TREE : account=%s : ref=%s : time=%f"
              request_id
              (S.Api.Account.to_string account)
              (S.Api.Ref.to_string ref_)
              time))
      (fun () -> S.Db.store_repo_tree ~request_id db account ref_ files)

  let cleanup_repo_configs request_id db =
    Abbs_time_it.run
      (fun time -> Logs.info (fun m -> m "%s : CLEANUP_REPO_CONFIGS : time=%f" request_id time))
      (fun () -> S.Db.cleanup_repo_configs ~request_id db)

  let publish_msg request_id client user pull_request msg =
    Abbs_time_it.run
      (fun time -> Logs.info (fun m -> m "%s : PUBLISH_MSG : time=%f" request_id time))
      (fun () -> S.Comment.publish_comment ~request_id client user pull_request msg)

  let fetch_pull_request request_id account client repo pull_request_id =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : FETCH_PULL_REQUEST : repo=%s : pull_request_id=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              (S.Api.Pull_request.Id.to_string pull_request_id)
              time))
      (fun () -> S.Api.fetch_pull_request ~request_id account client repo pull_request_id)

  let react_to_comment request_id client pull_request comment_id =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : REACT_TO_COMMENT : repo=%s : comment_id=%d : time=%f"
              request_id
              (S.Api.Repo.to_string @@ Terrat_pull_request.repo pull_request)
              comment_id
              time))
      (fun () -> S.Api.react_to_comment ~request_id client pull_request comment_id)

  let query_next_pending_work_manifest request_id db =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m -> m "%s : QUERY_NEXT_PENDING_WORK_MANIFEST : time=%f" request_id time))
      (fun () -> S.Db.query_next_pending_work_manifest ~request_id db)

  let run_work_manifest request_id config client work_manifest =
    let module Wm = Terrat_work_manifest3 in
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : RUN_WORK_MANIFEST : id=%a : time=%f"
              request_id
              Uuidm.pp
              work_manifest.Wm.id
              time))
      (fun () -> S.Work_manifest.run ~request_id config client work_manifest)

  let store_flow_state request_id db work_manifest_id state =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m "%s : STORE_FLOW_STATE : id=%a : time=%f" request_id Uuidm.pp work_manifest_id time))
      (fun () -> S.Db.store_flow_state ~request_id db work_manifest_id state)

  let query_flow_state request_id db work_manifest_id =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m "%s : QUERY_FLOW_STATE : id=%a : time=%f" request_id Uuidm.pp work_manifest_id time))
      (fun () -> S.Db.query_flow_state ~request_id db work_manifest_id)

  let delete_flow_state request_id db work_manifest_id =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m "%s : DELETE_FLOW_STATE : id=%a : time=%f" request_id Uuidm.pp work_manifest_id time))
      (fun () -> S.Db.delete_flow_state ~request_id db work_manifest_id)

  let cleanup_flow_states request_id db =
    Abbs_time_it.run
      (fun time -> Logs.info (fun m -> m "%s : CLEANUP_FLOW_STATE : time=%f" request_id time))
      (fun () -> S.Db.cleanup_flow_states ~request_id db)

  let create_work_manifest request_id db work_manifest =
    Abbs_time_it.run
      (fun time -> Logs.info (fun m -> m "%s : CREATE_WORK_MANIFEST : time=%f" request_id time))
      (fun () -> S.Work_manifest.create ~request_id db work_manifest)

  let update_work_manifest_state request_id db work_manifest_id state =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : UPDATE_WORK_MANIFEST_STATE : id=%a : state=%s : time=%f"
              request_id
              Uuidm.pp
              work_manifest_id
              (Terrat_work_manifest3.State.to_string state)
              time))
      (fun () -> S.Work_manifest.update_state ~request_id db work_manifest_id state)

  let update_work_manifest_run_id request_id db work_manifest_id run_id =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : UPDATE_WORK_MANIFEST_RUN_ID : id=%a : run_id=%s : time=%f"
              request_id
              Uuidm.pp
              work_manifest_id
              run_id
              time))
      (fun () -> S.Work_manifest.update_run_id ~request_id db work_manifest_id run_id)

  let update_work_manifest_changes request_id db work_manifest_id changes =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : UPDATE_WORK_MANIFEST_CHANGES : id=%a : time=%f"
              request_id
              Uuidm.pp
              work_manifest_id
              time))
      (fun () -> S.Work_manifest.update_changes ~request_id db work_manifest_id changes)

  let update_work_manifest_denied_dirspaces request_id db work_manifest_id denied_dirspaces =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : UPDATE_WORK_MANIFEST_DENIED_DIRSPACES : id=%a : time=%f"
              request_id
              Uuidm.pp
              work_manifest_id
              time))
      (fun () ->
        S.Work_manifest.update_denied_dirspaces ~request_id db work_manifest_id denied_dirspaces)

  let update_work_manifest_steps request_id db work_manifest_id steps =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : UPDATE_WORK_MANIFEST_STEPS : id=%a : time=%f"
              request_id
              Uuidm.pp
              work_manifest_id
              time))
      (fun () -> S.Work_manifest.update_steps ~request_id db work_manifest_id steps)

  let query_work_manifest request_id db work_manifest_id =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m "%s : QUERY_WORK_MANIFEST : id=%a : time=%f" request_id Uuidm.pp work_manifest_id time))
      (fun () -> S.Work_manifest.query ~request_id db work_manifest_id)

  let create_commit_checks request_id client repo ref_ checks =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : CREATE_COMMIT_CHECKS : repo=%s : num=%d : ref=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              (CCList.length checks)
              (S.Api.Ref.to_string ref_)
              time))
      (fun () -> S.Api.create_commit_checks ~request_id client repo ref_ checks)

  let fetch_commit_checks request_id client repo ref_ =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : FETCH_COMMIT_CHECKS : repo=%s : ref=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              (S.Api.Ref.to_string ref_)
              time))
      (fun () -> S.Api.fetch_commit_checks ~request_id client repo ref_)

  let unlock request_id db repo unlock_id =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : UNLOCK : repo=%s : unlock_id=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              (S.Unlock_id.to_string unlock_id)
              time))
      (fun () -> S.Db.unlock ~request_id db repo unlock_id)

  let query_pull_request_out_of_change_applies request_id db pull_request =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : QUERY_PULL_REQUEST_OUT_OF_CHANGE_APPLIES : pull_number=%s : time=%f"
              request_id
              (S.Api.Pull_request.Id.to_string (S.Api.Pull_request.id pull_request))
              time))
      (fun () -> S.Db.query_pull_request_out_of_change_applies ~request_id db pull_request)

  let query_applied_dirspaces request_id db pull_request =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : QUERY_APPLIED_DIRSPACES : repo=%s : pull_number=%s : time=%f"
              request_id
              (S.Api.Repo.to_string @@ S.Api.Pull_request.repo pull_request)
              (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
              time))
      (fun () -> S.Db.query_applied_dirspaces ~request_id db pull_request)

  let query_dirspaces_without_valid_plans ~base_ref ~branch_ref request_id db pull_request dirspaces
      =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : QUERY_DIRSPACES_WITHOUT_VALID_PLANS : pull_number=%s : time=%f"
              request_id
              (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
              time))
      (fun () ->
        S.Db.query_dirspaces_without_valid_plans
          ~request_id
          ~base_ref
          ~branch_ref
          db
          pull_request
          dirspaces)

  let store_dirspaceflows ~base_ref ~branch_ref request_id db repo dirspaceflows =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : STORE_DIRSPACEFLOWS : repo=%s : base_ref=%s : branch_ref=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              (S.Api.Ref.to_string base_ref)
              (S.Api.Ref.to_string branch_ref)
              time))
      (fun () -> S.Db.store_dirspaceflows ~request_id ~base_ref ~branch_ref db repo dirspaceflows)

  let query_plan request_id db work_manifest_id dirspace =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : QUERY_PLAN : id=%a : dir=%s : workspace=%s : time=%f"
              request_id
              Uuidm.pp
              work_manifest_id
              dirspace.Terrat_dirspace.dir
              dirspace.Terrat_dirspace.workspace
              time))
      (fun () -> S.Db.query_plan ~request_id db work_manifest_id dirspace)

  let cleanup_plans request_id db = S.Db.cleanup_plans ~request_id db

  let store_plan request_id db work_manifest_id dirspace data has_changes =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : STORE_PLAN : id=%a : dir=%s : workspace=%s : time=%f"
              request_id
              Uuidm.pp
              work_manifest_id
              dirspace.Terrat_dirspace.dir
              dirspace.Terrat_dirspace.workspace
              time))
      (fun () -> S.Db.store_plan ~request_id db work_manifest_id dirspace data has_changes)

  let store_tf_operation_result request_id db work_manifest_id result =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : STORE_TF_OPERATION_RESULT : id=%a : time=%f"
              request_id
              Uuidm.pp
              work_manifest_id
              time))
      (fun () -> S.Db.store_tf_operation_result ~request_id db work_manifest_id result)

  let store_tf_operation_result2 request_id db work_manifest_id result =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : STORE_TF_OPERATION_RESULT2 : id=%a : time=%f"
              request_id
              Uuidm.pp
              work_manifest_id
              time))
      (fun () -> S.Db.store_tf_operation_result2 ~request_id db work_manifest_id result)

  let query_conflicting_work_manifests_in_repo request_id db pull_request dirspaces op =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m "%s : QUERY_CONFLICTING_WORK_MANIFESTS_IN_REPO : time=%f" request_id time))
      (fun () ->
        S.Db.query_conflicting_work_manifests_in_repo ~request_id db pull_request dirspaces op)

  let eval_apply_requirements request_id config user client repo_config pull_request matches =
    Abbs_time_it.run
      (fun time -> Logs.info (fun m -> m "%s : EVAL_APPLY_REQUIREMENTS : time=%f" request_id time))
      (fun () ->
        S.Apply_requirements.eval ~request_id config user client repo_config pull_request matches)

  let query_dirspaces_owned_by_other_pull_requests request_id db pull_request dirspaces =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m "%s : QUERY_DIRSPACES_OWNED_BY_OTHER_PULL_REQUESTS : time=%f" request_id time))
      (fun () ->
        S.Db.query_dirspaces_owned_by_other_pull_requests ~request_id db pull_request dirspaces)

  let merge_pull_request ?retain_pr_title request_id client pull_request merge_strategy =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : MERGE_PULL_REQUEST : METHOD %s : time=%f"
              request_id
              (Terrat_base_repo_config_v1.Automerge.Merge_strategy.to_string merge_strategy)
              time))
      (fun () ->
        S.Api.merge_pull_request ~request_id ?retain_pr_title client pull_request merge_strategy)

  let delete_branch request_id client repo branch =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : DELETE_BRANCH : repo=%s : branch=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              branch
              time))
      (fun () -> S.Api.delete_branch ~request_id client repo branch)

  let store_drift_schedule request_id db repo drift =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : STORE_DRIFT_SCHEDULE : repo=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              time))
      (fun () -> S.Db.store_drift_schedule ~request_id db repo drift)

  let query_missing_drift_scheduled_runs request_id db =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m -> m "%s : QUERY_MISSING_DRIFT_SCHEDULED_RUNS : time=%f" request_id time))
      (fun () -> S.Db.query_missing_drift_scheduled_runs ~request_id db)

  let fetch_repo_config_with_provenance ?built_config ~system_defaults request_id client repo ref_ =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : FETCH_REPO_CONFIG_WITH_PROVENANCE : repo=%s : ref=%s : time=%f"
              request_id
              (S.Api.Repo.to_string repo)
              (S.Api.Ref.to_string ref_)
              time))
      (fun () ->
        S.Repo_config.fetch_with_provenance
          ?built_config
          ~system_defaults
          request_id
          client
          repo
          ref_)

  let store_gate_approval ~request_id ~token ~approver pull_request db =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : STORE_GATE_APPROVAL : token=%s : approver=%s : pull_number = %s : time=%f"
              request_id
              token
              approver
              (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
              time))
      (fun () -> S.Gate.add_approval ~request_id ~token ~approver pull_request db)

  let eval_gate ~request_id client dirspaces pull_request db =
    Abbs_time_it.run
      (fun time ->
        Logs.info (fun m ->
            m
              "%s : EVAL_GATE : pull_number = %s : time=%f"
              request_id
              (S.Api.Pull_request.Id.to_string @@ S.Api.Pull_request.id pull_request)
              time))
      (fun () -> S.Gate.eval ~request_id client dirspaces pull_request db)

  module Repo_config = struct
    type fetch_err = Terrat_vcs_provider2.fetch_repo_config_with_provenance_err [@@deriving show]

    let fetch_with_provenance ?built_config ~system_defaults request_id _config client repo ref_ =
      fetch_repo_config_with_provenance ?built_config ~system_defaults request_id client repo ref_

    let fetch ?built_config ~system_defaults request_id config client repo ref_ =
      let open Abbs_future_combinators.Infix_result_monad in
      fetch_with_provenance ?built_config ~system_defaults request_id config client repo ref_
      >>= fun (_, repo_config) -> Abb.Future.return (Ok repo_config)
  end

  module Event = struct
    type t =
      | Pull_request_open of {
          account : S.Api.Account.t;
          user : S.Api.User.t;
          repo : S.Api.Repo.t;
          pull_request_id : S.Api.Pull_request.Id.t;
        }
      | Pull_request_close of {
          account : S.Api.Account.t;
          user : S.Api.User.t;
          repo : S.Api.Repo.t;
          pull_request_id : S.Api.Pull_request.Id.t;
        }
      | Pull_request_sync of {
          account : S.Api.Account.t;
          user : S.Api.User.t;
          repo : S.Api.Repo.t;
          pull_request_id : S.Api.Pull_request.Id.t;
        }
      | Pull_request_ready_for_review of {
          account : S.Api.Account.t;
          user : S.Api.User.t;
          repo : S.Api.Repo.t;
          pull_request_id : S.Api.Pull_request.Id.t;
        }
      | Pull_request_comment of {
          account : S.Api.Account.t;
          comment : Terrat_comment.t; [@to_yojson Comment.to_yojson] [@of_yojson Comment.of_yojson]
          repo : S.Api.Repo.t;
          pull_request_id : S.Api.Pull_request.Id.t;
          comment_id : int;
          user : S.Api.User.t;
        }
      | Push of {
          account : S.Api.Account.t;
          user : S.Api.User.t;
          repo : S.Api.Repo.t;
          branch : S.Api.Ref.t;
        }
      | Run_scheduled_drift
      | Run_drift of {
          account : S.Api.Account.t;
          name : string;
          reconcile : bool option; [@default None]
          repo : S.Api.Repo.t;
          tag_query :
            (Terrat_tag_query.t[@to_yojson Tag_query.to_yojson] [@of_yojson Tag_query.of_yojson])
            option;
              [@default None]
        }
    [@@deriving yojson]

    let account = function
      | Pull_request_open { account; _ }
      | Pull_request_close { account; _ }
      | Pull_request_sync { account; _ }
      | Pull_request_ready_for_review { account; _ }
      | Pull_request_comment { account; _ }
      | Push { account; _ }
      | Run_drift { account; _ } -> account
      | Run_scheduled_drift -> assert false

    let user = function
      | Pull_request_open { user; _ }
      | Pull_request_close { user; _ }
      | Pull_request_sync { user; _ }
      | Pull_request_ready_for_review { user; _ }
      | Pull_request_comment { user; _ }
      | Push { user; _ } -> user
      | Run_scheduled_drift | Run_drift _ -> assert false

    let initiator = function
      | Pull_request_open { user; _ }
      | Pull_request_close { user; _ }
      | Pull_request_sync { user; _ }
      | Pull_request_ready_for_review { user; _ }
      | Pull_request_comment { user; _ }
      | Push { user; _ } -> Terrat_work_manifest3.Initiator.User (S.Api.User.to_string user)
      | Run_scheduled_drift | Run_drift _ -> Terrat_work_manifest3.Initiator.System

    let repo = function
      | Pull_request_open { repo; _ }
      | Pull_request_close { repo; _ }
      | Pull_request_sync { repo; _ }
      | Pull_request_ready_for_review { repo; _ }
      | Pull_request_comment { repo; _ }
      | Push { repo; _ }
      | Run_drift { repo; _ } -> repo
      | Run_scheduled_drift -> assert false

    let pull_request_id_safe = function
      | Pull_request_open { pull_request_id; _ }
      | Pull_request_close { pull_request_id; _ }
      | Pull_request_sync { pull_request_id; _ }
      | Pull_request_ready_for_review { pull_request_id; _ }
      | Pull_request_comment { pull_request_id; _ } -> Some pull_request_id
      | Push _ | Run_scheduled_drift | Run_drift _ -> None

    let pull_request_id event =
      match pull_request_id_safe event with
      | Some pull_request_id -> pull_request_id
      | None -> assert false

    let unlock_ids = function
      | Pull_request_comment { comment = Terrat_comment.Unlock ids; _ } ->
          CCList.sort_uniq ~cmp:CCString.compare ids
      | Pull_request_open _
      | Pull_request_close _
      | Pull_request_sync _
      | Pull_request_ready_for_review _
      | Pull_request_comment _
      | Push _
      | Run_scheduled_drift
      | Run_drift _ -> assert false

    let trigger_type = function
      | Pull_request_open _
      | Pull_request_sync _
      | Pull_request_ready_for_review _
      | Pull_request_close _ -> `Auto
      | Pull_request_comment _ -> `Manual
      | Push _ | Run_scheduled_drift | Run_drift _ -> assert false

    let gate_approval_tokens = function
      | Pull_request_comment { comment = Terrat_comment.Gate_approval { tokens }; _ } -> tokens
      | Pull_request_open _
      | Pull_request_sync _
      | Pull_request_ready_for_review _
      | Pull_request_close _
      | Pull_request_comment _
      | Push _
      | Run_scheduled_drift
      | Run_drift _ -> assert false
  end

  module Id = struct
    type t =
      | Account_disabled
      | Account_enabled
      | Account_expired
      | All_layers_completed
      | Always_store_pull_request
      | Batch_runs_disabled
      | Batch_runs_enabled
      | Can_run_stack_auto_apply
      | Check_access_control_apply
      | Check_access_control_ci_change
      | Check_access_control_files
      | Check_access_control_plan
      | Check_access_control_repo_config
      | Check_account_status_expired
      | Check_account_tier
      | Check_all_dirspaces_applied
      | Check_conflicting_work_manifests
      | Check_dirspaces_missing_plans
      | Check_dirspaces_owned_by_other_pull_requests
      | Check_enabled_in_repo_config
      | Check_gates
      | Check_merge_conflict
      | Check_non_empty_matches
      | Check_pull_request_state
      | Check_reconcile
      | Check_valid_destination_branch
      | Checkpoint
      | Complete_no_change_dirspaces
      | Complete_work_manifest
      | Config_build_not_required
      | Config_build_required
      | Create_drift_events
      | Create_work_manifest
      | Event_kind_feedback
      | Event_kind_gate_approval
      | Event_kind_help
      | Event_kind_index
      | Event_kind_op
      | Event_kind_push
      | Event_kind_repo_config
      | Event_kind_run_drift
      | Event_kind_unlock
      | Index_not_required
      | Index_required
      | More_layers_to_run
      | Op_kind_apply
      | Op_kind_apply_autoapprove
      | Op_kind_apply_force
      | Op_kind_plan
      | Publish_help
      | Publish_index
      | Publish_repo_config
      | Publish_unlock
      | React_to_comment
      | Record_feedback
      | Recover
      | Recover_noop
      | Reset_ctx
      | Run_work_manifest_iter
      | Store_account_repository
      | Store_gate_approval
      | Store_pull_request
      | Store_stacks
      | Synthesize_pull_request_sync
      | Test_account_status
      | Test_batch_runs
      | Test_config_build_required
      | Test_event_kind
      | Test_index_required
      | Test_more_layers_to_run
      | Test_op_kind
      | Test_tree_build_required
      | Tree_build_not_required
      | Tree_build_required
      | Unlock
      | Unset_work_manifest_id
      | Update_drift_schedule
      | Wait_for_work_manifest_run
    [@@deriving show, eq]

    let to_string = function
      | Account_disabled -> "account_disabled"
      | Account_enabled -> "account_enabled"
      | Account_expired -> "account_expired"
      | All_layers_completed -> "all_layers_completed"
      | Always_store_pull_request -> "always_store_pull_request"
      | Batch_runs_disabled -> "batch_runs_disabled"
      | Batch_runs_enabled -> "batch_runs_enabled"
      | Can_run_stack_auto_apply -> "can_run_stack_auto_apply"
      | Check_access_control_apply -> "check_access_control_apply"
      | Check_access_control_ci_change -> "check_access_control_ci_change"
      | Check_access_control_files -> "check_access_control_files"
      | Check_access_control_plan -> "check_access_control_plan"
      | Check_access_control_repo_config -> "check_access_control_repo_config"
      | Check_account_status_expired -> "check_account_status_expired"
      | Check_account_tier -> "check_account_tier"
      | Check_all_dirspaces_applied -> "check_all_dirspaces_applied"
      | Check_conflicting_work_manifests -> "check_conflicting_work_manifests"
      | Check_dirspaces_missing_plans -> "check_dirspaces_missing_plans"
      | Check_dirspaces_owned_by_other_pull_requests ->
          "check_dirspaces_owned_by_other_pull_requests"
      | Check_enabled_in_repo_config -> "check_enabled_in_repo_config"
      | Check_gates -> "check_gates"
      | Check_merge_conflict -> "check_merge_conflict"
      | Check_non_empty_matches -> "check_non_empty_matches"
      | Check_pull_request_state -> "check_pull_request_state"
      | Check_reconcile -> "check_reconcile"
      | Check_valid_destination_branch -> "check_valid_destination_branch"
      | Checkpoint -> "checkpoint"
      | Complete_no_change_dirspaces -> "complete_no_change_dirspaces"
      | Complete_work_manifest -> "complete_work_manifest"
      | Config_build_not_required -> "config_build_not_required"
      | Config_build_required -> "config_build_required"
      | Create_drift_events -> "create_drift_events"
      | Create_work_manifest -> "create_work_manifest"
      | Event_kind_feedback -> "event_kind_feedback"
      | Event_kind_gate_approval -> "event_kind_gate_approval"
      | Event_kind_help -> "event_kind_help"
      | Event_kind_index -> "event_kind_index"
      | Event_kind_op -> "event_kind_op"
      | Event_kind_push -> "event_kind_push"
      | Event_kind_repo_config -> "event_kind_repo_config"
      | Event_kind_run_drift -> "event_kind_run_drift"
      | Event_kind_unlock -> "event_kind_unlock"
      | Index_not_required -> "index_not_required"
      | Index_required -> "index_required"
      | More_layers_to_run -> "more_layers_to_run"
      | Op_kind_apply -> "op_kind_apply"
      | Op_kind_apply_autoapprove -> "op_kind_apply_autoapprove"
      | Op_kind_apply_force -> "op_kind_apply_force"
      | Op_kind_plan -> "op_kind_plan"
      | Publish_help -> "publish_help"
      | Publish_index -> "publish_index"
      | Publish_repo_config -> "publish_repo_config"
      | Publish_unlock -> "publish_unlock"
      | React_to_comment -> "react_to_comment"
      | Record_feedback -> "record_feedback"
      | Recover -> "recover"
      | Recover_noop -> "recover_noop"
      | Reset_ctx -> "reset_ctx"
      | Run_work_manifest_iter -> "run_work_manifest_iter"
      | Store_account_repository -> "store_account_repository"
      | Store_gate_approval -> "store_gate_approval"
      | Store_pull_request -> "store_pull_request"
      | Store_stacks -> "store_stacks"
      | Synthesize_pull_request_sync -> "synthesize_pull_request_sync"
      | Test_account_status -> "test_account_status"
      | Test_batch_runs -> "test_batch_runs"
      | Test_config_build_required -> "test_config_build_required"
      | Test_event_kind -> "test_event_kind"
      | Test_index_required -> "test_index_required"
      | Test_more_layers_to_run -> "test_more_layers_to_run"
      | Test_op_kind -> "test_op_kind"
      | Test_tree_build_required -> "test_tree_build_required"
      | Tree_build_not_required -> "tree_build_not_required"
      | Tree_build_required -> "tree_build_required"
      | Unlock -> "unlock"
      | Unset_work_manifest_id -> "unset_work_manifest_id"
      | Update_drift_schedule -> "update_drift_schedule"
      | Wait_for_work_manifest_run -> "wait_for_work_manifest_run"

    let of_string = function
      | "account_disabled" -> Some Account_disabled
      | "account_enabled" -> Some Account_enabled
      | "account_expired" -> Some Account_expired
      | "all_layers_completed" -> Some All_layers_completed
      | "always_store_pull_request" -> Some Always_store_pull_request
      | "batch_runs_disabled" -> Some Batch_runs_disabled
      | "batch_runs_enabled" -> Some Batch_runs_enabled
      | "can_run_stack_auto_apply" -> Some Can_run_stack_auto_apply
      | "check_access_control_apply" -> Some Check_access_control_apply
      | "check_access_control_ci_change" -> Some Check_access_control_ci_change
      | "check_access_control_files" -> Some Check_access_control_files
      | "check_access_control_plan" -> Some Check_access_control_plan
      | "check_access_control_repo_config" -> Some Check_access_control_repo_config
      | "check_account_status_expired" -> Some Check_account_status_expired
      | "check_account_tier" -> Some Check_account_tier
      | "check_all_dirspaces_applied" -> Some Check_all_dirspaces_applied
      | "check_conflicting_work_manifests" -> Some Check_conflicting_work_manifests
      | "check_dirspaces_missing_plans" -> Some Check_dirspaces_missing_plans
      | "check_dirspaces_owned_by_other_pull_requests" ->
          Some Check_dirspaces_owned_by_other_pull_requests
      | "check_enabled_in_repo_config" -> Some Check_enabled_in_repo_config
      | "check_gates" -> Some Check_gates
      | "check_merge_conflict" -> Some Check_merge_conflict
      | "check_non_empty_matches" -> Some Check_non_empty_matches
      | "check_pull_request_state" -> Some Check_pull_request_state
      | "check_reconcile" -> Some Check_reconcile
      | "check_valid_destination_branch" -> Some Check_valid_destination_branch
      | "checkpoint" -> Some Checkpoint
      | "complete_no_change_dirspaces" -> Some Complete_no_change_dirspaces
      | "complete_work_manifest" -> Some Complete_work_manifest
      | "config_build_not_required" -> Some Config_build_not_required
      | "config_build_required" -> Some Config_build_required
      | "create_drift_events" -> Some Create_drift_events
      | "create_work_manifest" -> Some Create_work_manifest
      | "event_kind_feedback" -> Some Event_kind_feedback
      | "event_kind_gate_approval" -> Some Event_kind_gate_approval
      | "event_kind_help" -> Some Event_kind_help
      | "event_kind_index" -> Some Event_kind_index
      | "event_kind_op" -> Some Event_kind_op
      | "event_kind_push" -> Some Event_kind_push
      | "event_kind_repo_config" -> Some Event_kind_repo_config
      | "event_kind_run_drift" -> Some Event_kind_run_drift
      | "event_kind_unlock" -> Some Event_kind_unlock
      | "index_not_required" -> Some Index_not_required
      | "index_required" -> Some Index_required
      | "more_layers_to_run" -> Some More_layers_to_run
      | "op_kind_apply" -> Some Op_kind_apply
      | "op_kind_apply_autoapprove" -> Some Op_kind_apply_autoapprove
      | "op_kind_apply_force" -> Some Op_kind_apply_force
      | "op_kind_plan" -> Some Op_kind_plan
      | "publish_help" -> Some Publish_help
      | "publish_index" -> Some Publish_index
      | "publish_repo_config" -> Some Publish_repo_config
      | "publish_unlock" -> Some Publish_unlock
      | "react_to_comment" -> Some React_to_comment
      | "record_feedback" -> Some Record_feedback
      | "recover" -> Some Recover
      | "recover_noop" -> Some Recover_noop
      | "reset_ctx" -> Some Reset_ctx
      | "run_work_manifest_iter" -> Some Run_work_manifest_iter
      | "store_account_repository" -> Some Store_account_repository
      | "store_gate_approval" -> Some Store_gate_approval
      | "store_pull_request" -> Some Store_pull_request
      | "store_stacks" -> Some Store_stacks
      | "synthesize_pull_request_sync" -> Some Synthesize_pull_request_sync
      | "test_account_status" -> Some Test_account_status
      | "test_batch_runs" -> Some Test_batch_runs
      | "test_config_build_required" -> Some Test_config_build_required
      | "test_event_kind" -> Some Test_event_kind
      | "test_index_required" -> Some Test_index_required
      | "test_more_layers_to_run" -> Some Test_more_layers_to_run
      | "test_op_kind" -> Some Test_op_kind
      | "test_tree_build_required" -> Some Test_tree_build_required
      | "tree_build_not_required" -> Some Tree_build_not_required
      | "tree_build_required" -> Some Tree_build_required
      | "unlock" -> Some Unlock
      | "unset_work_manifest_id" -> Some Unset_work_manifest_id
      | "update_drift_schedule" -> Some Update_drift_schedule
      | "wait_for_work_manifest_run" -> Some Wait_for_work_manifest_run
      | _ -> None
  end

  module State = struct
    type of_string_err = [ `Error ] [@@deriving show]

    module St = struct
      type t =
        | Initial
        | Resume
        | Waiting_for_work_manifest_run
        | Waiting_for_work_manifest_initiate
        | Waiting_for_work_manifest_result
        | Work_manifest_completed
      [@@deriving show, yojson]
    end

    module Io = struct
      module I = struct
        type t =
          | Work_manifest_initiate of {
              encryption_key : Cstruct.t;
              initiate : Terrat_api_components.Work_manifest_initiate.t;
              p :
                (Terrat_api_components.Work_manifest.t option, [ `Error ]) result
                Abb.Future.Promise.t;
            }
          | Work_manifest_result of {
              result : Terrat_api_components.Work_manifest_result.t;
              p : (unit, [ `Error ]) result Abb.Future.Promise.t;
            }
          | Work_manifest_run_success
          | Work_manifest_run_failure of
              [ `Failed_to_start_with_msg_err of string
              | `Failed_to_start
              | `Missing_workflow
              | `Job_failed of string
              | `Error
              ]
          | Plan_store of {
              dirspace : Terrat_dirspace.t;
              data : string;
              has_changes : bool;
              p : (unit, [ `Error ]) result Abb.Future.Promise.t;
            }
          | Plan_fetch of {
              dirspace : Terrat_dirspace.t;
              p : (string option, [ `Error ]) result Abb.Future.Promise.t;
            }
          | Work_manifest_failure of { p : (unit, [ `Error ]) result Abb.Future.Promise.t }
          | Checkpointed
          | Tabula_rasa
      end

      module O = struct
        type 'a t =
          | Clone of 'a list
          | Checkpoint
          | Reset_ctx
      end
    end

    type uuidm = Uuidm.t

    let uuidm_to_yojson = CCFun.(Uuidm.to_string %> [%to_yojson: string])

    let uuidm_of_yojson json =
      let open CCResult.Infix in
      [%of_yojson: string] json
      >>= fun uuid ->
      CCResult.map_err
        (CCFun.const ("Invalid uuid: " ^ uuid))
        (CCResult.of_opt (Uuidm.of_string uuid))

    type t = {
      event : Event.t;
      request_id : string;
      work_manifest_id : uuidm option;
      st : St.t;
      input : Io.I.t option; [@to_yojson fun _ -> `Null] [@of_yojson fun _ -> Ok None]
      output : t Io.O.t option; [@to_yojson fun _ -> `Null] [@of_yojson fun _ -> Ok None]
    }
    [@@deriving yojson]

    type step_err =
      [ `Error
      | Repo_config.fetch_err
      | Terrat_change_match3.synthesize_config_err
      | Pgsql_pool.err
      | `Noop of (t[@opaque])
      ]
    [@@deriving show]

    let to_string t = Yojson.Safe.to_string (to_yojson t)

    let of_string s =
      try CCResult.map_err (fun _ -> `Error) (of_yojson (Yojson.Safe.from_string s))
      with Yojson.Json_error _ -> Error `Error
  end

  module Flow = Abb_flow.Make (Abb.Future) (Id) (State)

  let log = function
    | Flow.Event.Step_start (step, state) ->
        Logs.info (fun m ->
            m
              "%s : FLOW : STEP_START : %s"
              state.State.request_id
              (Id.to_string (Flow.Step.id step)))
    | Flow.Event.Step_end (step, ret, state) ->
        Logs.info (fun m ->
            m
              "%s : FLOW : STEP_END : %s : %s"
              state.State.request_id
              (Id.to_string (Flow.Step.id step))
              (match ret with
              | `Failure (`Step_err (_, `Noop _)) -> "NOOP"
              | `Failure run_err -> "FAILURE : " ^ Flow.show_run_err run_err
              | `Success _ -> "SUCCESS"
              | `Yield state -> (
                  match state.State.output with
                  | Some State.Io.O.Checkpoint -> "CHECKPOINT"
                  | _ -> "YIELD")))
    | Flow.Event.Choice_start (id, state) ->
        Logs.info (fun m ->
            m "%s : FLOW : CHOICE_START : %s" state.State.request_id (Id.to_string id))
    | Flow.Event.Choice_end (id, ret, state) ->
        Logs.info (fun m ->
            m
              "%s : FLOW : CHOICE_END : %s : %s"
              state.State.request_id
              (Id.to_string id)
              (match ret with
              | Ok (choice, _) -> "CHOICE : " ^ Id.to_string choice
              | Error run_err -> "FAILURE : " ^ Flow.show_run_err run_err))
    | Flow.Event.Finally_start (id, state) ->
        Logs.info (fun m ->
            m "%s : FLOW : FINALLY_START : %s" state.State.request_id (Id.to_string id))
    | Flow.Event.Finally_resume (id, state) ->
        Logs.info (fun m ->
            m "%s : FLOW : FINALLY_RESUME : %s" state.State.request_id (Id.to_string id))
    | Flow.Event.Recover_choice (recover_id, choice_id, state) ->
        Logs.info (fun m ->
            m
              "%s : FLOW : RECOVER_CHOICE : %s : %s"
              state.State.request_id
              (Id.to_string recover_id)
              (Id.to_string choice_id))
    | Flow.Event.Recover_start (recover_id, state) ->
        Logs.info (fun m ->
            m "%s : FLOW : RECOVER_START : %s" state.State.request_id (Id.to_string recover_id))

  module Access_control = Terrat_access_control2.Make (struct
    type client = S.Api.Client.t
    type repo = S.Api.Repo.t

    include S.Access_control
  end)

  module Access_control_engine = struct
    module Dirspace_map = Terrat_data.Dirspace_map
    module V1 = Terrat_base_repo_config_v1
    module Ac = V1.Access_control
    module P = V1.Access_control.Policy

    type t = {
      config : Terrat_base_repo_config_v1.Access_control.t;
      ctx : Access_control.Ctx.t;
      policy_branch : S.Api.Ref.t;
      request_id : string;
      user : string;
    }
    [@@warning "-69"]

    let make ~request_id ~ctx ~repo_config ~user ~policy_branch () =
      let config = V1.access_control repo_config in
      { config; ctx; policy_branch; request_id; user }

    let policy_branch t = S.Api.Ref.to_string t.policy_branch

    let eval_ci_change t diff =
      let ci_config_update = t.config.Ac.ci_config_update in
      if t.config.Ac.enabled then
        Abbs_time_it.run (log_time t.request_id "ACCESS_CONTROL_EVAL_CI_CHANGE") (fun () ->
            let open Abbs_future_combinators.Infix_result_monad in
            Access_control.eval_ci_change t.ctx ci_config_update diff
            >>| function
            | true -> None
            | false -> Some ci_config_update)
      else (
        Logs.info (fun m -> m "%s : ACCESS_CONTROL_DISABLED" t.request_id);
        Abb.Future.return (Ok None))

    let eval_files t diff =
      let files_policy = t.config.Ac.files in
      if t.config.Ac.enabled then
        Abbs_time_it.run (log_time t.request_id "ACCESS_CONTROL_FILES") (fun () ->
            let open Abbs_future_combinators.Infix_result_monad in
            Access_control.eval_files t.ctx files_policy diff
            >>| function
            | `Ok -> None
            | `Denied denied -> Some denied)
      else (
        Logs.info (fun m -> m "%s : ACCESS_CONTROL_DISABLED" t.request_id);
        Abb.Future.return (Ok None))

    let eval_repo_config t diff =
      let terrateam_config_update = t.config.Ac.terrateam_config_update in
      if t.config.Ac.enabled then
        Abbs_time_it.run (log_time t.request_id "ACCESS_CONTROL_EVAL_REPO_CONFIG") (fun () ->
            let open Abbs_future_combinators.Infix_result_monad in
            Access_control.eval_repo_config t.ctx terrateam_config_update diff
            >>| function
            | true -> None
            | false -> Some terrateam_config_update)
      else (
        Logs.info (fun m -> m "%s : ACCESS_CONTROL_DISABLED" t.request_id);
        Abb.Future.return (Ok None))

    let eval' t change_matches selector =
      if t.config.Ac.enabled then
        let policies =
          (* Policies have been specified, but that doesn't mean the specific
             operation that is being executed has a configuration.  So iterate
             through and pluck out the specific configuration and take the
             default if that configuration was not specified. *)
          t.config.Ac.policies
          |> CCList.map (fun ({ P.tag_query; _ } as p) ->
              Terrat_access_control2.Policy.{ tag_query; policy = selector p })
        in
        Abbs_time_it.run (log_time t.request_id "ACCESS_CONTROL_SUPERAPPROVAL_EVAL") (fun () ->
            Access_control.eval t.ctx policies change_matches)
      else (
        Logs.info (fun m -> m "%s : ACCESS_CONTROL_DISABLED" t.request_id);
        Abb.Future.return (Ok Terrat_access_control2.R.{ pass = change_matches; deny = [] }))

    let eval_superapproved t reviewers change_matches =
      let open Abbs_future_combinators.Infix_result_monad in
      (* First, let's see if this user can even apply any of the denied changes
         if there is a superapproval. If there isn't, we return the original
         response, otherwise we have to see if any of the changes have super
         approvals. *)
      eval' t change_matches (fun { P.apply_with_superapproval; _ } -> apply_with_superapproval)
      >>= function
      | { Terrat_access_control2.R.pass = _ :: _ as pass; deny = _ } ->
          (* Now, of those that passed, let's see if any have been approved by a
             super approver.  To do this we'll iterate over the approvers. *)
          let pass_with_superapproval =
            pass
            |> CCList.map (fun ({ Terrat_change_match3.Dirspace_config.dirspace; _ } as ch) ->
                (dirspace, ch))
            |> Dirspace_map.of_list
          in
          Abbs_future_combinators.List_result.fold_left
            ~f:(fun acc user ->
              let changes = acc |> Dirspace_map.to_list |> CCList.map snd in
              let ctx = Access_control.Ctx.set_user user t.ctx in
              let t' = { t with ctx } in
              eval' t' changes (fun { P.superapproval; _ } -> superapproval)
              >>= fun { Terrat_access_control2.R.pass; _ } ->
              let acc =
                CCListLabels.fold_left
                  ~f:(fun acc { Terrat_change_match3.Dirspace_config.dirspace; _ } ->
                    Dirspace_map.remove dirspace acc)
                  ~init:acc
                  pass
              in
              Abb.Future.return (Ok acc))
            ~init:pass_with_superapproval
            reviewers
          >>= fun unapproved ->
          Abb.Future.return
            (Ok
               (Dirspace_map.fold
                  (fun k _ acc -> Dirspace_map.remove k acc)
                  unapproved
                  pass_with_superapproval))
      | _ ->
          Logs.debug (fun m ->
              m "%s : ACCESS_CONTROL : NO_MATCHING_CHANGES_FOR_SUPERAPPROVAL" t.request_id);
          Abb.Future.return (Ok Dirspace_map.empty)

    let eval_tf_operation t change_matches = function
      | `Plan -> eval' t change_matches (fun { P.plan; _ } -> plan)
      | `Apply reviewers -> (
          let open Abbs_future_combinators.Infix_result_monad in
          eval' t change_matches (fun { P.apply; _ } -> apply)
          >>= function
          | { Terrat_access_control2.R.pass; deny = _ :: _ as deny } ->
              (* If we have some denies, then let's see if any of them can be
                 applied with because of a super approver.  If not, we'll return
                 the original response. *)
              Logs.debug (fun m -> m "%s : ACCESS_CONTROL : EVAL_SUPERAPPROVAL" t.request_id);
              let denied_change_matches =
                CCList.map
                  (fun { Terrat_access_control2.R.Deny.change_match; _ } -> change_match)
                  deny
              in
              eval_superapproved t reviewers denied_change_matches
              >>= fun superapproved ->
              let pass = pass @ (superapproved |> Dirspace_map.to_list |> CCList.map snd) in
              let deny =
                CCList.filter
                  (fun {
                         Terrat_access_control2.R.Deny.change_match =
                           { Terrat_change_match3.Dirspace_config.dirspace; _ };
                         _;
                       }
                     -> not (Dirspace_map.mem dirspace superapproved))
                  deny
              in
              Abb.Future.return (Ok { Terrat_access_control2.R.pass; deny })
          | r -> Abb.Future.return (Ok r))
      | `Apply_force -> eval' t change_matches (fun { P.apply_force; _ } -> apply_force)
      | `Apply_autoapprove ->
          eval' t change_matches (fun { P.apply_autoapprove; _ } -> apply_autoapprove)

    let eval_pr_operation t = function
      | `Unlock ->
          if t.config.Ac.enabled then
            let match_list = t.config.Ac.unlock in
            Abbs_time_it.run (log_time t.request_id "ACCESS_CONTROL_EVAL") (fun () ->
                let open Abbs_future_combinators.Infix_result_monad in
                Access_control.eval_match_list t.ctx match_list
                >>| function
                | true -> None
                | false -> Some match_list)
          else (
            Logs.debug (fun m -> m "%s : ACCESS_CONTROL_DISABLED" t.request_id);
            Abb.Future.return (Ok None))

    let plan_require_all_dirspace_access t = t.config.Ac.plan_require_all_dirspace_access
    let apply_require_all_dirspace_access t = t.config.Ac.apply_require_all_dirspace_access
  end

  (* We want to be able to compute some values and have them accessible
     throughout the execution of a flow, like binding a variable but a flow can
     be stopped and started and even started on a different computer, so "later"
     accesses of the value might need to compute it again.  To make more
     seamless, we have derived values, these are a function whose value is
     cached but can be recomputed if lost.  This particular implementation is
     using a process-wide cache, such that if any requests happen to come back
     to the same service, they will not have to recompute their value. *)
  module Dv = struct
    module Matches = struct
      type t = {
        working_set_matches : Terrat_change_match3.Dirspace_config.t list;
            (* All unapplied matches in the current working layer *)
        all_matches : Terrat_change_match3.Dirspace_config.t list list;
            (* All matches broken up into layers in the order they must be applied. *)
        all_unapplied_matches : Terrat_change_match3.Dirspace_config.t list list;
            (* All unapplied layers in the order they must be applied *)
        all_tag_query_matches : Terrat_change_match3.Dirspace_config.t list list;
            (* All layers filtered by the tag query *)
        working_layer : Terrat_change_match3.Dirspace_config.t list;
            (* The all dirspaces configs in current layer, where "current" is
               defined as the first layer that does not have all of its
               dirspaces applied. *)
      }
      [@@deriving show]
    end

    (* Cache Dv values so there is little to no cost in fetching them
       frequently.  We cache them a unique identifier for the current invocation
       of the flow, that way each flow invocation gets a consistent view of the
       values but as the values change between resumes the values get
       updated. *)
    module Cache = struct
      let on_hit v () = Prmths.Counter.inc_one (Metrics.cache_dv_call_count ~v "hit")
      let on_miss v () = Prmths.Counter.inc_one (Metrics.cache_dv_call_count ~v "miss")
      let on_evict v () = Prmths.Counter.inc_one (Metrics.cache_dv_call_count ~v "evict")

      module Matches = Abbs_cache.Expiring.Make (struct
        type k =
          string
          * S.Api.Account.t
          * S.Api.Repo.t
          * S.Api.Ref.t
          * S.Api.Ref.t
          * [ `Plan | `Apply | `Stack_auto_apply ]
        [@@deriving eq]

        type v = Matches.t

        type err =
          [ Repo_config.fetch_err
          | Terrat_change_match3.synthesize_config_err
          ]

        type args = unit -> (v, err) result Abb.Future.t

        let fetch f = f ()
        let weight v = kb_of_bytes (CCString.length (Matches.show v))
      end)

      module Access_control_eval_tf_op = Abbs_cache.Expiring.Make (struct
        type k =
          string
          * S.Api.Account.t
          * S.Api.Repo.t
          * S.Api.Pull_request.Id.t
          * S.Api.Ref.t
          * [ `Plan
            | `Stack_auto_apply of string list
            | `Apply of string list
            | `Apply_autoapprove
            | `Apply_force
            ]
        [@@deriving eq]

        type v = Terrat_access_control2.R.t

        type err =
          [ Repo_config.fetch_err
          | Terrat_change_match3.synthesize_config_err
          ]

        type args = unit -> (v, err) result Abb.Future.t

        let fetch f = f ()
        let weight v = kb_of_bytes (CCString.length (Terrat_access_control2.R.show v))
      end)

      module Apply_requirements = Abbs_cache.Expiring.Make (struct
        type k = string [@@deriving eq]
        type v = S.Apply_requirements.Result.t

        type err =
          [ Repo_config.fetch_err
          | Terrat_change_match3.synthesize_config_err
          ]

        type args = unit -> (v, err) result Abb.Future.t

        let fetch f = f ()
        let weight _ = 1
      end)

      module Repo_config = Abbs_cache.Expiring.Make (struct
        type k = string * S.Api.Account.t * S.Api.Repo.t * S.Api.Ref.t [@@deriving eq]
        type v = string list * Terrat_base_repo_config_v1.raw Terrat_base_repo_config_v1.t
        type err = Repo_config.fetch_err
        type args = unit -> (v, err) result Abb.Future.t

        let fetch f = f ()

        let weight (_, repo_config) =
          kb_of_bytes
            (CCString.length
               (Yojson.Safe.to_string
                  Terrat_base_repo_config_v1.(View.to_yojson (to_view repo_config))))
      end)

      module Pull_request = Abbs_cache.Expiring.Make (struct
        type k = string * S.Api.Account.t * S.Api.Repo.t * S.Api.Pull_request.Id.t [@@deriving eq]
        type v = (Terrat_change.Diff.t list, bool) S.Api.Pull_request.t [@@deriving to_yojson]
        type err = [ `Error ]
        type args = unit -> (v, err) result Abb.Future.t

        let fetch f = f ()

        let weight pull_request =
          kb_of_bytes (CCString.length (Yojson.Safe.to_string (v_to_yojson pull_request)))
      end)

      let matches =
        Matches.create
          {
            Abbs_cache.Expiring.on_hit = on_hit "matches";
            on_miss = on_miss "matches";
            on_evict = on_evict "matches";
            duration = Duration.of_min 1;
            capacity = cache_capacity_mb_in_kb 10;
          }

      let access_control_eval_tf_op =
        Access_control_eval_tf_op.create
          {
            Abbs_cache.Expiring.on_hit = on_hit "access_control_eval_tf_op";
            on_miss = on_miss "access_control_eval_tf_op";
            on_evict = on_evict "access_control_eval_tf_op";
            duration = Duration.of_min 1;
            capacity = cache_capacity_mb_in_kb 5;
          }

      let apply_requirements =
        Apply_requirements.create
          {
            Abbs_cache.Expiring.on_hit = on_hit "apply_requirements";
            on_miss = on_miss "apply_requirements";
            on_evict = on_evict "apply_requirements";
            duration = Duration.of_min 1;
            capacity = 50;
          }

      let repo_config =
        Repo_config.create
          {
            Abbs_cache.Expiring.on_hit = on_hit "repo_config";
            on_miss = on_miss "repo_config";
            on_evict = on_evict "repo_config";
            duration = Duration.of_min 1;
            capacity = cache_capacity_mb_in_kb 10;
          }

      let pull_request =
        Pull_request.create
          {
            Abbs_cache.Expiring.on_hit = on_hit "pull_request";
            on_miss = on_miss "pull_request";
            on_evict = on_evict "pull_request";
            duration = Duration.of_min 1;
            capacity = cache_capacity_mb_in_kb 10;
          }
    end

    let is_interactive _ctx state =
      match state.State.event with
      | Event.Pull_request_open _
      | Event.Pull_request_close _
      | Event.Pull_request_sync _
      | Event.Pull_request_ready_for_review _
      | Event.Pull_request_comment _ -> true
      | Event.Push _ | Event.Run_scheduled_drift | Event.Run_drift _ -> false

    let repo_config_system_defaults ctx _state =
      let module V1 = Terrat_base_repo_config_v1 in
      match Terrat_config.infracost @@ S.Api.Config.config @@ Ctx.config ctx with
      | Some _ -> Abb.Future.return (Ok V1.default)
      | None ->
          let system_defaults =
            {
              (V1.to_view V1.default) with
              V1.View.cost_estimation = V1.Cost_estimation.make ~enabled:false ();
            }
          in
          Abb.Future.return (Ok (V1.of_view system_defaults))

    let client ctx state =
      create_client state.State.request_id (Ctx.config ctx) (Event.account state.State.event)

    let pull_request_safe ctx state =
      match Event.pull_request_id_safe state.State.event with
      | None -> Abb.Future.return (Ok None)
      | Some pull_request_id -> (
          let account = Event.account state.State.event in
          let repo = Event.repo state.State.event in
          let fetch () =
            let open Abbs_future_combinators.Infix_result_monad in
            create_client state.State.request_id (Ctx.config ctx) account
            >>= fun client ->
            fetch_pull_request state.State.request_id account client repo pull_request_id
          in
          let open Abb.Future.Infix_monad in
          Abbs_time_it.run
            (fun time ->
              (* This is pretty noisy, so only log if the value is greater than 0. *)
              if time > 0.0 then
                Logs.info (fun m ->
                    m
                      "%s : DV : PULL_REQUEST : repo=%s : pull_number=%s : time=%f"
                      state.State.request_id
                      (S.Api.Repo.to_string repo)
                      (S.Api.Pull_request.Id.to_string pull_request_id)
                      time))
            (fun () ->
              Cache.Pull_request.fetch
                Cache.pull_request
                (Ctx.request_id ctx, account, repo, pull_request_id)
                fetch)
          >>= function
          | Ok pull_request -> Abb.Future.return (Ok (Some pull_request))
          | Error `Error -> Abb.Future.return (Error `Error))

    let pull_request ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      pull_request_safe ctx state
      >>= function
      | Some pull_request -> Abb.Future.return (Ok pull_request)
      | None -> assert false

    let target ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      match state.State.event with
      | Event.Pull_request_open _
      | Event.Pull_request_close _
      | Event.Pull_request_sync _
      | Event.Pull_request_ready_for_review _
      | Event.Pull_request_comment _ ->
          pull_request ctx state
          >>= fun pull_request ->
          Abb.Future.return
            (Ok
               (Terrat_vcs_provider2.Target.Pr
                  (Terrat_pull_request.set_diff () @@ Terrat_pull_request.set_checks () pull_request)))
      | Event.Run_drift { repo; _ } ->
          client ctx state
          >>= fun client ->
          fetch_remote_repo state.State.request_id client repo
          >>= fun remote_repo ->
          let branch = S.Api.Ref.to_string (S.Api.Remote_repo.default_branch remote_repo) in
          Abb.Future.return (Ok (Terrat_vcs_provider2.Target.Drift { repo; branch }))
      | Event.Push _ | Event.Run_scheduled_drift -> assert false

    let branch_ref ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      match Event.pull_request_id_safe state.State.event with
      | Some _ ->
          pull_request ctx state
          >>= fun pull_request ->
          Abb.Future.return (Ok (S.Api.Pull_request.branch_ref pull_request))
      | None -> (
          client ctx state
          >>= fun client ->
          fetch_remote_repo state.State.request_id client (Event.repo state.State.event)
          >>= fun remote_repo ->
          let default_branch = S.Api.Remote_repo.default_branch remote_repo in
          fetch_branch_sha
            state.State.request_id
            client
            (Event.repo state.State.event)
            default_branch
          >>= function
          | Some branch_sha -> Abb.Future.return (Ok branch_sha)
          | None -> assert false)

    let branch_name ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      match Event.pull_request_id_safe state.State.event with
      | Some _ ->
          pull_request ctx state
          >>= fun pull_request ->
          Abb.Future.return (Ok (S.Api.Pull_request.branch_name pull_request))
      | None ->
          client ctx state
          >>= fun client ->
          fetch_remote_repo state.State.request_id client (Event.repo state.State.event)
          >>= fun remote_repo ->
          Abb.Future.return (Ok (S.Api.Remote_repo.default_branch remote_repo))

    let working_branch_ref ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      let default_branch_sha =
        client ctx state
        >>= fun client ->
        fetch_remote_repo state.State.request_id client (Event.repo state.State.event)
        >>= fun remote_repo ->
        let default_branch = S.Api.Remote_repo.default_branch remote_repo in
        fetch_branch_sha state.State.request_id client (Event.repo state.State.event) default_branch
        >>= function
        | Some branch_sha -> Abb.Future.return (Ok branch_sha)
        | None -> assert false
      in
      match Event.pull_request_id_safe state.State.event with
      | Some _ -> (
          pull_request ctx state
          >>= fun pull_request ->
          match S.Api.Pull_request.state pull_request with
          | Terrat_pull_request.State.Open _ | Terrat_pull_request.State.Closed ->
              Abb.Future.return (Ok (S.Api.Pull_request.branch_ref pull_request))
          | Terrat_pull_request.State.Merged _ -> default_branch_sha)
      | None -> default_branch_sha

    let base_ref ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      match Event.pull_request_id_safe state.State.event with
      | Some _ ->
          pull_request ctx state
          >>= fun pull_request -> Abb.Future.return (Ok (S.Api.Pull_request.base_ref pull_request))
      | None -> (
          client ctx state
          >>= fun client ->
          fetch_remote_repo state.State.request_id client (Event.repo state.State.event)
          >>= fun remote_repo ->
          let default_branch = S.Api.Remote_repo.default_branch remote_repo in
          fetch_branch_sha
            state.State.request_id
            client
            (Event.repo state.State.event)
            default_branch
          >>= function
          | Some branch_sha -> Abb.Future.return (Ok branch_sha)
          | None -> assert false)

    let base_branch_name ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      match Event.pull_request_id_safe state.State.event with
      | Some _ ->
          pull_request ctx state
          >>= fun pull_request ->
          Abb.Future.return (Ok (S.Api.Pull_request.base_branch_name pull_request))
      | None ->
          client ctx state
          >>= fun client ->
          fetch_remote_repo state.State.request_id client (Event.repo state.State.event)
          >>= fun remote_repo ->
          Abb.Future.return (Ok (S.Api.Remote_repo.default_branch remote_repo))

    let build_config_cache_ref ref_ repo_config =
      let json_str =
        repo_config
        |> Terrat_base_repo_config_v1.to_version_1
        |> Terrat_repo_config.Version_1.to_yojson
        |> Yojson.Safe.sort
        |> Yojson.Safe.to_string
      in
      let sha256_hex = Sha256.(to_hex (string json_str)) in
      S.Api.Ref.of_string (S.Api.Ref.to_string ref_ ^ ":" ^ sha256_hex)

    let repo_config_build_cache_ref ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      client ctx state
      >>= fun client ->
      branch_ref ctx state
      >>= fun branch_ref' ->
      working_branch_ref ctx state
      >>= fun working_branch_ref' ->
      repo_config_system_defaults ctx state
      >>= fun system_defaults ->
      Repo_config.fetch_with_provenance
        ~system_defaults
        state.State.request_id
        (Ctx.config ctx)
        client
        (Event.repo state.State.event)
        branch_ref'
      >>= fun (_, repo_config) ->
      Abb.Future.return (Ok (build_config_cache_ref working_branch_ref' repo_config))

    let query_built_config ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      repo_config_build_cache_ref ctx state
      >>= fun build_cache_ref ->
      query_repo_config_json
        state.State.request_id
        (Ctx.storage ctx)
        (Event.account state.State.event)
        build_cache_ref

    let query_built_tree ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      working_branch_ref ctx state
      >>= fun working_branch_ref' ->
      query_repo_tree
        state.State.request_id
        (Ctx.storage ctx)
        (Event.account state.State.event)
        working_branch_ref'
        None

    let repo_config_with_provenance ctx state =
      let account = Event.account state.State.event in
      let repo = Event.repo state.State.event in
      let fetch () =
        let open Abbs_future_combinators.Infix_result_monad in
        client ctx state
        >>= fun client ->
        branch_ref ctx state
        >>= fun branch_ref' ->
        repo_config_system_defaults ctx state
        >>= fun system_defaults ->
        query_built_config ctx state
        >>= fun built_config ->
        Repo_config.fetch_with_provenance
          ?built_config
          ~system_defaults
          state.State.request_id
          (Ctx.config ctx)
          client
          repo
          branch_ref'
      in
      let open Abb.Future.Infix_monad in
      Abbs_time_it.run
        (fun time ->
          Logs.info (fun m ->
              m
                "%s : DV : REPO_CONFIG : account=%s : repo=%s : time=%f"
                state.State.request_id
                (S.Api.Account.to_string account)
                (S.Api.Repo.to_string repo)
                time))
        (fun () ->
          let open Abbs_future_combinators.Infix_result_monad in
          branch_ref ctx state
          >>= fun branch_ref' ->
          Cache.Repo_config.fetch
            Cache.repo_config
            (Ctx.request_id ctx, account, repo, branch_ref')
            fetch)
      >>= function
      | Ok _ as ret -> Abb.Future.return ret
      | Error (#Repo_config.fetch_err as err) -> Abb.Future.return (Error err)

    let repo_config ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      repo_config_with_provenance ctx state
      >>= fun (_, repo_config) -> Abb.Future.return (Ok repo_config)

    let repo_tree_branch ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      let repo = Event.repo state.State.event in
      client ctx state
      >>= fun client ->
      branch_ref ctx state
      >>= fun branch_ref' -> fetch_tree state.State.request_id client repo branch_ref'

    let query_index ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      working_branch_ref ctx state
      >>= fun working_branch_ref' ->
      query_index
        state.State.request_id
        (Ctx.storage ctx)
        (Event.account state.State.event)
        working_branch_ref'

    let query_repo_tree ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      base_ref ctx state
      >>= fun base_ref' ->
      working_branch_ref ctx state
      >>= fun working_branch_ref' ->
      query_repo_tree
        state.State.request_id
        (Ctx.storage ctx)
        (Event.account state.State.event)
        working_branch_ref'
        (Some base_ref')

    let tag_query ctx state =
      match state.State.event with
      | Event.Pull_request_open _
      | Event.Pull_request_close _
      | Event.Pull_request_sync _
      | Event.Pull_request_ready_for_review _ -> Abb.Future.return (Ok Terrat_tag_query.any)
      | Event.Pull_request_comment
          {
            comment =
              Terrat_comment.(
                ( Plan { tag_query }
                | Apply { tag_query }
                | Apply_autoapprove { tag_query }
                | Apply_force { tag_query } ));
            _;
          }
      | Event.Run_drift { tag_query = Some tag_query; _ } -> Abb.Future.return (Ok tag_query)
      | Event.Run_drift _ -> (
          let module V1 = Terrat_base_repo_config_v1 in
          let module D = V1.Drift in
          let open Abbs_future_combinators.Infix_result_monad in
          repo_config ctx state
          >>= fun repo_config ->
          let { D.schedules; _ } = V1.drift repo_config in
          match Sln_map.String.to_list schedules with
          | (_, { D.Schedule.tag_query; _ }) :: _ -> Abb.Future.return (Ok tag_query)
          | [] -> Abb.Future.return (Ok Terrat_tag_query.any))
      | Event.Pull_request_comment _ | Event.Push _ | Event.Run_scheduled_drift -> assert false

    let matches ctx state op =
      let compute_matches
          ~ctx:_
          ~repo_config
          ~tag_query
          ~out_of_change_applies
          ~applied_dirspaces
          ~diff
          ~repo_tree
          ~index
          () =
        let module Dc = Terrat_change_match3.Dirspace_config in
        let module Dir_set = CCSet.Make (CCString) in
        let open CCResult.Infix in
        Terrat_change_match3.synthesize_config ~index repo_config
        >>= fun config ->
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
                 { Terrat_change_match3.Dirspace_config.dirspace = { Terrat_dirspace.dir; _ }; _ }
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
        (* Filter out any dirspaces that have been applied or refer to a directory
           that no longer exists. This could happen because of
           [out_of_change_applies], these may refer to directories that no longer
           exist, and thus we can't do much about them other than ignore them. *)
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
              match op with
              | `Apply | `Stack_auto_apply ->
                  (* If it's an apply, we limit the working set to only those
                     that can be applied, based on stacks configuration. *)
                  let module S = Terrat_base_repo_config_v1.Stacks.Stack in
                  let module Oc = Terrat_base_repo_config_v1.Stacks.Rules in
                  let flat_all_unapplied_matches = CCList.flatten all_unapplied_matches in
                  layer
                  |> CCList.filter (Terrat_change_match3.match_tag_query ~tag_query)
                  |> CCList.filter
                       (fun { Dc.stack_config = { S.rules = { Oc.apply_after; _ }; _ }; _ } ->
                         not
                           (CCList.exists
                              (fun { Dc.stack_name; _ } ->
                                CCList.mem ~eq:CCString.equal stack_name apply_after)
                              flat_all_unapplied_matches))
              | _ -> CCList.filter (Terrat_change_match3.match_tag_query ~tag_query) layer)
          | [] -> []
        in
        let all_tag_query_matches =
          CCList.map (CCList.filter (Terrat_change_match3.match_tag_query ~tag_query)) all_matches
        in
        let unapplied_dirspaces =
          all_unapplied_matches
          |> CCList.flat_map (fun layer -> CCList.map (fun { Dc.dirspace; _ } -> dirspace) layer)
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
        Ok
          ( working_set_matches,
            all_matches,
            all_tag_query_matches,
            all_unapplied_matches,
            working_layer )
      in
      let missing_autoplan_matches ctx state db pull_request matches =
        let module Dc = Terrat_change_match3.Dirspace_config in
        let open Abbs_future_combinators.Infix_result_monad in
        branch_ref ctx state
        >>= fun branch_ref ->
        base_ref ctx state
        >>= fun base_ref ->
        query_dirspaces_without_valid_plans
          ~base_ref
          ~branch_ref
          state.State.request_id
          db
          pull_request
          (CCList.map (fun { Dc.dirspace; _ } -> dirspace) matches)
        >>= fun dirspaces ->
        let dirspaces = Terrat_data.Dirspace_set.of_list dirspaces in
        Abb.Future.return
          (Ok
             (CCList.filter
                (fun { Dc.dirspace; _ } -> Terrat_data.Dirspace_set.mem dirspace dirspaces)
                matches))
      in
      let out_of_change_applies ctx state =
        let open Abbs_future_combinators.Infix_result_monad in
        pull_request_safe ctx state
        >>= function
        | Some pull_request ->
            query_pull_request_out_of_change_applies
              state.State.request_id
              (Ctx.storage ctx)
              pull_request
        | None -> Abb.Future.return (Ok [])
      in
      let applied_dirspaces ctx state =
        let open Abbs_future_combinators.Infix_result_monad in
        pull_request_safe ctx state
        >>= function
        | Some pull_request ->
            query_applied_dirspaces state.State.request_id (Ctx.storage ctx) pull_request
        | None -> Abb.Future.return (Ok [])
      in
      let diff ctx state =
        let open Abbs_future_combinators.Infix_result_monad in
        pull_request_safe ctx state
        >>= function
        | Some pull_request -> Abb.Future.return (Ok (S.Api.Pull_request.diff pull_request))
        | None ->
            repo_tree_branch ctx state
            >>= fun tree ->
            Abb.Future.return
              (Ok (CCList.map (fun filename -> Terrat_change.Diff.Change { filename }) tree))
      in
      let account = Event.account state.State.event in
      let repo = Event.repo state.State.event in
      let fetch () =
        let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
        let open Abbs_future_combinators.Infix_result_monad in
        (* TODO: Do not fetch the branch if we are going to use a built tree *)
        Abbs_future_combinators.Infix_result_app.(
          (fun repo_config repo_tree -> (repo_config, repo_tree))
          <$> repo_config ctx state
          <*> repo_tree_branch ctx state)
        >>= fun (repo_config, repo_tree) ->
        query_index ctx state
        >>= fun index ->
        query_repo_tree ctx state
        >>= fun built_repo_tree ->
        out_of_change_applies ctx state
        >>= fun out_of_change_applies ->
        applied_dirspaces ctx state
        >>= fun applied_dirspaces ->
        base_branch_name ctx state
        >>= fun base_branch_name ->
        branch_name ctx state
        >>= fun branch_name ->
        diff ctx state
        >>= fun diff ->
        tag_query ctx state
        >>= fun tag_query ->
        (* If there is a built repo tree, use that, otherwise the one derived
           from the repository. *)
        let repo_tree =
          CCOption.map_or
            ~default:repo_tree
            (fun built_tree -> CCList.map (fun { I.path; _ } -> path) built_tree)
            built_repo_tree
        in
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
        let diff =
          CCOption.map_or
            ~default:diff
            (fun built_tree ->
              CCList.filter_map
                (function
                  | { I.path; changed = Some true; _ } ->
                      Some (Terrat_change.Diff.Change { filename = path })
                  | { I.path; changed = None; _ } when Sln_set.String.mem path changed_files ->
                      Some (Terrat_change.Diff.Change { filename = path })
                  | _ -> None)
                built_tree)
            built_repo_tree
        in
        Abbs_time_it.run (log_time state.State.request_id "DERIVE_AND_COMPUTE") (fun () ->
            Abb.Thread.run (fun () ->
                let repo_config =
                  Terrat_base_repo_config_v1.derive
                    ~ctx:
                      (Terrat_base_repo_config_v1.Ctx.make
                         ~dest_branch:(S.Api.Ref.to_string base_branch_name)
                         ~branch:(S.Api.Ref.to_string branch_name)
                         ())
                    ~index:
                      (CCOption.map_or
                         ~default:Terrat_base_repo_config_v1.Index.empty
                         (fun { Terrat_vcs_provider2.Index.index; _ } -> index)
                         index)
                    ~file_list:repo_tree
                    repo_config
                in
                compute_matches
                  ~ctx:
                    (Terrat_base_repo_config_v1.Ctx.make
                       ~dest_branch:(S.Api.Ref.to_string base_branch_name)
                       ~branch:(S.Api.Ref.to_string branch_name)
                       ())
                  ~repo_config
                  ~tag_query
                  ~out_of_change_applies
                  ~applied_dirspaces
                  ~diff
                  ~repo_tree
                  ~index:
                    (CCOption.map_or
                       ~default:Terrat_base_repo_config_v1.Index.empty
                       (fun { Terrat_vcs_provider2.Index.index; _ } -> index)
                       index)
                  ()))
        >>= fun ( working_set_matches,
                  all_matches,
                  all_tag_query_matches,
                  all_unapplied_matches,
                  working_layer )
              ->
        pull_request_safe ctx state
        >>= function
        | Some pull_request -> (
            let trigger_type = Event.trigger_type state.State.event in
            match (op, trigger_type) with
            | `Plan, `Auto ->
                Logs.info (fun m -> m "%s : MATCHES : PLAN : AUTO" state.State.request_id);
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
                       ->
                      autoplan
                      && ((not (S.Api.Pull_request.is_draft_pr pull_request)) || autoplan_draft_pr))
                    working_set_matches
                in
                missing_autoplan_matches
                  ctx
                  state
                  (Ctx.storage ctx)
                  pull_request
                  working_set_matches
                >>= fun working_set_matches ->
                Abb.Future.return
                  (Ok
                     {
                       Matches.working_set_matches;
                       all_matches;
                       all_tag_query_matches;
                       all_unapplied_matches;
                       working_layer;
                     })
            | `Stack_auto_apply, _ ->
                Logs.info (fun m -> m "%s : MATCHES : STACK_AUTO_APPLY" state.State.request_id);
                let module S = Terrat_base_repo_config_v1.Stacks in
                let working_set_matches =
                  CCList.filter
                    (fun {
                           Terrat_change_match3.Dirspace_config.stack_config =
                             { S.Stack.rules = { S.Rules.auto_apply; _ }; _ };
                           _;
                         }
                       -> CCOption.get_or ~default:false auto_apply)
                    working_set_matches
                in
                Abb.Future.return
                  (Ok
                     {
                       Matches.working_set_matches;
                       all_matches;
                       all_tag_query_matches;
                       all_unapplied_matches;
                       working_layer;
                     })
            | (`Apply | `Apply_autoapprove | `Apply_force), `Auto ->
                Logs.info (fun m -> m "%s : MATCHES : APPLY : AUTO" state.State.request_id);
                let working_set_matches =
                  CCList.filter
                    (fun {
                           Terrat_change_match3.Dirspace_config.when_modified =
                             { Terrat_base_repo_config_v1.When_modified.autoapply; _ };
                           _;
                         }
                       -> autoapply)
                    working_set_matches
                in
                Abb.Future.return
                  (Ok
                     {
                       Matches.working_set_matches;
                       all_matches;
                       all_tag_query_matches;
                       all_unapplied_matches;
                       working_layer;
                     })
            | (`Plan | `Apply | `Apply_autoapprove | `Apply_force), `Manual ->
                Logs.info (fun m -> m "%s : MATCHES : PLAN-APPLY : MANUAL" state.State.request_id);
                Abb.Future.return
                  (Ok
                     {
                       Matches.working_set_matches;
                       all_matches;
                       all_tag_query_matches;
                       all_unapplied_matches;
                       working_layer;
                     }))
        | None ->
            Abb.Future.return
              (Ok
                 {
                   Matches.working_set_matches;
                   all_matches;
                   all_tag_query_matches;
                   all_unapplied_matches;
                   working_layer;
                 })
      in
      let open Abb.Future.Infix_monad in
      Abbs_time_it.run
        (fun time ->
          Logs.info (fun m ->
              m
                "%s : DV : MATCHES : op=%s :  time=%f"
                state.State.request_id
                (match op with
                | `Apply -> "apply"
                | `Stack_auto_apply -> "stack_auto_apply"
                | `Plan -> "plan"
                | `Apply_autoapprove -> "apply_autoapprove"
                | `Apply_force -> "apply_force")
                time))
        (fun () ->
          let open Abbs_future_combinators.Infix_result_monad in
          base_ref ctx state
          >>= fun base_ref' ->
          branch_ref ctx state
          >>= fun branch_ref' ->
          let op =
            match op with
            | `Plan -> `Plan
            | `Stack_auto_apply -> `Stack_auto_apply
            | `Apply | `Apply_autoapprove | `Apply_force -> `Apply
          in
          Cache.Matches.fetch
            Cache.matches
            (Ctx.request_id ctx, account, repo, base_ref', branch_ref', op)
            fetch)
      >>= function
      | Ok _ as ret -> Abb.Future.return ret
      | Error (#Repo_config.fetch_err as err) -> Abb.Future.return (Error err)
      | Error (#Terrat_change_match3.synthesize_config_err as err) -> Abb.Future.return (Error err)

    let access_control ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun client pull_request repo_config -> (client, pull_request, repo_config))
        <$> client ctx state
        <*> pull_request ctx state
        <*> repo_config ctx state)
      >>= fun (client, pull_request, repo_config) ->
      fetch_remote_repo state.State.request_id client (S.Api.Pull_request.repo pull_request)
      >>= fun remote_repo ->
      Abb.Future.return
        (Ok
           (Access_control_engine.make
              ~request_id:state.State.request_id
              ~ctx:
                (Access_control.Ctx.make
                   ~request_id:state.State.request_id
                   ~client
                   ~config:(S.Api.Config.config (Ctx.config ctx))
                   ~repo:(S.Api.Pull_request.repo pull_request)
                   ~user:S.Api.User.(Id.to_string @@ id @@ Event.user state.State.event)
                   ())
              ~repo_config
              ~user:(S.Api.User.to_string (Event.user state.State.event))
              ~policy_branch:(S.Api.Remote_repo.default_branch remote_repo)
              ()))

    let tf_operation_access_control_evaluation ctx state op =
      let account = Event.account state.State.event in
      let repo = Event.repo state.State.event in
      let pull_request_id = Event.pull_request_id state.State.event in
      let op' =
        match op with
        | `Apply _ -> `Apply
        | `Stack_auto_apply _ -> `Stack_auto_apply
        | (`Plan | `Apply_autoapprove | `Apply_force) as op -> op
      in
      let eval_op =
        match op with
        | `Stack_auto_apply reviews -> `Apply reviews
        | (`Apply _ | `Plan | `Apply_autoapprove | `Apply_force) as op -> op
      in
      let fetch () =
        let open Abbs_future_combinators.Infix_result_monad in
        access_control ctx state
        >>= fun ac ->
        matches ctx state op'
        >>= fun matches ->
        Access_control_engine.eval_tf_operation ac matches.Matches.working_set_matches eval_op
      in
      let open Abb.Future.Infix_monad in
      Abbs_time_it.run
        (fun time ->
          Logs.info (fun m ->
              m
                "%s : DV : ACCESS_CONTROL_TF_OP : op=%s : time=%f"
                state.State.request_id
                (match op' with
                | `Apply -> "apply"
                | `Stack_auto_apply -> "stack_auto_apply"
                | `Plan -> "plan"
                | `Apply_autoapprove -> "apply_autoapprove"
                | `Apply_force -> "apply_force")
                time))
        (fun () ->
          let open Abbs_future_combinators.Infix_result_monad in
          pull_request ctx state
          >>= fun pull_request ->
          Cache.Access_control_eval_tf_op.fetch
            Cache.access_control_eval_tf_op
            ( Ctx.request_id ctx,
              account,
              repo,
              pull_request_id,
              S.Api.Pull_request.branch_ref pull_request,
              op )
            fetch)
      >>= function
      | Ok _ as ret -> Abb.Future.return ret
      | Error (#Repo_config.fetch_err as err) -> Abb.Future.return (Error err)
      | Error (#Terrat_change_match3.synthesize_config_err as err) -> Abb.Future.return (Error err)

    let dirspaces ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      let fetch_dirspace ~system_defaults ?built_config client dest_branch branch repo ref_ =
        Abbs_future_combinators.Infix_result_app.(
          (fun repo_config repo_tree -> (repo_config, repo_tree))
          <$> Repo_config.fetch
                ?built_config
                ~system_defaults
                state.State.request_id
                (Ctx.config ctx)
                client
                repo
                ref_
          <*> fetch_tree state.State.request_id client repo ref_)
        >>= fun (repo_config, repo_tree) ->
        Abbs_time_it.run (log_time state.State.request_id "DERIVE") (fun () ->
            Abbs_future_combinators.to_result
            @@ Abb.Thread.run (fun () ->
                Terrat_base_repo_config_v1.derive
                  ~ctx:(Terrat_base_repo_config_v1.Ctx.make ~dest_branch ~branch ())
                  ~index:Terrat_base_repo_config_v1.Index.empty
                  ~file_list:repo_tree
                  repo_config))
        >>= fun repo_config ->
        Abb.Future.return
          (Terrat_change_match3.synthesize_config
             ~index:Terrat_base_repo_config_v1.Index.empty
             repo_config)
        >>= fun config ->
        Abbs_time_it.run (log_time state.State.request_id "MATCH_DIFF_LIST") (fun () ->
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
                dirspaceflows))
      in
      client ctx state
      >>= fun client ->
      base_branch_name ctx state
      >>= fun base_branch_name ->
      branch_name ctx state
      >>= fun branch_name ->
      base_ref ctx state
      >>= fun base_ref ->
      working_branch_ref ctx state
      >>= fun working_branch_ref ->
      let dest_branch_name = S.Api.Ref.to_string base_branch_name in
      let branch_name = S.Api.Ref.to_string branch_name in
      let repo = Event.repo state.State.event in
      repo_config_system_defaults ctx state
      >>= fun system_defaults ->
      query_repo_config_json
        state.State.request_id
        (Ctx.storage ctx)
        (Event.account state.State.event)
        base_ref
      >>= fun base_built_config ->
      query_repo_config_json
        state.State.request_id
        (Ctx.storage ctx)
        (Event.account state.State.event)
        working_branch_ref
      >>= fun working_branch_built_config ->
      Abbs_future_combinators.Infix_result_app.(
        (fun base_dirspaces dirspaces -> (base_dirspaces, dirspaces))
        <$> fetch_dirspace
              ~system_defaults
              ?built_config:base_built_config
              client
              dest_branch_name
              branch_name
              repo
              base_ref
        <*> fetch_dirspace
              ~system_defaults
              ?built_config:working_branch_built_config
              client
              dest_branch_name
              branch_name
              repo
              working_branch_ref)

    let apply_requirements ctx state op =
      let fetch () =
        let open Abbs_future_combinators.Infix_result_monad in
        Abbs_future_combinators.Infix_result_app.(
          (fun client repo_config pull_request matches ->
            (client, repo_config, pull_request, matches))
          <$> client ctx state
          <*> repo_config ctx state
          <*> pull_request ctx state
          <*> matches ctx state op)
        >>= fun (client, repo_config, pull_request, matches) ->
        eval_apply_requirements
          state.State.request_id
          (Ctx.config ctx)
          (Event.user state.State.event)
          client
          repo_config
          pull_request
          matches.Matches.working_set_matches
      in
      let open Abb.Future.Infix_monad in
      Abbs_time_it.run
        (fun time ->
          Logs.info (fun m ->
              m "%s : DV : APPLY_REQUIREMENTS : time=%f" state.State.request_id time))
        (fun () ->
          Cache.Apply_requirements.fetch Cache.apply_requirements (Ctx.request_id ctx) fetch)
      >>= function
      | Ok _ as ret -> Abb.Future.return ret
      | Error (#Repo_config.fetch_err as err) -> Abb.Future.return (Error err)
      | Error (#Terrat_change_match3.synthesize_config_err as err) -> Abb.Future.return (Error err)

    let access_control_results ctx state op =
      let open Abbs_future_combinators.Infix_result_monad in
      match Event.initiator state.State.event with
      | Terrat_work_manifest3.Initiator.User _ -> (
          match op with
          | (`Plan | `Apply_autoapprove | `Apply_force) as op ->
              tf_operation_access_control_evaluation ctx state op
          | (`Apply | `Stack_auto_apply) as op' ->
              apply_requirements ctx state op'
              >>= fun apply_requirements ->
              let reviews =
                CCList.filter_map
                  (fun { Terrat_pull_request_review.user; _ } -> user)
                  (S.Apply_requirements.Result.approved_reviews apply_requirements)
              in
              let access_control_run_type =
                match op' with
                | `Apply -> `Apply reviews
                | `Stack_auto_apply -> `Stack_auto_apply reviews
              in
              tf_operation_access_control_evaluation ctx state access_control_run_type)
      | Terrat_work_manifest3.Initiator.System ->
          matches ctx state op
          >>= fun matches ->
          Abb.Future.return
            (Ok { Terrat_access_control2.R.pass = matches.Matches.working_set_matches; deny = [] })
  end

  module H = struct
    let log_state_err request_id st input work_manifest_id =
      let string_of_input =
        let open State.Io.I in
        function
        | Work_manifest_initiate _ -> "Work_manifest_initiate"
        | Work_manifest_result _ -> "Work_manifest_result"
        | Work_manifest_run_success -> "Work_manifest_run_success"
        | Work_manifest_run_failure _ -> "Work_manifest_run_failure"
        | Plan_store _ -> "Plan_store"
        | Plan_fetch _ -> "Plan_fetch"
        | Work_manifest_failure _ -> "Work_manifest_failure"
        | Checkpointed -> "Checkpointed"
        | Tabula_rasa -> "Tabula_rasa"
      in
      Logs.err (fun m ->
          m
            "EVALUATOR %s : STATE_ERROR : st=%a : input=%s : work_manifest_id=%s"
            request_id
            State.St.pp
            st
            (CCOption.map_or ~default:"" string_of_input input)
            (CCOption.map_or ~default:"" Uuidm.to_string work_manifest_id))

    let log_state_err_iter _ctx state =
      log_state_err
        state.State.request_id
        state.State.st
        state.State.input
        state.State.work_manifest_id;
      Abb.Future.return (Error `Silent_failure)

    let run_interactive ctx state f =
      if Dv.is_interactive ctx state then f () else Abb.Future.return (Ok state)

    let maybe_publish_msg ctx state msg =
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        Dv.client ctx state
        >>= fun client ->
        Dv.pull_request_safe ctx state
        >>= function
        | Some pull_request ->
            publish_msg
              state.State.request_id
              client
              (S.Api.User.to_string @@ Event.user state.State.event)
              pull_request
              msg
        | None -> Abb.Future.return (Ok ())
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok () -> Abb.Future.return ()
      | Error `Error ->
          Logs.err (fun m -> m "%s : MAYBE_PUBLISH_MSG" state.State.request_id);
          Abb.Future.return ()

    (* Implement a work manifest iteration.  This can create a work manifest if
       one doesn't exist already, update the existing one with new information
       one has already been created, handle run success and failure, and finally
       handle initiate and result.  The only thing this does not handle is
       completing a work manifest, so that iterations can be composed together.
       [fallthrough] is used compose different iter handlers together. *)
    let eval_work_manifest_iter
        ~name
        ~create
        ~update
        ~run_success
        ~run_failure
        ~initiate
        ~result
        ~fallthrough
        ctx
        state =
      let module St = State.St in
      let module I = State.Io.I in
      let module Wm = Terrat_work_manifest3 in
      let states_of_work_manifests work_manifests =
        CCList.map
          (fun { Wm.id; _ } ->
            { state with State.st = St.Waiting_for_work_manifest_run; work_manifest_id = Some id })
          work_manifests
      in
      let open Abbs_future_combinators.Infix_result_monad in
      match (state.State.st, state.State.input, state.State.work_manifest_id) with
      | St.Initial, None, None -> (
          Logs.info (fun m -> m "%s : WORK_MANIFEST_ITER : %s : CREATE" state.State.request_id name);
          Abbs_time_it.run (log_time state.State.request_id "CREATE") (fun () -> create ctx state)
          >>= function
          | [] -> Abb.Future.return (Error (`Noop state))
          | self :: work_manifests ->
              Abb.Future.return
                (Error
                   (`Clone
                      ( {
                          state with
                          State.st = St.Waiting_for_work_manifest_run;
                          work_manifest_id = Some self.Wm.id;
                        },
                        states_of_work_manifests work_manifests ))))
      | St.Initial, None, Some work_manifest_id -> (
          Logs.info (fun m ->
              m
                "%s : WORK_MANIFEST_ITER : %s : UPDATE : id=%a"
                state.State.request_id
                name
                Uuidm.pp
                work_manifest_id);
          query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
          >>= function
          | Some ({ Wm.state = Wm.State.(Queued | Running); _ } as work_manifest) -> (
              Abbs_time_it.run (log_time state.State.request_id "UPDATE") (fun () ->
                  update ctx state work_manifest)
              >>= function
              | [] -> Abb.Future.return (Ok { state with State.st = St.Initial })
              | work_manifests -> (
                  match
                    CCList.partition
                      (fun { Wm.id; _ } -> Uuidm.equal id work_manifest_id)
                      work_manifests
                  with
                  | [], work_manifests ->
                      let states = states_of_work_manifests work_manifests in
                      Abbs_future_combinators.List_result.iter
                        ~f:(run_success ctx state)
                        work_manifests
                      >>= fun () ->
                      Abb.Future.return
                        (Error
                           (`Clone ({ state with State.st = St.Work_manifest_completed }, states)))
                  | [ self ], work_manifests ->
                      let state = { state with State.work_manifest_id = Some self.Wm.id } in
                      Abbs_future_combinators.List_result.iter
                        ~f:(run_success ctx state)
                        (self :: work_manifests)
                      >>= fun () ->
                      let states = states_of_work_manifests work_manifests in
                      Abb.Future.return
                        (Error
                           (`Clone
                              ( { state with State.st = St.Waiting_for_work_manifest_initiate },
                                states )))
                  | _ :: _, _ -> assert false))
          | Some { Wm.id; state = state'; _ } ->
              Logs.err (fun m ->
                  m
                    "%s : WORK_MANIFEST_ITER : %s : UPDATE : INVALID_STATE : id=%a : state=%s"
                    state.State.request_id
                    name
                    Uuidm.pp
                    id
                    (Wm.State.to_string state'));
              Abb.Future.return (Error `Silent_failure)
          | None ->
              Logs.err (fun m ->
                  m
                    "%s : WORK_MANIFEST_ITER : %s : UPDATE : NOT_FOUND : id=%a"
                    state.State.request_id
                    name
                    Uuidm.pp
                    work_manifest_id);
              Abb.Future.return (Error `Silent_failure))
      | St.Waiting_for_work_manifest_run, None, Some _ ->
          (* This should be reached if we cloned some work manifests. *)
          Abb.Future.return (Error (`Yield state))
      | St.Work_manifest_completed, None, Some _ ->
          (* This should be reached if we cloned some work manifests. *)
          Abb.Future.return (Error (`Noop state))
      | St.Waiting_for_work_manifest_run, Some I.Work_manifest_run_success, Some work_manifest_id
        -> (
          Logs.info (fun m ->
              m
                "%s : WORK_MANIFEST_ITER : %s : RUN_SUCCESS : id=%a"
                state.State.request_id
                name
                Uuidm.pp
                work_manifest_id);
          query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
          >>= function
          | Some ({ Wm.state = Wm.State.(Queued | Running); _ } as work_manifest) ->
              Abbs_time_it.run (log_time state.State.request_id "RUN_SUCCESS") (fun () ->
                  run_success ctx state work_manifest)
              >>= fun () ->
              Abb.Future.return
                (Error
                   (`Yield
                      { state with State.st = St.Waiting_for_work_manifest_initiate; input = None }))
          | Some { Wm.id; state = state'; _ } ->
              Logs.err (fun m ->
                  m
                    "%s : WORK_MANIFEST_ITER : %s : RUN_SUCCESS : INVALID_STATE : id=%a : state=%s"
                    state.State.request_id
                    name
                    Uuidm.pp
                    id
                    (Wm.State.to_string state'));
              Abb.Future.return (Error `Silent_failure)
          | None ->
              Logs.err (fun m ->
                  m
                    "%s : WORK_MANIFEST_ITER : %s : RUN_SUCCESS : NOT_FOUND : id=%a"
                    state.State.request_id
                    name
                    Uuidm.pp
                    work_manifest_id);
              Abb.Future.return (Error `Silent_failure))
      | ( St.Waiting_for_work_manifest_run,
          Some (I.Work_manifest_run_failure err),
          Some work_manifest_id ) -> (
          Logs.info (fun m ->
              m
                "%s : WORK_MANIFEST_ITER : %s : RUN_FAILURE : id=%a"
                state.State.request_id
                name
                Uuidm.pp
                work_manifest_id);
          query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
          >>= function
          | Some work_manifest ->
              Abbs_time_it.run (log_time state.State.request_id "RUN_FAILURE") (fun () ->
                  run_failure ctx state err work_manifest)
              >>= fun () ->
              Abb.Future.return
                (Error
                   (`Noop { state with State.st = State.St.Work_manifest_completed; input = None }))
          | None ->
              Logs.err (fun m ->
                  m
                    "%s : WORK_MANIFEST_ITER : %s : RUN_FAILURE : NOT_FOUND : id=%a"
                    state.State.request_id
                    name
                    Uuidm.pp
                    work_manifest_id);
              Abb.Future.return (Error `Silent_failure))
      | St.Waiting_for_work_manifest_initiate, None, Some _ ->
          Abb.Future.return (Error (`Yield state))
      | ( St.Waiting_for_work_manifest_initiate,
          Some
            (I.Work_manifest_initiate
               {
                 encryption_key;
                 initiate = { Terrat_api_components.Work_manifest_initiate.run_id; sha };
                 p;
               }),
          Some work_manifest_id ) -> (
          Logs.info (fun m ->
              m
                "%s : WORK_MANIFEST_ITER : %s : INITIATE : id=%a : run_id=%s : sha=%s"
                state.State.request_id
                name
                Uuidm.pp
                work_manifest_id
                run_id
                sha);
          query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
          >>= function
          | Some ({ Wm.state = Wm.State.(Queued | Running); _ } as work_manifest) -> (
              Abbs_time_it.run (log_time state.State.request_id "INITIATE") (fun () ->
                  initiate ctx state encryption_key run_id sha work_manifest)
              >>= function
              | Some response ->
                  let open Abb.Future.Infix_monad in
                  Abb.Future.Promise.set p (Ok (Some response))
                  >>= fun () ->
                  Abb.Future.return
                    (Error
                       (`Yield
                          {
                            state with
                            State.st = St.Waiting_for_work_manifest_result;
                            output = None;
                            input = None;
                          }))
              | None -> Abb.Future.return (Error (`Noop state)))
          | Some { Wm.id; state = Wm.State.Aborted; _ } ->
              Logs.info (fun m ->
                  m
                    "%s : WORK_MANIFEST_ITER %s : INITIATE : ABORTED : id=%a"
                    state.State.request_id
                    name
                    Uuidm.pp
                    id);
              Abb.Future.return (Error (`Noop state))
          | Some { Wm.id; state = state'; _ } ->
              Logs.err (fun m ->
                  m
                    "%s : WORK_MANIFEST_ITER : %s : INITIATE : INVALID_STATE : id=%a : state=%s"
                    state.State.request_id
                    name
                    Uuidm.pp
                    id
                    (Wm.State.to_string state'));
              Abb.Future.return (Error (`Noop state))
          | None ->
              Logs.err (fun m ->
                  m
                    "%s : WORK_MANIFEST_ITER : %s : INITIATE : NOT_FOUND : id=%a"
                    state.State.request_id
                    name
                    Uuidm.pp
                    work_manifest_id);
              Abb.Future.return (Error (`Noop state)))
      | ( St.Waiting_for_work_manifest_result,
          Some (I.Work_manifest_result { result = req; p }),
          Some work_manifest_id ) ->
          Logs.info (fun m ->
              m
                "%s : WORK_MANIFEST_ITER : %s : RESULT : id=%a"
                state.State.request_id
                name
                Uuidm.pp
                work_manifest_id);
          Abbs_future_combinators.on_failure
            (fun () ->
              query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
              >>= function
              | Some ({ Wm.state = Wm.State.(Queued | Running | Aborted); _ } as work_manifest) -> (
                  let open Abb.Future.Infix_monad in
                  Abbs_time_it.run (log_time state.State.request_id "RESULT") (fun () ->
                      result ctx state req work_manifest)
                  >>= function
                  | Ok () ->
                      Abb.Future.Promise.set p (Ok ())
                      >>= fun () ->
                      Abb.Future.return
                        (Ok { state with State.st = St.Initial; input = None; output = None })
                  | Error (`Noop state) ->
                      Abb.Future.Promise.set p (Ok ())
                      >>= fun () ->
                      Abb.Future.return
                        (Error (`Noop { state with State.st = St.Initial; input = None }))
                  | Error err -> Abb.Future.return (Error err))
              | Some { Wm.id; state = state'; _ } ->
                  Logs.err (fun m ->
                      m
                        "%s : WORK_MANIFEST_ITER : %s : RESULT : INVALID_STATE : id=%a : state=%s"
                        state.State.request_id
                        name
                        Uuidm.pp
                        id
                        (Wm.State.to_string state'));
                  Abb.Future.return (Error `Silent_failure)
              | None ->
                  Logs.err (fun m ->
                      m
                        "%s : WORK_MANIFEST_ITER : %s : RESULT : NOT_FOUND : id=%a"
                        state.State.request_id
                        name
                        Uuidm.pp
                        work_manifest_id);
                  Abb.Future.return (Error `Silent_failure))
            ~failure:(fun () -> Abb.Future.Promise.set p (Error `Error))
      | _, Some (I.Work_manifest_failure { p }), Some work_manifest_id ->
          Logs.info (fun m ->
              m
                "%s : WORK_MANIFEST_ITER : %s : WORK_MANIFEST_FAILURE : id=%a"
                state.State.request_id
                name
                Uuidm.pp
                work_manifest_id);
          Abbs_future_combinators.with_finally
            (fun () ->
              query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
              >>= function
              | Some ({ Wm.state = Wm.State.(Queued | Running); _ } as work_manifest) ->
                  update_work_manifest_state
                    state.State.request_id
                    (Ctx.storage ctx)
                    work_manifest_id
                    Wm.State.Aborted
                  >>= fun () ->
                  run_failure ctx state `Error work_manifest
                  >>= fun () -> Abb.Future.return (Error (`Noop state))
              | Some _ -> Abb.Future.return (Error (`Noop state))
              | None ->
                  Logs.err (fun m ->
                      m
                        "%s : WORK_MANIFEST_ITER : %s : WORK_MANIFEST_FAILURE : NOT_FOUND : id=%a"
                        state.State.request_id
                        name
                        Uuidm.pp
                        work_manifest_id);
                  Abb.Future.return (Error `Silent_failure))
            ~finally:(fun () -> Abb.Future.Promise.set p (Ok ()))
      | _, _, _ -> fallthrough ctx state

    let eval_plan_work_manifest_iter ~store ~fetch ~fallthrough ctx state =
      let module St = State.St in
      let module I = State.Io.I in
      let open Abbs_future_combinators.Infix_result_monad in
      match (state.State.st, state.State.input, state.State.work_manifest_id) with
      | ( St.Waiting_for_work_manifest_result,
          Some (I.Plan_store { dirspace; data; has_changes; p }),
          Some work_manifest_id ) ->
          store ctx state dirspace data has_changes work_manifest_id
          >>= fun () ->
          let open Abb.Future.Infix_monad in
          Abb.Future.Promise.set p (Ok ())
          >>= fun () -> Abb.Future.return (Error (`Yield { state with State.input = None }))
      | ( St.Waiting_for_work_manifest_result,
          Some (I.Plan_fetch { dirspace; p }),
          Some work_manifest_id ) ->
          fetch ctx state dirspace work_manifest_id
          >>= fun data ->
          let open Abb.Future.Infix_monad in
          Abb.Future.Promise.set p (Ok data)
          >>= fun () ->
          Abb.Future.return (Error (`Yield { state with State.input = None; output = None }))
      | _, _, _ -> fallthrough ctx state

    let initiate_work_manifest state request_id db run_id sha =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      function
      | { Wm.id; branch_ref; state = Wm.State.(Queued | Running); _ }
        when CCString.equal branch_ref sha -> (
          update_work_manifest_run_id request_id db id run_id
          >>= fun () ->
          update_work_manifest_state request_id db id Wm.State.Running
          >>= fun () ->
          query_work_manifest request_id db id
          >>= function
          | Some wm -> Abb.Future.return (Ok (Some wm))
          | None -> assert false)
      | { Wm.id; branch_ref; state = Wm.State.(Queued | Running); _ } ->
          Logs.info (fun m ->
              m
                "%s : MISMATCHED_REFS : id=%a : branch_ref=%s : sha=%s"
                request_id
                Uuidm.pp
                id
                branch_ref
                sha);
          update_work_manifest_run_id request_id db id run_id
          >>= fun () -> Abb.Future.return (Error (`Ref_mismatch_err state))
      | { Wm.id; branch_ref; state = state'; _ } ->
          Logs.info (fun m ->
              m
                "%s : COULD_NOT_INITIATE : id=%a : state=%s : branch_ref=%s : sha=%s"
                request_id
                Uuidm.pp
                id
                (Wm.State.to_string state')
                branch_ref
                sha);
          Abb.Future.return (Ok None)

    let match_tag_queries ~accessor ~changes queries =
      CCList.map
        (fun change ->
          ( change,
            CCList.find_idx
              (fun q -> Terrat_change_match3.match_tag_query ~tag_query:(accessor q) change)
              queries ))
        changes

    let publish_run_failure request_id client user pull_request = function
      | `Error -> publish_msg request_id client user pull_request Msg.Unexpected_temporary_err
      | `Job_failed run_id ->
          publish_msg request_id client user pull_request (Msg.Work_manifest_run_failed { run_id })
      | (`Failed_to_start_with_msg_err _ | `Missing_workflow | `Failed_to_start) as err ->
          publish_msg request_id client user pull_request (Msg.Run_work_manifest_err err)

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

    let generate_index_run_dirs ctx state wm =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun client repo_config repo_tree base_branch_name branch_name ->
          (client, repo_config, repo_tree, base_branch_name, branch_name))
        <$> Dv.client ctx state
        <*> Dv.repo_config ctx state
        <*> Dv.repo_tree_branch ctx state
        <*> Dv.base_branch_name ctx state
        <*> Dv.branch_name ctx state)
      >>= fun (_client, repo_config, repo_tree, base_branch_name', branch_name') ->
      Dv.query_repo_tree ctx state
      >>= fun built_repo_tree ->
      let repo_tree =
        let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
        CCOption.map_or
          ~default:repo_tree
          (fun built_tree -> CCList.map (fun { I.path; _ } -> path) built_tree)
          built_repo_tree
      in
      let dest_branch = S.Api.Ref.to_string base_branch_name' in
      let branch = S.Api.Ref.to_string branch_name' in
      Abbs_time_it.run (log_time state.State.request_id "DERIVE") (fun () ->
          Abbs_future_combinators.to_result
          @@ Abb.Thread.run (fun () ->
              Terrat_base_repo_config_v1.derive
                ~ctx:(Terrat_base_repo_config_v1.Ctx.make ~dest_branch ~branch ())
                ~index:Terrat_base_repo_config_v1.Index.empty
                ~file_list:repo_tree
                repo_config))
      >>= fun repo_config ->
      Abb.Future.return
        (Terrat_change_match3.synthesize_config
           ~index:Terrat_base_repo_config_v1.Index.empty
           repo_config)
      >>= fun config ->
      let tag_query = wm.Wm.tag_query in
      Abbs_time_it.run (log_time state.State.request_id "MATCH_DIFF_LIST") (fun () ->
          Abbs_future_combinators.to_result
          @@ Abb.Thread.run (fun () ->
              CCList.filter
                (Terrat_change_match3.match_tag_query ~tag_query)
                (CCList.flatten
                   (Terrat_change_match3.match_diff_list
                      config
                      (CCList.map
                         (fun filename -> Terrat_change.Diff.(Change { filename }))
                         repo_tree)))))
      >>= fun matches ->
      Abb.Future.return (dirspaceflows_of_changes repo_config matches)
      >>= fun dirspaceflows ->
      let module Dsf = Terrat_change.Dirspaceflow in
      let changes =
        CCList.map
          (fun ({ Dsf.workflow; _ } as dsf) ->
            { dsf with Dsf.workflow = CCOption.map (fun { Dsf.Workflow.idx; _ } -> idx) workflow })
          dirspaceflows
      in
      Abb.Future.return (Ok { wm with Wm.changes })

    let create_token installation_id work_manifest_id db =
      let open Abbs_future_combinators.Infix_result_monad in
      Terrat_user.create_system_user
        ~access_token_id:work_manifest_id
        ~capabilities:
          Terrat_user.Capability.
            [
              Installation_id installation_id;
              Kv_store_read;
              Kv_store_write;
              Kv_store_system_read;
              Kv_store_system_write;
            ]
        db
      >>= fun user -> Terrat_user.Token.to_token db user

    let generate_index_work_manifest_initiate ctx state _encryption_key run_id sha work_manifest =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      initiate_work_manifest state state.State.request_id (Ctx.storage ctx) run_id sha work_manifest
      >>= function
      | Some
          ({ Wm.account; id; branch_ref = _; base_ref = _; state = Wm.State.(Queued | Running); _ }
           as wm) ->
          generate_index_run_dirs ctx state wm
          >>= fun wm ->
          Dv.base_ref ctx state
          >>= fun base_ref' ->
          Dv.repo_config ctx state
          >>= fun repo_config ->
          Dv.repo_tree_branch ctx state
          >>= fun repo_tree ->
          Dv.query_repo_tree ctx state
          >>= fun built_repo_tree ->
          let repo_tree =
            let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
            CCOption.map_or
              ~default:repo_tree
              (fun built_tree -> CCList.map (fun { I.path; _ } -> path) built_tree)
              built_repo_tree
          in
          Dv.base_branch_name ctx state
          >>= fun base_branch_name ->
          Dv.branch_name ctx state
          >>= fun branch_name ->
          Abbs_time_it.run (log_time state.State.request_id "DERIVE") (fun () ->
              Abbs_future_combinators.to_result
              @@ Abb.Thread.run (fun () ->
                  Terrat_base_repo_config_v1.derive
                    ~ctx:
                      (Terrat_base_repo_config_v1.Ctx.make
                         ~dest_branch:(S.Api.Ref.to_string base_branch_name)
                         ~branch:(S.Api.Ref.to_string branch_name)
                         ())
                    ~index:Terrat_base_repo_config_v1.Index.empty
                    ~file_list:repo_tree
                    repo_config))
          >>= fun repo_config ->
          create_token (S.Api.Account.Id.to_string @@ S.Api.Account.id account) id (Ctx.storage ctx)
          >>= fun token ->
          let module I = Terrat_api_components.Work_manifest_index in
          let dirs =
            wm.Wm.changes
            |> CCList.map Terrat_change.Dirspaceflow.to_dirspace
            |> CCList.map (fun Terrat_change.Dirspace.{ dir; _ } -> dir)
          in
          let config =
            repo_config
            |> Terrat_base_repo_config_v1.to_version_1
            |> Terrat_repo_config.Version_1.to_yojson
          in
          let response =
            Terrat_api_components.Work_manifest.Work_manifest_index
              { I.dirs; base_ref = S.Api.Ref.to_string base_ref'; token; type_ = `Index; config }
          in
          Abb.Future.return (Ok (Some response))
      | Some _ | None -> Abb.Future.return (Ok None)

    let generate_index_work_manifest_result ctx state result work_manifest =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      match result with
      | Terrat_api_components.Work_manifest_result.Work_manifest_index_result index ->
          store_index_result state.State.request_id (Ctx.storage ctx) work_manifest.Wm.id index
          >>= fun () ->
          store_index state.State.request_id (Ctx.storage ctx) work_manifest.Wm.id index
          >>= fun _ ->
          run_interactive ctx state (fun () ->
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.pull_request ctx state
              >>= fun pull_request ->
              let module Status = Terrat_commit_check.Status in
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Completed"
                  ~status:Status.Completed
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam index"
              in
              create_commit_checks
                state.State.request_id
                client
                repo
                (S.Api.Pull_request.branch_ref pull_request)
                [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok ())
      | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result _ ->
          assert false
      | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result2 _ ->
          assert false
      | Terrat_api_components_work_manifest_result.Work_manifest_build_config_result _ ->
          assert false
      | Terrat_api_components_work_manifest_result.Work_manifest_build_tree_result _ -> assert false
      | Terrat_api_components_work_manifest_result.Work_manifest_build_result_failure _ ->
          assert false

    let maybe_create_completed_apply_check
        request_id
        config
        client
        account
        repo_config
        repo
        pull_request =
      let module R = Terrat_base_repo_config_v1 in
      let apply_requirements = R.apply_requirements repo_config in
      if apply_requirements.R.Apply_requirements.create_completed_apply_check_on_noop then
        let checks =
          [
            S.Commit_check.make_str
              ~config
              ~description:"Completed"
              ~status:Terrat_commit_check.Status.Completed
              ~repo
              ~account
              "terrateam apply";
          ]
        in
        create_commit_checks
          request_id
          client
          (S.Api.Pull_request.repo pull_request)
          (S.Api.Pull_request.branch_ref pull_request)
          checks
      else Abb.Future.return (Ok ())

    (* Partitions a dirspaceflows by a few attributes:

       1. The environment, so all environments get their own work manifest.

       2. runs_on, so any runs that get their own runs_on configuration get
          their own work manifest.  *)
    let partition_by_run_params ~max_workspaces_per_batch dirspaceflows =
      let module M = struct
        type t = string option * Yojson.Safe.t option [@@deriving eq]
      end in
      let module Dsf = Terrat_change.Dirspaceflow in
      let module We = Terrat_base_repo_config_v1.Workflows.Entry in
      let partitions =
        CCListLabels.fold_left
          ~f:(fun acc dsf ->
            let k =
              match dsf with
              | {
               Dsf.workflow = Some { Dsf.Workflow.workflow = { We.environment; runs_on; _ }; _ };
               _;
              } -> (environment, runs_on)
              | _ -> (None, None)
            in
            CCList.Assoc.update
              ~eq:M.equal
              ~f:(fun v -> Some (dsf :: CCOption.get_or ~default:[] v))
              k
              acc)
          ~init:[]
          dirspaceflows
      in
      CCList.flat_map
        (fun (k, dsfs) ->
          dsfs
          |> CCList.sort (fun l r ->
              (*Ensure chunks are sorted by dirspace so chunks are consistent between runs. *)
              Terrat_dirspace.compare (Dsf.to_dirspace l) (Dsf.to_dirspace r))
          |> CCList.chunks max_workspaces_per_batch
          |> CCList.map (fun chunk -> (k, chunk)))
        partitions

    let create_op_commit_checks
        request_id
        config
        client
        account
        repo
        ref_
        work_manifest
        description
        status =
      let module Wm = Terrat_work_manifest3 in
      match work_manifest.Wm.changes with
      | [] -> Abb.Future.return (Ok ())
      | dirspaces ->
          let run_type =
            match CCList.rev work_manifest.Wm.steps with
            | [] -> assert false
            | step :: _ -> Wm.Step.to_string step
          in
          let aggregate =
            [
              S.Commit_check.make_str
                ~config
                ~description
                ~status
                ~work_manifest
                ~repo
                ~account
                (Printf.sprintf "terrateam %s pre-hooks" run_type);
              S.Commit_check.make_str
                ~config
                ~description
                ~status
                ~work_manifest
                ~repo
                ~account
                (Printf.sprintf "terrateam %s post-hooks" run_type);
            ]
          in
          let dirspace_checks =
            if CCList.length dirspaces <= dirspace_check_threshold then
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
          in
          let checks = aggregate @ dirspace_checks in
          create_commit_checks request_id client repo ref_ checks

    let create_op_commit_checks_of_result
        request_id
        config
        client
        account
        repo
        ref_
        work_manifest
        result =
      let module Wm = Terrat_work_manifest3 in
      let module Wmr = Terrat_vcs_provider2.Work_manifest_result in
      let status = function
        | true -> Terrat_commit_check.Status.Completed
        | false -> Terrat_commit_check.Status.Failed
      in
      let description = function
        | true -> "Completed"
        | false -> "Failed"
      in
      let run_type =
        match CCList.rev work_manifest.Wm.steps with
        | [] -> assert false
        | step :: _ -> Wm.Step.to_string step
      in
      let aggregate =
        [
          S.Commit_check.make_str
            ~config
            ~description:(description result.Wmr.pre_hooks_success)
            ~status:(status result.Wmr.pre_hooks_success)
            ~work_manifest
            ~repo
            ~account
            (Printf.sprintf "terrateam %s pre-hooks" run_type);
          S.Commit_check.make_str
            ~config
            ~description:(description result.Wmr.post_hooks_success)
            ~status:(status result.Wmr.post_hooks_success)
            ~work_manifest
            ~repo
            ~account
            (Printf.sprintf "terrateam %s post-hooks" run_type);
        ]
      in
      let dirspace_checks =
        if CCList.length result.Wmr.dirspaces_success <= dirspace_check_threshold then
          CCList.map
            (fun (dirspace, success) ->
              S.Commit_check.make_dirspace
                ~config
                ~description:(description success)
                ~run_type
                ~dirspace
                ~status:(status success)
                ~work_manifest
                ~repo
                ~account
                ())
            result.Wmr.dirspaces_success
        else []
      in
      let checks = aggregate @ dirspace_checks in
      create_commit_checks request_id client repo ref_ checks

    let make_work_manifest
        ~state
        ~base_ref
        ~branch_ref
        ~changes
        ~denied_dirspaces
        ~environment
        ~tag_query
        ~target
        ~runs_on
        ~op =
      let module Wm = Terrat_work_manifest3 in
      {
        Wm.account = Event.account state.State.event;
        base_ref = S.Api.Ref.to_string base_ref;
        branch = None;
        branch_ref = S.Api.Ref.to_string branch_ref;
        changes;
        completed_at = None;
        created_at = ();
        denied_dirspaces;
        environment;
        id = ();
        initiator = Event.initiator state.State.event;
        run_id = ();
        runs_on;
        state = ();
        steps =
          [
            (match op with
            | `Plan -> Wm.Step.Plan
            | `Apply | `Apply_force | `Stack_auto_apply -> Wm.Step.Apply
            | `Apply_autoapprove -> Wm.Step.Unsafe_apply);
          ];
        tag_query;
        target;
      }

    let maybe_create_pending_apply_commit_checks
        request_id
        config
        client
        account
        repo
        ref_
        all_matches
        apply_requirements =
      let module Ar = Terrat_base_repo_config_v1.Apply_requirements in
      if apply_requirements.Ar.create_pending_apply_check then
        let open Abbs_future_combinators.Infix_result_monad in
        fetch_commit_checks request_id client repo ref_
        >>= fun commit_checks ->
        let commit_check_titles =
          commit_checks
          |> CCList.map (fun Terrat_commit_check.{ title; _ } -> title)
          |> Sln_set.String.of_list
        in
        let missing_commit_checks =
          let checks =
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
          if CCList.length checks <= dirspace_check_threshold then checks else []
        in
        let missing_apply_check =
          if not (Sln_set.String.mem "terrateam apply" commit_check_titles) then
            [
              S.Commit_check.make_str
                ~config
                ~description:"Waiting"
                ~status:Terrat_commit_check.Status.Queued
                ~repo
                ~account
                "terrateam apply";
            ]
          else []
        in
        create_commit_checks
          request_id
          client
          repo
          ref_
          (missing_apply_check @ missing_commit_checks)
      else Abb.Future.return (Ok ())

    let run_drift_plan_op_work_manifest_iter_create ctx state =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun repo_config base_ref branch_ref working_branch_ref matches ->
          (repo_config, base_ref, branch_ref, working_branch_ref, matches))
        <$> Dv.repo_config ctx state
        <*> Dv.base_ref ctx state
        <*> Dv.branch_ref ctx state
        <*> Dv.working_branch_ref ctx state
        <*> Dv.matches ctx state `Plan)
      >>= fun (repo_config, base_ref, branch_ref, working_branch_ref, matches) ->
      let all_matches = CCList.flatten matches.Dv.Matches.all_tag_query_matches in
      Abb.Future.return (dirspaceflows_of_changes_with_branch_target repo_config all_matches)
      >>= fun all_dirspaceflows ->
      store_dirspaceflows
        ~base_ref
        ~branch_ref
        state.State.request_id
        (Ctx.storage ctx)
        (Event.repo state.State.event)
        all_dirspaceflows
      >>= fun () ->
      let all_dirspaceflows = strip_lock_branch_target all_dirspaceflows in
      let module V1 = Terrat_base_repo_config_v1 in
      let max_workspaces_per_batch =
        if (V1.batch_runs repo_config).V1.Batch_runs.enabled then
          (V1.batch_runs repo_config).V1.Batch_runs.max_workspaces_per_batch
        else CCInt.max_int
      in
      let dirspaceflows_by_run_params =
        partition_by_run_params ~max_workspaces_per_batch all_dirspaceflows
      in
      Abbs_future_combinators.List_result.map
        ~f:(fun ((environment, runs_on), dirspaceflows) ->
          let changes =
            let module Dsf = Terrat_change.Dirspaceflow in
            CCList.map
              (fun ({ Dsf.workflow; _ } as dsf) ->
                {
                  dsf with
                  Dsf.workflow = CCOption.map (fun Dsf.Workflow.{ idx; _ } -> idx) workflow;
                })
              dirspaceflows
          in
          Dv.target ctx state
          >>= fun target ->
          Dv.tag_query ctx state
          >>= fun tag_query ->
          let work_manifest =
            make_work_manifest
              ~state
              ~base_ref
              ~branch_ref:working_branch_ref
              ~changes
              ~denied_dirspaces:[]
              ~environment
              ~tag_query
              ~target
              ~runs_on
              ~op:`Plan
          in
          create_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest
          >>= fun work_manifest ->
          Logs.info (fun m ->
              m
                "%s : CREATED_WORK_MANIFEST : id=%a : base_ref=%s : branch_ref=%s : env=%s : \
                 runs_on=%s"
                state.State.request_id
                Uuidm.pp
                work_manifest.Wm.id
                (S.Api.Ref.to_string base_ref)
                (S.Api.Ref.to_string branch_ref)
                (CCOption.get_or ~default:"" work_manifest.Wm.environment)
                (CCOption.map_or ~default:"" Yojson.Safe.to_string work_manifest.Wm.runs_on));
          run_interactive ctx state (fun () ->
              Dv.client ctx state
              >>= fun client ->
              create_op_commit_checks
                state.State.request_id
                (Ctx.config ctx)
                client
                (Event.account state.State.event)
                (Event.repo state.State.event)
                branch_ref
                work_manifest
                "Queued"
                Terrat_commit_check.Status.Queued
              >>= fun () ->
              maybe_create_pending_apply_commit_checks
                state.State.request_id
                (Ctx.config ctx)
                client
                (Event.account state.State.event)
                (Event.repo state.State.event)
                branch_ref
                (CCList.flatten matches.Dv.Matches.all_matches)
                (Terrat_base_repo_config_v1.apply_requirements repo_config)
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok work_manifest))
        dirspaceflows_by_run_params

    let run_drift_plan_op_work_manifest_iter_update ctx state work_manifest =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun repo_config base_ref branch_ref working_branch_ref matches ->
          (repo_config, base_ref, branch_ref, working_branch_ref, matches))
        <$> Dv.repo_config ctx state
        <*> Dv.base_ref ctx state
        <*> Dv.branch_ref ctx state
        <*> Dv.working_branch_ref ctx state
        <*> Dv.matches ctx state `Plan)
      >>= fun (repo_config, base_ref, branch_ref, working_branch_ref, matches) ->
      let all_matches = CCList.flatten matches.Dv.Matches.all_tag_query_matches in
      Abb.Future.return (dirspaceflows_of_changes_with_branch_target repo_config all_matches)
      >>= fun all_dirspaceflows ->
      store_dirspaceflows
        ~base_ref
        ~branch_ref
        state.State.request_id
        (Ctx.storage ctx)
        (Event.repo state.State.event)
        all_dirspaceflows
      >>= fun () ->
      let all_dirspaceflows = strip_lock_branch_target all_dirspaceflows in
      let module V1 = Terrat_base_repo_config_v1 in
      let max_workspaces_per_batch =
        if (V1.batch_runs repo_config).V1.Batch_runs.enabled then
          (V1.batch_runs repo_config).V1.Batch_runs.max_workspaces_per_batch
        else CCInt.max_int
      in
      let dirspaceflows_by_run_params =
        partition_by_run_params ~max_workspaces_per_batch all_dirspaceflows
      in
      Abbs_future_combinators.List_result.map
        ~f:(fun ((environment, runs_on), dirspaceflows) ->
          let changes =
            let module Dsf = Terrat_change.Dirspaceflow in
            CCList.map
              (fun ({ Dsf.workflow; _ } as dsf) ->
                {
                  dsf with
                  Dsf.workflow = CCOption.map (fun Dsf.Workflow.{ idx; _ } -> idx) workflow;
                })
              dirspaceflows
          in
          if CCOption.equal CCString.equal work_manifest.Wm.environment environment then
            let work_manifest =
              {
                work_manifest with
                Wm.changes;
                denied_dirspaces = [];
                steps = work_manifest.Wm.steps @ [ Wm.Step.Plan ];
              }
            in
            update_work_manifest_changes
              state.State.request_id
              (Ctx.storage ctx)
              work_manifest.Wm.id
              changes
            >>= fun () ->
            update_work_manifest_steps
              state.State.request_id
              (Ctx.storage ctx)
              work_manifest.Wm.id
              work_manifest.Wm.steps
            >>= fun () ->
            run_interactive ctx state (fun () ->
                Dv.client ctx state
                >>= fun client ->
                create_op_commit_checks
                  state.State.request_id
                  (Ctx.config ctx)
                  client
                  (Event.account state.State.event)
                  (Event.repo state.State.event)
                  branch_ref
                  work_manifest
                  "Queued"
                  Terrat_commit_check.Status.Queued
                >>= fun () ->
                maybe_create_pending_apply_commit_checks
                  state.State.request_id
                  (Ctx.config ctx)
                  client
                  (Event.account state.State.event)
                  (Event.repo state.State.event)
                  branch_ref
                  (CCList.flatten matches.Dv.Matches.all_matches)
                  (Terrat_base_repo_config_v1.apply_requirements repo_config)
                >>= fun () -> Abb.Future.return (Ok state))
            >>= fun _ -> Abb.Future.return (Ok work_manifest)
          else
            Dv.target ctx state
            >>= fun target ->
            Dv.tag_query ctx state
            >>= fun tag_query ->
            let work_manifest =
              make_work_manifest
                ~state
                ~base_ref
                ~branch_ref:working_branch_ref
                ~changes
                ~denied_dirspaces:[]
                ~environment
                ~tag_query
                ~target
                ~runs_on
                ~op:`Plan
            in
            create_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest
            >>= fun work_manifest ->
            Logs.info (fun m ->
                m
                  "%s : CREATED_WORK_MANIFEST : id=%a : base_ref=%s : branch_ref=%s : env=%s : \
                   runs_on=%s"
                  state.State.request_id
                  Uuidm.pp
                  work_manifest.Wm.id
                  (S.Api.Ref.to_string base_ref)
                  (S.Api.Ref.to_string branch_ref)
                  (CCOption.get_or ~default:"" work_manifest.Wm.environment)
                  (CCOption.map_or ~default:"" Yojson.Safe.to_string work_manifest.Wm.runs_on));
            run_interactive ctx state (fun () ->
                Dv.client ctx state
                >>= fun client ->
                create_op_commit_checks
                  state.State.request_id
                  (Ctx.config ctx)
                  client
                  (Event.account state.State.event)
                  (Event.repo state.State.event)
                  branch_ref
                  work_manifest
                  "Queued"
                  Terrat_commit_check.Status.Queued
                >>= fun () ->
                maybe_create_pending_apply_commit_checks
                  state.State.request_id
                  (Ctx.config ctx)
                  client
                  (Event.account state.State.event)
                  (Event.repo state.State.event)
                  branch_ref
                  (CCList.flatten matches.Dv.Matches.all_matches)
                  (Terrat_base_repo_config_v1.apply_requirements repo_config)
                >>= fun () -> Abb.Future.return (Ok state))
            >>= fun _ -> Abb.Future.return (Ok work_manifest))
        dirspaceflows_by_run_params

    let run_op_work_manifest_iter_create op ctx state =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun repo_config base_ref branch_ref working_branch_ref matches access_control_results ->
          (repo_config, base_ref, branch_ref, working_branch_ref, matches, access_control_results))
        <$> Dv.repo_config ctx state
        <*> Dv.base_ref ctx state
        <*> Dv.branch_ref ctx state
        <*> Dv.working_branch_ref ctx state
        <*> Dv.matches ctx state op
        <*> Dv.access_control_results ctx state op)
      >>= fun ( repo_config,
                base_ref,
                branch_ref,
                working_branch_ref,
                matches,
                access_control_results )
            ->
      let { Terrat_access_control2.R.pass = passed_dirspaces; deny = denied_dirspaces } =
        access_control_results
      in
      Abb.Future.return
        (dirspaceflows_of_changes_with_branch_target
           repo_config
           (CCList.flatten matches.Dv.Matches.all_matches))
      >>= fun all_dirspaceflows ->
      store_dirspaceflows
        ~base_ref
        ~branch_ref
        state.State.request_id
        (Ctx.storage ctx)
        (Event.repo state.State.event)
        all_dirspaceflows
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
      Abbs_future_combinators.List_result.map
        ~f:(fun ((environment, runs_on), dirspaceflows) ->
          let changes =
            let module Dsf = Terrat_change.Dirspaceflow in
            CCList.map
              (fun ({ Dsf.workflow; _ } as dsf) ->
                {
                  dsf with
                  Dsf.workflow = CCOption.map (fun Dsf.Workflow.{ idx; _ } -> idx) workflow;
                })
              dirspaceflows
          in
          Dv.target ctx state
          >>= fun target ->
          Dv.tag_query ctx state
          >>= fun tag_query ->
          let work_manifest =
            make_work_manifest
              ~state
              ~base_ref
              ~branch_ref:working_branch_ref
              ~changes
              ~denied_dirspaces
              ~environment
              ~tag_query
              ~target
              ~runs_on
              ~op
          in
          create_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest
          >>= fun work_manifest ->
          Logs.info (fun m ->
              m
                "%s : CREATED_WORK_MANIFEST : id=%a : base_ref=%s : branch_ref=%s : env=%s : \
                 runs_on=%s"
                state.State.request_id
                Uuidm.pp
                work_manifest.Wm.id
                (S.Api.Ref.to_string base_ref)
                (S.Api.Ref.to_string branch_ref)
                (CCOption.get_or ~default:"" work_manifest.Wm.environment)
                (CCOption.map_or ~default:"" Yojson.Safe.to_string work_manifest.Wm.runs_on));
          run_interactive ctx state (fun () ->
              Dv.client ctx state
              >>= fun client ->
              create_op_commit_checks
                state.State.request_id
                (Ctx.config ctx)
                client
                (Event.account state.State.event)
                (Event.repo state.State.event)
                branch_ref
                work_manifest
                "Queued"
                Terrat_commit_check.Status.Queued
              >>= fun () ->
              maybe_create_pending_apply_commit_checks
                state.State.request_id
                (Ctx.config ctx)
                client
                (Event.account state.State.event)
                (Event.repo state.State.event)
                branch_ref
                (CCList.flatten matches.Dv.Matches.all_matches)
                (Terrat_base_repo_config_v1.apply_requirements repo_config)
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok work_manifest))
        dirspaceflows_by_run_params

    let run_op_work_manifest_iter_update op ctx state work_manifest =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun repo_config base_ref branch_ref working_branch_ref matches access_control_results ->
          (repo_config, base_ref, branch_ref, working_branch_ref, matches, access_control_results))
        <$> Dv.repo_config ctx state
        <*> Dv.base_ref ctx state
        <*> Dv.branch_ref ctx state
        <*> Dv.working_branch_ref ctx state
        <*> Dv.matches ctx state op
        <*> Dv.access_control_results ctx state op)
      >>= fun ( repo_config,
                base_ref,
                branch_ref,
                working_branch_ref,
                matches,
                access_control_results )
            ->
      let { Terrat_access_control2.R.pass = passed_dirspaces; deny = denied_dirspaces } =
        access_control_results
      in
      Abb.Future.return
        (dirspaceflows_of_changes_with_branch_target
           repo_config
           (CCList.flatten matches.Dv.Matches.all_matches))
      >>= fun all_dirspaceflows ->
      store_dirspaceflows
        ~base_ref
        ~branch_ref
        state.State.request_id
        (Ctx.storage ctx)
        (Event.repo state.State.event)
        all_dirspaceflows
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
      Abbs_future_combinators.List_result.map
        ~f:(fun ((environment, runs_on), dirspaceflows) ->
          let changes =
            let module Dsf = Terrat_change.Dirspaceflow in
            CCList.map
              (fun ({ Dsf.workflow; _ } as dsf) ->
                {
                  dsf with
                  Dsf.workflow = CCOption.map (fun Dsf.Workflow.{ idx; _ } -> idx) workflow;
                })
              dirspaceflows
          in
          if CCOption.equal CCString.equal work_manifest.Wm.environment environment then
            let work_manifest =
              {
                work_manifest with
                Wm.changes;
                denied_dirspaces;
                steps =
                  work_manifest.Wm.steps
                  @ [
                      (match op with
                      | `Plan -> Wm.Step.Plan
                      | `Apply | `Apply_force | `Stack_auto_apply -> Wm.Step.Apply
                      | `Apply_autoapprove -> Wm.Step.Unsafe_apply);
                    ];
              }
            in
            update_work_manifest_changes
              state.State.request_id
              (Ctx.storage ctx)
              work_manifest.Wm.id
              changes
            >>= fun () ->
            update_work_manifest_denied_dirspaces
              state.State.request_id
              (Ctx.storage ctx)
              work_manifest.Wm.id
              denied_dirspaces
            >>= fun () ->
            update_work_manifest_steps
              state.State.request_id
              (Ctx.storage ctx)
              work_manifest.Wm.id
              work_manifest.Wm.steps
            >>= fun () ->
            run_interactive ctx state (fun () ->
                Dv.client ctx state
                >>= fun client ->
                create_op_commit_checks
                  state.State.request_id
                  (Ctx.config ctx)
                  client
                  (Event.account state.State.event)
                  (Event.repo state.State.event)
                  branch_ref
                  work_manifest
                  "Queued"
                  Terrat_commit_check.Status.Queued
                >>= fun () ->
                maybe_create_pending_apply_commit_checks
                  state.State.request_id
                  (Ctx.config ctx)
                  client
                  (Event.account state.State.event)
                  (Event.repo state.State.event)
                  branch_ref
                  (CCList.flatten matches.Dv.Matches.all_matches)
                  (Terrat_base_repo_config_v1.apply_requirements repo_config)
                >>= fun () -> Abb.Future.return (Ok state))
            >>= fun _ -> Abb.Future.return (Ok work_manifest)
          else
            Dv.target ctx state
            >>= fun target ->
            Dv.tag_query ctx state
            >>= fun tag_query ->
            let work_manifest =
              make_work_manifest
                ~state
                ~base_ref
                ~branch_ref:working_branch_ref
                ~changes
                ~denied_dirspaces
                ~environment
                ~tag_query
                ~target
                ~runs_on
                ~op
            in
            create_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest
            >>= fun work_manifest ->
            Logs.info (fun m ->
                m
                  "%s : CREATED_WORK_MANIFEST : id=%a : base_ref=%s : branch_ref=%s : env=%s : \
                   runs_on=%s"
                  state.State.request_id
                  Uuidm.pp
                  work_manifest.Wm.id
                  (S.Api.Ref.to_string base_ref)
                  (S.Api.Ref.to_string branch_ref)
                  (CCOption.get_or ~default:"" work_manifest.Wm.environment)
                  (CCOption.map_or ~default:"" Yojson.Safe.to_string work_manifest.Wm.runs_on));
            run_interactive ctx state (fun () ->
                Dv.client ctx state
                >>= fun client ->
                create_op_commit_checks
                  state.State.request_id
                  (Ctx.config ctx)
                  client
                  (Event.account state.State.event)
                  (Event.repo state.State.event)
                  branch_ref
                  work_manifest
                  "Queued"
                  Terrat_commit_check.Status.Queued
                >>= fun () ->
                maybe_create_pending_apply_commit_checks
                  state.State.request_id
                  (Ctx.config ctx)
                  client
                  (Event.account state.State.event)
                  (Event.repo state.State.event)
                  branch_ref
                  (CCList.flatten matches.Dv.Matches.all_matches)
                  (Terrat_base_repo_config_v1.apply_requirements repo_config)
                >>= fun () -> Abb.Future.return (Ok state))
            >>= fun _ -> Abb.Future.return (Ok work_manifest))
        dirspaceflows_by_run_params

    let run_op_work_manifest_iter_run_success op ctx state work_manifest =
      let open Abbs_future_combinators.Infix_result_monad in
      let maybe_publish_autoapply_running request_id client user pull_request = function
        | `Apply | `Apply_autoapprove | `Apply_force ->
            if Event.trigger_type state.State.event = `Auto then
              publish_msg request_id client user pull_request Msg.Autoapply_running
            else Abb.Future.return (Ok ())
        | `Stack_auto_apply | `Plan -> Abb.Future.return (Ok ())
      in
      run_interactive ctx state (fun () ->
          Dv.client ctx state
          >>= fun client ->
          Dv.pull_request ctx state
          >>= fun pull_request ->
          let module Status = Terrat_commit_check.Status in
          create_op_commit_checks
            state.State.request_id
            (Ctx.config ctx)
            client
            (Event.account state.State.event)
            (S.Api.Pull_request.repo pull_request)
            (S.Api.Pull_request.branch_ref pull_request)
            work_manifest
            "Running"
            Status.Running
          >>= fun () ->
          maybe_publish_autoapply_running
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            op
          >>= fun () -> Abb.Future.return (Ok state))
      >>= fun _ -> Abb.Future.return (Ok ())

    let run_op_work_manifest_iter_run_failure ctx state err work_manifest =
      let open Abbs_future_combinators.Infix_result_monad in
      run_interactive ctx state (fun () ->
          Dv.client ctx state
          >>= fun client ->
          Dv.pull_request ctx state
          >>= fun pull_request ->
          let module Status = Terrat_commit_check.Status in
          create_op_commit_checks
            state.State.request_id
            (Ctx.config ctx)
            client
            (Event.account state.State.event)
            (S.Api.Pull_request.repo pull_request)
            (S.Api.Pull_request.branch_ref pull_request)
            work_manifest
            "Failed"
            Status.Failed
          >>= fun () ->
          publish_run_failure
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            err
          >>= fun () -> Abb.Future.return (Ok state))
      >>= fun _ -> Abb.Future.return (Ok ())

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

    let run_op_work_manifest_iter_initiate ctx state _encryption_key run_id sha work_manifest =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      initiate_work_manifest state state.State.request_id (Ctx.storage ctx) run_id sha work_manifest
      >>= function
      | Some { Wm.account; steps; base_ref = _; branch_ref = _; changes; target; _ } -> (
          Dv.base_branch_name ctx state
          >>= fun _base_branch_name ->
          let step =
            match CCList.rev steps with
            | [] -> assert false
            | step :: _ -> step
          in
          let run_kind =
            let module Vcs = Terrat_vcs_provider2 in
            match (target, step) with
            | Vcs.Target.Pr pr, (Wm.Step.Apply | Wm.Step.Plan | Wm.Step.Unsafe_apply) ->
                `Pull_request pr
            | Vcs.Target.Pr _, Wm.Step.Index -> `Index
            | Vcs.Target.Pr _, Wm.Step.Build_config -> `Build_config
            | Vcs.Target.Pr _, Wm.Step.Build_tree -> `Build_tree
            | Vcs.Target.Drift _, _ -> `Drift
          in
          let run_kind_str =
            match run_kind with
            | `Pull_request _ -> "pr"
            | `Index -> "index"
            | `Drift -> "drift"
            | `Build_config -> "build-config"
            | `Build_tree -> "build-tree"
          in
          match step with
          | Wm.Step.Plan ->
              Dv.repo_config ctx state
              >>= fun repo_config ->
              Dv.repo_tree_branch ctx state
              >>= fun repo_tree ->
              Dv.query_repo_tree ctx state
              >>= fun built_repo_tree ->
              let repo_tree =
                let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
                CCOption.map_or
                  ~default:repo_tree
                  (fun built_tree -> CCList.map (fun { I.path; _ } -> path) built_tree)
                  built_repo_tree
              in
              Dv.base_branch_name ctx state
              >>= fun base_branch_name ->
              Dv.branch_name ctx state
              >>= fun branch_name ->
              Dv.query_index ctx state
              >>= fun index ->
              let index =
                CCOption.map_or
                  ~default:Terrat_base_repo_config_v1.Index.empty
                  (fun { Terrat_vcs_provider2.Index.index; _ } -> index)
                  index
              in
              Abbs_time_it.run (log_time state.State.request_id "DERIVE") (fun () ->
                  Abbs_future_combinators.to_result
                  @@ Abb.Thread.run (fun () ->
                      Terrat_base_repo_config_v1.derive
                        ~ctx:
                          (Terrat_base_repo_config_v1.Ctx.make
                             ~dest_branch:(S.Api.Ref.to_string base_branch_name)
                             ~branch:(S.Api.Ref.to_string branch_name)
                             ())
                        ~index
                        ~file_list:repo_tree
                        repo_config))
              >>= fun repo_config ->
              Abb.Future.return (Terrat_change_match3.synthesize_config ~index repo_config)
              >>= fun config ->
              Dv.dirspaces ctx state
              >>= fun (base_dirspaces, dirspaces) ->
              create_token
                (S.Api.Account.Id.to_string @@ S.Api.Account.id account)
                work_manifest.Wm.id
                (Ctx.storage ctx)
              >>= fun token ->
              let run_kind_data =
                let module Rkd = Terrat_api_components.Work_manifest_plan.Run_kind_data in
                let module Rkdpr = Terrat_api_components.Run_kind_data_pull_request in
                match run_kind with
                | `Pull_request pr ->
                    Some
                      (Rkd.Run_kind_data_pull_request
                         { Rkdpr.id = S.Api.Pull_request.Id.to_string (S.Api.Pull_request.id pr) })
                | `Index | `Drift | `Build_config | `Build_tree -> None
              in
              Abb.Future.return
                (Ok
                   (Some
                      Terrat_api_components.(
                        Work_manifest.Work_manifest_plan
                          {
                            Work_manifest_plan.token;
                            api_base_url =
                              Terrat_config.api_base @@ S.Api.Config.config @@ Ctx.config ctx;
                            installation_id = S.Api.Account.Id.to_string @@ S.Api.Account.id account;
                            base_dirspaces;
                            base_ref = S.Api.Ref.to_string base_branch_name;
                            changed_dirspaces = changed_dirspaces config changes;
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
                          })))
          | Wm.Step.(Apply | Unsafe_apply) ->
              Dv.repo_config ctx state
              >>= fun repo_config ->
              Dv.repo_tree_branch ctx state
              >>= fun repo_tree ->
              Dv.query_repo_tree ctx state
              >>= fun built_repo_tree ->
              let repo_tree =
                let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
                CCOption.map_or
                  ~default:repo_tree
                  (fun built_tree -> CCList.map (fun { I.path; _ } -> path) built_tree)
                  built_repo_tree
              in
              Dv.base_branch_name ctx state
              >>= fun base_branch_name ->
              Dv.branch_name ctx state
              >>= fun branch_name ->
              Dv.query_index ctx state
              >>= fun index ->
              let index =
                CCOption.map_or
                  ~default:Terrat_base_repo_config_v1.Index.empty
                  (fun { Terrat_vcs_provider2.Index.index; _ } -> index)
                  index
              in
              Abbs_time_it.run (log_time state.State.request_id "DERIVE") (fun () ->
                  Abbs_future_combinators.to_result
                  @@ Abb.Thread.run (fun () ->
                      Terrat_base_repo_config_v1.derive
                        ~ctx:
                          (Terrat_base_repo_config_v1.Ctx.make
                             ~dest_branch:(S.Api.Ref.to_string base_branch_name)
                             ~branch:(S.Api.Ref.to_string branch_name)
                             ())
                        ~index
                        ~file_list:repo_tree
                        repo_config))
              >>= fun repo_config ->
              Abb.Future.return (Terrat_change_match3.synthesize_config ~index repo_config)
              >>= fun config ->
              create_token
                (S.Api.Account.Id.to_string @@ S.Api.Account.id account)
                work_manifest.Wm.id
                (Ctx.storage ctx)
              >>= fun token ->
              let run_kind_data =
                let module Rkd = Terrat_api_components.Work_manifest_apply.Run_kind_data in
                let module Rkdpr = Terrat_api_components.Run_kind_data_pull_request in
                match run_kind with
                | `Pull_request pr ->
                    Some
                      (Rkd.Run_kind_data_pull_request
                         { Rkdpr.id = S.Api.Pull_request.Id.to_string (S.Api.Pull_request.id pr) })
                | `Index | `Drift | `Build_config | `Build_tree -> None
              in
              Abb.Future.return
                (Ok
                   (Some
                      Terrat_api_components.(
                        Work_manifest.Work_manifest_apply
                          {
                            Work_manifest_apply.token;
                            api_base_url =
                              Terrat_config.api_base @@ S.Api.Config.config @@ Ctx.config ctx;
                            installation_id = S.Api.Account.Id.to_string @@ S.Api.Account.id account;
                            base_ref = S.Api.Ref.to_string base_branch_name;
                            changed_dirspaces = changed_dirspaces config changes;
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
                          })))
          | Wm.Step.Index -> assert false
          | Wm.Step.Build_config -> assert false
          | Wm.Step.Build_tree -> assert false)
      | None -> Abb.Future.return (Ok None)

    let run_op_work_manifest_iter_result op ctx state result work_manifest =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      match result with
      | Terrat_api_components_work_manifest_result.Work_manifest_index_result _ -> assert false
      | Terrat_api_components_work_manifest_result.Work_manifest_build_config_result _ ->
          assert false
      | Terrat_api_components_work_manifest_result.Work_manifest_build_result_failure _ ->
          assert false
      | Terrat_api_components_work_manifest_result.Work_manifest_build_tree_result _ -> assert false
      | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result2 result ->
          Dv.client ctx state
          >>= fun client ->
          Dv.matches ctx state op
          >>= fun matches ->
          let work_manifest_result = S.Work_manifest.result2 result in
          store_tf_operation_result2
            state.State.request_id
            (Ctx.storage ctx)
            work_manifest.Wm.id
            result
          >>= fun () ->
          (if work_manifest.Wm.state <> Wm.State.Aborted then
             (* In the case of an abort, we do not report back to the user, we
                just want to store the results. *)
             run_interactive ctx state (fun () ->
                 Dv.pull_request ctx state
                 >>= fun pull_request ->
                 create_op_commit_checks_of_result
                   state.State.request_id
                   (Ctx.config ctx)
                   client
                   work_manifest.Wm.account
                   (S.Api.Pull_request.repo pull_request)
                   (S.Api.Pull_request.branch_ref pull_request)
                   work_manifest
                   work_manifest_result
                 >>= fun () ->
                 query_account_status
                   state.State.request_id
                   (Ctx.storage ctx)
                   (Event.account state.State.event)
                 >>= fun account_status ->
                 (* TODO: HUGE HACK, redo this later *)
                 let run =
                   let open Abbs_future_combinators.Infix_result_monad in
                   Abbs_future_combinators.Infix_result_app.(
                     (fun client pull_request repo_config repo_tree ->
                       (client, pull_request, repo_config, repo_tree))
                     <$> Dv.client ctx state
                     <*> Dv.pull_request ctx state
                     <*> Dv.repo_config_with_provenance ctx state
                     <*> Dv.repo_tree_branch ctx state)
                   >>= fun (_client, pull_request, (_provenance, repo_config), repo_tree) ->
                   Dv.query_repo_tree ctx state
                   >>= fun built_repo_tree ->
                   let repo_tree =
                     let module I =
                       Terrat_api_components.Work_manifest_build_tree_result.Files.Items
                     in
                     CCOption.map_or
                       ~default:repo_tree
                       (fun built_tree -> CCList.map (fun { I.path; _ } -> path) built_tree)
                       built_repo_tree
                   in
                   Dv.query_index ctx state
                   >>= fun index ->
                   let index =
                     let module R = Terrat_base_repo_config_v1 in
                     match R.indexer repo_config with
                     | { R.Indexer.enabled = true; _ } ->
                         CCOption.map_or
                           ~default:Terrat_base_repo_config_v1.Index.empty
                           (fun { Terrat_vcs_provider2.Index.index; _ } -> index)
                           index
                     | _ -> Terrat_base_repo_config_v1.Index.empty
                   in
                   Abbs_time_it.run (log_time state.State.request_id "DERIVE") (fun () ->
                       Abbs_future_combinators.to_result
                       @@ Abb.Thread.run (fun () ->
                           Terrat_base_repo_config_v1.derive
                             ~ctx:
                               (Terrat_base_repo_config_v1.Ctx.make
                                  ~dest_branch:
                                    (S.Api.Ref.to_string
                                       (S.Api.Pull_request.base_branch_name pull_request))
                                  ~branch:
                                    (S.Api.Ref.to_string
                                       (S.Api.Pull_request.branch_name pull_request))
                                  ())
                             ~index
                             ~file_list:repo_tree
                             repo_config))
                   >>= fun repo_config ->
                   Abb.Future.return (Terrat_change_match3.synthesize_config ~index repo_config)
                   >>= fun synthesized_config ->
                   Abb.Future.return (Ok (repo_config, synthesized_config))
                 in
                 run
                 >>= fun (repo_config, synthesized_config) ->
                 (* TODO: HUGE HACK, redo this later *)
                 publish_msg
                   state.State.request_id
                   client
                   (S.Api.User.to_string @@ Event.user state.State.event)
                   pull_request
                   (Msg.Tf_op_result2
                      {
                        account_status;
                        config = Ctx.config ctx;
                        db = Ctx.storage ctx;
                        is_layered_run = CCList.length matches.Dv.Matches.all_matches > 1;
                        remaining_layers = matches.Dv.Matches.all_unapplied_matches;
                        result;
                        repo_config;
                        synthesized_config;
                        work_manifest;
                      })
                 >>= fun () -> Abb.Future.return (Ok state))
           else Abb.Future.return (Ok state))
          >>= fun state ->
          let module Wmr = Terrat_vcs_provider2.Work_manifest_result in
          if not work_manifest_result.Wmr.overall_success then
            (* If the run failed, then we're done. *)
            Abb.Future.return (Error (`Noop state))
          else Abb.Future.return (Ok ())
      | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result result ->
          Dv.client ctx state
          >>= fun client ->
          let work_manifest_result = S.Work_manifest.result result in
          store_tf_operation_result
            state.State.request_id
            (Ctx.storage ctx)
            work_manifest.Wm.id
            result
          >>= fun () ->
          (if work_manifest.Wm.state <> Wm.State.Aborted then
             run_interactive ctx state (fun () ->
                 Dv.pull_request ctx state
                 >>= fun pull_request ->
                 create_op_commit_checks_of_result
                   state.State.request_id
                   (Ctx.config ctx)
                   client
                   work_manifest.Wm.account
                   (S.Api.Pull_request.repo pull_request)
                   (S.Api.Pull_request.branch_ref pull_request)
                   work_manifest
                   work_manifest_result
                 >>= fun () -> Abb.Future.return (Ok state))
           else Abb.Future.return (Ok state))
          >>= fun state ->
          let module Wmr = Terrat_vcs_provider2.Work_manifest_result in
          if not work_manifest_result.Wmr.overall_success then
            (* If the run failed, then we're done. *)
            Abb.Future.return (Error (`Noop state))
          else Abb.Future.return (Ok ())

    let run_op_work_manifest_plan_iter_store ctx state dirspace data has_changes work_manifest_id =
      store_plan
        state.State.request_id
        (Ctx.storage ctx)
        work_manifest_id
        dirspace
        (Base64.decode_exn data)
        has_changes

    let run_op_work_manifest_plan_iter_fetch ctx state dirspace work_manifest_id =
      query_plan state.State.request_id (Ctx.storage ctx) work_manifest_id dirspace
  end

  module F = struct
    (* Checkpoint commits the existing transaction the flow is running in and
       immediate creates a new one.  This is useful when cloning, to ensure each
       clone gets its own transaction.  Additionally, it can be useful if a
       value used by many transactions has been updated (for example something
       an the installation level) but we do not want to hold up any other
       transactions that may touch that value because we are done with it.

       Some care does need to be taken with checkpoint.  We use transactions to
       coordinate between requests for the same flow.  Checkpointing could let
       other waiting transactions start even though the idea behind
       checkpointing is to immediately start a new transaction in side the same
       flow execution.  Now we have an unexpected interleaving between
       transactions that we did not want.

       As such, ensure that, when checkpointing, that the flow has not initiated
       concurrent work that could intervleav unexpected.  That is, all compute
       operations are either done or not started.

       If the goal is to reset context (for example caches), look at returning a
       [`Reset_ctx], which resets the context and resets caches. *)
    let checkpoint _ctx state = Abb.Future.return (Error (`Checkpoint state))

    let wait_for_initiate _ctx state =
      match state.State.input with
      | Some (State.Io.I.Work_manifest_initiate _) -> Abb.Future.return (Ok state)
      | _ ->
          Abb.Future.return
            (Error (`Yield { state with State.st = State.St.Waiting_for_work_manifest_initiate }))

    let store_account_repository ctx state =
      match state.State.event with
      | Event.Pull_request_open { account; repo; _ }
      | Event.Pull_request_close { account; repo; _ }
      | Event.Pull_request_sync { account; repo; _ }
      | Event.Pull_request_ready_for_review { account; repo; _ }
      | Event.Pull_request_comment { account; repo; _ }
      | Event.Push { account; repo; _ }
      | Event.Run_drift { account; repo; _ } ->
          let open Abbs_future_combinators.Infix_result_monad in
          store_account_repository state.State.request_id (Ctx.storage ctx) account repo
          >>= fun () ->
          (* Checkpoint here so that we do not hold up any other runs for this
             repository with a db lock *)
          Abb.Future.return (Error (`Checkpoint state))
      | Event.Run_scheduled_drift -> Abb.Future.return (Ok state)

    let test_account_status ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      query_account_status
        state.State.request_id
        (Ctx.storage ctx)
        (Event.account state.State.event)
      >>= function
      | `Active | `Trial_ending _ -> Abb.Future.return (Ok (Id.Account_enabled, state))
      | `Expired -> Abb.Future.return (Ok (Id.Account_expired, state))
      | `Disabled -> Abb.Future.return (Ok (Id.Account_disabled, state))

    let account_disabled _ state =
      Prmths.Counter.inc_one Metrics.op_on_account_disabled_total;
      Logs.info (fun m -> m "%s : ACCOUNT_DISABLED" state.State.request_id);
      Abb.Future.return (Error (`Noop state))

    let test_event_kind _ctx state =
      match state.State.event with
      | Event.Pull_request_open _
      | Event.Pull_request_close _
      | Event.Pull_request_sync _
      | Event.Pull_request_ready_for_review _
      | Event.Pull_request_comment
          { comment = Terrat_comment.(Plan _ | Apply _ | Apply_autoapprove _ | Apply_force _); _ }
        -> Abb.Future.return (Ok (Id.Event_kind_op, state))
      | Event.Pull_request_comment { comment = Terrat_comment.Help; _ } ->
          Abb.Future.return (Ok (Id.Event_kind_help, state))
      | Event.Pull_request_comment { comment = Terrat_comment.Unlock _; _ } ->
          Abb.Future.return (Ok (Id.Event_kind_unlock, state))
      | Event.Pull_request_comment { comment = Terrat_comment.Repo_config; _ } ->
          Abb.Future.return (Ok (Id.Event_kind_repo_config, state))
      | Event.Pull_request_comment { comment = Terrat_comment.Feedback _; _ } ->
          Abb.Future.return (Ok (Id.Event_kind_feedback, state))
      | Event.Pull_request_comment { comment = Terrat_comment.Index; _ } ->
          Abb.Future.return (Ok (Id.Event_kind_index, state))
      | Event.Pull_request_comment { comment = Terrat_comment.Gate_approval _; _ } ->
          Abb.Future.return (Ok (Id.Event_kind_gate_approval, state))
      | Event.Push _ -> Abb.Future.return (Ok (Id.Event_kind_push, state))
      | Event.Run_scheduled_drift -> Abb.Future.return (Ok (Id.Event_kind_run_drift, state))
      | Event.Run_drift _ ->
          (* This event type is only created internally *)
          assert false

    let test_index_required ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.repo_config ctx state
      >>= fun repo_config ->
      Dv.query_index ctx state
      >>= fun index ->
      let module R = Terrat_base_repo_config_v1 in
      match (R.indexer repo_config, index) with
      | { R.Indexer.enabled = true; _ }, None -> Abb.Future.return (Ok (Id.Index_required, state))
      | _ -> Abb.Future.return (Ok (Id.Index_not_required, state))

    let run_index_work_manifest_iter =
      H.eval_work_manifest_iter
        ~name:"INDEX"
        ~create:(fun ctx state ->
          let module Wm = Terrat_work_manifest3 in
          let open Abbs_future_combinators.Infix_result_monad in
          let account = Event.account state.State.event in
          let repo = Event.repo state.State.event in
          Dv.client ctx state
          >>= fun client ->
          Dv.base_ref ctx state
          >>= fun base_ref' ->
          Dv.working_branch_ref ctx state
          >>= fun working_branch_ref' ->
          Dv.target ctx state
          >>= fun target ->
          let work_manifest =
            {
              Wm.account;
              base_ref = S.Api.Ref.to_string base_ref';
              branch = None;
              branch_ref = S.Api.Ref.to_string working_branch_ref';
              changes = [];
              completed_at = None;
              created_at = ();
              denied_dirspaces = [];
              environment = None;
              id = ();
              initiator = Event.initiator state.State.event;
              run_id = ();
              runs_on = None;
              state = ();
              steps = [ Wm.Step.Index ];
              tag_query = Terrat_tag_query.any;
              target;
            }
          in
          create_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest
          >>= fun work_manifest ->
          H.run_interactive ctx state (fun () ->
              let module Status = Terrat_commit_check.Status in
              Dv.branch_ref ctx state
              >>= fun branch_ref' ->
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Queued"
                  ~status:Status.Queued
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam index"
              in
              create_commit_checks state.State.request_id client repo branch_ref' [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun state ->
          Logs.info (fun m ->
              m
                "%s : CREATED_WORK_MANIFEST : id=%a : base_ref=%s : branch_ref=%s : runs_on=%s"
                state.State.request_id
                Uuidm.pp
                work_manifest.Wm.id
                (S.Api.Ref.to_string base_ref')
                (S.Api.Ref.to_string working_branch_ref')
                (CCOption.map_or ~default:"" Yojson.Safe.to_string work_manifest.Wm.runs_on));
          Abb.Future.return (Ok [ work_manifest ]))
        ~update:(fun ctx state work_manifest ->
          let module Wm = Terrat_work_manifest3 in
          let open Abbs_future_combinators.Infix_result_monad in
          let work_manifest =
            { work_manifest with Wm.steps = work_manifest.Wm.steps @ [ Wm.Step.Index ] }
          in
          update_work_manifest_steps
            state.State.request_id
            (Ctx.storage ctx)
            work_manifest.Wm.id
            work_manifest.Wm.steps
          >>= fun () ->
          H.run_interactive ctx state (fun () ->
              let module Status = Terrat_commit_check.Status in
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.branch_ref ctx state
              >>= fun branch_ref' ->
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Queued"
                  ~status:Status.Queued
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam index"
              in
              create_commit_checks state.State.request_id client repo branch_ref' [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok [ work_manifest ]))
        ~run_success:(fun ctx state work_manifest ->
          let open Abbs_future_combinators.Infix_result_monad in
          H.run_interactive ctx state (fun () ->
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.pull_request ctx state
              >>= fun pull_request ->
              let module Status = Terrat_commit_check.Status in
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Running"
                  ~status:Status.Running
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam index"
              in
              create_commit_checks
                state.State.request_id
                client
                repo
                (S.Api.Pull_request.branch_ref pull_request)
                [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok ()))
        ~run_failure:(fun ctx state err work_manifest ->
          let open Abbs_future_combinators.Infix_result_monad in
          H.run_interactive ctx state (fun () ->
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.pull_request ctx state
              >>= fun pull_request ->
              let module Status = Terrat_commit_check.Status in
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Failed"
                  ~status:Status.Failed
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam index"
              in
              create_commit_checks
                state.State.request_id
                client
                repo
                (S.Api.Pull_request.branch_ref pull_request)
                [ check ]
              >>= fun () ->
              H.publish_run_failure
                state.State.request_id
                client
                (S.Api.User.to_string @@ Event.user state.State.event)
                pull_request
                err
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok ()))
        ~initiate:H.generate_index_work_manifest_initiate
        ~result:H.generate_index_work_manifest_result
        ~fallthrough:H.log_state_err_iter

    let store_stacks ctx state =
      H.run_interactive ctx state (fun () ->
          let open Abbs_future_combinators.Infix_result_monad in
          let account = Event.account state.State.event in
          let repo = Event.repo state.State.event in
          Dv.repo_config ctx state
          >>= fun repo_config ->
          Dv.repo_tree_branch ctx state
          >>= fun repo_tree ->
          Dv.base_branch_name ctx state
          >>= fun base_branch_name ->
          Dv.branch_name ctx state
          >>= fun branch_name ->
          Dv.query_index ctx state
          >>= fun index ->
          let index =
            CCOption.map_or
              ~default:Terrat_base_repo_config_v1.Index.empty
              (fun { Terrat_vcs_provider2.Index.index; _ } -> index)
              index
          in
          Dv.query_repo_tree ctx state
          >>= fun built_repo_tree ->
          let repo_tree =
            let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
            CCOption.map_or
              ~default:repo_tree
              (fun built_tree -> CCList.map (fun { I.path; _ } -> path) built_tree)
              built_repo_tree
          in
          Abbs_time_it.run (log_time state.State.request_id "DERIVE") (fun () ->
              Abbs_future_combinators.to_result
              @@ Abb.Thread.run (fun () ->
                  Terrat_base_repo_config_v1.derive
                    ~ctx:
                      (Terrat_base_repo_config_v1.Ctx.make
                         ~dest_branch:(S.Api.Ref.to_string base_branch_name)
                         ~branch:(S.Api.Ref.to_string branch_name)
                         ())
                    ~index
                    ~file_list:repo_tree
                    repo_config))
          >>= fun repo_config ->
          Abb.Future.return (Terrat_change_match3.synthesize_config ~index repo_config)
          >>= fun config ->
          Dv.pull_request ctx state
          >>= fun pull_request ->
          S.Stacks.store
            ~request_id:(Ctx.request_id ctx)
            ~installation_id:(S.Api.Account.id account)
            ~repo_id:(S.Api.Repo.id repo)
            ~pull_request_id:(S.Api.Pull_request.id pull_request)
            config
            (Ctx.storage ctx)
          >>= fun () -> Abb.Future.return (Ok state))

    (* This is run for its side effect.  If the repo config is not valid, the
       surrounding [eval_step] will publish the error. *)
    let test_repo_config_validity ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.repo_config ctx state >>= fun _ -> Abb.Future.return (Ok state)

    let publish_repo_config ctx state =
      let run =
        let open Abbs_future_combinators.Infix_result_monad in
        Abbs_future_combinators.Infix_result_app.(
          (fun client pull_request repo_config repo_tree ->
            (client, pull_request, repo_config, repo_tree))
          <$> Dv.client ctx state
          <*> Dv.pull_request ctx state
          <*> Dv.repo_config_with_provenance ctx state
          <*> Dv.repo_tree_branch ctx state)
        >>= fun (client, pull_request, (provenance, repo_config), repo_tree) ->
        Dv.query_repo_tree ctx state
        >>= fun built_repo_tree ->
        let repo_tree =
          let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
          CCOption.map_or
            ~default:repo_tree
            (fun built_tree -> CCList.map (fun { I.path; _ } -> path) built_tree)
            built_repo_tree
        in
        Dv.query_index ctx state
        >>= fun index ->
        let index =
          let module R = Terrat_base_repo_config_v1 in
          match R.indexer repo_config with
          | { R.Indexer.enabled = true; _ } ->
              CCOption.map_or
                ~default:Terrat_base_repo_config_v1.Index.empty
                (fun { Terrat_vcs_provider2.Index.index; _ } -> index)
                index
          | _ -> Terrat_base_repo_config_v1.Index.empty
        in
        Abbs_time_it.run (log_time state.State.request_id "DERIVE") (fun () ->
            Abbs_future_combinators.to_result
            @@ Abb.Thread.run (fun () ->
                Terrat_base_repo_config_v1.derive
                  ~ctx:
                    (Terrat_base_repo_config_v1.Ctx.make
                       ~dest_branch:
                         (S.Api.Ref.to_string (S.Api.Pull_request.base_branch_name pull_request))
                       ~branch:(S.Api.Ref.to_string (S.Api.Pull_request.branch_name pull_request))
                       ())
                  ~index
                  ~file_list:repo_tree
                  repo_config))
        >>= fun repo_config ->
        match Terrat_change_match3.synthesize_config ~index repo_config with
        | Ok _config ->
            publish_msg
              state.State.request_id
              client
              (S.Api.User.to_string @@ Event.user state.State.event)
              pull_request
              (Msg.Repo_config (provenance, repo_config))
            >>= fun () -> Abb.Future.return (Ok state)
        | Error (#Terrat_change_match3.synthesize_config_err as err) ->
            Abbs_future_combinators.Result.ignore
              (publish_msg
                 state.State.request_id
                 client
                 (S.Api.User.to_string @@ Event.user state.State.event)
                 pull_request
                 (Msg.Synthesize_config_err err))
            >>= fun () -> Abb.Future.return (Error `Error)
      in
      let open Abb.Future.Infix_monad in
      run >>= fun _ -> Abb.Future.return (Ok state)

    let publish_help ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.client ctx state
      >>= fun client ->
      Dv.pull_request ctx state
      >>= fun pull_request ->
      publish_msg
        state.State.request_id
        client
        (S.Api.User.to_string @@ Event.user state.State.event)
        pull_request
        Msg.Help
      >>= fun () -> Abb.Future.return (Ok state)

    let publish_index ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.client ctx state
      >>= fun client ->
      Dv.pull_request ctx state
      >>= fun pull_request ->
      Dv.query_index ctx state
      >>= function
      | Some index ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Index_complete
               ( index.Terrat_vcs_provider2.Index.success,
                 CCList.map
                   (fun { Terrat_vcs_provider2.Index.Failure.file; line_num; error } ->
                     (file, line_num, error))
                   index.Terrat_vcs_provider2.Index.failures ))
          >>= fun () -> Abb.Future.return (Ok state)
      | None -> assert false

    let check_enabled_in_repo_config ctx state =
      let module V1 = Terrat_base_repo_config_v1 in
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.repo_config ctx state
      >>= fun repo_config ->
      if V1.enabled repo_config then Abb.Future.return (Ok state)
      else Abb.Future.return (Error (`Noop state))

    let react_to_comment ctx state =
      match state.State.event with
      | Event.Pull_request_comment { comment_id; _ } ->
          let open Abbs_future_combinators.Infix_result_monad in
          Dv.client ctx state
          >>= fun client ->
          Dv.pull_request ctx state
          >>= fun pull_request ->
          react_to_comment state.State.request_id client pull_request comment_id
          >>= fun () -> Abb.Future.return (Ok state)
      | Event.Pull_request_open _
      | Event.Pull_request_close _
      | Event.Pull_request_sync _
      | Event.Pull_request_ready_for_review _
      | Event.Push _
      | Event.Run_scheduled_drift
      | Event.Run_drift _ -> Abb.Future.return (Ok state)

    let test_batch_runs_enabled ctx state =
      let module V1 = Terrat_base_repo_config_v1 in
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.repo_config ctx state
      >>= fun repo_config ->
      let br = V1.batch_runs repo_config in
      if br.V1.Batch_runs.enabled then Abb.Future.return (Ok (Id.Batch_runs_enabled, state))
      else Abb.Future.return (Ok (Id.Batch_runs_disabled, state))

    let store_pull_request ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.client ctx state
      >>= fun _client ->
      Dv.pull_request ctx state
      >>= fun pull_request ->
      store_pull_request state.State.request_id (Ctx.storage ctx) pull_request
      >>= fun () -> Abb.Future.return (Ok state)

    let record_feedback _ctx state =
      match state.State.event with
      | Event.Pull_request_comment
          { account; repo; user; comment = Terrat_comment.Feedback feedback; pull_request_id; _ } ->
          Logs.info (fun m ->
              m
                "%s : FEEDBACK : account=%s : repo=%s : pull_number=%s : user=%s : %s"
                state.State.request_id
                (S.Api.Account.to_string account)
                (S.Api.Repo.to_string repo)
                (S.Api.Pull_request.Id.to_string pull_request_id)
                (S.Api.User.to_string user)
                feedback);
          Abb.Future.return (Ok state)
      | Event.Pull_request_comment _
      | Event.Pull_request_open _
      | Event.Pull_request_close _
      | Event.Pull_request_sync _
      | Event.Pull_request_ready_for_review _
      | Event.Push _
      | Event.Run_scheduled_drift
      | Event.Run_drift _ ->
          Logs.err (fun m -> m "%s : NOT_FEEDBACK_COMMENT" state.State.request_id);
          Abb.Future.return (Ok state)

    let complete_work_manifest ctx state =
      let maybe_complete_work_manifest work_manifest_id =
        let module Wm = Terrat_work_manifest3 in
        let open Abbs_future_combinators.Infix_result_monad in
        query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
        >>= function
        | Some { Wm.state = Wm.State.(Queued | Running); _ } ->
            update_work_manifest_state
              state.State.request_id
              (Ctx.storage ctx)
              work_manifest_id
              Wm.State.Completed
        | Some _ | None -> Abb.Future.return (Ok ())
      in
      match (state.State.st, state.State.input, state.State.work_manifest_id) with
      | (State.St.Initial | State.St.Work_manifest_completed), _, Some work_manifest_id ->
          let open Abbs_future_combinators.Infix_result_monad in
          maybe_complete_work_manifest work_manifest_id
          >>= fun () ->
          Abb.Future.return
            (Error (`Yield { state with State.st = State.St.Waiting_for_work_manifest_initiate }))
      | ( State.St.Waiting_for_work_manifest_initiate,
          Some (State.Io.I.Work_manifest_initiate { p; _ }),
          Some work_manifest_id ) ->
          let module D = Terrat_api_components.Work_manifest_done in
          let response =
            Terrat_api_components.Work_manifest.Work_manifest_done { D.type_ = `Done }
          in
          let open Abb.Future.Infix_monad in
          Abb.Future.Promise.set p (Ok (Some response))
          >>= fun () ->
          let open Abbs_future_combinators.Infix_result_monad in
          maybe_complete_work_manifest work_manifest_id
          >>= fun () ->
          Abb.Future.return
            (Ok
               {
                 state with
                 State.st = State.St.Initial;
                 input = None;
                 output = None;
                 work_manifest_id = None;
               })
      | _, Some (State.Io.I.Work_manifest_failure _), _ | _, _, None ->
          (* No work manifest was run so ignore *)
          Abb.Future.return (Ok state)
      | _, _, _ ->
          H.log_state_err
            state.State.request_id
            state.State.st
            state.State.input
            state.State.work_manifest_id;
          assert false

    let unlock ctx state =
      let repo = Event.repo state.State.event in
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
      let run state client pull_request unlock_ids =
        let open Abbs_future_combinators.Infix_result_monad in
        Dv.repo_config ctx state
        >>= fun _repo_config ->
        fetch_remote_repo state.State.request_id client repo
        >>= fun _remote_repo ->
        Dv.access_control ctx state
        >>= fun access_control ->
        let open Abb.Future.Infix_monad in
        Access_control_engine.eval_pr_operation access_control `Unlock
        >>= function
        | Ok None ->
            Prmths.Counter.inc_one (Metrics.access_control_total ~t:"unlock" ~r:"allowed");
            let open Abbs_future_combinators.Infix_result_monad in
            Abbs_future_combinators.List_result.iter
              ~f:(unlock state.State.request_id (Ctx.storage ctx) repo)
              unlock_ids
            >>= fun () ->
            publish_msg
              state.State.request_id
              client
              (S.Api.User.to_string @@ Event.user state.State.event)
              pull_request
              Msg.Unlock_success
            >>= fun () -> Abb.Future.return (Ok state)
        | Ok (Some match_list) ->
            let open Abbs_future_combinators.Infix_result_monad in
            Prmths.Counter.inc_one (Metrics.access_control_total ~t:"unlock" ~r:"denied");
            publish_msg
              state.State.request_id
              client
              (S.Api.User.to_string @@ Event.user state.State.event)
              pull_request
              (Msg.Access_control_denied
                 (Access_control_engine.policy_branch access_control, `Unlock match_list))
            >>= fun () -> Abb.Future.return (Ok state)
        | Error `Error ->
            let open Abbs_future_combinators.Infix_result_monad in
            Prmths.Counter.inc_one (Metrics.access_control_total ~t:"unlock" ~r:"denied");
            publish_msg
              state.State.request_id
              client
              (S.Api.User.to_string @@ Event.user state.State.event)
              pull_request
              (Msg.Access_control_denied
                 (Access_control_engine.policy_branch access_control, `Lookup_err))
            >>= fun () -> Abb.Future.return (Error `Error)
      in
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.client ctx state
      >>= fun client ->
      Dv.pull_request ctx state
      >>= fun pull_request ->
      let open Abb.Future.Infix_monad in
      Abb.Future.return
        (parse_unlock_ids (S.Api.Pull_request.id pull_request) (Event.unlock_ids state.State.event))
      >>= function
      | Ok unlock_ids -> (
          run state client pull_request unlock_ids
          >>= function
          | Ok _ as r -> Abb.Future.return r
          | Error (#Repo_config.fetch_err as err) -> Abb.Future.return (Error err))
      | Error (`Invalid_unlock_id s) ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Invalid_unlock_id s)
          >>= fun _ -> Abb.Future.return (Error `Error)

    let test_op_kind _ctx state =
      match state.State.event with
      | Event.Pull_request_open _
      | Event.Pull_request_sync _
      | Event.Pull_request_ready_for_review _
      | Event.Pull_request_comment { comment = Terrat_comment.Plan _; _ } ->
          Abb.Future.return (Ok (Id.Op_kind_plan, state))
      | Event.Pull_request_comment { comment = Terrat_comment.Apply _; _ } ->
          Abb.Future.return (Ok (Id.Op_kind_apply, state))
      | Event.Pull_request_comment { comment = Terrat_comment.Apply_autoapprove _; _ } ->
          Abb.Future.return (Ok (Id.Op_kind_apply_autoapprove, state))
      | Event.Pull_request_comment { comment = Terrat_comment.Apply_force _; _ } ->
          Abb.Future.return (Ok (Id.Op_kind_apply_force, state))
      | Event.Pull_request_close _ -> Abb.Future.return (Ok (Id.Op_kind_apply, state))
      | Event.Run_scheduled_drift -> Abb.Future.return (Ok (Id.Event_kind_run_drift, state))
      | Event.Pull_request_comment
          {
            comment =
              Terrat_comment.(Feedback _ | Help | Repo_config | Unlock _ | Index | Gate_approval _);
            _;
          } -> assert false
      | Event.Push _ | Event.Run_drift _ -> assert false

    let check_pull_request_state ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.pull_request ctx state
      >>= fun pull_request ->
      match S.Api.Pull_request.state pull_request with
      | Terrat_pull_request.State.Closed ->
          Logs.info (fun m -> m "%s : NOOP : PR_CLOSED" state.State.request_id);
          let repo = Event.repo state.State.event in
          Dv.client ctx state
          >>= fun client ->
          Dv.branch_ref ctx state
          >>= fun ref_ ->
          fetch_commit_checks state.State.request_id client repo ref_
          >>= fun commit_checks ->
          let module Ch = Terrat_commit_check in
          let unfinished_checks =
            CCList.filter_map
              (function
                | { Ch.status = Ch.Status.(Completed | Failed | Canceled); _ } -> None
                | { Ch.status = Ch.Status.(Queued | Running); _ } as c ->
                    Some { c with Ch.status = Ch.Status.Canceled })
              commit_checks
          in
          create_commit_checks state.State.request_id client repo ref_ unfinished_checks
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | Terrat_pull_request.State.(Open _ | Merged _) -> Abb.Future.return (Ok state)

    let check_non_empty_matches ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.access_control_results ctx state `Plan
      >>= fun { Terrat_access_control2.R.pass = working_set_matches; _ } ->
      let trigger_type = Event.trigger_type state.State.event in
      match (working_set_matches, trigger_type) with
      | [], `Auto ->
          Logs.info (fun m -> m "%s : NOOP : AUTOPLAN_NO_MATCHES" state.State.request_id);
          Abbs_future_combinators.Infix_result_app.(
            (fun pull_request repo_config matches base_ref branch_ref ->
              (pull_request, repo_config, matches, base_ref, branch_ref))
            <$> Dv.pull_request ctx state
            <*> Dv.repo_config ctx state
            <*> Dv.matches ctx state `Plan
            <*> Dv.base_ref ctx state
            <*> Dv.branch_ref ctx state)
          >>= fun (pull_request, repo_config, matches, base_ref, branch_ref) ->
          Abb.Future.return
            (H.dirspaceflows_of_changes_with_branch_target
               repo_config
               (CCList.flatten matches.Dv.Matches.all_matches))
          >>= fun all_dirspaceflows ->
          (* Ensure that even if we don't run anything, all of the dirspace
             flows are stored.  This is important if autoplan is off but the
             pull request is merged, we need the record that there were changes
             we want to act on in the change. *)
          store_dirspaceflows
            ~base_ref
            ~branch_ref
            state.State.request_id
            (Ctx.storage ctx)
            (Event.repo state.State.event)
            all_dirspaceflows
          >>= fun () ->
          Dv.client ctx state
          >>= fun client ->
          (if CCList.is_empty matches.Dv.Matches.all_unapplied_matches then
             H.maybe_create_completed_apply_check
               state.State.request_id
               (Ctx.config ctx)
               client
               (Event.account state.State.event)
               repo_config
               (Event.repo state.State.event)
               pull_request
           else Abb.Future.return (Ok ()))
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | [], `Manual ->
          Logs.info (fun m -> m "%s : PLAN_NO_MATCHING_DIRSPACES" state.State.request_id);
          Dv.pull_request ctx state
          >>= fun pull_request ->
          Dv.client ctx state
          >>= fun client ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            Msg.Plan_no_matching_dirspaces
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | _ :: _, _ -> Abb.Future.return (Ok state)

    let check_account_status_expired ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      query_account_status
        state.State.request_id
        (Ctx.storage ctx)
        (Event.account state.State.event)
      >>= function
      | `Active -> Abb.Future.return (Ok state)
      | `Trial_ending duration ->
          Logs.info (fun m ->
              m
                "EVALUATOR ; %s : TRIAL_ENDING : days=%d"
                state.State.request_id
                (Duration.to_day duration));
          Abb.Future.return (Ok state)
      | `Expired | `Disabled ->
          Logs.info (fun m -> m "%s : ACCOUNT_EXPIRED" state.State.request_id);
          Dv.client ctx state
          >>= fun client ->
          Dv.pull_request ctx state
          >>= fun pull_request ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            Msg.Account_expired
          >>= fun () -> Abb.Future.return (Error (`Noop state))

    let check_account_tier ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      H.run_interactive ctx state (fun () ->
          let user = Event.user state.State.event in
          let account = Event.account state.State.event in
          Abbs_time_it.run
            (fun time ->
              Logs.info (fun m ->
                  m
                    "%s : TIER_CHECK : account=%s : user=%s : time=%f"
                    state.State.request_id
                    (S.Api.Account.Id.to_string @@ S.Api.Account.id account)
                    (S.Api.User.Id.to_string @@ S.Api.User.id user)
                    time))
            (fun () -> S.Tier.check ~request_id:state.State.request_id user account ctx.Ctx.storage)
          >>= function
          | None -> Abb.Future.return (Ok state)
          | Some checks ->
              Dv.client ctx state
              >>= fun client ->
              Dv.pull_request ctx state
              >>= fun pull_request ->
              publish_msg
                state.State.request_id
                client
                (S.Api.User.to_string user)
                pull_request
                (Msg.Tier_check checks)
              >>= fun () -> Abb.Future.return (Error `Silent_failure))

    let check_access_control_ci_change ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun access_control pull_request -> (access_control, pull_request))
        <$> Dv.access_control ctx state
        <*> Dv.pull_request ctx state)
      >>= fun (access_control, pull_request) ->
      let open Abb.Future.Infix_monad in
      Access_control_engine.eval_ci_change access_control (S.Api.Pull_request.diff pull_request)
      >>= function
      | Ok None -> Abb.Future.return (Ok state)
      | Ok (Some match_list) ->
          let open Abbs_future_combinators.Infix_result_monad in
          Dv.client ctx state
          >>= fun client ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `Ci_config_update match_list))
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | Error `Error ->
          let open Abbs_future_combinators.Infix_result_monad in
          Abbs_future_combinators.Infix_result_app.(
            (fun client pull_request -> (client, pull_request))
            <$> Dv.client ctx state
            <*> Dv.pull_request ctx state)
          >>= fun (client, pull_request) ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `Lookup_err))
          >>= fun () -> Abb.Future.return (Error (`Noop state))

    let check_access_control_files ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun access_control pull_request -> (access_control, pull_request))
        <$> Dv.access_control ctx state
        <*> Dv.pull_request ctx state)
      >>= fun (access_control, pull_request) ->
      let open Abb.Future.Infix_monad in
      Access_control_engine.eval_files access_control (S.Api.Pull_request.diff pull_request)
      >>= function
      | Ok None -> Abb.Future.return (Ok state)
      | Ok (Some (fname, match_list)) ->
          let open Abbs_future_combinators.Infix_result_monad in
          Dv.client ctx state
          >>= fun client ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `Files (fname, match_list)))
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | Error `Error ->
          let open Abbs_future_combinators.Infix_result_monad in
          Abbs_future_combinators.Infix_result_app.(
            (fun client pull_request -> (client, pull_request))
            <$> Dv.client ctx state
            <*> Dv.pull_request ctx state)
          >>= fun (client, pull_request) ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `Lookup_err))
          >>= fun () -> Abb.Future.return (Error (`Noop state))

    let check_access_control_repo_config ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun access_control pull_request -> (access_control, pull_request))
        <$> Dv.access_control ctx state
        <*> Dv.pull_request ctx state)
      >>= fun (access_control, pull_request) ->
      let open Abb.Future.Infix_monad in
      Access_control_engine.eval_repo_config access_control (S.Api.Pull_request.diff pull_request)
      >>= function
      | Ok None -> Abb.Future.return (Ok state)
      | Ok (Some match_list) ->
          let open Abbs_future_combinators.Infix_result_monad in
          Dv.client ctx state
          >>= fun client ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               ( Access_control_engine.policy_branch access_control,
                 `Terrateam_config_update match_list ))
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | Error `Error ->
          let open Abbs_future_combinators.Infix_result_monad in
          Abbs_future_combinators.Infix_result_app.(
            (fun client pull_request -> (client, pull_request))
            <$> Dv.client ctx state
            <*> Dv.pull_request ctx state)
          >>= fun (client, pull_request) ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `Lookup_err))
          >>= fun () -> Abb.Future.return (Error (`Noop state))

    let check_valid_destination_branch ctx state =
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
        CCOption.get_exn_or ("pattern_glob " ^ s ^ " " ^ pattern) (Lua_pattern.of_string pattern)
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
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun client pull_request repo_config -> (client, pull_request, repo_config))
        <$> Dv.client ctx state
        <*> Dv.pull_request ctx state
        <*> Dv.repo_config ctx state)
      >>= fun (client, pull_request, repo_config) ->
      fetch_remote_repo state.State.request_id client (S.Api.Pull_request.repo pull_request)
      >>= fun remote_repo ->
      let default_branch = S.Api.Remote_repo.default_branch remote_repo in
      let base_branch_name = S.Api.Pull_request.base_branch_name pull_request in
      let branch_name = S.Api.Pull_request.branch_name pull_request in
      let valid_branches =
        match Rc.destination_branches repo_config with
        | [] -> [ Ds.make ~branch:(S.Api.Ref.to_string default_branch) () ]
        | ds -> ds
      in
      let dest_branch = CCString.lowercase_ascii (S.Api.Ref.to_string base_branch_name) in
      let source_branch = CCString.lowercase_ascii (S.Api.Ref.to_string branch_name) in
      match eval_destination_branch_match dest_branch source_branch valid_branches with
      | Ok () -> Abb.Future.return (Ok state)
      | Error `No_matching_dest_branch -> (
          match Event.trigger_type state.State.event with
          | `Auto ->
              Logs.info (fun m ->
                  m
                    "%s : DEST_BRANCH_NOT_VALID : branch=%s"
                    state.State.request_id
                    (S.Api.Ref.to_string base_branch_name));
              Abb.Future.return (Error (`Noop state))
          | `Manual ->
              let open Abbs_future_combinators.Infix_result_monad in
              Logs.info (fun m ->
                  m
                    "%s : DEST_BRANCH_NOT_VALID_BRANCH_EXPLICIT : branch=%s"
                    state.State.request_id
                    (S.Api.Ref.to_string base_branch_name));
              publish_msg
                state.State.request_id
                client
                (S.Api.User.to_string @@ Event.user state.State.event)
                pull_request
                (Msg.Dest_branch_no_match pull_request)
              >>= fun () -> Abb.Future.return (Error `Error))
      | Error `No_matching_source_branch -> (
          match Event.trigger_type state.State.event with
          | `Auto ->
              Logs.info (fun m ->
                  m
                    "%s : SOURCE_BRANCH_NOT_VALID : branch=%s"
                    state.State.request_id
                    (S.Api.Ref.to_string branch_name));
              Abb.Future.return (Error (`Noop state))
          | `Manual ->
              let open Abbs_future_combinators.Infix_result_monad in
              Logs.info (fun m ->
                  m
                    "%s : SOURCE_BRANCH_NOT_VALID_BRANCH_EXPLICIT : branch=%s"
                    state.State.request_id
                    (S.Api.Ref.to_string branch_name));
              publish_msg
                state.State.request_id
                client
                (S.Api.User.to_string @@ Event.user state.State.event)
                pull_request
                (Msg.Dest_branch_no_match pull_request)
              >>= fun () -> Abb.Future.return (Error (`Noop state)))

    let check_access_control_plan ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.access_control ctx state
      >>= fun access_control ->
      let open Abb.Future.Infix_monad in
      Dv.tf_operation_access_control_evaluation ctx state `Plan
      >>= function
      | Ok { Terrat_access_control2.R.pass = []; deny = _ :: _ as deny }
        when not (Access_control_engine.plan_require_all_dirspace_access access_control) ->
          let open Abbs_future_combinators.Infix_result_monad in
          Abbs_future_combinators.Infix_result_app.(
            (fun client pull_request -> (client, pull_request))
            <$> Dv.client ctx state
            <*> Dv.pull_request ctx state)
          >>= fun (client, pull_request) ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `All_dirspaces deny))
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | Ok { Terrat_access_control2.R.pass = _; deny }
        when CCList.is_empty deny
             || not (Access_control_engine.plan_require_all_dirspace_access access_control) ->
          Abb.Future.return (Ok state)
      | Ok { Terrat_access_control2.R.deny; _ } ->
          let open Abbs_future_combinators.Infix_result_monad in
          Abbs_future_combinators.Infix_result_app.(
            (fun client pull_request -> (client, pull_request))
            <$> Dv.client ctx state
            <*> Dv.pull_request ctx state)
          >>= fun (client, pull_request) ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `Dirspaces deny))
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | Error `Error ->
          let open Abbs_future_combinators.Infix_result_monad in
          Abbs_future_combinators.Infix_result_app.(
            (fun client pull_request -> (client, pull_request))
            <$> Dv.client ctx state
            <*> Dv.pull_request ctx state)
          >>= fun (client, pull_request) ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `Lookup_err))
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | Error ((#Repo_config.fetch_err | #Terrat_change_match3.synthesize_config_err) as err) ->
          Abb.Future.return (Error err)

    let check_merge_conflict ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.pull_request ctx state
      >>= fun pull_request ->
      match S.Api.Pull_request.state pull_request with
      | Terrat_pull_request.State.(Open Open_status.Merge_conflict) ->
          Logs.info (fun m -> m "%s : MERGE_CONFLICT" state.State.request_id);
          Dv.client ctx state
          >>= fun client ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            Msg.Pull_request_not_mergeable
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | Terrat_pull_request.State.Open _
      | Terrat_pull_request.State.Closed
      | Terrat_pull_request.State.Merged _ -> Abb.Future.return (Ok state)

    let check_conflicting_work_manifests op ctx state =
      let module Vcs = Terrat_vcs_provider2 in
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.pull_request ctx state
      >>= fun pull_request ->
      Dv.access_control_results ctx state op
      >>= fun { Terrat_access_control2.R.pass = passed_dirspaces; _ } ->
      let dirspaces =
        CCList.map
          (fun { Terrat_change_match3.Dirspace_config.dirspace; _ } -> dirspace)
          passed_dirspaces
      in
      let unified_op =
        match op with
        | `Plan -> `Plan
        | `Apply | `Apply_autoapprove | `Apply_force | `Stack_auto_apply -> `Apply
      in
      query_conflicting_work_manifests_in_repo
        state.State.request_id
        (Ctx.storage ctx)
        pull_request
        dirspaces
        unified_op
      >>= function
      | None -> Abb.Future.return (Ok state)
      | Some (Vcs.Conflicting_work_manifests.Conflicting wms) ->
          Dv.client ctx state
          >>= fun client ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Conflicting_work_manifests wms)
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | Some (Vcs.Conflicting_work_manifests.Maybe_stale wms) ->
          (* Stale operations will still be queued but we will inform the user
             that there is something up. *)
          Dv.client ctx state
          >>= fun client ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Maybe_stale_work_manifests wms)
          >>= fun () -> Abb.Future.return (Ok state)

    let run_plan_work_manifest_iter =
      H.eval_work_manifest_iter
        ~name:"PLAN"
        ~create:(H.run_op_work_manifest_iter_create `Plan)
        ~update:(H.run_op_work_manifest_iter_update `Plan)
        ~run_success:(H.run_op_work_manifest_iter_run_success `Plan)
        ~run_failure:H.run_op_work_manifest_iter_run_failure
        ~initiate:H.run_op_work_manifest_iter_initiate
        ~result:(H.run_op_work_manifest_iter_result `Plan)
        ~fallthrough:
          (H.eval_plan_work_manifest_iter
             ~store:H.run_op_work_manifest_plan_iter_store
             ~fetch:H.run_op_work_manifest_plan_iter_fetch
             ~fallthrough:H.log_state_err_iter)

    let run_drift_plan_work_manifest_iter =
      H.eval_work_manifest_iter
        ~name:"DRIFT_PLAN"
        ~create:H.run_drift_plan_op_work_manifest_iter_create
        ~update:H.run_drift_plan_op_work_manifest_iter_update
        ~run_success:(H.run_op_work_manifest_iter_run_success `Plan)
        ~run_failure:H.run_op_work_manifest_iter_run_failure
        ~initiate:H.run_op_work_manifest_iter_initiate
        ~result:(H.run_op_work_manifest_iter_result `Plan)
        ~fallthrough:
          (H.eval_plan_work_manifest_iter
             ~store:H.run_op_work_manifest_plan_iter_store
             ~fetch:H.run_op_work_manifest_plan_iter_fetch
             ~fallthrough:H.log_state_err_iter)

    let check_gates op ctx state =
      match op with
      | `Apply_force -> Abb.Future.return (Ok state)
      | _ -> (
          let open Abbs_future_combinators.Infix_result_monad in
          Abbs_future_combinators.Infix_result_app.(
            (fun client pull_request matches -> (client, pull_request, matches))
            <$> Dv.client ctx state
            <*> Dv.pull_request ctx state
            <*> Dv.matches ctx state `Apply)
          >>= fun (client, pull_request, matches) ->
          let module Dc = Terrat_change_match3.Dirspace_config in
          let dirspaces =
            CCList.map (fun { Dc.dirspace; _ } -> dirspace) matches.Dv.Matches.working_set_matches
          in
          eval_gate ~request_id:state.State.request_id client dirspaces pull_request ctx.Ctx.storage
          >>= function
          | [] -> Abb.Future.return (Ok state)
          | denied ->
              publish_msg
                state.State.request_id
                client
                (S.Api.User.to_string @@ Event.user state.State.event)
                pull_request
                (Msg.Gate_check_failure denied)
              >>= fun () -> Abb.Future.return (Error `Silent_failure))

    let check_access_control_apply op ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.apply_requirements ctx state op
      >>= fun apply_requirements ->
      let access_control_run_type =
        match op with
        | `Apply | `Stack_auto_apply ->
            `Apply
              (CCList.filter_map
                 (fun { Terrat_pull_request_review.user; _ } -> user)
                 (S.Apply_requirements.Result.approved_reviews apply_requirements))
        | (`Apply_autoapprove | `Apply_force | `Plan) as op -> op
      in
      Abbs_future_combinators.Infix_result_app.(
        (fun access_control matches client pull_request access_control_result ->
          (access_control, matches, client, pull_request, access_control_result))
        <$> Dv.access_control ctx state
        <*> Dv.matches ctx state op
        <*> Dv.client ctx state
        <*> Dv.pull_request ctx state
        <*> Dv.tf_operation_access_control_evaluation ctx state access_control_run_type)
      >>= fun (access_control, _matches, client, pull_request, access_control_result) ->
      let passed_apply_requirements = S.Apply_requirements.Result.passed apply_requirements in
      match access_control_result with
      | _ when (not passed_apply_requirements) && not (op = `Apply_force) ->
          (* Regardless of access control, if apply requirements were NOT
             passed, then we cannot apply this change UNLESS we are in an
             "apply-force" because then access control result is important
             because we are bypassing the apply requirements. *)
          Logs.info (fun m -> m "%s : PR_NOT_APPLIABLE" state.State.request_id);
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Pull_request_not_appliable (pull_request, apply_requirements))
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | { Terrat_access_control2.R.pass = []; deny = _ :: _ as deny }
        when not (Access_control_engine.apply_require_all_dirspace_access access_control) ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `All_dirspaces deny))
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | { Terrat_access_control2.R.pass = _; deny }
        when CCList.is_empty deny
             || not (Access_control_engine.apply_require_all_dirspace_access access_control) ->
          Abb.Future.return (Ok state)
      | { Terrat_access_control2.R.deny; _ } ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Access_control_denied
               (Access_control_engine.policy_branch access_control, `Dirspaces deny))
          >>= fun () -> Abb.Future.return (Error (`Noop state))

    let check_non_empty_matches_apply op ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.access_control_results ctx state op
      >>= fun { Terrat_access_control2.R.pass = working_set_matches; _ } ->
      let trigger_type = Event.trigger_type state.State.event in
      match (op, working_set_matches, trigger_type) with
      | `Stack_auto_apply, [], _ | _, [], `Auto ->
          Logs.info (fun m -> m "%s : NOOP : AUTOAPPLY_NO_MATCHES" state.State.request_id);
          Abb.Future.return (Error (`Noop state))
      | _, [], _ ->
          Logs.info (fun m -> m "%s : NOOP : APPLY_NO_MATCHING_DIRSPACES" state.State.request_id);
          Dv.client ctx state
          >>= fun client ->
          Dv.pull_request ctx state
          >>= fun pull_request ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            Msg.Apply_no_matching_dirspaces
          >>= fun () -> Abb.Future.return (Error (`Noop state))
      | _, _ :: _, _ -> Abb.Future.return (Ok state)

    let check_dirspaces_owned_by_other_pull_requests op ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Abbs_future_combinators.Infix_result_app.(
        (fun repo_config pull_request matches -> (repo_config, pull_request, matches))
        <$> Dv.repo_config ctx state
        <*> Dv.pull_request ctx state
        <*> Dv.matches ctx state op)
      >>= fun (repo_config, pull_request, matches) ->
      Abb.Future.return
        (H.dirspaceflows_of_changes repo_config (CCList.flatten matches.Dv.Matches.all_matches))
      >>= fun all_match_dirspaceflows ->
      query_dirspaces_owned_by_other_pull_requests
        state.State.request_id
        (Ctx.storage ctx)
        pull_request
        (CCList.map Terrat_change.Dirspaceflow.to_dirspace all_match_dirspaceflows)
      >>= function
      | [] -> Abb.Future.return (Ok state)
      | owned_dirspaces ->
          Dv.client ctx state
          >>= fun client ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Dirspaces_owned_by_other_pull_request owned_dirspaces)
          >>= fun () -> Abb.Future.return (Error (`Noop state))

    let check_dirspaces_missing_plans op ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.pull_request ctx state
      >>= fun pull_request ->
      Dv.branch_ref ctx state
      >>= fun branch_ref ->
      Dv.base_ref ctx state
      >>= fun base_ref ->
      Dv.access_control_results ctx state op
      >>= fun { Terrat_access_control2.R.pass = working_set_matches; _ } ->
      query_dirspaces_without_valid_plans
        ~base_ref
        ~branch_ref
        state.State.request_id
        (Ctx.storage ctx)
        pull_request
        (CCList.map
           (fun { Terrat_change_match3.Dirspace_config.dirspace; _ } -> dirspace)
           working_set_matches)
      >>= function
      | [] -> Abb.Future.return (Ok state)
      | dirspaces ->
          Dv.client ctx state
          >>= fun client ->
          publish_msg
            state.State.request_id
            client
            (S.Api.User.to_string @@ Event.user state.State.event)
            pull_request
            (Msg.Missing_plans dirspaces)
          >>= fun () -> Abb.Future.return (Error (`Noop state))

    let run_apply_work_manifest_iter op =
      H.eval_work_manifest_iter
        ~name:"APPLY"
        ~create:(H.run_op_work_manifest_iter_create op)
        ~update:(H.run_op_work_manifest_iter_update op)
        ~run_success:(H.run_op_work_manifest_iter_run_success op)
        ~run_failure:H.run_op_work_manifest_iter_run_failure
        ~initiate:H.run_op_work_manifest_iter_initiate
        ~result:(H.run_op_work_manifest_iter_result op)
        ~fallthrough:
          (H.eval_plan_work_manifest_iter
             ~store:H.run_op_work_manifest_plan_iter_store
             ~fetch:H.run_op_work_manifest_plan_iter_fetch
             ~fallthrough:H.log_state_err_iter)

    let check_all_dirspaces_applied op ctx state =
      let automerge_config = Terrat_base_repo_config_v1.automerge in
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.matches ctx state op
      >>= fun matches ->
      match (state.State.work_manifest_id, matches.Dv.Matches.all_unapplied_matches) with
      | Some work_manifest_id, [] -> (
          query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
          >>= function
          | Some work_manifest ->
              Logs.info (fun m ->
                  m
                    "%s : ALL_DIRSPACES_APPLIED : id=%a"
                    state.State.request_id
                    Uuidm.pp
                    work_manifest_id);
              Dv.client ctx state
              >>= fun client ->
              Dv.pull_request ctx state
              >>= fun pull_request ->
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Completed"
                  ~status:Terrat_commit_check.Status.Completed
                  ~work_manifest
                  ~repo:(Event.repo state.State.event)
                  ~account:(Event.account state.State.event)
                  "terrateam apply"
              in
              create_commit_checks
                state.State.request_id
                client
                (S.Api.Pull_request.repo pull_request)
                (S.Api.Pull_request.branch_ref pull_request)
                [ check ]
              >>= fun () ->
              Dv.repo_config ctx state
              >>= fun repo_config ->
              let module Am = Terrat_base_repo_config_v1.Automerge in
              let {
                Am.enabled;
                delete_branch = delete_branch';
                merge_strategy;
                require_explicit_apply;
                retain_pr_title;
              } =
                automerge_config repo_config
              in
              if enabled && ((not require_explicit_apply) || op <> `Plan) then
                let open Abb.Future.Infix_monad in
                merge_pull_request
                  ~retain_pr_title
                  state.State.request_id
                  client
                  pull_request
                  merge_strategy
                >>= function
                | Ok () ->
                    if delete_branch' then
                      (* Nothing to do if this fails and it can fail for a few valid
                         reasons, so just ignore. *)
                      delete_branch
                        state.State.request_id
                        client
                        (S.Api.Pull_request.repo pull_request)
                        (S.Api.Ref.to_string (S.Api.Pull_request.branch_name pull_request))
                      >>= fun _ -> Abb.Future.return (Ok state)
                    else Abb.Future.return (Ok state)
                | Error (`Merge_err reason) ->
                    H.maybe_publish_msg ctx state (Msg.Automerge_failure (pull_request, reason))
                    >>= fun () -> Abb.Future.return (Ok state)
                | Error `Error as err -> Abb.Future.return err
              else Abb.Future.return (Ok state)
          | None -> assert false)
      | Some work_manifest_id, unapplied_dirspaces ->
          let module Dsc = Terrat_change_match3.Dirspace_config in
          Logs.info (fun m ->
              m
                "%s : UNAPPLIED_DIRSPACES : id=%a : dirspaces=%s"
                state.State.request_id
                Uuidm.pp
                work_manifest_id
                (CCString.concat
                   " "
                   (CCList.map
                      (fun { Dsc.dirspace = { Terrat_dirspace.dir; workspace }; _ } ->
                        dir ^ ":" ^ workspace)
                      (CCList.flatten unapplied_dirspaces))));
          Abb.Future.return (Ok state)
      | None, _ -> assert false

    let recover_noop_complete_work_manifest ctx state =
      match state.State.work_manifest_id with
      | None -> Abb.Future.return (Ok state)
      | Some _ -> complete_work_manifest ctx state

    let update_drift_schedule ctx state =
      let module V1 = Terrat_base_repo_config_v1 in
      let module D = Terrat_base_repo_config_v1.Drift in
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.repo_config ctx state
      >>= fun repo_config ->
      let { D.enabled; schedules } = V1.drift repo_config in
      CCList.iter
        (fun (name, { D.Schedule.tag_query; reconcile; schedule; window }) ->
          Logs.info (fun m ->
              m
                "%s : DRIFT : UPDATE_SCHEDULE : name=%s : enabled=%s : repo=%s : schedule=%s : \
                 reconcile=%s : tag_query=%s : window=%s"
                state.State.request_id
                name
                (Bool.to_string enabled)
                (S.Api.Repo.to_string (Event.repo state.State.event))
                (D.Schedule.Sched.to_string schedule)
                (Bool.to_string reconcile)
                (Terrat_tag_query.to_string tag_query)
                (CCOption.map_or
                   ~default:""
                   (fun { D.Window.start; end_ } -> start ^ "-" ^ end_)
                   window)))
        (Sln_map.String.to_list schedules);
      store_drift_schedule
        state.State.request_id
        (Ctx.storage ctx)
        (Event.repo state.State.event)
        (V1.drift repo_config)
      >>= fun () -> Abb.Future.return (Ok state)

    let create_drift_events ctx state =
      match state.State.st with
      | State.St.Initial -> (
          let open Abbs_future_combinators.Infix_result_monad in
          query_missing_drift_scheduled_runs state.State.request_id (Ctx.storage ctx)
          >>= function
          | [] -> Abb.Future.return (Error (`Noop state))
          | self :: needed_runs ->
              let f (name, account, repo, reconcile, tag_query, window) =
                Logs.info (fun m ->
                    m
                      "%s : DRIFT : CREATE_EVENT : name=%s : account=%s : repo=%s : reconcile=%s : \
                       tag_query=%s : window=%s"
                      state.State.request_id
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
                {
                  state with
                  State.st = State.St.Resume;
                  event =
                    Event.Run_drift
                      {
                        account;
                        name;
                        repo;
                        reconcile = Some reconcile;
                        tag_query = Some tag_query;
                      };
                }
              in
              let states = CCList.map f needed_runs in
              let state = f self in
              Abb.Future.return (Error (`Clone (state, states))))
      | State.St.Resume -> (
          match state.State.event with
          | Event.Run_drift { account; name; repo; reconcile; tag_query } ->
              Logs.info (fun m ->
                  m
                    "%s : DRIFT : RUN : name=%s : account=%s : repo=%s : reconcile=%s : \
                     tag_query=%s"
                    state.State.request_id
                    name
                    (S.Api.Account.to_string account)
                    (S.Api.Repo.to_string repo)
                    (CCOption.map_or ~default:"" Bool.to_string reconcile)
                    (CCOption.map_or ~default:"" Terrat_tag_query.to_string tag_query));
              Abb.Future.return (Ok { state with State.st = State.St.Initial })
          | _ -> assert false)
      | _ ->
          H.log_state_err
            state.State.request_id
            state.State.st
            state.State.input
            state.State.work_manifest_id;
          Abb.Future.return (Error `Silent_failure)

    let run_drift_work_manifest_iter = run_drift_plan_work_manifest_iter
    let run_drift_reconcile_work_manifest_iter = run_apply_work_manifest_iter `Apply

    let check_reconcile _ctx state =
      match state.State.event with
      | Event.Run_drift { reconcile = Some true; _ } -> Abb.Future.return (Ok state)
      | Event.Run_drift { reconcile = Some false | None; _ } ->
          Abb.Future.return (Error (`Noop state))
      | Event.Pull_request_open _ -> assert false
      | Event.Pull_request_close _ -> assert false
      | Event.Pull_request_sync _ -> assert false
      | Event.Pull_request_ready_for_review _ -> assert false
      | Event.Pull_request_comment _ -> assert false
      | Event.Push _ -> assert false
      | Event.Run_scheduled_drift -> assert false

    let test_config_build_required ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.repo_config ctx state
      >>= fun repo_config ->
      let module V1 = Terrat_base_repo_config_v1 in
      let config_builder = V1.config_builder repo_config in
      if config_builder.V1.Config_builder.enabled then
        Dv.query_built_config ctx state
        >>= function
        | Some _ -> Abb.Future.return (Ok (Id.Config_build_not_required, state))
        | None -> Abb.Future.return (Ok (Id.Config_build_required, state))
      else Abb.Future.return (Ok (Id.Config_build_not_required, state))

    let test_tree_build_required ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.repo_config ctx state
      >>= fun repo_config ->
      let module V1 = Terrat_base_repo_config_v1 in
      let tree_builder = V1.tree_builder repo_config in
      if tree_builder.V1.Tree_builder.enabled then
        Dv.query_built_tree ctx state
        >>= function
        | Some _ -> Abb.Future.return (Ok (Id.Tree_build_not_required, state))
        | None -> Abb.Future.return (Ok (Id.Tree_build_required, state))
      else Abb.Future.return (Ok (Id.Tree_build_not_required, state))

    let run_tree_builder_work_manifest_iter =
      H.eval_work_manifest_iter
        ~name:"TREE_BUILDER"
        ~create:(fun ctx state ->
          let module Wm = Terrat_work_manifest3 in
          let open Abbs_future_combinators.Infix_result_monad in
          let account = Event.account state.State.event in
          let repo = Event.repo state.State.event in
          Dv.client ctx state
          >>= fun client ->
          Dv.base_ref ctx state
          >>= fun base_ref' ->
          Dv.working_branch_ref ctx state
          >>= fun working_branch_ref' ->
          Dv.target ctx state
          >>= fun target ->
          let work_manifest =
            {
              Wm.account;
              base_ref = S.Api.Ref.to_string base_ref';
              branch = None;
              branch_ref = S.Api.Ref.to_string working_branch_ref';
              changes = [];
              completed_at = None;
              created_at = ();
              denied_dirspaces = [];
              environment = None;
              id = ();
              initiator = Event.initiator state.State.event;
              run_id = ();
              runs_on = None;
              state = ();
              steps = [ Wm.Step.Build_tree ];
              tag_query = Terrat_tag_query.any;
              target;
            }
          in
          create_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest
          >>= fun work_manifest ->
          H.run_interactive ctx state (fun () ->
              let module Status = Terrat_commit_check.Status in
              Dv.branch_ref ctx state
              >>= fun branch_ref' ->
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Queued"
                  ~status:Status.Queued
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam build-tree"
              in
              create_commit_checks state.State.request_id client repo branch_ref' [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun state ->
          Logs.info (fun m ->
              m
                "%s : CREATED_WORK_MANIFEST : id=%a : base_ref=%s : branch_ref=%s : runs_on=%s"
                state.State.request_id
                Uuidm.pp
                work_manifest.Wm.id
                (S.Api.Ref.to_string base_ref')
                (S.Api.Ref.to_string working_branch_ref')
                (CCOption.map_or ~default:"" Yojson.Safe.to_string work_manifest.Wm.runs_on));
          Abb.Future.return (Ok [ work_manifest ]))
        ~update:(fun ctx state work_manifest ->
          let module Wm = Terrat_work_manifest3 in
          let open Abbs_future_combinators.Infix_result_monad in
          let work_manifest =
            { work_manifest with Wm.steps = work_manifest.Wm.steps @ [ Wm.Step.Build_tree ] }
          in
          update_work_manifest_steps
            state.State.request_id
            (Ctx.storage ctx)
            work_manifest.Wm.id
            work_manifest.Wm.steps
          >>= fun () ->
          H.run_interactive ctx state (fun () ->
              let module Status = Terrat_commit_check.Status in
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.branch_ref ctx state
              >>= fun branch_ref' ->
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Queued"
                  ~status:Status.Queued
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam build-tree"
              in
              create_commit_checks state.State.request_id client repo branch_ref' [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok [ work_manifest ]))
        ~run_success:(fun ctx state work_manifest ->
          let open Abbs_future_combinators.Infix_result_monad in
          H.run_interactive ctx state (fun () ->
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.pull_request ctx state
              >>= fun pull_request ->
              let module Status = Terrat_commit_check.Status in
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Running"
                  ~status:Status.Running
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam build-tree"
              in
              create_commit_checks
                state.State.request_id
                client
                repo
                (S.Api.Pull_request.branch_ref pull_request)
                [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok ()))
        ~run_failure:(fun ctx state err work_manifest ->
          let open Abbs_future_combinators.Infix_result_monad in
          H.run_interactive ctx state (fun () ->
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.pull_request ctx state
              >>= fun pull_request ->
              let module Status = Terrat_commit_check.Status in
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Failed"
                  ~status:Status.Failed
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam build-tree"
              in
              create_commit_checks
                state.State.request_id
                client
                repo
                (S.Api.Pull_request.branch_ref pull_request)
                [ check ]
              >>= fun () ->
              H.publish_run_failure
                state.State.request_id
                client
                (S.Api.User.to_string @@ Event.user state.State.event)
                pull_request
                err
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok ()))
        ~initiate:(fun ctx state _encryption_key run_id sha work_manifest ->
          let module Wm = Terrat_work_manifest3 in
          let open Abbs_future_combinators.Infix_result_monad in
          H.initiate_work_manifest
            state
            state.State.request_id
            (Ctx.storage ctx)
            run_id
            sha
            work_manifest
          >>= function
          | Some
              {
                Wm.account;
                id;
                branch_ref = _;
                base_ref = _;
                state = Wm.State.(Queued | Running);
                _;
              } ->
              Dv.base_branch_name ctx state
              >>= fun base_branch_name' ->
              Dv.repo_config ctx state
              >>= fun repo_config ->
              H.create_token
                (S.Api.Account.Id.to_string @@ S.Api.Account.id account)
                id
                (Ctx.storage ctx)
              >>= fun token ->
              let module B = Terrat_api_components.Work_manifest_build_tree in
              let config =
                repo_config
                |> Terrat_base_repo_config_v1.to_version_1
                |> Terrat_repo_config.Version_1.to_yojson
              in
              let response =
                Terrat_api_components.Work_manifest.Work_manifest_build_tree
                  {
                    B.base_ref = S.Api.Ref.to_string base_branch_name';
                    token;
                    type_ = `Build_tree;
                    config;
                  }
              in
              Abb.Future.return (Ok (Some response))
          | Some _ | None -> Abb.Future.return (Ok None))
        ~result:(fun ctx state result work_manifest ->
          let module Wmr = Terrat_api_components.Work_manifest_result in
          let module Bt = Terrat_api_components.Work_manifest_build_tree_result in
          let module Bf = Terrat_api_components.Work_manifest_build_result_failure in
          let open Abbs_future_combinators.Infix_result_monad in
          let fail msg =
            H.run_interactive ctx state (fun () ->
                let account = Event.account state.State.event in
                let repo = Event.repo state.State.event in
                Dv.client ctx state
                >>= fun client ->
                Dv.pull_request ctx state
                >>= fun pull_request ->
                let module Status = Terrat_commit_check.Status in
                let check =
                  S.Commit_check.make_str
                    ~config:(Ctx.config ctx)
                    ~description:"Failed"
                    ~status:Status.Failed
                    ~work_manifest
                    ~repo
                    ~account
                    "terrateam build-tree"
                in
                create_commit_checks
                  state.State.request_id
                  client
                  repo
                  (S.Api.Pull_request.branch_ref pull_request)
                  [ check ]
                >>= fun () ->
                publish_msg
                  state.State.request_id
                  client
                  (S.Api.User.to_string @@ Event.user state.State.event)
                  pull_request
                  msg
                >>= fun () -> Abb.Future.return (Ok state))
            >>= fun _ -> Abb.Future.return (Ok ())
          in
          match result with
          | Wmr.Work_manifest_build_tree_result { Bt.files } ->
              let open Abbs_future_combinators.Infix_result_monad in
              let account = Event.account state.State.event in
              Dv.working_branch_ref ctx state
              >>= fun working_branch_ref' ->
              store_repo_tree
                state.State.request_id
                (Ctx.storage ctx)
                account
                working_branch_ref'
                files
              >>= fun () ->
              H.run_interactive ctx state (fun () ->
                  let account = Event.account state.State.event in
                  let repo = Event.repo state.State.event in
                  Dv.client ctx state
                  >>= fun client ->
                  Dv.pull_request ctx state
                  >>= fun pull_request ->
                  let module Status = Terrat_commit_check.Status in
                  let check =
                    S.Commit_check.make_str
                      ~config:(Ctx.config ctx)
                      ~description:"Completed"
                      ~status:Status.Completed
                      ~work_manifest
                      ~repo
                      ~account
                      "terrateam build-tree"
                  in
                  create_commit_checks
                    state.State.request_id
                    client
                    repo
                    (S.Api.Pull_request.branch_ref pull_request)
                    [ check ]
                  >>= fun () -> Abb.Future.return (Ok state))
              >>= fun _ -> Abb.Future.return (Ok ())
          | Wmr.Work_manifest_build_result_failure { Bf.msg } ->
              let open Abbs_future_combinators.Infix_result_monad in
              fail (Msg.Build_tree_failure msg)
              >>= fun () -> Abb.Future.return (Error (`Noop state))
          | Wmr.Work_manifest_build_config_result _ -> assert false
          | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result _ ->
              assert false
          | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result2 _ ->
              assert false
          | Terrat_api_components_work_manifest_result.Work_manifest_index_result _ -> assert false)
        ~fallthrough:H.log_state_err_iter

    let run_config_builder_work_manifest_iter =
      H.eval_work_manifest_iter
        ~name:"CONFIG_BUILDER"
        ~create:(fun ctx state ->
          let module Wm = Terrat_work_manifest3 in
          let open Abbs_future_combinators.Infix_result_monad in
          let account = Event.account state.State.event in
          let repo = Event.repo state.State.event in
          Dv.client ctx state
          >>= fun client ->
          Dv.base_ref ctx state
          >>= fun base_ref' ->
          Dv.working_branch_ref ctx state
          >>= fun working_branch_ref' ->
          Dv.target ctx state
          >>= fun target ->
          let work_manifest =
            {
              Wm.account;
              base_ref = S.Api.Ref.to_string base_ref';
              branch = None;
              branch_ref = S.Api.Ref.to_string working_branch_ref';
              changes = [];
              completed_at = None;
              created_at = ();
              denied_dirspaces = [];
              environment = None;
              id = ();
              initiator = Event.initiator state.State.event;
              run_id = ();
              runs_on = None;
              state = ();
              steps = [ Wm.Step.Build_config ];
              tag_query = Terrat_tag_query.any;
              target;
            }
          in
          create_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest
          >>= fun work_manifest ->
          H.run_interactive ctx state (fun () ->
              let module Status = Terrat_commit_check.Status in
              Dv.branch_ref ctx state
              >>= fun branch_ref' ->
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Queued"
                  ~status:Status.Queued
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam build-config"
              in
              create_commit_checks state.State.request_id client repo branch_ref' [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun state ->
          Logs.info (fun m ->
              m
                "%s : CREATED_WORK_MANIFEST : id=%a : base_ref=%s : branch_ref=%s : runs_on=%s"
                state.State.request_id
                Uuidm.pp
                work_manifest.Wm.id
                (S.Api.Ref.to_string base_ref')
                (S.Api.Ref.to_string working_branch_ref')
                (CCOption.map_or ~default:"" Yojson.Safe.to_string work_manifest.Wm.runs_on));
          Abb.Future.return (Ok [ work_manifest ]))
        ~update:(fun ctx state work_manifest ->
          let module Wm = Terrat_work_manifest3 in
          let open Abbs_future_combinators.Infix_result_monad in
          let work_manifest =
            { work_manifest with Wm.steps = work_manifest.Wm.steps @ [ Wm.Step.Build_config ] }
          in
          update_work_manifest_steps
            state.State.request_id
            (Ctx.storage ctx)
            work_manifest.Wm.id
            work_manifest.Wm.steps
          >>= fun () ->
          H.run_interactive ctx state (fun () ->
              let module Status = Terrat_commit_check.Status in
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.branch_ref ctx state
              >>= fun branch_ref' ->
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Queued"
                  ~status:Status.Queued
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam build-config"
              in
              create_commit_checks state.State.request_id client repo branch_ref' [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok [ work_manifest ]))
        ~run_success:(fun ctx state work_manifest ->
          let open Abbs_future_combinators.Infix_result_monad in
          H.run_interactive ctx state (fun () ->
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.pull_request ctx state
              >>= fun pull_request ->
              let module Status = Terrat_commit_check.Status in
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Running"
                  ~status:Status.Running
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam build-config"
              in
              create_commit_checks
                state.State.request_id
                client
                repo
                (S.Api.Pull_request.branch_ref pull_request)
                [ check ]
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok ()))
        ~run_failure:(fun ctx state err work_manifest ->
          let open Abbs_future_combinators.Infix_result_monad in
          H.run_interactive ctx state (fun () ->
              let account = Event.account state.State.event in
              let repo = Event.repo state.State.event in
              Dv.client ctx state
              >>= fun client ->
              Dv.pull_request ctx state
              >>= fun pull_request ->
              let module Status = Terrat_commit_check.Status in
              let check =
                S.Commit_check.make_str
                  ~config:(Ctx.config ctx)
                  ~description:"Failed"
                  ~status:Status.Failed
                  ~work_manifest
                  ~repo
                  ~account
                  "terrateam build-config"
              in
              create_commit_checks
                state.State.request_id
                client
                repo
                (S.Api.Pull_request.branch_ref pull_request)
                [ check ]
              >>= fun () ->
              H.publish_run_failure
                state.State.request_id
                client
                (S.Api.User.to_string @@ Event.user state.State.event)
                pull_request
                err
              >>= fun () -> Abb.Future.return (Ok state))
          >>= fun _ -> Abb.Future.return (Ok ()))
        ~initiate:(fun ctx state _encryption_key run_id sha work_manifest ->
          let module Wm = Terrat_work_manifest3 in
          let open Abbs_future_combinators.Infix_result_monad in
          H.initiate_work_manifest
            state
            state.State.request_id
            (Ctx.storage ctx)
            run_id
            sha
            work_manifest
          >>= function
          | Some
              {
                Wm.account;
                id;
                branch_ref = _;
                base_ref = _;
                state = Wm.State.(Queued | Running);
                _;
              } ->
              Dv.repo_config ctx state
              >>= fun repo_config ->
              Dv.repo_tree_branch ctx state
              >>= fun repo_tree ->
              Dv.query_repo_tree ctx state
              >>= fun built_repo_tree ->
              let repo_tree =
                let module I = Terrat_api_components.Work_manifest_build_tree_result.Files.Items in
                CCOption.map_or
                  ~default:repo_tree
                  (fun built_tree -> CCList.map (fun { I.path; _ } -> path) built_tree)
                  built_repo_tree
              in
              Dv.query_index ctx state
              >>= fun index ->
              Dv.base_branch_name ctx state
              >>= fun base_branch_name ->
              Dv.branch_name ctx state
              >>= fun branch_name ->
              Abbs_time_it.run (log_time state.State.request_id "DERIVE") (fun () ->
                  Abbs_future_combinators.to_result
                  @@ Abb.Thread.run (fun () ->
                      Terrat_base_repo_config_v1.derive
                        ~ctx:
                          (Terrat_base_repo_config_v1.Ctx.make
                             ~dest_branch:(S.Api.Ref.to_string base_branch_name)
                             ~branch:(S.Api.Ref.to_string branch_name)
                             ())
                        ~index:
                          (CCOption.map_or
                             ~default:Terrat_base_repo_config_v1.Index.empty
                             (fun { Terrat_vcs_provider2.Index.index; _ } -> index)
                             index)
                        ~file_list:repo_tree
                        repo_config))
              >>= fun repo_config ->
              H.create_token
                (S.Api.Account.Id.to_string @@ S.Api.Account.id account)
                id
                (Ctx.storage ctx)
              >>= fun token ->
              let module B = Terrat_api_components.Work_manifest_build_config in
              let config =
                repo_config
                |> Terrat_base_repo_config_v1.to_version_1
                |> Terrat_repo_config.Version_1.to_yojson
              in
              let response =
                Terrat_api_components.Work_manifest.Work_manifest_build_config
                  {
                    B.base_ref = S.Api.Ref.to_string base_branch_name;
                    token;
                    type_ = `Build_config;
                    config;
                  }
              in
              Abb.Future.return (Ok (Some response))
          | Some _ | None -> Abb.Future.return (Ok None))
        ~result:(fun ctx state result work_manifest ->
          let module Wmr = Terrat_api_components.Work_manifest_result in
          let module Bc = Terrat_api_components.Work_manifest_build_config_result in
          let module Bf = Terrat_api_components.Work_manifest_build_result_failure in
          let open Abbs_future_combinators.Infix_result_monad in
          let fail msg =
            H.run_interactive ctx state (fun () ->
                let account = Event.account state.State.event in
                let repo = Event.repo state.State.event in
                Dv.client ctx state
                >>= fun client ->
                Dv.pull_request ctx state
                >>= fun pull_request ->
                let module Status = Terrat_commit_check.Status in
                let check =
                  S.Commit_check.make_str
                    ~config:(Ctx.config ctx)
                    ~description:"Failed"
                    ~status:Status.Failed
                    ~work_manifest
                    ~repo
                    ~account
                    "terrateam build-config"
                in
                create_commit_checks
                  state.State.request_id
                  client
                  repo
                  (S.Api.Pull_request.branch_ref pull_request)
                  [ check ]
                >>= fun () ->
                publish_msg
                  state.State.request_id
                  client
                  (S.Api.User.to_string @@ Event.user state.State.event)
                  pull_request
                  msg
                >>= fun () -> Abb.Future.return (Ok state))
            >>= fun _ -> Abb.Future.return (Ok ())
          in
          match result with
          | Wmr.Work_manifest_build_config_result { Bc.config } -> (
              let module V1 = Terrat_base_repo_config_v1 in
              let open Abb.Future.Infix_monad in
              Abb.Future.return (V1.of_version_1_json config)
              >>= function
              | Ok _ ->
                  let open Abbs_future_combinators.Infix_result_monad in
                  let account = Event.account state.State.event in
                  Dv.repo_config_build_cache_ref ctx state
                  >>= fun build_cache_ref ->
                  store_repo_config_json
                    state.State.request_id
                    (Ctx.storage ctx)
                    account
                    build_cache_ref
                    config
                  >>= fun () ->
                  H.run_interactive ctx state (fun () ->
                      let account = Event.account state.State.event in
                      let repo = Event.repo state.State.event in
                      Dv.client ctx state
                      >>= fun client ->
                      Dv.pull_request ctx state
                      >>= fun pull_request ->
                      let module Status = Terrat_commit_check.Status in
                      let check =
                        S.Commit_check.make_str
                          ~config:(Ctx.config ctx)
                          ~description:"Completed"
                          ~status:Status.Completed
                          ~work_manifest
                          ~repo
                          ~account
                          "terrateam build-config"
                      in
                      create_commit_checks
                        state.State.request_id
                        client
                        repo
                        (S.Api.Pull_request.branch_ref pull_request)
                        [ check ]
                      >>= fun () -> Abb.Future.return (Ok state))
                  >>= fun _ -> Abb.Future.return (Ok ())
              | Error (#Terrat_base_repo_config_v1.of_version_1_err as err) ->
                  let open Abbs_future_combinators.Infix_result_monad in
                  fail (Msg.Build_config_err err)
                  >>= fun () -> Abb.Future.return (Error (`Noop state))
              | Error (`Repo_config_schema_err _ as err) ->
                  let open Abbs_future_combinators.Infix_result_monad in
                  fail (Msg.Build_config_err err)
                  >>= fun () -> Abb.Future.return (Error (`Noop state)))
          | Wmr.Work_manifest_build_result_failure { Bf.msg } ->
              let open Abbs_future_combinators.Infix_result_monad in
              fail (Msg.Build_config_failure msg)
              >>= fun () -> Abb.Future.return (Error (`Noop state))
          | Wmr.Work_manifest_build_tree_result _ -> assert false
          | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result _ ->
              assert false
          | Terrat_api_components_work_manifest_result.Work_manifest_tf_operation_result2 _ ->
              assert false
          | Terrat_api_components_work_manifest_result.Work_manifest_index_result _ -> assert false)
        ~fallthrough:H.log_state_err_iter

    let test_more_layers_to_run op ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.matches ctx state op
      >>= fun matches ->
      match matches.Dv.Matches.working_layer with
      | [] -> Abb.Future.return (Ok (Id.All_layers_completed, state))
      | working_layer -> (
          let module Dc = Terrat_change_match3.Dirspace_config in
          let working_layer_dirspaces =
            Terrat_data.Dirspace_set.of_list
              (CCList.map (fun { Dc.dirspace; _ } -> dirspace) working_layer)
          in
          match state.State.work_manifest_id with
          | Some work_manifest_id -> (
              let module Wm = Terrat_work_manifest3 in
              query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
              >>= function
              | Some { Wm.changes; _ } ->
                  let module Dc = Terrat_change_match3.Dirspace_config in
                  let module V1 = Terrat_base_repo_config_v1 in
                  let module S = V1.Stacks in
                  let module Dsf = Terrat_change.Dirspaceflow in
                  let changed_dirspaces =
                    Terrat_data.Dirspace_set.of_list (CCList.map Dsf.to_dirspace changes)
                  in
                  if Terrat_data.Dirspace_set.disjoint changed_dirspaces working_layer_dirspaces
                  then
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
                    Abb.Future.return (Ok (Id.More_layers_to_run, state))
                  else if
                    op = `Plan
                    && CCList.exists
                         (fun {
                                Dc.stack_config = { S.Stack.rules = { S.Rules.auto_apply; _ }; _ };
                                _;
                              }
                            -> CCOption.get_or ~default:false auto_apply)
                         working_layer
                  then Abb.Future.return (Ok (Id.Can_run_stack_auto_apply, state))
                  else
                    (* This does not mean that all layers are completely
                       finished, but it means all layers are done as far as they
                       can be and there are no more layers that can be
                       automatically run. *)
                    Abb.Future.return (Ok (Id.All_layers_completed, state))
              | None -> assert false)
          | None -> Abb.Future.return (Ok (Id.More_layers_to_run, state)))

    let synthesize_pull_request_sync _ctx state =
      let account = Event.account state.State.event in
      let user = Event.user state.State.event in
      let repo = Event.repo state.State.event in
      let pull_request_id = Event.pull_request_id state.State.event in
      let event = Event.Pull_request_sync { account; user; repo; pull_request_id } in
      Abb.Future.return (Ok { state with State.event })

    let complete_no_change_dirspaces ctx state =
      let module Wm = Terrat_work_manifest3 in
      let module Dsf = Terrat_change.Dirspaceflow in
      let module Dc = Terrat_change_match3.Dirspace_config in
      let open Abbs_future_combinators.Infix_result_monad in
      H.run_interactive ctx state (fun () ->
          match state.State.work_manifest_id with
          | Some work_manifest_id -> (
              query_work_manifest state.State.request_id (Ctx.storage ctx) work_manifest_id
              >>= function
              | Some ({ Wm.changes; _ } as work_manifest) ->
                  Dv.matches ctx state `Plan
                  >>= fun matches ->
                  let unapplied_dirspaces =
                    Terrat_data.Dirspace_set.of_list
                      (CCList.map
                         (fun { Dc.dirspace; _ } -> dirspace)
                         (CCList.flatten matches.Dv.Matches.all_unapplied_matches))
                  in
                  let applied_changes =
                    CCList.filter
                      (fun { Dsf.dirspace; _ } ->
                        not (Terrat_data.Dirspace_set.mem dirspace unapplied_dirspaces))
                      changes
                  in
                  let account = Event.account state.State.event in
                  let repo = Event.repo state.State.event in
                  let checks =
                    CCList.map
                      (fun { Dsf.dirspace; _ } ->
                        S.Commit_check.make_dirspace
                          ~config:(Ctx.config ctx)
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
                  Dv.client ctx state
                  >>= fun client ->
                  Dv.branch_ref ctx state
                  >>= fun ref_ ->
                  create_commit_checks state.State.request_id client repo ref_ checks
                  >>= fun () -> Abb.Future.return (Ok state)
              | None -> Abb.Future.return (Ok state))
          | None -> Abb.Future.return (Ok state))

    let store_gate_approval ctx state =
      let open Abbs_future_combinators.Infix_result_monad in
      Dv.pull_request ctx state
      >>= fun pull_request ->
      let approver = S.Api.User.to_string @@ Event.user state.State.event in
      let tokens = Event.gate_approval_tokens state.State.event in
      Abbs_future_combinators.List_result.iter
        ~f:(fun token ->
          store_gate_approval
            ~request_id:state.State.request_id
            ~token
            ~approver
            pull_request
            ctx.Ctx.storage)
        tokens
      >>= fun () -> Abb.Future.return (Ok state)
  end

  let eval_step step ctx state =
    let open Abb.Future.Infix_monad in
    match state.State.input with
    | Some State.Io.I.(Checkpointed | Tabula_rasa) ->
        Abb.Future.return (`Success { state with State.input = None })
    | _ -> (
        step ctx state
        >>= function
        | Ok state -> Abb.Future.return (`Success state)
        | Error (`Yield _ as r) -> Abb.Future.return r
        | Error (`Noop _ as r) -> Abb.Future.return (`Failure r)
        | Error (`Clone (state, v)) ->
            Abb.Future.return (`Yield { state with State.output = Some (State.Io.O.Clone v) })
        | Error (`Checkpoint state) ->
            Abb.Future.return (`Yield { state with State.output = Some State.Io.O.Checkpoint })
        | Error (`Reset_ctx state) ->
            Abb.Future.return (`Yield { state with State.output = Some State.Io.O.Reset_ctx })
        | Error `Error ->
            Logs.info (fun m -> m "%s" state.State.request_id);
            H.maybe_publish_msg ctx state Msg.Unexpected_temporary_err
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error (#Terrat_change_match3.synthesize_config_err as err) ->
            Logs.info (fun m ->
                m "%s : %a" state.State.request_id Terrat_change_match3.pp_synthesize_config_err err);
            H.maybe_publish_msg ctx state (Msg.Synthesize_config_err err)
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error (#Terrat_base_repo_config_v1.of_version_1_err as err) ->
            Logs.info (fun m ->
                m
                  "%s : %a"
                  state.State.request_id
                  Terrat_base_repo_config_v1.pp_of_version_1_err
                  err);
            H.maybe_publish_msg ctx state (Msg.Repo_config_err err)
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error (`Json_decode_err (fname, err) | `Yaml_decode_err (fname, err)) ->
            H.maybe_publish_msg ctx state (Msg.Repo_config_parse_failure (fname, err))
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error (`Repo_config_schema_err (fname, err)) ->
            H.maybe_publish_msg ctx state (Msg.Repo_config_schema_err (fname, err))
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error (`Premium_feature_err feature as err) ->
            Logs.info (fun m ->
                m
                  "%s : %a"
                  state.State.request_id
                  Terrat_vcs_provider2.pp_fetch_repo_config_with_provenance_err
                  err);
            H.maybe_publish_msg ctx state (Msg.Premium_feature_err feature)
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error (`Config_merge_err details as err) ->
            Logs.info (fun m -> m "%s : %a" state.State.request_id Repo_config.pp_fetch_err err);
            H.maybe_publish_msg ctx state (Msg.Repo_config_merge_err details)
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error (#Terrat_vcs_provider2.fetch_repo_config_with_provenance_err as err) ->
            Logs.info (fun m ->
                m
                  "%s : %a"
                  state.State.request_id
                  Terrat_vcs_provider2.pp_fetch_repo_config_with_provenance_err
                  err);
            H.maybe_publish_msg ctx state Msg.Unexpected_temporary_err
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error (`Ref_mismatch_err state) ->
            H.maybe_publish_msg ctx state Msg.Mismatched_refs
            >>= fun () -> Abb.Future.return (`Failure (`Noop state))
        | Error (#Terrat_vcs_provider2.gate_add_approval_err as err) ->
            Logs.info (fun m ->
                m "%s : %a" state.State.request_id Terrat_vcs_provider2.pp_gate_add_approval_err err);
            H.maybe_publish_msg ctx state Msg.Unexpected_temporary_err
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error (#Str_template.err as err) ->
            Logs.info (fun m -> m "%s : %a" state.State.request_id Str_template.pp_err err);
            H.maybe_publish_msg ctx state (Msg.Str_template_err err)
            >>= fun () -> Abb.Future.return (`Failure `Error)
        | Error `Silent_failure ->
            (* A failure where we know that any communication to the user that
               is necessary has been done.  So we just want to log that the
               failure happened. *)
            Logs.info (fun m -> m "%s : SILENT_FAILURE" state.State.request_id);
            Abb.Future.return (`Failure `Error)
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "%s : ERROR : %a" state.State.request_id Pgsql_io.pp_err err);
            Abb.Future.return (`Failure `Error)
        | Error (#Terrat_user.Token.to_token_err as err) ->
            Logs.err (fun m ->
                m "%s : ERROR : %a" state.State.request_id Terrat_user.Token.pp_to_token_err err);
            Abb.Future.return (`Failure `Error))

  (* Flow start *)
  let flow =
    let account_status_flow =
      Flow.Flow.(
        choice
          ~id:Id.Test_account_status
          ~f:F.test_account_status
          [
            (Id.Account_enabled, action []);
            (Id.Account_expired, action []);
            ( Id.Account_disabled,
              action [ Flow.Step.make ~id:Id.Account_disabled ~f:(eval_step F.account_disabled) () ]
            );
          ])
    in
    let enabled_flow =
      Flow.Flow.(
        action
          [
            Flow.Step.make
              ~id:Id.Check_enabled_in_repo_config
              ~f:(eval_step F.check_enabled_in_repo_config)
              ();
            Flow.Step.make ~id:Id.React_to_comment ~f:(eval_step F.react_to_comment) ();
          ])
    in
    let recover_noop_flow =
      Flow.Flow.(
        action
          [
            Flow.Step.make
              ~id:Id.Complete_work_manifest
              ~f:(eval_step F.recover_noop_complete_work_manifest)
              ();
          ])
    in
    let complete_work_manifest_flow =
      Flow.Flow.(
        action
          [
            Flow.Step.make ~id:Id.Complete_work_manifest ~f:(eval_step F.complete_work_manifest) ();
          ])
    in
    let maybe_complete_work_manifest_flow =
      Flow.Flow.(
        choice
          ~id:Id.Test_batch_runs
          ~f:F.test_batch_runs_enabled
          [
            ( Id.Batch_runs_enabled,
              action
                [
                  Flow.Step.make
                    ~id:Id.Complete_work_manifest
                    ~f:(eval_step F.complete_work_manifest)
                    ();
                  Flow.Step.make
                    ~id:Id.Unset_work_manifest_id
                    ~f:
                      (eval_step (fun _ state ->
                           Abb.Future.return (Ok { state with State.work_manifest_id = None })))
                    ();
                ] );
            (Id.Batch_runs_disabled, action []);
          ])
    in
    let store_pull_request_flow =
      Flow.Flow.(
        action [ Flow.Step.make ~id:Id.Store_pull_request ~f:(eval_step F.store_pull_request) () ])
    in
    let tree_builder_flow =
      Flow.Flow.(
        choice
          ~id:Id.Test_tree_build_required
          ~f:F.test_tree_build_required
          [
            ( Id.Tree_build_required,
              seq
                (action
                   [
                     Flow.Step.make
                       ~id:Id.Run_work_manifest_iter
                       ~f:(eval_step F.run_tree_builder_work_manifest_iter)
                       ();
                   ])
                maybe_complete_work_manifest_flow );
            (Id.Tree_build_not_required, action []);
          ])
    in
    let config_builder_flow =
      Flow.Flow.(
        choice
          ~id:Id.Test_config_build_required
          ~f:F.test_config_build_required
          [
            ( Id.Config_build_required,
              seq
                (action
                   [
                     Flow.Step.make
                       ~id:Id.Run_work_manifest_iter
                       ~f:(eval_step F.run_config_builder_work_manifest_iter)
                       ();
                   ])
                maybe_complete_work_manifest_flow );
            (Id.Config_build_not_required, action []);
          ])
    in
    let index_flow =
      Flow.Flow.(
        seq tree_builder_flow
        @@ seq config_builder_flow
        @@ seq
             (choice
                ~id:Id.Test_index_required
                ~f:F.test_index_required
                [
                  ( Id.Index_required,
                    seq
                      (action
                         [
                           Flow.Step.make
                             ~id:Id.Run_work_manifest_iter
                             ~f:(eval_step F.run_index_work_manifest_iter)
                             ();
                         ])
                      maybe_complete_work_manifest_flow );
                  (Id.Index_not_required, action []);
                ])
             (action [ Flow.Step.make ~id:Id.Store_stacks ~f:(eval_step F.store_stacks) () ]))
    in
    let event_kind_op_flow =
      let layers_flow ~stack_auto_apply_flow op next_layer_flow =
        Flow.Flow.(
          choice
            ~id:Id.Test_more_layers_to_run
            ~f:(F.test_more_layers_to_run op)
            [
              ( Id.More_layers_to_run,
                seq
                  (action
                     [
                       Flow.Step.make
                         ~id:Id.Complete_work_manifest
                         ~f:(eval_step F.complete_work_manifest)
                         ();
                       Flow.Step.make
                         ~id:Id.Synthesize_pull_request_sync
                         ~f:(eval_step F.synthesize_pull_request_sync)
                         ();
                       Flow.Step.make ~id:Id.Checkpoint ~f:(eval_step F.checkpoint) ();
                     ])
                  next_layer_flow );
              ( Id.Can_run_stack_auto_apply,
                seq
                  (action
                     [
                       Flow.Step.make
                         ~id:Id.Complete_work_manifest
                         ~f:(eval_step F.complete_work_manifest)
                         ();
                       Flow.Step.make ~id:Id.Checkpoint ~f:(eval_step F.checkpoint) ();
                     ])
                  stack_auto_apply_flow );
              ( Id.All_layers_completed,
                action
                  [
                    Flow.Step.make
                      ~id:Id.Check_all_dirspaces_applied
                      ~f:(eval_step (F.check_all_dirspaces_applied op))
                      ();
                    Flow.Step.make
                      ~id:Id.Complete_work_manifest
                      ~f:(eval_step F.complete_work_manifest)
                      ();
                  ] );
            ])
      in
      let rec op_kind_plan_flow _ _ =
        Flow.Flow.(
          seq
            (action
               [
                 Flow.Step.make
                   ~id:Id.Check_pull_request_state
                   ~f:(eval_step F.check_pull_request_state)
                   ();
               ])
            (seq
               (seq
                  index_flow
                  (action
                     [
                       Flow.Step.make
                         ~id:Id.Check_access_control_ci_change
                         ~f:(eval_step F.check_access_control_ci_change)
                         ();
                       Flow.Step.make
                         ~id:Id.Check_access_control_files
                         ~f:(eval_step F.check_access_control_files)
                         ();
                       Flow.Step.make
                         ~id:Id.Check_access_control_repo_config
                         ~f:(eval_step F.check_access_control_repo_config)
                         ();
                       Flow.Step.make
                         ~id:Id.Check_valid_destination_branch
                         ~f:(eval_step F.check_valid_destination_branch)
                         ();
                       Flow.Step.make
                         ~id:Id.Check_access_control_plan
                         ~f:(eval_step F.check_access_control_plan)
                         ();
                       Flow.Step.make
                         ~id:Id.Check_non_empty_matches
                         ~f:(eval_step F.check_non_empty_matches)
                         ();
                       Flow.Step.make
                         ~id:Id.Check_account_status_expired
                         ~f:(eval_step F.check_account_status_expired)
                         ();
                       Flow.Step.make
                         ~id:Id.Check_account_tier
                         ~f:(eval_step F.check_account_tier)
                         ();
                       Flow.Step.make
                         ~id:Id.Check_merge_conflict
                         ~f:(eval_step F.check_merge_conflict)
                         ();
                       Flow.Step.make
                         ~id:Id.Check_conflicting_work_manifests
                         ~f:(eval_step (F.check_conflicting_work_manifests `Plan))
                         ();
                       Flow.Step.make
                         ~id:Id.Run_work_manifest_iter
                         ~f:(eval_step F.run_plan_work_manifest_iter)
                         ();
                       (* Wait for the initiate call to make the next steps. At
                          this point we can have two active API calls happening:

                          1. The RESULT API call, that we just handled.  We have
                             responded to that API call and the compute layer (a
                             GitHub Action, for example) is going to immediately
                             make the request for the next piece of work...

                          2. The INITIATE API call.  This is the compute layer
                             asking what to do next.

                          The API call that is hitting this piece of code is the
                          RESULT.  So we will yield and wait for the API call
                          for the INITIATE in order to continue.

                          NOTE: This is actually not a great solution.  This
                          flow abstraction doesn't deal with concurrency very
                          well (two API calls impacting the same flow), so we
                          are trying to avoid it by limiting concurrency.  But
                          this is a hack.  For example, if the compute layer
                          fails, we will never complete the work manifest, even
                          though the work has been done.  Whether or not that is
                          a bug depends on your perspective. *)
                       Flow.Step.make ~id:Id.Reset_ctx ~f:(eval_step F.wait_for_initiate) ();
                       (* Complete any commit checks for dirspaces with no changes in them. *)
                       Flow.Step.make
                         ~id:Id.Complete_no_change_dirspaces
                         ~f:(eval_step F.complete_no_change_dirspaces)
                         ();
                     ]))
               (layers_flow
                  `Plan
                  ~stack_auto_apply_flow:(gen (op_kind_apply_flow `Stack_auto_apply))
                  (gen op_kind_plan_flow))))
      and op_kind_apply_flow op _ _ =
        Flow.Flow.(
          seq
            (action
               [
                 Flow.Step.make
                   ~id:Id.Check_pull_request_state
                   ~f:(eval_step F.check_pull_request_state)
                   ();
                 Flow.Step.make
                   ~id:Id.Check_access_control_ci_change
                   ~f:(eval_step F.check_access_control_ci_change)
                   ();
                 Flow.Step.make
                   ~id:Id.Check_access_control_files
                   ~f:(eval_step F.check_access_control_files)
                   ();
                 Flow.Step.make
                   ~id:Id.Check_access_control_repo_config
                   ~f:(eval_step F.check_access_control_repo_config)
                   ();
                 Flow.Step.make ~id:Id.Check_gates ~f:(eval_step (F.check_gates op)) ();
                 Flow.Step.make
                   ~id:Id.Check_access_control_apply
                   ~f:(eval_step (F.check_access_control_apply op))
                   ();
                 Flow.Step.make
                   ~id:Id.Check_conflicting_work_manifests
                   ~f:(eval_step (F.check_conflicting_work_manifests op))
                   ();
                 Flow.Step.make
                   ~id:Id.Check_non_empty_matches
                   ~f:(eval_step (F.check_non_empty_matches_apply op))
                   ();
                 Flow.Step.make
                   ~id:Id.Check_account_status_expired
                   ~f:(eval_step F.check_account_status_expired)
                   ();
                 Flow.Step.make ~id:Id.Check_account_tier ~f:(eval_step F.check_account_tier) ();
                 Flow.Step.make
                   ~id:Id.Check_dirspaces_owned_by_other_pull_requests
                   ~f:(eval_step (F.check_dirspaces_owned_by_other_pull_requests op))
                   ();
                 Flow.Step.make
                   ~id:Id.Check_dirspaces_missing_plans
                   ~f:(eval_step (F.check_dirspaces_missing_plans op))
                   ();
                 Flow.Step.make
                   ~id:Id.Run_work_manifest_iter
                   ~f:(eval_step (F.run_apply_work_manifest_iter op))
                   ();
                 (* Wait for the initiate call to make the next steps. At
                    this point we can have two active API calls happening:

                    1. The RESULT API call, that we just handled.  We have
                       responded to that API call and the compute layer (a
                       GitHub Action, for example) is going to immediately make
                       the request for the next piece of work...

                    2. The INITIATE API call.  This is the compute layer asking
                       what to do next.

                    The API call that is hitting this piece of code is the
                    RESULT.  So we will yield and wait for the API call for the
                    INITIATE in order to continue.

                    NOTE: This is actually not a great solution.  This flow
                    abstraction doesn't deal with concurrency very well (two API
                    calls impacting the same flow), so we are trying to avoid it
                    by limiting concurrency.  But this is a hack.  For example,
                    if the compute layer fails, we will never complete the work
                    manifest, even though the work has been done.  Whether or
                    not that is a bug depends on your perspective. *)
                 Flow.Step.make ~id:Id.Reset_ctx ~f:(eval_step F.wait_for_initiate) ();
               ])
            (layers_flow
               op
               ~stack_auto_apply_flow:(gen (op_kind_apply_flow `Stack_auto_apply))
               (gen op_kind_plan_flow)))
      in
      Flow.Flow.(
        recover
          ~id:Id.Recover
          (finally
             ~id:Id.Always_store_pull_request
             ~finally:store_pull_request_flow
             (seq
                account_status_flow
                (seq
                   enabled_flow
                   (seq
                      store_pull_request_flow
                      (choice
                         ~id:Id.Test_op_kind
                         ~f:F.test_op_kind
                         [
                           (Id.Op_kind_plan, gen op_kind_plan_flow);
                           (Id.Op_kind_apply, gen (op_kind_apply_flow `Apply));
                           ( Id.Op_kind_apply_autoapprove,
                             gen (op_kind_apply_flow `Apply_autoapprove) );
                           (Id.Op_kind_apply_force, gen (op_kind_apply_flow `Apply_force));
                         ])))))
          ~f:(fun _ _state -> function
            | `Step_err (_, `Noop state) -> Abb.Future.return (Ok (Id.Recover_noop, state))
            | _ -> Abb.Future.return (Error `Error))
          ~recover:[ (Id.Recover_noop, recover_noop_flow) ])
    in
    let event_kind_run_drift_flow =
      Flow.Flow.(
        recover
          ~id:Id.Recover
          (seq
             (action
                [
                  Flow.Step.make ~id:Id.Create_drift_events ~f:(eval_step F.create_drift_events) ();
                  (* Checkpoint to ensure that every work manifest runs in its
                     own transaction with its own caches. *)
                  Flow.Step.make ~id:Id.Checkpoint ~f:(eval_step F.checkpoint) ();
                ])
          @@ seq account_status_flow
          @@ seq enabled_flow
          @@ seq index_flow
          @@ action
               [
                 Flow.Step.make
                   ~id:Id.Run_work_manifest_iter
                   ~f:(eval_step F.run_drift_work_manifest_iter)
                   ();
                 Flow.Step.make
                   ~id:Id.Complete_work_manifest
                   ~f:(eval_step F.complete_work_manifest)
                   ();
                 Flow.Step.make
                   ~id:Id.Unset_work_manifest_id
                   ~f:
                     (eval_step (fun _ state ->
                          Abb.Future.return (Ok { state with State.work_manifest_id = None })))
                   ();
                 Flow.Step.make ~id:Id.Check_reconcile ~f:(eval_step F.check_reconcile) ();
                 Flow.Step.make
                   ~id:Id.Run_work_manifest_iter
                   ~f:(eval_step F.run_drift_reconcile_work_manifest_iter)
                   ();
                 Flow.Step.make
                   ~id:Id.Complete_work_manifest
                   ~f:(eval_step F.complete_work_manifest)
                   ();
               ])
          ~f:(fun _ _state -> function
            | `Step_err (_, `Noop state) -> Abb.Future.return (Ok (Id.Recover_noop, state))
            | _ -> Abb.Future.return (Error `Error))
          ~recover:[ (Id.Recover_noop, recover_noop_flow) ])
    in
    let event_kind_push_flow =
      Flow.Flow.(
        seq
          (action
             [
               Flow.Step.make ~id:Id.Update_drift_schedule ~f:(eval_step F.update_drift_schedule) ();
             ])
          event_kind_run_drift_flow)
    in
    let event_kind_repo_config_flow =
      Flow.Flow.(
        seq store_pull_request_flow
        @@ seq
             (action
                [
                  Flow.Step.make
                    ~id:Id.Publish_repo_config
                    ~f:(eval_step F.test_repo_config_validity)
                    ();
                ])
        @@ seq index_flow
        @@ action
             [
               Flow.Step.make ~id:Id.React_to_comment ~f:(eval_step F.react_to_comment) ();
               Flow.Step.make
                 ~id:Id.Complete_work_manifest
                 ~f:(eval_step F.complete_work_manifest)
                 ();
               Flow.Step.make ~id:Id.Publish_repo_config ~f:(eval_step F.publish_repo_config) ();
             ])
    in
    let event_kind_index_flow =
      Flow.Flow.(
        seq store_pull_request_flow
        @@ seq
             index_flow
             (seq
                complete_work_manifest_flow
                (action [ Flow.Step.make ~id:Id.Publish_index ~f:(eval_step F.publish_index) () ])))
    in
    let event_kind_unlock_flow =
      Flow.Flow.(action [ Flow.Step.make ~id:Id.Unlock ~f:(eval_step F.unlock) () ])
    in
    let event_kind_gate_approval =
      Flow.Flow.(
        action
          [
            Flow.Step.make ~id:Id.React_to_comment ~f:(eval_step F.react_to_comment) ();
            Flow.Step.make ~id:Id.Store_gate_approval ~f:(eval_step F.store_gate_approval) ();
          ])
    in
    let store_account_repository_flow =
      Flow.Flow.(
        action
          [
            Flow.Step.make
              ~id:Id.Store_account_repository
              ~f:(eval_step F.store_account_repository)
              ();
          ])
    in
    Flow.create
      ~log
      Flow.Flow.(
        seq
          store_account_repository_flow
          (choice
             ~id:Id.Test_event_kind
             ~f:F.test_event_kind
             [
               (Id.Event_kind_op, event_kind_op_flow);
               (Id.Event_kind_push, event_kind_push_flow);
               (Id.Event_kind_run_drift, event_kind_run_drift_flow);
               (Id.Event_kind_repo_config, event_kind_repo_config_flow);
               (Id.Event_kind_index, event_kind_index_flow);
               (Id.Event_kind_unlock, event_kind_unlock_flow);
               ( Id.Event_kind_help,
                 action [ Flow.Step.make ~id:Id.Publish_help ~f:(eval_step F.publish_help) () ] );
               ( Id.Event_kind_feedback,
                 action
                   [ Flow.Step.make ~id:Id.Record_feedback ~f:(eval_step F.record_feedback) () ] );
               (Id.Event_kind_gate_approval, event_kind_gate_approval);
             ]))
  (* Flow end *)

  module Runner = struct
    let resume_event ctx resume f =
      let state = Flow.Yield.state resume in
      (* We create a new [request_id] for each run of the flow.  Technically
         speaking [request_id] is a legacy name representing where the value
         came from and how it's commonly used but in reality it is used as a
         unique id per run.  Generally a flow is initiated by some external
         event, such as a web request which is where this value comes from.
         However sometimes a [resume] can happen inside of another run, for
         example when emitting a value or running a work manifest.  So we always
         create a new request ID before resuming a run, ensuring it gets a
         unique value. *)
      let request_id' = Ouuid.to_string (Ouuid.v4 ()) in
      Abbs_future_combinators.with_finally
        (fun () ->
          Logs.info (fun m ->
              m
                "%s : FLOW : RESUME_START : id=%s : new_request_id=%s"
                (Ctx.request_id ctx)
                state.State.request_id
                request_id');
          f (Ctx.set_request_id request_id' ctx) resume)
        ~finally:(fun () ->
          Logs.info (fun m ->
              m
                "%s : FLOW : RESUME_END : id=%s : new_request_id=%s"
                (Ctx.request_id ctx)
                state.State.request_id
                request_id');
          Abb.Future.return ())

    let rec exec_flow ctx resume' =
      let open Abb.Future.Infix_monad in
      Flow.resume ctx resume' flow
      >>= function
      | (`Success _ | `Failure _) as ret -> Abb.Future.return (Ok [ ret ])
      | `Yield resume' -> (
          let state = Flow.Yield.state resume' in
          match state.State.output with
          | Some (State.Io.O.Clone states) ->
              let open Abbs_future_combinators.Infix_result_monad in
              (* Cloning is used to fan a state out.  The new state's are
                 immediately resumed from where they left off. *)
              Abbs_future_combinators.List_result.map
                ~f:(fun state ->
                  let request_id = Ouuid.to_string (Ouuid.v4 ()) in
                  Logs.info (fun m ->
                      m "%s : CLONE : request_id=%s" state.State.request_id request_id);
                  let state = { state with State.request_id; input = None; output = None } in
                  let resume' = Flow.Yield.set_state state resume' in
                  exec_flow ctx resume')
                states
              >>= fun rets ->
              let rets = CCList.flatten rets in
              exec_flow
                ctx
                (Flow.Yield.set_state { state with State.input = None; output = None } resume')
              >>= fun vs -> Abb.Future.return (Ok (rets @ vs))
          | Some State.Io.O.Reset_ctx ->
              (* There are times when, inside of a single transaction, we want to
                 reset the context.  This is likely to reset any caches, because
                 maybe we suspect that the a remote object has changed due to
                 something that we've done.  But we don't want to give up our
                 ownership of the flow state yet.  Caches (in the [Dv] module)
                 are keyed off of a context request id, so by changing the
                 request id, we effectively clear the cache, as far as the flow
                 is concerned. *)
              let request_id = Ouuid.to_string (Ouuid.v4 ()) in
              Logs.info (fun m ->
                  m
                    "%s : RESET_CTX : old=%s : new=%s"
                    state.State.request_id
                    (Ctx.request_id ctx)
                    request_id);
              let ctx = Ctx.set_request_id request_id ctx in
              exec_flow
                ctx
                (Flow.Yield.set_state
                   { state with State.input = Some State.Io.I.Tabula_rasa; output = None }
                   resume')
          | Some _ | None -> (
              match state.State.work_manifest_id with
              | Some work_manifest_id ->
                  let open Abbs_future_combinators.Infix_result_monad in
                  let data = Flow.Yield.to_string resume' in
                  store_flow_state (Ctx.request_id ctx) (Ctx.storage ctx) work_manifest_id data
                  >>= fun () -> Abb.Future.return (Ok [ `Yield resume' ])
              | None -> Abb.Future.return (Ok [ `Yield resume' ])))

    let rec run_work_manifests request_id ctx =
      let module Wm = Terrat_work_manifest3 in
      let open Abbs_future_combinators.Infix_result_monad in
      Pgsql_pool.with_conn (Ctx.storage ctx) ~f:(fun db ->
          Pgsql_io.tx db ~f:(fun () ->
              query_next_pending_work_manifest request_id db
              >>= function
              | Some work_manifest -> (
                  let run =
                    create_client request_id (Ctx.config ctx) work_manifest.Wm.account
                    >>= fun client ->
                    run_work_manifest request_id (Ctx.config ctx) client work_manifest
                  in
                  let open Abb.Future.Infix_monad in
                  run
                  >>= function
                  | Ok () ->
                      update_work_manifest_state
                        request_id
                        db
                        work_manifest.Wm.id
                        Terrat_work_manifest3.State.Running
                      >>= fun _ ->
                      Abb.Future.fork
                        (notify_work_manifest_run_success request_id ctx work_manifest)
                      >>= fun _ -> Abb.Future.return (Ok `Cont)
                  | Error err ->
                      update_work_manifest_state
                        request_id
                        db
                        work_manifest.Wm.id
                        Terrat_work_manifest3.State.Aborted
                      >>= fun _ ->
                      Abb.Future.fork
                        (notify_work_manifest_run_failure request_id ctx work_manifest err)
                      >>= fun _ -> Abb.Future.return (Ok `Cont))
              | None -> Abb.Future.return (Ok `Done)))
      >>= function
      | `Cont -> run_work_manifests request_id ctx
      | `Done -> Abb.Future.return (Ok ())

    and resume_raw ctx resume_point update =
      let open Abbs_future_combinators.Infix_result_monad in
      Pgsql_pool.with_conn (Ctx.storage ctx) ~f:(fun db ->
          Pgsql_io.tx db ~f:(fun () ->
              match resume_point with
              | `Work_manifest work_manifest_id -> (
                  query_flow_state (Ctx.request_id ctx) db work_manifest_id
                  >>= function
                  | Some str ->
                      Abb.Future.return (Flow.Yield.of_string str)
                      >>= fun resume' ->
                      let state = update (Flow.Yield.state resume') in
                      let resume' = Flow.Yield.set_state state resume' in
                      resume_event (Ctx.set_storage db ctx) resume' exec_flow
                  | None -> Abb.Future.return (Error `Error))
              | `Resume resume' ->
                  let state = update (Flow.Yield.state resume') in
                  let resume' = Flow.Yield.set_state state resume' in
                  resume_event (Ctx.set_storage db ctx) resume' exec_flow))
      >>= fun rets ->
      let open Abb.Future.Infix_monad in
      Abbs_future_combinators.List.map
        ~f:(function
          | `Success _ ->
              let open Abb.Future.Infix_monad in
              (match resume_point with
                | `Work_manifest work_manifest_id ->
                    Pgsql_pool.with_conn (Ctx.storage ctx) ~f:(fun db ->
                        delete_flow_state (Ctx.request_id ctx) db work_manifest_id)
                | `Resume _ -> Abb.Future.return (Ok ()))
              >>= fun _ -> Abb.Future.return (Ok ())
          | `Failure _ ->
              let open Abb.Future.Infix_monad in
              (match resume_point with
                | `Work_manifest work_manifest_id ->
                    Pgsql_pool.with_conn (Ctx.storage ctx) ~f:(fun db ->
                        delete_flow_state (Ctx.request_id ctx) db work_manifest_id)
                | `Resume _ -> Abb.Future.return (Ok ()))
              >>= fun _ -> Abb.Future.return (Error `Error)
          | `Yield resume' -> (
              let state = Flow.Yield.state resume' in
              match state with
              | {
               State.output = Some State.Io.O.Checkpoint;
               work_manifest_id = Some work_manifest_id;
               request_id;
               _;
              } ->
                  Logs.info (fun m -> m "%s : RESUME_CHECKPOINTED_WITH_WORK_MANIFEST_ID" request_id);
                  resume_raw ctx (`Work_manifest work_manifest_id) (fun state ->
                      { state with State.input = Some State.Io.I.Checkpointed; output = None })
              | {
               State.output = Some State.Io.O.Checkpoint;
               work_manifest_id = None;
               request_id;
               _;
              } ->
                  Logs.info (fun m ->
                      m "%s : RESUME_CHECKPOINTED_WITHOUT_WORK_MANIFEST_ID" request_id);
                  let resume' = Flow.Yield.set_state state resume' in
                  resume_raw ctx (`Resume resume') (fun state ->
                      { state with State.input = Some State.Io.I.Checkpointed; output = None })
              | _ -> Abb.Future.return (Ok ())))
        rets
      >>= fun rets ->
      let open Abbs_future_combinators.Infix_result_monad in
      Abb.Future.return (CCResult.flatten_l rets) >>= fun _ -> Abb.Future.return (Ok ())

    and resume ctx work_manifest_id update =
      Abbs_future_combinators.with_finally
        (fun () -> resume_raw ctx (`Work_manifest work_manifest_id) update)
        ~finally:(fun () ->
          Abbs_future_combinators.ignore (run_work_manifests (Ctx.request_id ctx) ctx))

    and notify_work_manifest_run_success _request_id ctx work_manifest =
      let module Wm = Terrat_work_manifest3 in
      Abbs_future_combinators.ignore
        (resume_raw ctx (`Work_manifest work_manifest.Wm.id) (fun state ->
             { state with State.input = Some State.Io.I.Work_manifest_run_success }))

    and notify_work_manifest_run_failure _request_id ctx work_manifest err =
      let module Wm = Terrat_work_manifest3 in
      Abbs_future_combinators.ignore
        (resume_raw ctx (`Work_manifest work_manifest.Wm.id) (fun state ->
             { state with State.input = Some (State.Io.I.Work_manifest_run_failure err) }))

    let run ctx =
      let open Abb.Future.Infix_monad in
      Abb.Future.await_bind
        (function
          | `Det () -> Abb.Future.return ()
          | `Aborted ->
              Logs.info (fun m -> m "%s : RUNNER : ABORTED" (Ctx.request_id ctx));
              Abb.Future.return ()
          | `Exn (exn, bt_opt) ->
              Logs.err (fun m ->
                  m
                    "%s : RUNNER : %s : %s"
                    (Ctx.request_id ctx)
                    (Printexc.to_string exn)
                    (CCOption.map_or ~default:"" Printexc.raw_backtrace_to_string bt_opt));
              Abb.Future.return ())
        (run_work_manifests (Ctx.request_id ctx) ctx
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "%s : ERROR : %a" (Ctx.request_id ctx) Pgsql_io.pp_err err);
            Abb.Future.return ()
        | Error (#Pgsql_pool.err as err) ->
            Logs.err (fun m -> m "%s : ERROR : %a" (Ctx.request_id ctx) Pgsql_pool.pp_err err);
            Abb.Future.return ()
        | Error `Error -> Abb.Future.return ())
  end

  let log_event state =
    match state.State.event with
    | Event.Pull_request_open { account; user; repo; pull_request_id } ->
        Logs.info (fun m ->
            m
              "%s : EVENT : PULL_REQUEST_OPEN : account=%s : user=%s : repo=%s : pull_number=%s"
              state.State.request_id
              (S.Api.Account.to_string account)
              (S.Api.User.to_string user)
              (S.Api.Repo.to_string repo)
              (S.Api.Pull_request.Id.to_string pull_request_id))
    | Event.Pull_request_close { account; user; repo; pull_request_id } ->
        Logs.info (fun m ->
            m
              "%s : EVENT : PULL_REQUEST_CLOSE : account=%s : user=%s : repo=%s : pull_number=%s"
              state.State.request_id
              (S.Api.Account.to_string account)
              (S.Api.User.to_string user)
              (S.Api.Repo.to_string repo)
              (S.Api.Pull_request.Id.to_string pull_request_id))
    | Event.Pull_request_sync { account; user; repo; pull_request_id } ->
        Logs.info (fun m ->
            m
              "%s : EVENT : PULL_REQUEST_SYNC : account=%s : user=%s : repo=%s : pull_number=%s"
              state.State.request_id
              (S.Api.Account.to_string account)
              (S.Api.User.to_string user)
              (S.Api.Repo.to_string repo)
              (S.Api.Pull_request.Id.to_string pull_request_id))
    | Event.Pull_request_ready_for_review { account; user; repo; pull_request_id } ->
        Logs.info (fun m ->
            m
              "%s : EVENT : PULL_REQUEST_READY_FOR_REVIEW : account=%s : user=%s : repo=%s : \
               pull_number=%s"
              state.State.request_id
              (S.Api.Account.to_string account)
              (S.Api.User.to_string user)
              (S.Api.Repo.to_string repo)
              (S.Api.Pull_request.Id.to_string pull_request_id))
    | Event.Pull_request_comment { account; comment; repo; pull_request_id; comment_id; user } ->
        Logs.info (fun m ->
            m
              "%s : EVENT : PULL_REQUEST_COMMENT : account=%s : user=%s : repo=%s : pull_number=%s \
               : comment_id=%d : comment=%s "
              state.State.request_id
              (S.Api.Account.to_string account)
              (S.Api.User.to_string user)
              (S.Api.Repo.to_string repo)
              (S.Api.Pull_request.Id.to_string pull_request_id)
              comment_id
              (Terrat_comment.to_string comment))
    | Event.Push { account; user; repo; branch } ->
        Logs.info (fun m ->
            m
              "%s : EVENT : PUSH : account=%s : user=%s : repo=%s : branch=%s"
              state.State.request_id
              (S.Api.Account.to_string account)
              (S.Api.User.to_string user)
              (S.Api.Repo.to_string repo)
              (S.Api.Ref.to_string branch))
    | Event.Run_scheduled_drift ->
        Logs.info (fun m -> m "%s : EVENT : RUN_SCHEDULED_DRIFT" state.State.request_id)
    | Event.Run_drift _ -> assert false

  let run_event ctx event =
    let open Abb.Future.Infix_monad in
    Abb.Future.fork
      (Abbs_future_combinators.with_finally
         (fun () ->
           Logs.info (fun m -> m "%s : FLOW : START" (Ctx.request_id ctx));
           let state =
             {
               State.request_id = Ctx.request_id ctx;
               event;
               work_manifest_id = None;
               st = State.St.Initial;
               input = None;
               output = None;
             }
           in
           log_event state;
           Runner.resume_raw ctx (`Resume (Flow.yield_of_state state)) CCFun.id)
         ~finally:(fun () ->
           Logs.info (fun m -> m "%s : FLOW : END" (Ctx.request_id ctx));
           Abbs_future_combinators.ignore (Abb.Future.fork (Runner.run ctx))))
    >>= fun _ -> Abb.Future.return ()

  let resume_work ctx work_manifest_id update =
    Abb.Future.await_bind
      (function
        | `Det r -> Abb.Future.return r
        | `Aborted ->
            Logs.err (fun m -> m "%s : RUNNER : ABORTED" (Ctx.request_id ctx));
            Abb.Future.return (Error `Error)
        | `Exn (exn, bt_opt) ->
            Logs.err (fun m ->
                m
                  "%s : RUNNER : %s : %s"
                  (Ctx.request_id ctx)
                  (Printexc.to_string exn)
                  (CCOption.map_or ~default:"" Printexc.raw_backtrace_to_string bt_opt));
            Abb.Future.return (Error `Error))
      (let open Abb.Future.Infix_monad in
       Abbs_future_combinators.with_finally
         (fun () ->
           Runner.resume ctx work_manifest_id update
           >>= function
           | Ok () -> Abb.Future.return (Ok ())
           | Error (#Pgsql_pool.err as err) ->
               Logs.err (fun m ->
                   m
                     "%s : work_manifest_id=%a : %a"
                     (Ctx.request_id ctx)
                     Uuidm.pp
                     work_manifest_id
                     Pgsql_pool.pp_err
                     err);
               Abb.Future.return (Error `Error)
           | Error (#Pgsql_io.err as err) ->
               Logs.err (fun m ->
                   m
                     "%s : work_manifest_id=%a : %a"
                     (Ctx.request_id ctx)
                     Uuidm.pp
                     work_manifest_id
                     Pgsql_io.pp_err
                     err);
               Abb.Future.return (Error `Error)
           | Error (#Flow.Yield.of_string_err as err) ->
               Logs.err (fun m ->
                   m
                     "%s : work_manifest_id=%a : %a"
                     (Ctx.request_id ctx)
                     Uuidm.pp
                     work_manifest_id
                     Flow.Yield.pp_of_string_err
                     err);
               Abb.Future.return (Error `Error)
           | Error `Error ->
               Logs.err (fun m ->
                   m
                     "%s : work_manifest_id=%a : ERROR"
                     (Ctx.request_id ctx)
                     Uuidm.pp
                     work_manifest_id);
               Abb.Future.return (Error `Error))
         ~finally:(fun () -> Abbs_future_combinators.ignore (Abb.Future.fork (Runner.run ctx))))

  (* If the flow future finishes first, fail, otherwise return what the flow's
     promise would return. *)
  let first ?(timeout = 120.0) workflow fut =
    let open Abb.Future.Infix_monad in
    Abbs_future_combinators.first
      (Abbs_future_combinators.first (Abb.Sys.sleep timeout >>| fun () -> Error `Timeout) workflow
      >>= fun (_, other) -> Abb.Future.abort other >>= fun () -> Abb.Future.return (Error `Error))
      (fut
      >>= function
      | Ok r -> Abb.Future.return (Ok r)
      | Error err -> Abb.Future.return (Error err))
    >>= fun (r, _) -> Abb.Future.return r

  let run_pull_request_open ~ctx ~account ~user ~repo ~pull_request_id () =
    let open Abb.Future.Infix_monad in
    let event = Event.Pull_request_open { account; user; repo; pull_request_id } in
    (run_event ctx event >>= fun _ -> Abb.Future.return (Ok ())
      : (unit, [ `Error ]) result Abb.Future.t
      :> (unit, [> `Error ]) result Abb.Future.t)

  let run_pull_request_close ~ctx ~account ~user ~repo ~pull_request_id () =
    let open Abb.Future.Infix_monad in
    let event = Event.Pull_request_close { account; user; repo; pull_request_id } in
    (run_event ctx event >>= fun _ -> Abb.Future.return (Ok ())
      : (unit, [ `Error ]) result Abb.Future.t
      :> (unit, [> `Error ]) result Abb.Future.t)

  let run_pull_request_sync ~ctx ~account ~user ~repo ~pull_request_id () =
    let open Abb.Future.Infix_monad in
    let event = Event.Pull_request_sync { account; user; repo; pull_request_id } in
    (run_event ctx event >>= fun _ -> Abb.Future.return (Ok ())
      : (unit, [ `Error ]) result Abb.Future.t
      :> (unit, [> `Error ]) result Abb.Future.t)

  let run_pull_request_ready_for_review ~ctx ~account ~user ~repo ~pull_request_id () =
    let open Abb.Future.Infix_monad in
    let event = Event.Pull_request_ready_for_review { account; user; repo; pull_request_id } in
    (run_event ctx event >>= fun _ -> Abb.Future.return (Ok ())
      : (unit, [ `Error ]) result Abb.Future.t
      :> (unit, [> `Error ]) result Abb.Future.t)

  let run_pull_request_comment ~ctx ~account ~user ~comment ~repo ~pull_request_id ~comment_id () =
    let open Abb.Future.Infix_monad in
    let event =
      Event.Pull_request_comment { account; user; comment; repo; pull_request_id; comment_id }
    in
    (run_event ctx event >>= fun _ -> Abb.Future.return (Ok ())
      : (unit, [ `Error ]) result Abb.Future.t
      :> (unit, [> `Error ]) result Abb.Future.t)

  let run_push ~ctx ~account ~user ~repo ~branch () =
    let open Abb.Future.Infix_monad in
    let event = Event.Push { account; user; repo; branch } in
    (run_event ctx event >>= fun _ -> Abb.Future.return (Ok ())
      : (unit, [ `Error ]) result Abb.Future.t
      :> (unit, [> `Error ]) result Abb.Future.t)

  let run_work_manifest_initiate ~ctx ~encryption_key work_manifest_id initiate =
    let open Abb.Future.Infix_monad in
    let p = Abb.Future.Promise.create () in
    Abb.Future.fork
      (resume_work ctx work_manifest_id (fun state ->
           Logs.info (fun m ->
               m "%s : INITIATE : state=%s" (Ctx.request_id ctx) state.State.request_id);
           {
             state with
             State.input = Some (State.Io.I.Work_manifest_initiate { encryption_key; initiate; p });
           }))
    >>= fun fut ->
    (first fut (Abb.Future.Promise.future p)
      : (Terrat_api_components.Work_manifest.t option, [ `Error ]) result Abb.Future.t
      :> (Terrat_api_components.Work_manifest.t option, [> `Error ]) result Abb.Future.t)

  let run_work_manifest_result ~ctx work_manifest_id result =
    let open Abb.Future.Infix_monad in
    let p = Abb.Future.Promise.create () in
    Abb.Future.fork
      (resume_work ctx work_manifest_id (fun state ->
           Logs.info (fun m ->
               m "%s : RESULT : state=%s" (Ctx.request_id ctx) state.State.request_id);
           { state with State.input = Some (State.Io.I.Work_manifest_result { result; p }) }))
    >>= fun fut ->
    (first fut (Abb.Future.Promise.future p)
      : (unit, [ `Error ]) result Abb.Future.t
      :> (unit, [> `Error ]) result Abb.Future.t)

  let run_plan_store ~ctx work_manifest_id plan =
    let module Pc = Terrat_api_components.Plan_create in
    let open Abb.Future.Infix_monad in
    let p = Abb.Future.Promise.create () in
    let { Pc.path; workspace; plan_data; has_changes } = plan in
    let dirspace = { Terrat_dirspace.dir = path; workspace } in
    Abb.Future.fork
      (resume_work ctx work_manifest_id (fun state ->
           Logs.info (fun m ->
               m "%s : PLAN_STORE : state=%s" (Ctx.request_id ctx) state.State.request_id);
           {
             state with
             State.input =
               Some (State.Io.I.Plan_store { dirspace; data = plan_data; has_changes; p });
           }))
    >>= fun fut ->
    (first fut (Abb.Future.Promise.future p)
      : (unit, [ `Error ]) result Abb.Future.t
      :> (unit, [> `Error ]) result Abb.Future.t)

  let run_plan_fetch ~ctx work_manifest_id dirspace =
    let open Abb.Future.Infix_monad in
    let p = Abb.Future.Promise.create () in
    Abb.Future.fork
      (resume_work ctx work_manifest_id (fun state ->
           Logs.info (fun m ->
               m "%s : PLAN_FETCH : state=%s" (Ctx.request_id ctx) state.State.request_id);
           { state with State.input = Some (State.Io.I.Plan_fetch { dirspace; p }) }))
    >>= fun fut ->
    (first fut (Abb.Future.Promise.future p)
      : (string option, [ `Error ]) result Abb.Future.t
      :> (string option, [> `Error ]) result Abb.Future.t)

  let run_work_manifest_failure ~ctx work_manifest_id =
    let open Abb.Future.Infix_monad in
    let p = Abb.Future.Promise.create () in
    Abb.Future.fork
      (resume_work ctx work_manifest_id (fun state ->
           Logs.info (fun m ->
               m "%s : WORK_MANIFEST_FAILURE : state=%s" (Ctx.request_id ctx) state.State.request_id);
           { state with State.input = Some (State.Io.I.Work_manifest_failure { p }) }))
    >>= fun fut ->
    (first fut (Abb.Future.Promise.future p)
      : (unit, [ `Error ]) result Abb.Future.t
      :> (unit, [> `Error ]) result Abb.Future.t)

  let run_scheduled_drift ctx =
    Logs.info (fun m -> m "%s : SCHEDULED_DRIFT" (Ctx.request_id ctx));
    Abbs_future_combinators.to_result (run_event ctx Event.Run_scheduled_drift)

  let run_plan_cleanup ctx =
    let open Abb.Future.Infix_monad in
    Logs.info (fun m -> m "%s : PLAN_CLEANUP : START" (Ctx.request_id ctx));
    Abbs_time_it.run
      (fun t -> Logs.info (fun m -> m "%s : PLAN_CLEANUP : END : time=%f" (Ctx.request_id ctx) t))
      (fun () ->
        Pgsql_pool.with_conn (Ctx.storage ctx) ~f:(fun db -> cleanup_plans (Ctx.request_id ctx) db))
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error `Error -> Abb.Future.return (Error `Error)
    | Error (#Pgsql_pool.err as err) ->
        Logs.err (fun m -> m "%s : PLAN_CLEANUP : %a" (Ctx.request_id ctx) Pgsql_pool.pp_err err);
        Abb.Future.return (Error `Error)

  let run_flow_state_cleanup ctx =
    let open Abb.Future.Infix_monad in
    Logs.info (fun m -> m "%s : FLOW_STATE_CLEANUP" (Ctx.request_id ctx));
    Pgsql_pool.with_conn (Ctx.storage ctx) ~f:(fun db ->
        cleanup_flow_states (Ctx.request_id ctx) db)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error `Error -> Abb.Future.return (Error `Error)
    | Error (#Pgsql_pool.err as err) ->
        Logs.err (fun m ->
            m "%s : FLOW_STATE_CLEANUP : %a" (Ctx.request_id ctx) Pgsql_pool.pp_err err);
        Abb.Future.return (Error `Error)

  let run_repo_config_cleanup ctx =
    let open Abb.Future.Infix_monad in
    Logs.info (fun m -> m "%s : REPO_CONFIG_CLEANUP" (Ctx.request_id ctx));
    Pgsql_pool.with_conn (Ctx.storage ctx) ~f:(fun db ->
        cleanup_repo_configs (Ctx.request_id ctx) db)
    >>= function
    | Ok () -> Abb.Future.return (Ok ())
    | Error `Error -> Abb.Future.return (Error `Error)
    | Error (#Pgsql_pool.err as err) ->
        Logs.err (fun m ->
            m "%s : REPO_CONFIG_CLEANUP : %a" (Ctx.request_id ctx) Pgsql_pool.pp_err err);
        Abb.Future.return (Error `Error)
end
