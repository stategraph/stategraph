module Initiate = struct
  module Parameters = struct
    type t = { compute_node_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Terrat_api_components.Work_manifest_initiate.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Work_manifest.t
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

  let url = "/api/github/v1/compute-node/{compute_node_id}/initiate"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("compute_node_id", Var (params.compute_node_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end
