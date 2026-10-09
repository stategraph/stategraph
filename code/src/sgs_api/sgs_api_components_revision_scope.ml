type t = {
  hash : string;
  module_ : Sgs_api_components_revision_module.t option; [@default None] [@key "module"]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
