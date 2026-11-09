module Update_org_private_registry = struct
  module Parameters = struct
    type t = {
      org : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Auth_type = struct
        let t_of_yojson = function
          | `String "oidc_aws" -> Ok `Oidc_aws
          | `String "oidc_azure" -> Ok `Oidc_azure
          | `String "oidc_cloudsmith" -> Ok `Oidc_cloudsmith
          | `String "oidc_gcp" -> Ok `Oidc_gcp
          | `String "oidc_jfrog" -> Ok `Oidc_jfrog
          | `String "token" -> Ok `Token
          | `String "username_password" -> Ok `Username_password
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Oidc_aws -> `String "oidc_aws"
          | `Oidc_azure -> `String "oidc_azure"
          | `Oidc_cloudsmith -> `String "oidc_cloudsmith"
          | `Oidc_gcp -> `String "oidc_gcp"
          | `Oidc_jfrog -> `String "oidc_jfrog"
          | `Token -> `String "token"
          | `Username_password -> `String "username_password"

        type t =
          ([ `Oidc_aws
           | `Oidc_azure
           | `Oidc_cloudsmith
           | `Oidc_gcp
           | `Oidc_jfrog
           | `Token
           | `Username_password
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Registry_type = struct
        let t_of_yojson = function
          | `String "cargo_registry" -> Ok `Cargo_registry
          | `String "composer_repository" -> Ok `Composer_repository
          | `String "docker_registry" -> Ok `Docker_registry
          | `String "git_source" -> Ok `Git_source
          | `String "goproxy_server" -> Ok `Goproxy_server
          | `String "helm_registry" -> Ok `Helm_registry
          | `String "hex_organization" -> Ok `Hex_organization
          | `String "hex_repository" -> Ok `Hex_repository
          | `String "maven_repository" -> Ok `Maven_repository
          | `String "npm_registry" -> Ok `Npm_registry
          | `String "nuget_feed" -> Ok `Nuget_feed
          | `String "pub_repository" -> Ok `Pub_repository
          | `String "python_index" -> Ok `Python_index
          | `String "rubygems_server" -> Ok `Rubygems_server
          | `String "terraform_registry" -> Ok `Terraform_registry
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Cargo_registry -> `String "cargo_registry"
          | `Composer_repository -> `String "composer_repository"
          | `Docker_registry -> `String "docker_registry"
          | `Git_source -> `String "git_source"
          | `Goproxy_server -> `String "goproxy_server"
          | `Helm_registry -> `String "helm_registry"
          | `Hex_organization -> `String "hex_organization"
          | `Hex_repository -> `String "hex_repository"
          | `Maven_repository -> `String "maven_repository"
          | `Npm_registry -> `String "npm_registry"
          | `Nuget_feed -> `String "nuget_feed"
          | `Pub_repository -> `String "pub_repository"
          | `Python_index -> `String "python_index"
          | `Rubygems_server -> `String "rubygems_server"
          | `Terraform_registry -> `String "terraform_registry"

        type t =
          ([ `Cargo_registry
           | `Composer_repository
           | `Docker_registry
           | `Git_source
           | `Goproxy_server
           | `Helm_registry
           | `Hex_organization
           | `Hex_repository
           | `Maven_repository
           | `Npm_registry
           | `Nuget_feed
           | `Pub_repository
           | `Python_index
           | `Rubygems_server
           | `Terraform_registry
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Selected_repository_ids = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Visibility = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "private" -> Ok `Private
          | `String "selected" -> Ok `Selected
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `Private -> `String "private"
          | `Selected -> `String "selected"

        type t =
          ([ `All
           | `Private
           | `Selected
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        account_id : string option; [@default None]
        api_host : string option; [@default None]
        audience : string option; [@default None]
        auth_type : Auth_type.t option; [@default None]
        aws_region : string option; [@default None]
        client_id : string option; [@default None]
        domain : string option; [@default None]
        domain_owner : string option; [@default None]
        encrypted_value : string option; [@default None]
        identity_mapping_name : string option; [@default None]
        jfrog_oidc_provider_name : string option; [@default None]
        key_id : string option; [@default None]
        namespace : string option; [@default None]
        registry_type : Registry_type.t option; [@default None]
        replaces_base : bool; [@default false]
        role_name : string option; [@default None]
        selected_repository_ids : Selected_repository_ids.t option; [@default None]
        service_account : string option; [@default None]
        service_slug : string option; [@default None]
        tenant_id : string option; [@default None]
        url : string option; [@default None]
        username : string option; [@default None]
        visibility : Visibility.t option; [@default None]
        workload_identity_provider : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/private-registries/{secret_name}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("secret_name", Var (params.secret_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_org_private_registry = struct
  module Parameters = struct
    type t = {
      org : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/private-registries/{secret_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("secret_name", Var (params.secret_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_org_private_registry = struct
  module Parameters = struct
    type t = {
      org : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Org_private_registry_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/private-registries/{secret_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("secret_name", Var (params.secret_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_org_public_key = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      module Primary = struct
        type t = {
          key : string;
          key_id : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/private-registries/public-key"

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

module Create_org_private_registry = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Auth_type = struct
        let t_of_yojson = function
          | `String "oidc_aws" -> Ok `Oidc_aws
          | `String "oidc_azure" -> Ok `Oidc_azure
          | `String "oidc_cloudsmith" -> Ok `Oidc_cloudsmith
          | `String "oidc_gcp" -> Ok `Oidc_gcp
          | `String "oidc_jfrog" -> Ok `Oidc_jfrog
          | `String "token" -> Ok `Token
          | `String "username_password" -> Ok `Username_password
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Oidc_aws -> `String "oidc_aws"
          | `Oidc_azure -> `String "oidc_azure"
          | `Oidc_cloudsmith -> `String "oidc_cloudsmith"
          | `Oidc_gcp -> `String "oidc_gcp"
          | `Oidc_jfrog -> `String "oidc_jfrog"
          | `Token -> `String "token"
          | `Username_password -> `String "username_password"

        type t =
          ([ `Oidc_aws
           | `Oidc_azure
           | `Oidc_cloudsmith
           | `Oidc_gcp
           | `Oidc_jfrog
           | `Token
           | `Username_password
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Registry_type = struct
        let t_of_yojson = function
          | `String "cargo_registry" -> Ok `Cargo_registry
          | `String "composer_repository" -> Ok `Composer_repository
          | `String "docker_registry" -> Ok `Docker_registry
          | `String "git_source" -> Ok `Git_source
          | `String "goproxy_server" -> Ok `Goproxy_server
          | `String "helm_registry" -> Ok `Helm_registry
          | `String "hex_organization" -> Ok `Hex_organization
          | `String "hex_repository" -> Ok `Hex_repository
          | `String "maven_repository" -> Ok `Maven_repository
          | `String "npm_registry" -> Ok `Npm_registry
          | `String "nuget_feed" -> Ok `Nuget_feed
          | `String "pub_repository" -> Ok `Pub_repository
          | `String "python_index" -> Ok `Python_index
          | `String "rubygems_server" -> Ok `Rubygems_server
          | `String "terraform_registry" -> Ok `Terraform_registry
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Cargo_registry -> `String "cargo_registry"
          | `Composer_repository -> `String "composer_repository"
          | `Docker_registry -> `String "docker_registry"
          | `Git_source -> `String "git_source"
          | `Goproxy_server -> `String "goproxy_server"
          | `Helm_registry -> `String "helm_registry"
          | `Hex_organization -> `String "hex_organization"
          | `Hex_repository -> `String "hex_repository"
          | `Maven_repository -> `String "maven_repository"
          | `Npm_registry -> `String "npm_registry"
          | `Nuget_feed -> `String "nuget_feed"
          | `Pub_repository -> `String "pub_repository"
          | `Python_index -> `String "python_index"
          | `Rubygems_server -> `String "rubygems_server"
          | `Terraform_registry -> `String "terraform_registry"

        type t =
          ([ `Cargo_registry
           | `Composer_repository
           | `Docker_registry
           | `Git_source
           | `Goproxy_server
           | `Helm_registry
           | `Hex_organization
           | `Hex_repository
           | `Maven_repository
           | `Npm_registry
           | `Nuget_feed
           | `Pub_repository
           | `Python_index
           | `Rubygems_server
           | `Terraform_registry
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Selected_repository_ids = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Visibility = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "private" -> Ok `Private
          | `String "selected" -> Ok `Selected
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `Private -> `String "private"
          | `Selected -> `String "selected"

        type t =
          ([ `All
           | `Private
           | `Selected
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        account_id : string option; [@default None]
        api_host : string option; [@default None]
        audience : string option; [@default None]
        auth_type : Auth_type.t option; [@default None]
        aws_region : string option; [@default None]
        client_id : string option; [@default None]
        domain : string option; [@default None]
        domain_owner : string option; [@default None]
        encrypted_value : string option; [@default None]
        identity_mapping_name : string option; [@default None]
        jfrog_oidc_provider_name : string option; [@default None]
        key_id : string option; [@default None]
        namespace : string option; [@default None]
        registry_type : Registry_type.t;
        replaces_base : bool; [@default false]
        role_name : string option; [@default None]
        selected_repository_ids : Selected_repository_ids.t option; [@default None]
        service_account : string option; [@default None]
        service_slug : string option; [@default None]
        tenant_id : string option; [@default None]
        url : string;
        username : string option; [@default None]
        visibility : Visibility.t;
        workload_identity_provider : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Org_private_registry_configuration_with_selected_repositories.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/private-registries"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_org_private_registries = struct
  module Parameters = struct
    type t = {
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 30 (int "per_page") /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Configurations = struct
          type t = Githubc2_components.Org_private_registry_configuration.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          configurations : Configurations.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/private-registries"

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
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end
