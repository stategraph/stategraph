module Base_dirspaces = struct
  type t = Terrat_api_components_work_manifest_dir.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Capabilities = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Changed_dirspaces = struct
  type t = Terrat_api_components_work_manifest_dir.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Config = struct
  type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Dirspaces = struct
  type t = Terrat_api_components_work_manifest_dir.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Run_kind_data = struct
  type t = Run_kind_data_pull_request of Terrat_api_components_run_kind_data_pull_request.t
  [@@deriving show, eq]

  let of_yojson =
    Json_schema.one_of
      (let open CCResult in
       [
         (fun v ->
           map
             (fun v -> Run_kind_data_pull_request v)
             (Terrat_api_components_run_kind_data_pull_request.of_yojson v));
       ])

  let to_yojson = function
    | Run_kind_data_pull_request v -> Terrat_api_components_run_kind_data_pull_request.to_yojson v
end

module Type = struct
  let t_of_yojson = function
    | `String "plan" -> Ok `Plan
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Plan -> `String "plan"

  type t = ([ `Plan ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  api_base_url : string;
  base_dirspaces : Base_dirspaces.t;
  base_ref : string;
  capabilities : Capabilities.t;
  changed_dirspaces : Changed_dirspaces.t;
  config : Config.t;
  dirspaces : Dirspaces.t;
  id : string option; [@default None]
  installation_id : string;
  protocol_version : int option; [@default None]
  result_version : int;
  run_kind : string;
  run_kind_data : Run_kind_data.t option; [@default None]
  token : string;
  type_ : Type.t; [@key "type"]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
