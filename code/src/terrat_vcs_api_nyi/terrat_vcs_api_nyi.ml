let src = Logs.Src.create "terrat_vcs_api_nyi"

module Logs = (val Logs.src_log src : Logs.LOG)

module Config = struct
  type t
  type vcs_config

  let make ~config ~vcs_config () = raise (Failure "nyi")
  let config t = raise (Failure "nyi")
  let vcs_config t = raise (Failure "nyi")
end

module User = struct
  module Id = struct
    type t = unit [@@deriving yojson, show, eq]

    let of_string s = raise (Failure "nyi")
    let to_string t = raise (Failure "nyi")
  end

  type t = unit [@@deriving yojson]

  let make s = raise (Failure "nyi")
  let id t = raise (Failure "nyi")
  let to_string t = raise (Failure "nyi")
end

module Account = struct
  module Id = struct
    type t = unit [@@deriving yojson, show, eq]

    let of_string s = raise (Failure "nyi")
    let to_string t = raise (Failure "nyi")
  end

  type t = unit [@@deriving show, yojson, eq]

  let make id = raise (Failure "nyi")
  let id t = raise (Failure "nyi")
  let to_string t = raise (Failure "nyi")
end

module Comment = struct
  module Id = struct
    type t = unit [@@deriving yojson, show, eq]

    let of_string s = raise (Failure "nyi")
    let to_string t = raise (Failure "nyi")
    let compare _ _ = raise (Failure "nyi")
  end

  type t = unit [@@deriving eq, yojson]

  let make ~id = raise (Failure "nyi")
  let id t = raise (Failure "nyi")
end

module Repo = struct
  module Id = struct
    type t = unit [@@deriving yojson, show, eq]

    let of_string s = raise (Failure "nyi")
    let to_string t = raise (Failure "nyi")
  end

  type t = unit [@@deriving show, eq, yojson]

  let make ~id ~name ~owner () = raise (Failure "nyi")
  let name t = raise (Failure "nyi")
  let owner t = raise (Failure "nyi")
  let id t = raise (Failure "nyi")
  let to_string t = raise (Failure "nyi")
end

module Remote_repo = struct
  type t = unit [@@deriving yojson]

  let to_repo t = raise (Failure "nyi")
  let default_branch t = raise (Failure "nyi")
  let is_archived _ = raise (Failure "nyi")
end

module Ref = struct
  type t = unit [@@deriving show, eq, yojson]

  let to_string t = raise (Failure "nyi")
  let of_string s = raise (Failure "nyi")
end

module Pull_request = struct
  module Id = struct
    type t = unit [@@deriving yojson, show, eq]

    let of_string s = raise (Failure "nyi")
    let to_string t = raise (Failure "nyi")
  end

  include Terrat_pull_request

  type 'diff t = (Id.t, 'diff, Repo.t, Ref.t) Terrat_pull_request.t [@@deriving show, to_yojson]
end

module Client = struct
  type t = unit
  type native

  let make ~account ~client ~config () = raise (Failure "nyi")
  let to_native t = raise (Failure "nyi")
end

let fetch_branch_sha ~request_id client repo ref_ = raise (Failure "nyi")
let fetch_branch_commits ~request_id client repo ref_ = raise (Failure "nyi")
let fetch_file ~request_id client repo ref_ path = raise (Failure "nyi")
let fetch_remote_repo ~request_id client repo = raise (Failure "nyi")
let fetch_centralized_repo ~request_id client owner = raise (Failure "nyi")
let create_client ~request_id config account = raise (Failure "nyi")
let fetch_tree ~request_id client repo ref_ = raise (Failure "nyi")
let comment_on_pull_request ~request_id client pull_request body = raise (Failure "nyi")
let delete_pull_request_comment ~request_id client pull_request comment_id = raise (Failure "nyi")
let minimize_pull_request_comment ~request_id client pull_request comment_id = raise (Failure "nyi")
let fetch_diff ~client ~owner ~repo pull_number = raise (Failure "nyi")
let fetch_pull_request ~request_id account client repo pull_request_id = raise (Failure "nyi")
let fetch_diff_files ~request_id ~base_ref ~branch_ref repo client = raise (Failure "nyi")
let react_to_comment ~request_id client pull_request comment_id = raise (Failure "nyi")
let create_commit_checks ~request_id ~brand client repo ref_ checks = raise (Failure "nyi")
let fetch_commit_checks ~request_id client repo ref_ = raise (Failure "nyi")
let fetch_pull_request_mergeable ~request_id repo pull_request_id client = raise (Failure "nyi")
let fetch_pull_request_reviews ~request_id client repo pull_request = raise (Failure "nyi")
let fetch_pull_request_requested_reviews ~request_id repo pull_number client = raise (Failure "nyi")
let fetch_pull_request_review_decision ~request_id repo pull_number client = raise (Failure "nyi")

let merge_pull_request ~request_id ?retain_pr_title client pull_request merge_strategy =
  raise (Failure "nyi")

let delete_branch ~request_id client repo branch = raise (Failure "nyi")
let is_member_of_team ~request_id ~team ~user repo client = raise (Failure "nyi")
let get_repo_role ~request_id repo user client = raise (Failure "nyi")
let get_org_role ~request_id ~org user client = raise (Failure "nyi")
let find_workflow_file ~request_id repo client = raise (Failure "nyi")
