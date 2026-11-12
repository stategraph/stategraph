module GetApiV4UserCounts = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "user_counts"

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/user_counts"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
