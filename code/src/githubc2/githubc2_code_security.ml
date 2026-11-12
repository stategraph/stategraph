module Get_configuration_for_repository = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "code-security-configuration"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_configuration_for_repository.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module No_content = struct end
    module Not_modified = struct end

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
      | `No_content
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("204", fun _ -> Ok `No_content);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/code-security-configuration"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_repositories_for_configuration = struct
  module Parameters = struct
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      configuration_id : int;
      org : string;
      per_page : int; [@default 30]
      status : string; [@default "all"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "code-security"
    / "configurations"
    /% Path.int
    / "repositories"
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")
    /? option_default "all" (string "status")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_configuration_repositories.t list
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/code-security/configurations/{configuration_id}/repositories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("status", Var (params.status, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Set_configuration_as_default = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Default_for_new_repos = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "none" -> Ok `None
          | `String "private_and_internal" -> Ok `Private_and_internal
          | `String "public" -> Ok `Public
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `None -> `String "none"
          | `Private_and_internal -> `String "private_and_internal"
          | `Public -> `String "public"

        type t =
          ([ `All
           | `None
           | `Private_and_internal
           | `Public
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { default_for_new_repos : Default_for_new_repos.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "code-security" / "configurations" /% Path.int / "defaults"

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Default_for_new_repos = struct
          let t_of_yojson = function
            | `String "all" -> Ok `All
            | `String "none" -> Ok `None
            | `String "private_and_internal" -> Ok `Private_and_internal
            | `String "public" -> Ok `Public
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `All -> `String "all"
            | `None -> `String "none"
            | `Private_and_internal -> `String "private_and_internal"
            | `Public -> `String "public"

          type t =
            ([ `All
             | `None
             | `Private_and_internal
             | `Public
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          configuration : Githubc2_components.Code_security_configuration.t option; [@default None]
          default_for_new_repos : Default_for_new_repos.t option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/code-security/configurations/{configuration_id}/defaults"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Attach_configuration = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Scope = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "all_without_configurations" -> Ok `All_without_configurations
        | `String "private_or_internal" -> Ok `Private_or_internal
        | `String "public" -> Ok `Public
        | `String "selected" -> Ok `Selected
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `All_without_configurations -> `String "all_without_configurations"
        | `Private_or_internal -> `String "private_or_internal"
        | `Public -> `String "public"
        | `Selected -> `String "selected"

      type t =
        ([ `All
         | `All_without_configurations
         | `Private_or_internal
         | `Public
         | `Selected
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Selected_repository_ids = struct
      type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      scope : Scope.t;
      selected_repository_ids : Selected_repository_ids.t option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "code-security" / "configurations" /% Path.int / "attach"

  module Responses = struct
    module Accepted = struct
      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
    end

    type t = [ `Accepted of Accepted.t ] [@@deriving show, eq]

    let t = [ ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson) ]
  end

  let url = "/orgs/{org}/code-security/configurations/{configuration_id}/attach"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Update_configuration = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Advanced_security = struct
      let t_of_yojson = function
        | `String "code_security" -> Ok `Code_security
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "secret_protection" -> Ok `Secret_protection
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Code_security -> `String "code_security"
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Secret_protection -> `String "secret_protection"

      type t =
        ([ `Code_security
         | `Disabled
         | `Enabled
         | `Secret_protection
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_scanning_default_setup = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_scanning_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_security = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_alerts = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_security_updates = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph_autosubmit_action = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph_autosubmit_action_options = struct
      module Primary = struct
        type t = { labeled_runners : bool option [@default None] }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Enforcement = struct
      let t_of_yojson = function
        | `String "enforced" -> Ok `Enforced
        | `String "unenforced" -> Ok `Unenforced
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Enforced -> `String "enforced"
        | `Unenforced -> `String "unenforced"

      type t =
        ([ `Enforced
         | `Unenforced
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Private_vulnerability_reporting = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_delegated_bypass = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_delegated_bypass_options = struct
      module Primary = struct
        module Reviewers = struct
          module Items = struct
            module Primary = struct
              module Mode = struct
                let t_of_yojson = function
                  | `String "ALWAYS" -> Ok `ALWAYS
                  | `String "EXEMPT" -> Ok `EXEMPT
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `ALWAYS -> `String "ALWAYS"
                  | `EXEMPT -> `String "EXEMPT"

                type t =
                  ([ `ALWAYS
                   | `EXEMPT
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              module Reviewer_type = struct
                let t_of_yojson = function
                  | `String "ROLE" -> Ok `ROLE
                  | `String "TEAM" -> Ok `TEAM
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `ROLE -> `String "ROLE"
                  | `TEAM -> `String "TEAM"

                type t =
                  ([ `ROLE
                   | `TEAM
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                mode : Mode.t; [@default `ALWAYS]
                reviewer_id : int;
                reviewer_type : Reviewer_type.t;
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { reviewers : Reviewers.t option [@default None] }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Secret_scanning_extended_metadata = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_generic_secrets = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_non_provider_patterns = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_push_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_validity_checks = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      advanced_security : Advanced_security.t option; [@default None]
      code_scanning_default_setup : Code_scanning_default_setup.t option; [@default None]
      code_scanning_default_setup_options :
        Githubc2_components.Code_scanning_default_setup_options.t option;
          [@default None]
      code_scanning_delegated_alert_dismissal : Code_scanning_delegated_alert_dismissal.t;
          [@default `Disabled]
      code_scanning_options : Githubc2_components.Code_scanning_options.t option; [@default None]
      code_security : Code_security.t option; [@default None]
      dependabot_alerts : Dependabot_alerts.t option; [@default None]
      dependabot_delegated_alert_dismissal : Dependabot_delegated_alert_dismissal.t option;
          [@default None]
      dependabot_security_updates : Dependabot_security_updates.t option; [@default None]
      dependency_graph : Dependency_graph.t option; [@default None]
      dependency_graph_autosubmit_action : Dependency_graph_autosubmit_action.t option;
          [@default None]
      dependency_graph_autosubmit_action_options :
        Dependency_graph_autosubmit_action_options.t option;
          [@default None]
      description : string option; [@default None]
      enforcement : Enforcement.t option; [@default None]
      name : string option; [@default None]
      private_vulnerability_reporting : Private_vulnerability_reporting.t option; [@default None]
      secret_protection : Secret_protection.t option; [@default None]
      secret_scanning : Secret_scanning.t option; [@default None]
      secret_scanning_delegated_alert_dismissal :
        Secret_scanning_delegated_alert_dismissal.t option;
          [@default None]
      secret_scanning_delegated_bypass : Secret_scanning_delegated_bypass.t option; [@default None]
      secret_scanning_delegated_bypass_options : Secret_scanning_delegated_bypass_options.t option;
          [@default None]
      secret_scanning_extended_metadata : Secret_scanning_extended_metadata.t option;
          [@default None]
      secret_scanning_generic_secrets : Secret_scanning_generic_secrets.t option; [@default None]
      secret_scanning_non_provider_patterns : Secret_scanning_non_provider_patterns.t option;
          [@default None]
      secret_scanning_push_protection : Secret_scanning_push_protection.t option; [@default None]
      secret_scanning_validity_checks : Secret_scanning_validity_checks.t option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "code-security" / "configurations" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module No_content = struct end

    type t =
      [ `OK of OK.t
      | `No_content
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("204", fun _ -> Ok `No_content);
      ]
  end

  let url = "/orgs/{org}/code-security/configurations/{configuration_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_configuration = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "code-security" / "configurations" /% Path.int

  module Responses = struct
    module No_content = struct end

    module Bad_request = struct
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

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/orgs/{org}/code-security/configurations/{configuration_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_configuration = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "code-security" / "configurations" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

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
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/code-security/configurations/{configuration_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Detach_configuration = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Selected_repository_ids = struct
      type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = { selected_repository_ids : Selected_repository_ids.t }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "code-security" / "configurations" / "detach"

  module Responses = struct
    module No_content = struct end

    module Bad_request = struct
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

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/orgs/{org}/code-security/configurations/detach"

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
      `Delete
end

module Get_default_configurations = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "code-security" / "configurations" / "defaults"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_default_configurations.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

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
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/code-security/configurations/defaults"

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

module Create_configuration = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Advanced_security = struct
      let t_of_yojson = function
        | `String "code_security" -> Ok `Code_security
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "secret_protection" -> Ok `Secret_protection
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Code_security -> `String "code_security"
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Secret_protection -> `String "secret_protection"

      type t =
        ([ `Code_security
         | `Disabled
         | `Enabled
         | `Secret_protection
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_scanning_default_setup = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_scanning_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_security = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_alerts = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_security_updates = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph_autosubmit_action = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph_autosubmit_action_options = struct
      module Primary = struct
        type t = { labeled_runners : bool [@default false] }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Enforcement = struct
      let t_of_yojson = function
        | `String "enforced" -> Ok `Enforced
        | `String "unenforced" -> Ok `Unenforced
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Enforced -> `String "enforced"
        | `Unenforced -> `String "unenforced"

      type t =
        ([ `Enforced
         | `Unenforced
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Private_vulnerability_reporting = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_delegated_bypass = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_delegated_bypass_options = struct
      module Primary = struct
        module Reviewers = struct
          module Items = struct
            module Primary = struct
              module Mode = struct
                let t_of_yojson = function
                  | `String "ALWAYS" -> Ok `ALWAYS
                  | `String "EXEMPT" -> Ok `EXEMPT
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `ALWAYS -> `String "ALWAYS"
                  | `EXEMPT -> `String "EXEMPT"

                type t =
                  ([ `ALWAYS
                   | `EXEMPT
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              module Reviewer_type = struct
                let t_of_yojson = function
                  | `String "ROLE" -> Ok `ROLE
                  | `String "TEAM" -> Ok `TEAM
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `ROLE -> `String "ROLE"
                  | `TEAM -> `String "TEAM"

                type t =
                  ([ `ROLE
                   | `TEAM
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                mode : Mode.t; [@default `ALWAYS]
                reviewer_id : int;
                reviewer_type : Reviewer_type.t;
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { reviewers : Reviewers.t option [@default None] }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Secret_scanning_extended_metadata = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_generic_secrets = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_non_provider_patterns = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_push_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_validity_checks = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      advanced_security : Advanced_security.t; [@default `Disabled]
      code_scanning_default_setup : Code_scanning_default_setup.t; [@default `Disabled]
      code_scanning_default_setup_options :
        Githubc2_components.Code_scanning_default_setup_options.t option;
          [@default None]
      code_scanning_delegated_alert_dismissal : Code_scanning_delegated_alert_dismissal.t;
          [@default `Not_set]
      code_scanning_options : Githubc2_components.Code_scanning_options.t option; [@default None]
      code_security : Code_security.t option; [@default None]
      dependabot_alerts : Dependabot_alerts.t; [@default `Disabled]
      dependabot_delegated_alert_dismissal : Dependabot_delegated_alert_dismissal.t;
          [@default `Disabled]
      dependabot_security_updates : Dependabot_security_updates.t; [@default `Disabled]
      dependency_graph : Dependency_graph.t; [@default `Enabled]
      dependency_graph_autosubmit_action : Dependency_graph_autosubmit_action.t;
          [@default `Disabled]
      dependency_graph_autosubmit_action_options :
        Dependency_graph_autosubmit_action_options.t option;
          [@default None]
      description : string option; [@default None]
      enforcement : Enforcement.t; [@default `Enforced]
      name : string;
      private_vulnerability_reporting : Private_vulnerability_reporting.t; [@default `Disabled]
      secret_protection : Secret_protection.t option; [@default None]
      secret_scanning : Secret_scanning.t; [@default `Disabled]
      secret_scanning_delegated_alert_dismissal :
        Secret_scanning_delegated_alert_dismissal.t option;
          [@default None]
      secret_scanning_delegated_bypass : Secret_scanning_delegated_bypass.t; [@default `Disabled]
      secret_scanning_delegated_bypass_options : Secret_scanning_delegated_bypass_options.t option;
          [@default None]
      secret_scanning_extended_metadata : Secret_scanning_extended_metadata.t option;
          [@default None]
      secret_scanning_generic_secrets : Secret_scanning_generic_secrets.t; [@default `Disabled]
      secret_scanning_non_provider_patterns : Secret_scanning_non_provider_patterns.t;
          [@default `Disabled]
      secret_scanning_push_protection : Secret_scanning_push_protection.t; [@default `Disabled]
      secret_scanning_validity_checks : Secret_scanning_validity_checks.t; [@default `Disabled]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "code-security" / "configurations"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Code_security_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/orgs/{org}/code-security/configurations"

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

module Get_configurations_for_org = struct
  module Parameters = struct
    module Target_type = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "global" -> Ok `Global
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Global -> `String "global"

      type t =
        ([ `All
         | `Global
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      org : string;
      per_page : int; [@default 30]
      target_type : Target_type.t; [@default `All]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "code-security"
    / "configurations"
    /? option_default
         `All
         (ud "target_type" (fun value ->
              CCResult.to_opt (Parameters.Target_type.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_configuration.t list
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/code-security/configurations"

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
           ("target_type", Var (params.target_type, Enum Target_type.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_repositories_for_enterprise_configuration = struct
  module Parameters = struct
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      configuration_id : int;
      enterprise : string;
      per_page : int; [@default 30]
      status : string; [@default "all"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "enterprises"
    /% Path.string
    / "code-security"
    / "configurations"
    /% Path.int
    / "repositories"
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")
    /? option_default "all" (string "status")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_configuration_repositories.t list
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/code-security/configurations/{configuration_id}/repositories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("status", Var (params.status, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Set_configuration_as_default_for_enterprise = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      enterprise : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Default_for_new_repos = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "none" -> Ok `None
          | `String "private_and_internal" -> Ok `Private_and_internal
          | `String "public" -> Ok `Public
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `None -> `String "none"
          | `Private_and_internal -> `String "private_and_internal"
          | `Public -> `String "public"

        type t =
          ([ `All
           | `None
           | `Private_and_internal
           | `Public
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { default_for_new_repos : Default_for_new_repos.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "enterprises" /% Path.string / "code-security" / "configurations" /% Path.int / "defaults"

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Default_for_new_repos = struct
          let t_of_yojson = function
            | `String "all" -> Ok `All
            | `String "none" -> Ok `None
            | `String "private_and_internal" -> Ok `Private_and_internal
            | `String "public" -> Ok `Public
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `All -> `String "all"
            | `None -> `String "none"
            | `Private_and_internal -> `String "private_and_internal"
            | `Public -> `String "public"

          type t =
            ([ `All
             | `None
             | `Private_and_internal
             | `Public
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          configuration : Githubc2_components.Code_security_configuration.t option; [@default None]
          default_for_new_repos : Default_for_new_repos.t option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/code-security/configurations/{configuration_id}/defaults"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Attach_enterprise_configuration = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      enterprise : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Scope = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "all_without_configurations" -> Ok `All_without_configurations
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `All_without_configurations -> `String "all_without_configurations"

      type t =
        ([ `All
         | `All_without_configurations
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = { scope : Scope.t } [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "enterprises" /% Path.string / "code-security" / "configurations" /% Path.int / "attach"

  module Responses = struct
    module Accepted = struct
      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Accepted of Accepted.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/code-security/configurations/{configuration_id}/attach"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Update_enterprise_configuration = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      enterprise : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Advanced_security = struct
      let t_of_yojson = function
        | `String "code_security" -> Ok `Code_security
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "secret_protection" -> Ok `Secret_protection
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Code_security -> `String "code_security"
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Secret_protection -> `String "secret_protection"

      type t =
        ([ `Code_security
         | `Disabled
         | `Enabled
         | `Secret_protection
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_scanning_default_setup = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_scanning_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_security = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_alerts = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_security_updates = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph_autosubmit_action = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph_autosubmit_action_options = struct
      module Primary = struct
        type t = { labeled_runners : bool option [@default None] }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Enforcement = struct
      let t_of_yojson = function
        | `String "enforced" -> Ok `Enforced
        | `String "unenforced" -> Ok `Unenforced
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Enforced -> `String "enforced"
        | `Unenforced -> `String "unenforced"

      type t =
        ([ `Enforced
         | `Unenforced
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Private_vulnerability_reporting = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_extended_metadata = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_generic_secrets = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_non_provider_patterns = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_push_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_validity_checks = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      advanced_security : Advanced_security.t option; [@default None]
      code_scanning_default_setup : Code_scanning_default_setup.t option; [@default None]
      code_scanning_default_setup_options :
        Githubc2_components.Code_scanning_default_setup_options.t option;
          [@default None]
      code_scanning_delegated_alert_dismissal : Code_scanning_delegated_alert_dismissal.t;
          [@default `Disabled]
      code_scanning_options : Githubc2_components.Code_scanning_options.t option; [@default None]
      code_security : Code_security.t option; [@default None]
      dependabot_alerts : Dependabot_alerts.t option; [@default None]
      dependabot_security_updates : Dependabot_security_updates.t option; [@default None]
      dependency_graph : Dependency_graph.t option; [@default None]
      dependency_graph_autosubmit_action : Dependency_graph_autosubmit_action.t option;
          [@default None]
      dependency_graph_autosubmit_action_options :
        Dependency_graph_autosubmit_action_options.t option;
          [@default None]
      description : string option; [@default None]
      enforcement : Enforcement.t option; [@default None]
      name : string option; [@default None]
      private_vulnerability_reporting : Private_vulnerability_reporting.t option; [@default None]
      secret_protection : Secret_protection.t option; [@default None]
      secret_scanning : Secret_scanning.t option; [@default None]
      secret_scanning_delegated_alert_dismissal : Secret_scanning_delegated_alert_dismissal.t;
          [@default `Disabled]
      secret_scanning_extended_metadata : Secret_scanning_extended_metadata.t; [@default `Disabled]
      secret_scanning_generic_secrets : Secret_scanning_generic_secrets.t; [@default `Disabled]
      secret_scanning_non_provider_patterns : Secret_scanning_non_provider_patterns.t option;
          [@default None]
      secret_scanning_push_protection : Secret_scanning_push_protection.t option; [@default None]
      secret_scanning_validity_checks : Secret_scanning_validity_checks.t option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "enterprises" /% Path.string / "code-security" / "configurations" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/code-security/configurations/{configuration_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_configuration_for_enterprise = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      enterprise : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "enterprises" /% Path.string / "code-security" / "configurations" /% Path.int

  module Responses = struct
    module No_content = struct end

    module Bad_request = struct
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

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/code-security/configurations/{configuration_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_single_configuration_for_enterprise = struct
  module Parameters = struct
    type t = {
      configuration_id : int;
      enterprise : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "enterprises" /% Path.string / "code-security" / "configurations" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

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
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/code-security/configurations/{configuration_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("configuration_id", Var (params.configuration_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_default_configurations_for_enterprise = struct
  module Parameters = struct
    type t = { enterprise : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "enterprises" /% Path.string / "code-security" / "configurations" / "defaults"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_default_configurations.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/enterprises/{enterprise}/code-security/configurations/defaults"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("enterprise", Var (params.enterprise, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_configuration_for_enterprise = struct
  module Parameters = struct
    type t = { enterprise : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Advanced_security = struct
      let t_of_yojson = function
        | `String "code_security" -> Ok `Code_security
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "secret_protection" -> Ok `Secret_protection
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Code_security -> `String "code_security"
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Secret_protection -> `String "secret_protection"

      type t =
        ([ `Code_security
         | `Disabled
         | `Enabled
         | `Secret_protection
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_scanning_default_setup = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_scanning_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Code_security = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_alerts = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependabot_security_updates = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph_autosubmit_action = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Dependency_graph_autosubmit_action_options = struct
      module Primary = struct
        type t = { labeled_runners : bool [@default false] }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Enforcement = struct
      let t_of_yojson = function
        | `String "enforced" -> Ok `Enforced
        | `String "unenforced" -> Ok `Unenforced
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Enforced -> `String "enforced"
        | `Unenforced -> `String "unenforced"

      type t =
        ([ `Enforced
         | `Unenforced
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Private_vulnerability_reporting = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_delegated_alert_dismissal = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_extended_metadata = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_generic_secrets = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_non_provider_patterns = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_push_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Secret_scanning_validity_checks = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "not_set" -> Ok `Not_set
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Not_set -> `String "not_set"

      type t =
        ([ `Disabled
         | `Enabled
         | `Not_set
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      advanced_security : Advanced_security.t; [@default `Disabled]
      code_scanning_default_setup : Code_scanning_default_setup.t; [@default `Disabled]
      code_scanning_default_setup_options :
        Githubc2_components.Code_scanning_default_setup_options.t option;
          [@default None]
      code_scanning_delegated_alert_dismissal : Code_scanning_delegated_alert_dismissal.t;
          [@default `Disabled]
      code_scanning_options : Githubc2_components.Code_scanning_options.t option; [@default None]
      code_security : Code_security.t option; [@default None]
      dependabot_alerts : Dependabot_alerts.t; [@default `Disabled]
      dependabot_security_updates : Dependabot_security_updates.t; [@default `Disabled]
      dependency_graph : Dependency_graph.t; [@default `Enabled]
      dependency_graph_autosubmit_action : Dependency_graph_autosubmit_action.t;
          [@default `Disabled]
      dependency_graph_autosubmit_action_options :
        Dependency_graph_autosubmit_action_options.t option;
          [@default None]
      description : string option; [@default None]
      enforcement : Enforcement.t; [@default `Enforced]
      name : string;
      private_vulnerability_reporting : Private_vulnerability_reporting.t; [@default `Disabled]
      secret_protection : Secret_protection.t option; [@default None]
      secret_scanning : Secret_scanning.t; [@default `Disabled]
      secret_scanning_delegated_alert_dismissal : Secret_scanning_delegated_alert_dismissal.t;
          [@default `Disabled]
      secret_scanning_extended_metadata : Secret_scanning_extended_metadata.t; [@default `Disabled]
      secret_scanning_generic_secrets : Secret_scanning_generic_secrets.t; [@default `Disabled]
      secret_scanning_non_provider_patterns : Secret_scanning_non_provider_patterns.t;
          [@default `Disabled]
      secret_scanning_push_protection : Secret_scanning_push_protection.t; [@default `Disabled]
      secret_scanning_validity_checks : Secret_scanning_validity_checks.t; [@default `Disabled]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "enterprises" /% Path.string / "code-security" / "configurations"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Code_security_configuration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
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
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/code-security/configurations"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("enterprise", Var (params.enterprise, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_configurations_for_enterprise = struct
  module Parameters = struct
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      enterprise : string;
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "enterprises"
    /% Path.string
    / "code-security"
    / "configurations"
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_security_configuration.t list
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/code-security/configurations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("enterprise", Var (params.enterprise, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
