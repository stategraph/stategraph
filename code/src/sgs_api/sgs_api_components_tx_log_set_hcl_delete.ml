module Action = struct
  let t_of_yojson = function
    | `String "hcl_delete" -> Ok `Hcl_delete
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Hcl_delete -> `String "hcl_delete"

  type t = ([ `Hcl_delete ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Data = struct
  type t = {
    node_id : string;
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
