type t = {
  created_at : string;
  expiration : string option; [@default None]
  id : string;
  name : string;
  owner_id : string;
  owner_name : string;
  owner_type : Sgs_api_components_user_type.t;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
