module Action = struct
  let t_of_yojson = function
    | `String "hcl_set" -> Ok `Hcl_set
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Hcl_set -> `String "hcl_set"

  type t = ([ `Hcl_set ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Data = struct
  module Data = struct
    type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module File_refs = struct
    type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Ref_hints = struct
    type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  type t = {
    child_module : Sgs_tx_log_data_tf_module_key.t option; [@default None]
    data : Data.t;
    file : string;
    file_refs : File_refs.t option; [@default None]
    hints : Sgs_tx_log_hints_hints.t option; [@default None]
    ref_hints : Ref_hints.t option; [@default None]
    tf_module : Sgs_tx_log_data_tf_module_key.t option; [@default None]
  }
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Object_type = struct
  let t_of_yojson = function
    | `String "hcl" -> Ok `Hcl
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Hcl -> `String "hcl"

  type t = ([ `Hcl ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  action : Action.t;
  data : Data.t;
  object_type : Object_type.t;
  state_id : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
