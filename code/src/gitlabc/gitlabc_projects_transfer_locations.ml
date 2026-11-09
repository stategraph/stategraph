module GetApiV4ProjectsIdTransferLocations = struct
  module Parameters = struct
    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      search : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "search")
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end

    type t =
      [ `OK
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("403", fun _ -> Ok `Forbidden) ]
  end

  let url = "/api/v4/projects/{id}/transfer_locations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("search", Var (params.search, Option String));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
