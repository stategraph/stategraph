type t = {
  node_id : string;
  source : string;
  version : string;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
