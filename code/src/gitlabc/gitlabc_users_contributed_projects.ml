module GetApiV4UsersUserIdContributedProjects = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "id" -> Ok `Id
        | `String "last_activity_at" -> Ok `Last_activity_at
        | `String "name" -> Ok `Name
        | `String "packages_size" -> Ok `Packages_size
        | `String "path" -> Ok `Path
        | `String "repository_size" -> Ok `Repository_size
        | `String "similarity" -> Ok `Similarity
        | `String "star_count" -> Ok `Star_count
        | `String "storage_size" -> Ok `Storage_size
        | `String "updated_at" -> Ok `Updated_at
        | `String "wiki_size" -> Ok `Wiki_size
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Id -> `String "id"
        | `Last_activity_at -> `String "last_activity_at"
        | `Name -> `String "name"
        | `Packages_size -> `String "packages_size"
        | `Path -> `String "path"
        | `Repository_size -> `String "repository_size"
        | `Similarity -> `String "similarity"
        | `Star_count -> `String "star_count"
        | `Storage_size -> `String "storage_size"
        | `Updated_at -> `String "updated_at"
        | `Wiki_size -> `String "wiki_size"

      type t =
        ([ `Created_at
         | `Id
         | `Last_activity_at
         | `Name
         | `Packages_size
         | `Path
         | `Repository_size
         | `Similarity
         | `Star_count
         | `Storage_size
         | `Updated_at
         | `Wiki_size
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

    type t = {
      order_by : Order_by.t; [@default `Created_at]
      page : int; [@default 1]
      per_page : int; [@default 20]
      simple : bool; [@default false]
      sort : Sort.t; [@default `Desc]
      user_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default
         `Created_at
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option_default false (bool "simple")

  module Responses = struct
    module OK = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Not_found
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/api/v4/users/{user_id}/contributed_projects"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("order_by", Var (params.order_by, Enum Order_by.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("simple", Var (params.simple, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
