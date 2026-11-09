module Get_user_installation = struct
  module Parameters = struct
    type t = { username : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Installation.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/users/{username}/installation"

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

module List_subscriptions_for_authenticated_user_stubbed = struct
  module Parameters = struct
    type t = {
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
      type t = Githubc2_components.User_marketplace_purchase.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
      ]
  end

  let url = "/user/marketplace_purchases/stubbed"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_subscriptions_for_authenticated_user = struct
  module Parameters = struct
    type t = {
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
      type t = Githubc2_components.User_marketplace_purchase.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Unauthorized = struct
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
      | `Unauthorized of Unauthorized.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/marketplace_purchases"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_repo_from_installation_for_authenticated_user = struct
  module Parameters = struct
    type t = {
      installation_id : int;
      repository_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
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

    module Unprocessable_entity = struct end

    type t =
      [ `No_content
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/user/installations/{installation_id}/repositories/{repository_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("installation_id", Var (params.installation_id, Int));
           ("repository_id", Var (params.repository_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_repo_to_installation_for_authenticated_user = struct
  module Parameters = struct
    type t = {
      installation_id : int;
      repository_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
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
      [ `No_content
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/installations/{installation_id}/repositories/{repository_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("installation_id", Var (params.installation_id, Int));
           ("repository_id", Var (params.repository_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module List_installation_repos_for_authenticated_user = struct
  module Parameters = struct
    type t = {
      installation_id : int;
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
        module Repositories = struct
          module Items = struct
            module All_of = struct
              module Primary = struct
                module Code_search_index_status = struct
                  module Primary = struct
                    type t = {
                      lexical_commit_sha : string option; [@default None]
                      lexical_search_ok : bool option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Custom_properties = struct
                  include
                    Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
                end

                module Merge_commit_message = struct
                  let t_of_yojson = function
                    | `String "BLANK" -> Ok `BLANK
                    | `String "PR_BODY" -> Ok `PR_BODY
                    | `String "PR_TITLE" -> Ok `PR_TITLE
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `BLANK -> `String "BLANK"
                    | `PR_BODY -> `String "PR_BODY"
                    | `PR_TITLE -> `String "PR_TITLE"

                  type t =
                    ([ `BLANK
                     | `PR_BODY
                     | `PR_TITLE
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Merge_commit_title = struct
                  let t_of_yojson = function
                    | `String "MERGE_MESSAGE" -> Ok `MERGE_MESSAGE
                    | `String "PR_TITLE" -> Ok `PR_TITLE
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `MERGE_MESSAGE -> `String "MERGE_MESSAGE"
                    | `PR_TITLE -> `String "PR_TITLE"

                  type t =
                    ([ `MERGE_MESSAGE
                     | `PR_TITLE
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Permissions = struct
                  module Primary = struct
                    type t = {
                      admin : bool;
                      maintain : bool option; [@default None]
                      pull : bool;
                      push : bool;
                      triage : bool option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Pull_request_creation_policy = struct
                  let t_of_yojson = function
                    | `String "all" -> Ok `All
                    | `String "collaborators_only" -> Ok `Collaborators_only
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `All -> `String "all"
                    | `Collaborators_only -> `String "collaborators_only"

                  type t =
                    ([ `All
                     | `Collaborators_only
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Squash_merge_commit_message = struct
                  let t_of_yojson = function
                    | `String "BLANK" -> Ok `BLANK
                    | `String "COMMIT_MESSAGES" -> Ok `COMMIT_MESSAGES
                    | `String "PR_BODY" -> Ok `PR_BODY
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `BLANK -> `String "BLANK"
                    | `COMMIT_MESSAGES -> `String "COMMIT_MESSAGES"
                    | `PR_BODY -> `String "PR_BODY"

                  type t =
                    ([ `BLANK
                     | `COMMIT_MESSAGES
                     | `PR_BODY
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Squash_merge_commit_title = struct
                  let t_of_yojson = function
                    | `String "COMMIT_OR_PR_TITLE" -> Ok `COMMIT_OR_PR_TITLE
                    | `String "PR_TITLE" -> Ok `PR_TITLE
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `COMMIT_OR_PR_TITLE -> `String "COMMIT_OR_PR_TITLE"
                    | `PR_TITLE -> `String "PR_TITLE"

                  type t =
                    ([ `COMMIT_OR_PR_TITLE
                     | `PR_TITLE
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Topics = struct
                  type t = string list
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                type t = {
                  allow_auto_merge : bool; [@default false]
                  allow_forking : bool option; [@default None]
                  allow_merge_commit : bool; [@default true]
                  allow_rebase_merge : bool; [@default true]
                  allow_squash_merge : bool; [@default true]
                  allow_update_branch : bool; [@default false]
                  anonymous_access_enabled : bool option; [@default None]
                  archive_url : string;
                  archived : bool; [@default false]
                  assignees_url : string;
                  blobs_url : string;
                  branches_url : string;
                  clone_url : string;
                  code_search_index_status : Code_search_index_status.t option; [@default None]
                  collaborators_url : string;
                  comments_url : string;
                  commits_url : string;
                  compare_url : string;
                  contents_url : string;
                  contributors_url : string;
                  created_at : string option; [@default None]
                  custom_properties : Custom_properties.t option; [@default None]
                  default_branch : string;
                  delete_branch_on_merge : bool; [@default false]
                  deployments_url : string;
                  description : string option; [@default None]
                  disabled : bool;
                  downloads_url : string;
                  events_url : string;
                  fork : bool;
                  forks : int;
                  forks_count : int;
                  forks_url : string;
                  full_name : string;
                  git_commits_url : string;
                  git_refs_url : string;
                  git_tags_url : string;
                  git_url : string;
                  has_discussions : bool; [@default false]
                  has_downloads : bool; [@default true]
                  has_issues : bool; [@default true]
                  has_pages : bool;
                  has_projects : bool; [@default true]
                  has_pull_requests : bool; [@default true]
                  has_wiki : bool; [@default true]
                  homepage : string option; [@default None]
                  hooks_url : string;
                  html_url : string;
                  id : int64;
                  is_template : bool; [@default false]
                  issue_comment_url : string;
                  issue_events_url : string;
                  issues_url : string;
                  keys_url : string;
                  labels_url : string;
                  language : string option; [@default None]
                  languages_url : string;
                  license : Githubc2_components.Nullable_license_simple.t option; [@default None]
                  master_branch : string option; [@default None]
                  merge_commit_message : Merge_commit_message.t option; [@default None]
                  merge_commit_title : Merge_commit_title.t option; [@default None]
                  merges_url : string;
                  milestones_url : string;
                  mirror_url : string option; [@default None]
                  name : string;
                  node_id : string;
                  notifications_url : string;
                  open_issues : int;
                  open_issues_count : int;
                  owner : Githubc2_components.Simple_user.t;
                  permissions : Permissions.t option; [@default None]
                  private_ : bool; [@default false] [@key "private"]
                  pull_request_creation_policy : Pull_request_creation_policy.t option;
                      [@default None]
                  pulls_url : string;
                  pushed_at : string option; [@default None]
                  releases_url : string;
                  size : int;
                  squash_merge_commit_message : Squash_merge_commit_message.t option;
                      [@default None]
                  squash_merge_commit_title : Squash_merge_commit_title.t option; [@default None]
                  ssh_url : string;
                  stargazers_count : int;
                  stargazers_url : string;
                  starred_at : string option; [@default None]
                  statuses_url : string;
                  subscribers_url : string;
                  subscription_url : string;
                  svn_url : string;
                  tags_url : string;
                  teams_url : string;
                  temp_clone_token : string option; [@default None]
                  topics : Topics.t option; [@default None]
                  trees_url : string;
                  updated_at : string option; [@default None]
                  url : string;
                  use_squash_pr_title_as_default : bool; [@default false]
                  visibility : string; [@default "public"]
                  watchers : int;
                  watchers_count : int;
                  web_commit_signoff_required : bool; [@default false]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            module T = struct
              module Primary = struct
                module Code_search_index_status = struct
                  module Primary = struct
                    type t = {
                      lexical_commit_sha : string option; [@default None]
                      lexical_search_ok : bool option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Custom_properties = struct
                  include
                    Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
                end

                module Merge_commit_message = struct
                  let t_of_yojson = function
                    | `String "BLANK" -> Ok `BLANK
                    | `String "PR_BODY" -> Ok `PR_BODY
                    | `String "PR_TITLE" -> Ok `PR_TITLE
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `BLANK -> `String "BLANK"
                    | `PR_BODY -> `String "PR_BODY"
                    | `PR_TITLE -> `String "PR_TITLE"

                  type t =
                    ([ `BLANK
                     | `PR_BODY
                     | `PR_TITLE
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Merge_commit_title = struct
                  let t_of_yojson = function
                    | `String "MERGE_MESSAGE" -> Ok `MERGE_MESSAGE
                    | `String "PR_TITLE" -> Ok `PR_TITLE
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `MERGE_MESSAGE -> `String "MERGE_MESSAGE"
                    | `PR_TITLE -> `String "PR_TITLE"

                  type t =
                    ([ `MERGE_MESSAGE
                     | `PR_TITLE
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Permissions = struct
                  module Primary = struct
                    type t = {
                      admin : bool;
                      maintain : bool option; [@default None]
                      pull : bool;
                      push : bool;
                      triage : bool option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Pull_request_creation_policy = struct
                  let t_of_yojson = function
                    | `String "all" -> Ok `All
                    | `String "collaborators_only" -> Ok `Collaborators_only
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `All -> `String "all"
                    | `Collaborators_only -> `String "collaborators_only"

                  type t =
                    ([ `All
                     | `Collaborators_only
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Squash_merge_commit_message = struct
                  let t_of_yojson = function
                    | `String "BLANK" -> Ok `BLANK
                    | `String "COMMIT_MESSAGES" -> Ok `COMMIT_MESSAGES
                    | `String "PR_BODY" -> Ok `PR_BODY
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `BLANK -> `String "BLANK"
                    | `COMMIT_MESSAGES -> `String "COMMIT_MESSAGES"
                    | `PR_BODY -> `String "PR_BODY"

                  type t =
                    ([ `BLANK
                     | `COMMIT_MESSAGES
                     | `PR_BODY
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Squash_merge_commit_title = struct
                  let t_of_yojson = function
                    | `String "COMMIT_OR_PR_TITLE" -> Ok `COMMIT_OR_PR_TITLE
                    | `String "PR_TITLE" -> Ok `PR_TITLE
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `COMMIT_OR_PR_TITLE -> `String "COMMIT_OR_PR_TITLE"
                    | `PR_TITLE -> `String "PR_TITLE"

                  type t =
                    ([ `COMMIT_OR_PR_TITLE
                     | `PR_TITLE
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Topics = struct
                  type t = string list
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                type t = {
                  allow_auto_merge : bool; [@default false]
                  allow_forking : bool option; [@default None]
                  allow_merge_commit : bool; [@default true]
                  allow_rebase_merge : bool; [@default true]
                  allow_squash_merge : bool; [@default true]
                  allow_update_branch : bool; [@default false]
                  anonymous_access_enabled : bool option; [@default None]
                  archive_url : string;
                  archived : bool; [@default false]
                  assignees_url : string;
                  blobs_url : string;
                  branches_url : string;
                  clone_url : string;
                  code_search_index_status : Code_search_index_status.t option; [@default None]
                  collaborators_url : string;
                  comments_url : string;
                  commits_url : string;
                  compare_url : string;
                  contents_url : string;
                  contributors_url : string;
                  created_at : string option; [@default None]
                  custom_properties : Custom_properties.t option; [@default None]
                  default_branch : string;
                  delete_branch_on_merge : bool; [@default false]
                  deployments_url : string;
                  description : string option; [@default None]
                  disabled : bool;
                  downloads_url : string;
                  events_url : string;
                  fork : bool;
                  forks : int;
                  forks_count : int;
                  forks_url : string;
                  full_name : string;
                  git_commits_url : string;
                  git_refs_url : string;
                  git_tags_url : string;
                  git_url : string;
                  has_discussions : bool; [@default false]
                  has_downloads : bool; [@default true]
                  has_issues : bool; [@default true]
                  has_pages : bool;
                  has_projects : bool; [@default true]
                  has_pull_requests : bool; [@default true]
                  has_wiki : bool; [@default true]
                  homepage : string option; [@default None]
                  hooks_url : string;
                  html_url : string;
                  id : int64;
                  is_template : bool; [@default false]
                  issue_comment_url : string;
                  issue_events_url : string;
                  issues_url : string;
                  keys_url : string;
                  labels_url : string;
                  language : string option; [@default None]
                  languages_url : string;
                  license : Githubc2_components.Nullable_license_simple.t option; [@default None]
                  master_branch : string option; [@default None]
                  merge_commit_message : Merge_commit_message.t option; [@default None]
                  merge_commit_title : Merge_commit_title.t option; [@default None]
                  merges_url : string;
                  milestones_url : string;
                  mirror_url : string option; [@default None]
                  name : string;
                  node_id : string;
                  notifications_url : string;
                  open_issues : int;
                  open_issues_count : int;
                  owner : Githubc2_components.Simple_user.t;
                  permissions : Permissions.t option; [@default None]
                  private_ : bool; [@default false] [@key "private"]
                  pull_request_creation_policy : Pull_request_creation_policy.t option;
                      [@default None]
                  pulls_url : string;
                  pushed_at : string option; [@default None]
                  releases_url : string;
                  size : int;
                  squash_merge_commit_message : Squash_merge_commit_message.t option;
                      [@default None]
                  squash_merge_commit_title : Squash_merge_commit_title.t option; [@default None]
                  ssh_url : string;
                  stargazers_count : int;
                  stargazers_url : string;
                  starred_at : string option; [@default None]
                  statuses_url : string;
                  subscribers_url : string;
                  subscription_url : string;
                  svn_url : string;
                  tags_url : string;
                  teams_url : string;
                  temp_clone_token : string option; [@default None]
                  topics : Topics.t option; [@default None]
                  trees_url : string;
                  updated_at : string option; [@default None]
                  url : string;
                  use_squash_pr_title_as_default : bool; [@default false]
                  visibility : string; [@default "public"]
                  watchers : int;
                  watchers_count : int;
                  web_commit_signoff_required : bool; [@default false]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = T.t [@@deriving yojson { strict = false; meta = false }, show, eq]

            let of_yojson json =
              let open CCResult in
              flat_map (fun _ -> T.of_yojson json) (All_of.of_yojson json)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          repositories : Repositories.t;
          repository_selection : string option; [@default None]
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/user/installations/{installation_id}/repositories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_installations_for_authenticated_user = struct
  module Parameters = struct
    type t = {
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
        module Installations = struct
          type t = Githubc2_components.Installation.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          installations : Installations.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_modified = struct end

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
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/user/installations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_repo_installation = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Installation.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Moved_permanently = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/installation"

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

module Get_org_installation = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Installation.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/installation"

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

module List_accounts_for_plan_stubbed = struct
  module Parameters = struct
    module Direction = struct
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

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 30]
      plan_id : int;
      sort : Sort.t; [@default `Created]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Marketplace_purchase.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
      ]
  end

  let url = "/marketplace_listing/stubbed/plans/{plan_id}/accounts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("plan_id", Var (params.plan_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Option (Enum Direction.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_plans_stubbed = struct
  module Parameters = struct
    type t = {
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
      type t = Githubc2_components.Marketplace_listing_plan.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
      ]
  end

  let url = "/marketplace_listing/stubbed/plans"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_subscription_plan_for_account_stubbed = struct
  module Parameters = struct
    type t = { account_id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Marketplace_purchase.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/marketplace_listing/stubbed/accounts/{account_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("account_id", Var (params.account_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_accounts_for_plan = struct
  module Parameters = struct
    module Direction = struct
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

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 30]
      plan_id : int;
      sort : Sort.t; [@default `Created]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Marketplace_purchase.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
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
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/marketplace_listing/plans/{plan_id}/accounts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("plan_id", Var (params.plan_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Option (Enum Direction.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_plans = struct
  module Parameters = struct
    type t = {
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
      type t = Githubc2_components.Marketplace_listing_plan.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
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
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/marketplace_listing/plans"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_subscription_plan_for_account = struct
  module Parameters = struct
    type t = { account_id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Marketplace_purchase.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
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
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/marketplace_listing/accounts/{account_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("account_id", Var (params.account_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Revoke_installation_access_token = struct
  module Parameters = struct end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/installation/token"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module List_repos_accessible_to_installation = struct
  module Parameters = struct
    type t = {
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
        module Repositories = struct
          type t = Githubc2_components.Repository.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          repositories : Repositories.t;
          repository_selection : string option; [@default None]
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_modified = struct end

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
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/installation/repositories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_by_slug = struct
  module Parameters = struct
    type t = { app_slug : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Integration.t
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

  let url = "/apps/{app_slug}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("app_slug", Var (params.app_slug, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Scope_token = struct
  module Parameters = struct
    type t = { client_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Repositories = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Repository_ids = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        access_token : string;
        permissions : Githubc2_components.App_permissions.t option; [@default None]
        repositories : Repositories.t option; [@default None]
        repository_ids : Repository_ids.t option; [@default None]
        target : string option; [@default None]
        target_id : int option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Authorization.t
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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/applications/{client_id}/token/scoped"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("client_id", Var (params.client_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Reset_token = struct
  module Parameters = struct
    type t = { client_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { access_token : string }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Authorization.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/applications/{client_id}/token"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("client_id", Var (params.client_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_token = struct
  module Parameters = struct
    type t = { client_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { access_token : string }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/applications/{client_id}/token"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("client_id", Var (params.client_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Check_token = struct
  module Parameters = struct
    type t = { client_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { access_token : string }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Authorization.t
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
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/applications/{client_id}/token"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("client_id", Var (params.client_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Delete_authorization = struct
  module Parameters = struct
    type t = { client_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { access_token : string }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/applications/{client_id}/grant"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("client_id", Var (params.client_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Unsuspend_installation = struct
  module Parameters = struct
    type t = { installation_id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/app/installations/{installation_id}/suspended"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Suspend_installation = struct
  module Parameters = struct
    type t = { installation_id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/app/installations/{installation_id}/suspended"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Create_installation_access_token = struct
  module Parameters = struct
    type t = { installation_id : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Repositories = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Repository_ids = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        permissions : Githubc2_components.App_permissions.t option; [@default None]
        repositories : Repositories.t option; [@default None]
        repository_ids : Repository_ids.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Installation_token.t
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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/app/installations/{installation_id}/access_tokens"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Delete_installation = struct
  module Parameters = struct
    type t = { installation_id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/app/installations/{installation_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_installation = struct
  module Parameters = struct
    type t = { installation_id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Installation.t
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

  let url = "/app/installations/{installation_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_installations = struct
  module Parameters = struct
    type t = {
      outdated : string option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 30]
      since : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option (string "since")
    /? option (string "outdated")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Installation.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/app/installations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("since", Var (params.since, Option String));
           ("outdated", Var (params.outdated, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_installation_requests_for_authenticated_app = struct
  module Parameters = struct
    type t = {
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
      type t = Githubc2_components.Integration_installation_request.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
      ]
  end

  let url = "/app/installation-requests"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Redeliver_webhook_delivery = struct
  module Parameters = struct
    type t = { delivery_id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module Accepted = struct
      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Accepted of Accepted.t
      | `Bad_request of Bad_request.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/app/hook/deliveries/{delivery_id}/attempts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("delivery_id", Var (params.delivery_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_webhook_delivery = struct
  module Parameters = struct
    type t = { delivery_id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Hook_delivery.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/app/hook/deliveries/{delivery_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("delivery_id", Var (params.delivery_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_webhook_deliveries = struct
  module Parameters = struct
    module Status = struct
      let t_of_yojson = function
        | `String "failure" -> Ok `Failure
        | `String "success" -> Ok `Success
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Failure -> `String "failure"
        | `Success -> `String "success"

      type t =
        ([ `Failure
         | `Success
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      cursor : string option; [@default None]
      per_page : int; [@default 30]
      status : Status.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default 30 (int "per_page")
    /? option (string "cursor")
    /? option
         (ud "status" (fun value -> CCResult.to_opt (Parameters.Status.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Hook_delivery_item.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/app/hook/deliveries"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("cursor", Var (params.cursor, Option String));
           ("status", Var (params.status, Option (Enum Status.t_to_yojson)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_webhook_config_for_app = struct
  module Parameters = struct end

  module Request_body = struct
    module Primary = struct
      type t = {
        content_type : string option; [@default None]
        insecure_ssl : Githubc2_components.Webhook_config_insecure_ssl.t option; [@default None]
        secret : string option; [@default None]
        url : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Webhook_config.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/app/hook/config"

  let make ~body =
   fun () ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Get_webhook_config_for_app = struct
  module Parameters = struct end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Webhook_config.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/app/hook/config"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_from_manifest = struct
  module Parameters = struct
    type t = { code : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module Created = struct
      module All_of = struct
        module Primary = struct
          module Events = struct
            type t = string list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Owner = struct
            type t =
              | Simple_user of Githubc2_components.Simple_user.t
              | Enterprise of Githubc2_components.Enterprise.t
            [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [
                   (fun v ->
                     map (fun v -> Simple_user v) (Githubc2_components.Simple_user.of_yojson v));
                   (fun v ->
                     map (fun v -> Enterprise v) (Githubc2_components.Enterprise.of_yojson v));
                 ])

            let to_yojson = function
              | Simple_user v -> Githubc2_components.Simple_user.to_yojson v
              | Enterprise v -> Githubc2_components.Enterprise.to_yojson v
          end

          module Permissions = struct
            module Primary = struct
              type t = {
                checks : string option; [@default None]
                contents : string option; [@default None]
                deployments : string option; [@default None]
                issues : string option; [@default None]
                metadata : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module Additional = struct
              type t = string [@@deriving yojson { strict = false; meta = false }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Additional)
          end

          type t = {
            client_id : string;
            client_secret : string;
            created_at : string;
            description : string option; [@default None]
            events : Events.t;
            external_url : string;
            html_url : string;
            id : int;
            installations_count : int option; [@default None]
            name : string;
            node_id : string;
            owner : Owner.t;
            pem : string;
            permissions : Permissions.t;
            slug : string option; [@default None]
            updated_at : string;
            webhook_secret : string option; [@default None]
          }
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module T = struct
        module Primary = struct
          module Events = struct
            type t = string list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Owner = struct
            type t =
              | Simple_user of Githubc2_components.Simple_user.t
              | Enterprise of Githubc2_components.Enterprise.t
            [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [
                   (fun v ->
                     map (fun v -> Simple_user v) (Githubc2_components.Simple_user.of_yojson v));
                   (fun v ->
                     map (fun v -> Enterprise v) (Githubc2_components.Enterprise.of_yojson v));
                 ])

            let to_yojson = function
              | Simple_user v -> Githubc2_components.Simple_user.to_yojson v
              | Enterprise v -> Githubc2_components.Enterprise.to_yojson v
          end

          module Permissions = struct
            module Primary = struct
              type t = {
                checks : string option; [@default None]
                contents : string option; [@default None]
                deployments : string option; [@default None]
                issues : string option; [@default None]
                metadata : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module Additional = struct
              type t = string [@@deriving yojson { strict = false; meta = false }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Additional)
          end

          type t = {
            client_id : string;
            client_secret : string;
            created_at : string;
            description : string option; [@default None]
            events : Events.t;
            external_url : string;
            html_url : string;
            id : int;
            installations_count : int option; [@default None]
            name : string;
            node_id : string;
            owner : Owner.t;
            pem : string;
            permissions : Permissions.t;
            slug : string option; [@default None]
            updated_at : string;
            webhook_secret : string option; [@default None]
          }
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = T.t [@@deriving yojson { strict = false; meta = false }, show, eq]

      let of_yojson json =
        let open CCResult in
        flat_map (fun _ -> T.of_yojson json) (All_of.of_yojson json)
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error_simple.t
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

  let url = "/app-manifests/{code}/conversions"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("code", Var (params.code, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_authenticated = struct
  module Parameters = struct end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Integration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/app"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
