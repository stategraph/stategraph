type t = {
  body_id : string option; [@default None]
  node_id : string;
  tf_module : Sgs_tx_log_data_tf_module_key.t option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
