module Update_campaign = struct
  module Parameters = struct
    type t = {
      campaign_number : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Managers = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Team_managers = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      contact_link : string option; [@default None]
      description : string option; [@default None]
      ends_at : string option; [@default None]
      managers : Managers.t option; [@default None]
      name : string option; [@default None]
      state : Githubc2_components.Campaign_state.t option; [@default None]
      team_managers : Team_managers.t option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Campaign_summary.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/orgs/{org}/campaigns/{campaign_number}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String)); ("campaign_number", Var (params.campaign_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_campaign = struct
  module Parameters = struct
    type t = {
      campaign_number : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/orgs/{org}/campaigns/{campaign_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String)); ("campaign_number", Var (params.campaign_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_campaign_summary = struct
  module Parameters = struct
    type t = {
      campaign_number : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Campaign_summary.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/orgs/{org}/campaigns/{campaign_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String)); ("campaign_number", Var (params.campaign_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_campaign = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Code_scanning_alerts = struct
        module Items = struct
          module Alert_numbers = struct
            type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t = {
            alert_numbers : Alert_numbers.t;
            repository_id : int;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Managers = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Team_managers = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        code_scanning_alerts : Code_scanning_alerts.t option; [@default None]
        contact_link : string option; [@default None]
        description : string;
        ends_at : string;
        generate_issues : bool; [@default false]
        managers : Managers.t option; [@default None]
        name : string;
        team_managers : Team_managers.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    module V1 = struct
      module Code_scanning_alerts = struct
        module Items = struct
          module Alert_numbers = struct
            type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t = {
            alert_numbers : Alert_numbers.t;
            repository_id : int;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Managers = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Team_managers = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        code_scanning_alerts : Code_scanning_alerts.t option; [@default None]
        contact_link : string option; [@default None]
        description : string;
        ends_at : string;
        generate_issues : bool; [@default false]
        managers : Managers.t option; [@default None]
        name : string;
        team_managers : Team_managers.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    type t =
      | V0 of V0.t
      | V1 of V1.t
    [@@deriving show, eq]

    let of_yojson =
      Json_schema.one_of
        (let open CCResult in
         [
           (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
           (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
         ])

    let to_yojson = function
      | V0 v -> V0.to_yojson v
      | V1 v -> V1.to_yojson v
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Campaign_summary.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Too_many_requests = struct end

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Too_many_requests
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("429", fun _ -> Ok `Too_many_requests);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/orgs/{org}/campaigns"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_org_campaigns = struct
  module Parameters = struct
    module Direction = struct
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

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "ends_at" -> Ok `Ends_at
        | `String "published" -> Ok `Published
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Ends_at -> `String "ends_at"
        | `Published -> `String "published"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Ends_at
         | `Published
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t; [@default `Desc]
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      sort : Sort.t; [@default `Created]
      state : Githubc2_components.Campaign_state.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option
         (ud "state" (fun value ->
              CCResult.to_opt (Githubc2_components.Campaign_state.t_of_yojson (`String value))))
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Campaign_summary.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/orgs/{org}/campaigns"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ( "state",
             Var (params.state, Option (Enum Githubc2_components.Campaign_state.t_to_yojson)) );
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
