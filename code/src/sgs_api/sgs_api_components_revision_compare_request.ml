type t = {
  scope : Sgs_api_components_revision_scope.t;
  tx_id : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
