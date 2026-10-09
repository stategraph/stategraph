type t = {
  call_key : string;
  dir : string;
  pattern : string;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
