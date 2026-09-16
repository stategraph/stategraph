module Changed_dirspaces = struct
  type t = Terrat_api_components_work_manifest_dir.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Config = struct
  type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Type = struct
  let t_of_yojson = function
    | `String "unsafe-apply" -> Ok `Unsafe_apply
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Unsafe_apply -> `String "unsafe-apply"

  type t = ([ `Unsafe_apply ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  base_ref : string;
  changed_dirspaces : Changed_dirspaces.t;
  config : Config.t;
  id : string option; [@default None]
  run_kind : string;
  token : string;
  type_ : Type.t; [@key "type"]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
