module Get_github_billing_usage_summary_report_user = struct
  module Parameters = struct
    type t = {
      day : int option; [@default None]
      month : int option; [@default None]
      product : string option; [@default None]
      repository : string option; [@default None]
      sku : string option; [@default None]
      username : string;
      year : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (int "year")
    /? option (int "month")
    /? option (int "day")
    /? option (string "repository")
    /? option (string "product")
    /? option (string "sku")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Billing_usage_summary_report_user.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/users/{username}/settings/billing/usage/summary"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("username", Var (params.username, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("year", Var (params.year, Option Int));
           ("month", Var (params.month, Option Int));
           ("day", Var (params.day, Option Int));
           ("repository", Var (params.repository, Option String));
           ("product", Var (params.product, Option String));
           ("sku", Var (params.sku, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_github_billing_usage_report_user = struct
  module Parameters = struct
    type t = {
      day : int option; [@default None]
      month : int option; [@default None]
      username : string;
      year : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (int "year") /? option (int "month") /? option (int "day")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Billing_usage_report_user.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/users/{username}/settings/billing/usage"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("username", Var (params.username, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("year", Var (params.year, Option Int));
           ("month", Var (params.month, Option Int));
           ("day", Var (params.day, Option Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_github_billing_premium_request_usage_report_user = struct
  module Parameters = struct
    type t = {
      day : int option; [@default None]
      model : string option; [@default None]
      month : int option; [@default None]
      product : string option; [@default None]
      username : string;
      year : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (int "year")
    /? option (int "month")
    /? option (int "day")
    /? option (string "model")
    /? option (string "product")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Billing_premium_request_usage_report_user.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/users/{username}/settings/billing/premium_request/usage"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("username", Var (params.username, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("year", Var (params.year, Option Int));
           ("month", Var (params.month, Option Int));
           ("day", Var (params.day, Option Int));
           ("model", Var (params.model, Option String));
           ("product", Var (params.product, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_github_billing_ai_credit_usage_report_user = struct
  module Parameters = struct
    type t = {
      day : int option; [@default None]
      model : string option; [@default None]
      month : int option; [@default None]
      product : string option; [@default None]
      username : string;
      year : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (int "year")
    /? option (int "month")
    /? option (int "day")
    /? option (string "model")
    /? option (string "product")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Billing_ai_credit_usage_report_user.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/users/{username}/settings/billing/ai_credit/usage"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("username", Var (params.username, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("year", Var (params.year, Option Int));
           ("month", Var (params.month, Option Int));
           ("day", Var (params.day, Option Int));
           ("model", Var (params.model, Option String));
           ("product", Var (params.product, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_github_billing_usage_summary_report_org = struct
  module Parameters = struct
    type t = {
      day : int option; [@default None]
      month : int option; [@default None]
      org : string;
      product : string option; [@default None]
      repository : string option; [@default None]
      sku : string option; [@default None]
      year : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (int "year")
    /? option (int "month")
    /? option (int "day")
    /? option (string "repository")
    /? option (string "product")
    /? option (string "sku")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Billing_usage_summary_report_org.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/organizations/{org}/settings/billing/usage/summary"

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
           ("year", Var (params.year, Option Int));
           ("month", Var (params.month, Option Int));
           ("day", Var (params.day, Option Int));
           ("repository", Var (params.repository, Option String));
           ("product", Var (params.product, Option String));
           ("sku", Var (params.sku, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_github_billing_usage_report_org = struct
  module Parameters = struct
    type t = {
      day : int option; [@default None]
      month : int option; [@default None]
      org : string;
      year : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (int "year") /? option (int "month") /? option (int "day")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Billing_usage_report.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/organizations/{org}/settings/billing/usage"

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
           ("year", Var (params.year, Option Int));
           ("month", Var (params.month, Option Int));
           ("day", Var (params.day, Option Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_github_billing_premium_request_usage_report_org = struct
  module Parameters = struct
    type t = {
      day : int option; [@default None]
      model : string option; [@default None]
      month : int option; [@default None]
      org : string;
      product : string option; [@default None]
      user : string option; [@default None]
      year : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (int "year")
    /? option (int "month")
    /? option (int "day")
    /? option (string "user")
    /? option (string "model")
    /? option (string "product")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Billing_premium_request_usage_report_org.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/organizations/{org}/settings/billing/premium_request/usage"

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
           ("year", Var (params.year, Option Int));
           ("month", Var (params.month, Option Int));
           ("day", Var (params.day, Option Int));
           ("user", Var (params.user, Option String));
           ("model", Var (params.model, Option String));
           ("product", Var (params.product, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_budget_org = struct
  module Parameters = struct
    type t = {
      budget_id : string;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Budget_alerting = struct
        module Primary = struct
          module Alert_recipients = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t = {
            alert_recipients : Alert_recipients.t option; [@default None]
            will_alert : bool option; [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Budget_scope = struct
        let t_of_yojson = function
          | `String "cost_center" -> Ok `Cost_center
          | `String "enterprise" -> Ok `Enterprise
          | `String "multi_user_customer" -> Ok `Multi_user_customer
          | `String "organization" -> Ok `Organization
          | `String "repository" -> Ok `Repository
          | `String "user" -> Ok `User
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Cost_center -> `String "cost_center"
          | `Enterprise -> `String "enterprise"
          | `Multi_user_customer -> `String "multi_user_customer"
          | `Organization -> `String "organization"
          | `Repository -> `String "repository"
          | `User -> `String "user"

        type t =
          ([ `Cost_center
           | `Enterprise
           | `Multi_user_customer
           | `Organization
           | `Repository
           | `User
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Budget_type = struct
        module V0 = struct
          let t_of_yojson = function
            | `String "BundlePricing" -> Ok `BundlePricing
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `BundlePricing -> `String "BundlePricing"

          type t = ([ `BundlePricing ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module V1 = struct
          let t_of_yojson = function
            | `String "ProductPricing" -> Ok `ProductPricing
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `ProductPricing -> `String "ProductPricing"

          type t = ([ `ProductPricing ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module V2 = struct
          let t_of_yojson = function
            | `String "SkuPricing" -> Ok `SkuPricing
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `SkuPricing -> `String "SkuPricing"

          type t = ([ `SkuPricing ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t =
          | V0 of V0.t
          | V1 of V1.t
          | V2 of V2.t
        [@@deriving show, eq]

        let of_yojson =
          Json_schema.one_of
            (let open CCResult in
             [
               (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
               (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
               (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
             ])

        let to_yojson = function
          | V0 v -> V0.to_yojson v
          | V1 v -> V1.to_yojson v
          | V2 v -> V2.to_yojson v
      end

      type t = {
        budget_alerting : Budget_alerting.t option; [@default None]
        budget_amount : int option; [@default None]
        budget_entity_name : string option; [@default None]
        budget_product_sku : string option; [@default None]
        budget_scope : Budget_scope.t option; [@default None]
        budget_type : Budget_type.t option; [@default None]
        prevent_further_usage : bool option; [@default None]
        user : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Update_budget.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
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
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/organizations/{org}/settings/billing/budgets/{budget_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("budget_id", Var (params.budget_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_budget_org = struct
  module Parameters = struct
    type t = {
      budget_id : string;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Delete_budget.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/organizations/{org}/settings/billing/budgets/{budget_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("budget_id", Var (params.budget_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_budget_org = struct
  module Parameters = struct
    type t = {
      budget_id : string;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Get_budget.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/organizations/{org}/settings/billing/budgets/{budget_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("budget_id", Var (params.budget_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_organization_budget = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Budget_alerting = struct
        module Primary = struct
          module Alert_recipients = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t = {
            alert_recipients : Alert_recipients.t option; [@default None]
            will_alert : bool option; [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Budget_scope = struct
        let t_of_yojson = function
          | `String "multi_user_customer" -> Ok `Multi_user_customer
          | `String "organization" -> Ok `Organization
          | `String "repository" -> Ok `Repository
          | `String "user" -> Ok `User
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Multi_user_customer -> `String "multi_user_customer"
          | `Organization -> `String "organization"
          | `Repository -> `String "repository"
          | `User -> `String "user"

        type t =
          ([ `Multi_user_customer
           | `Organization
           | `Repository
           | `User
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Budget_type = struct
        module V0 = struct
          let t_of_yojson = function
            | `String "BundlePricing" -> Ok `BundlePricing
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `BundlePricing -> `String "BundlePricing"

          type t = ([ `BundlePricing ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module V1 = struct
          let t_of_yojson = function
            | `String "ProductPricing" -> Ok `ProductPricing
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `ProductPricing -> `String "ProductPricing"

          type t = ([ `ProductPricing ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module V2 = struct
          let t_of_yojson = function
            | `String "SkuPricing" -> Ok `SkuPricing
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `SkuPricing -> `String "SkuPricing"

          type t = ([ `SkuPricing ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t =
          | V0 of V0.t
          | V1 of V1.t
          | V2 of V2.t
        [@@deriving show, eq]

        let of_yojson =
          Json_schema.one_of
            (let open CCResult in
             [
               (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
               (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
               (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
             ])

        let to_yojson = function
          | V0 v -> V0.to_yojson v
          | V1 v -> V1.to_yojson v
          | V2 v -> V2.to_yojson v
      end

      type t = {
        budget_alerting : Budget_alerting.t option; [@default None]
        budget_amount : int option; [@default None]
        budget_entity_name : string; [@default ""]
        budget_product_sku : string option; [@default None]
        budget_scope : Budget_scope.t option; [@default None]
        budget_type : Budget_type.t option; [@default None]
        prevent_further_usage : bool option; [@default None]
        user : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Create_budget.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
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
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/organizations/{org}/settings/billing/budgets"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
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

module Get_all_budgets_org = struct
  module Parameters = struct
    module Scope = struct
      let t_of_yojson = function
        | `String "cost_center" -> Ok `Cost_center
        | `String "enterprise" -> Ok `Enterprise
        | `String "multi_user_customer" -> Ok `Multi_user_customer
        | `String "organization" -> Ok `Organization
        | `String "repository" -> Ok `Repository
        | `String "user" -> Ok `User
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Cost_center -> `String "cost_center"
        | `Enterprise -> `String "enterprise"
        | `Multi_user_customer -> `String "multi_user_customer"
        | `Organization -> `String "organization"
        | `Repository -> `String "repository"
        | `User -> `String "user"

      type t =
        ([ `Cost_center
         | `Enterprise
         | `Multi_user_customer
         | `Organization
         | `Repository
         | `User
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 10]
      scope : Scope.t option; [@default None]
      user : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default 1 (int "page")
    /? option_default 10 (int "per_page")
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option (string "user")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Get_all_budgets.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/organizations/{org}/settings/billing/budgets"

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
           ("scope", Var (params.scope, Option (Enum Scope.t_to_yojson)));
           ("user", Var (params.user, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_github_billing_ai_credit_usage_report_org = struct
  module Parameters = struct
    type t = {
      day : int option; [@default None]
      model : string option; [@default None]
      month : int option; [@default None]
      org : string;
      product : string option; [@default None]
      user : string option; [@default None]
      year : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (int "year")
    /? option (int "month")
    /? option (int "day")
    /? option (string "user")
    /? option (string "model")
    /? option (string "product")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Billing_ai_credit_usage_report_org.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/organizations/{org}/settings/billing/ai_credit/usage"

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
           ("year", Var (params.year, Option Int));
           ("month", Var (params.month, Option Int));
           ("day", Var (params.day, Option Int));
           ("user", Var (params.user, Option String));
           ("model", Var (params.model, Option String));
           ("product", Var (params.product, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
