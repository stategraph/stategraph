module Whoareyou = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "gitlab" / "whoareyou"

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Gitlab_whoareyou.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/v1/gitlab/whoareyou"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Whoami = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "gitlab" / "whoami"

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Gitlab_user.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct end

    type t =
      [ `OK of OK.t
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v1/gitlab/whoami"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
