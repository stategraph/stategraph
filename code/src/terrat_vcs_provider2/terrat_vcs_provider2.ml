type premium_features =
  [ `Access_control
  | `Multiple_drift_schedules
  | `Gatekeeping
  | `Require_completed_reviews
  | `Notifications_summary
  ]
[@@deriving show]

type premium_feature_err = [ `Premium_feature_err of premium_features ] [@@deriving show]

type fetch_repo_config_with_provenance_err =
  [ Terrat_base_repo_config_v1.of_version_1_err
  | `Repo_config_schema_err of string * Jsonschema_check.Validation_err.t list
  | `Config_merge_err of (string * string) * (string option * Yojson.Safe.t * Yojson.Safe.t)
  | `Json_decode_err of string * string
  | `Unexpected_err of string
  | `Yaml_decode_err of string * string
  | premium_feature_err
  | `Error
  ]
[@@deriving show]

type access_control_query_err = [ `Error ] [@@deriving show]
type access_control_err = access_control_query_err [@@deriving show]

type gate_add_approval_err =
  [ `Error
  | `No_matching_token_err of string
  | `Premium_feature_err of premium_features
  ]
[@@deriving show]

type gate_eval_err = [ `Error ] [@@deriving show]
type tier_check_err = [ `Error ] [@@deriving show]

type run_work_manifest_err =
  [ `Failed_to_start_with_msg_err of string
  | `Failed_to_start
  | `Missing_workflow
  | `Job_failed of string
  | `Error
  ]

module Account_status = struct
  type t =
    [ `Active
    | `Expired
    | `Disabled
    | `Trial_ending of Duration.t
    ]
  [@@deriving show]
end

module Work_manifest_result = struct
  type t = {
    dirspaces_success : (Terrat_change.Dirspace.t * bool) list;
    overall_success : bool;
    post_hooks_success : bool;
    pre_hooks_success : bool;
  }
end

module Conflicting_work_manifests = struct
  type 'a t =
    | Conflicting of 'a list
    | Maybe_stale of 'a list
end

module Target = struct
  type ('pr, 'repo) t =
    | Pr of 'pr
    | Drift of {
        repo : 'repo;
        branch : string;
      }
  [@@deriving show]
end

module Index = struct
  module Failure = struct
    type t = {
      file : string;
      line_num : int option;
      error : string;
    }
  end

  type t = {
    success : bool;
    failures : Failure.t list;
    index : Terrat_base_repo_config_v1.Index.t;
  }
end

module Gate_eval = struct
  type t = {
    dirspace : Terrat_dirspace.t option;
    token : string option;
    name : string option;
    result : Terrat_gate.Result.t;
  }
  [@@deriving show]
end

module Msg = struct
  type access_control_denied =
    [ `All_dirspaces of Terrat_access_control2.R.Deny.t list
    | `Ci_config_update of Terrat_base_repo_config_v1.Access_control.Match_list.t
    | `Dirspaces of Terrat_access_control2.R.Deny.t list
    | `Files of string * Terrat_base_repo_config_v1.Access_control.Match_list.t
    | `Lookup_err
    | `Terrateam_config_update of Terrat_base_repo_config_v1.Access_control.Match_list.t
    | `Unlock of Terrat_base_repo_config_v1.Access_control.Match_list.t
    ]

  type ('account, 'db, 'pull_request, 'target, 'apply_requirements, 'config) t =
    | Access_control_denied of (string * access_control_denied)
    | Account_expired
    | Apply_no_matching_dirspaces
    | Apply_requirements_config_err of [ Terrat_tag_query_ast.err | `Invalid_query of string ]
    | Apply_requirements_validation_err
    | Autoapply_running
    | Automerge_failure of ('pull_request * string)
    | Bad_custom_branch_tag_pattern of (string * string)
    | Bad_glob of string
    | Build_config_err of Terrat_base_repo_config_v1.of_version_1_json_err
    | Build_config_failure of string
    | Build_tree_failure of string
    | Conflicting_work_manifests of ('account, 'target) Terrat_work_manifest3.Existing.t list
    | Dest_branch_no_match of 'pull_request
    | Dirspaces_owned_by_other_pull_request of (Terrat_change.Dirspace.t * 'pull_request) list
    | Gate_check_failure of Gate_eval.t list
    | Help
    | Index_complete of (bool * (string * int option * string) list)
    | Invalid_unlock_id of string
    | Maybe_stale_work_manifests of ('account, 'target) Terrat_work_manifest3.Existing.t list
    | Mismatched_refs
    | Missing_plans of Terrat_change.Dirspace.t list
    | Plan_all_changes_applied
    | Plan_no_matching_dirspaces
    | Premium_feature_err of premium_features
    | Pull_request_not_appliable of ('pull_request * 'apply_requirements)
    | Pull_request_not_mergeable
    | Repo_config of (string list * Terrat_base_repo_config_v1.derived Terrat_base_repo_config_v1.t)
    | Repo_config_err of Terrat_base_repo_config_v1.of_version_1_err
    | Repo_config_failure of string
    | Repo_config_merge_err of ((string * string) * (string option * Yojson.Safe.t * Yojson.Safe.t))
    | Repo_config_parse_failure of string * string
    | Repo_config_schema_err of (string * Jsonschema_check.Validation_err.t list)
    | Run_work_manifest_err of
        [ `Failed_to_start_with_msg_err of string | `Failed_to_start | `Missing_workflow ]
    | Str_template_err of Str_template.err
    | Synthesize_config_err of Terrat_change_match3.synthesize_config_err
    | Tag_query_err of Terrat_tag_query_ast.err
    | Tf_op_result2 of {
        account_status : Account_status.t;
        db : 'db;
        config : 'config;
        is_layered_run : bool;
        remaining_layers : Terrat_change_match3.Dirspace_config.t list list;
        repo_config : Terrat_base_repo_config_v1.derived Terrat_base_repo_config_v1.t;
        result : Terrat_api_components_work_manifest_tf_operation_result2.t;
        synthesized_config : Terrat_change_match3.Config.t;
        work_manifest : ('account, 'target) Terrat_work_manifest3.Existing.t;
      }
    | Tier_check of Terrat_tier.Check.t
    | Unexpected_temporary_err
    | Unlock_success
    | Work_manifest_run_failed of { run_id : string }
end

module type S = sig
  val name : string

  module Api : Terrat_vcs_api.S

  val enforce_installation_access :
    request_id:string ->
    Terrat_user.t ->
    Api.Account.Id.t ->
    Pgsql_io.t ->
    (unit, [> `Forbidden ]) result Abb.Future.t

  module Unlock_id : sig
    type t

    val of_pull_request : Api.Pull_request.Id.t -> t
    val drift : unit -> t
    val to_string : t -> string
  end

  module Db : sig
    type t = Pgsql_io.t

    val store_account_repository :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Repo.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val lock_repository :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Repo.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_pull_request :
      request_id:string ->
      t ->
      (Terrat_change.Diff.t list, bool) Api.Pull_request.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_index :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_api_components.Work_manifest_index_result.t ->
      (Index.t, [> `Error ]) result Abb.Future.t

    val store_index_result :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_api_components.Work_manifest_index_result.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_repo_config_json :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      Yojson.Safe.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_repo_config_history :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Repo.t ->
      branch:Api.Ref.t ->
      sha:Api.Ref.t ->
      Yojson.Safe.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_repo_tree :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      Terrat_api_components.Work_manifest_build_tree_result.Files.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_flow_state :
      request_id:string -> t -> Uuidm.t -> string -> (unit, [> `Error ]) result Abb.Future.t

    val store_dirspaceflows :
      request_id:string ->
      base_ref:Api.Ref.t ->
      branch_ref:Api.Ref.t ->
      t ->
      Api.Repo.t ->
      (Terrat_base_repo_config_v1.Dirs.Dir.Branch_target.t
      * Terrat_change.Dirspaceflow.Workflow.t option)
      Terrat_change.Dirspaceflow.t
      list ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_tf_operation_result :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_api_components_work_manifest_tf_operation_result.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_tf_operation_result2 :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_api_components_work_manifest_tf_operation_result2.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_drift_schedule :
      request_id:string ->
      t ->
      Api.Repo.t ->
      Terrat_base_repo_config_v1.Drift.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val query_account_status :
      request_id:string -> t -> Api.Account.t -> (Account_status.t, [> `Error ]) result Abb.Future.t

    val query_index :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      (Index.t option, [> `Error ]) result Abb.Future.t

    val query_repo_config_json :
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      (Yojson.Safe.t option, [> `Error ]) result Abb.Future.t

    val query_repo_tree :
      ?base_ref:Api.Ref.t ->
      request_id:string ->
      t ->
      Api.Account.t ->
      Api.Ref.t ->
      (Terrat_api_components.Work_manifest_build_tree_result.Files.t option, [> `Error ]) result
      Abb.Future.t

    val query_next_pending_work_manifest :
      ?new_age:bool ->
      request_id:string ->
      t ->
      ( ( Api.Account.t,
          ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        option,
        [> `Error ] )
      result
      Abb.Future.t

    val query_flow_state :
      request_id:string -> t -> Uuidm.t -> (string option, [> `Error ]) result Abb.Future.t

    val delete_flow_state :
      request_id:string -> t -> Uuidm.t -> (unit, [> `Error ]) result Abb.Future.t

    val query_pull_request_out_of_change_applies :
      request_id:string ->
      t ->
      ('diff, 'checks) Api.Pull_request.t ->
      (Terrat_change.Dirspace.t list, [> `Error ]) result Abb.Future.t

    val query_applied_dirspaces_for_context :
      request_id:string ->
      t ->
      (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
      (Terrat_change.Dirspace.t list, [> `Error ]) result Abb.Future.t

    val query_applied_dirspaces :
      request_id:string ->
      t ->
      ('diff, 'checks) Api.Pull_request.t ->
      (Terrat_change.Dirspace.t list, [> `Error ]) result Abb.Future.t

    val query_dirspaces_without_valid_plans :
      request_id:string ->
      base_ref:Api.Ref.t ->
      branch_ref:Api.Ref.t ->
      t ->
      ('diff, 'checks) Api.Pull_request.t ->
      Terrat_change.Dirspace.t list ->
      (Terrat_change.Dirspace.t list, [> `Error ]) result Abb.Future.t

    val query_conflicting_work_manifests_in_repo :
      request_id:string ->
      t ->
      ('diff, 'checks) Api.Pull_request.t ->
      Terrat_change.Dirspace.t list ->
      [< `Plan | `Apply ] ->
      ( ( Api.Account.t,
          ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        Conflicting_work_manifests.t
        option,
        [> `Error ] )
      result
      Abb.Future.t

    val query_conflicting_work_manifests_in_repo_for_context :
      request_id:string ->
      t ->
      (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
      Terrat_change.Dirspace.t list ->
      [< `Plan | `Apply ] ->
      ( ( Api.Account.t,
          ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        Conflicting_work_manifests.t
        option,
        [> `Error ] )
      result
      Abb.Future.t

    val query_dirspaces_owned_by_other_pull_requests :
      request_id:string ->
      t ->
      ('diff, 'checks) Api.Pull_request.t ->
      Terrat_change.Dirspace.t list ->
      ((Terrat_change.Dirspace.t * (unit, unit) Api.Pull_request.t) list, [> `Error ]) result
      Abb.Future.t

    val query_missing_drift_scheduled_runs :
      request_id:string ->
      t ->
      ( (string * Api.Account.t * Api.Repo.t * bool * Terrat_tag_query.t * (string * string) option)
        list,
        [> `Error ] )
      result
      Abb.Future.t

    val cleanup_repo_configs : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t
    val cleanup_flow_states : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t
    val cleanup_plans : request_id:string -> t -> (unit, [> `Error ]) result Abb.Future.t

    val unlock :
      request_id:string -> t -> Api.Repo.t -> Unlock_id.t -> (unit, [> `Error ]) result Abb.Future.t

    val query_plan :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_dirspace.t ->
      (string option, [> `Error ]) result Abb.Future.t

    val store_plan :
      request_id:string ->
      t ->
      Uuidm.t ->
      Terrat_dirspace.t ->
      string ->
      bool ->
      (unit, [> `Error ]) result Abb.Future.t

    val store_branch_hash :
      request_id:string ->
      branch_name:Api.Ref.t ->
      branch_ref:Api.Ref.t ->
      Api.Repo.t ->
      t ->
      (unit, [> `Error ]) result Abb.Future.t

    val query_repo_by_id :
      request_id:string ->
      t ->
      Api.Account.Id.t ->
      Api.Repo.Id.t ->
      (Api.Repo.t option, [> `Error ]) result Abb.Future.t

    val delete_repo :
      request_id:string ->
      t ->
      Api.Account.Id.t ->
      Api.Repo.Id.t ->
      (unit, [> `Error ]) result Abb.Future.t
  end

  module Apply_requirements : sig
    module Result : sig
      type t

      val passed : t -> bool
      val approved_reviews : t -> Terrat_pull_request_review.t list
    end

    val eval :
      request_id:string ->
      Api.Config.t ->
      Api.User.t ->
      Api.Client.t ->
      'a Terrat_base_repo_config_v1.t ->
      ('diff, 'checks) Api.Pull_request.t ->
      Terrat_change_match3.Dirspace_config.t list ->
      (Result.t, [> `Error ]) result Abb.Future.t
  end

  module Gate : sig
    val add_approval :
      request_id:string ->
      token:string ->
      approver:string ->
      ('a, 'b) Api.Pull_request.t ->
      Db.t ->
      (unit, [> gate_add_approval_err ]) result Abb.Future.t

    val eval :
      request_id:string ->
      Api.Client.t ->
      Terrat_dirspace.t list ->
      ('a, 'b) Api.Pull_request.t ->
      Db.t ->
      (Gate_eval.t list, [> gate_eval_err ]) result Abb.Future.t
  end

  module Tier : sig
    val check :
      request_id:string ->
      Api.User.t ->
      Api.Account.t ->
      Db.t ->
      (Terrat_tier.Check.t option, [> tier_check_err ]) result Abb.Future.t
  end

  module Comment : sig
    val publish_comment :
      request_id:string ->
      Api.Client.t ->
      string ->
      ('diff, 'checks) Api.Pull_request.t ->
      ( Api.Account.t,
        Db.t,
        ('diff2, 'checks2) Api.Pull_request.t,
        (('diff3, 'checks3) Api.Pull_request.t, Api.Repo.t) Target.t,
        Apply_requirements.Result.t,
        Api.Config.t )
      Msg.t ->
      (unit, [> `Error ]) result Abb.Future.t
  end

  module Repo_config : sig
    val fetch_with_provenance :
      ?system_defaults:Terrat_base_repo_config_v1.raw Terrat_base_repo_config_v1.t ->
      ?built_config:Yojson.Safe.t ->
      string ->
      Api.Client.t ->
      Api.Repo.t ->
      Api.Ref.t ->
      ( string list * Terrat_base_repo_config_v1.raw Terrat_base_repo_config_v1.t,
        [> fetch_repo_config_with_provenance_err ] )
      result
      Abb.Future.t
  end

  module Access_control : sig
    val query :
      request_id:string ->
      Api.Client.t ->
      Api.Repo.t ->
      string ->
      Terrat_base_repo_config_v1.Access_control.Match.t ->
      (bool, [> access_control_query_err ]) result Abb.Future.t

    val is_ci_changed :
      request_id:string ->
      Api.Client.t ->
      Api.Repo.t ->
      Terrat_change.Diff.t list ->
      (bool, [> access_control_err ]) result Abb.Future.t
  end

  module Commit_check : sig
    val make_dirspace_title : run_type:string -> Terrat_dirspace.t -> string

    val make_dirspace :
      ?work_manifest:('a, 'b) Terrat_work_manifest3.Existing.t ->
      config:Api.Config.t ->
      description:string ->
      run_type:string ->
      dirspace:Terrat_dirspace.t ->
      status:Terrat_commit_check.Status.t ->
      repo:Api.Repo.t ->
      account:Api.Account.t ->
      unit ->
      Terrat_commit_check.t

    val make_str :
      ?work_manifest:('a, 'b) Terrat_work_manifest3.Existing.t ->
      config:Api.Config.t ->
      description:string ->
      status:Terrat_commit_check.Status.t ->
      repo:Api.Repo.t ->
      account:Api.Account.t ->
      string ->
      Terrat_commit_check.t
  end

  module Work_manifest : sig
    val run :
      request_id:string ->
      Api.Config.t ->
      Api.Client.t ->
      ( Api.Account.t,
        ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
      Terrat_work_manifest3.Existing.t ->
      (unit, [> run_work_manifest_err ]) result Abb.Future.t

    val create :
      request_id:string ->
      Db.t ->
      ( Api.Account.t,
        ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
      Terrat_work_manifest3.New.t ->
      ( ( Api.Account.t,
          ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t,
        [> `Error ] )
      result
      Abb.Future.t

    val query' :
      request_id:string ->
      Db.t ->
      Uuidm.t list ->
      ( ( Api.Account.t,
          ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        list,
        [> `Error ] )
      result
      Abb.Future.t

    val query :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      ( ( Api.Account.t,
          ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        option,
        [> `Error ] )
      result
      Abb.Future.t

    val query_by_run_id :
      request_id:string ->
      Db.t ->
      string ->
      ( ( Api.Account.t,
          ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
        Terrat_work_manifest3.Existing.t
        option,
        [> `Error ] )
      result
      Abb.Future.t

    val update_state :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      Terrat_work_manifest3.State.t ->
      (unit, [> `Error ]) result Abb.Future.t

    val update_run_id :
      request_id:string -> Db.t -> Uuidm.t -> string -> (unit, [> `Error ]) result Abb.Future.t

    val update_changes :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      int option Terrat_change.Dirspaceflow.t list ->
      (unit, [> `Error ]) result Abb.Future.t

    val update_denied_dirspaces :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      Terrat_work_manifest3.Deny.t list ->
      (unit, [> `Error ]) result Abb.Future.t

    val update_steps :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      Terrat_work_manifest3.Step.t list ->
      (unit, [> `Error ]) result Abb.Future.t

    val result : Terrat_api_components_work_manifest_tf_operation_result.t -> Work_manifest_result.t

    val result2 :
      Terrat_api_components_work_manifest_tf_operation_result2.t -> Work_manifest_result.t
  end

  module Ui : sig
    val work_manifest_url :
      Api.Config.t ->
      Api.Account.t ->
      int option ->
      ('a, 'b) Terrat_work_manifest3.Existing.t ->
      Uri.t option
  end

  module Job_context : sig
    val create_or_get_for_pull_request :
      request_id:string ->
      Db.t ->
      Api.Account.t ->
      Api.Repo.t ->
      Api.Pull_request.Id.t ->
      ((Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t, [> `Error ]) result
      Abb.Future.t

    val create_or_get_for_branch :
      request_id:string ->
      Db.t ->
      Api.Account.t ->
      Api.Repo.t ->
      Api.Ref.t ->
      ((Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t, [> `Error ]) result
      Abb.Future.t

    val query :
      request_id:string ->
      Db.t ->
      Uuidm.t ->
      ((Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t option, [> `Error ]) result
      Abb.Future.t

    module Job : sig
      val create :
        request_id:string ->
        Db.t ->
        Terrat_job_context.Job.Type_.t ->
        (Api.Pull_request.Id.t, Api.Ref.t) Terrat_job_context.Context.t ->
        Api.User.t option ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t,
          [> `Error ] )
        result
        Abb.Future.t

      val query :
        request_id:string ->
        Db.t ->
        job_id:Uuidm.t ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t option,
          [> `Error ] )
        result
        Abb.Future.t

      val query_all_by_context_id :
        request_id:string ->
        Db.t ->
        context_id:Uuidm.t ->
        unit ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t list,
          [> `Error ] )
        result
        Abb.Future.t

      val query_pending_by_context_id :
        request_id:string ->
        Db.t ->
        context_id:Uuidm.t ->
        unit ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t list,
          [> `Error ] )
        result
        Abb.Future.t

      val query_by_work_manifest_id :
        request_id:string ->
        Db.t ->
        work_manifest_id:Uuidm.t ->
        unit ->
        ( (Api.Pull_request.Id.t, Api.Ref.t, Api.User.t option) Terrat_job_context.Job.t option,
          [> `Error ] )
        result
        Abb.Future.t

      val update_state :
        request_id:string ->
        Db.t ->
        job_id:Uuidm.t ->
        Terrat_job_context.Job.State.t ->
        (unit, [> `Error ]) result Abb.Future.t

      val add_work_manifest :
        request_id:string ->
        Db.t ->
        job_id:Uuidm.t ->
        work_manifest_id:Uuidm.t ->
        unit ->
        (unit, [> `Error ]) result Abb.Future.t

      val query_work_manifests :
        request_id:string ->
        Db.t ->
        job_id:Uuidm.t ->
        unit ->
        ( ( Api.Account.t,
            ((unit, unit) Api.Pull_request.t, Api.Repo.t) Target.t )
          Terrat_work_manifest3.Existing.t
          list,
          [> `Error ] )
        result
        Abb.Future.t
    end

    module Compute_node : sig
      val create :
        request_id:string ->
        id:Uuidm.t ->
        capabilities:Terrat_job_context.Compute_node.Capabilities.t ->
        Db.t ->
        (Terrat_job_context.Compute_node.t, [> `Error ]) result Abb.Future.t

      val query :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        Db.t ->
        (Terrat_job_context.Compute_node.t option, [> `Error ]) result Abb.Future.t

      val query_work :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        Db.t ->
        (Terrat_job_context.Compute_node_work.t option, [> `Error ]) result Abb.Future.t

      val update_state :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        Db.t ->
        Terrat_job_context.Compute_node.State.t ->
        (unit, [> `Error ]) result Abb.Future.t

      val set_work :
        request_id:string ->
        compute_node_id:Uuidm.t ->
        work_manifest:Uuidm.t ->
        Db.t ->
        Terrat_api_components.Work_manifest.t ->
        (unit, [> `Error ]) result Abb.Future.t
    end
  end

  module Stacks :
    Terrat_vcs_stacks.S
      with type Installation_id.t = Api.Account.Id.t
       and type Repo_id.t = Api.Repo.Id.t
       and type Pull_request_id.t = Api.Pull_request.Id.t
       and type Config.t = Api.Config.t
       and type db = Db.t
end
