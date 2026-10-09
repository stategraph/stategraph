type t = {
  kind : Sgs_api_components_revision_module_kind.t;
  source : string;
  version : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
