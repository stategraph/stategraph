type t = {
  ended_at : string;
  id : string;
  name : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
