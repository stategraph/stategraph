module Modules_ = struct
  type t = Sgs_api_components_revision_state_module.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  modules : Modules_.t;
  root_hash : string option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
