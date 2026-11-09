module GetApiV4ProjectsProjectIdPackagesNugetV2Packages____ = struct
  module Parameters = struct
    type t = {
      filter_ : string; [@key "$filter"]
      project_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "$filter"

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("400", fun _ -> Ok `Bad_request); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{project_id}/packages/nuget/v2/Packages\\(\\)"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("project_id", Var (params.project_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("$filter", Var (params.filter_, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsProjectIdPackagesNugetV2Findpackagesbyid____ = struct
  module Parameters = struct
    type t = {
      id : string;
      project_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "id"

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("400", fun _ -> Ok `Bad_request); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{project_id}/packages/nuget/v2/FindPackagesById\\(\\)"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("project_id", Var (params.project_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesPackageIdPipelines = struct
  module Parameters = struct
    type t = {
      cursor : string option; [@default None]
      id : string;
      package_id : int;
      page : int; [@default 1]
      per_page : int; [@default 20]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option (string "cursor")

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/{package_id}/pipelines"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("package_id", Var (params.package_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("cursor", Var (params.cursor, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4ProjectsIdPackagesPackageIdPackageFilesPackageFileId = struct
  module Parameters = struct
    type t = {
      id : string;
      package_file_id : int;
      package_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/{package_id}/package_files/{package_file_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_id", Var (params.package_id, Int));
           ("package_file_id", Var (params.package_file_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module GetApiV4ProjectsIdPackagesPackageIdPackageFiles = struct
  module Parameters = struct
    type t = {
      id : string;
      package_id : int;
      page : int; [@default 1]
      per_page : int; [@default 20]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 1 (int "page") /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/packages/{package_id}/package_files"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("package_id", Var (params.package_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4ProjectsIdPackagesPackageId = struct
  module Parameters = struct
    type t = {
      id : string;
      package_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/{package_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("package_id", Var (params.package_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module GetApiV4ProjectsIdPackagesPackageId = struct
  module Parameters = struct
    type t = {
      id : string;
      package_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [ ("200", fun _ -> Ok `OK); ("403", fun _ -> Ok `Forbidden); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/api/v4/projects/{id}/packages/{package_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("package_id", Var (params.package_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PutApiV4ProjectsIdPackagesTerraformModulesModuleNameModuleSystem_moduleVersionFileAuthorize =
struct
  module Parameters = struct
    type t = {
      id : string;
      module_name : string;
      module_system : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t =
      Gitlabc_components
      .PutApiV4ProjectsIdPackagesTerraformModulesModuleNameModuleSystem_moduleVersionFileAuthorize
      .t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

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

  let url =
    "/api/v4/projects/{id}/packages/terraform/modules/{module_name}/{module_system}/*module_version/file/authorize"

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
           ("module_name", Var (params.module_name, String));
           ("module_system", Var (params.module_system, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module PutApiV4ProjectsIdPackagesTerraformModulesModuleNameModuleSystem_moduleVersionFile = struct
  module Parameters = struct
    type t = {
      file : string;
      id : string;
      module_name : string;
      module_system : string;
      module_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/terraform/modules/{module_name}/{module_system}/*module_version/file"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("module_name", Var (params.module_name, String));
           ("module_system", Var (params.module_system, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdPackagesTerraformModulesModuleNameModuleSystem_moduleVersion = struct
  module Parameters = struct
    module Terraform_get = struct
      let t_of_yojson = function
        | `String "1" -> Ok `V_1
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `V_1 -> `String "1"

      type t = ([ `V_1 ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson]) [@@deriving show, eq]
    end

    type t = {
      id : string;
      module_name : string;
      module_system : string;
      module_version : string;
      terraform_get : Terraform_get.t option; [@default None] [@key "terraform-get"]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "module_version"
    /? option
         (ud "terraform-get" (fun value ->
              CCResult.to_opt (Parameters.Terraform_get.t_of_yojson (`String value))))

  module Responses = struct
    module No_content = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/terraform/modules/{module_name}/{module_system}/*module_version"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("module_name", Var (params.module_name, String));
           ("module_system", Var (params.module_system, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("module_version", Var (params.module_version, String));
           ("terraform-get", Var (params.terraform_get, Option (Enum Terraform_get.t_to_yojson)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesTerraformModulesModuleNameModuleSystem = struct
  module Parameters = struct
    module Terraform_get = struct
      let t_of_yojson = function
        | `String "1" -> Ok `V_1
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `V_1 -> `String "1"

      type t = ([ `V_1 ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson]) [@@deriving show, eq]
    end

    type t = {
      id : string;
      module_name : string;
      module_system : string;
      terraform_get : Terraform_get.t option; [@default None] [@key "terraform-get"]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "terraform-get" (fun value ->
              CCResult.to_opt (Parameters.Terraform_get.t_of_yojson (`String value))))

  module Responses = struct
    module No_content = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/terraform/modules/{module_name}/{module_system}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("module_name", Var (params.module_name, String));
           ("module_system", Var (params.module_system, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("terraform-get", Var (params.terraform_get, Option (Enum Terraform_get.t_to_yojson))) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesRubygemsFileName = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : int;
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

  let url = "/api/v4/projects/{id}/packages/rubygems/{file_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)); ("file_name", Var (params.file_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesRubygemsQuickMarshal48FileName = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : int;
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

  let url = "/api/v4/projects/{id}/packages/rubygems/quick/Marshal.4.8/{file_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)); ("file_name", Var (params.file_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesRubygemsGemsFileName = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/rubygems/gems/{file_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)); ("file_name", Var (params.file_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdPackagesRubygemsApiV1GemsAuthorize = struct
  module Parameters = struct
    type t = { id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized); ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/rubygems/api/v1/gems/authorize"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsIdPackagesRubygemsApiV1Gems = struct
  module Parameters = struct
    type t = { id : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdPackagesRubygemsApiV1Gems.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/rubygems/api/v1/gems"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdPackagesRubygemsApiV1Dependencies = struct
  module Parameters = struct
    module Gems = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      gems : Gems.t option; [@default None]
      id : int;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (array (string "gems"))

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/rubygems/api/v1/dependencies"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("gems", Var (params.gems, Option (Array String))) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesRpmRepodata_fileName = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "file_name"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/rpm/repodata/*file_name"

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
         [ ("file_name", Var (params.file_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdPackagesRpmAuthorize = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/rpm/authorize"

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

module GetApiV4ProjectsIdPackagesRpm_packageFileId_fileName = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : string;
      package_file_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? int "package_file_id" /? string "file_name"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/rpm/*package_file_id/*file_name"

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
           ("package_file_id", Var (params.package_file_id, Int));
           ("file_name", Var (params.file_name, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdPackagesRpm = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/rpm"

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

module GetApiV4ProjectsIdPackagesPypiSimple_packageName = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/pypi/simple/*package_name"

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
         [ ("package_name", Var (params.package_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesPypiSimple = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/pypi/simple"

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
      `Get
end

module GetApiV4ProjectsIdPackagesPypiFilesSha256_fileIdentifier = struct
  module Parameters = struct
    type t = {
      file_identifier : string;
      id : string;
      sha256 : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "file_identifier"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/pypi/files/{sha256}/*file_identifier"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("sha256", Var (params.sha256, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("file_identifier", Var (params.file_identifier, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdPackagesPypiAuthorize = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/pypi/authorize"

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

module PostApiV4ProjectsIdPackagesPypi = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdPackagesPypi.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
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
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/pypi"

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

module PatchApiV4ProjectsIdPackagesProtectionRulesPackageProtectionRuleId = struct
  module Parameters = struct
    type t = {
      id : string;
      package_protection_rule_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PatchApiV4ProjectsIdPackagesProtectionRulesPackageProtectionRuleId.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/protection/rules/{package_protection_rule_id}"

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
           ("package_protection_rule_id", Var (params.package_protection_rule_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module DeleteApiV4ProjectsIdPackagesProtectionRulesPackageProtectionRuleId = struct
  module Parameters = struct
    type t = {
      id : string;
      package_protection_rule_id : int;
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

  let url = "/api/v4/projects/{id}/packages/protection/rules/{package_protection_rule_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_protection_rule_id", Var (params.package_protection_rule_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PostApiV4ProjectsIdPackagesProtectionRules = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdPackagesProtectionRules.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
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
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/protection/rules"

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

module GetApiV4ProjectsIdPackagesProtectionRules = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/protection/rules"

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
      `Get
end

module PutApiV4ProjectsIdPackagesNugetV2Authorize = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/v2/authorize"

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
      `Put
end

module GetApiV4ProjectsIdPackagesNugetV2_metadata = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/v2/$metadata"

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
      `Get
end

module PutApiV4ProjectsIdPackagesNugetV2 = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPackagesNugetV2.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/v2"

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
      `Put
end

module GetApiV4ProjectsIdPackagesNugetV2 = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Not_found
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/v2"

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
      `Get
end

module PutApiV4ProjectsIdPackagesNugetSymbolpackageAuthorize = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/symbolpackage/authorize"

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
      `Put
end

module PutApiV4ProjectsIdPackagesNugetSymbolpackage = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPackagesNugetSymbolpackage.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/symbolpackage"

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
      `Put
end

module GetApiV4ProjectsIdPackagesNugetSymbolfiles_fileName_signature_sameFileName = struct
  module Parameters = struct
    type t = {
      symbolchecksum : string; [@key "Symbolchecksum"]
      file_name : string;
      id : string;
      same_file_name : string;
      signature : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "file_name" /? string "signature" /? string "same_file_name"

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/symbolfiles/*file_name/*signature/*same_file_name"

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
           ("file_name", Var (params.file_name, String));
           ("signature", Var (params.signature, String));
           ("same_file_name", Var (params.same_file_name, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesNugetQuery = struct
  module Parameters = struct
    type t = {
      id : string;
      prerelease : bool; [@default true]
      q : string option; [@default None]
      skip : int; [@default 0]
      take : int; [@default 20]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "q")
    /? option_default 0 (int "skip")
    /? option_default 20 (int "take")
    /? option_default true (bool "prerelease")

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/query"

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
           ("q", Var (params.q, Option String));
           ("skip", Var (params.skip, Int));
           ("take", Var (params.take, Int));
           ("prerelease", Var (params.prerelease, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesNugetMetadata_packageNameIndex = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/metadata/*package_name/index"

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
         [ ("package_name", Var (params.package_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesNugetMetadata_packageName_packageVersion = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name" /? string "package_version"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/metadata/*package_name/*package_version"

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
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesNugetIndex = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Not_found
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/index"

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
      `Get
end

module GetApiV4ProjectsIdPackagesNugetDownload_packageNameIndex = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/download/*package_name/index"

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
         [ ("package_name", Var (params.package_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesNugetDownload_packageName_packageVersion_packageFilename = struct
  module Parameters = struct
    type t = {
      id : string;
      package_filename : string;
      package_name : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name" /? string "package_version" /? string "package_filename"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/nuget/download/*package_name/*package_version/*package_filename"

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
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_filename", Var (params.package_filename, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module PutApiV4ProjectsIdPackagesNugetAuthorize = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/authorize"

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
      `Put
end

module DeleteApiV4ProjectsIdPackagesNuget_packageName_packageVersion = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name" /? string "package_version"

  module Responses = struct
    module No_content = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget/*package_name/*package_version"

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
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
         ])
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdPackagesNuget = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPackagesNuget.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/nuget"

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
      `Put
end

module PutApiV4ProjectsIdPackagesNpmPackageName = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPackagesNpmPackageName.t
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

  let url = "/api/v4/projects/{id}/packages/npm/{package_name}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("package_name", Var (params.package_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module DeleteApiV4ProjectsIdPackagesNpmPackage_packageNameDistTagsTag = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
      tag : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name"

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

  let url = "/api/v4/projects/{id}/packages/npm/-/package/*package_name/dist-tags/{tag}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("tag", Var (params.tag, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("package_name", Var (params.package_name, String)) ])
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdPackagesNpmPackage_packageNameDistTagsTag = struct
  module Parameters = struct
    type t = {
      id : string;
      tag : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPackagesNpmPackage_packageNameDistTagsTag.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
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

  let url = "/api/v4/projects/{id}/packages/npm/-/package/*package_name/dist-tags/{tag}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("tag", Var (params.tag, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdPackagesNpmPackage_packageNameDistTags = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name"

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

  let url = "/api/v4/projects/{id}/packages/npm/-/package/*package_name/dist-tags"

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
         [ ("package_name", Var (params.package_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdPackagesNpmNpmV1SecurityAuditsQuick = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Temporary_redirect = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Temporary_redirect
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("307", fun _ -> Ok `Temporary_redirect);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/npm/-/npm/v1/security/audits/quick"

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

module PostApiV4ProjectsIdPackagesNpmNpmV1SecurityAdvisoriesBulk = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Temporary_redirect = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Temporary_redirect
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("307", fun _ -> Ok `Temporary_redirect);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/npm/-/npm/v1/security/advisories/bulk"

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

module GetApiV4ProjectsIdPackagesNpm_packageName__fileName = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : string;
      package_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name" /? string "file_name"

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [ ("200", fun _ -> Ok `OK); ("403", fun _ -> Ok `Forbidden); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/api/v4/projects/{id}/packages/npm/*package_name/-/*file_name"

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
           ("package_name", Var (params.package_name, String));
           ("file_name", Var (params.file_name, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesNpm_packageName = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "package_name"

  module Responses = struct
    module OK = struct end
    module Found = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Found
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("302", fun _ -> Ok `Found);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/npm/*package_name"

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
         [ ("package_name", Var (params.package_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module PutApiV4ProjectsIdPackagesMaven_pathFileNameAuthorize = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPackagesMaven_pathFileNameAuthorize.t
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

  let url = "/api/v4/projects/{id}/packages/maven/*path/{file_name}/authorize"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("file_name", Var (params.file_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module PutApiV4ProjectsIdPackagesMaven_pathFileName = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPackagesMaven_pathFileName.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/maven/*path/{file_name}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("file_name", Var (params.file_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdPackagesMaven_pathFileName = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : string;
      path : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "path"

  module Responses = struct
    module OK = struct end
    module Found = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Found
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("302", fun _ -> Ok `Found);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/maven/*path/{file_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("file_name", Var (params.file_name, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("path", Var (params.path, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesHelmChannelIndexYaml = struct
  module Parameters = struct
    type t = {
      channel : string;
      id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized); ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/helm/{channel}/index.yaml"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)); ("channel", Var (params.channel, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesHelmChannelChartsFileNameTgz = struct
  module Parameters = struct
    type t = {
      channel : string;
      file_name : string;
      id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/helm/{channel}/charts/{file_name}.tgz"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, Int));
           ("channel", Var (params.channel, String));
           ("file_name", Var (params.file_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdPackagesHelmApiChannelChartsAuthorize = struct
  module Parameters = struct
    type t = {
      channel : string;
      id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/helm/api/{channel}/charts/authorize"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)); ("channel", Var (params.channel, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsIdPackagesHelmApiChannelCharts = struct
  module Parameters = struct
    type t = {
      channel : string;
      id : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdPackagesHelmApiChannelCharts.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/helm/api/{channel}/charts"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)); ("channel", Var (params.channel, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdPackagesGo_moduleName_vModuleVersionZip = struct
  module Parameters = struct
    type t = {
      id : string;
      module_name : string;
      module_version : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "module_name"

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/packages/go/*module_name/@v/{module_version}.zip"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String)); ("module_version", Var (params.module_version, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("module_name", Var (params.module_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesGo_moduleName_vModuleVersionMod = struct
  module Parameters = struct
    type t = {
      id : string;
      module_name : string;
      module_version : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "module_name"

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/packages/go/*module_name/@v/{module_version}.mod"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String)); ("module_version", Var (params.module_version, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("module_name", Var (params.module_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesGo_moduleName_vModuleVersionInfo = struct
  module Parameters = struct
    type t = {
      id : string;
      module_name : string;
      module_version : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "module_name"

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/packages/go/*module_name/@v/{module_version}.info"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String)); ("module_version", Var (params.module_version, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("module_name", Var (params.module_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesGo_moduleName_vList = struct
  module Parameters = struct
    type t = {
      id : string;
      module_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "module_name"

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/packages/go/*module_name/@v/list"

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
         [ ("module_name", Var (params.module_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module PutApiV4ProjectsIdPackagesDebianFileNameAuthorize = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPackagesDebianFileNameAuthorize.t
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

  let url = "/api/v4/projects/{id}/packages/debian/{file_name}/authorize"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("file_name", Var (params.file_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module PutApiV4ProjectsIdPackagesDebianFileName = struct
  module Parameters = struct
    type t = {
      file_name : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPackagesDebianFileName.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/debian/{file_name}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("file_name", Var (params.file_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdPackagesDebianPoolDistributionLetterPackageNamePackageVersionFileName =
struct
  module Parameters = struct
    type t = {
      distribution : string;
      file_name : string;
      id : string;
      letter : string;
      package_name : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/debian/pool/{distribution}/{letter}/{package_name}/{package_version}/{file_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("distribution", Var (params.distribution, String));
           ("letter", Var (params.letter, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("file_name", Var (params.file_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesDebianDists_distributionComponentSourceByHashSha256FileSha256 =
struct
  module Parameters = struct
    type t = {
      component : string;
      distribution : string;
      file_sha256 : int;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "distribution"

  module Responses = struct
    module OK = struct end
    module Accepted = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Accepted
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("202", fun _ -> Ok `Accepted);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/debian/dists/*distribution/{component}/source/by-hash/SHA256/{file_sha256}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("component", Var (params.component, String));
           ("file_sha256", Var (params.file_sha256, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("distribution", Var (params.distribution, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesDebianDists_distributionComponentSourceSources = struct
  module Parameters = struct
    type t = {
      component : string;
      distribution : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "distribution"

  module Responses = struct
    module OK = struct end
    module Accepted = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Accepted
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("202", fun _ -> Ok `Accepted);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/debian/dists/*distribution/{component}/source/Sources"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("component", Var (params.component, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("distribution", Var (params.distribution, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module
  GetApiV4ProjectsIdPackagesDebianDists_distributionComponentDebianInstallerBinaryArchitectureByHashSha256FileSha256 =
struct
  module Parameters = struct
    type t = {
      architecture : string;
      component : string;
      distribution : string;
      file_sha256 : int;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "distribution"

  module Responses = struct
    module OK = struct end
    module Accepted = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Accepted
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("202", fun _ -> Ok `Accepted);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/debian/dists/*distribution/{component}/debian-installer/binary-{architecture}/by-hash/SHA256/{file_sha256}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("component", Var (params.component, String));
           ("architecture", Var (params.architecture, String));
           ("file_sha256", Var (params.file_sha256, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("distribution", Var (params.distribution, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module
  GetApiV4ProjectsIdPackagesDebianDists_distributionComponentDebianInstallerBinaryArchitecturePackages =
struct
  module Parameters = struct
    type t = {
      architecture : string;
      component : string;
      distribution : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "distribution"

  module Responses = struct
    module OK = struct end
    module Accepted = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Accepted
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("202", fun _ -> Ok `Accepted);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/debian/dists/*distribution/{component}/debian-installer/binary-{architecture}/Packages"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("component", Var (params.component, String));
           ("architecture", Var (params.architecture, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("distribution", Var (params.distribution, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module
  GetApiV4ProjectsIdPackagesDebianDists_distributionComponentBinaryArchitectureByHashSha256FileSha256 =
struct
  module Parameters = struct
    type t = {
      architecture : string;
      component : string;
      distribution : string;
      file_sha256 : int;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "distribution"

  module Responses = struct
    module OK = struct end
    module Accepted = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Accepted
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("202", fun _ -> Ok `Accepted);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/debian/dists/*distribution/{component}/binary-{architecture}/by-hash/SHA256/{file_sha256}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("component", Var (params.component, String));
           ("architecture", Var (params.architecture, String));
           ("file_sha256", Var (params.file_sha256, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("distribution", Var (params.distribution, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesDebianDists_distributionComponentBinary_ArchitecturePackages =
struct
  module Parameters = struct
    type t = {
      architecture : string;
      component : string;
      distribution : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "distribution"

  module Responses = struct
    module OK = struct end
    module Accepted = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Accepted
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("202", fun _ -> Ok `Accepted);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/debian/dists/*distribution/{component}/binary-{architecture}/Packages"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("component", Var (params.component, String));
           ("architecture", Var (params.architecture, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("distribution", Var (params.distribution, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesDebianDists_distributionReleaseGpg = struct
  module Parameters = struct
    type t = {
      distribution : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "distribution"

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

  let url = "/api/v4/projects/{id}/packages/debian/dists/*distribution/Release.gpg"

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
         [ ("distribution", Var (params.distribution, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesDebianDists_distributionRelease = struct
  module Parameters = struct
    type t = {
      distribution : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "distribution"

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

  let url = "/api/v4/projects/{id}/packages/debian/dists/*distribution/Release"

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
         [ ("distribution", Var (params.distribution, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesDebianDists_distributionInrelease = struct
  module Parameters = struct
    type t = {
      distribution : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "distribution"

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

  let url = "/api/v4/projects/{id}/packages/debian/dists/*distribution/InRelease"

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
         [ ("distribution", Var (params.distribution, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesConanV2UsersCheckCredentials = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
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

  let url = "/api/v4/projects/{id}/packages/conan/v2/users/check_credentials"

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
      `Get
end

module
  GetApiV4ProjectsIdPackagesConanV2ConansPackageNamePackageVersionPackageUsernamePackageChannelRevisionsRecipeRevisionFilesFileName =
struct
  module Parameters = struct
    module File_name = struct
      let t_of_yojson = function
        | `String "conan_export.tgz" -> Ok `Conan_export_tgz
        | `String "conan_package.tgz" -> Ok `Conan_package_tgz
        | `String "conan_sources.tgz" -> Ok `Conan_sources_tgz
        | `String "conanfile.py" -> Ok `Conanfile_py
        | `String "conaninfo.txt" -> Ok `Conaninfo_txt
        | `String "conanmanifest.txt" -> Ok `Conanmanifest_txt
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Conan_export_tgz -> `String "conan_export.tgz"
        | `Conan_package_tgz -> `String "conan_package.tgz"
        | `Conan_sources_tgz -> `String "conan_sources.tgz"
        | `Conanfile_py -> `String "conanfile.py"
        | `Conaninfo_txt -> `String "conaninfo.txt"
        | `Conanmanifest_txt -> `String "conanmanifest.txt"

      type t =
        ([ `Conan_export_tgz
         | `Conan_package_tgz
         | `Conan_sources_tgz
         | `Conanfile_py
         | `Conaninfo_txt
         | `Conanmanifest_txt
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      file_name : File_name.t;
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
      recipe_revision : string;
    }
    [@@deriving make, show, eq]
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

  let url =
    "/api/v4/projects/{id}/packages/conan/v2/conans/{package_name}/{package_version}/{package_username}/{package_channel}/revisions/{recipe_revision}/files/{file_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("recipe_revision", Var (params.recipe_revision, String));
           ("file_name", Var (params.file_name, Enum File_name.t_to_yojson));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesConanV2ConansSearch = struct
  module Parameters = struct
    type t = {
      id : string;
      q : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "q"

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("400", fun _ -> Ok `Bad_request); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/conan/v2/conans/search"

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
         [ ("q", Var (params.q, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesConanV1UsersCheckCredentials = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
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

  let url = "/api/v4/projects/{id}/packages/conan/v1/users/check_credentials"

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
      `Get
end

module GetApiV4ProjectsIdPackagesConanV1UsersAuthenticate = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
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

  let url = "/api/v4/projects/{id}/packages/conan/v1/users/authenticate"

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
      `Get
end

module GetApiV4ProjectsIdPackagesConanV1Ping = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Not_found
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/api/v4/projects/{id}/packages/conan/v1/ping"

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
      `Get
end

module
  PutApiV4ProjectsIdPackagesConanV1FilesPackageNamePackageVersionPackageUsernamePackageChannelRecipeRevisionPackageConanPackageReferencePackageRevisionFileNameAuthorize =
struct
  module Parameters = struct
    module File_name = struct
      let t_of_yojson = function
        | `String "conan_export.tgz" -> Ok `Conan_export_tgz
        | `String "conan_package.tgz" -> Ok `Conan_package_tgz
        | `String "conan_sources.tgz" -> Ok `Conan_sources_tgz
        | `String "conanfile.py" -> Ok `Conanfile_py
        | `String "conaninfo.txt" -> Ok `Conaninfo_txt
        | `String "conanmanifest.txt" -> Ok `Conanmanifest_txt
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Conan_export_tgz -> `String "conan_export.tgz"
        | `Conan_package_tgz -> `String "conan_package.tgz"
        | `Conan_sources_tgz -> `String "conan_sources.tgz"
        | `Conanfile_py -> `String "conanfile.py"
        | `Conaninfo_txt -> `String "conaninfo.txt"
        | `Conanmanifest_txt -> `String "conanmanifest.txt"

      type t =
        ([ `Conan_export_tgz
         | `Conan_package_tgz
         | `Conan_sources_tgz
         | `Conanfile_py
         | `Conaninfo_txt
         | `Conanmanifest_txt
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      conan_package_reference : string;
      file_name : File_name.t;
      id : string;
      package_channel : string;
      package_name : string;
      package_revision : string;
      package_username : string;
      package_version : string;
      recipe_revision : string;
    }
    [@@deriving make, show, eq]
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

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/files/{package_name}/{package_version}/{package_username}/{package_channel}/{recipe_revision}/package/{conan_package_reference}/{package_revision}/{file_name}/authorize"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("recipe_revision", Var (params.recipe_revision, String));
           ("conan_package_reference", Var (params.conan_package_reference, String));
           ("package_revision", Var (params.package_revision, String));
           ("file_name", Var (params.file_name, Enum File_name.t_to_yojson));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module
  PutApiV4ProjectsIdPackagesConanV1FilesPackageNamePackageVersionPackageUsernamePackageChannelRecipeRevisionPackageConanPackageReferencePackageRevisionFileName =
struct
  module Parameters = struct
    module File_name = struct
      let t_of_yojson = function
        | `String "conan_export.tgz" -> Ok `Conan_export_tgz
        | `String "conan_package.tgz" -> Ok `Conan_package_tgz
        | `String "conan_sources.tgz" -> Ok `Conan_sources_tgz
        | `String "conanfile.py" -> Ok `Conanfile_py
        | `String "conaninfo.txt" -> Ok `Conaninfo_txt
        | `String "conanmanifest.txt" -> Ok `Conanmanifest_txt
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Conan_export_tgz -> `String "conan_export.tgz"
        | `Conan_package_tgz -> `String "conan_package.tgz"
        | `Conan_sources_tgz -> `String "conan_sources.tgz"
        | `Conanfile_py -> `String "conanfile.py"
        | `Conaninfo_txt -> `String "conaninfo.txt"
        | `Conanmanifest_txt -> `String "conanmanifest.txt"

      type t =
        ([ `Conan_export_tgz
         | `Conan_package_tgz
         | `Conan_sources_tgz
         | `Conanfile_py
         | `Conaninfo_txt
         | `Conanmanifest_txt
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      conan_package_reference : string;
      file_name : File_name.t;
      id : string;
      package_channel : string;
      package_name : string;
      package_revision : string;
      package_username : string;
      package_version : string;
      recipe_revision : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t =
      Gitlabc_components
      .PutApiV4ProjectsIdPackagesConanV1FilesPackageNamePackageVersionPackageUsernamePackageChannelRecipeRevisionPackageConanPackageReferencePackageRevisionFileName
      .t
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

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/files/{package_name}/{package_version}/{package_username}/{package_channel}/{recipe_revision}/package/{conan_package_reference}/{package_revision}/{file_name}"

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
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("recipe_revision", Var (params.recipe_revision, String));
           ("conan_package_reference", Var (params.conan_package_reference, String));
           ("package_revision", Var (params.package_revision, String));
           ("file_name", Var (params.file_name, Enum File_name.t_to_yojson));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module
  GetApiV4ProjectsIdPackagesConanV1FilesPackageNamePackageVersionPackageUsernamePackageChannelRecipeRevisionPackageConanPackageReferencePackageRevisionFileName =
struct
  module Parameters = struct
    module File_name = struct
      let t_of_yojson = function
        | `String "conan_export.tgz" -> Ok `Conan_export_tgz
        | `String "conan_package.tgz" -> Ok `Conan_package_tgz
        | `String "conan_sources.tgz" -> Ok `Conan_sources_tgz
        | `String "conanfile.py" -> Ok `Conanfile_py
        | `String "conaninfo.txt" -> Ok `Conaninfo_txt
        | `String "conanmanifest.txt" -> Ok `Conanmanifest_txt
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Conan_export_tgz -> `String "conan_export.tgz"
        | `Conan_package_tgz -> `String "conan_package.tgz"
        | `Conan_sources_tgz -> `String "conan_sources.tgz"
        | `Conanfile_py -> `String "conanfile.py"
        | `Conaninfo_txt -> `String "conaninfo.txt"
        | `Conanmanifest_txt -> `String "conanmanifest.txt"

      type t =
        ([ `Conan_export_tgz
         | `Conan_package_tgz
         | `Conan_sources_tgz
         | `Conanfile_py
         | `Conaninfo_txt
         | `Conanmanifest_txt
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      conan_package_reference : string;
      file_name : File_name.t;
      id : string;
      package_channel : string;
      package_name : string;
      package_revision : string;
      package_username : string;
      package_version : string;
      recipe_revision : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [ ("200", fun _ -> Ok `OK); ("403", fun _ -> Ok `Forbidden); ("404", fun _ -> Ok `Not_found) ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/files/{package_name}/{package_version}/{package_username}/{package_channel}/{recipe_revision}/package/{conan_package_reference}/{package_revision}/{file_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("recipe_revision", Var (params.recipe_revision, String));
           ("conan_package_reference", Var (params.conan_package_reference, String));
           ("package_revision", Var (params.package_revision, String));
           ("file_name", Var (params.file_name, Enum File_name.t_to_yojson));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module
  PutApiV4ProjectsIdPackagesConanV1FilesPackageNamePackageVersionPackageUsernamePackageChannelRecipeRevisionExportFileNameAuthorize =
struct
  module Parameters = struct
    module File_name = struct
      let t_of_yojson = function
        | `String "conan_export.tgz" -> Ok `Conan_export_tgz
        | `String "conan_package.tgz" -> Ok `Conan_package_tgz
        | `String "conan_sources.tgz" -> Ok `Conan_sources_tgz
        | `String "conanfile.py" -> Ok `Conanfile_py
        | `String "conaninfo.txt" -> Ok `Conaninfo_txt
        | `String "conanmanifest.txt" -> Ok `Conanmanifest_txt
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Conan_export_tgz -> `String "conan_export.tgz"
        | `Conan_package_tgz -> `String "conan_package.tgz"
        | `Conan_sources_tgz -> `String "conan_sources.tgz"
        | `Conanfile_py -> `String "conanfile.py"
        | `Conaninfo_txt -> `String "conaninfo.txt"
        | `Conanmanifest_txt -> `String "conanmanifest.txt"

      type t =
        ([ `Conan_export_tgz
         | `Conan_package_tgz
         | `Conan_sources_tgz
         | `Conanfile_py
         | `Conaninfo_txt
         | `Conanmanifest_txt
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      file_name : File_name.t;
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
      recipe_revision : string;
    }
    [@@deriving make, show, eq]
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

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/files/{package_name}/{package_version}/{package_username}/{package_channel}/{recipe_revision}/export/{file_name}/authorize"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("recipe_revision", Var (params.recipe_revision, String));
           ("file_name", Var (params.file_name, Enum File_name.t_to_yojson));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module
  PutApiV4ProjectsIdPackagesConanV1FilesPackageNamePackageVersionPackageUsernamePackageChannelRecipeRevisionExportFileName =
struct
  module Parameters = struct
    module File_name = struct
      let t_of_yojson = function
        | `String "conan_export.tgz" -> Ok `Conan_export_tgz
        | `String "conan_package.tgz" -> Ok `Conan_package_tgz
        | `String "conan_sources.tgz" -> Ok `Conan_sources_tgz
        | `String "conanfile.py" -> Ok `Conanfile_py
        | `String "conaninfo.txt" -> Ok `Conaninfo_txt
        | `String "conanmanifest.txt" -> Ok `Conanmanifest_txt
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Conan_export_tgz -> `String "conan_export.tgz"
        | `Conan_package_tgz -> `String "conan_package.tgz"
        | `Conan_sources_tgz -> `String "conan_sources.tgz"
        | `Conanfile_py -> `String "conanfile.py"
        | `Conaninfo_txt -> `String "conaninfo.txt"
        | `Conanmanifest_txt -> `String "conanmanifest.txt"

      type t =
        ([ `Conan_export_tgz
         | `Conan_package_tgz
         | `Conan_sources_tgz
         | `Conanfile_py
         | `Conaninfo_txt
         | `Conanmanifest_txt
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      file_name : File_name.t;
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
      recipe_revision : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t =
      Gitlabc_components
      .PutApiV4ProjectsIdPackagesConanV1FilesPackageNamePackageVersionPackageUsernamePackageChannelRecipeRevisionExportFileName
      .t
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

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/files/{package_name}/{package_version}/{package_username}/{package_channel}/{recipe_revision}/export/{file_name}"

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
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("recipe_revision", Var (params.recipe_revision, String));
           ("file_name", Var (params.file_name, Enum File_name.t_to_yojson));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module
  GetApiV4ProjectsIdPackagesConanV1FilesPackageNamePackageVersionPackageUsernamePackageChannelRecipeRevisionExportFileName =
struct
  module Parameters = struct
    module File_name = struct
      let t_of_yojson = function
        | `String "conan_export.tgz" -> Ok `Conan_export_tgz
        | `String "conan_package.tgz" -> Ok `Conan_package_tgz
        | `String "conan_sources.tgz" -> Ok `Conan_sources_tgz
        | `String "conanfile.py" -> Ok `Conanfile_py
        | `String "conaninfo.txt" -> Ok `Conaninfo_txt
        | `String "conanmanifest.txt" -> Ok `Conanmanifest_txt
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Conan_export_tgz -> `String "conan_export.tgz"
        | `Conan_package_tgz -> `String "conan_package.tgz"
        | `Conan_sources_tgz -> `String "conan_sources.tgz"
        | `Conanfile_py -> `String "conanfile.py"
        | `Conaninfo_txt -> `String "conaninfo.txt"
        | `Conanmanifest_txt -> `String "conanmanifest.txt"

      type t =
        ([ `Conan_export_tgz
         | `Conan_package_tgz
         | `Conan_sources_tgz
         | `Conanfile_py
         | `Conaninfo_txt
         | `Conanmanifest_txt
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      file_name : File_name.t;
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
      recipe_revision : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/files/{package_name}/{package_version}/{package_username}/{package_channel}/{recipe_revision}/export/{file_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("recipe_revision", Var (params.recipe_revision, String));
           ("file_name", Var (params.file_name, Enum File_name.t_to_yojson));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module
  PostApiV4ProjectsIdPackagesConanV1ConansPackageNamePackageVersionPackageUsernamePackageChannelUploadUrls =
struct
  module Parameters = struct
    type t = {
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/conans/{package_name}/{package_version}/{package_username}/{package_channel}/upload_urls"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module
  PostApiV4ProjectsIdPackagesConanV1ConansPackageNamePackageVersionPackageUsernamePackageChannelPackagesConanPackageReferenceUploadUrls =
struct
  module Parameters = struct
    type t = {
      conan_package_reference : string;
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/conans/{package_name}/{package_version}/{package_username}/{package_channel}/packages/{conan_package_reference}/upload_urls"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("conan_package_reference", Var (params.conan_package_reference, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module
  GetApiV4ProjectsIdPackagesConanV1ConansPackageNamePackageVersionPackageUsernamePackageChannelPackagesConanPackageReferenceDownloadUrls =
struct
  module Parameters = struct
    type t = {
      conan_package_reference : string;
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/conans/{package_name}/{package_version}/{package_username}/{package_channel}/packages/{conan_package_reference}/download_urls"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("conan_package_reference", Var (params.conan_package_reference, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module
  GetApiV4ProjectsIdPackagesConanV1ConansPackageNamePackageVersionPackageUsernamePackageChannelPackagesConanPackageReferenceDigest =
struct
  module Parameters = struct
    type t = {
      conan_package_reference : string;
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/conans/{package_name}/{package_version}/{package_username}/{package_channel}/packages/{conan_package_reference}/digest"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("conan_package_reference", Var (params.conan_package_reference, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module
  GetApiV4ProjectsIdPackagesConanV1ConansPackageNamePackageVersionPackageUsernamePackageChannelPackagesConanPackageReference =
struct
  module Parameters = struct
    type t = {
      conan_package_reference : string;
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/conans/{package_name}/{package_version}/{package_username}/{package_channel}/packages/{conan_package_reference}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
           ("conan_package_reference", Var (params.conan_package_reference, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module
  GetApiV4ProjectsIdPackagesConanV1ConansPackageNamePackageVersionPackageUsernamePackageChannelDownloadUrls =
struct
  module Parameters = struct
    type t = {
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/conans/{package_name}/{package_version}/{package_username}/{package_channel}/download_urls"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module
  GetApiV4ProjectsIdPackagesConanV1ConansPackageNamePackageVersionPackageUsernamePackageChannelDigest =
struct
  module Parameters = struct
    type t = {
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/conans/{package_name}/{package_version}/{package_username}/{package_channel}/digest"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module
  DeleteApiV4ProjectsIdPackagesConanV1ConansPackageNamePackageVersionPackageUsernamePackageChannel =
struct
  module Parameters = struct
    type t = {
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/conans/{package_name}/{package_version}/{package_username}/{package_channel}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module GetApiV4ProjectsIdPackagesConanV1ConansPackageNamePackageVersionPackageUsernamePackageChannel =
struct
  module Parameters = struct
    type t = {
      id : string;
      package_channel : string;
      package_name : string;
      package_username : string;
      package_version : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v4/projects/{id}/packages/conan/v1/conans/{package_name}/{package_version}/{package_username}/{package_channel}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("package_name", Var (params.package_name, String));
           ("package_version", Var (params.package_version, String));
           ("package_username", Var (params.package_username, String));
           ("package_channel", Var (params.package_channel, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesConanV1ConansSearch = struct
  module Parameters = struct
    type t = {
      id : string;
      q : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "q"

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("400", fun _ -> Ok `Bad_request); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/conan/v1/conans/search"

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
         [ ("q", Var (params.q, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPackagesComposerArchives_packageName = struct
  module Parameters = struct
    type t = {
      id : string;
      package_name : string;
      sha : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "sha" /? string "package_name"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/composer/archives/*package_name"

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
         [ ("sha", Var (params.sha, String)); ("package_name", Var (params.package_name, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdPackagesComposer = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdPackagesComposer.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/packages/composer"

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

module GetApiV4ProjectsIdPackages = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "name" -> Ok `Name
        | `String "type" -> Ok `Type
        | `String "version" -> Ok `Version
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Name -> `String "name"
        | `Type -> `String "type"
        | `Version -> `String "version"

      type t =
        ([ `Created_at
         | `Name
         | `Type
         | `Version
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Package_type = struct
      let t_of_yojson = function
        | `String "composer" -> Ok `Composer
        | `String "conan" -> Ok `Conan
        | `String "debian" -> Ok `Debian
        | `String "generic" -> Ok `Generic
        | `String "golang" -> Ok `Golang
        | `String "helm" -> Ok `Helm
        | `String "maven" -> Ok `Maven
        | `String "ml_model" -> Ok `Ml_model
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "pypi" -> Ok `Pypi
        | `String "rpm" -> Ok `Rpm
        | `String "rubygems" -> Ok `Rubygems
        | `String "terraform_module" -> Ok `Terraform_module
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Composer -> `String "composer"
        | `Conan -> `String "conan"
        | `Debian -> `String "debian"
        | `Generic -> `String "generic"
        | `Golang -> `String "golang"
        | `Helm -> `String "helm"
        | `Maven -> `String "maven"
        | `Ml_model -> `String "ml_model"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Pypi -> `String "pypi"
        | `Rpm -> `String "rpm"
        | `Rubygems -> `String "rubygems"
        | `Terraform_module -> `String "terraform_module"

      type t =
        ([ `Composer
         | `Conan
         | `Debian
         | `Generic
         | `Golang
         | `Helm
         | `Maven
         | `Ml_model
         | `Npm
         | `Nuget
         | `Pypi
         | `Rpm
         | `Rubygems
         | `Terraform_module
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

    module Status = struct
      let t_of_yojson = function
        | `String "default" -> Ok `Default
        | `String "deprecated" -> Ok `Deprecated
        | `String "error" -> Ok `Error
        | `String "hidden" -> Ok `Hidden
        | `String "pending_destruction" -> Ok `Pending_destruction
        | `String "processing" -> Ok `Processing
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Default -> `String "default"
        | `Deprecated -> `String "deprecated"
        | `Error -> `String "error"
        | `Hidden -> `String "hidden"
        | `Pending_destruction -> `String "pending_destruction"
        | `Processing -> `String "processing"

      type t =
        ([ `Default
         | `Deprecated
         | `Error
         | `Hidden
         | `Pending_destruction
         | `Processing
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      id : string;
      include_versionless : bool option; [@default None]
      order_by : Order_by.t; [@default `Created_at]
      package_name : string option; [@default None]
      package_type : Package_type.t option; [@default None]
      package_version : string option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 20]
      sort : Sort.t; [@default `Asc]
      status : Status.t option; [@default None]
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
         `Created_at
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option_default
         `Asc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option
         (ud "package_type" (fun value ->
              CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value))))
    /? option (string "package_name")
    /? option (string "package_version")
    /? option (bool "include_versionless")
    /? option
         (ud "status" (fun value -> CCResult.to_opt (Parameters.Status.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [ ("200", fun _ -> Ok `OK); ("403", fun _ -> Ok `Forbidden); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/api/v4/projects/{id}/packages"

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
           ("package_type", Var (params.package_type, Option (Enum Package_type.t_to_yojson)));
           ("package_name", Var (params.package_name, Option String));
           ("package_version", Var (params.package_version, Option String));
           ("include_versionless", Var (params.include_versionless, Option Bool));
           ("status", Var (params.status, Option (Enum Status.t_to_yojson)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
