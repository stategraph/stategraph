type t = {
  name : string;
  organization : string option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
