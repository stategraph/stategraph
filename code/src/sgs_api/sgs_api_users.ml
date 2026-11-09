module Update = struct
  module Parameters = struct
    type t = { user_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.User_update_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? uuid "user_id"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.User_update_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/api/v1/users/update"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, String)) ])
      ~url
      ~responses:Responses.t
      `Put
end

module Set_instance_admin = struct
  module Parameters = struct
    type t = { user_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.User_set_instance_admin_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? uuid "user_id"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.User_set_instance_admin_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/api/v1/users/set-instance-admin"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, String)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module Detail = struct
  module Parameters = struct
    type t = { user_id : string } [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? uuid "user_id"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.User_detail_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/api/v1/users/detail"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete = struct
  module Parameters = struct
    type t = { user_id : string } [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? uuid "user_id"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.User_delete_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/api/v1/users/delete"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, String)) ])
      ~url
      ~responses:Responses.t
      `Delete
end

module Change_password = struct
  module Parameters = struct
    type t = { user_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.User_change_password_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? uuid "user_id"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.User_change_password_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/api/v1/users/change-password"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, String)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module Create = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Sgs_api_components.User_create_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.User_create_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/api/v1/users"

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

module List = struct
  module Parameters = struct
    type t = {
      cursor : string option; [@default None]
      limit : int; [@default 25]
      search : string option; [@default None]
      type_ : string option; [@default None] [@key "type"]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "type")
    /? option (string "search")
    /? option (string "cursor")
    /? option_default 25 (int "limit")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Users_list_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/api/v1/users"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("type", Var (params.type_, Option String));
           ("search", Var (params.search, Option String));
           ("cursor", Var (params.cursor, Option String));
           ("limit", Var (params.limit, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
