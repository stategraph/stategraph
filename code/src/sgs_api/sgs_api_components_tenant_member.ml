module Admin_scope = struct
  let t_of_yojson = function
    | `String "instance" -> Ok `Instance
    | `String "none" -> Ok `None
    | `String "tenant" -> Ok `Tenant
    | `String "wider" -> Ok `Wider
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Instance -> `String "instance"
    | `None -> `String "none"
    | `Tenant -> `String "tenant"
    | `Wider -> `String "wider"

  type t =
    ([ `Instance
     | `None
     | `Tenant
     | `Wider
     ]
    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Users_manage_scope = struct
  let t_of_yojson = function
    | `String "instance" -> Ok `Instance
    | `String "none" -> Ok `None
    | `String "tenant" -> Ok `Tenant
    | `String "wider" -> Ok `Wider
    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

  let t_to_yojson = function
    | `Instance -> `String "instance"
    | `None -> `String "none"
    | `Tenant -> `String "tenant"
    | `Wider -> `String "wider"

  type t =
    ([ `Instance
     | `None
     | `Tenant
     | `Wider
     ]
    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  admin_scope : Admin_scope.t;
  avatar_url : string option; [@default None]
  email : string option; [@default None]
  joined_at : string;
  name : string;
  type_ : string; [@key "type"]
  user_id : string;
  users_manage_scope : Users_manage_scope.t;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
