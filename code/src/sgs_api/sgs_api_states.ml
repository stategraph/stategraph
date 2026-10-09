module Summary = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.State_summary.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/summary"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Security_scans = struct
  module Parameters = struct
    type t = {
      limit : int option; [@default None]
      page : string option; [@default None]
      state_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Security_scans_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/states/{state_id}/security/scans"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Option String)); ("limit", Var (params.limit, Option Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Security_scan = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module Accepted = struct
      type t = Sgs_api_components.Task.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Accepted of Accepted.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/states/{state_id}/security/scan"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Security_findings_summary = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Security_findings_summary.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/states/{state_id}/security/findings/summary"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Security_findings = struct
  module Parameters = struct
    type t = {
      limit : int option; [@default None]
      page : string option; [@default None]
      severity : string option; [@default None]
      state_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Security_state_findings.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/states/{state_id}/security/findings"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Option String));
           ("severity", Var (params.severity, Option String));
           ("limit", Var (params.limit, Option Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Revision_scopes = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Revision_scopes_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/revision/scopes"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Revision_hash = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Revision_hash_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/revision/hash"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Revision_compare = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Revision_compare_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Revision_compare_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/revision/compare"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Revision_add = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Revision_add_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Not_found
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/api/v1/states/{state_id}/revision"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Resources_summary = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Resources_summary.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/resources/summary"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Modules_list = struct
  module Parameters = struct
    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      limit : int option; [@default None]
      page : Page.t option; [@default None]
      state_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Modules.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/modules"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Option (Array String)));
           ("limit", Var (params.limit, Option Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Instance_blast_radius = struct
  module Parameters = struct
    type t = {
      instance_address : string;
      limit : int option; [@default None]
      max_depth : int option; [@default None]
      state_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Instance_blast_radius.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/instances/{instance_address}/blast-radius"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("state_id", Var (params.state_id, String));
           ("instance_address", Var (params.instance_address, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("max_depth", Var (params.max_depth, Option Int));
           ("limit", Var (params.limit, Option Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Instances_list = struct
  module Parameters = struct
    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      limit : int option; [@default None]
      page : Page.t option; [@default None]
      q : string option; [@default None]
      state_id : string;
      tz : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Instances.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/instances"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Option (Array String)));
           ("q", Var (params.q, Option String));
           ("tz", Var (params.tz, Option String));
           ("limit", Var (params.limit, Option Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Export = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/export"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Costs_unsupported = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.State_cost_unsupported.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/costs/unsupported"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Costs_calculate = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module Accepted = struct
      type t = Sgs_api_components.Task.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    module Internal_server_error = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Accepted of Accepted.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/states/{state_id}/costs/calculate"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Costs_actuals = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.State_cost_actuals.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/costs/actuals"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Costs = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.State_costs.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/states/{state_id}/costs"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end

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
      [ `OK
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/api/v1/states/{state_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Backend_set_workspace = struct
  module Parameters = struct
    type t = {
      state_id : string;
      workspace : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end

    type t =
      [ `OK
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized) ]
  end

  let url = "/api/v1/states/backend/{group_id}/{workspace}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("state_id", Var (params.state_id, String)); ("workspace", Var (params.workspace, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Backend_get_workspace = struct
  module Parameters = struct
    type t = {
      group_id : string;
      workspace : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = string [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/states/backend/{group_id}/{workspace}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("group_id", Var (params.group_id, String)); ("workspace", Var (params.workspace, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Backend_set = struct
  module Parameters = struct
    type t = { state_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end

    type t =
      [ `OK
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized) ]
  end

  let url = "/api/v1/states/backend/{group_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Backend_get = struct
  module Parameters = struct
    type t = { group_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = string [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/states/backend/{group_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("group_id", Var (params.group_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
