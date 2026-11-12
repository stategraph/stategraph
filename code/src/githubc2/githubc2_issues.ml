module List_for_authenticated_user = struct
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

    module Filter = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "assigned" -> Ok `Assigned
        | `String "created" -> Ok `Created
        | `String "mentioned" -> Ok `Mentioned
        | `String "repos" -> Ok `Repos
        | `String "subscribed" -> Ok `Subscribed
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Assigned -> `String "assigned"
        | `Created -> `String "created"
        | `Mentioned -> `String "mentioned"
        | `Repos -> `String "repos"
        | `Subscribed -> `String "subscribed"

      type t =
        ([ `All
         | `Assigned
         | `Created
         | `Mentioned
         | `Repos
         | `Subscribed
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "comments" -> Ok `Comments
        | `String "created" -> Ok `Created
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Comments -> `String "comments"
        | `Created -> `String "created"
        | `Updated -> `String "updated"

      type t =
        ([ `Comments
         | `Created
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "closed" -> Ok `Closed
        | `String "open" -> Ok `Open
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Closed -> `String "closed"
        | `Open -> `String "open"

      type t =
        ([ `All
         | `Closed
         | `Open
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t; [@default `Desc]
      filter : Filter.t; [@default `Assigned]
      labels : string option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 30]
      since : string option; [@default None]
      sort : Sort.t; [@default `Created]
      state : State.t; [@default `Open]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "issues"
    /? option_default
         `Assigned
         (ud "filter" (fun value -> CCResult.to_opt (Parameters.Filter.t_of_yojson (`String value))))
    /? option_default
         `Open
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option (string "labels")
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "since")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/issues"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("filter", Var (params.filter, Enum Filter.t_to_yojson));
           ("state", Var (params.state, Enum State.t_to_yojson));
           ("labels", Var (params.labels, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("since", Var (params.since, Option String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_labels_for_milestone = struct
  module Parameters = struct
    type t = {
      milestone_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "milestones"
    /% Path.int
    / "labels"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Label.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/milestones/{milestone_number}/labels"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("milestone_number", Var (params.milestone_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_milestone = struct
  module Parameters = struct
    type t = {
      milestone_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module State = struct
        let t_of_yojson = function
          | `String "closed" -> Ok `Closed
          | `String "open" -> Ok `Open
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Closed -> `String "closed"
          | `Open -> `String "open"

        type t =
          ([ `Closed
           | `Open
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        description : string option; [@default None]
        due_on : string option; [@default None]
        state : State.t; [@default `Open]
        title : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "milestones" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Milestone.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/milestones/{milestone_number}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("milestone_number", Var (params.milestone_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_milestone = struct
  module Parameters = struct
    type t = {
      milestone_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "milestones" /% Path.int

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

  let url = "/repos/{owner}/{repo}/milestones/{milestone_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("milestone_number", Var (params.milestone_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_milestone = struct
  module Parameters = struct
    type t = {
      milestone_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "milestones" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Milestone.t
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

  let url = "/repos/{owner}/{repo}/milestones/{milestone_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("milestone_number", Var (params.milestone_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_milestone = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module State = struct
        let t_of_yojson = function
          | `String "closed" -> Ok `Closed
          | `String "open" -> Ok `Open
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Closed -> `String "closed"
          | `Open -> `String "open"

        type t =
          ([ `Closed
           | `Open
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        description : string option; [@default None]
        due_on : string option; [@default None]
        state : State.t; [@default `Open]
        title : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "milestones"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Milestone.t
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

  let url = "/repos/{owner}/{repo}/milestones"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_milestones = struct
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
        | `String "completeness" -> Ok `Completeness
        | `String "due_on" -> Ok `Due_on
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Completeness -> `String "completeness"
        | `Due_on -> `String "due_on"

      type t =
        ([ `Completeness
         | `Due_on
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "closed" -> Ok `Closed
        | `String "open" -> Ok `Open
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Closed -> `String "closed"
        | `Open -> `String "open"

      type t =
        ([ `All
         | `Closed
         | `Open
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t; [@default `Asc]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
      sort : Sort.t; [@default `Due_on]
      state : State.t; [@default `Open]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "milestones"
    /? option_default
         `Open
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option_default
         `Due_on
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Asc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Milestone.t list
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

  let url = "/repos/{owner}/{repo}/milestones"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("state", Var (params.state, Enum State.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_label = struct
  module Parameters = struct
    type t = {
      name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        color : string option; [@default None]
        description : string option; [@default None]
        new_name : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "labels" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Label.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/labels/{name}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("name", Var (params.name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_label = struct
  module Parameters = struct
    type t = {
      name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "labels" /% Path.string

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/labels/{name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("name", Var (params.name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_label = struct
  module Parameters = struct
    type t = {
      name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "labels" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Label.t
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

  let url = "/repos/{owner}/{repo}/labels/{name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("name", Var (params.name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_label = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        color : string option; [@default None]
        description : string option; [@default None]
        name : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "labels"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Label.t
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

  let url = "/repos/{owner}/{repo}/labels"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_labels_for_repo = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "labels"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Label.t list
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

  let url = "/repos/{owner}/{repo}/labels"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_events_for_timeline = struct
  module Parameters = struct
    type t = {
      exclude : string option; [@default None]
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "timeline"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option (string "exclude")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Timeline_issue_events.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/timeline"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("exclude", Var (params.exclude, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Dismiss_suggestion = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
      suggestion_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "suggestions"
    /% Path.int
    / "dismiss"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_suggestion.t
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/suggestions/{suggestion_id}/dismiss"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
           ("suggestion_id", Var (params.suggestion_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Approve_suggestion = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
      suggestion_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "suggestions"
    /% Path.int
    / "approve"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_suggestion.t
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/suggestions/{suggestion_id}/approve"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
           ("suggestion_id", Var (params.suggestion_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_suggestions = struct
  module Parameters = struct
    module Action = struct
      let t_of_yojson = function
        | `String "add_assignee" -> Ok `Add_assignee
        | `String "add_field" -> Ok `Add_field
        | `String "add_label" -> Ok `Add_label
        | `String "close_issue" -> Ok `Close_issue
        | `String "set_type" -> Ok `Set_type
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Add_assignee -> `String "add_assignee"
        | `Add_field -> `String "add_field"
        | `Add_label -> `String "add_label"
        | `Close_issue -> `String "close_issue"
        | `Set_type -> `String "set_type"

      type t =
        ([ `Add_assignee
         | `Add_field
         | `Add_label
         | `Close_issue
         | `Set_type
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "applied" -> Ok `Applied
        | `String "approved" -> Ok `Approved
        | `String "dismissed" -> Ok `Dismissed
        | `String "invalidated" -> Ok `Invalidated
        | `String "pending" -> Ok `Pending
        | `String "replaced" -> Ok `Replaced
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Applied -> `String "applied"
        | `Approved -> `String "approved"
        | `Dismissed -> `String "dismissed"
        | `Invalidated -> `String "invalidated"
        | `Pending -> `String "pending"
        | `Replaced -> `String "replaced"

      type t =
        ([ `All
         | `Applied
         | `Approved
         | `Dismissed
         | `Invalidated
         | `Pending
         | `Replaced
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      action : Action.t option; [@default None]
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
      state : State.t; [@default `Pending]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "suggestions"
    /? option_default
         `Pending
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option
         (ud "action" (fun value -> CCResult.to_opt (Parameters.Action.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_suggestion.t list
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

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/suggestions"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("state", Var (params.state, Enum State.t_to_yojson));
           ("action", Var (params.action, Option (Enum Action.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Reprioritize_sub_issue = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        after_id : int option; [@default None]
        before_id : int option; [@default None]
        sub_issue_id : int;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "sub_issues" / "priority"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t
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
      type t = Githubc2_components.Validation_error_simple.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/sub_issues/priority"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Add_sub_issue = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        replace_parent : bool option; [@default None]
        sub_issue_id : int;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "sub_issues"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Issue.t
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/sub_issues"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_sub_issues = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "sub_issues"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/sub_issues"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_sub_issue = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { sub_issue_id : int }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "sub_issue"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
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

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/sub_issue"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_parent = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "parent"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/parent"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Unlock = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "lock"

  module Responses = struct
    module No_content = struct end

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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/lock"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Lock = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Lock_reason = struct
        let t_of_yojson = function
          | `String "off-topic" -> Ok `Off_topic
          | `String "resolved" -> Ok `Resolved
          | `String "spam" -> Ok `Spam
          | `String "too heated" -> Ok `Too_heated
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Off_topic -> `String "off-topic"
          | `Resolved -> `String "resolved"
          | `Spam -> `String "spam"
          | `Too_heated -> `String "too heated"

        type t =
          ([ `Off_topic
           | `Resolved
           | `Spam
           | `Too_heated
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { lock_reason : Lock_reason.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "lock"

  module Responses = struct
    module No_content = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/lock"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Remove_label = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "labels" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Label.t list
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/labels/{name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
           ("name", Var (params.name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Remove_all_labels = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "labels"

  module Responses = struct
    module No_content = struct end

    module Moved_permanently = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/labels"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_labels = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Labels = struct
          module Items = struct
            module V0 = struct
              type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module V1 = struct
              module Primary = struct
                module Confidence = struct
                  let t_of_yojson = function
                    | `String "high" -> Ok `High
                    | `String "low" -> Ok `Low
                    | `String "medium" -> Ok `Medium
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `High -> `String "high"
                    | `Low -> `String "low"
                    | `Medium -> `String "medium"

                  type t =
                    ([ `High
                     | `Low
                     | `Medium
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                type t = {
                  confidence : Confidence.t option; [@default None]
                  name : string;
                  rationale : string option; [@default None]
                  suggest : bool option; [@default None]
                }
                [@@deriving make, yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t =
              | V0 of V0.t
              | V1 of V1.t
            [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [
                   (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                   (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                 ])

            let to_yojson = function
              | V0 v -> V0.to_yojson v
              | V1 v -> V1.to_yojson v
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { labels : Labels.t option [@default None] }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module V2 = struct
      module Items = struct
        module Primary = struct
          module Confidence = struct
            let t_of_yojson = function
              | `String "high" -> Ok `High
              | `String "low" -> Ok `Low
              | `String "medium" -> Ok `Medium
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `High -> `String "high"
              | `Low -> `String "low"
              | `Medium -> `String "medium"

            type t =
              ([ `High
               | `Low
               | `Medium
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t = {
            confidence : Confidence.t option; [@default None]
            name : string;
            rationale : string option; [@default None]
            suggest : bool option; [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t =
      | V0 of V0.t
      | V1 of V1.t
      | V2 of V2.t
    [@@deriving show, eq]

    let of_yojson =
      Json_schema.one_of
        (let open CCResult in
         [
           (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
           (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
           (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
         ])

    let to_yojson = function
      | V0 v -> V0.to_yojson v
      | V1 v -> V1.to_yojson v
      | V2 v -> V2.to_yojson v
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "labels"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Label.t list
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/labels"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Set_labels = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Labels = struct
          type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { labels : Labels.t option [@default None] }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module V2 = struct
      module Primary = struct
        module Labels = struct
          module Items = struct
            module Primary = struct
              type t = { name : string }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { labels : Labels.t option [@default None] }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V3 = struct
      module Items = struct
        module Primary = struct
          type t = { name : string }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module V4 = struct
      type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t =
      | V0 of V0.t
      | V1 of V1.t
      | V2 of V2.t
      | V3 of V3.t
      | V4 of V4.t
    [@@deriving show, eq]

    let of_yojson =
      Json_schema.one_of
        (let open CCResult in
         [
           (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
           (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
           (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
           (fun v -> map (fun v -> V3 v) (V3.of_yojson v));
           (fun v -> map (fun v -> V4 v) (V4.of_yojson v));
         ])

    let to_yojson = function
      | V0 v -> V0.to_yojson v
      | V1 v -> V1.to_yojson v
      | V2 v -> V2.to_yojson v
      | V3 v -> V3.to_yojson v
      | V4 v -> V4.to_yojson v
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "labels"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Label.t list
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/labels"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module List_labels_on_issue = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "labels"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Label.t list
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/labels"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_issue_field_value = struct
  module Parameters = struct
    type t = {
      issue_field_id : int;
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "issue-field-values"
    /% Path.int

  module Responses = struct
    module No_content = struct end

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

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/issue-field-values/{issue_field_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
           ("issue_field_id", Var (params.issue_field_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_issue_field_values = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Issue_field_values = struct
        module Items = struct
          module Value = struct
            module V0 = struct
              type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module V1 = struct
              type t = float [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module V2 = struct
              type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t =
              | V0 of V0.t
              | V1 of V1.t
              | V2 of V2.t
            [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [
                   (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                   (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                   (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
                 ])

            let to_yojson = function
              | V0 v -> V0.to_yojson v
              | V1 v -> V1.to_yojson v
              | V2 v -> V2.to_yojson v
          end

          type t = {
            field_id : int;
            value : Value.t;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { issue_field_values : Issue_field_values.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "issue-field-values"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_field_value.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
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

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/issue-field-values"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Set_issue_field_values = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Issue_field_values = struct
        module Items = struct
          module Value = struct
            module V0 = struct
              type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module V1 = struct
              type t = float [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t =
              | V0 of V0.t
              | V1 of V1.t
            [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [
                   (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                   (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                 ])

            let to_yojson = function
              | V0 v -> V0.to_yojson v
              | V1 v -> V1.to_yojson v
          end

          type t = {
            field_id : int;
            value : Value.t;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { issue_field_values : Issue_field_values.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "issue-field-values"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_field_value.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
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

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/issue-field-values"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module List_issue_field_values_for_issue = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "issue-field-values"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_field_value.t list
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/issue-field-values"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_events = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "events"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_event_for_issue.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/events"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_dependencies_blocking = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "dependencies"
    / "blocking"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t list
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocking"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_dependency_blocked_by = struct
  module Parameters = struct
    type t = {
      issue_id : int;
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "dependencies"
    / "blocked_by"
    /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Moved_permanently = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by/{issue_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
           ("issue_id", Var (params.issue_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_blocked_by_dependency = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { issue_id : int }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "dependencies"
    / "blocked_by"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Issue.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Moved_permanently = struct
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Moved_permanently of Moved_permanently.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_dependencies_blocked_by = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "dependencies"
    / "blocked_by"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t list
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_comment = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { body : string } [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "comments"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Issue_comment.t
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/comments"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_comments = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
      since : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /% Path.int
    / "comments"
    /? option (string "since")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_comment.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/comments"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("since", Var (params.since, Option String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Check_user_can_be_assigned_to_issue = struct
  module Parameters = struct
    type t = {
      assignee : string;
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "assignees" /% Path.string

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

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/assignees/{assignee}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
           ("assignee", Var (params.assignee, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_assignees = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Assignees = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { assignees : Assignees.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "assignees"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/assignees"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_assignees = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Assignees = struct
        module Items = struct
          module V0 = struct
            type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            module Primary = struct
              module Confidence = struct
                let t_of_yojson = function
                  | `String "high" -> Ok `High
                  | `String "low" -> Ok `Low
                  | `String "medium" -> Ok `Medium
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `High -> `String "high"
                  | `Low -> `String "low"
                  | `Medium -> `String "medium"

                type t =
                  ([ `High
                   | `Low
                   | `Medium
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                confidence : Confidence.t option; [@default None]
                login : string;
                rationale : string option; [@default None]
                suggest : bool option; [@default None]
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t =
            | V0 of V0.t
            | V1 of V1.t
          [@@deriving show, eq]

          let of_yojson =
            Json_schema.one_of
              (let open CCResult in
               [
                 (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                 (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
               ])

          let to_yojson = function
            | V0 v -> V0.to_yojson v
            | V1 v -> V1.to_yojson v
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { assignees : Assignees.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int / "assignees"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Issue.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/assignees"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Update = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Assignees = struct
        module Items = struct
          module V0 = struct
            type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            module Primary = struct
              module Confidence = struct
                let t_of_yojson = function
                  | `String "high" -> Ok `High
                  | `String "low" -> Ok `Low
                  | `String "medium" -> Ok `Medium
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `High -> `String "high"
                  | `Low -> `String "low"
                  | `Medium -> `String "medium"

                type t =
                  ([ `High
                   | `Low
                   | `Medium
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                confidence : Confidence.t option; [@default None]
                login : string option; [@default None]
                rationale : string option; [@default None]
                suggest : bool option; [@default None]
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t =
            | V0 of V0.t
            | V1 of V1.t
          [@@deriving show, eq]

          let of_yojson =
            Json_schema.one_of
              (let open CCResult in
               [
                 (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                 (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
               ])

          let to_yojson = function
            | V0 v -> V0.to_yojson v
            | V1 v -> V1.to_yojson v
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Issue_field_values = struct
        module Items = struct
          module Confidence = struct
            let t_of_yojson = function
              | `String "high" -> Ok `High
              | `String "low" -> Ok `Low
              | `String "medium" -> Ok `Medium
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `High -> `String "high"
              | `Low -> `String "low"
              | `Medium -> `String "medium"

            type t =
              ([ `High
               | `Low
               | `Medium
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module Value = struct
            module V0 = struct
              type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module V1 = struct
              type t = float [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module V2 = struct
              type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t =
              | V0 of V0.t
              | V1 of V1.t
              | V2 of V2.t
            [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [
                   (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                   (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                   (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
                 ])

            let to_yojson = function
              | V0 v -> V0.to_yojson v
              | V1 v -> V1.to_yojson v
              | V2 v -> V2.to_yojson v
          end

          type t = {
            confidence : Confidence.t option; [@default None]
            field_id : int;
            rationale : string option; [@default None]
            suggest : bool option; [@default None]
            value : Value.t;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Labels = struct
        module Items = struct
          module V0 = struct
            type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            module Primary = struct
              module Confidence = struct
                let t_of_yojson = function
                  | `String "high" -> Ok `High
                  | `String "low" -> Ok `Low
                  | `String "medium" -> Ok `Medium
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `High -> `String "high"
                  | `Low -> `String "low"
                  | `Medium -> `String "medium"

                type t =
                  ([ `High
                   | `Low
                   | `Medium
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                color : string option; [@default None]
                confidence : Confidence.t option; [@default None]
                description : string option; [@default None]
                id : int option; [@default None]
                name : string option; [@default None]
                rationale : string option; [@default None]
                suggest : bool option; [@default None]
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t =
            | V0 of V0.t
            | V1 of V1.t
          [@@deriving show, eq]

          let of_yojson =
            Json_schema.one_of
              (let open CCResult in
               [
                 (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                 (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
               ])

          let to_yojson = function
            | V0 v -> V0.to_yojson v
            | V1 v -> V1.to_yojson v
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Milestone = struct
        module V0 = struct
          type t = string option [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module V1 = struct
          type t = int option [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t =
          | V0 of V0.t
          | V1 of V1.t
        [@@deriving show, eq]

        let of_yojson =
          Json_schema.one_of
            (let open CCResult in
             [
               (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
               (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
             ])

        let to_yojson = function
          | V0 v -> V0.to_yojson v
          | V1 v -> V1.to_yojson v
      end

      module State = struct
        let t_of_yojson = function
          | `String "closed" -> Ok `Closed
          | `String "open" -> Ok `Open
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Closed -> `String "closed"
          | `Open -> `String "open"

        type t =
          ([ `Closed
           | `Open
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module State_reason = struct
        let t_of_yojson = function
          | `String "completed" -> Ok `Completed
          | `String "duplicate" -> Ok `Duplicate
          | `String "not_planned" -> Ok `Not_planned
          | `String "reopened" -> Ok `Reopened
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Completed -> `String "completed"
          | `Duplicate -> `String "duplicate"
          | `Not_planned -> `String "not_planned"
          | `Reopened -> `String "reopened"

        type t =
          ([ `Completed
           | `Duplicate
           | `Not_planned
           | `Reopened
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Title = struct
        module V0 = struct
          type t = string option [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module V1 = struct
          type t = int option [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t =
          | V0 of V0.t
          | V1 of V1.t
        [@@deriving show, eq]

        let of_yojson =
          Json_schema.one_of
            (let open CCResult in
             [
               (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
               (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
             ])

        let to_yojson = function
          | V0 v -> V0.to_yojson v
          | V1 v -> V1.to_yojson v
      end

      module Type = struct
        module V0 = struct
          type t = string option [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module V1 = struct
          module Primary = struct
            module Confidence = struct
              let t_of_yojson = function
                | `String "high" -> Ok `High
                | `String "low" -> Ok `Low
                | `String "medium" -> Ok `Medium
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `High -> `String "high"
                | `Low -> `String "low"
                | `Medium -> `String "medium"

              type t =
                ([ `High
                 | `Low
                 | `Medium
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              confidence : Confidence.t option; [@default None]
              rationale : string option; [@default None]
              suggest : bool option; [@default None]
              value : string option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t =
          | V0 of V0.t
          | V1 of V1.t
        [@@deriving show, eq]

        let of_yojson =
          Json_schema.one_of
            (let open CCResult in
             [
               (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
               (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
             ])

        let to_yojson = function
          | V0 v -> V0.to_yojson v
          | V1 v -> V1.to_yojson v
      end

      type t = {
        assignee : string option; [@default None]
        assignees : Assignees.t option; [@default None]
        body : string option; [@default None]
        duplicate_issue_id : int option; [@default None]
        issue_field_values : Issue_field_values.t option; [@default None]
        labels : Labels.t option; [@default None]
        milestone : Milestone.t option; [@default None]
        state : State.t option; [@default None]
        state_reason : State_reason.t option; [@default None]
        title : Title.t option; [@default None]
        type_ : Type.t option; [@default None] [@key "type"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int

  module Responses = struct
    module OK = struct
      module All_of = struct
        module Primary = struct
          module Assignees = struct
            type t = Githubc2_components.Simple_user.t list
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Issue_field_values = struct
            type t = Githubc2_components.Issue_field_value.t list
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Labels = struct
            module Items = struct
              module V0 = struct
                type t = string [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module V1 = struct
                module Primary = struct
                  type t = {
                    color : string option; [@default None]
                    default : bool option; [@default None]
                    description : string option; [@default None]
                    id : int64 option; [@default None]
                    name : string option; [@default None]
                    node_id : string option; [@default None]
                    url : string option; [@default None]
                  }
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t =
                | V0 of V0.t
                | V1 of V1.t
              [@@deriving show, eq]

              let of_yojson =
                Json_schema.one_of
                  (let open CCResult in
                   [
                     (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                     (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                   ])

              let to_yojson = function
                | V0 v -> V0.to_yojson v
                | V1 v -> V1.to_yojson v
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Pull_request = struct
            module Primary = struct
              type t = {
                diff_url : string option; [@default None]
                html_url : string option; [@default None]
                merged_at : string option; [@default None]
                patch_url : string option; [@default None]
                url : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module State_reason = struct
            let t_of_yojson = function
              | `String "completed" -> Ok `Completed
              | `String "duplicate" -> Ok `Duplicate
              | `String "not_planned" -> Ok `Not_planned
              | `String "reopened" -> Ok `Reopened
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Completed -> `String "completed"
              | `Duplicate -> `String "duplicate"
              | `Not_planned -> `String "not_planned"
              | `Reopened -> `String "reopened"

            type t =
              ([ `Completed
               | `Duplicate
               | `Not_planned
               | `Reopened
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Suggestions = struct
            module Primary = struct
              module Assignees = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      login : string option; [@default None]
                      rationale : string option; [@default None]
                      suggest : bool option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Issue_field_values = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Value = struct
                      module V0 = struct
                        type t = string
                        [@@deriving yojson { strict = false; meta = false }, show, eq]
                      end

                      module V1 = struct
                        type t = float
                        [@@deriving yojson { strict = false; meta = false }, show, eq]
                      end

                      module V2 = struct
                        type t = string list
                        [@@deriving yojson { strict = false; meta = false }, show, eq]
                      end

                      type t =
                        | V0 of V0.t
                        | V1 of V1.t
                        | V2 of V2.t
                      [@@deriving show, eq]

                      let of_yojson =
                        Json_schema.one_of
                          (let open CCResult in
                           [
                             (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                             (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                             (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
                           ])

                      let to_yojson = function
                        | V0 v -> V0.to_yojson v
                        | V1 v -> V1.to_yojson v
                        | V2 v -> V2.to_yojson v
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      field_id : int option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      rationale : string option; [@default None]
                      suggest : bool option; [@default None]
                      value : Value.t option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Labels = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      name : string option; [@default None]
                      rationale : string option; [@default None]
                      suggest : bool option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module State = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      duplicate_issue_id : int option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      rationale : string option; [@default None]
                      state_reason : string option; [@default None]
                      suggest : bool option; [@default None]
                      value : string option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Type = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      rationale : string option; [@default None]
                      suggest : bool option; [@default None]
                      value : string option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                assignees : Assignees.t option; [@default None]
                issue_field_values : Issue_field_values.t option; [@default None]
                labels : Labels.t option; [@default None]
                state : State.t option; [@default None]
                type_ : Type.t option; [@default None] [@key "type"]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = {
            active_lock_reason : string option; [@default None]
            assignee : Githubc2_components.Nullable_simple_user.t option; [@default None]
            assignees : Assignees.t option; [@default None]
            author_association : Githubc2_components.Author_association.t option; [@default None]
            body : string option; [@default None]
            body_html : string option; [@default None]
            body_text : string option; [@default None]
            closed_at : string option; [@default None]
            closed_by : Githubc2_components.Nullable_simple_user.t option; [@default None]
            comments : int;
            comments_url : string;
            created_at : string;
            draft : bool option; [@default None]
            events_url : string;
            html_url : string;
            id : int64;
            issue_dependencies_summary : Githubc2_components.Issue_dependencies_summary.t option;
                [@default None]
            issue_field_values : Issue_field_values.t option; [@default None]
            labels : Labels.t;
            labels_url : string;
            locked : bool;
            milestone : Githubc2_components.Nullable_milestone.t option; [@default None]
            node_id : string;
            number : int;
            parent_issue_url : string option; [@default None]
            performed_via_github_app : Githubc2_components.Nullable_integration.t option;
                [@default None]
            pinned_comment : Githubc2_components.Nullable_issue_comment.t option; [@default None]
            pull_request : Pull_request.t option; [@default None]
            reactions : Githubc2_components.Reaction_rollup.t option; [@default None]
            repository : Githubc2_components.Repository.t option; [@default None]
            repository_url : string;
            state : string;
            state_reason : State_reason.t option; [@default None]
            sub_issues_summary : Githubc2_components.Sub_issues_summary.t option; [@default None]
            suggestions : Suggestions.t option; [@default None]
            timeline_url : string option; [@default None]
            title : string;
            type_ : Githubc2_components.Issue_type.t option; [@default None] [@key "type"]
            updated_at : string;
            url : string;
            user : Githubc2_components.Nullable_simple_user.t option; [@default None]
          }
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module T = struct
        module Primary = struct
          module Assignees = struct
            type t = Githubc2_components.Simple_user.t list
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Issue_field_values = struct
            type t = Githubc2_components.Issue_field_value.t list
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Labels = struct
            module Items = struct
              module V0 = struct
                type t = string [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module V1 = struct
                module Primary = struct
                  type t = {
                    color : string option; [@default None]
                    default : bool option; [@default None]
                    description : string option; [@default None]
                    id : int64 option; [@default None]
                    name : string option; [@default None]
                    node_id : string option; [@default None]
                    url : string option; [@default None]
                  }
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t =
                | V0 of V0.t
                | V1 of V1.t
              [@@deriving show, eq]

              let of_yojson =
                Json_schema.one_of
                  (let open CCResult in
                   [
                     (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                     (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                   ])

              let to_yojson = function
                | V0 v -> V0.to_yojson v
                | V1 v -> V1.to_yojson v
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Pull_request = struct
            module Primary = struct
              type t = {
                diff_url : string option; [@default None]
                html_url : string option; [@default None]
                merged_at : string option; [@default None]
                patch_url : string option; [@default None]
                url : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module State_reason = struct
            let t_of_yojson = function
              | `String "completed" -> Ok `Completed
              | `String "duplicate" -> Ok `Duplicate
              | `String "not_planned" -> Ok `Not_planned
              | `String "reopened" -> Ok `Reopened
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Completed -> `String "completed"
              | `Duplicate -> `String "duplicate"
              | `Not_planned -> `String "not_planned"
              | `Reopened -> `String "reopened"

            type t =
              ([ `Completed
               | `Duplicate
               | `Not_planned
               | `Reopened
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Suggestions = struct
            module Primary = struct
              module Assignees = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      login : string option; [@default None]
                      rationale : string option; [@default None]
                      suggest : bool option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Issue_field_values = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Value = struct
                      module V0 = struct
                        type t = string
                        [@@deriving yojson { strict = false; meta = false }, show, eq]
                      end

                      module V1 = struct
                        type t = float
                        [@@deriving yojson { strict = false; meta = false }, show, eq]
                      end

                      module V2 = struct
                        type t = string list
                        [@@deriving yojson { strict = false; meta = false }, show, eq]
                      end

                      type t =
                        | V0 of V0.t
                        | V1 of V1.t
                        | V2 of V2.t
                      [@@deriving show, eq]

                      let of_yojson =
                        Json_schema.one_of
                          (let open CCResult in
                           [
                             (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                             (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                             (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
                           ])

                      let to_yojson = function
                        | V0 v -> V0.to_yojson v
                        | V1 v -> V1.to_yojson v
                        | V2 v -> V2.to_yojson v
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      field_id : int option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      rationale : string option; [@default None]
                      suggest : bool option; [@default None]
                      value : Value.t option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Labels = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      name : string option; [@default None]
                      rationale : string option; [@default None]
                      suggest : bool option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module State = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      duplicate_issue_id : int option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      rationale : string option; [@default None]
                      state_reason : string option; [@default None]
                      suggest : bool option; [@default None]
                      value : string option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Type = struct
                module Items = struct
                  module Primary = struct
                    module Confidence = struct
                      let t_of_yojson = function
                        | `String "high" -> Ok `High
                        | `String "low" -> Ok `Low
                        | `String "medium" -> Ok `Medium
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `High -> `String "high"
                        | `Low -> `String "low"
                        | `Medium -> `String "medium"

                      type t =
                        ([ `High
                         | `Low
                         | `Medium
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Ignored_reason = struct
                      let t_of_yojson = function
                        | `String "already_applied" -> Ok `Already_applied
                        | `String "issue_already_closed" -> Ok `Issue_already_closed
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Already_applied -> `String "already_applied"
                        | `Issue_already_closed -> `String "issue_already_closed"

                      type t =
                        ([ `Already_applied
                         | `Issue_already_closed
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      confidence : Confidence.t option; [@default None]
                      ignored : bool option; [@default None]
                      ignored_reason : Ignored_reason.t option; [@default None]
                      rationale : string option; [@default None]
                      suggest : bool option; [@default None]
                      value : string option; [@default None]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                assignees : Assignees.t option; [@default None]
                issue_field_values : Issue_field_values.t option; [@default None]
                labels : Labels.t option; [@default None]
                state : State.t option; [@default None]
                type_ : Type.t option; [@default None] [@key "type"]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = {
            active_lock_reason : string option; [@default None]
            assignee : Githubc2_components.Nullable_simple_user.t option; [@default None]
            assignees : Assignees.t option; [@default None]
            author_association : Githubc2_components.Author_association.t option; [@default None]
            body : string option; [@default None]
            body_html : string option; [@default None]
            body_text : string option; [@default None]
            closed_at : string option; [@default None]
            closed_by : Githubc2_components.Nullable_simple_user.t option; [@default None]
            comments : int;
            comments_url : string;
            created_at : string;
            draft : bool option; [@default None]
            events_url : string;
            html_url : string;
            id : int64;
            issue_dependencies_summary : Githubc2_components.Issue_dependencies_summary.t option;
                [@default None]
            issue_field_values : Issue_field_values.t option; [@default None]
            labels : Labels.t;
            labels_url : string;
            locked : bool;
            milestone : Githubc2_components.Nullable_milestone.t option; [@default None]
            node_id : string;
            number : int;
            parent_issue_url : string option; [@default None]
            performed_via_github_app : Githubc2_components.Nullable_integration.t option;
                [@default None]
            pinned_comment : Githubc2_components.Nullable_issue_comment.t option; [@default None]
            pull_request : Pull_request.t option; [@default None]
            reactions : Githubc2_components.Reaction_rollup.t option; [@default None]
            repository : Githubc2_components.Repository.t option; [@default None]
            repository_url : string;
            state : string;
            state_reason : State_reason.t option; [@default None]
            sub_issues_summary : Githubc2_components.Sub_issues_summary.t option; [@default None]
            suggestions : Suggestions.t option; [@default None]
            timeline_url : string option; [@default None]
            title : string;
            type_ : Githubc2_components.Issue_type.t option; [@default None] [@key "type"]
            updated_at : string;
            url : string;
            user : Githubc2_components.Nullable_simple_user.t option; [@default None]
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

    module Moved_permanently = struct
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Get = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Moved_permanently = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_modified
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("issue_number", Var (params.issue_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_event = struct
  module Parameters = struct
    type t = {
      event_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" / "events" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_event.t
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/events/{event_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("event_id", Var (params.event_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_events_for_repo = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    / "events"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_event.t list
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

  let url = "/repos/{owner}/{repo}/issues/events"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Unpin_comment = struct
  module Parameters = struct
    type t = {
      comment_id : int64;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    / "comments"
    /% Path.ud CCInt64.of_string
    / "pin"

  module Responses = struct
    module No_content = struct end

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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/comments/{comment_id}/pin"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("comment_id", Var (params.comment_id, Int64));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Pin_comment = struct
  module Parameters = struct
    type t = {
      comment_id : int64;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    / "comments"
    /% Path.ud CCInt64.of_string
    / "pin"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_comment.t
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

    module Gone = struct
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
      | `Gone of Gone.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/comments/{comment_id}/pin"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("comment_id", Var (params.comment_id, Int64));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Update_comment = struct
  module Parameters = struct
    type t = {
      comment_id : int64;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { body : string } [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" / "comments" /% Path.ud CCInt64.of_string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_comment.t
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

  let url = "/repos/{owner}/{repo}/issues/comments/{comment_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("comment_id", Var (params.comment_id, Int64));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_comment = struct
  module Parameters = struct
    type t = {
      comment_id : int64;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" / "comments" /% Path.ud CCInt64.of_string

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/issues/comments/{comment_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("comment_id", Var (params.comment_id, Int64));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_comment = struct
  module Parameters = struct
    type t = {
      comment_id : int64;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues" / "comments" /% Path.ud CCInt64.of_string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_comment.t
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

  let url = "/repos/{owner}/{repo}/issues/comments/{comment_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("comment_id", Var (params.comment_id, Int64));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_comments_for_repo = struct
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
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
      since : string option; [@default None]
      sort : Sort.t; [@default `Created]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    / "comments"
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "since")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_comment.t list
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

  let url = "/repos/{owner}/{repo}/issues/comments"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Option (Enum Direction.t_to_yojson)));
           ("since", Var (params.since, Option String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Assignees = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Issue_field_values = struct
        module Items = struct
          module Value = struct
            module V0 = struct
              type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module V1 = struct
              type t = float [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module V2 = struct
              type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t =
              | V0 of V0.t
              | V1 of V1.t
              | V2 of V2.t
            [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [
                   (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                   (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                   (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
                 ])

            let to_yojson = function
              | V0 v -> V0.to_yojson v
              | V1 v -> V1.to_yojson v
              | V2 v -> V2.to_yojson v
          end

          type t = {
            field_id : int;
            value : Value.t;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Labels = struct
        module Items = struct
          module V0 = struct
            type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            module Primary = struct
              type t = {
                color : string option; [@default None]
                description : string option; [@default None]
                id : int option; [@default None]
                name : string option; [@default None]
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t =
            | V0 of V0.t
            | V1 of V1.t
          [@@deriving show, eq]

          let of_yojson =
            Json_schema.one_of
              (let open CCResult in
               [
                 (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                 (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
               ])

          let to_yojson = function
            | V0 v -> V0.to_yojson v
            | V1 v -> V1.to_yojson v
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Milestone = struct
        module V0 = struct
          type t = string option [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module V1 = struct
          type t = int option [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t =
          | V0 of V0.t
          | V1 of V1.t
        [@@deriving show, eq]

        let of_yojson =
          Json_schema.one_of
            (let open CCResult in
             [
               (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
               (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
             ])

        let to_yojson = function
          | V0 v -> V0.to_yojson v
          | V1 v -> V1.to_yojson v
      end

      module Title = struct
        module V0 = struct
          type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module V1 = struct
          type t = int [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t =
          | V0 of V0.t
          | V1 of V1.t
        [@@deriving show, eq]

        let of_yojson =
          Json_schema.one_of
            (let open CCResult in
             [
               (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
               (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
             ])

        let to_yojson = function
          | V0 v -> V0.to_yojson v
          | V1 v -> V1.to_yojson v
      end

      type t = {
        assignee : string option; [@default None]
        assignees : Assignees.t option; [@default None]
        body : string option; [@default None]
        issue_field_values : Issue_field_values.t option; [@default None]
        labels : Labels.t option; [@default None]
        milestone : Milestone.t option; [@default None]
        title : Title.t;
        type_ : string option; [@default None] [@key "type"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issues"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Issue.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
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

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      module Primary = struct
        type t = {
          code : string option; [@default None]
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/issues"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_for_repo = struct
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
        | `String "comments" -> Ok `Comments
        | `String "created" -> Ok `Created
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Comments -> `String "comments"
        | `Created -> `String "created"
        | `Updated -> `String "updated"

      type t =
        ([ `Comments
         | `Created
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "closed" -> Ok `Closed
        | `String "open" -> Ok `Open
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Closed -> `String "closed"
        | `Open -> `String "open"

      type t =
        ([ `All
         | `Closed
         | `Open
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      assignee : string option; [@default None]
      creator : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      issue_field_values : string option; [@default None]
      labels : string option; [@default None]
      mentioned : string option; [@default None]
      milestone : string option; [@default None]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
      since : string option; [@default None]
      sort : Sort.t; [@default `Created]
      state : State.t; [@default `Open]
      type_ : string option; [@default None] [@key "type"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "issues"
    /? option (string "milestone")
    /? option_default
         `Open
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option (string "assignee")
    /? option (string "type")
    /? option (string "creator")
    /? option (string "mentioned")
    /? option (string "issue_field_values")
    /? option (string "labels")
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "since")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t list
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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("milestone", Var (params.milestone, Option String));
           ("state", Var (params.state, Enum State.t_to_yojson));
           ("assignee", Var (params.assignee, Option String));
           ("type", Var (params.type_, Option String));
           ("creator", Var (params.creator, Option String));
           ("mentioned", Var (params.mentioned, Option String));
           ("issue_field_values", Var (params.issue_field_values, Option String));
           ("labels", Var (params.labels, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("since", Var (params.since, Option String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Check_user_can_be_assigned = struct
  module Parameters = struct
    type t = {
      assignee : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "assignees" /% Path.string

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

  let url = "/repos/{owner}/{repo}/assignees/{assignee}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("assignee", Var (params.assignee, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_assignees = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "assignees"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Simple_user.t list
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

  let url = "/repos/{owner}/{repo}/assignees"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_for_org = struct
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

    module Filter = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "assigned" -> Ok `Assigned
        | `String "created" -> Ok `Created
        | `String "mentioned" -> Ok `Mentioned
        | `String "repos" -> Ok `Repos
        | `String "subscribed" -> Ok `Subscribed
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Assigned -> `String "assigned"
        | `Created -> `String "created"
        | `Mentioned -> `String "mentioned"
        | `Repos -> `String "repos"
        | `Subscribed -> `String "subscribed"

      type t =
        ([ `All
         | `Assigned
         | `Created
         | `Mentioned
         | `Repos
         | `Subscribed
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "comments" -> Ok `Comments
        | `String "created" -> Ok `Created
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Comments -> `String "comments"
        | `Created -> `String "created"
        | `Updated -> `String "updated"

      type t =
        ([ `Comments
         | `Created
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "closed" -> Ok `Closed
        | `String "open" -> Ok `Open
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Closed -> `String "closed"
        | `Open -> `String "open"

      type t =
        ([ `All
         | `Closed
         | `Open
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t; [@default `Desc]
      filter : Filter.t; [@default `Assigned]
      labels : string option; [@default None]
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      since : string option; [@default None]
      sort : Sort.t; [@default `Created]
      state : State.t; [@default `Open]
      type_ : string option; [@default None] [@key "type"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "issues"
    /? option_default
         `Assigned
         (ud "filter" (fun value -> CCResult.to_opt (Parameters.Filter.t_of_yojson (`String value))))
    /? option_default
         `Open
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option (string "labels")
    /? option (string "type")
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "since")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t list
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

  let url = "/orgs/{org}/issues"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("filter", Var (params.filter, Enum Filter.t_to_yojson));
           ("state", Var (params.state, Enum State.t_to_yojson));
           ("labels", Var (params.labels, Option String));
           ("type", Var (params.type_, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("since", Var (params.since, Option String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List = struct
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

    module Filter = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "assigned" -> Ok `Assigned
        | `String "created" -> Ok `Created
        | `String "mentioned" -> Ok `Mentioned
        | `String "repos" -> Ok `Repos
        | `String "subscribed" -> Ok `Subscribed
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Assigned -> `String "assigned"
        | `Created -> `String "created"
        | `Mentioned -> `String "mentioned"
        | `Repos -> `String "repos"
        | `Subscribed -> `String "subscribed"

      type t =
        ([ `All
         | `Assigned
         | `Created
         | `Mentioned
         | `Repos
         | `Subscribed
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "comments" -> Ok `Comments
        | `String "created" -> Ok `Created
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Comments -> `String "comments"
        | `Created -> `String "created"
        | `Updated -> `String "updated"

      type t =
        ([ `Comments
         | `Created
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "closed" -> Ok `Closed
        | `String "open" -> Ok `Open
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Closed -> `String "closed"
        | `Open -> `String "open"

      type t =
        ([ `All
         | `Closed
         | `Open
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      collab : bool option; [@default None]
      direction : Direction.t; [@default `Desc]
      filter : Filter.t; [@default `Assigned]
      labels : string option; [@default None]
      orgs : bool option; [@default None]
      owned : bool option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 30]
      pulls : bool option; [@default None]
      since : string option; [@default None]
      sort : Sort.t; [@default `Created]
      state : State.t; [@default `Open]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "issues"
    /? option_default
         `Assigned
         (ud "filter" (fun value -> CCResult.to_opt (Parameters.Filter.t_of_yojson (`String value))))
    /? option_default
         `Open
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option (string "labels")
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "since")
    /? option (bool "collab")
    /? option (bool "orgs")
    /? option (bool "owned")
    /? option (bool "pulls")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

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
      | `Not_modified
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/issues"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("filter", Var (params.filter, Enum Filter.t_to_yojson));
           ("state", Var (params.state, Enum State.t_to_yojson));
           ("labels", Var (params.labels, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("since", Var (params.since, Option String));
           ("collab", Var (params.collab, Option Bool));
           ("orgs", Var (params.orgs, Option Bool));
           ("owned", Var (params.owned, Option Bool));
           ("pulls", Var (params.pulls, Option Bool));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
