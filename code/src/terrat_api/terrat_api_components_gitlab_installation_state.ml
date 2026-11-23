type t = {
  id : string;
  state : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
