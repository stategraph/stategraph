module GetApiV4ProjectsIdTemplatesTypeName = struct
  module Parameters = struct
    module Type = struct
      let t_of_yojson = function
        | `String "dockerfiles" -> Ok `Dockerfiles
        | `String "gitignores" -> Ok `Gitignores
        | `String "gitlab_ci_ymls" -> Ok `Gitlab_ci_ymls
        | `String "issues" -> Ok `Issues
        | `String "licenses" -> Ok `Licenses
        | `String "merge_requests" -> Ok `Merge_requests
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Dockerfiles -> `String "dockerfiles"
        | `Gitignores -> `String "gitignores"
        | `Gitlab_ci_ymls -> `String "gitlab_ci_ymls"
        | `Issues -> `String "issues"
        | `Licenses -> `String "licenses"
        | `Merge_requests -> `String "merge_requests"

      type t =
        ([ `Dockerfiles
         | `Gitignores
         | `Gitlab_ci_ymls
         | `Issues
         | `Licenses
         | `Merge_requests
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      fullname : string option; [@default None]
      id : string;
      name : string;
      project : string option; [@default None]
      source_template_project_id : int option; [@default None]
      type_ : Type.t; [@key "type"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "templates"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Type.t_of_yojson (`String value)))
    /% Path.string
    /? option (int "source_template_project_id")
    /? option (string "project")
    /? option (string "fullname")

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

  let url = "/api/v4/projects/{id}/templates/{type}/{name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("type", Var (params.type_, Enum Type.t_to_yojson));
           ("name", Var (params.name, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("source_template_project_id", Var (params.source_template_project_id, Option Int));
           ("project", Var (params.project, Option String));
           ("fullname", Var (params.fullname, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdTemplatesType = struct
  module Parameters = struct
    module Type = struct
      let t_of_yojson = function
        | `String "dockerfiles" -> Ok `Dockerfiles
        | `String "gitignores" -> Ok `Gitignores
        | `String "gitlab_ci_ymls" -> Ok `Gitlab_ci_ymls
        | `String "issues" -> Ok `Issues
        | `String "licenses" -> Ok `Licenses
        | `String "merge_requests" -> Ok `Merge_requests
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Dockerfiles -> `String "dockerfiles"
        | `Gitignores -> `String "gitignores"
        | `Gitlab_ci_ymls -> `String "gitlab_ci_ymls"
        | `Issues -> `String "issues"
        | `Licenses -> `String "licenses"
        | `Merge_requests -> `String "merge_requests"

      type t =
        ([ `Dockerfiles
         | `Gitignores
         | `Gitlab_ci_ymls
         | `Issues
         | `Licenses
         | `Merge_requests
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      type_ : Type.t; [@key "type"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "templates"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Type.t_of_yojson (`String value)))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

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

  let url = "/api/v4/projects/{id}/templates/{type}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("type", Var (params.type_, Enum Type.t_to_yojson)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end
