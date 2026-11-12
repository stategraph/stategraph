module Is_member = struct
  module Parameters = struct
    type t = { id : int } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "gitlab" / "groups" /% Path.int / "is-member"

  module Responses = struct
    module OK = struct
      type t = { result : bool } [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/v1/gitlab/groups/{id}/is-member"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "gitlab" / "groups"

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Gitlab_group.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/v1/gitlab/groups"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
