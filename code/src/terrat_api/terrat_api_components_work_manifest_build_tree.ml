module Config = struct
  type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Type = struct
  let t_of_yojson = function
    | `String "build-tree" -> Ok `Build_tree
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Build_tree -> `String "build-tree"

  type t = ([ `Build_tree ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  base_ref : string;
  config : Config.t;
  id : string option; [@default None]
  token : string;
  type_ : Type.t; [@key "type"]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
