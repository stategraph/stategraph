module PostApiV4ApplicationsIdRenewSecret = struct
  module Parameters = struct
    type t = { id : int } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "applications" /% Path.int / "renew-secret"

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/applications/{id}/renew-secret"

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
      `Post
end
