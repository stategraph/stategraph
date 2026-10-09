module Action = struct
  let t_of_yojson = function
    | `String "file_delete" -> Ok `File_delete
    | `String "file_set" -> Ok `File_set
    | `String "hcl_delete" -> Ok `Hcl_delete
    | `String "hcl_set" -> Ok `Hcl_set
    | `String "module_delete" -> Ok `Module_delete
    | `String "module_set" -> Ok `Module_set
    | `String "refresh" -> Ok `Refresh
    | `String "state_delete" -> Ok `State_delete
    | `String "state_set" -> Ok `State_set
    | `String "tfvar_delete" -> Ok `Tfvar_delete
    | `String "tfvar_ephemeral" -> Ok `Tfvar_ephemeral
    | `String "tfvar_set" -> Ok `Tfvar_set
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `File_delete -> `String "file_delete"
    | `File_set -> `String "file_set"
    | `Hcl_delete -> `String "hcl_delete"
    | `Hcl_set -> `String "hcl_set"
    | `Module_delete -> `String "module_delete"
    | `Module_set -> `String "module_set"
    | `Refresh -> `String "refresh"
    | `State_delete -> `String "state_delete"
    | `State_set -> `String "state_set"
    | `Tfvar_delete -> `String "tfvar_delete"
    | `Tfvar_ephemeral -> `String "tfvar_ephemeral"
    | `Tfvar_set -> `String "tfvar_set"

  type t =
    ([ `File_delete
     | `File_set
     | `Hcl_delete
     | `Hcl_set
     | `Module_delete
     | `Module_set
     | `Refresh
     | `State_delete
     | `State_set
     | `Tfvar_delete
     | `Tfvar_ephemeral
     | `Tfvar_set
     ]
    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Data = struct
  type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Object_type = struct
  let t_of_yojson = function
    | `String "check_result" -> Ok `Check_result
    | `String "check_result_entry" -> Ok `Check_result_entry
    | `String "file" -> Ok `File
    | `String "hcl" -> Ok `Hcl
    | `String "instance" -> Ok `Instance
    | `String "module" -> Ok `Module
    | `String "output" -> Ok `Output
    | `String "provider" -> Ok `Provider
    | `String "refresh" -> Ok `Refresh
    | `String "resource" -> Ok `Resource
    | `String "state_metadata" -> Ok `State_metadata
    | `String "tf_module_hcl" -> Ok `Tf_module_hcl
    | `String "tfvar" -> Ok `Tfvar
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Check_result -> `String "check_result"
    | `Check_result_entry -> `String "check_result_entry"
    | `File -> `String "file"
    | `Hcl -> `String "hcl"
    | `Instance -> `String "instance"
    | `Module -> `String "module"
    | `Output -> `String "output"
    | `Provider -> `String "provider"
    | `Refresh -> `String "refresh"
    | `Resource -> `String "resource"
    | `State_metadata -> `String "state_metadata"
    | `Tf_module_hcl -> `String "tf_module_hcl"
    | `Tfvar -> `String "tfvar"

  type t =
    ([ `Check_result
     | `Check_result_entry
     | `File
     | `Hcl
     | `Instance
     | `Module
     | `Output
     | `Provider
     | `Refresh
     | `Resource
     | `State_metadata
     | `Tf_module_hcl
     | `Tfvar
     ]
    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  action : Action.t;
  created_at : string;
  data : Data.t;
  id : string;
  object_type : Object_type.t;
  state_id : string;
  user_id : string option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
