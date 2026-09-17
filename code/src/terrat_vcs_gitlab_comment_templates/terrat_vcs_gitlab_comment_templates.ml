module Tmpl = struct
  module Transformers = struct
    let money =
      ( "money",
        Snabela.Kv.(
          function
          | F num -> S (Printf.sprintf "%01.02f" num)
          | any -> any) )

    let plan_diff =
      ( "plan_diff",
        Snabela.Kv.(
          function
          | S plan -> S (Terrat_plan_diff.transform plan)
          | any -> any) )

    let compact_plan =
      ( "compact_plan",
        Snabela.Kv.(
          function
          | S plan ->
              S
                (plan
                |> CCString.split_on_char '\n'
                |> CCList.filter (fun s -> CCString.find ~sub:"= (known after apply)" s = -1)
                |> CCString.concat "\n")
          | any -> any) )

    let minus_one =
      ( "minus_one",
        Snabela.Kv.(
          function
          | I v -> I (v - 1)
          | F v -> F (v -. 1.0)
          | any -> any) )
  end

  (* Each template is prepared for both brands when the module loads, so a
     template that does not parse fails at startup. *)
  let read =
    Terrat_brand.branded (fun s ->
        s
        |> Snabela.Template.of_utf8_string
        |> (function
        | Ok tmpl -> tmpl
        | Error (#Snabela.Template.err as err) -> failwith (Snabela.Template.show_err err))
        |> fun tmpl ->
        Snabela.of_template tmpl Transformers.[ money; compact_plan; plan_diff; minus_one ])

  let jinja = Terrat_brand.branded CCFun.id
  let terrateam_comment_help = read [%blob "tmpl/terrateam_comment_help.tmpl"]

  let apply_requirements_config_err_tag_query =
    read [%blob "tmpl/apply_requirements_config_err_tag_query.tmpl"]

  let apply_requirements_config_err_invalid_query =
    read [%blob "tmpl/apply_requirements_config_err_invalid_query.tmpl"]

  let apply_requirements_validation_err = read [%blob "tmpl/apply_requirements_validation_err.tmpl"]
  let mismatched_refs = read [%blob "tmpl/mismatched_refs.tmpl"]
  let missing_plans = read [%blob "tmpl/missing_plans.tmpl"]

  let dirspaces_owned_by_other_pull_requests =
    read [%blob "tmpl/dirspaces_owned_by_other_pull_requests.tmpl"]

  let conflicting_work_manifests = read [%blob "tmpl/conflicting_work_manifests.tmpl"]

  let apply_queued_behind_work_manifests =
    read [%blob "tmpl/apply_queued_behind_work_manifests.tmpl"]

  let synthesize_config_err_stack_cycle =
    jinja [%blob "tmpl/synthesize_config_err_stack_cycle.tmpl"]

  let synthesize_config_err_cycle = jinja [%blob "tmpl/synthesize_config_err_cycle.tmpl"]

  let synthesize_config_err_depends_on_crosses_stack =
    jinja [%blob "tmpl/synthesize_config_err_depends_on_crosses_stack.tmpl"]

  let synthesize_config_err_workspace_in_multiple_stacks =
    jinja [%blob "tmpl/synthesize_config_err_workspace_in_multiple_stacks.tmpl"]

  let synthesize_config_err_workspace_matches_no_stacks =
    jinja [%blob "tmpl/synthesize_config_err_workspace_matches_no_stacks.tmpl"]

  let synthesize_config_err_stack_not_found =
    jinja [%blob "tmpl/synthesize_config_err_stack_not_found.tmpl"]

  let str_template_err_missing_var = jinja [%blob "tmpl/str_template_err_missing_var.tmpl"]

  let operation_failed_branch_not_found =
    jinja [%blob "tmpl/operation_failed_branch_not_found.tmpl"]

  let operation_failed_compute_aborted = jinja [%blob "tmpl/operation_failed_compute_aborted.tmpl"]
  let operation_failed_db_err = jinja [%blob "tmpl/operation_failed_db_err.tmpl"]
  let operation_failed_internal_err = jinja [%blob "tmpl/operation_failed_internal_err.tmpl"]
  let operation_failed_vcs_api_err = jinja [%blob "tmpl/operation_failed_vcs_api_err.tmpl"]

  let operation_failed_vcs_api_timeout_err =
    jinja [%blob "tmpl/operation_failed_vcs_api_timeout_err.tmpl"]

  let operation_failed_work_manifest_start_err =
    jinja [%blob "tmpl/operation_failed_work_manifest_start_err.tmpl"]

  let maybe_stale_work_manifests = read [%blob "tmpl/maybe_stale_work_manifests.tmpl"]
  let repo_config_parse_failure = read [%blob "tmpl/repo_config_parse_failure.tmpl"]
  let repo_config_schema_err = read [%blob "tmpl/repo_config_schema_err.tmpl"]
  let repo_config_generic_failure = read [%blob "tmpl/repo_config_generic_failure.tmpl"]
  let pull_request_not_appliable = jinja [%blob "tmpl/pull_request_not_appliable.tmpl"]
  let pull_request_not_mergeable = read [%blob "tmpl/pull_request_not_mergeable.tmpl"]
  let apply_no_matching_dirspaces = jinja [%blob "tmpl/apply_no_matching_dirspaces.tmpl"]
  let plan_no_matching_dirspaces = jinja [%blob "tmpl/plan_no_matching_dirspaces.tmpl"]
  let plan_all_changes_applied = read [%blob "tmpl/plan_all_changes_applied.tmpl"]
  let matches_in_later_layer = jinja [%blob "tmpl/matches_in_later_layer.tmpl"]
  let tag_query_dropped_dirspaces = jinja [%blob "tmpl/tag_query_dropped_dirspaces.tmpl"]
  let base_branch_not_default_branch = read [%blob "tmpl/dest_branch_no_match.tmpl"]
  let auto_apply_running = read [%blob "tmpl/auto_apply_running.tmpl"]
  let bad_custom_branch_tag_pattern = read [%blob "tmpl/bad_custom_branch_tag_pattern.tmpl"]
  let bad_glob = read [%blob "tmpl/bad_glob.tmpl"]
  let unlock_success = read [%blob "tmpl/unlock_success.tmpl"]

  let access_control_all_dirspaces_denied =
    read [%blob "tmpl/access_control_all_dirspaces_denied.tmpl"]

  let access_control_dirspaces_denied = read [%blob "tmpl/access_control_dirspaces_denied.tmpl"]
  let access_control_files_denied = read [%blob "tmpl/access_control_files_denied.tmpl"]
  let access_control_unlock_denied = read [%blob "tmpl/access_control_unlock_denied.tmpl"]

  let access_control_ci_config_update_denied =
    read [%blob "tmpl/access_control_ci_config_update_denied.tmpl"]

  let access_control_terrateam_config_update_denied =
    read [%blob "tmpl/access_control_terrateam_config_update_denied.tmpl"]

  let access_control_lookup_err = read [%blob "tmpl/access_control_lookup_err.tmpl"]
  let tag_query_error = read [%blob "tmpl/tag_query_error.tmpl"]
  let account_expired_err = read [%blob "tmpl/account_expired_err.tmpl"]
  let repo_config = read [%blob "tmpl/repo_config.tmpl"]
  let work_manifest_run_failed = jinja [%blob "tmpl/work_manifest_run_failed.tmpl"]
  let failed_to_start_workflow = read [%blob "tmpl/failed_to_start_workflow.tmpl"]

  let failed_to_start_identity_verification_workflow =
    read [%blob "tmpl/failed_to_start_identify_verification_workflow.tmpl"]

  let failed_to_start_missing_inputs = read [%blob "tmpl/failed_to_start_missing_inputs.tmpl"]
  let failed_to_find_workflow = read [%blob "tmpl/failed_to_find_workflow.tmpl"]
  let comment_too_large = read [%blob "tmpl/comment_too_large.tmpl"]
  let index_complete = read [%blob "tmpl/index_complete.tmpl"]
  let invalid_lock_id = read [%blob "tmpl/unlock_failed_bad_id.tmpl"]

  (* Repo config errors *)
  let repo_config_err_access_control_policy_apply_autoapprove_match_parse_err =
    read [%blob "tmpl/repo_config_err_access_control_policy_apply_autoapprove_match_parse_err.tmpl"]

  let repo_config_err_access_control_policy_apply_force_match_parse_err =
    read [%blob "tmpl/repo_config_err_access_control_policy_apply_force_match_parse_err.tmpl"]

  let repo_config_err_access_control_policy_apply_match_parse_err =
    read [%blob "tmpl/repo_config_err_access_control_policy_apply_match_parse_err.tmpl"]

  let repo_config_err_access_control_policy_apply_with_superapproval_match_parse_err =
    read
      [%blob
        "tmpl/repo_config_err_access_control_policy_apply_with_supperapproval_match_parse_err.tmpl"]

  let repo_config_err_access_control_policy_plan_match_parse_err =
    read [%blob "tmpl/repo_config_err_access_control_policy_plan_match_parse_err.tmpl"]

  let repo_config_err_access_control_policy_superapproval_match_parse_err =
    read [%blob "tmpl/repo_config_err_access_control_policy_superapproval_match_parse_err.tmpl"]

  let repo_config_err_access_control_policy_tag_query_err =
    read [%blob "tmpl/repo_config_err_access_control_policy_tag_query_err.tmpl"]

  let repo_config_err_access_control_terrateam_config_update_match_parse_err =
    read [%blob "tmpl/repo_config_err_access_control_terrateam_config_update_match_parse_err.tmpl"]

  let repo_config_err_access_control_ci_config_update_match_parse_err =
    read [%blob "tmpl/repo_config_err_access_control_ci_config_update_match_parse_err.tmpl"]

  let repo_config_err_access_control_file_match_parse_err =
    read [%blob "tmpl/repo_config_err_access_control_file_match_parse_err.tmpl"]

  let repo_config_err_access_control_unlock_match_parse_err =
    read [%blob "tmpl/repo_config_err_access_control_unlock_match_parse_err.tmpl"]

  let repo_config_err_apply_requirements_approved_all_of_match_parse_err =
    read [%blob "tmpl/repo_config_err_apply_requirements_approved_all_of_match_parse_err.tmpl"]

  let repo_config_err_apply_requirements_approved_any_of_match_parse_err =
    read [%blob "tmpl/repo_config_err_apply_requirements_approved_any_of_match_parse_err.tmpl"]

  let repo_config_err_apply_requirements_check_tag_query_err =
    read [%blob "tmpl/repo_config_err_apply_requirements_check_tag_query_err.tmpl"]

  let repo_config_err_depends_on_err = read [%blob "tmpl/repo_config_err_depends_on_err.tmpl"]

  let repo_config_err_drift_tag_query_err =
    read [%blob "tmpl/repo_config_err_drift_tag_query_err.tmpl"]

  let repo_config_err_glob_parse_err = read [%blob "tmpl/repo_config_err_glob_parse_err.tmpl"]
  let repo_config_err_bad_glob_err = jinja [%blob "tmpl/repo_config_err_bad_glob_err.tmpl"]
  let repo_config_err_pattern_parse_err = read [%blob "tmpl/repo_config_err_pattern_parse_err.tmpl"]

  let repo_config_err_window_parse_timezone_err =
    read [%blob "tmpl/repo_config_err_window_parse_timezone_err.tmpl"]

  let repo_config_err_workflows_tag_query_parse_err =
    read [%blob "tmpl/repo_config_err_workflows_tag_query_parse_err.tmpl"]

  let plan_complete2 = jinja [%blob "tmpl/plan_complete2.tmpl"]
  let apply_complete2 = jinja [%blob "tmpl/apply_complete2.tmpl"]
  let automerge_failure = read [%blob "tmpl/automerge_error.tmpl"]

  let premium_feature_err_access_control =
    read [%blob "tmpl/premium_feature_err_access_control.tmpl"]

  let premium_feature_err_multiple_drift_schedules =
    read [%blob "tmpl/premium_feature_err_multiple_drift_schedules.tmpl"]

  let premium_feature_err_gatekeeping = read [%blob "tmpl/premium_feature_err_gatekeeping.tmpl"]

  let premium_feature_err_require_completed_reviews =
    read [%blob "tmpl/premium_feature_err_require_completed_reviews.tmpl"]

  let premium_feature_err_notifications_summary =
    read [%blob "tmpl/premium_feature_err_notifications_summary.tmpl"]

  let repo_config_merge_err = read [%blob "tmpl/repo_config_merge_err.tmpl"]
  let gate_check_failure = jinja [%blob "tmpl/gate_check_failure.tmpl"]
  let tier_check = read [%blob "tmpl/tier_check.tmpl"]
  let build_tree_failure = read [%blob "tmpl/build_tree_failure.tmpl"]

  let notification_policy_tag_query_err =
    jinja [%blob "tmpl/notification_policy_tag_query_err.tmpl"]

  let repo_config_err_workflows_missing_apply_step_err =
    jinja [%blob "tmpl/repo_config_err_workflows_missing_apply_step_err.tmpl"]

  let repo_config_err_workflows_missing_plan_step_err =
    jinja [%blob "tmpl/repo_config_err_workflows_missing_plan_step_err.tmpl"]
end

module Ui = struct
  let work_manifest_url _config _account = raise (Failure "nyi")
end
