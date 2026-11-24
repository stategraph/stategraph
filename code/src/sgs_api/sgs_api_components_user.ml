type t = {
  auth_origin : string option; [@default None]
  avatar_url : string option; [@default None]
  capabilities : Sg_caps_wire_capabilities.t;
  email : string option; [@default None]
  id : string;
  name : string;
  type_ : Sgs_api_components_user_type.t; [@key "type"]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
