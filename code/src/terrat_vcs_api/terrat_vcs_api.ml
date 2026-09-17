(* How a VCS API call can fail.  A call that ran out of time is kept apart from
   [`Error] so the user is told that their VCS did not answer, rather than that
   something inside Terrateam broke.  The payload names the call.  See
   [Terrat_vcs_provider2.Msg.operation_failed_reason]. *)
type call_err =
  [ `Error
  | `Vcs_api_timeout_err of string
  ]
[@@deriving show]

(* Report a call the VCS did not answer the same as every other VCS failure.
   For the callers that cannot tell the user which side was at fault: the
   comment is the delivery channel, so a timeout while commenting reaches
   no one. *)
let collapse_call_err f =
  let open Abb.Future.Infix_monad in
  f ()
  >>= function
  | Ok _ as r -> Abb.Future.return r
  | Error (`Error | `Vcs_api_timeout_err _) -> Abb.Future.return (Error `Error)

(* The centralized configuration repository of an owner.  The first repository
   in [names] that holds a configuration file on its default branch is selected
   for every repository of the owner.  A path counts whether or not the file is
   empty. *)
module Centralized_repo = struct
  let names = CCList.map Terrat_brand.to_string Terrat_brand.all
  let directory = "config"

  let is_config_file ~basenames name =
    CCList.exists
      (fun basename ->
        CCString.equal name (basename ^ ".yml") || CCString.equal name (basename ^ ".yaml"))
      basenames

  let is_config_path path =
    match CCString.split_on_char '/' path with
    | [ dir; name ] when CCString.equal dir directory ->
        is_config_file ~basenames:[ "defaults"; "overrides" ] name
    | [ dir; repo; name ] when CCString.equal dir directory && not (CCString.is_empty repo) ->
        is_config_file ~basenames:[ "defaults"; "overrides"; "config" ] name
    | _ -> false

  let select lookup =
    let open Abb.Future.Infix_monad in
    let rec select' = function
      | [] -> Abb.Future.return (Ok None)
      | name :: names -> (
          lookup name
          >>= function
          | Ok None -> select' names
          | (Ok (Some _) | Error _) as r -> Abb.Future.return r)
    in
    select' names
end

module type ID = sig
  type t [@@deriving yojson, eq, show]

  val of_string : string -> t option
  val to_string : t -> string
end

module type CONFIG = sig
  type t
  type vcs_config

  val make : config:Terrat_config.t -> vcs_config:vcs_config -> unit -> t
  val config : t -> Terrat_config.t
  val vcs_config : t -> vcs_config
end

module type S = sig
  module Config : CONFIG

  module User : sig
    module Id : ID

    type t [@@deriving yojson]

    val make : Id.t -> t
    val id : t -> Id.t
    val to_string : t -> string
  end

  module Account : sig
    module Id : ID

    type t [@@deriving show, eq, yojson]

    val make : Id.t -> t
    val id : t -> Id.t
    val to_string : t -> string
  end

  module Client : sig
    type t
    type native

    val to_native : t -> native
  end

  module Comment : sig
    module Id : sig
      include ID

      val compare : t -> t -> int
    end

    type t [@@deriving eq, yojson]

    val make : id:Id.t -> unit -> t
    val id : t -> Id.t
  end

  module Ref : sig
    type t [@@deriving show, eq, yojson]

    val to_string : t -> string
    val of_string : string -> t
  end

  module Repo : sig
    module Id : ID

    type t [@@deriving show, eq, yojson]

    val make : id:Id.t -> name:string -> owner:string -> unit -> t
    val id : t -> Id.t
    val owner : t -> string
    val name : t -> string
    val to_string : t -> string
  end

  module Remote_repo : sig
    type t [@@deriving yojson]

    val to_repo : t -> Repo.t
    val default_branch : t -> Ref.t
    val is_archived : t -> bool
  end

  module Pull_request : sig
    module Id : ID

    include
      module type of Terrat_pull_request
        with type ('id, 'diff, 'repo, 'ref) t = ('id, 'diff, 'repo, 'ref) Terrat_pull_request.t
         and type State.Merged.t = Terrat_pull_request.State.Merged.t
         and type State.t = Terrat_pull_request.State.t

    type 'diff t = (Id.t, 'diff, Repo.t, Ref.t) Terrat_pull_request.t [@@deriving show, to_yojson]
  end

  val create_client :
    request_id:string ->
    Config.t ->
    Account.t ->
    Pgsql_io.t ->
    (Client.t, [> call_err ]) result Abb.Future.t

  val fetch_branch_sha :
    request_id:string ->
    Client.t ->
    Repo.t ->
    Ref.t ->
    (Ref.t option, [> call_err ]) result Abb.Future.t

  val fetch_file :
    request_id:string ->
    Client.t ->
    Repo.t ->
    Ref.t ->
    string ->
    (string option, [> call_err ]) result Abb.Future.t

  val fetch_remote_repo :
    request_id:string -> Client.t -> Repo.t -> (Remote_repo.t, [> call_err ]) result Abb.Future.t

  val fetch_centralized_repo :
    request_id:string ->
    Client.t ->
    string ->
    (Remote_repo.t option, [> call_err ]) result Abb.Future.t

  val fetch_tree :
    request_id:string ->
    Client.t ->
    Repo.t ->
    Ref.t ->
    (string list, [> call_err ]) result Abb.Future.t

  (** Publishes [body] closed with {!Terrat_comment.add_self_marker}, so that the comment is
      recognized and ignored when the VCS sends it back as an event. *)
  val comment_on_pull_request :
    request_id:string ->
    Client.t ->
    'diff Pull_request.t ->
    string ->
    (Comment.Id.t, [> call_err ]) result Abb.Future.t

  val delete_pull_request_comment :
    request_id:string ->
    Client.t ->
    'diff Pull_request.t ->
    Comment.Id.t ->
    (unit, [> call_err ]) result Abb.Future.t

  val minimize_pull_request_comment :
    request_id:string ->
    Client.t ->
    'diff Pull_request.t ->
    Comment.Id.t ->
    (unit, [> call_err ]) result Abb.Future.t

  val fetch_pull_request :
    request_id:string ->
    Account.t ->
    Client.t ->
    Repo.t ->
    Pull_request.Id.t ->
    (Terrat_change.Diff.t list Pull_request.t, [> call_err ]) result Abb.Future.t

  (** The VCS's verdict on whether the pull request will merge. [None] means the VCS has no verdict.

      A VCS computes this asynchronously, so this call waits for the answer. It is deliberately not
      part of {!fetch_pull_request}: only the apply requirements read it, and while it lived on the
      pull request every caller paid the wait. *)
  val fetch_pull_request_mergeable :
    request_id:string ->
    Repo.t ->
    Pull_request.Id.t ->
    Client.t ->
    (bool option, [> call_err ]) result Abb.Future.t

  val fetch_pull_request_reviews :
    request_id:string ->
    Repo.t ->
    Pull_request.Id.t ->
    Client.t ->
    (Terrat_pull_request_review.t list, [> call_err ]) result Abb.Future.t

  val fetch_pull_request_requested_reviews :
    request_id:string ->
    Repo.t ->
    Pull_request.Id.t ->
    Client.t ->
    (Terrat_base_repo_config_v1.Access_control.Match.t list, [> call_err ]) result Abb.Future.t

  (** The VCS's verdict on the pull request's required reviews. [None] means the VCS has no verdict,
      either because the target branch requires no reviews or because the VCS does not implement
      this. *)
  val fetch_pull_request_review_decision :
    request_id:string ->
    Repo.t ->
    Pull_request.Id.t ->
    Client.t ->
    (Terrat_pull_request_review.Decision.t option, [> call_err ]) result Abb.Future.t

  val fetch_diff_files :
    request_id:string ->
    base_ref:Ref.t ->
    branch_ref:Ref.t ->
    Repo.t ->
    Client.t ->
    (Terrat_change.Diff.t list, [> call_err ]) result Abb.Future.t

  val react_to_comment :
    request_id:string ->
    Client.t ->
    'a Pull_request.t ->
    int ->
    (unit, [> call_err ]) result Abb.Future.t

  val create_commit_checks :
    request_id:string ->
    brand:Terrat_brand.t ->
    Client.t ->
    Repo.t ->
    Ref.t ->
    Terrat_commit_check.t list ->
    (unit, [> call_err ]) result Abb.Future.t

  val fetch_commit_checks :
    request_id:string ->
    Client.t ->
    Repo.t ->
    Ref.t ->
    (Terrat_commit_check.t list, [> call_err ]) result Abb.Future.t

  val merge_pull_request :
    request_id:string ->
    ?retain_pr_title:bool ->
    Client.t ->
    'diff Pull_request.t ->
    Terrat_base_repo_config_v1.Automerge.Merge_strategy.t ->
    (unit, [> call_err | `Merge_err of string ]) result Abb.Future.t

  val delete_branch :
    request_id:string -> Client.t -> Repo.t -> string -> (unit, [> call_err ]) result Abb.Future.t

  val is_member_of_team :
    request_id:string ->
    team:string ->
    user:User.t ->
    Repo.t ->
    Client.t ->
    (bool, [> call_err ]) result Abb.Future.t

  val get_repo_role :
    request_id:string ->
    Repo.t ->
    User.t ->
    Client.t ->
    (string option, [> call_err ]) result Abb.Future.t

  val get_org_role :
    request_id:string ->
    org:string ->
    User.t ->
    Client.t ->
    ([ `Admin | `User ] option, [> call_err ]) result Abb.Future.t

  val find_workflow_file :
    request_id:string -> Repo.t -> Client.t -> (string option, [> call_err ]) result Abb.Future.t
end
