module Reads = struct
  type t = Sgs_tx_log_data_file_read.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Template_vars = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  content : string;
  content_hash : string;
  filepath : string;
  mode : int;
  module_ : string; [@key "module"]
  node_id : string;
  present : bool option; [@default None]
  reads : Reads.t option; [@default None]
  template_vars : Template_vars.t;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
