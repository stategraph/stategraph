module Handoff = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "dedicated-stategraphs" /% Path.string / "handoff"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Dedicated_stategraph_handoff_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end
    module Conflict = struct end
    module Precondition_failed = struct end
    module Bad_gateway = struct end
    module Service_unavailable = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      | `Conflict
      | `Precondition_failed
      | `Bad_gateway
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("409", fun _ -> Ok `Conflict);
        ("412", fun _ -> Ok `Precondition_failed);
        ("502", fun _ -> Ok `Bad_gateway);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v1/dedicated-stategraphs/{id}/handoff"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Delete = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "dedicated-stategraphs" /% Path.string

  module Responses = struct
    module No_content = struct end
    module Unauthorized = struct end
    module Not_found = struct end
    module Bad_gateway = struct end
    module Service_unavailable = struct end

    type t =
      [ `No_content
      | `Unauthorized
      | `Not_found
      | `Bad_gateway
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("502", fun _ -> Ok `Bad_gateway);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v1/dedicated-stategraphs/{id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "dedicated-stategraphs" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Dedicated_stategraph.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end
    module Bad_gateway = struct end
    module Service_unavailable = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      | `Bad_gateway
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("502", fun _ -> Ok `Bad_gateway);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v1/dedicated-stategraphs/{id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Sgs_api_components.Dedicated_stategraph_create_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "dedicated-stategraphs"

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.Dedicated_stategraph.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end
    module Unauthorized = struct end
    module Not_found = struct end
    module Conflict = struct end
    module Precondition_failed = struct end
    module Bad_gateway = struct end
    module Service_unavailable = struct end

    type t =
      [ `Created of Created.t
      | `Bad_request
      | `Unauthorized
      | `Not_found
      | `Conflict
      | `Precondition_failed
      | `Bad_gateway
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("409", fun _ -> Ok `Conflict);
        ("412", fun _ -> Ok `Precondition_failed);
        ("502", fun _ -> Ok `Bad_gateway);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v1/dedicated-stategraphs"

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

module List = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "dedicated-stategraphs"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Dedicated_stategraphs_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end
    module Bad_gateway = struct end
    module Service_unavailable = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      | `Bad_gateway
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("502", fun _ -> Ok `Bad_gateway);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v1/dedicated-stategraphs"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Regions = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "dedicated-stategraph-regions"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Dedicated_stategraph_regions_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Not_found = struct end
    module Bad_gateway = struct end
    module Service_unavailable = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Not_found
      | `Bad_gateway
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("502", fun _ -> Ok `Bad_gateway);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v1/dedicated-stategraph-regions"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
