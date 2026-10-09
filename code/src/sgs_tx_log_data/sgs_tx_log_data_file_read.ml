module Call_path = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Refs = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Template_vars = struct
  type t = Sgs_tx_log_data_template_var_ref.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  call_key : string;
  call_path : Call_path.t;
  file_function : string;
  fileset : Sgs_tx_log_data_fileset_entry.t option; [@default None]
  fileset_rel : string option; [@default None]
  inlined_file_expr : string option; [@default None]
  node_id : string;
  refs : Refs.t;
  template_vars : Template_vars.t;
  tf_module : Sgs_tx_log_data_tf_module_key.t;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
