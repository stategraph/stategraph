type t = {
  id : string;
  name : string;
  schema_version : int;
  workspace : string;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
