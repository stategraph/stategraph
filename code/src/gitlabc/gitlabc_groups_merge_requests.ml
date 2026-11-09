module GetApiV4GroupsIdMergeRequests = struct
  module Parameters = struct
    module Approved = struct
      let t_of_yojson = function
        | `String "no" -> Ok `No
        | `String "yes" -> Ok `Yes
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `No -> `String "no"
        | `Yes -> `String "yes"

      type t =
        ([ `No
         | `Yes
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Assignee_username = struct
      type t = string list [@@deriving show, eq]
    end

    module Labels = struct
      type t = string list [@@deriving show, eq]
    end

    module Not_assignee_username_ = struct
      type t = string list [@@deriving show, eq]
    end

    module Not_labels_ = struct
      type t = string list [@@deriving show, eq]
    end

    module Order_by = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "label_priority" -> Ok `Label_priority
        | `String "merged_at" -> Ok `Merged_at
        | `String "milestone_due" -> Ok `Milestone_due
        | `String "popularity" -> Ok `Popularity
        | `String "priority" -> Ok `Priority
        | `String "title" -> Ok `Title
        | `String "updated_at" -> Ok `Updated_at
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Label_priority -> `String "label_priority"
        | `Merged_at -> `String "merged_at"
        | `Milestone_due -> `String "milestone_due"
        | `Popularity -> `String "popularity"
        | `Priority -> `String "priority"
        | `Title -> `String "title"
        | `Updated_at -> `String "updated_at"

      type t =
        ([ `Created_at
         | `Label_priority
         | `Merged_at
         | `Milestone_due
         | `Popularity
         | `Priority
         | `Title
         | `Updated_at
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Scope = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "assigned-to-me" -> Ok `Assigned_to_me
        | `String "assigned_to_me" -> Ok `Assigned_to_me_2
        | `String "created-by-me" -> Ok `Created_by_me
        | `String "created_by_me" -> Ok `Created_by_me_2
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Assigned_to_me -> `String "assigned-to-me"
        | `Assigned_to_me_2 -> `String "assigned_to_me"
        | `Created_by_me -> `String "created-by-me"
        | `Created_by_me_2 -> `String "created_by_me"

      type t =
        ([ `All
         | `Assigned_to_me
         | `Assigned_to_me_2
         | `Created_by_me
         | `Created_by_me_2
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

    module State = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "closed" -> Ok `Closed
        | `String "locked" -> Ok `Locked
        | `String "merged" -> Ok `Merged
        | `String "opened" -> Ok `Opened
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Closed -> `String "closed"
        | `Locked -> `String "locked"
        | `Merged -> `String "merged"
        | `Opened -> `String "opened"

      type t =
        ([ `All
         | `Closed
         | `Locked
         | `Merged
         | `Opened
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module View = struct
      let t_of_yojson = function
        | `String "simple" -> Ok `Simple
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Simple -> `String "simple"

      type t = ([ `Simple ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson]) [@@deriving show, eq]
    end

    module Wip = struct
      let t_of_yojson = function
        | `String "no" -> Ok `No
        | `String "yes" -> Ok `Yes
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `No -> `String "no"
        | `Yes -> `String "yes"

      type t =
        ([ `No
         | `Yes
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      approved : Approved.t option; [@default None]
      approved_by_ids : string option; [@default None]
      approved_by_usernames : string option; [@default None]
      approver_ids : string option; [@default None]
      assignee_id : int option; [@default None]
      assignee_username : Assignee_username.t option; [@default None]
      author_id : int option; [@default None]
      author_username : string option; [@default None]
      created_after : string option; [@default None]
      created_before : string option; [@default None]
      deployed_after : string option; [@default None]
      deployed_before : string option; [@default None]
      environment : string option; [@default None]
      id : string;
      in_ : string option; [@default None] [@key "in"]
      labels : Labels.t option; [@default None]
      merge_user_id : int option; [@default None]
      merge_user_username : string option; [@default None]
      milestone : string option; [@default None]
      my_reaction_emoji : string option; [@default None]
      non_archived : bool; [@default true]
      not_assignee_id_ : int option; [@default None] [@key "not[assignee_id]"]
      not_assignee_username_ : Not_assignee_username_.t option;
          [@default None] [@key "not[assignee_username]"]
      not_author_id_ : int option; [@default None] [@key "not[author_id]"]
      not_author_username_ : string option; [@default None] [@key "not[author_username]"]
      not_labels_ : Not_labels_.t option; [@default None] [@key "not[labels]"]
      not_milestone_ : string option; [@default None] [@key "not[milestone]"]
      not_my_reaction_emoji_ : string option; [@default None] [@key "not[my_reaction_emoji]"]
      not_reviewer_id_ : int option; [@default None] [@key "not[reviewer_id]"]
      not_reviewer_username_ : string option; [@default None] [@key "not[reviewer_username]"]
      order_by : Order_by.t; [@default `Created_at]
      page : int; [@default 1]
      per_page : int; [@default 20]
      reviewer_id : int option; [@default None]
      reviewer_username : string option; [@default None]
      scope : Scope.t option; [@default None]
      search : string option; [@default None]
      sort : Sort.t; [@default `Desc]
      source_branch : string option; [@default None]
      source_project_id : int option; [@default None]
      state : State.t; [@default `All]
      target_branch : string option; [@default None]
      updated_after : string option; [@default None]
      updated_before : string option; [@default None]
      view : View.t option; [@default None]
      wip : Wip.t option; [@default None]
      with_labels_details : bool; [@default false]
      with_merge_status_recheck : bool; [@default false]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (int "author_id")
    /? option (string "author_username")
    /? option (int "assignee_id")
    /? option (array (string "assignee_username"))
    /? option (string "reviewer_username")
    /? option (array (string "labels"))
    /? option (string "milestone")
    /? option (string "my_reaction_emoji")
    /? option (int "reviewer_id")
    /? option_default
         `All
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option_default
         `Created_at
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default false (bool "with_labels_details")
    /? option_default false (bool "with_merge_status_recheck")
    /? option (string "created_after")
    /? option (string "created_before")
    /? option (string "updated_after")
    /? option (string "updated_before")
    /? option
         (ud "view" (fun value -> CCResult.to_opt (Parameters.View.t_of_yojson (`String value))))
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option (string "source_branch")
    /? option (int "source_project_id")
    /? option (string "target_branch")
    /? option (string "search")
    /? option (string "in")
    /? option (ud "wip" (fun value -> CCResult.to_opt (Parameters.Wip.t_of_yojson (`String value))))
    /? option (int "not[author_id]")
    /? option (string "not[author_username]")
    /? option (int "not[assignee_id]")
    /? option (array (string "not[assignee_username]"))
    /? option (string "not[reviewer_username]")
    /? option (array (string "not[labels]"))
    /? option (string "not[milestone]")
    /? option (string "not[my_reaction_emoji]")
    /? option (int "not[reviewer_id]")
    /? option (string "deployed_before")
    /? option (string "deployed_after")
    /? option (string "environment")
    /? option
         (ud "approved" (fun value ->
              CCResult.to_opt (Parameters.Approved.t_of_yojson (`String value))))
    /? option (int "merge_user_id")
    /? option (string "merge_user_username")
    /? option (string "approver_ids")
    /? option (string "approved_by_ids")
    /? option (string "approved_by_usernames")
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option_default true (bool "non_archived")

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Not_found
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/groups/{id}/merge_requests"

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
           ("author_id", Var (params.author_id, Option Int));
           ("author_username", Var (params.author_username, Option String));
           ("assignee_id", Var (params.assignee_id, Option Int));
           ("assignee_username", Var (params.assignee_username, Option (Array String)));
           ("reviewer_username", Var (params.reviewer_username, Option String));
           ("labels", Var (params.labels, Option (Array String)));
           ("milestone", Var (params.milestone, Option String));
           ("my_reaction_emoji", Var (params.my_reaction_emoji, Option String));
           ("reviewer_id", Var (params.reviewer_id, Option Int));
           ("state", Var (params.state, Enum State.t_to_yojson));
           ("order_by", Var (params.order_by, Enum Order_by.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("with_labels_details", Var (params.with_labels_details, Bool));
           ("with_merge_status_recheck", Var (params.with_merge_status_recheck, Bool));
           ("created_after", Var (params.created_after, Option String));
           ("created_before", Var (params.created_before, Option String));
           ("updated_after", Var (params.updated_after, Option String));
           ("updated_before", Var (params.updated_before, Option String));
           ("view", Var (params.view, Option (Enum View.t_to_yojson)));
           ("scope", Var (params.scope, Option (Enum Scope.t_to_yojson)));
           ("source_branch", Var (params.source_branch, Option String));
           ("source_project_id", Var (params.source_project_id, Option Int));
           ("target_branch", Var (params.target_branch, Option String));
           ("search", Var (params.search, Option String));
           ("in", Var (params.in_, Option String));
           ("wip", Var (params.wip, Option (Enum Wip.t_to_yojson)));
           ("not[author_id]", Var (params.not_author_id_, Option Int));
           ("not[author_username]", Var (params.not_author_username_, Option String));
           ("not[assignee_id]", Var (params.not_assignee_id_, Option Int));
           ("not[assignee_username]", Var (params.not_assignee_username_, Option (Array String)));
           ("not[reviewer_username]", Var (params.not_reviewer_username_, Option String));
           ("not[labels]", Var (params.not_labels_, Option (Array String)));
           ("not[milestone]", Var (params.not_milestone_, Option String));
           ("not[my_reaction_emoji]", Var (params.not_my_reaction_emoji_, Option String));
           ("not[reviewer_id]", Var (params.not_reviewer_id_, Option Int));
           ("deployed_before", Var (params.deployed_before, Option String));
           ("deployed_after", Var (params.deployed_after, Option String));
           ("environment", Var (params.environment, Option String));
           ("approved", Var (params.approved, Option (Enum Approved.t_to_yojson)));
           ("merge_user_id", Var (params.merge_user_id, Option Int));
           ("merge_user_username", Var (params.merge_user_username, Option String));
           ("approver_ids", Var (params.approver_ids, Option String));
           ("approved_by_ids", Var (params.approved_by_ids, Option String));
           ("approved_by_usernames", Var (params.approved_by_usernames, Option String));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("non_archived", Var (params.non_archived, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
