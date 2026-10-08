module Tenants = struct
  type t = Sgs_api_components_tenant.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  admin_rights : Sgs_api_components_admin_rights.t;
  auth_origin : string option; [@default None]
  avatar_url : string option; [@default None]
  capabilities : Sg_caps_wire_capabilities.t option; [@default None]
  created_at : string;
  email : string option; [@default None]
  id : string;
  name : string;
  tenants : Tenants.t;
  tenants_complete : bool;
  type_ : string; [@key "type"]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
