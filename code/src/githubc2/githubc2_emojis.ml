module Get = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "emojis"

  module Responses = struct
    module OK = struct
      module Additional = struct
        type t = string [@@deriving yojson { strict = false; meta = false }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Additional)
    end

    module Not_modified = struct end

    type t =
      [ `OK of OK.t
      | `Not_modified
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
      ]
  end

  let url = "/emojis"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
