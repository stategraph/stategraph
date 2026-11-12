module Restore_package_version_for_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      package_version_id : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /% Path.int
    / "restore"

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url =
    "/users/{username}/packages/{package_type}/{package_name}/versions/{package_version_id}/restore"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("username", Var (params.username, String));
           ("package_version_id", Var (params.package_version_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Delete_package_version_for_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      package_version_id : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /% Path.int

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/users/{username}/packages/{package_type}/{package_name}/versions/{package_version_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("username", Var (params.username, String));
           ("package_version_id", Var (params.package_version_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_package_version_for_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      package_version_id : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package_version.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/users/{username}/packages/{package_type}/{package_name}/versions/{package_version_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("package_version_id", Var (params.package_version_id, Int));
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_all_package_versions_for_package_owned_by_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package_version.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/users/{username}/packages/{package_type}/{package_name}/versions"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Restore_package_for_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      token : string option; [@default None]
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "restore"
    /? option (string "token")

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/users/{username}/packages/{package_type}/{package_name}/restore"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("username", Var (params.username, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("token", Var (params.token, Option String)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module Delete_package_for_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/users/{username}/packages/{package_type}/{package_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_package_for_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/users/{username}/packages/{package_type}/{package_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_packages_for_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Visibility = struct
      let t_of_yojson = function
        | `String "internal" -> Ok `Internal
        | `String "private" -> Ok `Private
        | `String "public" -> Ok `Public
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Internal -> `String "internal"
        | `Private -> `String "private"
        | `Public -> `String "public"

      type t =
        ([ `Internal
         | `Private
         | `Public
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_type : Package_type.t;
      page : int; [@default 1]
      per_page : int; [@default 30]
      username : string;
      visibility : Visibility.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "packages"
    /? ud "package_type" (fun value ->
        CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /? option
         (ud "visibility" (fun value ->
              CCResult.to_opt (Parameters.Visibility.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/packages"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("username", Var (params.username, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("visibility", Var (params.visibility, Option (Enum Visibility.t_to_yojson)));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_docker_migration_conflicting_packages_for_user = struct
  module Parameters = struct
    type t = { username : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "docker" / "conflicts"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/docker/conflicts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("username", Var (params.username, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Restore_package_version_for_authenticated_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      package_version_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /% Path.int
    / "restore"

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/packages/{package_type}/{package_name}/versions/{package_version_id}/restore"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("package_version_id", Var (params.package_version_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Delete_package_version_for_authenticated_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      package_version_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /% Path.int

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/packages/{package_type}/{package_name}/versions/{package_version_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("package_version_id", Var (params.package_version_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_package_version_for_authenticated_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      package_version_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package_version.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/user/packages/{package_type}/{package_name}/versions/{package_version_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("package_version_id", Var (params.package_version_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_all_package_versions_for_package_owned_by_authenticated_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "active" -> Ok `Active
        | `String "deleted" -> Ok `Deleted
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Active -> `String "active"
        | `Deleted -> `String "deleted"

      type t =
        ([ `Active
         | `Deleted
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      page : int; [@default 1]
      per_page : int; [@default 30]
      state : State.t; [@default `Active]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")
    /? option_default
         `Active
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package_version.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/packages/{package_type}/{package_name}/versions"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("state", Var (params.state, Enum State.t_to_yojson));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Restore_package_for_authenticated_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
      token : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "restore"
    /? option (string "token")

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/packages/{package_type}/{package_name}/restore"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("token", Var (params.token, Option String)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module Delete_package_for_authenticated_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/packages/{package_type}/{package_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_package_for_authenticated_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_name : string;
      package_type : Package_type.t;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/user/packages/{package_type}/{package_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_packages_for_authenticated_user = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Visibility = struct
      let t_of_yojson = function
        | `String "internal" -> Ok `Internal
        | `String "private" -> Ok `Private
        | `String "public" -> Ok `Public
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Internal -> `String "internal"
        | `Private -> `String "private"
        | `Public -> `String "public"

      type t =
        ([ `Internal
         | `Private
         | `Public
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      package_type : Package_type.t;
      page : int; [@default 1]
      per_page : int; [@default 30]
      visibility : Visibility.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "packages"
    /? ud "package_type" (fun value ->
        CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /? option
         (ud "visibility" (fun value ->
              CCResult.to_opt (Parameters.Visibility.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
      ]
  end

  let url = "/user/packages"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("visibility", Var (params.visibility, Option (Enum Visibility.t_to_yojson)));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_docker_migration_conflicting_packages_for_authenticated_user = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "user" / "docker" / "conflicts"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/user/docker/conflicts"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Restore_package_version_for_org = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      org : string;
      package_name : string;
      package_type : Package_type.t;
      package_version_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /% Path.int
    / "restore"

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url =
    "/orgs/{org}/packages/{package_type}/{package_name}/versions/{package_version_id}/restore"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("org", Var (params.org, String));
           ("package_version_id", Var (params.package_version_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Delete_package_version_for_org = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      org : string;
      package_name : string;
      package_type : Package_type.t;
      package_version_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /% Path.int

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/packages/{package_type}/{package_name}/versions/{package_version_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("org", Var (params.org, String));
           ("package_version_id", Var (params.package_version_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_package_version_for_organization = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      org : string;
      package_name : string;
      package_type : Package_type.t;
      package_version_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package_version.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/packages/{package_type}/{package_name}/versions/{package_version_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("org", Var (params.org, String));
           ("package_version_id", Var (params.package_version_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_all_package_versions_for_package_owned_by_org = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "active" -> Ok `Active
        | `String "deleted" -> Ok `Deleted
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Active -> `String "active"
        | `Deleted -> `String "deleted"

      type t =
        ([ `Active
         | `Deleted
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      org : string;
      package_name : string;
      package_type : Package_type.t;
      page : int; [@default 1]
      per_page : int; [@default 30]
      state : State.t; [@default `Active]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "versions"
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")
    /? option_default
         `Active
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package_version.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/packages/{package_type}/{package_name}/versions"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("org", Var (params.org, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("state", Var (params.state, Enum State.t_to_yojson));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Restore_package_for_org = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      org : string;
      package_name : string;
      package_type : Package_type.t;
      token : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string
    / "restore"
    /? option (string "token")

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/packages/{package_type}/{package_name}/restore"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("org", Var (params.org, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("token", Var (params.token, Option String)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module Delete_package_for_org = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      org : string;
      package_name : string;
      package_type : Package_type.t;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string

  module Responses = struct
    module No_content = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/packages/{package_type}/{package_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("org", Var (params.org, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_package_for_organization = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      org : string;
      package_name : string;
      package_type : Package_type.t;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "packages"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/packages/{package_type}/{package_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("package_name", Var (params.package_name, String));
           ("org", Var (params.org, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_packages_for_organization = struct
  module Parameters = struct
    module Package_type = struct
      let t_of_yojson = function
        | `String "container" -> Ok `Container
        | `String "docker" -> Ok `Docker
        | `String "maven" -> Ok `Maven
        | `String "npm" -> Ok `Npm
        | `String "nuget" -> Ok `Nuget
        | `String "rubygems" -> Ok `Rubygems
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Container -> `String "container"
        | `Docker -> `String "docker"
        | `Maven -> `String "maven"
        | `Npm -> `String "npm"
        | `Nuget -> `String "nuget"
        | `Rubygems -> `String "rubygems"

      type t =
        ([ `Container
         | `Docker
         | `Maven
         | `Npm
         | `Nuget
         | `Rubygems
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Visibility = struct
      let t_of_yojson = function
        | `String "internal" -> Ok `Internal
        | `String "private" -> Ok `Private
        | `String "public" -> Ok `Public
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Internal -> `String "internal"
        | `Private -> `String "private"
        | `Public -> `String "public"

      type t =
        ([ `Internal
         | `Private
         | `Public
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      org : string;
      package_type : Package_type.t;
      page : int; [@default 1]
      per_page : int; [@default 30]
      visibility : Visibility.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "packages"
    /? ud "package_type" (fun value ->
        CCResult.to_opt (Parameters.Package_type.t_of_yojson (`String value)))
    /? option
         (ud "visibility" (fun value ->
              CCResult.to_opt (Parameters.Visibility.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/packages"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("package_type", Var (params.package_type, Enum Package_type.t_to_yojson));
           ("visibility", Var (params.visibility, Option (Enum Visibility.t_to_yojson)));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_docker_migration_conflicting_packages_for_organization = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "docker" / "conflicts"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Package.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/docker/conflicts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
