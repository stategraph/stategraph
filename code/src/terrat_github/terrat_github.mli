type user_err =
  [ Githubc2_abb.call_err
  | `Unauthorized of Githubc2_components.Basic_error.t
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_modified
  | `Unauthorized of Githubc2_components.Basic_error.t
  ]
[@@deriving show]

type get_installation_access_token_err =
  [ Githubc2_abb.call_err
  | `Unauthorized of Githubc2_components.Basic_error.t
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_found of Githubc2_components.Basic_error.t
  | `Unprocessable_entity of Githubc2_components.Validation_error.t
  ]
[@@deriving show]

type get_user_installations_err =
  [ Githubc2_abb.call_err
  | `Unauthorized of Githubc2_components.Basic_error.t
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_modified
  ]
[@@deriving show]

type get_installation_repos_err =
  [ Githubc2_abb.call_err
  | `Not_modified
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_found of Githubc2_components.Basic_error.t
  | `Unauthorized of Githubc2_components.Basic_error.t
  ]
[@@deriving show]

type fetch_file_err =
  [ Githubc2_abb.call_err
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Found
  | `Not_file
  | `Not_modified
  ]
[@@deriving show]

type fetch_directory_err =
  [ Githubc2_abb.call_err
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Found
  | `Not_directory
  | `Not_modified
  ]
[@@deriving show]

type fetch_pull_request_err =
  [ Githubc2_abb.call_err
  | `Not_modified
  | `Not_found of Githubc2_components.Basic_error.t
  | `Not_acceptable of Githubc2_components.Basic_error.t
  | `Internal_server_error of Githubc2_components.Basic_error.t
  | `Service_unavailable of Githubc2_pulls.Get.Responses.Service_unavailable.t
  ]
[@@deriving show]

type fetch_diff_files_err =
  [ Githubc2_abb.call_err
  | `Not_found of Githubc2_components.Basic_error.t
  | `Internal_server_error of Githubc2_components.Basic_error.t
  | `Service_unavailable of Githubc2_repos.Compare_commits.Responses.Service_unavailable.t
  ]
[@@deriving show]

type fetch_repo_err =
  [ Githubc2_abb.call_err
  | `Moved_permanently of Githubc2_repos.Get.Responses.Moved_permanently.t
  | `Forbidden of Githubc2_repos.Get.Responses.Forbidden.t
  | `Not_found of Githubc2_repos.Get.Responses.Not_found.t
  ]
[@@deriving show]

type fetch_branch_err =
  [ Githubc2_abb.call_err
  | `Moved_permanently of Githubc2_repos.Get_branch.Responses.Moved_permanently.t
  | `Not_found of Githubc2_repos.Get_branch.Responses.Not_found.t
  ]
[@@deriving show]

type publish_comment_err =
  [ Githubc2_abb.call_err
  | `Forbidden of Githubc2_components.Basic_error.t
  | `Not_found of Githubc2_components.Basic_error.t
  | `Gone of Githubc2_components.Basic_error.t
  | `Unprocessable_entity of Githubc2_components.Validation_error.t
  ]
[@@deriving show]

type delete_comment_err = Githubc2_abb.call_err [@@deriving show]

type minimize_comment_err =
  [ Githubc2_abb.call_err
  | `Not_found
  ]
[@@deriving show]

type update_comment_err =
  [ Githubc2_abb.call_err
  | `Not_found
  | `Unprocessable_entity of Githubc2_components.Validation_error.t
  ]
[@@deriving show]

type fetch_pull_request_review_decision_err =
  [ Githubc2_abb.call_err
  | `Graphql_err of string list
  | `Not_found
  ]
[@@deriving show]

type publish_reaction_err =
  [ Githubc2_abb.call_err
  | `Unprocessable_entity of Githubc2_components.Validation_error.t
  ]
[@@deriving show]

type get_tree_err =
  [ Githubc2_abb.call_err
  | `Not_found of Githubc2_components.Basic_error.t
  | `Unprocessable_entity of Githubc2_components.Validation_error.t
  | `Conflict of Githubc2_components.Basic_error.t
  ]
[@@deriving show]

type get_team_membership_in_org_err = Githubc2_abb.call_err [@@deriving show]
type get_repo_collaborator_permission_err = Githubc2_abb.call_err [@@deriving show]
type get_org_membership_err = Githubc2_abb.call_err [@@deriving show]

module Commit_status : sig
  type create_err = Githubc2_abb.call_err [@@deriving show]

  type list_err =
    [ Githubc2_abb.call_err
    | `Error
    | `Moved_permanently of Githubc2_components.Basic_error.t
    ]
  [@@deriving show]

  module Create : sig
    module T : sig
      type t [@@deriving show]

      val make :
        ?target_url:string ->
        ?description:string ->
        ?context:string ->
        state:Githubc2_repos.Create_commit_status.Request_body.Primary.State.t ->
        unit ->
        t
    end

    type t = T.t list
  end

  val create :
    owner:string ->
    repo:string ->
    sha:string ->
    creates:Create.t ->
    Githubc2_abb.t ->
    (unit, [> create_err ]) result Abb.Future.t

  val list :
    owner:string ->
    repo:string ->
    sha:string ->
    Githubc2_abb.t ->
    (Githubc2_components.Status.t list, [> list_err ]) result Abb.Future.t
end

module Status_check : sig
  type list_err = Githubc2_abb.call_err [@@deriving show]

  val list :
    owner:string ->
    repo:string ->
    ref_:string ->
    Githubc2_abb.t ->
    (Githubc2_components.Check_run.t list, [> list_err ]) result Abb.Future.t
end

module Pull_request_reviews : sig
  type list_err =
    [ `Error
    | Githubc2_abb.call_err
    ]
  [@@deriving show]

  val list :
    owner:string ->
    repo:string ->
    pull_number:int ->
    Githubc2_abb.t ->
    (Githubc2_components.Pull_request_review.t list, [> list_err ]) result Abb.Future.t
end

val create : Terrat_config.Github.t -> Githubc2_abb.Authorization.t -> Githubc2_abb.t

val with_client :
  Terrat_config.Github.t ->
  Githubc2_abb.Authorization.t ->
  (Githubc2_abb.t -> 'a Abb.Future.t) ->
  'a Abb.Future.t

(** Perform a call but with a retry *)
val call :
  ?tries:int ->
  Githubc2_abb.t ->
  'a Openapi.Request.t ->
  ('a Openapi.Response.t, [> Githubc2_abb.call_err ]) result Abb.Future.t

val user :
  config:Terrat_config.Github.t ->
  access_token:string ->
  unit ->
  (Githubc2_users.Get_authenticated.Responses.OK.t, [> user_err ]) result Abb.Future.t

val get_installation_access_token :
  ?expiration_sec:float ->
  ?permissions:Githubc2_components.App_permissions.t ->
  Terrat_config.Github.t ->
  int ->
  (string, [> get_installation_access_token_err ]) result Abb.Future.t

val fetch_repo :
  owner:string ->
  repo:string ->
  Githubc2_abb.t ->
  (Githubc2_components.Full_repository.t, [> fetch_repo_err ]) result Abb.Future.t

val fetch_branch :
  owner:string ->
  repo:string ->
  branch:string ->
  Githubc2_abb.t ->
  (Githubc2_components.Branch_with_protection.t, [> fetch_branch_err ]) result Abb.Future.t

val fetch_file :
  owner:string ->
  repo:string ->
  ref_:string ->
  path:string ->
  Githubc2_abb.t ->
  (Githubc2_components.Content_file.t option, [> fetch_file_err ]) result Abb.Future.t

val fetch_directory :
  owner:string ->
  repo:string ->
  ref_:string ->
  path:string ->
  Githubc2_abb.t ->
  (Githubc2_components.Content_directory.t option, [> fetch_directory_err ]) result Abb.Future.t

val fetch_pull_request_files :
  owner:string ->
  repo:string ->
  pull_number:int ->
  Githubc2_abb.t ->
  (Githubc2_components.Diff_entry.t list, [> Githubc2_abb.call_err | `Error ]) result Abb.Future.t

val fetch_pull_request :
  owner:string ->
  repo:string ->
  pull_number:int ->
  Githubc2_abb.t ->
  (Githubc2_components.Pull_request.t, [> fetch_pull_request_err ]) result Abb.Future.t

val fetch_diff_files :
  owner:string ->
  repo:string ->
  base_ref:string ->
  branch_ref:string ->
  Githubc2_abb.t ->
  (Githubc2_components.Diff_entry.t list, [> fetch_diff_files_err | `Error ]) result Abb.Future.t

val get_user_installations :
  Githubc2_abb.t ->
  (Githubc2_components.Installation.t list, [> get_user_installations_err ]) result Abb.Future.t

val get_installation_repos :
  Githubc2_abb.t ->
  (Githubc2_components.Repository.t list, [> get_installation_repos_err ]) result Abb.Future.t

val find_workflow_file :
  owner:string ->
  repo:string ->
  Githubc2_abb.t ->
  (string option, [> get_installation_access_token_err ]) result Abb.Future.t

val load_workflow :
  ?override_path:string ->
  owner:string ->
  repo:string ->
  Githubc2_abb.t ->
  (int option, [> get_installation_access_token_err ]) result Abb.Future.t

val list_workflows :
  owner:string ->
  repo:string ->
  Githubc2_abb.t ->
  ((int * string * string) list, [> get_installation_access_token_err ]) result Abb.Future.t

val publish_comment :
  owner:string ->
  repo:string ->
  pull_number:int ->
  body:string ->
  Githubc2_abb.t ->
  (int, [> publish_comment_err ]) result Abb.Future.t

val delete_comment :
  owner:string ->
  repo:string ->
  comment_id:int ->
  Githubc2_abb.t ->
  (unit, [> delete_comment_err ]) result Abb.Future.t

val minimize_comment :
  owner:string ->
  repo:string ->
  comment_id:int ->
  Githubc2_abb.t ->
  (unit, [> minimize_comment_err ]) result Abb.Future.t

val update_comment :
  owner:string ->
  repo:string ->
  comment_id:int ->
  body:string ->
  Githubc2_abb.t ->
  (unit, [> update_comment_err ]) result Abb.Future.t

(** GitHub's [PullRequest.reviewDecision], which is its own verdict on the target branch's
    required-review rule, CODEOWNERS included. [None] means GitHub returned [null], which happens
    when the branch requires no reviews at all. *)
val fetch_pull_request_review_decision :
  owner:string ->
  repo:string ->
  pull_number:int ->
  Githubc2_abb.t ->
  (string option, [> fetch_pull_request_review_decision_err ]) result Abb.Future.t

val react_to_comment :
  ?content:Githubc2_reactions.Create_for_issue_comment.Request_body.Primary.Content.t ->
  owner:string ->
  repo:string ->
  comment_id:int ->
  Githubc2_abb.t ->
  (unit, [> publish_reaction_err ]) result Abb.Future.t

val get_tree :
  owner:string ->
  repo:string ->
  sha:string ->
  Githubc2_abb.t ->
  (string list, [> get_tree_err ]) result Abb.Future.t

val get_team_membership_in_org :
  org:string ->
  team:string ->
  user:string ->
  Githubc2_abb.t ->
  (bool, [> get_team_membership_in_org_err ]) result Abb.Future.t

val get_repo_collaborator_permission :
  org:string ->
  repo:string ->
  user:string ->
  Githubc2_abb.t ->
  (string option, [> get_repo_collaborator_permission_err ]) result Abb.Future.t

val get_org_membership :
  org:string ->
  user:string ->
  Githubc2_abb.t ->
  ([ `Admin | `User ] option, [> get_org_membership_err ]) result Abb.Future.t

(** GitHub does not include Oauth operations in their JSON schema, so implementing here. *)
module Oauth : sig
  type authorize_err =
    [ `Authorize_err of string
    | Abb_curl.Make(Abb).request_err
    ]
  [@@deriving show]

  type refresh_err =
    [ `Refresh_err of string
    | `Bad_refresh_token
    | Abb_curl.Make(Abb).request_err
    ]
  [@@deriving show]

  module Response : sig
    type t = {
      access_token : string;
      scope : string;
      token_type : string;
      refresh_token : string option; [@default None]
      refresh_token_expires_in : int option; [@default None]
      expires_in : int option; [@default None]
    }
    [@@deriving of_yojson { strict = false }, show]
  end

  val authorize :
    config:Terrat_config.Github.t -> string -> (Response.t, [> authorize_err ]) result Abb.Future.t

  val refresh :
    config:Terrat_config.Github.t -> string -> (Response.t, [> refresh_err ]) result Abb.Future.t
end
