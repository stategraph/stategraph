module Get_template = struct
  module Parameters = struct
    type t = { name : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "gitignore" / "templates" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Gitignore_template.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
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

  let url = "/gitignore/templates/{name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("name", Var (params.name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_all_templates = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "gitignore" / "templates"

  module Responses = struct
    module OK = struct
      type t = string list [@@deriving yojson { strict = false; meta = false }, show, eq]
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

  let url = "/gitignore/templates"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
