module File_reads = struct
  type t = Sgs_tx_log_hints_file_read_hint.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Module_ancestors = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Module_index_reads = struct
  type t = Sgs_tx_log_hints_module_index_read_hint.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Path_attrs = struct
  type t = Sgs_tx_log_hints_path_attr_hint.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Stored_for_each_body_refs = struct
  type t = Sgs_tx_log_hints_stored_for_each_body_ref.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Stored_for_each_refs = struct
  type t = Sgs_tx_log_hints_stored_for_each_ref.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Stored_object_attr_refs = struct
  type t = Sgs_tx_log_hints_stored_object_attr_ref.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  file_reads : File_reads.t option; [@default None]
  for_each : Sgs_tx_log_hints_stored_for_each_hint.t option; [@default None]
  for_each_file_calls : Sgs_tx_log_hints_for_each_file_calls.t option; [@default None]
  module_ancestors : Module_ancestors.t option; [@default None]
  module_index_reads : Module_index_reads.t option; [@default None]
  path_attrs : Path_attrs.t option; [@default None]
  realized_object : Sgs_tx_log_hints_stored_realized_object_hint.t option; [@default None]
  stored_for_each_body_refs : Stored_for_each_body_refs.t option; [@default None]
  stored_for_each_refs : Stored_for_each_refs.t option; [@default None]
  stored_object_attr_refs : Stored_object_attr_refs.t option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
