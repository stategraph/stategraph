module GetApiV4UsersIdEvents = struct
  module Parameters = struct
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

    module Target_type = struct
      let t_of_yojson = function
        | `String "design" -> Ok `Design
        | `String "issue" -> Ok `Issue
        | `String "merge_request" -> Ok `Merge_request
        | `String "milestone" -> Ok `Milestone
        | `String "note" -> Ok `Note
        | `String "project" -> Ok `Project
        | `String "snippet" -> Ok `Snippet
        | `String "user" -> Ok `User
        | `String "wiki" -> Ok `Wiki
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Design -> `String "design"
        | `Issue -> `String "issue"
        | `Merge_request -> `String "merge_request"
        | `Milestone -> `String "milestone"
        | `Note -> `String "note"
        | `Project -> `String "project"
        | `Snippet -> `String "snippet"
        | `User -> `String "user"
        | `Wiki -> `String "wiki"

      type t =
        ([ `Design
         | `Issue
         | `Merge_request
         | `Milestone
         | `Note
         | `Project
         | `Snippet
         | `User
         | `Wiki
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      action : string option; [@default None]
      after : string option; [@default None]
      before : string option; [@default None]
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      sort : Sort.t; [@default `Desc]
      target_type : Target_type.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option (string "action")
    /? option
         (ud "target_type" (fun value ->
              CCResult.to_opt (Parameters.Target_type.t_of_yojson (`String value))))
    /? option (string "before")
    /? option (string "after")
    /? option_default
         `Desc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))

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

  let url = "/api/v4/users/{id}/events"

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
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("action", Var (params.action, Option String));
           ("target_type", Var (params.target_type, Option (Enum Target_type.t_to_yojson)));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
