type t = {
  call_key : string;
  input : string;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
