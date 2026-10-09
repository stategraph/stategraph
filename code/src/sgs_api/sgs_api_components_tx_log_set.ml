type t =
  | Tx_log_set_hcl_set of Sgs_api_components_tx_log_set_hcl_set.t
  | Tx_log_set_hcl_delete of Sgs_api_components_tx_log_set_hcl_delete.t
  | Tx_log_set_tfvar_set of Sgs_api_components_tx_log_set_tfvar_set.t
  | Tx_log_set_tfvar_delete of Sgs_api_components_tx_log_set_tfvar_delete.t
  | Tx_log_set_tfvar_ephemeral of Sgs_api_components_tx_log_set_tfvar_ephemeral.t
  | Tx_log_set_file_set of Sgs_api_components_tx_log_set_file_set.t
  | Tx_log_set_file_delete of Sgs_api_components_tx_log_set_file_delete.t
  | Tx_log_set_state_set of Sgs_api_components_tx_log_set_state_set.t
  | Tx_log_set_refresh of Sgs_api_components_tx_log_set_refresh.t
  | Tx_log_set_module_set of Sgs_api_components_tx_log_set_module_set.t
  | Tx_log_set_module_delete of Sgs_api_components_tx_log_set_module_delete.t
[@@deriving show, eq]

let of_yojson =
  Json_schema.one_of
    (let open CCResult in
     [
       (fun v ->
         map (fun v -> Tx_log_set_hcl_set v) (Sgs_api_components_tx_log_set_hcl_set.of_yojson v));
       (fun v ->
         map
           (fun v -> Tx_log_set_hcl_delete v)
           (Sgs_api_components_tx_log_set_hcl_delete.of_yojson v));
       (fun v ->
         map (fun v -> Tx_log_set_tfvar_set v) (Sgs_api_components_tx_log_set_tfvar_set.of_yojson v));
       (fun v ->
         map
           (fun v -> Tx_log_set_tfvar_delete v)
           (Sgs_api_components_tx_log_set_tfvar_delete.of_yojson v));
       (fun v ->
         map
           (fun v -> Tx_log_set_tfvar_ephemeral v)
           (Sgs_api_components_tx_log_set_tfvar_ephemeral.of_yojson v));
       (fun v ->
         map (fun v -> Tx_log_set_file_set v) (Sgs_api_components_tx_log_set_file_set.of_yojson v));
       (fun v ->
         map
           (fun v -> Tx_log_set_file_delete v)
           (Sgs_api_components_tx_log_set_file_delete.of_yojson v));
       (fun v ->
         map (fun v -> Tx_log_set_state_set v) (Sgs_api_components_tx_log_set_state_set.of_yojson v));
       (fun v ->
         map (fun v -> Tx_log_set_refresh v) (Sgs_api_components_tx_log_set_refresh.of_yojson v));
       (fun v ->
         map
           (fun v -> Tx_log_set_module_set v)
           (Sgs_api_components_tx_log_set_module_set.of_yojson v));
       (fun v ->
         map
           (fun v -> Tx_log_set_module_delete v)
           (Sgs_api_components_tx_log_set_module_delete.of_yojson v));
     ])

let to_yojson = function
  | Tx_log_set_hcl_set v -> Sgs_api_components_tx_log_set_hcl_set.to_yojson v
  | Tx_log_set_hcl_delete v -> Sgs_api_components_tx_log_set_hcl_delete.to_yojson v
  | Tx_log_set_tfvar_set v -> Sgs_api_components_tx_log_set_tfvar_set.to_yojson v
  | Tx_log_set_tfvar_delete v -> Sgs_api_components_tx_log_set_tfvar_delete.to_yojson v
  | Tx_log_set_tfvar_ephemeral v -> Sgs_api_components_tx_log_set_tfvar_ephemeral.to_yojson v
  | Tx_log_set_file_set v -> Sgs_api_components_tx_log_set_file_set.to_yojson v
  | Tx_log_set_file_delete v -> Sgs_api_components_tx_log_set_file_delete.to_yojson v
  | Tx_log_set_state_set v -> Sgs_api_components_tx_log_set_state_set.to_yojson v
  | Tx_log_set_refresh v -> Sgs_api_components_tx_log_set_refresh.to_yojson v
  | Tx_log_set_module_set v -> Sgs_api_components_tx_log_set_module_set.to_yojson v
  | Tx_log_set_module_delete v -> Sgs_api_components_tx_log_set_module_delete.to_yojson v
