module Config = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "server" / "config"

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Server_config.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/v1/server/config"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
