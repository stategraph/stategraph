module Render_raw = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "markdown" / "raw"

  module Responses = struct
    module OK = struct end
    module Not_modified = struct end

    type t =
      [ `OK
      | `Not_modified
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("304", fun _ -> Ok `Not_modified) ]
  end

  let url = "/markdown/raw"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Render = struct
  module Parameters = struct end

  module Request_body = struct
    module Primary = struct
      module Mode = struct
        let t_of_yojson = function
          | `String "gfm" -> Ok `Gfm
          | `String "markdown" -> Ok `Markdown
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Gfm -> `String "gfm"
          | `Markdown -> `String "markdown"

        type t =
          ([ `Gfm
           | `Markdown
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        context : string option; [@default None]
        mode : Mode.t; [@default `Markdown]
        text : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "markdown"

  module Responses = struct
    module OK = struct end
    module Not_modified = struct end

    type t =
      [ `OK
      | `Not_modified
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("304", fun _ -> Ok `Not_modified) ]
  end

  let url = "/markdown"

  let make ~body =
   fun () ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end
