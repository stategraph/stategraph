module GetApiV4GroupsIdPackages = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "name" -> Ok `Name
        | `String "project_path" -> Ok `Project_path
        | `String "type" -> Ok `Type
        | `String "version" -> Ok `Version
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Name -> `String "name"
        | `Project_path -> `String "project_path"
        | `Type -> `String "type"
        | `Version -> `String "version"

      type t =
        ([ `Created_at
         | `Name
         | `Project_path
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
      exclude_subgroups : bool; [@default false]
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

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "groups"
    /% Path.string
    / "packages"
    /? option_default false (bool "exclude_subgroups")
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

  let url = "/api/v4/groups/{id}/packages"

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
           ("exclude_subgroups", Var (params.exclude_subgroups, Bool));
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
