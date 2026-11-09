module GetApiV4GroupsIdDescendantGroups = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "id" -> Ok `Id
        | `String "name" -> Ok `Name
        | `String "path" -> Ok `Path
        | `String "similarity" -> Ok `Similarity
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Id -> `String "id"
        | `Name -> `String "name"
        | `Path -> `String "path"
        | `Similarity -> `String "similarity"

      type t =
        ([ `Id
         | `Name
         | `Path
         | `Similarity
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Skip_groups = struct
      type t = int list [@@deriving show, eq]
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
      all_available : bool option; [@default None]
      id : string;
      marked_for_deletion_on : string option; [@default None]
      min_access_level : int option; [@default None]
      order_by : Order_by.t; [@default `Name]
      owned : bool; [@default false]
      page : int; [@default 1]
      per_page : int; [@default 20]
      repository_storage : string option; [@default None]
      search : string option; [@default None]
      skip_groups : Skip_groups.t option; [@default None]
      sort : Sort.t; [@default `Asc]
      statistics : bool; [@default false]
      top_level_only : bool option; [@default None]
      visibility : Visibility.t option; [@default None]
      with_custom_attributes : bool; [@default false]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default false (bool "statistics")
    /? option (array (int "skip_groups"))
    /? option (bool "all_available")
    /? option
         (ud "visibility" (fun value ->
              CCResult.to_opt (Parameters.Visibility.t_of_yojson (`String value))))
    /? option (string "search")
    /? option_default false (bool "owned")
    /? option_default
         `Name
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option_default
         `Asc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
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
    /? option (bool "top_level_only")
    /? option (string "repository_storage")
    /? option (string "marked_for_deletion_on")
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option_default false (bool "with_custom_attributes")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/groups/{id}/descendant_groups"

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
           ("skip_groups", Var (params.skip_groups, Option (Array Int)));
           ("all_available", Var (params.all_available, Option Bool));
           ("visibility", Var (params.visibility, Option (Enum Visibility.t_to_yojson)));
           ("search", Var (params.search, Option String));
           ("owned", Var (params.owned, Bool));
           ("order_by", Var (params.order_by, Enum Order_by.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("min_access_level", Var (params.min_access_level, Option Int));
           ("top_level_only", Var (params.top_level_only, Option Bool));
           ("repository_storage", Var (params.repository_storage, Option String));
           ("marked_for_deletion_on", Var (params.marked_for_deletion_on, Option String));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("with_custom_attributes", Var (params.with_custom_attributes, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
