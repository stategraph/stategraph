type t = {
  input : string;
  to_addr : string;
  to_call : string option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
