module Kind = struct
  let t_of_yojson = function
    | `String "import_id_unresolved" -> Ok `Import_id_unresolved
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Import_id_unresolved -> `String "import_id_unresolved"

  type t = ([ `Import_id_unresolved ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  block : string;
  detail : string;
  kind : Kind.t;
  reference : string;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
