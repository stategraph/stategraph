module Users = struct
  module Parameters = struct
    module Order = struct
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
        | `String "followers" -> Ok `Followers
        | `String "joined" -> Ok `Joined
        | `String "repositories" -> Ok `Repositories
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Followers -> `String "followers"
        | `Joined -> `String "joined"
        | `Repositories -> `String "repositories"

      type t =
        ([ `Followers
         | `Joined
         | `Repositories
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      order : Order.t; [@default `Desc]
      page : int; [@default 1]
      per_page : int; [@default 30]
      q : string;
      sort : Sort.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "q"
    /? option
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "order" (fun value -> CCResult.to_opt (Parameters.Order.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Items = struct
          type t = Githubc2_components.User_search_result_item.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          incomplete_results : bool;
          items : Items.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_modified = struct end

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
      | `Not_modified
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/search/users"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("q", Var (params.q, String));
           ("sort", Var (params.sort, Option (Enum Sort.t_to_yojson)));
           ("order", Var (params.order, Enum Order.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Topics = struct
  module Parameters = struct
    type t = {
      page : int; [@default 1]
      per_page : int; [@default 30]
      q : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "q" /? option_default 30 (int "per_page") /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Items = struct
          type t = Githubc2_components.Topic_search_result_item.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          incomplete_results : bool;
          items : Items.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_modified = struct end

    type t =
      [ `OK of OK.t
      | `Not_modified
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
      ]
  end

  let url = "/search/topics"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("q", Var (params.q, String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Repos = struct
  module Parameters = struct
    module Order = struct
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
        | `String "forks" -> Ok `Forks
        | `String "help-wanted-issues" -> Ok `Help_wanted_issues
        | `String "stars" -> Ok `Stars
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Forks -> `String "forks"
        | `Help_wanted_issues -> `String "help-wanted-issues"
        | `Stars -> `String "stars"
        | `Updated -> `String "updated"

      type t =
        ([ `Forks
         | `Help_wanted_issues
         | `Stars
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      order : Order.t; [@default `Desc]
      page : int; [@default 1]
      per_page : int; [@default 30]
      q : string;
      sort : Sort.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "q"
    /? option
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "order" (fun value -> CCResult.to_opt (Parameters.Order.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Items = struct
          type t = Githubc2_components.Repo_search_result_item.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          incomplete_results : bool;
          items : Items.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_modified = struct end

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
      | `Not_modified
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/search/repositories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("q", Var (params.q, String));
           ("sort", Var (params.sort, Option (Enum Sort.t_to_yojson)));
           ("order", Var (params.order, Enum Order.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Labels = struct
  module Parameters = struct
    module Order = struct
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
      order : Order.t; [@default `Desc]
      page : int; [@default 1]
      per_page : int; [@default 30]
      q : string;
      repository_id : int;
      sort : Sort.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? int "repository_id"
    /? string "q"
    /? option
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "order" (fun value -> CCResult.to_opt (Parameters.Order.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Items = struct
          type t = Githubc2_components.Label_search_result_item.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          incomplete_results : bool;
          items : Items.t;
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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/search/labels"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("repository_id", Var (params.repository_id, Int));
           ("q", Var (params.q, String));
           ("sort", Var (params.sort, Option (Enum Sort.t_to_yojson)));
           ("order", Var (params.order, Enum Order.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Issues_and_pull_requests = struct
  module Parameters = struct
    module Order = struct
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

    module Search_type = struct
      let t_of_yojson = function
        | `String "hybrid" -> Ok `Hybrid
        | `String "semantic" -> Ok `Semantic
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Hybrid -> `String "hybrid"
        | `Semantic -> `String "semantic"

      type t =
        ([ `Hybrid
         | `Semantic
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "comments" -> Ok `Comments
        | `String "created" -> Ok `Created
        | `String "interactions" -> Ok `Interactions
        | `String "reactions" -> Ok `Reactions
        | `String "reactions-+1" -> Ok `Reactions__1
        | `String "reactions--1" -> Ok `Reactions__1_2
        | `String "reactions-heart" -> Ok `Reactions_heart
        | `String "reactions-smile" -> Ok `Reactions_smile
        | `String "reactions-tada" -> Ok `Reactions_tada
        | `String "reactions-thinking_face" -> Ok `Reactions_thinking_face
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Comments -> `String "comments"
        | `Created -> `String "created"
        | `Interactions -> `String "interactions"
        | `Reactions -> `String "reactions"
        | `Reactions__1 -> `String "reactions-+1"
        | `Reactions__1_2 -> `String "reactions--1"
        | `Reactions_heart -> `String "reactions-heart"
        | `Reactions_smile -> `String "reactions-smile"
        | `Reactions_tada -> `String "reactions-tada"
        | `Reactions_thinking_face -> `String "reactions-thinking_face"
        | `Updated -> `String "updated"

      type t =
        ([ `Comments
         | `Created
         | `Interactions
         | `Reactions
         | `Reactions__1
         | `Reactions__1_2
         | `Reactions_heart
         | `Reactions_smile
         | `Reactions_tada
         | `Reactions_thinking_face
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      advanced_search : string option; [@default None]
      order : Order.t; [@default `Desc]
      page : int; [@default 1]
      per_page : int; [@default 30]
      q : string;
      search_type : Search_type.t option; [@default None]
      sort : Sort.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "q"
    /? option
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "order" (fun value -> CCResult.to_opt (Parameters.Order.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option (string "advanced_search")
    /? option
         (ud "search_type" (fun value ->
              CCResult.to_opt (Parameters.Search_type.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Items = struct
          type t = Githubc2_components.Issue_search_result_item.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        module Lexical_fallback_reason = struct
          module Items = struct
            let t_of_yojson = function
              | `String "no_accessible_repos" -> Ok `No_accessible_repos
              | `String "no_text_terms" -> Ok `No_text_terms
              | `String "non_issue_target" -> Ok `Non_issue_target
              | `String "only_non_semantic_fields_requested" ->
                  Ok `Only_non_semantic_fields_requested
              | `String "or_boolean_not_supported" -> Ok `Or_boolean_not_supported
              | `String "quoted_text" -> Ok `Quoted_text
              | `String "server_error" -> Ok `Server_error
              | `String "service_unavailable" -> Ok `Service_unavailable
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `No_accessible_repos -> `String "no_accessible_repos"
              | `No_text_terms -> `String "no_text_terms"
              | `Non_issue_target -> `String "non_issue_target"
              | `Only_non_semantic_fields_requested -> `String "only_non_semantic_fields_requested"
              | `Or_boolean_not_supported -> `String "or_boolean_not_supported"
              | `Quoted_text -> `String "quoted_text"
              | `Server_error -> `String "server_error"
              | `Service_unavailable -> `String "service_unavailable"

            type t =
              ([ `No_accessible_repos
               | `No_text_terms
               | `Non_issue_target
               | `Only_non_semantic_fields_requested
               | `Or_boolean_not_supported
               | `Quoted_text
               | `Server_error
               | `Service_unavailable
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        module Search_type = struct
          let t_of_yojson = function
            | `String "hybrid" -> Ok `Hybrid
            | `String "lexical" -> Ok `Lexical
            | `String "semantic" -> Ok `Semantic
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Hybrid -> `String "hybrid"
            | `Lexical -> `String "lexical"
            | `Semantic -> `String "semantic"

          type t =
            ([ `Hybrid
             | `Lexical
             | `Semantic
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          incomplete_results : bool;
          items : Items.t;
          lexical_fallback_reason : Lexical_fallback_reason.t option; [@default None]
          search_type : Search_type.t;
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
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/search/issues"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("q", Var (params.q, String));
           ("sort", Var (params.sort, Option (Enum Sort.t_to_yojson)));
           ("order", Var (params.order, Enum Order.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("advanced_search", Var (params.advanced_search, Option String));
           ("search_type", Var (params.search_type, Option (Enum Search_type.t_to_yojson)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Commits = struct
  module Parameters = struct
    module Order = struct
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
        | `String "author-date" -> Ok `Author_date
        | `String "committer-date" -> Ok `Committer_date
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Author_date -> `String "author-date"
        | `Committer_date -> `String "committer-date"

      type t =
        ([ `Author_date
         | `Committer_date
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      order : Order.t; [@default `Desc]
      page : int; [@default 1]
      per_page : int; [@default 30]
      q : string;
      sort : Sort.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "q"
    /? option
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "order" (fun value -> CCResult.to_opt (Parameters.Order.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Items = struct
          type t = Githubc2_components.Commit_search_result_item.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          incomplete_results : bool;
          items : Items.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_modified = struct end

    type t =
      [ `OK of OK.t
      | `Not_modified
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
      ]
  end

  let url = "/search/commits"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("q", Var (params.q, String));
           ("sort", Var (params.sort, Option (Enum Sort.t_to_yojson)));
           ("order", Var (params.order, Enum Order.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Code = struct
  module Parameters = struct
    module Order = struct
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
        | `String "indexed" -> Ok `Indexed
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Indexed -> `String "indexed"

      type t = ([ `Indexed ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson]) [@@deriving show, eq]
    end

    type t = {
      order : Order.t; [@default `Desc]
      page : int; [@default 1]
      per_page : int; [@default 30]
      q : string;
      sort : Sort.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "q"
    /? option
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "order" (fun value -> CCResult.to_opt (Parameters.Order.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Items = struct
          type t = Githubc2_components.Code_search_result_item.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          incomplete_results : bool;
          items : Items.t;
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
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/search/code"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("q", Var (params.q, String));
           ("sort", Var (params.sort, Option (Enum Sort.t_to_yojson)));
           ("order", Var (params.order, Enum Order.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
