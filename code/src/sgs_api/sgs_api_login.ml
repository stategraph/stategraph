module Initiate = struct
  module Parameters = struct
    type t = {
      provider : string;
      rd : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module Found = struct end
    module Not_found = struct end
    module Service_unavailable = struct end

    type t =
      [ `Found
      | `Not_found
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("302", fun _ -> Ok `Found);
        ("404", fun _ -> Ok `Not_found);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v1/login/{provider}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("provider", Var (params.provider, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("rd", Var (params.rd, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Password = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Sgs_api_components.Login_password_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Login_password_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v1/login/password"

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

module Options = struct
  module Parameters = struct end

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Login_options.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/v1/login/options"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
