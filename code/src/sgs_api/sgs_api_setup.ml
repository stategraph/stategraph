module Status = struct
  module Parameters = struct end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Setup_status_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct end

    type t =
      [ `OK of OK.t
      | `Internal_server_error
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("500", fun _ -> Ok `Internal_server_error);
      ]
  end

  let url = "/api/v1/setup/status"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Magic_claim = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Sgs_api_components.Setup_magic_claim_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.Setup_admin_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end
    module Forbidden = struct end
    module Conflict = struct end
    module Service_unavailable = struct end

    type t =
      [ `Created of Created.t
      | `Bad_request
      | `Forbidden
      | `Conflict
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("409", fun _ -> Ok `Conflict);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v1/setup/magic-claim"

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

module Github_app_manifest = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Sgs_api_components.Github_app_manifest_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Github_app_manifest_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/setup/github-app/manifest"

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

module Github_app_callback = struct
  module Parameters = struct
    type t = {
      code : string option; [@default None]
      state : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module Found = struct end

    type t = [ `Found ] [@@deriving show, eq]

    let t = [ ("302", fun _ -> Ok `Found) ]
  end

  let url = "/api/v1/setup/github-app/callback"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("code", Var (params.code, Option String)); ("state", Var (params.state, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Admin = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Sgs_api_components.Setup_admin_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.Setup_admin_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end
    module Forbidden = struct end
    module Conflict = struct end

    type t =
      [ `Created of Created.t
      | `Bad_request
      | `Forbidden
      | `Conflict
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("409", fun _ -> Ok `Conflict);
      ]
  end

  let url = "/api/v1/setup/admin"

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
