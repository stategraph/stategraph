module PostApiV4GroupsIdProjectsProjectId = struct
  module Parameters = struct
    type t = {
      id : string;
      project_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module Created = struct end

    type t = [ `Created ] [@@deriving show, eq]

    let t = [ ("201", fun _ -> Ok `Created) ]
  end

  let url = "/api/v4/groups/{id}/projects/{project_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("project_id", Var (params.project_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4GroupsIdProjectsShared = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "id" -> Ok `Id
        | `String "last_activity_at" -> Ok `Last_activity_at
        | `String "name" -> Ok `Name
        | `String "path" -> Ok `Path
        | `String "star_count" -> Ok `Star_count
        | `String "updated_at" -> Ok `Updated_at
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Id -> `String "id"
        | `Last_activity_at -> `String "last_activity_at"
        | `Name -> `String "name"
        | `Path -> `String "path"
        | `Star_count -> `String "star_count"
        | `Updated_at -> `String "updated_at"

      type t =
        ([ `Created_at
         | `Id
         | `Last_activity_at
         | `Name
         | `Path
         | `Star_count
         | `Updated_at
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
      archived : bool option; [@default None]
      id : string;
      min_access_level : int option; [@default None]
      order_by : Order_by.t; [@default `Created_at]
      page : int; [@default 1]
      per_page : int; [@default 20]
      search : string option; [@default None]
      simple : bool; [@default false]
      sort : Sort.t; [@default `Desc]
      starred : bool; [@default false]
      visibility : Visibility.t option; [@default None]
      with_custom_attributes : bool; [@default false]
      with_issues_enabled : bool; [@default false]
      with_merge_requests_enabled : bool; [@default false]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (bool "archived")
    /? option
         (ud "visibility" (fun value ->
              CCResult.to_opt (Parameters.Visibility.t_of_yojson (`String value))))
    /? option (string "search")
    /? option_default
         `Created_at
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default false (bool "simple")
    /? option_default false (bool "starred")
    /? option_default false (bool "with_issues_enabled")
    /? option_default false (bool "with_merge_requests_enabled")
    /? option
         (ud
            "min_access_level"
            (fun value ->
               match CCInt.of_string value with
               | Some 10 -> Some 10
               | Some 15 -> Some 15
               | Some 20 -> Some 20
               | Some 30 -> Some 30
               | Some 40 -> Some 40
               | Some 50 -> Some 50
               | _ -> None
              : string -> int option))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option_default false (bool "with_custom_attributes")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/groups/{id}/projects/shared"

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
           ("archived", Var (params.archived, Option Bool));
           ("visibility", Var (params.visibility, Option (Enum Visibility.t_to_yojson)));
           ("search", Var (params.search, Option String));
           ("order_by", Var (params.order_by, Enum Order_by.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("simple", Var (params.simple, Bool));
           ("starred", Var (params.starred, Bool));
           ("with_issues_enabled", Var (params.with_issues_enabled, Bool));
           ("with_merge_requests_enabled", Var (params.with_merge_requests_enabled, Bool));
           ("min_access_level", Var (params.min_access_level, Option Int));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("with_custom_attributes", Var (params.with_custom_attributes, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4GroupsIdProjects = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "id" -> Ok `Id
        | `String "last_activity_at" -> Ok `Last_activity_at
        | `String "name" -> Ok `Name
        | `String "path" -> Ok `Path
        | `String "similarity" -> Ok `Similarity
        | `String "star_count" -> Ok `Star_count
        | `String "updated_at" -> Ok `Updated_at
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Id -> `String "id"
        | `Last_activity_at -> `String "last_activity_at"
        | `Name -> `String "name"
        | `Path -> `String "path"
        | `Similarity -> `String "similarity"
        | `Star_count -> `String "star_count"
        | `Updated_at -> `String "updated_at"

      type t =
        ([ `Created_at
         | `Id
         | `Last_activity_at
         | `Name
         | `Path
         | `Similarity
         | `Star_count
         | `Updated_at
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
      archived : bool option; [@default None]
      id : string;
      include_ancestor_groups : bool; [@default false]
      include_subgroups : bool; [@default false]
      min_access_level : int option; [@default None]
      order_by : Order_by.t; [@default `Created_at]
      owned : bool; [@default false]
      page : int; [@default 1]
      per_page : int; [@default 20]
      search : string option; [@default None]
      simple : bool; [@default false]
      sort : Sort.t; [@default `Desc]
      starred : bool; [@default false]
      visibility : Visibility.t option; [@default None]
      with_custom_attributes : bool; [@default false]
      with_issues_enabled : bool; [@default false]
      with_merge_requests_enabled : bool; [@default false]
      with_security_reports : bool; [@default false]
      with_shared : bool; [@default true]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (bool "archived")
    /? option
         (ud "visibility" (fun value ->
              CCResult.to_opt (Parameters.Visibility.t_of_yojson (`String value))))
    /? option (string "search")
    /? option_default
         `Created_at
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default false (bool "simple")
    /? option_default false (bool "owned")
    /? option_default false (bool "starred")
    /? option_default false (bool "with_issues_enabled")
    /? option_default false (bool "with_merge_requests_enabled")
    /? option_default true (bool "with_shared")
    /? option_default false (bool "include_subgroups")
    /? option_default false (bool "include_ancestor_groups")
    /? option
         (ud
            "min_access_level"
            (fun value ->
               match CCInt.of_string value with
               | Some 10 -> Some 10
               | Some 15 -> Some 15
               | Some 20 -> Some 20
               | Some 30 -> Some 30
               | Some 40 -> Some 40
               | Some 50 -> Some 50
               | _ -> None
              : string -> int option))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option_default false (bool "with_custom_attributes")
    /? option_default false (bool "with_security_reports")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/groups/{id}/projects"

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
           ("archived", Var (params.archived, Option Bool));
           ("visibility", Var (params.visibility, Option (Enum Visibility.t_to_yojson)));
           ("search", Var (params.search, Option String));
           ("order_by", Var (params.order_by, Enum Order_by.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("simple", Var (params.simple, Bool));
           ("owned", Var (params.owned, Bool));
           ("starred", Var (params.starred, Bool));
           ("with_issues_enabled", Var (params.with_issues_enabled, Bool));
           ("with_merge_requests_enabled", Var (params.with_merge_requests_enabled, Bool));
           ("with_shared", Var (params.with_shared, Bool));
           ("include_subgroups", Var (params.include_subgroups, Bool));
           ("include_ancestor_groups", Var (params.include_ancestor_groups, Bool));
           ("min_access_level", Var (params.min_access_level, Option Int));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("with_custom_attributes", Var (params.with_custom_attributes, Bool));
           ("with_security_reports", Var (params.with_security_reports, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
