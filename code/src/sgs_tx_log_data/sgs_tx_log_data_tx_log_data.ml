type t =
  | Hcl_set of Sgs_tx_log_data_hcl_set.t
  | Hcl_delete of Sgs_tx_log_data_hcl_delete.t
  | State_set of Sgs_tx_log_data_state_set.t
  | Tfvar_set of Sgs_tx_log_data_tfvar_set.t
  | Tfvar_delete of Sgs_tx_log_data_tfvar_delete.t
  | Tfvar_ephemeral of Sgs_tx_log_data_tfvar_ephemeral.t
  | File_set of Sgs_tx_log_data_file_set.t
  | File_delete of Sgs_tx_log_data_file_delete.t
  | Refresh of Sgs_tx_log_data_refresh.t
  | Module_set of Sgs_tx_log_data_module_set.t
  | Module_delete of Sgs_tx_log_data_module_delete.t
[@@deriving show, eq]

let of_yojson =
  Json_schema.one_of
    (let open CCResult in
     [
       (fun v -> map (fun v -> Hcl_set v) (Sgs_tx_log_data_hcl_set.of_yojson v));
       (fun v -> map (fun v -> Hcl_delete v) (Sgs_tx_log_data_hcl_delete.of_yojson v));
       (fun v -> map (fun v -> State_set v) (Sgs_tx_log_data_state_set.of_yojson v));
       (fun v -> map (fun v -> Tfvar_set v) (Sgs_tx_log_data_tfvar_set.of_yojson v));
       (fun v -> map (fun v -> Tfvar_delete v) (Sgs_tx_log_data_tfvar_delete.of_yojson v));
       (fun v -> map (fun v -> Tfvar_ephemeral v) (Sgs_tx_log_data_tfvar_ephemeral.of_yojson v));
       (fun v -> map (fun v -> File_set v) (Sgs_tx_log_data_file_set.of_yojson v));
       (fun v -> map (fun v -> File_delete v) (Sgs_tx_log_data_file_delete.of_yojson v));
       (fun v -> map (fun v -> Refresh v) (Sgs_tx_log_data_refresh.of_yojson v));
       (fun v -> map (fun v -> Module_set v) (Sgs_tx_log_data_module_set.of_yojson v));
       (fun v -> map (fun v -> Module_delete v) (Sgs_tx_log_data_module_delete.of_yojson v));
     ])

let to_yojson = function
  | Hcl_set v -> Sgs_tx_log_data_hcl_set.to_yojson v
  | Hcl_delete v -> Sgs_tx_log_data_hcl_delete.to_yojson v
  | State_set v -> Sgs_tx_log_data_state_set.to_yojson v
  | Tfvar_set v -> Sgs_tx_log_data_tfvar_set.to_yojson v
  | Tfvar_delete v -> Sgs_tx_log_data_tfvar_delete.to_yojson v
  | Tfvar_ephemeral v -> Sgs_tx_log_data_tfvar_ephemeral.to_yojson v
  | File_set v -> Sgs_tx_log_data_file_set.to_yojson v
  | File_delete v -> Sgs_tx_log_data_file_delete.to_yojson v
  | Refresh v -> Sgs_tx_log_data_refresh.to_yojson v
  | Module_set v -> Sgs_tx_log_data_module_set.to_yojson v
  | Module_delete v -> Sgs_tx_log_data_module_delete.to_yojson v
