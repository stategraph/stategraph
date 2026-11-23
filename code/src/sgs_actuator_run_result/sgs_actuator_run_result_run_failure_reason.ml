type t =
  | Reason_tf_binary_not_found of Sgs_actuator_run_result_reason_tf_binary_not_found.t
  | Reason_hcl_parse of Sgs_actuator_run_result_reason_hcl_parse.t
  | Reason_write of Sgs_actuator_run_result_reason_write.t
  | Reason_init of Sgs_actuator_run_result_reason_init.t
  | Reason_plan of Sgs_actuator_run_result_reason_plan.t
  | Reason_show_json of Sgs_actuator_run_result_reason_show_json.t
  | Reason_failed_apply of Sgs_actuator_run_result_reason_failed_apply.t
  | Reason_read of Sgs_actuator_run_result_reason_read.t
  | Reason_temp_dir of Sgs_actuator_run_result_reason_temp_dir.t
  | Reason_preview_fetch of Sgs_actuator_run_result_reason_preview_fetch.t
  | Reason_preview_decode of Sgs_actuator_run_result_reason_preview_decode.t
  | Reason_params_fetch of Sgs_actuator_run_result_reason_params_fetch.t
  | Reason_bad_request of Sgs_actuator_run_result_reason_bad_request.t
  | Reason_unauthorized of Sgs_actuator_run_result_reason_unauthorized.t
  | Reason_failed_transport_call of Sgs_actuator_run_result_reason_failed_transport_call.t
  | Reason_client_create of Sgs_actuator_run_result_reason_client_create.t
  | Reason_next_task_failed of Sgs_actuator_run_result_reason_next_task_failed.t
  | Reason_next_timeout of Sgs_actuator_run_result_reason_next_timeout.t
  | Reason_results_task_failed of Sgs_actuator_run_result_reason_results_task_failed.t
  | Reason_capability_denied of Sgs_actuator_run_result_reason_capability_denied.t
  | Reason_tx_conflict of Sgs_actuator_run_result_reason_tx_conflict.t
  | Reason_tx_invalid_state of Sgs_actuator_run_result_reason_tx_invalid_state.t
  | Reason_remote_state_address_unresolved of
      Sgs_actuator_run_result_reason_remote_state_address_unresolved.t
  | Reason_tx_schema_version_mismatch of Sgs_actuator_run_result_reason_tx_schema_version_mismatch.t
  | Reason_state_schema_placeholder_present of
      Sgs_actuator_run_result_reason_state_schema_placeholder_present.t
  | Reason_state_schema_remote_module_missing of
      Sgs_actuator_run_result_reason_state_schema_remote_module_missing.t
  | Reason_state_schema_upgrade_failed of
      Sgs_actuator_run_result_reason_state_schema_upgrade_failed.t
  | Reason_state_schema_upgrade_rounds_exhausted of
      Sgs_actuator_run_result_reason_state_schema_upgrade_rounds_exhausted.t
  | Reason_state_schema_upgrade_timeout of
      Sgs_actuator_run_result_reason_state_schema_upgrade_timeout.t
  | Reason_import_id_unresolved of Sgs_actuator_run_result_reason_import_id_unresolved.t
[@@deriving show, eq]

let of_yojson =
  Json_schema.one_of
    (let open CCResult in
     [
       (fun v ->
         map
           (fun v -> Reason_tf_binary_not_found v)
           (Sgs_actuator_run_result_reason_tf_binary_not_found.of_yojson v));
       (fun v ->
         map (fun v -> Reason_hcl_parse v) (Sgs_actuator_run_result_reason_hcl_parse.of_yojson v));
       (fun v -> map (fun v -> Reason_write v) (Sgs_actuator_run_result_reason_write.of_yojson v));
       (fun v -> map (fun v -> Reason_init v) (Sgs_actuator_run_result_reason_init.of_yojson v));
       (fun v -> map (fun v -> Reason_plan v) (Sgs_actuator_run_result_reason_plan.of_yojson v));
       (fun v ->
         map (fun v -> Reason_show_json v) (Sgs_actuator_run_result_reason_show_json.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_failed_apply v)
           (Sgs_actuator_run_result_reason_failed_apply.of_yojson v));
       (fun v -> map (fun v -> Reason_read v) (Sgs_actuator_run_result_reason_read.of_yojson v));
       (fun v ->
         map (fun v -> Reason_temp_dir v) (Sgs_actuator_run_result_reason_temp_dir.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_preview_fetch v)
           (Sgs_actuator_run_result_reason_preview_fetch.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_preview_decode v)
           (Sgs_actuator_run_result_reason_preview_decode.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_params_fetch v)
           (Sgs_actuator_run_result_reason_params_fetch.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_bad_request v)
           (Sgs_actuator_run_result_reason_bad_request.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_unauthorized v)
           (Sgs_actuator_run_result_reason_unauthorized.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_failed_transport_call v)
           (Sgs_actuator_run_result_reason_failed_transport_call.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_client_create v)
           (Sgs_actuator_run_result_reason_client_create.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_next_task_failed v)
           (Sgs_actuator_run_result_reason_next_task_failed.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_next_timeout v)
           (Sgs_actuator_run_result_reason_next_timeout.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_results_task_failed v)
           (Sgs_actuator_run_result_reason_results_task_failed.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_capability_denied v)
           (Sgs_actuator_run_result_reason_capability_denied.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_tx_conflict v)
           (Sgs_actuator_run_result_reason_tx_conflict.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_tx_invalid_state v)
           (Sgs_actuator_run_result_reason_tx_invalid_state.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_remote_state_address_unresolved v)
           (Sgs_actuator_run_result_reason_remote_state_address_unresolved.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_tx_schema_version_mismatch v)
           (Sgs_actuator_run_result_reason_tx_schema_version_mismatch.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_state_schema_placeholder_present v)
           (Sgs_actuator_run_result_reason_state_schema_placeholder_present.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_state_schema_remote_module_missing v)
           (Sgs_actuator_run_result_reason_state_schema_remote_module_missing.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_state_schema_upgrade_failed v)
           (Sgs_actuator_run_result_reason_state_schema_upgrade_failed.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_state_schema_upgrade_rounds_exhausted v)
           (Sgs_actuator_run_result_reason_state_schema_upgrade_rounds_exhausted.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_state_schema_upgrade_timeout v)
           (Sgs_actuator_run_result_reason_state_schema_upgrade_timeout.of_yojson v));
       (fun v ->
         map
           (fun v -> Reason_import_id_unresolved v)
           (Sgs_actuator_run_result_reason_import_id_unresolved.of_yojson v));
     ])

let to_yojson = function
  | Reason_tf_binary_not_found v -> Sgs_actuator_run_result_reason_tf_binary_not_found.to_yojson v
  | Reason_hcl_parse v -> Sgs_actuator_run_result_reason_hcl_parse.to_yojson v
  | Reason_write v -> Sgs_actuator_run_result_reason_write.to_yojson v
  | Reason_init v -> Sgs_actuator_run_result_reason_init.to_yojson v
  | Reason_plan v -> Sgs_actuator_run_result_reason_plan.to_yojson v
  | Reason_show_json v -> Sgs_actuator_run_result_reason_show_json.to_yojson v
  | Reason_failed_apply v -> Sgs_actuator_run_result_reason_failed_apply.to_yojson v
  | Reason_read v -> Sgs_actuator_run_result_reason_read.to_yojson v
  | Reason_temp_dir v -> Sgs_actuator_run_result_reason_temp_dir.to_yojson v
  | Reason_preview_fetch v -> Sgs_actuator_run_result_reason_preview_fetch.to_yojson v
  | Reason_preview_decode v -> Sgs_actuator_run_result_reason_preview_decode.to_yojson v
  | Reason_params_fetch v -> Sgs_actuator_run_result_reason_params_fetch.to_yojson v
  | Reason_bad_request v -> Sgs_actuator_run_result_reason_bad_request.to_yojson v
  | Reason_unauthorized v -> Sgs_actuator_run_result_reason_unauthorized.to_yojson v
  | Reason_failed_transport_call v ->
      Sgs_actuator_run_result_reason_failed_transport_call.to_yojson v
  | Reason_client_create v -> Sgs_actuator_run_result_reason_client_create.to_yojson v
  | Reason_next_task_failed v -> Sgs_actuator_run_result_reason_next_task_failed.to_yojson v
  | Reason_next_timeout v -> Sgs_actuator_run_result_reason_next_timeout.to_yojson v
  | Reason_results_task_failed v -> Sgs_actuator_run_result_reason_results_task_failed.to_yojson v
  | Reason_capability_denied v -> Sgs_actuator_run_result_reason_capability_denied.to_yojson v
  | Reason_tx_conflict v -> Sgs_actuator_run_result_reason_tx_conflict.to_yojson v
  | Reason_tx_invalid_state v -> Sgs_actuator_run_result_reason_tx_invalid_state.to_yojson v
  | Reason_remote_state_address_unresolved v ->
      Sgs_actuator_run_result_reason_remote_state_address_unresolved.to_yojson v
  | Reason_tx_schema_version_mismatch v ->
      Sgs_actuator_run_result_reason_tx_schema_version_mismatch.to_yojson v
  | Reason_state_schema_placeholder_present v ->
      Sgs_actuator_run_result_reason_state_schema_placeholder_present.to_yojson v
  | Reason_state_schema_remote_module_missing v ->
      Sgs_actuator_run_result_reason_state_schema_remote_module_missing.to_yojson v
  | Reason_state_schema_upgrade_failed v ->
      Sgs_actuator_run_result_reason_state_schema_upgrade_failed.to_yojson v
  | Reason_state_schema_upgrade_rounds_exhausted v ->
      Sgs_actuator_run_result_reason_state_schema_upgrade_rounds_exhausted.to_yojson v
  | Reason_state_schema_upgrade_timeout v ->
      Sgs_actuator_run_result_reason_state_schema_upgrade_timeout.to_yojson v
  | Reason_import_id_unresolved v -> Sgs_actuator_run_result_reason_import_id_unresolved.to_yojson v
