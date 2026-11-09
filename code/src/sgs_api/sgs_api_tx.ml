module State_map = struct
  module Parameters = struct
    type t = { tx_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.State_map_response.t
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

  let url = "/api/v1/tx/{tx_id}/state-map"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Security_impact_summary = struct
  module Parameters = struct
    type t = { tx_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tx_security_impact_summary.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Accepted = struct
      type t = Sgs_api_components.Tx_security_impact_status.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Accepted of Accepted.t
      | `Unauthorized
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/tx/{tx_id}/security/impact/summary"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Security_impact = struct
  module Parameters = struct
    type t = { tx_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tx_security_impact.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Accepted = struct
      type t = Sgs_api_components.Tx_security_impact_status.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Accepted of Accepted.t
      | `Unauthorized
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/tx/{tx_id}/security/impact"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Preview = struct
  module Parameters = struct
    type t = { tx_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Preview_response.t
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

  let url = "/api/v1/tx/{tx_id}/preview"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Plan_operations = struct
  module Parameters = struct
    type t = {
      limit : int option; [@default None]
      page : string option; [@default None]
      tx_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (string "page") /? option (int "limit")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Plan_operations.t
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

  let url = "/api/v1/tx/{tx_id}/plan-operations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Option String)); ("limit", Var (params.limit, Option Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Output = struct
  module Parameters = struct
    type t = {
      limit : int option; [@default None]
      page : string option; [@default None]
      tx_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (string "page") /? option (int "limit")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tx_output_chunks.t
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

  let url = "/api/v1/tx/{tx_id}/output"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Option String)); ("limit", Var (params.limit, Option Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Append = struct
  module Parameters = struct
    type t = { tx_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Tx_log_set.t list
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

    type t =
      [ `OK
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/tx/{tx_id}/logs/append"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Logs_list = struct
  module Parameters = struct
    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      limit : int; [@default 20]
      page : Page.t option; [@default None]
      q : string option; [@default None]
      tx_id : string;
      tz : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (array (string "page"))
    /? option (string "q")
    /? option (string "tz")
    /? option_default 20 (int "limit")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tx_logs.t
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

  let url = "/api/v1/tx/{tx_id}/logs"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Option (Array String)));
           ("q", Var (params.q, Option String));
           ("tz", Var (params.tz, Option String));
           ("limit", Var (params.limit, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Costs = struct
  module Parameters = struct
    type t = { tx_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tx_cost_delta.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Accepted = struct
      type t = Sgs_api_components.Tx_cost_status.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Accepted of Accepted.t
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/tx/{tx_id}/costs"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Commit = struct
  module Parameters = struct
    type t = { tx_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Commit_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/api/v1/tx/{tx_id}/commit"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Apply = struct
  module Parameters = struct
    module Replace = struct
      let t_of_yojson = function
        | `String "delta" -> Ok `Delta
        | `String "hcl" -> Ok `Hcl
        | `String "overwrite" -> Ok `Overwrite
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Delta -> `String "delta"
        | `Hcl -> `String "hcl"
        | `Overwrite -> `String "overwrite"

      type t =
        ([ `Delta
         | `Hcl
         | `Overwrite
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      replace : Replace.t; [@default `Delta]
      tx_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default
         `Delta
         (ud "replace" (fun value ->
              CCResult.to_opt (Parameters.Replace.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Apply_response.t
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

  let url = "/api/v1/tx/{tx_id}/apply"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("replace", Var (params.replace, Enum Replace.t_to_yojson)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module Abort = struct
  module Parameters = struct
    type t = { tx_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tx.t
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

  let url = "/api/v1/tx/{tx_id}/abort"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get = struct
  module Parameters = struct
    type t = { tx_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tx_detail.t
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

  let url = "/api/v1/tx/{tx_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tx_id", Var (params.tx_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Session_create = struct
  module Parameters = struct end

  module Request_body = struct
    module Tags = struct
      type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = { tags : Tags.t } [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct
      type t = { token : string } [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `Created of Created.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tx/session/create"

  let make ~body =
   fun () ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end
