type t = {
  name : string;
  organization : string option; [@default None]
  rd : string option; [@default None]
  replace : bool option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
