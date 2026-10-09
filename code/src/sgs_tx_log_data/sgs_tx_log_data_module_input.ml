module Meta_args = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Selectors = struct
  type t = Sgs_tx_log_data_module_input_selector.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  hash : string;
  meta_args : Meta_args.t;
  selectors : Selectors.t option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
