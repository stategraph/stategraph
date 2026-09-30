type t = {
  configured : bool;
  creatable : bool;
  ready : bool;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
