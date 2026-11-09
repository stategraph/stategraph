module Set_cookie = struct
  module Parameters = struct
    type t = { session_id : string [@key "session-id"] } [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "session-id"

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v1/test/set-cookie"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("session-id", Var (params.session_id, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end
