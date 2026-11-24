module Users = struct
  module Items = struct
    type t = {
      admin_rights : Sgs_api_components_admin_rights.t;
      auth_origin : string option; [@default None]
      avatar_url : string option; [@default None]
      created_at : string;
      email : string option; [@default None]
      id : string;
      name : string;
      type_ : Sgs_api_components_user_type.t; [@key "type"]
    }
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  has_more : bool;
  limit : int;
  next_cursor : string option; [@default None]
  total_count : int;
  users : Users.t;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
