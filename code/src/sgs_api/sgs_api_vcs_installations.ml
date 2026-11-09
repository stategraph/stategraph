module List_unclaimed_github = struct
  module Parameters = struct
    type t = {
      cursor : string option; [@default None]
      limit : int; [@default 100]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (string "cursor") /? option_default 100 (int "limit")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Github_unclaimed_installations.t
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
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/vcs-installations/github/unclaimed"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("cursor", Var (params.cursor, Option String)); ("limit", Var (params.limit, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Github_claim_callback = struct
  module Parameters = struct
    type t = {
      code : string option; [@default None]
      setup_action : string option; [@default None]
      state : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "code")
    /? option (string "state")
    /? option (string "setup_action")

  module Responses = struct
    module Found = struct end

    type t = [ `Found ] [@@deriving show, eq]

    let t = [ ("302", fun _ -> Ok `Found) ]
  end

  let url = "/api/v1/vcs-installations/github/claim/callback"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("code", Var (params.code, Option String));
           ("state", Var (params.state, Option String));
           ("setup_action", Var (params.setup_action, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
