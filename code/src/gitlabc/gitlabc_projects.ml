module DeleteApiV4ProjectsId = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string

  module Responses = struct
    module Accepted = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Accepted
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", fun _ -> Ok `Accepted);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}"

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
      `Delete
end

module PutApiV4ProjectsId = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsId.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("400", fun _ -> Ok `Bad_request); ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v4/projects/{id}"

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

module GetApiV4ProjectsId = struct
  module Parameters = struct
    type t = {
      id : string;
      license : bool; [@default false]
      statistics : bool; [@default false]
      with_custom_attributes : bool; [@default false]
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
    /? option_default false (bool "statistics")
    /? option_default false (bool "with_custom_attributes")
    /? option_default false (bool "license")

  module Responses = struct
    module OK = struct
      type t = Gitlabc_components.API_Entities_ProjectWithAccess.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}"

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
           ("statistics", Var (params.statistics, Bool));
           ("with_custom_attributes", Var (params.with_custom_attributes, Bool));
           ("license", Var (params.license, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsUserUserId = struct
  module Parameters = struct
    type t = { user_id : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsUserUserId.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" / "user" /% Path.int

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/user/{user_id}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsRemoteImportS3 = struct
  module Parameters = struct
    module Override_params_analytics_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_auto_cancel_pending_pipelines_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"

      type t =
        ([ `Disabled
         | `Enabled
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_auto_devops_deploy_strategy_ = struct
      let t_of_yojson = function
        | `String "continuous" -> Ok `Continuous
        | `String "manual" -> Ok `Manual
        | `String "timed_incremental" -> Ok `Timed_incremental
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Continuous -> `String "continuous"
        | `Manual -> `String "manual"
        | `Timed_incremental -> `String "timed_incremental"

      type t =
        ([ `Continuous
         | `Manual
         | `Timed_incremental
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_build_git_strategy_ = struct
      let t_of_yojson = function
        | `String "clone" -> Ok `Clone
        | `String "fetch" -> Ok `Fetch
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Clone -> `String "clone"
        | `Fetch -> `String "fetch"

      type t =
        ([ `Clone
         | `Fetch
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_builds_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_container_registry_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_environments_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_feature_flags_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_forking_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_infrastructure_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_issues_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_merge_method_ = struct
      let t_of_yojson = function
        | `String "ff" -> Ok `Ff
        | `String "merge" -> Ok `Merge
        | `String "rebase_merge" -> Ok `Rebase_merge
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Ff -> `String "ff"
        | `Merge -> `String "merge"
        | `Rebase_merge -> `String "rebase_merge"

      type t =
        ([ `Ff
         | `Merge
         | `Rebase_merge
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_merge_requests_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_model_experiments_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_model_registry_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_monitor_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_pages_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | `String "public" -> Ok `Public
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"
        | `Public -> `String "public"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         | `Public
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_releases_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_repository_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_requirements_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_security_and_compliance_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_snippets_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_squash_option_ = struct
      let t_of_yojson = function
        | `String "always" -> Ok `Always
        | `String "default_off" -> Ok `Default_off
        | `String "default_on" -> Ok `Default_on
        | `String "never" -> Ok `Never
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Always -> `String "always"
        | `Default_off -> `String "default_off"
        | `Default_on -> `String "default_on"
        | `Never -> `String "never"

      type t =
        ([ `Always
         | `Default_off
         | `Default_on
         | `Never
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_tag_list_ = struct
      type t = string list [@@deriving show, eq]
    end

    module Override_params_topics_ = struct
      type t = string list [@@deriving show, eq]
    end

    module Override_params_visibility_ = struct
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

    module Override_params_wiki_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      access_key_id : string;
      bucket_name : string;
      file_key : string;
      name : string option; [@default None]
      namespace : string option; [@default None]
      override_params_allow_merge_on_skipped_pipeline_ : bool option;
          [@default None] [@key "override_params[allow_merge_on_skipped_pipeline]"]
      override_params_analytics_access_level_ : Override_params_analytics_access_level_.t option;
          [@default None] [@key "override_params[analytics_access_level]"]
      override_params_approvals_before_merge_ : int option;
          [@default None] [@key "override_params[approvals_before_merge]"]
      override_params_auto_cancel_pending_pipelines_ :
        Override_params_auto_cancel_pending_pipelines_.t option;
          [@default None] [@key "override_params[auto_cancel_pending_pipelines]"]
      override_params_auto_devops_deploy_strategy_ :
        Override_params_auto_devops_deploy_strategy_.t option;
          [@default None] [@key "override_params[auto_devops_deploy_strategy]"]
      override_params_auto_devops_enabled_ : bool option;
          [@default None] [@key "override_params[auto_devops_enabled]"]
      override_params_autoclose_referenced_issues_ : bool option;
          [@default None] [@key "override_params[autoclose_referenced_issues]"]
      override_params_avatar_ : string option; [@default None] [@key "override_params[avatar]"]
      override_params_build_git_strategy_ : Override_params_build_git_strategy_.t option;
          [@default None] [@key "override_params[build_git_strategy]"]
      override_params_build_timeout_ : int option;
          [@default None] [@key "override_params[build_timeout]"]
      override_params_builds_access_level_ : Override_params_builds_access_level_.t option;
          [@default None] [@key "override_params[builds_access_level]"]
      override_params_ci_config_path_ : string option;
          [@default None] [@key "override_params[ci_config_path]"]
      override_params_container_expiration_policy_attributes__cadence_ : string option;
          [@default None] [@key "override_params[container_expiration_policy_attributes][cadence]"]
      override_params_container_expiration_policy_attributes__enabled_ : bool option;
          [@default None] [@key "override_params[container_expiration_policy_attributes][enabled]"]
      override_params_container_expiration_policy_attributes__keep_n_ : int option;
          [@default None] [@key "override_params[container_expiration_policy_attributes][keep_n]"]
      override_params_container_expiration_policy_attributes__name_regex_ : string option;
          [@default None]
          [@key "override_params[container_expiration_policy_attributes][name_regex]"]
      override_params_container_expiration_policy_attributes__name_regex_keep_ : string option;
          [@default None]
          [@key "override_params[container_expiration_policy_attributes][name_regex_keep]"]
      override_params_container_expiration_policy_attributes__older_than_ : string option;
          [@default None]
          [@key "override_params[container_expiration_policy_attributes][older_than]"]
      override_params_container_registry_access_level_ :
        Override_params_container_registry_access_level_.t option;
          [@default None] [@key "override_params[container_registry_access_level]"]
      override_params_container_registry_enabled_ : bool option;
          [@default None] [@key "override_params[container_registry_enabled]"]
      override_params_description_ : string option;
          [@default None] [@key "override_params[description]"]
      override_params_emails_disabled_ : bool option;
          [@default None] [@key "override_params[emails_disabled]"]
      override_params_emails_enabled_ : bool option;
          [@default None] [@key "override_params[emails_enabled]"]
      override_params_enforce_auth_checks_on_uploads_ : bool option;
          [@default None] [@key "override_params[enforce_auth_checks_on_uploads]"]
      override_params_environments_access_level_ :
        Override_params_environments_access_level_.t option;
          [@default None] [@key "override_params[environments_access_level]"]
      override_params_external_authorization_classification_label_ : string option;
          [@default None] [@key "override_params[external_authorization_classification_label]"]
      override_params_feature_flags_access_level_ :
        Override_params_feature_flags_access_level_.t option;
          [@default None] [@key "override_params[feature_flags_access_level]"]
      override_params_forking_access_level_ : Override_params_forking_access_level_.t option;
          [@default None] [@key "override_params[forking_access_level]"]
      override_params_group_runners_enabled_ : bool option;
          [@default None] [@key "override_params[group_runners_enabled]"]
      override_params_infrastructure_access_level_ :
        Override_params_infrastructure_access_level_.t option;
          [@default None] [@key "override_params[infrastructure_access_level]"]
      override_params_issue_branch_template_ : string option;
          [@default None] [@key "override_params[issue_branch_template]"]
      override_params_issues_access_level_ : Override_params_issues_access_level_.t option;
          [@default None] [@key "override_params[issues_access_level]"]
      override_params_issues_enabled_ : bool option;
          [@default None] [@key "override_params[issues_enabled]"]
      override_params_jobs_enabled_ : bool option;
          [@default None] [@key "override_params[jobs_enabled]"]
      override_params_lfs_enabled_ : bool option;
          [@default None] [@key "override_params[lfs_enabled]"]
      override_params_merge_commit_template_ : string option;
          [@default None] [@key "override_params[merge_commit_template]"]
      override_params_merge_method_ : Override_params_merge_method_.t option;
          [@default None] [@key "override_params[merge_method]"]
      override_params_merge_requests_access_level_ :
        Override_params_merge_requests_access_level_.t option;
          [@default None] [@key "override_params[merge_requests_access_level]"]
      override_params_merge_requests_enabled_ : bool option;
          [@default None] [@key "override_params[merge_requests_enabled]"]
      override_params_mirror_ : bool option; [@default None] [@key "override_params[mirror]"]
      override_params_mirror_trigger_builds_ : bool option;
          [@default None] [@key "override_params[mirror_trigger_builds]"]
      override_params_model_experiments_access_level_ :
        Override_params_model_experiments_access_level_.t option;
          [@default None] [@key "override_params[model_experiments_access_level]"]
      override_params_model_registry_access_level_ :
        Override_params_model_registry_access_level_.t option;
          [@default None] [@key "override_params[model_registry_access_level]"]
      override_params_monitor_access_level_ : Override_params_monitor_access_level_.t option;
          [@default None] [@key "override_params[monitor_access_level]"]
      override_params_mr_default_target_self_ : bool option;
          [@default None] [@key "override_params[mr_default_target_self]"]
      override_params_only_allow_merge_if_all_discussions_are_resolved_ : bool option;
          [@default None] [@key "override_params[only_allow_merge_if_all_discussions_are_resolved]"]
      override_params_only_allow_merge_if_all_status_checks_passed_ : bool option;
          [@default None] [@key "override_params[only_allow_merge_if_all_status_checks_passed]"]
      override_params_only_allow_merge_if_pipeline_succeeds_ : bool option;
          [@default None] [@key "override_params[only_allow_merge_if_pipeline_succeeds]"]
      override_params_packages_enabled_ : bool option;
          [@default None] [@key "override_params[packages_enabled]"]
      override_params_pages_access_level_ : Override_params_pages_access_level_.t option;
          [@default None] [@key "override_params[pages_access_level]"]
      override_params_prevent_merge_without_jira_issue_ : bool option;
          [@default None] [@key "override_params[prevent_merge_without_jira_issue]"]
      override_params_printing_merge_request_link_enabled_ : bool option;
          [@default None] [@key "override_params[printing_merge_request_link_enabled]"]
      override_params_public_builds_ : bool option;
          [@default None] [@key "override_params[public_builds]"]
      override_params_public_jobs_ : bool option;
          [@default None] [@key "override_params[public_jobs]"]
      override_params_releases_access_level_ : Override_params_releases_access_level_.t option;
          [@default None] [@key "override_params[releases_access_level]"]
      override_params_remove_source_branch_after_merge_ : bool option;
          [@default None] [@key "override_params[remove_source_branch_after_merge]"]
      override_params_repository_access_level_ : Override_params_repository_access_level_.t option;
          [@default None] [@key "override_params[repository_access_level]"]
      override_params_repository_storage_ : string option;
          [@default None] [@key "override_params[repository_storage]"]
      override_params_request_access_enabled_ : bool option;
          [@default None] [@key "override_params[request_access_enabled]"]
      override_params_requirements_access_level_ :
        Override_params_requirements_access_level_.t option;
          [@default None] [@key "override_params[requirements_access_level]"]
      override_params_resolve_outdated_diff_discussions_ : bool option;
          [@default None] [@key "override_params[resolve_outdated_diff_discussions]"]
      override_params_security_and_compliance_access_level_ :
        Override_params_security_and_compliance_access_level_.t option;
          [@default None] [@key "override_params[security_and_compliance_access_level]"]
      override_params_service_desk_enabled_ : bool option;
          [@default None] [@key "override_params[service_desk_enabled]"]
      override_params_shared_runners_enabled_ : bool option;
          [@default None] [@key "override_params[shared_runners_enabled]"]
      override_params_show_default_award_emojis_ : bool option;
          [@default None] [@key "override_params[show_default_award_emojis]"]
      override_params_show_diff_preview_in_email_ : bool option;
          [@default None] [@key "override_params[show_diff_preview_in_email]"]
      override_params_snippets_access_level_ : Override_params_snippets_access_level_.t option;
          [@default None] [@key "override_params[snippets_access_level]"]
      override_params_snippets_enabled_ : bool option;
          [@default None] [@key "override_params[snippets_enabled]"]
      override_params_squash_commit_template_ : string option;
          [@default None] [@key "override_params[squash_commit_template]"]
      override_params_squash_option_ : Override_params_squash_option_.t option;
          [@default None] [@key "override_params[squash_option]"]
      override_params_suggestion_commit_message_ : string option;
          [@default None] [@key "override_params[suggestion_commit_message]"]
      override_params_tag_list_ : Override_params_tag_list_.t option;
          [@default None] [@key "override_params[tag_list]"]
      override_params_topics_ : Override_params_topics_.t option;
          [@default None] [@key "override_params[topics]"]
      override_params_visibility_ : Override_params_visibility_.t option;
          [@default None] [@key "override_params[visibility]"]
      override_params_warn_about_potentially_unwanted_characters_ : bool option;
          [@default None] [@key "override_params[warn_about_potentially_unwanted_characters]"]
      override_params_wiki_access_level_ : Override_params_wiki_access_level_.t option;
          [@default None] [@key "override_params[wiki_access_level]"]
      override_params_wiki_enabled_ : bool option;
          [@default None] [@key "override_params[wiki_enabled]"]
      overwrite : bool; [@default false]
      path : string;
      region : string;
      secret_access_key : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" / "remote-import-s3"

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Too_many_requests = struct end
    module Service_unavailable = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Too_many_requests
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("429", fun _ -> Ok `Too_many_requests);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v4/projects/remote-import-s3"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsRemoteImport = struct
  module Parameters = struct
    module Override_params_analytics_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_auto_cancel_pending_pipelines_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"

      type t =
        ([ `Disabled
         | `Enabled
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_auto_devops_deploy_strategy_ = struct
      let t_of_yojson = function
        | `String "continuous" -> Ok `Continuous
        | `String "manual" -> Ok `Manual
        | `String "timed_incremental" -> Ok `Timed_incremental
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Continuous -> `String "continuous"
        | `Manual -> `String "manual"
        | `Timed_incremental -> `String "timed_incremental"

      type t =
        ([ `Continuous
         | `Manual
         | `Timed_incremental
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_build_git_strategy_ = struct
      let t_of_yojson = function
        | `String "clone" -> Ok `Clone
        | `String "fetch" -> Ok `Fetch
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Clone -> `String "clone"
        | `Fetch -> `String "fetch"

      type t =
        ([ `Clone
         | `Fetch
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_builds_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_container_registry_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_environments_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_feature_flags_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_forking_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_infrastructure_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_issues_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_merge_method_ = struct
      let t_of_yojson = function
        | `String "ff" -> Ok `Ff
        | `String "merge" -> Ok `Merge
        | `String "rebase_merge" -> Ok `Rebase_merge
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Ff -> `String "ff"
        | `Merge -> `String "merge"
        | `Rebase_merge -> `String "rebase_merge"

      type t =
        ([ `Ff
         | `Merge
         | `Rebase_merge
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_merge_requests_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_model_experiments_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_model_registry_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_monitor_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_pages_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | `String "public" -> Ok `Public
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"
        | `Public -> `String "public"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         | `Public
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_releases_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_repository_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_requirements_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_security_and_compliance_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_snippets_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_squash_option_ = struct
      let t_of_yojson = function
        | `String "always" -> Ok `Always
        | `String "default_off" -> Ok `Default_off
        | `String "default_on" -> Ok `Default_on
        | `String "never" -> Ok `Never
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Always -> `String "always"
        | `Default_off -> `String "default_off"
        | `Default_on -> `String "default_on"
        | `Never -> `String "never"

      type t =
        ([ `Always
         | `Default_off
         | `Default_on
         | `Never
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_tag_list_ = struct
      type t = string list [@@deriving show, eq]
    end

    module Override_params_topics_ = struct
      type t = string list [@@deriving show, eq]
    end

    module Override_params_visibility_ = struct
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

    module Override_params_wiki_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      name : string option; [@default None]
      namespace : string option; [@default None]
      override_params_allow_merge_on_skipped_pipeline_ : bool option;
          [@default None] [@key "override_params[allow_merge_on_skipped_pipeline]"]
      override_params_analytics_access_level_ : Override_params_analytics_access_level_.t option;
          [@default None] [@key "override_params[analytics_access_level]"]
      override_params_approvals_before_merge_ : int option;
          [@default None] [@key "override_params[approvals_before_merge]"]
      override_params_auto_cancel_pending_pipelines_ :
        Override_params_auto_cancel_pending_pipelines_.t option;
          [@default None] [@key "override_params[auto_cancel_pending_pipelines]"]
      override_params_auto_devops_deploy_strategy_ :
        Override_params_auto_devops_deploy_strategy_.t option;
          [@default None] [@key "override_params[auto_devops_deploy_strategy]"]
      override_params_auto_devops_enabled_ : bool option;
          [@default None] [@key "override_params[auto_devops_enabled]"]
      override_params_autoclose_referenced_issues_ : bool option;
          [@default None] [@key "override_params[autoclose_referenced_issues]"]
      override_params_avatar_ : string option; [@default None] [@key "override_params[avatar]"]
      override_params_build_git_strategy_ : Override_params_build_git_strategy_.t option;
          [@default None] [@key "override_params[build_git_strategy]"]
      override_params_build_timeout_ : int option;
          [@default None] [@key "override_params[build_timeout]"]
      override_params_builds_access_level_ : Override_params_builds_access_level_.t option;
          [@default None] [@key "override_params[builds_access_level]"]
      override_params_ci_config_path_ : string option;
          [@default None] [@key "override_params[ci_config_path]"]
      override_params_container_expiration_policy_attributes__cadence_ : string option;
          [@default None] [@key "override_params[container_expiration_policy_attributes][cadence]"]
      override_params_container_expiration_policy_attributes__enabled_ : bool option;
          [@default None] [@key "override_params[container_expiration_policy_attributes][enabled]"]
      override_params_container_expiration_policy_attributes__keep_n_ : int option;
          [@default None] [@key "override_params[container_expiration_policy_attributes][keep_n]"]
      override_params_container_expiration_policy_attributes__name_regex_ : string option;
          [@default None]
          [@key "override_params[container_expiration_policy_attributes][name_regex]"]
      override_params_container_expiration_policy_attributes__name_regex_keep_ : string option;
          [@default None]
          [@key "override_params[container_expiration_policy_attributes][name_regex_keep]"]
      override_params_container_expiration_policy_attributes__older_than_ : string option;
          [@default None]
          [@key "override_params[container_expiration_policy_attributes][older_than]"]
      override_params_container_registry_access_level_ :
        Override_params_container_registry_access_level_.t option;
          [@default None] [@key "override_params[container_registry_access_level]"]
      override_params_container_registry_enabled_ : bool option;
          [@default None] [@key "override_params[container_registry_enabled]"]
      override_params_description_ : string option;
          [@default None] [@key "override_params[description]"]
      override_params_emails_disabled_ : bool option;
          [@default None] [@key "override_params[emails_disabled]"]
      override_params_emails_enabled_ : bool option;
          [@default None] [@key "override_params[emails_enabled]"]
      override_params_enforce_auth_checks_on_uploads_ : bool option;
          [@default None] [@key "override_params[enforce_auth_checks_on_uploads]"]
      override_params_environments_access_level_ :
        Override_params_environments_access_level_.t option;
          [@default None] [@key "override_params[environments_access_level]"]
      override_params_external_authorization_classification_label_ : string option;
          [@default None] [@key "override_params[external_authorization_classification_label]"]
      override_params_feature_flags_access_level_ :
        Override_params_feature_flags_access_level_.t option;
          [@default None] [@key "override_params[feature_flags_access_level]"]
      override_params_forking_access_level_ : Override_params_forking_access_level_.t option;
          [@default None] [@key "override_params[forking_access_level]"]
      override_params_group_runners_enabled_ : bool option;
          [@default None] [@key "override_params[group_runners_enabled]"]
      override_params_infrastructure_access_level_ :
        Override_params_infrastructure_access_level_.t option;
          [@default None] [@key "override_params[infrastructure_access_level]"]
      override_params_issue_branch_template_ : string option;
          [@default None] [@key "override_params[issue_branch_template]"]
      override_params_issues_access_level_ : Override_params_issues_access_level_.t option;
          [@default None] [@key "override_params[issues_access_level]"]
      override_params_issues_enabled_ : bool option;
          [@default None] [@key "override_params[issues_enabled]"]
      override_params_jobs_enabled_ : bool option;
          [@default None] [@key "override_params[jobs_enabled]"]
      override_params_lfs_enabled_ : bool option;
          [@default None] [@key "override_params[lfs_enabled]"]
      override_params_merge_commit_template_ : string option;
          [@default None] [@key "override_params[merge_commit_template]"]
      override_params_merge_method_ : Override_params_merge_method_.t option;
          [@default None] [@key "override_params[merge_method]"]
      override_params_merge_requests_access_level_ :
        Override_params_merge_requests_access_level_.t option;
          [@default None] [@key "override_params[merge_requests_access_level]"]
      override_params_merge_requests_enabled_ : bool option;
          [@default None] [@key "override_params[merge_requests_enabled]"]
      override_params_mirror_ : bool option; [@default None] [@key "override_params[mirror]"]
      override_params_mirror_trigger_builds_ : bool option;
          [@default None] [@key "override_params[mirror_trigger_builds]"]
      override_params_model_experiments_access_level_ :
        Override_params_model_experiments_access_level_.t option;
          [@default None] [@key "override_params[model_experiments_access_level]"]
      override_params_model_registry_access_level_ :
        Override_params_model_registry_access_level_.t option;
          [@default None] [@key "override_params[model_registry_access_level]"]
      override_params_monitor_access_level_ : Override_params_monitor_access_level_.t option;
          [@default None] [@key "override_params[monitor_access_level]"]
      override_params_mr_default_target_self_ : bool option;
          [@default None] [@key "override_params[mr_default_target_self]"]
      override_params_only_allow_merge_if_all_discussions_are_resolved_ : bool option;
          [@default None] [@key "override_params[only_allow_merge_if_all_discussions_are_resolved]"]
      override_params_only_allow_merge_if_all_status_checks_passed_ : bool option;
          [@default None] [@key "override_params[only_allow_merge_if_all_status_checks_passed]"]
      override_params_only_allow_merge_if_pipeline_succeeds_ : bool option;
          [@default None] [@key "override_params[only_allow_merge_if_pipeline_succeeds]"]
      override_params_packages_enabled_ : bool option;
          [@default None] [@key "override_params[packages_enabled]"]
      override_params_pages_access_level_ : Override_params_pages_access_level_.t option;
          [@default None] [@key "override_params[pages_access_level]"]
      override_params_prevent_merge_without_jira_issue_ : bool option;
          [@default None] [@key "override_params[prevent_merge_without_jira_issue]"]
      override_params_printing_merge_request_link_enabled_ : bool option;
          [@default None] [@key "override_params[printing_merge_request_link_enabled]"]
      override_params_public_builds_ : bool option;
          [@default None] [@key "override_params[public_builds]"]
      override_params_public_jobs_ : bool option;
          [@default None] [@key "override_params[public_jobs]"]
      override_params_releases_access_level_ : Override_params_releases_access_level_.t option;
          [@default None] [@key "override_params[releases_access_level]"]
      override_params_remove_source_branch_after_merge_ : bool option;
          [@default None] [@key "override_params[remove_source_branch_after_merge]"]
      override_params_repository_access_level_ : Override_params_repository_access_level_.t option;
          [@default None] [@key "override_params[repository_access_level]"]
      override_params_repository_storage_ : string option;
          [@default None] [@key "override_params[repository_storage]"]
      override_params_request_access_enabled_ : bool option;
          [@default None] [@key "override_params[request_access_enabled]"]
      override_params_requirements_access_level_ :
        Override_params_requirements_access_level_.t option;
          [@default None] [@key "override_params[requirements_access_level]"]
      override_params_resolve_outdated_diff_discussions_ : bool option;
          [@default None] [@key "override_params[resolve_outdated_diff_discussions]"]
      override_params_security_and_compliance_access_level_ :
        Override_params_security_and_compliance_access_level_.t option;
          [@default None] [@key "override_params[security_and_compliance_access_level]"]
      override_params_service_desk_enabled_ : bool option;
          [@default None] [@key "override_params[service_desk_enabled]"]
      override_params_shared_runners_enabled_ : bool option;
          [@default None] [@key "override_params[shared_runners_enabled]"]
      override_params_show_default_award_emojis_ : bool option;
          [@default None] [@key "override_params[show_default_award_emojis]"]
      override_params_show_diff_preview_in_email_ : bool option;
          [@default None] [@key "override_params[show_diff_preview_in_email]"]
      override_params_snippets_access_level_ : Override_params_snippets_access_level_.t option;
          [@default None] [@key "override_params[snippets_access_level]"]
      override_params_snippets_enabled_ : bool option;
          [@default None] [@key "override_params[snippets_enabled]"]
      override_params_squash_commit_template_ : string option;
          [@default None] [@key "override_params[squash_commit_template]"]
      override_params_squash_option_ : Override_params_squash_option_.t option;
          [@default None] [@key "override_params[squash_option]"]
      override_params_suggestion_commit_message_ : string option;
          [@default None] [@key "override_params[suggestion_commit_message]"]
      override_params_tag_list_ : Override_params_tag_list_.t option;
          [@default None] [@key "override_params[tag_list]"]
      override_params_topics_ : Override_params_topics_.t option;
          [@default None] [@key "override_params[topics]"]
      override_params_visibility_ : Override_params_visibility_.t option;
          [@default None] [@key "override_params[visibility]"]
      override_params_warn_about_potentially_unwanted_characters_ : bool option;
          [@default None] [@key "override_params[warn_about_potentially_unwanted_characters]"]
      override_params_wiki_access_level_ : Override_params_wiki_access_level_.t option;
          [@default None] [@key "override_params[wiki_access_level]"]
      override_params_wiki_enabled_ : bool option;
          [@default None] [@key "override_params[wiki_enabled]"]
      overwrite : bool; [@default false]
      path : string;
      url : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" / "remote-import"

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Too_many_requests = struct end
    module Service_unavailable = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Too_many_requests
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("429", fun _ -> Ok `Too_many_requests);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v4/projects/remote-import"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsImportAuthorize = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" / "import" / "authorize"

  module Responses = struct
    module Created = struct end

    type t = [ `Created ] [@@deriving show, eq]

    let t = [ ("201", fun _ -> Ok `Created) ]
  end

  let url = "/api/v4/projects/import/authorize"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsImportRelationAuthorize = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" / "import-relation" / "authorize"

  module Responses = struct
    module Created = struct end

    type t = [ `Created ] [@@deriving show, eq]

    let t = [ ("201", fun _ -> Ok `Created) ]
  end

  let url = "/api/v4/projects/import-relation/authorize"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsImportRelation = struct
  module Parameters = struct
    type t = {
      file : string;
      file_etag : string option; [@default None] [@key "file.etag"]
      file_md5 : string option; [@default None] [@key "file.md5"]
      file_name : string option; [@default None] [@key "file.name"]
      file_path : string option; [@default None] [@key "file.path"]
      file_remote_id : string option; [@default None] [@key "file.remote_id"]
      file_remote_url : string option; [@default None] [@key "file.remote_url"]
      file_sha1 : string option; [@default None] [@key "file.sha1"]
      file_sha256 : string option; [@default None] [@key "file.sha256"]
      file_size : int option; [@default None] [@key "file.size"]
      file_type : string option; [@default None] [@key "file.type"]
      path : string;
      relation : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" / "import-relation"

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Service_unavailable = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v4/projects/import-relation"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsImport = struct
  module Parameters = struct
    module Override_params_analytics_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_auto_cancel_pending_pipelines_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"

      type t =
        ([ `Disabled
         | `Enabled
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_auto_devops_deploy_strategy_ = struct
      let t_of_yojson = function
        | `String "continuous" -> Ok `Continuous
        | `String "manual" -> Ok `Manual
        | `String "timed_incremental" -> Ok `Timed_incremental
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Continuous -> `String "continuous"
        | `Manual -> `String "manual"
        | `Timed_incremental -> `String "timed_incremental"

      type t =
        ([ `Continuous
         | `Manual
         | `Timed_incremental
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_build_git_strategy_ = struct
      let t_of_yojson = function
        | `String "clone" -> Ok `Clone
        | `String "fetch" -> Ok `Fetch
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Clone -> `String "clone"
        | `Fetch -> `String "fetch"

      type t =
        ([ `Clone
         | `Fetch
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_builds_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_container_registry_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_environments_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_feature_flags_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_forking_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_infrastructure_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_issues_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_merge_method_ = struct
      let t_of_yojson = function
        | `String "ff" -> Ok `Ff
        | `String "merge" -> Ok `Merge
        | `String "rebase_merge" -> Ok `Rebase_merge
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Ff -> `String "ff"
        | `Merge -> `String "merge"
        | `Rebase_merge -> `String "rebase_merge"

      type t =
        ([ `Ff
         | `Merge
         | `Rebase_merge
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_merge_requests_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_model_experiments_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_model_registry_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_monitor_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_pages_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | `String "public" -> Ok `Public
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"
        | `Public -> `String "public"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         | `Public
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_releases_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_repository_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_requirements_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_security_and_compliance_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_snippets_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_squash_option_ = struct
      let t_of_yojson = function
        | `String "always" -> Ok `Always
        | `String "default_off" -> Ok `Default_off
        | `String "default_on" -> Ok `Default_on
        | `String "never" -> Ok `Never
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Always -> `String "always"
        | `Default_off -> `String "default_off"
        | `Default_on -> `String "default_on"
        | `Never -> `String "never"

      type t =
        ([ `Always
         | `Default_off
         | `Default_on
         | `Never
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Override_params_tag_list_ = struct
      type t = string list [@@deriving show, eq]
    end

    module Override_params_topics_ = struct
      type t = string list [@@deriving show, eq]
    end

    module Override_params_visibility_ = struct
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

    module Override_params_wiki_access_level_ = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | `String "private" -> Ok `Private
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"
        | `Private -> `String "private"

      type t =
        ([ `Disabled
         | `Enabled
         | `Private
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      file : string;
      file_etag : string option; [@default None] [@key "file.etag"]
      file_md5 : string option; [@default None] [@key "file.md5"]
      file_name : string option; [@default None] [@key "file.name"]
      file_path : string option; [@default None] [@key "file.path"]
      file_remote_id : string option; [@default None] [@key "file.remote_id"]
      file_remote_url : string option; [@default None] [@key "file.remote_url"]
      file_sha1 : string option; [@default None] [@key "file.sha1"]
      file_sha256 : string option; [@default None] [@key "file.sha256"]
      file_size : int option; [@default None] [@key "file.size"]
      file_type : string option; [@default None] [@key "file.type"]
      name : string option; [@default None]
      namespace : string option; [@default None]
      override_params_allow_merge_on_skipped_pipeline_ : bool option;
          [@default None] [@key "override_params[allow_merge_on_skipped_pipeline]"]
      override_params_analytics_access_level_ : Override_params_analytics_access_level_.t option;
          [@default None] [@key "override_params[analytics_access_level]"]
      override_params_approvals_before_merge_ : int option;
          [@default None] [@key "override_params[approvals_before_merge]"]
      override_params_auto_cancel_pending_pipelines_ :
        Override_params_auto_cancel_pending_pipelines_.t option;
          [@default None] [@key "override_params[auto_cancel_pending_pipelines]"]
      override_params_auto_devops_deploy_strategy_ :
        Override_params_auto_devops_deploy_strategy_.t option;
          [@default None] [@key "override_params[auto_devops_deploy_strategy]"]
      override_params_auto_devops_enabled_ : bool option;
          [@default None] [@key "override_params[auto_devops_enabled]"]
      override_params_autoclose_referenced_issues_ : bool option;
          [@default None] [@key "override_params[autoclose_referenced_issues]"]
      override_params_avatar_ : string option; [@default None] [@key "override_params[avatar]"]
      override_params_build_git_strategy_ : Override_params_build_git_strategy_.t option;
          [@default None] [@key "override_params[build_git_strategy]"]
      override_params_build_timeout_ : int option;
          [@default None] [@key "override_params[build_timeout]"]
      override_params_builds_access_level_ : Override_params_builds_access_level_.t option;
          [@default None] [@key "override_params[builds_access_level]"]
      override_params_ci_config_path_ : string option;
          [@default None] [@key "override_params[ci_config_path]"]
      override_params_container_expiration_policy_attributes__cadence_ : string option;
          [@default None] [@key "override_params[container_expiration_policy_attributes][cadence]"]
      override_params_container_expiration_policy_attributes__enabled_ : bool option;
          [@default None] [@key "override_params[container_expiration_policy_attributes][enabled]"]
      override_params_container_expiration_policy_attributes__keep_n_ : int option;
          [@default None] [@key "override_params[container_expiration_policy_attributes][keep_n]"]
      override_params_container_expiration_policy_attributes__name_regex_ : string option;
          [@default None]
          [@key "override_params[container_expiration_policy_attributes][name_regex]"]
      override_params_container_expiration_policy_attributes__name_regex_keep_ : string option;
          [@default None]
          [@key "override_params[container_expiration_policy_attributes][name_regex_keep]"]
      override_params_container_expiration_policy_attributes__older_than_ : string option;
          [@default None]
          [@key "override_params[container_expiration_policy_attributes][older_than]"]
      override_params_container_registry_access_level_ :
        Override_params_container_registry_access_level_.t option;
          [@default None] [@key "override_params[container_registry_access_level]"]
      override_params_container_registry_enabled_ : bool option;
          [@default None] [@key "override_params[container_registry_enabled]"]
      override_params_description_ : string option;
          [@default None] [@key "override_params[description]"]
      override_params_emails_disabled_ : bool option;
          [@default None] [@key "override_params[emails_disabled]"]
      override_params_emails_enabled_ : bool option;
          [@default None] [@key "override_params[emails_enabled]"]
      override_params_enforce_auth_checks_on_uploads_ : bool option;
          [@default None] [@key "override_params[enforce_auth_checks_on_uploads]"]
      override_params_environments_access_level_ :
        Override_params_environments_access_level_.t option;
          [@default None] [@key "override_params[environments_access_level]"]
      override_params_external_authorization_classification_label_ : string option;
          [@default None] [@key "override_params[external_authorization_classification_label]"]
      override_params_feature_flags_access_level_ :
        Override_params_feature_flags_access_level_.t option;
          [@default None] [@key "override_params[feature_flags_access_level]"]
      override_params_forking_access_level_ : Override_params_forking_access_level_.t option;
          [@default None] [@key "override_params[forking_access_level]"]
      override_params_group_runners_enabled_ : bool option;
          [@default None] [@key "override_params[group_runners_enabled]"]
      override_params_infrastructure_access_level_ :
        Override_params_infrastructure_access_level_.t option;
          [@default None] [@key "override_params[infrastructure_access_level]"]
      override_params_issue_branch_template_ : string option;
          [@default None] [@key "override_params[issue_branch_template]"]
      override_params_issues_access_level_ : Override_params_issues_access_level_.t option;
          [@default None] [@key "override_params[issues_access_level]"]
      override_params_issues_enabled_ : bool option;
          [@default None] [@key "override_params[issues_enabled]"]
      override_params_jobs_enabled_ : bool option;
          [@default None] [@key "override_params[jobs_enabled]"]
      override_params_lfs_enabled_ : bool option;
          [@default None] [@key "override_params[lfs_enabled]"]
      override_params_merge_commit_template_ : string option;
          [@default None] [@key "override_params[merge_commit_template]"]
      override_params_merge_method_ : Override_params_merge_method_.t option;
          [@default None] [@key "override_params[merge_method]"]
      override_params_merge_requests_access_level_ :
        Override_params_merge_requests_access_level_.t option;
          [@default None] [@key "override_params[merge_requests_access_level]"]
      override_params_merge_requests_enabled_ : bool option;
          [@default None] [@key "override_params[merge_requests_enabled]"]
      override_params_mirror_ : bool option; [@default None] [@key "override_params[mirror]"]
      override_params_mirror_trigger_builds_ : bool option;
          [@default None] [@key "override_params[mirror_trigger_builds]"]
      override_params_model_experiments_access_level_ :
        Override_params_model_experiments_access_level_.t option;
          [@default None] [@key "override_params[model_experiments_access_level]"]
      override_params_model_registry_access_level_ :
        Override_params_model_registry_access_level_.t option;
          [@default None] [@key "override_params[model_registry_access_level]"]
      override_params_monitor_access_level_ : Override_params_monitor_access_level_.t option;
          [@default None] [@key "override_params[monitor_access_level]"]
      override_params_mr_default_target_self_ : bool option;
          [@default None] [@key "override_params[mr_default_target_self]"]
      override_params_only_allow_merge_if_all_discussions_are_resolved_ : bool option;
          [@default None] [@key "override_params[only_allow_merge_if_all_discussions_are_resolved]"]
      override_params_only_allow_merge_if_all_status_checks_passed_ : bool option;
          [@default None] [@key "override_params[only_allow_merge_if_all_status_checks_passed]"]
      override_params_only_allow_merge_if_pipeline_succeeds_ : bool option;
          [@default None] [@key "override_params[only_allow_merge_if_pipeline_succeeds]"]
      override_params_packages_enabled_ : bool option;
          [@default None] [@key "override_params[packages_enabled]"]
      override_params_pages_access_level_ : Override_params_pages_access_level_.t option;
          [@default None] [@key "override_params[pages_access_level]"]
      override_params_prevent_merge_without_jira_issue_ : bool option;
          [@default None] [@key "override_params[prevent_merge_without_jira_issue]"]
      override_params_printing_merge_request_link_enabled_ : bool option;
          [@default None] [@key "override_params[printing_merge_request_link_enabled]"]
      override_params_public_builds_ : bool option;
          [@default None] [@key "override_params[public_builds]"]
      override_params_public_jobs_ : bool option;
          [@default None] [@key "override_params[public_jobs]"]
      override_params_releases_access_level_ : Override_params_releases_access_level_.t option;
          [@default None] [@key "override_params[releases_access_level]"]
      override_params_remove_source_branch_after_merge_ : bool option;
          [@default None] [@key "override_params[remove_source_branch_after_merge]"]
      override_params_repository_access_level_ : Override_params_repository_access_level_.t option;
          [@default None] [@key "override_params[repository_access_level]"]
      override_params_repository_storage_ : string option;
          [@default None] [@key "override_params[repository_storage]"]
      override_params_request_access_enabled_ : bool option;
          [@default None] [@key "override_params[request_access_enabled]"]
      override_params_requirements_access_level_ :
        Override_params_requirements_access_level_.t option;
          [@default None] [@key "override_params[requirements_access_level]"]
      override_params_resolve_outdated_diff_discussions_ : bool option;
          [@default None] [@key "override_params[resolve_outdated_diff_discussions]"]
      override_params_security_and_compliance_access_level_ :
        Override_params_security_and_compliance_access_level_.t option;
          [@default None] [@key "override_params[security_and_compliance_access_level]"]
      override_params_service_desk_enabled_ : bool option;
          [@default None] [@key "override_params[service_desk_enabled]"]
      override_params_shared_runners_enabled_ : bool option;
          [@default None] [@key "override_params[shared_runners_enabled]"]
      override_params_show_default_award_emojis_ : bool option;
          [@default None] [@key "override_params[show_default_award_emojis]"]
      override_params_show_diff_preview_in_email_ : bool option;
          [@default None] [@key "override_params[show_diff_preview_in_email]"]
      override_params_snippets_access_level_ : Override_params_snippets_access_level_.t option;
          [@default None] [@key "override_params[snippets_access_level]"]
      override_params_snippets_enabled_ : bool option;
          [@default None] [@key "override_params[snippets_enabled]"]
      override_params_squash_commit_template_ : string option;
          [@default None] [@key "override_params[squash_commit_template]"]
      override_params_squash_option_ : Override_params_squash_option_.t option;
          [@default None] [@key "override_params[squash_option]"]
      override_params_suggestion_commit_message_ : string option;
          [@default None] [@key "override_params[suggestion_commit_message]"]
      override_params_tag_list_ : Override_params_tag_list_.t option;
          [@default None] [@key "override_params[tag_list]"]
      override_params_topics_ : Override_params_topics_.t option;
          [@default None] [@key "override_params[topics]"]
      override_params_visibility_ : Override_params_visibility_.t option;
          [@default None] [@key "override_params[visibility]"]
      override_params_warn_about_potentially_unwanted_characters_ : bool option;
          [@default None] [@key "override_params[warn_about_potentially_unwanted_characters]"]
      override_params_wiki_access_level_ : Override_params_wiki_access_level_.t option;
          [@default None] [@key "override_params[wiki_access_level]"]
      override_params_wiki_enabled_ : bool option;
          [@default None] [@key "override_params[wiki_enabled]"]
      overwrite : bool; [@default false]
      path : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" / "import"

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Service_unavailable = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Service_unavailable
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("503", fun _ -> Ok `Service_unavailable);
      ]
  end

  let url = "/api/v4/projects/import"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end
