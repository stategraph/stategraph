[@@@warning "-32-53"]

let name = "nyi"
let enforce_installation_access ~request_id use account_id db = raise (Failure "nyi")

module Api = Terrat_vcs_api_nyi

module Unlock_id = struct
  type t = unit

  let of_pull_request id = raise (Failure "nyi")
  let drift () = raise (Failure "nyi")
  let to_string t = raise (Failure "nyi")
end

module Db = struct
  type t = Pgsql_io.t

  let store_account_repository ~request_id db account repo = raise (Failure "nyi")
  let lock_repository ~request_id db account repo = raise (Failure "nyi")
  let store_pull_request ~request_id db pull_request = raise (Failure "nyi")
  let store_index ~request_id db work_manifest_id index = raise (Failure "nyi")
  let store_index_result ~request_id db work_manifest_id index_result = raise (Failure "nyi")
  let store_repo_config_json ~request_id db account ref_ json = raise (Failure "nyi")

  let store_repo_config_history ~request_id db account repo ~branch ~sha json =
    raise (Failure "nyi")

  let store_repo_tree ~request_id db account ref_ files = raise (Failure "nyi")
  let store_flow_state ~request_id db work_manifest_id state = raise (Failure "nyi")

  let store_dirspaceflows ~request_id ~base_ref ~branch_ref db repo dirspaceflows =
    raise (Failure "nyi")

  let store_tf_operation_result ~request_id db work_manifest_id result = raise (Failure "nyi")
  let store_tf_operation_result2 ~request_id db work_manifest_id result = raise (Failure "nyi")
  let store_drift_schedule ~request_id db repo drift = raise (Failure "nyi")
  let query_account_status ~request_id db account = raise (Failure "nyi")
  let query_index ~request_id db account ref_ = raise (Failure "nyi")
  let query_repo_config_json ~request_id db account ref_ = raise (Failure "nyi")
  let query_repo_tree ?base_ref ~request_id db accoutn ref_ = raise (Failure "nyi")
  let query_next_pending_work_manifest ?new_age ~request_id db = raise (Failure "nyi")
  let query_flow_state ~request_id db work_manifest_id = raise (Failure "nyi")
  let delete_flow_state ~request_id db work_manifest_id = raise (Failure "nyi")
  let query_pull_request_out_of_change_applies ~request_id db pull_request = raise (Failure "nyi")
  let query_applied_dirspaces_for_context ~request_id db context = raise (Failure "nyi")
  let query_applied_dirspaces ~request_id db pull_request = raise (Failure "nyi")

  let query_dirspaces_without_valid_plans
      ~request_id
      ~base_ref
      ~branch_ref
      db
      pull_request
      dirspaces =
    raise (Failure "nyi")

  let query_conflicting_work_manifests_in_repo ~request_id db pull_request dirspaces op =
    raise (Failure "nyi")

  let query_conflicting_work_manifests_in_repo_for_context ~request_id db context dirspaces op =
    raise (Failure "nyi")

  let query_dirspaces_owned_by_other_pull_requests ~request_id db pull_request dirspaces =
    raise (Failure "nyi")

  let query_missing_drift_scheduled_runs ~request_id db = raise (Failure "nyi")
  let cleanup_repo_configs ~request_id db = raise (Failure "nyi")
  let cleanup_flow_states ~request_id db = raise (Failure "nyi")
  let cleanup_plans ~request_id db = raise (Failure "nyi")
  let unlock ~request_id db repo unlock_id = raise (Failure "nyi")
  let query_plan ~request_id db work_manifest_id dirspace = raise (Failure "nyi")
  let store_plan ~request_id db work_manifest_id dirspace data has_changes = raise (Failure "nyi")
  let store_branch_hash ~request_id ~branch_name ~branch_ref repo db = raise (Failure "nyi")
  let query_repo_by_id ~request_id db installation_id repo_id = raise (Failure "nyi")
  let delete_repo ~request_id db installation_id repo_id = raise (Failure "nyi")
end

module Apply_requirements = struct
  module Result = struct
    type t

    let passed t = raise (Failure "nyi")
    let approved_reviews t = raise (Failure "nyi")
  end

  let eval ~request_id config user client repo_config pull_request dirspace_configs =
    raise (Failure "nyi")
end

module Tier = struct
  let check ~request_id user account db = raise (Failure "nyi")
end

module Gate = struct
  let add_approval ~request_id ~token ~approver pull_request db = raise (Failure "nyi")
  let eval ~request_id client dirspaces pull_request db = raise (Failure "nyi")
end

module Comment = struct
  let publish_comment ~request_id client user pull_request msg = raise (Failure "nyi")
end

module Repo_config = struct
  let fetch_with_provenance ?system_defaults ?built_config request_id client repo ref_ =
    raise (Failure "nyi")
end

module Access_control = struct
  let query ~request_id client repo user match_ = raise (Failure "nyi")
  let is_ci_changed ~request_id client repo diffs = raise (Failure "nyi")
end

module Commit_check = struct
  let make_dirspace_title ~run_type dirspace = raise (Failure "nyi")

  let make_dirspace
      ?work_manifest
      ~config
      ~description
      ~run_type
      ~dirspace
      ~status
      ~repo
      ~account
      () =
    raise (Failure "nyi")

  let make_hook ?work_manifest ~config ~description ~run_type ~hook ~status ~repo ~account () =
    raise (Failure "nyi")

  let make_str ?work_manifest ~config ~description ~status ~repo ~account s = raise (Failure "nyi")
end

module Work_manifest = struct
  let run ~request_id config client = raise (Failure "nyi")
  let create ~request_id db work_manifest = raise (Failure "nyi")
  let query' ~request_id db ids = raise (Failure "nyi")
  let query ~request_id db work_manifest_id = raise (Failure "nyi")
  let query_by_run_id ~request_id db run_id = raise (Failure "nyi")
  let update_state ~request_id db work_manifest_id state = raise (Failure "nyi")
  let update_run_id ~request_id db work_manifest_id run_id = raise (Failure "nyi")
  let update_changes ~request_id db work_manifest_id dirspaceflows = raise (Failure "nyi")
  let update_denied_dirspaces ~request_id db work_manifest_id denies = raise (Failure "nyi")
  let update_steps ~request_id db work_manifest_id steps = raise (Failure "nyi")
  let result result = raise (Failure "nyi")
  let result2 result = raise (Failure "nyi")
end

module Ui = struct
  let work_manifest_url config account = raise (Failure "nyi")
end

module Stacks = struct
  include Terrat_vcs_stacks.Make (struct
    module Installation_id = Api.Account.Id
    module Repo_id = Api.Repo.Id
    module Pull_request_id = Api.Pull_request.Id
    module Config = Api.Config

    type db = Db.t

    let vcs = name
    let route_root () = raise (Failure "nyi")

    let store_stacks ~request_id ~installation_id:_ ~repo_id ~pull_request_id stacks db =
      raise (Failure "nyi")

    let query_stacks ~request_id ~installation_id:_ ~repo_id ~pull_request_id db =
      raise (Failure "nyi")

    let query_dirspace_states ~request_id ~installation_id:_ ~repo_id ~pull_request_id db =
      raise (Failure "nyi")

    let enforce_installation_access ~request_id user installation_id db = raise (Failure "nyi")
  end)
end

module Job_context = struct
  let create_or_get_for_pull_request ~request_id db account repo pull_request_id =
    raise (Failure "nyi")

  let create_or_get_for_branch ~request_id db account repo branch = raise (Failure "nyi")
  let query ~request_id db id = raise (Failure "nyi")

  module Job = struct
    let create ~request_id db type_ context initiator = raise (Failure "nyi")
    let query ~request_id db ~job_id = raise (Failure "nyi")
    let query_all_by_context_id ~request_id db ~context_id () = raise (Failure "nyi")
    let query_pending_by_context_id ~request_id db ~context_id () = raise (Failure "nyi")
    let query_by_work_manifest_id ~request_id db ~work_manifest_id () = raise (Failure "nyi")
    let update_state ~request_id db ~job_id state = raise (Failure "nyi")
    let add_work_manifest ~request_id db ~job_id ~work_manifest_id () = raise (Failure "nyi")
    let query_work_manifests ~request_id db ~job_id () = raise (Failure "nyi")
  end

  module Compute_node = struct
    let create ~request_id ~id ~capabilities db = raise (Failure "nyi")
    let query ~request_id ~compute_node_id db = raise (Failure "nyi")
    let query_work ~request_id ~compute_node_id db = raise (Failure "nyi")
    let update_state ~request_id ~compute_node_id db state = raise (Failure "nyi")
    let set_work ~request_id ~compute_node_id ~work_manifest db work = raise (Failure "nyi")
  end
end
