module Update = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      team_slug : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Notification_setting = struct
        let t_of_yojson = function
          | `String "notifications_disabled" -> Ok `Notifications_disabled
          | `String "notifications_enabled" -> Ok `Notifications_enabled
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Notifications_disabled -> `String "notifications_disabled"
          | `Notifications_enabled -> `String "notifications_enabled"

        type t =
          ([ `Notifications_disabled
           | `Notifications_enabled
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Organization_selection_type = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "disabled" -> Ok `Disabled
          | `String "selected" -> Ok `Selected
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `Disabled -> `String "disabled"
          | `Selected -> `String "selected"

        type t =
          ([ `All
           | `Disabled
           | `Selected
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Sync_to_organizations = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "disabled" -> Ok `Disabled
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `Disabled -> `String "disabled"

        type t =
          ([ `All
           | `Disabled
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        description : string option; [@default None]
        group_id : string option; [@default None]
        name : string option; [@default None]
        notification_setting : Notification_setting.t option; [@default None]
        organization_selection_type : Organization_selection_type.t; [@default `Disabled]
        sync_to_organizations : Sync_to_organizations.t; [@default `Disabled]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Enterprise_team.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/teams/{team_slug}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("team_slug", Var (params.team_slug, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      team_slug : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/teams/{team_slug}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("team_slug", Var (params.team_slug, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      team_slug : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Enterprise_team.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/teams/{team_slug}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("team_slug", Var (params.team_slug, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create = struct
  module Parameters = struct
    type t = { enterprise : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Notification_setting = struct
        let t_of_yojson = function
          | `String "notifications_disabled" -> Ok `Notifications_disabled
          | `String "notifications_enabled" -> Ok `Notifications_enabled
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Notifications_disabled -> `String "notifications_disabled"
          | `Notifications_enabled -> `String "notifications_enabled"

        type t =
          ([ `Notifications_disabled
           | `Notifications_enabled
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Organization_selection_type = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "disabled" -> Ok `Disabled
          | `String "selected" -> Ok `Selected
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `Disabled -> `String "disabled"
          | `Selected -> `String "selected"

        type t =
          ([ `All
           | `Disabled
           | `Selected
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Sync_to_organizations = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "disabled" -> Ok `Disabled
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `Disabled -> `String "disabled"

        type t =
          ([ `All
           | `Disabled
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        description : string option; [@default None]
        group_id : string option; [@default None]
        name : string;
        notification_setting : Notification_setting.t option; [@default None]
        organization_selection_type : Organization_selection_type.t; [@default `Disabled]
        sync_to_organizations : Sync_to_organizations.t; [@default `Disabled]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Enterprise_team.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/enterprises/{enterprise}/teams"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("enterprise", Var (params.enterprise, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 30 (int "per_page") /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Enterprise_team.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/teams"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("enterprise", Var (params.enterprise, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end
