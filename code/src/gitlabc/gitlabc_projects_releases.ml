module PostApiV4ProjectsIdReleasesTagNameEvidence = struct
  module Parameters = struct
    type t = {
      id : int;
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}/evidence"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tag_name", Var (params.tag_name, String)); ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdReleasesTagNameDownloads_directAssetPath = struct
  module Parameters = struct
    type t = {
      direct_asset_path : string;
      id : string;
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "direct_asset_path"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}/downloads/*direct_asset_path"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("tag_name", Var (params.tag_name, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("direct_asset_path", Var (params.direct_asset_path, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4ProjectsIdReleasesTagNameAssetsLinksLinkId = struct
  module Parameters = struct
    type t = {
      id : string;
      link_id : int;
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end
    module Unauthorized = struct end

    type t =
      [ `No_content
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content); ("401", fun _ -> Ok `Unauthorized) ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}/assets/links/{link_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("tag_name", Var (params.tag_name, String));
           ("link_id", Var (params.link_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdReleasesTagNameAssetsLinksLinkId = struct
  module Parameters = struct
    type t = {
      id : string;
      link_id : int;
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdReleasesTagNameAssetsLinksLinkId.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Unauthorized = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}/assets/links/{link_id}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("tag_name", Var (params.tag_name, String));
           ("link_id", Var (params.link_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdReleasesTagNameAssetsLinksLinkId = struct
  module Parameters = struct
    type t = {
      id : string;
      link_id : int;
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}/assets/links/{link_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("tag_name", Var (params.tag_name, String));
           ("link_id", Var (params.link_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdReleasesTagNameAssetsLinks = struct
  module Parameters = struct
    type t = {
      id : string;
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdReleasesTagNameAssetsLinks.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}/assets/links"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("tag_name", Var (params.tag_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdReleasesTagNameAssetsLinks = struct
  module Parameters = struct
    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 1 (int "page") /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}/assets/links"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("tag_name", Var (params.tag_name, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4ProjectsIdReleasesTagName = struct
  module Parameters = struct
    type t = {
      id : string;
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("tag_name", Var (params.tag_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdReleasesTagName = struct
  module Parameters = struct
    type t = {
      id : string;
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdReleasesTagName.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("tag_name", Var (params.tag_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdReleasesTagName = struct
  module Parameters = struct
    type t = {
      id : string;
      include_html_description : bool option; [@default None]
      tag_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (bool "include_html_description")

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/releases/{tag_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("tag_name", Var (params.tag_name, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("include_html_description", Var (params.include_html_description, Option Bool)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdReleases = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdReleases.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Conflict = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Conflict
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("409", fun _ -> Ok `Conflict);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id}/releases"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
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

module GetApiV4ProjectsIdReleases = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "released_at" -> Ok `Released_at
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Released_at -> `String "released_at"

      type t =
        ([ `Created_at
         | `Released_at
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "asc" -> Ok `Asc
        | `String "desc" -> Ok `Desc
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Asc -> `String "asc"
        | `Desc -> `String "desc"

      type t =
        ([ `Asc
         | `Desc
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      id : string;
      include_html_description : bool option; [@default None]
      order_by : Order_by.t; [@default `Released_at]
      page : int; [@default 1]
      per_page : int; [@default 20]
      sort : Sort.t; [@default `Desc]
      updated_after : string option; [@default None]
      updated_before : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option_default
         `Released_at
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option (bool "include_html_description")
    /? option (string "updated_before")
    /? option (string "updated_after")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/releases"

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
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("order_by", Var (params.order_by, Enum Order_by.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("include_html_description", Var (params.include_html_description, Option Bool));
           ("updated_before", Var (params.updated_before, Option String));
           ("updated_after", Var (params.updated_after, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
