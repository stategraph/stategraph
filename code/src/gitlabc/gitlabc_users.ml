module DeleteApiV4UsersId = struct
  module Parameters = struct
    type t = {
      hard_delete : bool option; [@default None]
      id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "users" /% Path.int /? option (bool "hard_delete")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/users/{id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("hard_delete", Var (params.hard_delete, Option Bool)) ])
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4UsersId = struct
  module Parameters = struct
    type t = { id : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4UsersId.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "users" /% Path.int

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/users/{id}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4UsersId = struct
  module Parameters = struct
    type t = {
      id : int;
      with_custom_attributes : bool; [@default false]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "users" /% Path.int /? option_default false (bool "with_custom_attributes")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/users/{id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("with_custom_attributes", Var (params.with_custom_attributes, Bool)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4Users = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4Users.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "users"

  module Responses = struct
    module Created = struct end

    type t = [ `Created ] [@@deriving show, eq]

    let t = [ ("201", fun _ -> Ok `Created) ]
  end

  let url = "/api/v4/users"

  let make ?body =
   fun () ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4Users = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "id" -> Ok `Id
        | `String "name" -> Ok `Name
        | `String "updated_at" -> Ok `Updated_at
        | `String "username" -> Ok `Username
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Id -> `String "id"
        | `Name -> `String "name"
        | `Updated_at -> `String "updated_at"
        | `Username -> `String "username"

      type t =
        ([ `Created_at
         | `Id
         | `Name
         | `Updated_at
         | `Username
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "asc" -> Ok `Asc
        | `String "desc" -> Ok `Desc
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Asc -> `String "asc"
        | `Desc -> `String "desc"

      type t =
        ([ `Asc
         | `Desc
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      active : bool; [@default false]
      admins : bool; [@default false]
      auditors : bool; [@default false]
      blocked : bool; [@default false]
      created_after : string option; [@default None]
      created_before : string option; [@default None]
      exclude_active : bool; [@default false]
      exclude_external : bool; [@default false]
      exclude_humans : bool; [@default false]
      exclude_internal : bool; [@default false]
      extern_uid : string option; [@default None]
      external_ : bool; [@default false] [@key "external"]
      humans : bool; [@default false]
      order_by : Order_by.t option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 20]
      provider : string option; [@default None]
      saml_provider_id : int option; [@default None]
      search : string option; [@default None]
      skip_ldap : bool; [@default false]
      sort : Sort.t option; [@default None]
      two_factor : string option; [@default None]
      username : string option; [@default None]
      with_custom_attributes : bool; [@default false]
      without_project_bots : bool; [@default false]
      without_projects : bool; [@default false]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "users"
    /? option (string "username")
    /? option (string "extern_uid")
    /? option (string "provider")
    /? option (string "search")
    /? option_default false (bool "active")
    /? option_default false (bool "humans")
    /? option_default false (bool "external")
    /? option_default false (bool "blocked")
    /? option (string "created_after")
    /? option (string "created_before")
    /? option_default false (bool "without_projects")
    /? option_default false (bool "without_project_bots")
    /? option_default false (bool "admins")
    /? option (string "two_factor")
    /? option_default false (bool "exclude_active")
    /? option_default false (bool "exclude_external")
    /? option_default false (bool "exclude_humans")
    /? option_default false (bool "exclude_internal")
    /? option
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option_default false (bool "with_custom_attributes")
    /? option_default false (bool "skip_ldap")
    /? option (int "saml_provider_id")
    /? option_default false (bool "auditors")

  module Responses = struct
    module OK = struct
      type t = Gitlabc_components.API_Entities_UserBasic.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/v4/users"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, Option String));
           ("extern_uid", Var (params.extern_uid, Option String));
           ("provider", Var (params.provider, Option String));
           ("search", Var (params.search, Option String));
           ("active", Var (params.active, Bool));
           ("humans", Var (params.humans, Bool));
           ("external", Var (params.external_, Bool));
           ("blocked", Var (params.blocked, Bool));
           ("created_after", Var (params.created_after, Option String));
           ("created_before", Var (params.created_before, Option String));
           ("without_projects", Var (params.without_projects, Bool));
           ("without_project_bots", Var (params.without_project_bots, Bool));
           ("admins", Var (params.admins, Bool));
           ("two_factor", Var (params.two_factor, Option String));
           ("exclude_active", Var (params.exclude_active, Bool));
           ("exclude_external", Var (params.exclude_external, Bool));
           ("exclude_humans", Var (params.exclude_humans, Bool));
           ("exclude_internal", Var (params.exclude_internal, Bool));
           ("order_by", Var (params.order_by, Option (Enum Order_by.t_to_yojson)));
           ("sort", Var (params.sort, Option (Enum Sort.t_to_yojson)));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("with_custom_attributes", Var (params.with_custom_attributes, Bool));
           ("skip_ldap", Var (params.skip_ldap, Bool));
           ("saml_provider_id", Var (params.saml_provider_id, Option Int));
           ("auditors", Var (params.auditors, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
