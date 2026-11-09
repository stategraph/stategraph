module Delete_for_release = struct
  module Parameters = struct
    type t = {
      owner : string;
      reaction_id : int;
      release_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/releases/{release_id}/reactions/{reaction_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("release_id", Var (params.release_id, Int));
           ("reaction_id", Var (params.reaction_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_for_release = struct
  module Parameters = struct
    type t = {
      owner : string;
      release_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Content = struct
        let t_of_yojson = function
          | `String "+1" -> Ok `_1
          | `String "eyes" -> Ok `Eyes
          | `String "heart" -> Ok `Heart
          | `String "hooray" -> Ok `Hooray
          | `String "laugh" -> Ok `Laugh
          | `String "rocket" -> Ok `Rocket
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `_1 -> `String "+1"
          | `Eyes -> `String "eyes"
          | `Heart -> `String "heart"
          | `Hooray -> `String "hooray"
          | `Laugh -> `String "laugh"
          | `Rocket -> `String "rocket"

        type t =
          ([ `_1
           | `Eyes
           | `Heart
           | `Hooray
           | `Laugh
           | `Rocket
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { content : Content.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Created of Created.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/releases/{release_id}/reactions"

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
           ("release_id", Var (params.release_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_for_release = struct
  module Parameters = struct
    module Content = struct
      let t_of_yojson = function
        | `String "+1" -> Ok `_1
        | `String "eyes" -> Ok `Eyes
        | `String "heart" -> Ok `Heart
        | `String "hooray" -> Ok `Hooray
        | `String "laugh" -> Ok `Laugh
        | `String "rocket" -> Ok `Rocket
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `_1 -> `String "+1"
        | `Eyes -> `String "eyes"
        | `Heart -> `String "heart"
        | `Hooray -> `String "hooray"
        | `Laugh -> `String "laugh"
        | `Rocket -> `String "rocket"

      type t =
        ([ `_1
         | `Eyes
         | `Heart
         | `Hooray
         | `Laugh
         | `Rocket
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      content : Content.t option; [@default None]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      release_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "content" (fun value ->
              CCResult.to_opt (Parameters.Content.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t list
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

  let url = "/repos/{owner}/{repo}/releases/{release_id}/reactions"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("release_id", Var (params.release_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("content", Var (params.content, Option (Enum Content.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_for_pull_request_comment = struct
  module Parameters = struct
    type t = {
      comment_id : int64;
      owner : string;
      reaction_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions/{reaction_id}"

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
           ("reaction_id", Var (params.reaction_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_for_pull_request_review_comment = struct
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
      module Content = struct
        let t_of_yojson = function
          | `String "+1" -> Ok `_1
          | `String "-1" -> Ok `_1_2
          | `String "confused" -> Ok `Confused
          | `String "eyes" -> Ok `Eyes
          | `String "heart" -> Ok `Heart
          | `String "hooray" -> Ok `Hooray
          | `String "laugh" -> Ok `Laugh
          | `String "rocket" -> Ok `Rocket
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `_1 -> `String "+1"
          | `_1_2 -> `String "-1"
          | `Confused -> `String "confused"
          | `Eyes -> `String "eyes"
          | `Heart -> `String "heart"
          | `Hooray -> `String "hooray"
          | `Laugh -> `String "laugh"
          | `Rocket -> `String "rocket"

        type t =
          ([ `_1
           | `_1_2
           | `Confused
           | `Eyes
           | `Heart
           | `Hooray
           | `Laugh
           | `Rocket
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { content : Content.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Created of Created.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions"

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
      `Post
end

module List_for_pull_request_review_comment = struct
  module Parameters = struct
    module Content = struct
      let t_of_yojson = function
        | `String "+1" -> Ok `_1
        | `String "-1" -> Ok `_1_2
        | `String "confused" -> Ok `Confused
        | `String "eyes" -> Ok `Eyes
        | `String "heart" -> Ok `Heart
        | `String "hooray" -> Ok `Hooray
        | `String "laugh" -> Ok `Laugh
        | `String "rocket" -> Ok `Rocket
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `_1 -> `String "+1"
        | `_1_2 -> `String "-1"
        | `Confused -> `String "confused"
        | `Eyes -> `String "eyes"
        | `Heart -> `String "heart"
        | `Hooray -> `String "hooray"
        | `Laugh -> `String "laugh"
        | `Rocket -> `String "rocket"

      type t =
        ([ `_1
         | `_1_2
         | `Confused
         | `Eyes
         | `Heart
         | `Hooray
         | `Laugh
         | `Rocket
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      comment_id : int64;
      content : Content.t option; [@default None]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "content" (fun value ->
              CCResult.to_opt (Parameters.Content.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t list
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

  let url = "/repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions"

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
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("content", Var (params.content, Option (Enum Content.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_for_issue = struct
  module Parameters = struct
    type t = {
      issue_number : int;
      owner : string;
      reaction_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/reactions/{reaction_id}"

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
           ("reaction_id", Var (params.reaction_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_for_issue = struct
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
      module Content = struct
        let t_of_yojson = function
          | `String "+1" -> Ok `_1
          | `String "-1" -> Ok `_1_2
          | `String "confused" -> Ok `Confused
          | `String "eyes" -> Ok `Eyes
          | `String "heart" -> Ok `Heart
          | `String "hooray" -> Ok `Hooray
          | `String "laugh" -> Ok `Laugh
          | `String "rocket" -> Ok `Rocket
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `_1 -> `String "+1"
          | `_1_2 -> `String "-1"
          | `Confused -> `String "confused"
          | `Eyes -> `String "eyes"
          | `Heart -> `String "heart"
          | `Hooray -> `String "hooray"
          | `Laugh -> `String "laugh"
          | `Rocket -> `String "rocket"

        type t =
          ([ `_1
           | `_1_2
           | `Confused
           | `Eyes
           | `Heart
           | `Hooray
           | `Laugh
           | `Rocket
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { content : Content.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Created of Created.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/reactions"

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

module List_for_issue = struct
  module Parameters = struct
    module Content = struct
      let t_of_yojson = function
        | `String "+1" -> Ok `_1
        | `String "-1" -> Ok `_1_2
        | `String "confused" -> Ok `Confused
        | `String "eyes" -> Ok `Eyes
        | `String "heart" -> Ok `Heart
        | `String "hooray" -> Ok `Hooray
        | `String "laugh" -> Ok `Laugh
        | `String "rocket" -> Ok `Rocket
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `_1 -> `String "+1"
        | `_1_2 -> `String "-1"
        | `Confused -> `String "confused"
        | `Eyes -> `String "eyes"
        | `Heart -> `String "heart"
        | `Hooray -> `String "hooray"
        | `Laugh -> `String "laugh"
        | `Rocket -> `String "rocket"

      type t =
        ([ `_1
         | `_1_2
         | `Confused
         | `Eyes
         | `Heart
         | `Hooray
         | `Laugh
         | `Rocket
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      content : Content.t option; [@default None]
      issue_number : int;
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "content" (fun value ->
              CCResult.to_opt (Parameters.Content.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t list
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

  let url = "/repos/{owner}/{repo}/issues/{issue_number}/reactions"

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
           ("content", Var (params.content, Option (Enum Content.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_for_issue_comment = struct
  module Parameters = struct
    type t = {
      comment_id : int64;
      owner : string;
      reaction_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/issues/comments/{comment_id}/reactions/{reaction_id}"

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
           ("reaction_id", Var (params.reaction_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_for_issue_comment = struct
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
      module Content = struct
        let t_of_yojson = function
          | `String "+1" -> Ok `_1
          | `String "-1" -> Ok `_1_2
          | `String "confused" -> Ok `Confused
          | `String "eyes" -> Ok `Eyes
          | `String "heart" -> Ok `Heart
          | `String "hooray" -> Ok `Hooray
          | `String "laugh" -> Ok `Laugh
          | `String "rocket" -> Ok `Rocket
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `_1 -> `String "+1"
          | `_1_2 -> `String "-1"
          | `Confused -> `String "confused"
          | `Eyes -> `String "eyes"
          | `Heart -> `String "heart"
          | `Hooray -> `String "hooray"
          | `Laugh -> `String "laugh"
          | `Rocket -> `String "rocket"

        type t =
          ([ `_1
           | `_1_2
           | `Confused
           | `Eyes
           | `Heart
           | `Hooray
           | `Laugh
           | `Rocket
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { content : Content.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Created of Created.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/issues/comments/{comment_id}/reactions"

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
      `Post
end

module List_for_issue_comment = struct
  module Parameters = struct
    module Content = struct
      let t_of_yojson = function
        | `String "+1" -> Ok `_1
        | `String "-1" -> Ok `_1_2
        | `String "confused" -> Ok `Confused
        | `String "eyes" -> Ok `Eyes
        | `String "heart" -> Ok `Heart
        | `String "hooray" -> Ok `Hooray
        | `String "laugh" -> Ok `Laugh
        | `String "rocket" -> Ok `Rocket
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `_1 -> `String "+1"
        | `_1_2 -> `String "-1"
        | `Confused -> `String "confused"
        | `Eyes -> `String "eyes"
        | `Heart -> `String "heart"
        | `Hooray -> `String "hooray"
        | `Laugh -> `String "laugh"
        | `Rocket -> `String "rocket"

      type t =
        ([ `_1
         | `_1_2
         | `Confused
         | `Eyes
         | `Heart
         | `Hooray
         | `Laugh
         | `Rocket
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      comment_id : int64;
      content : Content.t option; [@default None]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "content" (fun value ->
              CCResult.to_opt (Parameters.Content.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t list
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

  let url = "/repos/{owner}/{repo}/issues/comments/{comment_id}/reactions"

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
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("content", Var (params.content, Option (Enum Content.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_for_commit_comment = struct
  module Parameters = struct
    type t = {
      comment_id : int64;
      owner : string;
      reaction_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/comments/{comment_id}/reactions/{reaction_id}"

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
           ("reaction_id", Var (params.reaction_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_for_commit_comment = struct
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
      module Content = struct
        let t_of_yojson = function
          | `String "+1" -> Ok `_1
          | `String "-1" -> Ok `_1_2
          | `String "confused" -> Ok `Confused
          | `String "eyes" -> Ok `Eyes
          | `String "heart" -> Ok `Heart
          | `String "hooray" -> Ok `Hooray
          | `String "laugh" -> Ok `Laugh
          | `String "rocket" -> Ok `Rocket
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `_1 -> `String "+1"
          | `_1_2 -> `String "-1"
          | `Confused -> `String "confused"
          | `Eyes -> `String "eyes"
          | `Heart -> `String "heart"
          | `Hooray -> `String "hooray"
          | `Laugh -> `String "laugh"
          | `Rocket -> `String "rocket"

        type t =
          ([ `_1
           | `_1_2
           | `Confused
           | `Eyes
           | `Heart
           | `Hooray
           | `Laugh
           | `Rocket
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { content : Content.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Githubc2_components.Reaction.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Created of Created.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/comments/{comment_id}/reactions"

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
      `Post
end

module List_for_commit_comment = struct
  module Parameters = struct
    module Content = struct
      let t_of_yojson = function
        | `String "+1" -> Ok `_1
        | `String "-1" -> Ok `_1_2
        | `String "confused" -> Ok `Confused
        | `String "eyes" -> Ok `Eyes
        | `String "heart" -> Ok `Heart
        | `String "hooray" -> Ok `Hooray
        | `String "laugh" -> Ok `Laugh
        | `String "rocket" -> Ok `Rocket
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `_1 -> `String "+1"
        | `_1_2 -> `String "-1"
        | `Confused -> `String "confused"
        | `Eyes -> `String "eyes"
        | `Heart -> `String "heart"
        | `Hooray -> `String "hooray"
        | `Laugh -> `String "laugh"
        | `Rocket -> `String "rocket"

      type t =
        ([ `_1
         | `_1_2
         | `Confused
         | `Eyes
         | `Heart
         | `Hooray
         | `Laugh
         | `Rocket
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      comment_id : int64;
      content : Content.t option; [@default None]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "content" (fun value ->
              CCResult.to_opt (Parameters.Content.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Reaction.t list
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

  let url = "/repos/{owner}/{repo}/comments/{comment_id}/reactions"

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
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("content", Var (params.content, Option (Enum Content.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
