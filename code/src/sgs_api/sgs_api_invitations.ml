module Preview = struct
  module Parameters = struct
    type t = { token : string } [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "token"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Invitation_preview_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/api/v1/invitations/preview"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("token", Var (params.token, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Accept = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Sgs_api_components.Invitation_accept_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Invitation_accept_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/api/v1/invitations/accept"

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
