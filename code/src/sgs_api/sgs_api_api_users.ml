module Create = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Sgs_api_components.Api_user_create_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "api-users"

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.Api_user_create_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end
    module Unauthorized = struct end

    type t =
      [ `Created of Created.t
      | `Bad_request
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/api-users"

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
