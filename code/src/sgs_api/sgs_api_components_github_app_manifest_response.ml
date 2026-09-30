type t = {
  action_url : string;
  manifest : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
