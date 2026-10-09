let t_of_yojson = function
  | `String "local" -> Ok `Local
  | `String "remote" -> Ok `Remote
  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

let t_to_yojson = function
  | `Local -> `String "local"
  | `Remote -> `String "remote"

type t =
  ([ `Local
   | `Remote
   ]
  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
[@@deriving yojson { strict = false; meta = true }, show, eq]
