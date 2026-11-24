type t = {
  group_id : int;
  name : string;
  state : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
