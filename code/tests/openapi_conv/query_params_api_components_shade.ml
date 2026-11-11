let t_of_yojson =
  function
  | `String "dark" -> Ok `Dark
  | `String "light" -> Ok `Light
  | json -> Error ("Unknown value: " ^ (Yojson.Safe.pretty_to_string json))
let t_to_yojson =
  function | `Dark -> `String "dark" | `Light -> `String "light"
type t =
  (([ `Dark  | `Light ])[@of_yojson t_of_yojson][@to_yojson t_to_yojson])
[@@deriving ((yojson { strict = false; meta = true }), show, eq)]
