module Config = struct
  type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Dirs = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Type = struct
  let t_of_yojson = function
    | `String "index" -> Ok `Index
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Index -> `String "index"

  type t = ([ `Index ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  base_ref : string;
  config : Config.t;
  dirs : Dirs.t;
  id : string option; [@default None]
  token : string;
  type_ : Type.t; [@key "type"]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
