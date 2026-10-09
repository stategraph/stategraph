type t = {
  hash : string option; [@default None]
  kind : Sgs_api_components_revision_module_kind.t option; [@default None]
  source : string;
  version : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
