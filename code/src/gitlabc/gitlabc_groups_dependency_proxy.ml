module DeleteApiV4GroupsIdDependencyProxyCache = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "groups" /% Path.string / "dependency_proxy" / "cache"

  module Responses = struct
    module Accepted = struct end
    module Unauthorized = struct end

    type t =
      [ `Accepted
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t = [ ("202", fun _ -> Ok `Accepted); ("401", fun _ -> Ok `Unauthorized) ]
  end

  let url = "/api/v4/groups/{id}/dependency_proxy/cache"

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
