module PostApiV4ProjectsIdUnarchive = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "unarchive"

  module Responses = struct
    module Created = struct end
    module Forbidden = struct end

    type t =
      [ `Created
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t = [ ("201", fun _ -> Ok `Created); ("403", fun _ -> Ok `Forbidden) ]
  end

  let url = "/api/v4/projects/{id}/unarchive"

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
      `Post
end
