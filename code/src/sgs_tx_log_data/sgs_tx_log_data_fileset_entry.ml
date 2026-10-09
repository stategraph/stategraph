type t = {
  dir : string;
  pattern : string;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
