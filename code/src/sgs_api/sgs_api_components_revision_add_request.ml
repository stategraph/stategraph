module Nodes = struct
  type t = Sgs_api_components_revision_node.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  nodes : Nodes.t;
  scope : Sgs_api_components_revision_scope.t;
  tx_id : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
