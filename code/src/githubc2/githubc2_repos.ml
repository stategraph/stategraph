module List_for_user = struct
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
        | `String "full_name" -> Ok `Full_name
        | `String "pushed" -> Ok `Pushed
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Full_name -> `String "full_name"
        | `Pushed -> `String "pushed"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Full_name
         | `Pushed
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Type = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "member" -> Ok `Member
        | `String "owner" -> Ok `Owner
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Member -> `String "member"
        | `Owner -> `String "owner"

      type t =
        ([ `All
         | `Member
         | `Owner
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 30]
      sort : Sort.t; [@default `Full_name]
      type_ : Type.t; [@default `Owner] [@key "type"]
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "repos"
    /? option_default
         `Owner
         (ud "type" (fun value -> CCResult.to_opt (Parameters.Type.t_of_yojson (`String value))))
    /? option_default
         `Full_name
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Minimal_repository.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/users/{username}/repos"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("username", Var (params.username, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("type", Var (params.type_, Enum Type.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Option (Enum Direction.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Accept_invitation_for_authenticated_user = struct
  module Parameters = struct
    type t = { invitation_id : int } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "user" / "repository_invitations" /% Path.int

  module Responses = struct
    module No_content = struct end
    module Not_modified = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/user/repository_invitations/{invitation_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("invitation_id", Var (params.invitation_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Decline_invitation_for_authenticated_user = struct
  module Parameters = struct
    type t = { invitation_id : int } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "user" / "repository_invitations" /% Path.int

  module Responses = struct
    module No_content = struct end
    module Not_modified = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/user/repository_invitations/{invitation_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("invitation_id", Var (params.invitation_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module List_invitations_for_authenticated_user = struct
  module Parameters = struct
    type t = {
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "repository_invitations"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_invitation.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
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

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/repository_invitations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_for_authenticated_user = struct
  module Parameters = struct end

  module Request_body = struct
    module Primary = struct
      module Merge_commit_message = struct
        let t_of_yojson = function
          | `String "BLANK" -> Ok `BLANK
          | `String "PR_BODY" -> Ok `PR_BODY
          | `String "PR_TITLE" -> Ok `PR_TITLE
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `BLANK -> `String "BLANK"
          | `PR_BODY -> `String "PR_BODY"
          | `PR_TITLE -> `String "PR_TITLE"

        type t =
          ([ `BLANK
           | `PR_BODY
           | `PR_TITLE
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Merge_commit_title = struct
        let t_of_yojson = function
          | `String "MERGE_MESSAGE" -> Ok `MERGE_MESSAGE
          | `String "PR_TITLE" -> Ok `PR_TITLE
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `MERGE_MESSAGE -> `String "MERGE_MESSAGE"
          | `PR_TITLE -> `String "PR_TITLE"

        type t =
          ([ `MERGE_MESSAGE
           | `PR_TITLE
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Squash_merge_commit_message = struct
        let t_of_yojson = function
          | `String "BLANK" -> Ok `BLANK
          | `String "COMMIT_MESSAGES" -> Ok `COMMIT_MESSAGES
          | `String "PR_BODY" -> Ok `PR_BODY
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `BLANK -> `String "BLANK"
          | `COMMIT_MESSAGES -> `String "COMMIT_MESSAGES"
          | `PR_BODY -> `String "PR_BODY"

        type t =
          ([ `BLANK
           | `COMMIT_MESSAGES
           | `PR_BODY
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Squash_merge_commit_title = struct
        let t_of_yojson = function
          | `String "COMMIT_OR_PR_TITLE" -> Ok `COMMIT_OR_PR_TITLE
          | `String "PR_TITLE" -> Ok `PR_TITLE
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `COMMIT_OR_PR_TITLE -> `String "COMMIT_OR_PR_TITLE"
          | `PR_TITLE -> `String "PR_TITLE"

        type t =
          ([ `COMMIT_OR_PR_TITLE
           | `PR_TITLE
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        allow_auto_merge : bool; [@default false]
        allow_merge_commit : bool; [@default true]
        allow_rebase_merge : bool; [@default true]
        allow_squash_merge : bool; [@default true]
        auto_init : bool; [@default false]
        delete_branch_on_merge : bool; [@default false]
        description : string option; [@default None]
        gitignore_template : string option; [@default None]
        has_discussions : bool; [@default false]
        has_downloads : bool; [@default true]
        has_issues : bool; [@default true]
        has_projects : bool; [@default true]
        has_wiki : bool; [@default true]
        homepage : string option; [@default None]
        is_template : bool; [@default false]
        license_template : string option; [@default None]
        merge_commit_message : Merge_commit_message.t option; [@default None]
        merge_commit_title : Merge_commit_title.t option; [@default None]
        name : string;
        private_ : bool; [@default false] [@key "private"]
        squash_merge_commit_message : Squash_merge_commit_message.t option; [@default None]
        squash_merge_commit_title : Squash_merge_commit_title.t option; [@default None]
        team_id : int option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "user" / "repos"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Full_repository.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Not_modified
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/user/repos"

  let make ~body =
   fun () ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

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

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "full_name" -> Ok `Full_name
        | `String "pushed" -> Ok `Pushed
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Full_name -> `String "full_name"
        | `Pushed -> `String "pushed"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Full_name
         | `Pushed
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Type = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "member" -> Ok `Member
        | `String "owner" -> Ok `Owner
        | `String "private" -> Ok `Private
        | `String "public" -> Ok `Public
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Member -> `String "member"
        | `Owner -> `String "owner"
        | `Private -> `String "private"
        | `Public -> `String "public"

      type t =
        ([ `All
         | `Member
         | `Owner
         | `Private
         | `Public
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Visibility = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "private" -> Ok `Private
        | `String "public" -> Ok `Public
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Private -> `String "private"
        | `Public -> `String "public"

      type t =
        ([ `All
         | `Private
         | `Public
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      affiliation : string; [@default "owner,collaborator,organization_member"]
      before : string option; [@default None]
      direction : Direction.t option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 30]
      since : string option; [@default None]
      sort : Sort.t; [@default `Full_name]
      type_ : Type.t; [@default `All] [@key "type"]
      visibility : Visibility.t; [@default `All]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "repos"
    /? option_default
         `All
         (ud "visibility" (fun value ->
              CCResult.to_opt (Parameters.Visibility.t_of_yojson (`String value))))
    /? option_default "owner,collaborator,organization_member" (string "affiliation")
    /? option_default
         `All
         (ud "type" (fun value -> CCResult.to_opt (Parameters.Type.t_of_yojson (`String value))))
    /? option_default
         `Full_name
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option (string "since")
    /? option (string "before")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
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
      ]
  end

  let url = "/user/repos"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("visibility", Var (params.visibility, Enum Visibility.t_to_yojson));
           ("affiliation", Var (params.affiliation, String));
           ("type", Var (params.type_, Enum Type.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Option (Enum Direction.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("since", Var (params.since, Option String));
           ("before", Var (params.before, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_public = struct
  module Parameters = struct
    type t = { since : int option [@default None] } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "repositories" /? option (int "since")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Minimal_repository.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repositories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("since", Var (params.since, Option Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_using_template = struct
  module Parameters = struct
    type t = {
      template_owner : string;
      template_repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        description : string option; [@default None]
        include_all_branches : bool; [@default false]
        name : string;
        owner : string option; [@default None]
        private_ : bool; [@default false] [@key "private"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "generate"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Full_repository.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/repos/{template_owner}/{template_repo}/generate"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("template_owner", Var (params.template_owner, String));
           ("template_repo", Var (params.template_repo, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Download_zipball_archive = struct
  module Parameters = struct
    type t = {
      owner : string;
      ref_ : string; [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "zipball" /% Path.string

  module Responses = struct
    module Found = struct end

    type t = [ `Found ] [@@deriving show, eq]

    let t = [ ("302", fun _ -> Ok `Found) ]
  end

  let url = "/repos/{owner}/{repo}/zipball/{ref}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ref", Var (params.ref_, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Disable_vulnerability_alerts = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "vulnerability-alerts"

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/vulnerability-alerts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Enable_vulnerability_alerts = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "vulnerability-alerts"

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/vulnerability-alerts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Check_vulnerability_alerts = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "vulnerability-alerts"

  module Responses = struct
    module No_content = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Not_found
      ]
    [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/repos/{owner}/{repo}/vulnerability-alerts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Transfer = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Team_ids = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        new_name : string option; [@default None]
        new_owner : string;
        team_ids : Team_ids.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "transfer"

  module Responses = struct
    module Accepted = struct
      type t = Githubc2_components.Minimal_repository.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Accepted of Accepted.t ] [@@deriving show, eq]

    let t = [ ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/transfer"

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

module Get_views = struct
  module Parameters = struct
    module Per = struct
      let t_of_yojson = function
        | `String "day" -> Ok `Day
        | `String "week" -> Ok `Week
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Day -> `String "day"
        | `Week -> `String "week"

      type t =
        ([ `Day
         | `Week
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      owner : string;
      per : Per.t; [@default `Day]
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
    / "traffic"
    / "views"
    /? option_default
         `Day
         (ud "per" (fun value -> CCResult.to_opt (Parameters.Per.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.View_traffic.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/traffic/views"

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
         [ ("per", Var (params.per, Enum Per.t_to_yojson)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_top_referrers = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "traffic" / "popular" / "referrers"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Referrer_traffic.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/traffic/popular/referrers"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_top_paths = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "traffic" / "popular" / "paths"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Content_traffic.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/traffic/popular/paths"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_clones = struct
  module Parameters = struct
    module Per = struct
      let t_of_yojson = function
        | `String "day" -> Ok `Day
        | `String "week" -> Ok `Week
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Day -> `String "day"
        | `Week -> `String "week"

      type t =
        ([ `Day
         | `Week
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      owner : string;
      per : Per.t; [@default `Day]
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
    / "traffic"
    / "clones"
    /? option_default
         `Day
         (ud "per" (fun value -> CCResult.to_opt (Parameters.Per.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Clone_traffic.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/traffic/clones"

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
         [ ("per", Var (params.per, Enum Per.t_to_yojson)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Replace_all_topics = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Names = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { names : Names.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "topics"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Topic.t
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

  let url = "/repos/{owner}/{repo}/topics"

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
      `Put
end

module Get_all_topics = struct
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
    / "topics"
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Topic.t
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

  let url = "/repos/{owner}/{repo}/topics"

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
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_teams = struct
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
    / "teams"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Team.t list
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

  let url = "/repos/{owner}/{repo}/teams"

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

module Download_tarball_archive = struct
  module Parameters = struct
    type t = {
      owner : string;
      ref_ : string; [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "tarball" /% Path.string

  module Responses = struct
    module Found = struct end

    type t = [ `Found ] [@@deriving show, eq]

    let t = [ ("302", fun _ -> Ok `Found) ]
  end

  let url = "/repos/{owner}/{repo}/tarball/{ref}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ref", Var (params.ref_, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_tags = struct
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
    / "tags"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Tag.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/tags"

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

module Create_commit_status = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      sha : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module State = struct
        let t_of_yojson = function
          | `String "error" -> Ok `Error
          | `String "failure" -> Ok `Failure
          | `String "pending" -> Ok `Pending
          | `String "success" -> Ok `Success
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Error -> `String "error"
          | `Failure -> `String "failure"
          | `Pending -> `String "pending"
          | `Success -> `String "success"

        type t =
          ([ `Error
           | `Failure
           | `Pending
           | `Success
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        context : string; [@default "default"]
        description : string option; [@default None]
        state : State.t;
        target_url : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "statuses" /% Path.string

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Status.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/statuses/{sha}"

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
           ("sha", Var (params.sha, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_punch_card_stats = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "stats" / "punch_card"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_frequency_stat.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module No_content = struct end

    type t =
      [ `OK of OK.t
      | `No_content
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("204", fun _ -> Ok `No_content);
      ]
  end

  let url = "/repos/{owner}/{repo}/stats/punch_card"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_participation_stats = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "stats" / "participation"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Participation_stats.t
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

  let url = "/repos/{owner}/{repo}/stats/participation"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_contributors_stats = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "stats" / "contributors"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Contributor_activity.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Accepted = struct
      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
    end

    module No_content = struct end

    type t =
      [ `OK of OK.t
      | `Accepted of Accepted.t
      | `No_content
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("204", fun _ -> Ok `No_content);
      ]
  end

  let url = "/repos/{owner}/{repo}/stats/contributors"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_commit_activity_stats = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "stats" / "commit_activity"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Commit_activity.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Accepted = struct
      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
    end

    module No_content = struct end

    type t =
      [ `OK of OK.t
      | `Accepted of Accepted.t
      | `No_content
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("204", fun _ -> Ok `No_content);
      ]
  end

  let url = "/repos/{owner}/{repo}/stats/commit_activity"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_code_frequency_stats = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "stats" / "code_frequency"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Code_frequency_stat.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Accepted = struct
      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
    end

    module No_content = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK of OK.t
      | `Accepted of Accepted.t
      | `No_content
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("204", fun _ -> Ok `No_content);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/repos/{owner}/{repo}/stats/code_frequency"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_repo_ruleset_version = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      ruleset_id : int;
      version_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "rulesets" /% Path.int / "history" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Ruleset_version_with_state.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/rulesets/{ruleset_id}/history/{version_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ruleset_id", Var (params.ruleset_id, Int));
           ("version_id", Var (params.version_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_repo_ruleset_history = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
      ruleset_id : int;
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
    / "rulesets"
    /% Path.int
    / "history"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Ruleset_version.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/rulesets/{ruleset_id}/history"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ruleset_id", Var (params.ruleset_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_repo_ruleset = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      ruleset_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "rulesets" /% Path.int

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/rulesets/{ruleset_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ruleset_id", Var (params.ruleset_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_repo_ruleset = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      ruleset_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Bypass_actors = struct
        type t = Githubc2_components.Repository_ruleset_bypass_actor.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Rules = struct
        type t = Githubc2_components.Repository_rule.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Target = struct
        let t_of_yojson = function
          | `String "branch" -> Ok `Branch
          | `String "push" -> Ok `Push
          | `String "tag" -> Ok `Tag
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Branch -> `String "branch"
          | `Push -> `String "push"
          | `Tag -> `String "tag"

        type t =
          ([ `Branch
           | `Push
           | `Tag
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        bypass_actors : Bypass_actors.t option; [@default None]
        conditions : Githubc2_components.Repository_ruleset_conditions.t option; [@default None]
        enforcement : Githubc2_components.Repository_rule_enforcement.t option; [@default None]
        name : string option; [@default None]
        rules : Rules.t option; [@default None]
        target : Target.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "rulesets" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_ruleset.t
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

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/rulesets/{ruleset_id}"

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
           ("ruleset_id", Var (params.ruleset_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_repo_ruleset = struct
  module Parameters = struct
    type t = {
      includes_parents : bool; [@default true]
      owner : string;
      repo : string;
      ruleset_id : int;
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
    / "rulesets"
    /% Path.int
    /? option_default true (bool "includes_parents")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_ruleset.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/rulesets/{ruleset_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ruleset_id", Var (params.ruleset_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("includes_parents", Var (params.includes_parents, Bool)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_repo_rule_suite = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      rule_suite_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "rulesets" / "rule-suites" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Rule_suite.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/rulesets/rule-suites/{rule_suite_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("rule_suite_id", Var (params.rule_suite_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_repo_rule_suites = struct
  module Parameters = struct
    module Evaluate_status = struct
      let t_of_yojson = function
        | `String "active" -> Ok `Active
        | `String "all" -> Ok `All
        | `String "evaluate" -> Ok `Evaluate
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Active -> `String "active"
        | `All -> `String "all"
        | `Evaluate -> `String "evaluate"

      type t =
        ([ `Active
         | `All
         | `Evaluate
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Rule_suite_result = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "bypass" -> Ok `Bypass
        | `String "fail" -> Ok `Fail
        | `String "pass" -> Ok `Pass
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Bypass -> `String "bypass"
        | `Fail -> `String "fail"
        | `Pass -> `String "pass"

      type t =
        ([ `All
         | `Bypass
         | `Fail
         | `Pass
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Time_period = struct
      let t_of_yojson = function
        | `String "day" -> Ok `Day
        | `String "hour" -> Ok `Hour
        | `String "month" -> Ok `Month
        | `String "week" -> Ok `Week
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Day -> `String "day"
        | `Hour -> `String "hour"
        | `Month -> `String "month"
        | `Week -> `String "week"

      type t =
        ([ `Day
         | `Hour
         | `Month
         | `Week
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      actor_name : string option; [@default None]
      evaluate_status : Evaluate_status.t; [@default `All]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      ref_ : string option; [@default None] [@key "ref"]
      repo : string;
      rule_suite_result : Rule_suite_result.t; [@default `All]
      time_period : Time_period.t; [@default `Day]
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
    / "rulesets"
    / "rule-suites"
    /? option (string "ref")
    /? option_default
         `Day
         (ud "time_period" (fun value ->
              CCResult.to_opt (Parameters.Time_period.t_of_yojson (`String value))))
    /? option (string "actor_name")
    /? option_default
         `All
         (ud "rule_suite_result" (fun value ->
              CCResult.to_opt (Parameters.Rule_suite_result.t_of_yojson (`String value))))
    /? option_default
         `All
         (ud "evaluate_status" (fun value ->
              CCResult.to_opt (Parameters.Evaluate_status.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Rule_suites.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/rulesets/rule-suites"

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
           ("ref", Var (params.ref_, Option String));
           ("time_period", Var (params.time_period, Enum Time_period.t_to_yojson));
           ("actor_name", Var (params.actor_name, Option String));
           ("rule_suite_result", Var (params.rule_suite_result, Enum Rule_suite_result.t_to_yojson));
           ("evaluate_status", Var (params.evaluate_status, Enum Evaluate_status.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_repo_ruleset = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Bypass_actors = struct
        type t = Githubc2_components.Repository_ruleset_bypass_actor.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Rules = struct
        type t = Githubc2_components.Repository_rule.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Target = struct
        let t_of_yojson = function
          | `String "branch" -> Ok `Branch
          | `String "push" -> Ok `Push
          | `String "tag" -> Ok `Tag
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Branch -> `String "branch"
          | `Push -> `String "push"
          | `Tag -> `String "tag"

        type t =
          ([ `Branch
           | `Push
           | `Tag
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        bypass_actors : Bypass_actors.t option; [@default None]
        conditions : Githubc2_components.Repository_ruleset_conditions.t option; [@default None]
        enforcement : Githubc2_components.Repository_rule_enforcement.t;
        name : string;
        rules : Rules.t option; [@default None]
        target : Target.t; [@default `Branch]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "rulesets"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Repository_ruleset.t
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

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/rulesets"

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

module Get_repo_rulesets = struct
  module Parameters = struct
    type t = {
      includes_parents : bool; [@default true]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
      targets : string option; [@default None]
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
    / "rulesets"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option_default true (bool "includes_parents")
    /? option (string "targets")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_ruleset.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/rulesets"

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
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("includes_parents", Var (params.includes_parents, Bool));
           ("targets", Var (params.targets, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_branch_rules = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "rules"
    / "branches"
    /% Path.string
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_rule_detailed.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/rules/branches/{branch}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Upload_release_asset = struct
  module Parameters = struct
    type t = {
      label : string option; [@default None]
      name : string;
      owner : string;
      release_id : int;
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
    / "releases"
    /% Path.int
    / "assets"
    /? string "name"
    /? option (string "label")

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Release_asset.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct end

    type t =
      [ `Created of Created.t
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/repos/{owner}/{repo}/releases/{release_id}/assets"

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
         [ ("name", Var (params.name, String)); ("label", Var (params.label, Option String)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module List_release_assets = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      release_id : int;
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
    / "releases"
    /% Path.int
    / "assets"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Release_asset.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/releases/{release_id}/assets"

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
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_release = struct
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
      module Make_latest = struct
        let t_of_yojson = function
          | `String "false" -> Ok `False
          | `String "legacy" -> Ok `Legacy
          | `String "true" -> Ok `True
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `False -> `String "false"
          | `Legacy -> `String "legacy"
          | `True -> `String "true"

        type t =
          ([ `False
           | `Legacy
           | `True
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        body : string option; [@default None]
        discussion_category_name : string option; [@default None]
        draft : bool option; [@default None]
        make_latest : Make_latest.t; [@default `True]
        name : string option; [@default None]
        prerelease : bool option; [@default None]
        tag_name : string option; [@default None]
        target_commitish : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Release.t
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

  let url = "/repos/{owner}/{repo}/releases/{release_id}"

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
           ("release_id", Var (params.release_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_release = struct
  module Parameters = struct
    type t = {
      owner : string;
      release_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases" /% Path.int

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

  let url = "/repos/{owner}/{repo}/releases/{release_id}"

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
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_release = struct
  module Parameters = struct
    type t = {
      owner : string;
      release_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Release.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/repos/{owner}/{repo}/releases/{release_id}"

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
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_release_by_tag = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      tag : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases" / "tags" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Release.t
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

  let url = "/repos/{owner}/{repo}/releases/tags/{tag}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("tag", Var (params.tag, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_latest_release = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases" / "latest"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Release.t
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

  let url = "/repos/{owner}/{repo}/releases/latest"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Generate_release_notes = struct
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
        configuration_file_path : string option; [@default None]
        previous_tag_name : string option; [@default None]
        tag_name : string;
        target_commitish : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases" / "generate-notes"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Release_notes_content.t
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

  let url = "/repos/{owner}/{repo}/releases/generate-notes"

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

module Update_release_asset = struct
  module Parameters = struct
    type t = {
      asset_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        label : string option; [@default None]
        name : string option; [@default None]
        state : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases" / "assets" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Release_asset.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/releases/assets/{asset_id}"

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
           ("asset_id", Var (params.asset_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_release_asset = struct
  module Parameters = struct
    type t = {
      asset_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases" / "assets" /% Path.int

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

  let url = "/repos/{owner}/{repo}/releases/assets/{asset_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("asset_id", Var (params.asset_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_release_asset = struct
  module Parameters = struct
    type t = {
      asset_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases" / "assets" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Release_asset.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Found = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Found
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("302", fun _ -> Ok `Found);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/releases/assets/{asset_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("asset_id", Var (params.asset_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_release = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Make_latest = struct
        let t_of_yojson = function
          | `String "false" -> Ok `False
          | `String "legacy" -> Ok `Legacy
          | `String "true" -> Ok `True
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `False -> `String "false"
          | `Legacy -> `String "legacy"
          | `True -> `String "true"

        type t =
          ([ `False
           | `Legacy
           | `True
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        body : string option; [@default None]
        discussion_category_name : string option; [@default None]
        draft : bool; [@default false]
        generate_release_notes : bool; [@default false]
        make_latest : Make_latest.t; [@default `True]
        name : string option; [@default None]
        prerelease : bool; [@default false]
        tag_name : string;
        target_commitish : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "releases"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Release.t
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

  let url = "/repos/{owner}/{repo}/releases"

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

module List_releases = struct
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
    / "releases"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Release.t list
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

  let url = "/repos/{owner}/{repo}/releases"

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

module Get_readme_in_directory = struct
  module Parameters = struct
    type t = {
      dir : string;
      owner : string;
      ref_ : string option; [@default None] [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "readme" /% Path.string /? option (string "ref")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Content_file.t
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

  let url = "/repos/{owner}/{repo}/readme/{dir}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("dir", Var (params.dir, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("ref", Var (params.ref_, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_readme = struct
  module Parameters = struct
    type t = {
      owner : string;
      ref_ : string option; [@default None] [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "readme" /? option (string "ref")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Content_file.t
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

  let url = "/repos/{owner}/{repo}/readme"

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
         [ ("ref", Var (params.ref_, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Custom_properties_for_repos_create_or_update_repository_values = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Properties = struct
        type t = Githubc2_components.Custom_property_value.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { properties : Properties.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "properties" / "values"

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

    type t =
      [ `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/properties/values"

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
      `Patch
end

module Custom_properties_for_repos_get_repository_values = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "properties" / "values"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Custom_property_value.t list
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/properties/values"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Disable_private_vulnerability_reporting = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "private-vulnerability-reporting"

  module Responses = struct
    module No_content = struct end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/private-vulnerability-reporting"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Enable_private_vulnerability_reporting = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "private-vulnerability-reporting"

  module Responses = struct
    module No_content = struct end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/private-vulnerability-reporting"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Check_private_vulnerability_reporting = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "private-vulnerability-reporting"

  module Responses = struct
    module OK = struct
      module Primary = struct
        type t = { enabled : bool } [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Basic_error.t
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

  let url = "/repos/{owner}/{repo}/private-vulnerability-reporting"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_pages_health_check = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "pages" / "health"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Pages_health_check.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Accepted = struct
      type t = Githubc2_components.Empty_object.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct end

    type t =
      [ `OK of OK.t
      | `Accepted of Accepted.t
      | `Bad_request
      | `Not_found of Not_found.t
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/repos/{owner}/{repo}/pages/health"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Cancel_pages_deployment = struct
  module Parameters = struct
    module Pages_deployment_id = struct
      module V0 = struct
        type t = int [@@deriving show, eq]
      end

      module V1 = struct
        type t = string [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    type t = {
      owner : string;
      pages_deployment_id : Pages_deployment_id.t;
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
    / "pages"
    / "deployments"
    /% Path.ud (fun value ->
        CCOption.choice
          [
            CCOption.map (fun v -> Parameters.Pages_deployment_id.V0 v) (CCInt.of_string value);
            CCOption.map (fun v -> Parameters.Pages_deployment_id.V1 v) (CCOption.return value);
          ])
    / "cancel"

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

  let url = "/repos/{owner}/{repo}/pages/deployments/{pages_deployment_id}/cancel"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ( "pages_deployment_id",
             match params.pages_deployment_id with
             | Pages_deployment_id.V0 v -> Var (v, Int)
             | Pages_deployment_id.V1 v -> Var (v, String) );
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_pages_deployment = struct
  module Parameters = struct
    module Pages_deployment_id = struct
      module V0 = struct
        type t = int [@@deriving show, eq]
      end

      module V1 = struct
        type t = string [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    type t = {
      owner : string;
      pages_deployment_id : Pages_deployment_id.t;
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
    / "pages"
    / "deployments"
    /% Path.ud (fun value ->
        CCOption.choice
          [
            CCOption.map (fun v -> Parameters.Pages_deployment_id.V0 v) (CCInt.of_string value);
            CCOption.map (fun v -> Parameters.Pages_deployment_id.V1 v) (CCOption.return value);
          ])

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Pages_deployment_status.t
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

  let url = "/repos/{owner}/{repo}/pages/deployments/{pages_deployment_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ( "pages_deployment_id",
             match params.pages_deployment_id with
             | Pages_deployment_id.V0 v -> Var (v, Int)
             | Pages_deployment_id.V1 v -> Var (v, String) );
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_pages_deployment = struct
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
        artifact_id : float option; [@default None]
        artifact_url : string option; [@default None]
        environment : string; [@default "github-pages"]
        oidc_token : string;
        pages_build_version : string; [@default "GITHUB_SHA"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "pages" / "deployments"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Page_deployment.t
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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/pages/deployments"

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

module Get_pages_build = struct
  module Parameters = struct
    type t = {
      build_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "pages" / "builds" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Page_build.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/pages/builds/{build_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("build_id", Var (params.build_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_latest_pages_build = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "pages" / "builds" / "latest"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Page_build.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/pages/builds/latest"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Request_pages_build = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "pages" / "builds"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Page_build_status.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/pages/builds"

  let make params =
    Openapi.Request.make
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

module List_pages_builds = struct
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
    / "pages"
    / "builds"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Page_build.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/pages/builds"

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

module Delete_pages_site = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "pages"

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/pages"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_pages_site = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Build_type = struct
          let t_of_yojson = function
            | `String "legacy" -> Ok `Legacy
            | `String "workflow" -> Ok `Workflow
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Legacy -> `String "legacy"
            | `Workflow -> `String "workflow"

          type t =
            ([ `Legacy
             | `Workflow
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Source = struct
          module Primary = struct
            module Path = struct
              let t_of_yojson = function
                | `String "/" -> Ok `V__
                | `String "/docs" -> Ok `_docs
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `V__ -> `String "/"
                | `_docs -> `String "/docs"

              type t =
                ([ `V__
                 | `_docs
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              branch : string;
              path : Path.t; [@default `V__]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = {
          build_type : Build_type.t option; [@default None]
          source : Source.t;
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      module Primary = struct
        module Build_type = struct
          let t_of_yojson = function
            | `String "legacy" -> Ok `Legacy
            | `String "workflow" -> Ok `Workflow
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Legacy -> `String "legacy"
            | `Workflow -> `String "workflow"

          type t =
            ([ `Legacy
             | `Workflow
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Source = struct
          module Primary = struct
            module Path = struct
              let t_of_yojson = function
                | `String "/" -> Ok `V__
                | `String "/docs" -> Ok `_docs
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `V__ -> `String "/"
                | `_docs -> `String "/docs"

              type t =
                ([ `V__
                 | `_docs
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              branch : string;
              path : Path.t; [@default `V__]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = {
          build_type : Build_type.t;
          source : Source.t option; [@default None]
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
      Json_schema.any_of
        (let open CCResult in
         [
           (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
           (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
         ])

    let to_yojson = function
      | V0 v -> V0.to_yojson v
      | V1 v -> V1.to_yojson v
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "pages"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Page.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/pages"

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

module Update_information_about_pages_site = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Build_type = struct
          let t_of_yojson = function
            | `String "legacy" -> Ok `Legacy
            | `String "workflow" -> Ok `Workflow
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Legacy -> `String "legacy"
            | `Workflow -> `String "workflow"

          type t =
            ([ `Legacy
             | `Workflow
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Source = struct
          module V0 = struct
            let t_of_yojson = function
              | `String "gh-pages" -> Ok `Gh_pages
              | `String "master" -> Ok `Master
              | `String "master /docs" -> Ok `Master__docs
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Gh_pages -> `String "gh-pages"
              | `Master -> `String "master"
              | `Master__docs -> `String "master /docs"

            type t =
              ([ `Gh_pages
               | `Master
               | `Master__docs
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            module Primary = struct
              module Path = struct
                let t_of_yojson = function
                  | `String "/" -> Ok `V__
                  | `String "/docs" -> Ok `_docs
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `V__ -> `String "/"
                  | `_docs -> `String "/docs"

                type t =
                  ([ `V__
                   | `_docs
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                branch : string;
                path : Path.t;
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
            Json_schema.any_of
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
          build_type : Build_type.t;
          cname : string option; [@default None]
          https_enforced : bool option; [@default None]
          source : Source.t option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      module Primary = struct
        module Build_type = struct
          let t_of_yojson = function
            | `String "legacy" -> Ok `Legacy
            | `String "workflow" -> Ok `Workflow
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Legacy -> `String "legacy"
            | `Workflow -> `String "workflow"

          type t =
            ([ `Legacy
             | `Workflow
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Source = struct
          module V0 = struct
            let t_of_yojson = function
              | `String "gh-pages" -> Ok `Gh_pages
              | `String "master" -> Ok `Master
              | `String "master /docs" -> Ok `Master__docs
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Gh_pages -> `String "gh-pages"
              | `Master -> `String "master"
              | `Master__docs -> `String "master /docs"

            type t =
              ([ `Gh_pages
               | `Master
               | `Master__docs
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            module Primary = struct
              module Path = struct
                let t_of_yojson = function
                  | `String "/" -> Ok `V__
                  | `String "/docs" -> Ok `_docs
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `V__ -> `String "/"
                  | `_docs -> `String "/docs"

                type t =
                  ([ `V__
                   | `_docs
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                branch : string;
                path : Path.t;
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
            Json_schema.any_of
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
          build_type : Build_type.t option; [@default None]
          cname : string option; [@default None]
          https_enforced : bool option; [@default None]
          source : Source.t;
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V2 = struct
      module Primary = struct
        module Build_type = struct
          let t_of_yojson = function
            | `String "legacy" -> Ok `Legacy
            | `String "workflow" -> Ok `Workflow
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Legacy -> `String "legacy"
            | `Workflow -> `String "workflow"

          type t =
            ([ `Legacy
             | `Workflow
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Source = struct
          module V0 = struct
            let t_of_yojson = function
              | `String "gh-pages" -> Ok `Gh_pages
              | `String "master" -> Ok `Master
              | `String "master /docs" -> Ok `Master__docs
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Gh_pages -> `String "gh-pages"
              | `Master -> `String "master"
              | `Master__docs -> `String "master /docs"

            type t =
              ([ `Gh_pages
               | `Master
               | `Master__docs
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            module Primary = struct
              module Path = struct
                let t_of_yojson = function
                  | `String "/" -> Ok `V__
                  | `String "/docs" -> Ok `_docs
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `V__ -> `String "/"
                  | `_docs -> `String "/docs"

                type t =
                  ([ `V__
                   | `_docs
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                branch : string;
                path : Path.t;
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
            Json_schema.any_of
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
          build_type : Build_type.t option; [@default None]
          cname : string option; [@default None]
          https_enforced : bool option; [@default None]
          source : Source.t option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V3 = struct
      module Primary = struct
        module Build_type = struct
          let t_of_yojson = function
            | `String "legacy" -> Ok `Legacy
            | `String "workflow" -> Ok `Workflow
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Legacy -> `String "legacy"
            | `Workflow -> `String "workflow"

          type t =
            ([ `Legacy
             | `Workflow
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Source = struct
          module V0 = struct
            let t_of_yojson = function
              | `String "gh-pages" -> Ok `Gh_pages
              | `String "master" -> Ok `Master
              | `String "master /docs" -> Ok `Master__docs
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Gh_pages -> `String "gh-pages"
              | `Master -> `String "master"
              | `Master__docs -> `String "master /docs"

            type t =
              ([ `Gh_pages
               | `Master
               | `Master__docs
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            module Primary = struct
              module Path = struct
                let t_of_yojson = function
                  | `String "/" -> Ok `V__
                  | `String "/docs" -> Ok `_docs
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `V__ -> `String "/"
                  | `_docs -> `String "/docs"

                type t =
                  ([ `V__
                   | `_docs
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                branch : string;
                path : Path.t;
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
            Json_schema.any_of
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
          build_type : Build_type.t option; [@default None]
          cname : string option; [@default None]
          https_enforced : bool option; [@default None]
          source : Source.t option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V4 = struct
      module Primary = struct
        module Build_type = struct
          let t_of_yojson = function
            | `String "legacy" -> Ok `Legacy
            | `String "workflow" -> Ok `Workflow
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Legacy -> `String "legacy"
            | `Workflow -> `String "workflow"

          type t =
            ([ `Legacy
             | `Workflow
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Source = struct
          module V0 = struct
            let t_of_yojson = function
              | `String "gh-pages" -> Ok `Gh_pages
              | `String "master" -> Ok `Master
              | `String "master /docs" -> Ok `Master__docs
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Gh_pages -> `String "gh-pages"
              | `Master -> `String "master"
              | `Master__docs -> `String "master /docs"

            type t =
              ([ `Gh_pages
               | `Master
               | `Master__docs
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            module Primary = struct
              module Path = struct
                let t_of_yojson = function
                  | `String "/" -> Ok `V__
                  | `String "/docs" -> Ok `_docs
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `V__ -> `String "/"
                  | `_docs -> `String "/docs"

                type t =
                  ([ `V__
                   | `_docs
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                branch : string;
                path : Path.t;
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
            Json_schema.any_of
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
          build_type : Build_type.t option; [@default None]
          cname : string option; [@default None]
          https_enforced : bool;
          source : Source.t option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      | V0 of V0.t
      | V1 of V1.t
      | V2 of V2.t
      | V3 of V3.t
      | V4 of V4.t
    [@@deriving show, eq]

    let of_yojson =
      Json_schema.any_of
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
    rel / "repos" /% Path.string /% Path.string / "pages"

  module Responses = struct
    module No_content = struct end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Bad_request of Bad_request.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/pages"

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
      `Put
end

module Get_pages = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "pages"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Page.t
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

  let url = "/repos/{owner}/{repo}/pages"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Merge = struct
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
        base : string;
        commit_message : string option; [@default None]
        head : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "merges"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Commit.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module No_content = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end
    module Conflict = struct end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `No_content
      | `Forbidden of Forbidden.t
      | `Not_found
      | `Conflict
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("409", fun _ -> Ok `Conflict);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/merges"

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

module Merge_upstream = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { branch : string }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "merge-upstream"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Merged_upstream.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK of OK.t
      | `Conflict
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("409", fun _ -> Ok `Conflict);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/repos/{owner}/{repo}/merge-upstream"

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

module List_languages = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "languages"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Language.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/languages"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_deploy_key = struct
  module Parameters = struct
    type t = {
      key_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "keys" /% Path.int

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/keys/{key_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("key_id", Var (params.key_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_deploy_key = struct
  module Parameters = struct
    type t = {
      key_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "keys" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deploy_key.t
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

  let url = "/repos/{owner}/{repo}/keys/{key_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("key_id", Var (params.key_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_deploy_key = struct
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
        key : string;
        read_only : bool option; [@default None]
        title : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "keys"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Deploy_key.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/keys"

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

module List_deploy_keys = struct
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
    / "keys"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deploy_key.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/keys"

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

module List_issue_types = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "issue-types"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Issue_type.t list
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

  let url = "/repos/{owner}/{repo}/issue-types"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Update_invitation = struct
  module Parameters = struct
    type t = {
      invitation_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Permissions = struct
        let t_of_yojson = function
          | `String "admin" -> Ok `Admin
          | `String "maintain" -> Ok `Maintain
          | `String "read" -> Ok `Read
          | `String "triage" -> Ok `Triage
          | `String "write" -> Ok `Write
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Admin -> `String "admin"
          | `Maintain -> `String "maintain"
          | `Read -> `String "read"
          | `Triage -> `String "triage"
          | `Write -> `String "write"

        type t =
          ([ `Admin
           | `Maintain
           | `Read
           | `Triage
           | `Write
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { permissions : Permissions.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "invitations" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_invitation.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/invitations/{invitation_id}"

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
           ("invitation_id", Var (params.invitation_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_invitation = struct
  module Parameters = struct
    type t = {
      invitation_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "invitations" /% Path.int

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/invitations/{invitation_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("invitation_id", Var (params.invitation_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module List_invitations = struct
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
    / "invitations"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_invitation.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/invitations"

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

module Disable_immutable_releases = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "immutable-releases"

  module Responses = struct
    module No_content = struct end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/immutable-releases"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Enable_immutable_releases = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "immutable-releases"

  module Responses = struct
    module No_content = struct end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/immutable-releases"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Check_immutable_releases = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "immutable-releases"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Check_immutable_releases.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/repos/{owner}/{repo}/immutable-releases"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Test_push_webhook = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hooks" /% Path.int / "tests"

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

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}/tests"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("hook_id", Var (params.hook_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Ping_webhook = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hooks" /% Path.int / "pings"

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

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}/pings"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("hook_id", Var (params.hook_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Redeliver_webhook_delivery = struct
  module Parameters = struct
    type t = {
      delivery_id : int;
      hook_id : int;
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
    / "hooks"
    /% Path.int
    / "deliveries"
    /% Path.int
    / "attempts"

  module Responses = struct
    module Accepted = struct
      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Accepted of Accepted.t
      | `Bad_request of Bad_request.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}/deliveries/{delivery_id}/attempts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("hook_id", Var (params.hook_id, Int));
           ("delivery_id", Var (params.delivery_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_webhook_delivery = struct
  module Parameters = struct
    type t = {
      delivery_id : int;
      hook_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hooks" /% Path.int / "deliveries" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Hook_delivery.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}/deliveries/{delivery_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("hook_id", Var (params.hook_id, Int));
           ("delivery_id", Var (params.delivery_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_webhook_deliveries = struct
  module Parameters = struct
    module Status = struct
      let t_of_yojson = function
        | `String "failure" -> Ok `Failure
        | `String "success" -> Ok `Success
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Failure -> `String "failure"
        | `Success -> `String "success"

      type t =
        ([ `Failure
         | `Success
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      cursor : string option; [@default None]
      hook_id : int;
      owner : string;
      per_page : int; [@default 30]
      repo : string;
      status : Status.t option; [@default None]
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
    / "hooks"
    /% Path.int
    / "deliveries"
    /? option_default 30 (int "per_page")
    /? option (string "cursor")
    /? option
         (ud "status" (fun value -> CCResult.to_opt (Parameters.Status.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Hook_delivery_item.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}/deliveries"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("hook_id", Var (params.hook_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("cursor", Var (params.cursor, Option String));
           ("status", Var (params.status, Option (Enum Status.t_to_yojson)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_webhook_config_for_repo = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = {
      content_type : string option; [@default None]
      insecure_ssl : Githubc2_components.Webhook_config_insecure_ssl.t option; [@default None]
      secret : string option; [@default None]
      url : string option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hooks" /% Path.int / "config"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Webhook_config.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}/config"

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
           ("hook_id", Var (params.hook_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Get_webhook_config_for_repo = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hooks" /% Path.int / "config"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Webhook_config.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}/config"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("hook_id", Var (params.hook_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Update_webhook = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Add_events = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Events = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Remove_events = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        active : bool; [@default true]
        add_events : Add_events.t option; [@default None]
        config : Githubc2_components.Webhook_config.t option; [@default None]
        events : Events.t; [@default [ "push" ]]
        remove_events : Remove_events.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hooks" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Hook.t
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

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}"

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
           ("hook_id", Var (params.hook_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_webhook = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hooks" /% Path.int

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

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("hook_id", Var (params.hook_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_webhook = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hooks" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Hook.t
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

  let url = "/repos/{owner}/{repo}/hooks/{hook_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("hook_id", Var (params.hook_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_webhook = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Config = struct
      module Primary = struct
        type t = {
          content_type : string option; [@default None]
          insecure_ssl : Githubc2_components.Webhook_config_insecure_ssl.t option; [@default None]
          secret : string option; [@default None]
          url : string option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Events = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      active : bool; [@default true]
      config : Config.t option; [@default None]
      events : Events.t; [@default [ "push" ]]
      name : string option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hooks"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Hook.t
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
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/hooks"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
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

module List_webhooks = struct
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
    / "hooks"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Hook.t list
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

  let url = "/repos/{owner}/{repo}/hooks"

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

module Get_hash_algorithm = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "hash-algorithm"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_hash_algorithm.t
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/hash-algorithm"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_fork = struct
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
        default_branch_only : bool option; [@default None]
        name : string option; [@default None]
        organization : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "forks"

  module Responses = struct
    module Accepted = struct
      type t = Githubc2_components.Full_repository.t
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

    type t =
      [ `Accepted of Accepted.t
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/forks"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
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

module List_forks = struct
  module Parameters = struct
    module Sort = struct
      let t_of_yojson = function
        | `String "newest" -> Ok `Newest
        | `String "oldest" -> Ok `Oldest
        | `String "stargazers" -> Ok `Stargazers
        | `String "watchers" -> Ok `Watchers
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Newest -> `String "newest"
        | `Oldest -> `String "oldest"
        | `Stargazers -> `String "stargazers"
        | `Watchers -> `String "watchers"

      type t =
        ([ `Newest
         | `Oldest
         | `Stargazers
         | `Watchers
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
      sort : Sort.t; [@default `Newest]
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
    / "forks"
    /? option_default
         `Newest
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Minimal_repository.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/forks"

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
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Disable_deployment_protection_rule = struct
  module Parameters = struct
    type t = {
      environment_name : string;
      owner : string;
      protection_rule_id : int;
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
    / "environments"
    /% Path.string
    / "deployment_protection_rules"
    /% Path.int

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url =
    "/repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules/{protection_rule_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("environment_name", Var (params.environment_name, String));
           ("repo", Var (params.repo, String));
           ("owner", Var (params.owner, String));
           ("protection_rule_id", Var (params.protection_rule_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_custom_deployment_protection_rule = struct
  module Parameters = struct
    type t = {
      environment_name : string;
      owner : string;
      protection_rule_id : int;
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
    / "environments"
    /% Path.string
    / "deployment_protection_rules"
    /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deployment_protection_rule.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url =
    "/repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules/{protection_rule_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("environment_name", Var (params.environment_name, String));
           ("protection_rule_id", Var (params.protection_rule_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_custom_deployment_rule_integrations = struct
  module Parameters = struct
    type t = {
      environment_name : string;
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
    / "environments"
    /% Path.string
    / "deployment_protection_rules"
    / "apps"
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Available_custom_deployment_protection_rule_integrations = struct
          type t = Githubc2_components.Custom_deployment_rule_app.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          available_custom_deployment_protection_rule_integrations :
            Available_custom_deployment_protection_rule_integrations.t option;
              [@default None]
          total_count : int option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules/apps"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("environment_name", Var (params.environment_name, String));
           ("repo", Var (params.repo, String));
           ("owner", Var (params.owner, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_deployment_protection_rule = struct
  module Parameters = struct
    type t = {
      environment_name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { integration_id : int option [@default None] }
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
    / "environments"
    /% Path.string
    / "deployment_protection_rules"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Deployment_protection_rule.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("environment_name", Var (params.environment_name, String));
           ("repo", Var (params.repo, String));
           ("owner", Var (params.owner, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_all_deployment_protection_rules = struct
  module Parameters = struct
    type t = {
      environment_name : string;
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
    / "environments"
    /% Path.string
    / "deployment_protection_rules"

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Custom_deployment_protection_rules = struct
          type t = Githubc2_components.Deployment_protection_rule.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          custom_deployment_protection_rules : Custom_deployment_protection_rules.t option;
              [@default None]
          total_count : int option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("environment_name", Var (params.environment_name, String));
           ("repo", Var (params.repo, String));
           ("owner", Var (params.owner, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_deployment_branch_policy = struct
  module Parameters = struct
    type t = {
      branch_policy_id : int;
      environment_name : string;
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
    / "environments"
    /% Path.string
    / "deployment-branch-policies"
    /% Path.int

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url =
    "/repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies/{branch_policy_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("environment_name", Var (params.environment_name, String));
           ("branch_policy_id", Var (params.branch_policy_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_deployment_branch_policy = struct
  module Parameters = struct
    type t = {
      branch_policy_id : int;
      environment_name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Githubc2_components.Deployment_branch_policy_name_pattern.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "environments"
    /% Path.string
    / "deployment-branch-policies"
    /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deployment_branch_policy.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url =
    "/repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies/{branch_policy_id}"

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
           ("environment_name", Var (params.environment_name, String));
           ("branch_policy_id", Var (params.branch_policy_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_deployment_branch_policy = struct
  module Parameters = struct
    type t = {
      branch_policy_id : int;
      environment_name : string;
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
    / "environments"
    /% Path.string
    / "deployment-branch-policies"
    /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deployment_branch_policy.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url =
    "/repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies/{branch_policy_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("environment_name", Var (params.environment_name, String));
           ("branch_policy_id", Var (params.branch_policy_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_deployment_branch_policy = struct
  module Parameters = struct
    type t = {
      environment_name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Githubc2_components.Deployment_branch_policy_name_pattern_with_type.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "environments"
    /% Path.string
    / "deployment-branch-policies"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deployment_branch_policy.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module See_other = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `See_other
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("303", fun _ -> Ok `See_other);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies"

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
           ("environment_name", Var (params.environment_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_deployment_branch_policies = struct
  module Parameters = struct
    type t = {
      environment_name : string;
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
    / "environments"
    /% Path.string
    / "deployment-branch-policies"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Branch_policies = struct
          type t = Githubc2_components.Deployment_branch_policy.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          branch_policies : Branch_policies.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("environment_name", Var (params.environment_name, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_an_environment = struct
  module Parameters = struct
    type t = {
      environment_name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "environments" /% Path.string

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/environments/{environment_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("environment_name", Var (params.environment_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_or_update_environment = struct
  module Parameters = struct
    type t = {
      environment_name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Reviewers = struct
      module Items = struct
        module Primary = struct
          type t = {
            id : int option; [@default None]
            type_ : Githubc2_components.Deployment_reviewer_type.t option;
                [@default None] [@key "type"]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      deployment_branch_policy : Githubc2_components.Deployment_branch_policy_settings.t option;
          [@default None]
      prevent_self_review : bool option; [@default None]
      reviewers : Reviewers.t option; [@default None]
      wait_timer : int option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "environments" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Environment.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Basic_error.t
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

  let url = "/repos/{owner}/{repo}/environments/{environment_name}"

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
           ("environment_name", Var (params.environment_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_environment = struct
  module Parameters = struct
    type t = {
      environment_name : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "environments" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Environment.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/environments/{environment_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("environment_name", Var (params.environment_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_all_environments = struct
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
    / "environments"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Environments = struct
          type t = Githubc2_components.Environment.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          environments : Environments.t option; [@default None]
          total_count : int option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/environments"

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

module Create_dispatch_event = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Client_payload = struct
        include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
      end

      type t = {
        client_payload : Client_payload.t option; [@default None]
        event_type : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "dispatches"

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/dispatches"

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

module Get_deployment_status = struct
  module Parameters = struct
    type t = {
      deployment_id : int;
      owner : string;
      repo : string;
      status_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "deployments" /% Path.int / "statuses" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deployment_status.t
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

  let url = "/repos/{owner}/{repo}/deployments/{deployment_id}/statuses/{status_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("deployment_id", Var (params.deployment_id, Int));
           ("status_id", Var (params.status_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_deployment_status = struct
  module Parameters = struct
    type t = {
      deployment_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module State = struct
        let t_of_yojson = function
          | `String "error" -> Ok `Error
          | `String "failure" -> Ok `Failure
          | `String "in_progress" -> Ok `In_progress
          | `String "inactive" -> Ok `Inactive
          | `String "pending" -> Ok `Pending
          | `String "queued" -> Ok `Queued
          | `String "success" -> Ok `Success
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Error -> `String "error"
          | `Failure -> `String "failure"
          | `In_progress -> `String "in_progress"
          | `Inactive -> `String "inactive"
          | `Pending -> `String "pending"
          | `Queued -> `String "queued"
          | `Success -> `String "success"

        type t =
          ([ `Error
           | `Failure
           | `In_progress
           | `Inactive
           | `Pending
           | `Queued
           | `Success
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        auto_inactive : bool option; [@default None]
        description : string; [@default ""]
        environment : string option; [@default None]
        environment_url : string; [@default ""]
        log_url : string; [@default ""]
        state : State.t;
        target_url : string; [@default ""]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "deployments" /% Path.int / "statuses"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Deployment_status.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/deployments/{deployment_id}/statuses"

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
           ("deployment_id", Var (params.deployment_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_deployment_statuses = struct
  module Parameters = struct
    type t = {
      deployment_id : int;
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
    / "deployments"
    /% Path.int
    / "statuses"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deployment_status.t list
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

  let url = "/repos/{owner}/{repo}/deployments/{deployment_id}/statuses"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("deployment_id", Var (params.deployment_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_deployment = struct
  module Parameters = struct
    type t = {
      deployment_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "deployments" /% Path.int

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error_simple.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/deployments/{deployment_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("deployment_id", Var (params.deployment_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_deployment = struct
  module Parameters = struct
    type t = {
      deployment_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "deployments" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deployment.t
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

  let url = "/repos/{owner}/{repo}/deployments/{deployment_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("deployment_id", Var (params.deployment_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_deployment = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Payload = struct
        module V0 = struct
          include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
        end

        module V1 = struct
          type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
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

      module Required_contexts = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        auto_merge : bool; [@default true]
        description : string option; [@default Some ""]
        environment : string; [@default "production"]
        payload : Payload.t option; [@default None]
        production_environment : bool option; [@default None]
        ref_ : string; [@key "ref"]
        required_contexts : Required_contexts.t option; [@default None]
        task : string; [@default "deploy"]
        transient_environment : bool; [@default false]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "deployments"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Deployment.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Accepted = struct
      module Primary = struct
        type t = { message : string option [@default None] }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Conflict = struct end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Accepted of Accepted.t
      | `Conflict
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("409", fun _ -> Ok `Conflict);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/deployments"

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

module List_deployments = struct
  module Parameters = struct
    type t = {
      environment : string option; [@default Some "none"]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      ref_ : string; [@default "none"] [@key "ref"]
      repo : string;
      sha : string; [@default "none"]
      task : string; [@default "none"]
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
    / "deployments"
    /? option_default "none" (string "sha")
    /? option_default "none" (string "ref")
    /? option_default "none" (string "task")
    /? option_default (Some "none") (option (string "environment"))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Deployment.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/deployments"

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
           ("sha", Var (params.sha, String));
           ("ref", Var (params.ref_, String));
           ("task", Var (params.task, String));
           ("environment", Var (params.environment, Option String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_contributors = struct
  module Parameters = struct
    type t = {
      anon : string option; [@default None]
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
    / "contributors"
    /? option (string "anon")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Contributor.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

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
      [ `OK of OK.t
      | `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/contributors"

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
           ("anon", Var (params.anon, Option String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_file = struct
  module Parameters = struct
    type t = {
      owner : string;
      path : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Author = struct
        module Primary = struct
          type t = {
            email : string option; [@default None]
            name : string option; [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Committer = struct
        module Primary = struct
          type t = {
            email : string option; [@default None]
            name : string option; [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = {
        author : Author.t option; [@default None]
        branch : string option; [@default None]
        committer : Committer.t option; [@default None]
        message : string;
        sha : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "contents" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.File_commit.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
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
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/contents/{path}"

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
           ("path", Var (params.path, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_or_update_file_contents = struct
  module Parameters = struct
    type t = {
      owner : string;
      path : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Author = struct
        module Primary = struct
          type t = {
            date : string option; [@default None]
            email : string;
            name : string;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Committer = struct
        module Primary = struct
          type t = {
            date : string option; [@default None]
            email : string;
            name : string;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = {
        author : Author.t option; [@default None]
        branch : string option; [@default None]
        committer : Committer.t option; [@default None]
        content : string;
        message : string;
        sha : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "contents" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.File_commit.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Githubc2_components.File_commit.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t =
        | Basic_error of Githubc2_components.Basic_error.t
        | Repository_rule_violation_error of Githubc2_components.Repository_rule_violation_error.t
      [@@deriving show, eq]

      let of_yojson =
        Json_schema.one_of
          (let open CCResult in
           [
             (fun v -> map (fun v -> Basic_error v) (Githubc2_components.Basic_error.of_yojson v));
             (fun v ->
               map
                 (fun v -> Repository_rule_violation_error v)
                 (Githubc2_components.Repository_rule_violation_error.of_yojson v));
           ])

      let to_yojson = function
        | Basic_error v -> Githubc2_components.Basic_error.to_yojson v
        | Repository_rule_violation_error v ->
            Githubc2_components.Repository_rule_violation_error.to_yojson v
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Created of Created.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/contents/{path}"

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
           ("path", Var (params.path, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_content = struct
  module Parameters = struct
    type t = {
      owner : string;
      path : string;
      ref_ : string option; [@default None] [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "contents" /% Path.string /? option (string "ref")

  module Responses = struct
    module OK = struct
      type t =
        | Content_directory of Githubc2_components.Content_directory.t
        | Content_file of Githubc2_components.Content_file.t
        | Content_symlink of Githubc2_components.Content_symlink.t
        | Content_submodule of Githubc2_components.Content_submodule.t
      [@@deriving show, eq]

      let of_yojson =
        Json_schema.one_of
          (let open CCResult in
           [
             (fun v ->
               map
                 (fun v -> Content_directory v)
                 (Githubc2_components.Content_directory.of_yojson v));
             (fun v -> map (fun v -> Content_file v) (Githubc2_components.Content_file.of_yojson v));
             (fun v ->
               map (fun v -> Content_symlink v) (Githubc2_components.Content_symlink.of_yojson v));
             (fun v ->
               map
                 (fun v -> Content_submodule v)
                 (Githubc2_components.Content_submodule.of_yojson v));
           ])

      let to_yojson = function
        | Content_directory v -> Githubc2_components.Content_directory.to_yojson v
        | Content_file v -> Githubc2_components.Content_file.to_yojson v
        | Content_symlink v -> Githubc2_components.Content_symlink.to_yojson v
        | Content_submodule v -> Githubc2_components.Content_submodule.to_yojson v
    end

    module Found = struct end
    module Not_modified = struct end

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
      | `Found
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("302", fun _ -> Ok `Found);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/contents/{path}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("path", Var (params.path, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("ref", Var (params.ref_, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Compare_commits = struct
  module Parameters = struct
    type t = {
      basehead : string;
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
    / "compare"
    /% Path.string
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Commit_comparison.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/compare/{basehead}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("basehead", Var (params.basehead, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_community_profile_metrics = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "community" / "profile"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Community_profile.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/community/profile"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_commit_statuses_for_ref = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      ref_ : string; [@key "ref"]
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
    / "commits"
    /% Path.string
    / "statuses"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Status.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Moved_permanently = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/commits/{ref}/statuses"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ref", Var (params.ref_, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_combined_status_for_ref = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      ref_ : string; [@key "ref"]
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
    / "commits"
    /% Path.string
    / "status"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Combined_commit_status.t
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

  let url = "/repos/{owner}/{repo}/commits/{ref}/status"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ref", Var (params.ref_, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_commit = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      ref_ : string; [@key "ref"]
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
    / "commits"
    /% Path.string
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Commit.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
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
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Internal_server_error of Internal_server_error.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/commits/{ref}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ref", Var (params.ref_, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_pull_requests_associated_with_commit = struct
  module Parameters = struct
    type t = {
      commit_sha : string;
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
    / "commits"
    /% Path.string
    / "pulls"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Pull_request_simple.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/commits/{commit_sha}/pulls"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("commit_sha", Var (params.commit_sha, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_commit_comment = struct
  module Parameters = struct
    type t = {
      commit_sha : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        body : string;
        line : int option; [@default None]
        path : string option; [@default None]
        position : int option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "commits" /% Path.string / "comments"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Commit_comment.t
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

    type t =
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/commits/{commit_sha}/comments"

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
           ("commit_sha", Var (params.commit_sha, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_comments_for_commit = struct
  module Parameters = struct
    type t = {
      commit_sha : string;
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
    / "commits"
    /% Path.string
    / "comments"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Commit_comment.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/commits/{commit_sha}/comments"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("commit_sha", Var (params.commit_sha, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_branches_for_head_commit = struct
  module Parameters = struct
    type t = {
      commit_sha : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "commits" /% Path.string / "branches-where-head"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Branch_short.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/commits/{commit_sha}/branches-where-head"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("commit_sha", Var (params.commit_sha, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_commits = struct
  module Parameters = struct
    type t = {
      author : string option; [@default None]
      committer : string option; [@default None]
      owner : string;
      page : int; [@default 1]
      path : string option; [@default None]
      per_page : int; [@default 30]
      repo : string;
      sha : string option; [@default None]
      since : string option; [@default None]
      until : string option; [@default None]
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
    / "commits"
    /? option (string "sha")
    /? option (string "path")
    /? option (string "author")
    /? option (string "committer")
    /? option (string "since")
    /? option (string "until")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Commit.t list
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

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/repos/{owner}/{repo}/commits"

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
           ("sha", Var (params.sha, Option String));
           ("path", Var (params.path, Option String));
           ("author", Var (params.author, Option String));
           ("committer", Var (params.committer, Option String));
           ("since", Var (params.since, Option String));
           ("until", Var (params.until, Option String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_commit_comment = struct
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
    rel / "repos" /% Path.string /% Path.string / "comments" /% Path.ud CCInt64.of_string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Commit_comment.t
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

  let url = "/repos/{owner}/{repo}/comments/{comment_id}"

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

module Delete_commit_comment = struct
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
    rel / "repos" /% Path.string /% Path.string / "comments" /% Path.ud CCInt64.of_string

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

  let url = "/repos/{owner}/{repo}/comments/{comment_id}"

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

module Get_commit_comment = struct
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
    rel / "repos" /% Path.string /% Path.string / "comments" /% Path.ud CCInt64.of_string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Commit_comment.t
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

  let url = "/repos/{owner}/{repo}/comments/{comment_id}"

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

module List_commit_comments_for_repo = struct
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
    / "comments"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Commit_comment.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/comments"

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

module Get_collaborator_permission_level = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "collaborators" /% Path.string / "permission"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_collaborator_permission.t
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

  let url = "/repos/{owner}/{repo}/collaborators/{username}/permission"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_collaborator = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "collaborators" /% Path.string

  module Responses = struct
    module No_content = struct end

    module Forbidden = struct
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
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/collaborators/{username}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_collaborator = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { permission : string [@default "push"] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "collaborators" /% Path.string

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Repository_invitation.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module No_content = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `No_content
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/collaborators/{username}"

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
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Check_collaborator = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "collaborators" /% Path.string

  module Responses = struct
    module No_content = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Not_found
      ]
    [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/repos/{owner}/{repo}/collaborators/{username}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_collaborators = struct
  module Parameters = struct
    module Affiliation = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "direct" -> Ok `Direct
        | `String "outside" -> Ok `Outside
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Direct -> `String "direct"
        | `Outside -> `String "outside"

      type t =
        ([ `All
         | `Direct
         | `Outside
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Permission = struct
      let t_of_yojson = function
        | `String "admin" -> Ok `Admin
        | `String "maintain" -> Ok `Maintain
        | `String "pull" -> Ok `Pull
        | `String "push" -> Ok `Push
        | `String "triage" -> Ok `Triage
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Admin -> `String "admin"
        | `Maintain -> `String "maintain"
        | `Pull -> `String "pull"
        | `Push -> `String "push"
        | `Triage -> `String "triage"

      type t =
        ([ `Admin
         | `Maintain
         | `Pull
         | `Push
         | `Triage
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      affiliation : Affiliation.t; [@default `All]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      permission : Permission.t option; [@default None]
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
    / "collaborators"
    /? option_default
         `All
         (ud "affiliation" (fun value ->
              CCResult.to_opt (Parameters.Affiliation.t_of_yojson (`String value))))
    /? option
         (ud "permission" (fun value ->
              CCResult.to_opt (Parameters.Permission.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Collaborator.t list
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

  let url = "/repos/{owner}/{repo}/collaborators"

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
           ("affiliation", Var (params.affiliation, Enum Affiliation.t_to_yojson));
           ("permission", Var (params.permission, Option (Enum Permission.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Codeowners_errors = struct
  module Parameters = struct
    type t = {
      owner : string;
      ref_ : string option; [@default None] [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "codeowners" / "errors" /? option (string "ref")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Codeowners_errors.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/repos/{owner}/{repo}/codeowners/errors"

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
         [ ("ref", Var (params.ref_, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Rename_branch = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { new_name : string }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "branches" /% Path.string / "rename"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Branch_with_protection.t
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
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/branches/{branch}/rename"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Remove_user_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Users = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { users : Users.t }
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
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "users"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Simple_user.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/users"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_user_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Users = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { users : Users.t }
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
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "users"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Simple_user.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/users"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Set_user_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Users = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { users : Users.t }
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
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "users"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Simple_user.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/users"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_users_with_access_to_protected_branch = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "users"

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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/users"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_team_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Teams = struct
          type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { teams : Teams.t }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
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

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "teams"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Team.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/teams"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_team_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Teams = struct
          type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { teams : Teams.t }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
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

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "teams"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Team.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/teams"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Set_team_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Teams = struct
          type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { teams : Teams.t }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
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

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "teams"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Team.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/teams"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_teams_with_access_to_protected_branch = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "teams"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Team.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/teams"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_app_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Apps = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { apps : Apps.t } [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "apps"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Integration.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/apps"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_app_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Apps = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { apps : Apps.t } [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "apps"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Integration.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/apps"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Set_app_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Apps = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { apps : Apps.t } [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "apps"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Integration.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/apps"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_apps_with_access_to_protected_branch = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"
    / "apps"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Integration.t list
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions/apps"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_access_restrictions = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "restrictions"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Branch_restriction_policy.t
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/restrictions"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_status_check_contexts = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Contexts = struct
          type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { contexts : Contexts.t }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
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

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "branches"
    /% Path.string
    / "protection"
    / "required_status_checks"
    / "contexts"

  module Responses = struct
    module OK = struct
      type t = string list [@@deriving yojson { strict = false; meta = false }, show, eq]
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks/contexts"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_status_check_contexts = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Contexts = struct
          type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { contexts : Contexts.t }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
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

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "branches"
    /% Path.string
    / "protection"
    / "required_status_checks"
    / "contexts"

  module Responses = struct
    module OK = struct
      type t = string list [@@deriving yojson { strict = false; meta = false }, show, eq]
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks/contexts"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Set_status_check_contexts = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Contexts = struct
          type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = { contexts : Contexts.t }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
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

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "branches"
    /% Path.string
    / "protection"
    / "required_status_checks"
    / "contexts"

  module Responses = struct
    module OK = struct
      type t = string list [@@deriving yojson { strict = false; meta = false }, show, eq]
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks/contexts"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_all_status_check_contexts = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_status_checks"
    / "contexts"

  module Responses = struct
    module OK = struct
      type t = string list [@@deriving yojson { strict = false; meta = false }, show, eq]
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks/contexts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Update_status_check_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Checks = struct
        module Items = struct
          module Primary = struct
            type t = {
              app_id : int option; [@default None]
              context : string;
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Contexts = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        checks : Checks.t option; [@default None]
        contexts : Contexts.t option; [@default None]
        strict : bool option; [@default None]
      }
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_status_checks"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Status_check_policy.t
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Remove_status_check_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_status_checks"

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_status_checks_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_status_checks"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Status_check_policy.t
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_commit_signature_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_signatures"

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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_signatures"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_commit_signature_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_signatures"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Protected_branch_admin_enforced.t
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_signatures"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_commit_signature_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_signatures"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Protected_branch_admin_enforced.t
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_signatures"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Update_pull_request_review_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Bypass_pull_request_allowances = struct
        module Primary = struct
          module Apps = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module Teams = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module Users = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t = {
            apps : Apps.t option; [@default None]
            teams : Teams.t option; [@default None]
            users : Users.t option; [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Dismissal_restrictions = struct
        module Primary = struct
          module Apps = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module Teams = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module Users = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t = {
            apps : Apps.t option; [@default None]
            teams : Teams.t option; [@default None]
            users : Users.t option; [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = {
        bypass_pull_request_allowances : Bypass_pull_request_allowances.t option; [@default None]
        dismiss_stale_reviews : bool option; [@default None]
        dismissal_restrictions : Dismissal_restrictions.t option; [@default None]
        require_code_owner_reviews : bool option; [@default None]
        require_last_push_approval : bool; [@default false]
        required_approving_review_count : int option; [@default None]
      }
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_pull_request_reviews"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Protected_branch_pull_request_review.t
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_pull_request_reviews"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_pull_request_review_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_pull_request_reviews"

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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_pull_request_reviews"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_pull_request_review_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "required_pull_request_reviews"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Protected_branch_pull_request_review.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/required_pull_request_reviews"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_admin_branch_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "enforce_admins"

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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/enforce_admins"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Set_admin_branch_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "enforce_admins"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Protected_branch_admin_enforced.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/enforce_admins"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_admin_branch_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
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
    / "branches"
    /% Path.string
    / "protection"
    / "enforce_admins"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Protected_branch_admin_enforced.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection/enforce_admins"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_branch_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "branches" /% Path.string / "protection"

  module Responses = struct
    module No_content = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_branch_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Required_pull_request_reviews = struct
        module Primary = struct
          module Bypass_pull_request_allowances = struct
            module Primary = struct
              module Apps = struct
                type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              module Teams = struct
                type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              module Users = struct
                type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                apps : Apps.t option; [@default None]
                teams : Teams.t option; [@default None]
                users : Users.t option; [@default None]
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Dismissal_restrictions = struct
            module Primary = struct
              module Apps = struct
                type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              module Teams = struct
                type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              module Users = struct
                type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = {
                apps : Apps.t option; [@default None]
                teams : Teams.t option; [@default None]
                users : Users.t option; [@default None]
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = {
            bypass_pull_request_allowances : Bypass_pull_request_allowances.t option;
                [@default None]
            dismiss_stale_reviews : bool option; [@default None]
            dismissal_restrictions : Dismissal_restrictions.t option; [@default None]
            require_code_owner_reviews : bool option; [@default None]
            require_last_push_approval : bool; [@default false]
            required_approving_review_count : int option; [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Required_status_checks = struct
        module Primary = struct
          module Checks = struct
            module Items = struct
              module Primary = struct
                type t = {
                  app_id : int option; [@default None]
                  context : string;
                }
                [@@deriving make, yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module Contexts = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t = {
            checks : Checks.t option; [@default None]
            contexts : Contexts.t;
            strict : bool;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Restrictions = struct
        module Primary = struct
          module Apps = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module Teams = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module Users = struct
            type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t = {
            apps : Apps.t option; [@default None]
            teams : Teams.t;
            users : Users.t;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = {
        allow_deletions : bool option; [@default None]
        allow_force_pushes : bool option; [@default None]
        allow_fork_syncing : bool; [@default false]
        block_creations : bool option; [@default None]
        enforce_admins : bool option; [@default None]
        lock_branch : bool; [@default false]
        required_conversation_resolution : bool option; [@default None]
        required_linear_history : bool option; [@default None]
        required_pull_request_reviews : Required_pull_request_reviews.t option; [@default None]
        required_status_checks : Required_status_checks.t option; [@default None]
        restrictions : Restrictions.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "branches" /% Path.string / "protection"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Protected_branch.t
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection"

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
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_branch_protection = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "branches" /% Path.string / "protection"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Branch_protection.t
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

  let url = "/repos/{owner}/{repo}/branches/{branch}/protection"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_branch = struct
  module Parameters = struct
    type t = {
      branch : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "branches" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Branch_with_protection.t
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

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/branches/{branch}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("branch", Var (params.branch, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_branches = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      protected : bool option; [@default None]
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
    / "branches"
    /? option (bool "protected")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Short_branch.t list
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

  let url = "/repos/{owner}/{repo}/branches"

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
           ("protected", Var (params.protected, Option Bool));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Disable_automated_security_fixes = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "automated-security-fixes"

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/automated-security-fixes"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Enable_automated_security_fixes = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "automated-security-fixes"

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/automated-security-fixes"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Check_automated_security_fixes = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "automated-security-fixes"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Check_automated_security_fixes.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/repos/{owner}/{repo}/automated-security-fixes"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_autolink = struct
  module Parameters = struct
    type t = {
      autolink_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "autolinks" /% Path.int

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

  let url = "/repos/{owner}/{repo}/autolinks/{autolink_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("autolink_id", Var (params.autolink_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_autolink = struct
  module Parameters = struct
    type t = {
      autolink_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "autolinks" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Autolink.t
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

  let url = "/repos/{owner}/{repo}/autolinks/{autolink_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("autolink_id", Var (params.autolink_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_autolink = struct
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
        is_alphanumeric : bool; [@default true]
        key_prefix : string;
        url_template : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "autolinks"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Autolink.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/autolinks"

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

module List_autolinks = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "autolinks"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Autolink.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/autolinks"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_attestations = struct
  module Parameters = struct
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      owner : string;
      per_page : int; [@default 30]
      predicate_type : string option; [@default None]
      repo : string;
      subject_digest : string;
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
    / "attestations"
    /% Path.string
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")
    /? option (string "predicate_type")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Attestations = struct
          module Items = struct
            module Primary = struct
              module Bundle = struct
                module Primary = struct
                  module DsseEnvelope = struct
                    include
                      Json_schema.Additional_properties.Make
                        (Json_schema.Empty_obj)
                        (Json_schema.Obj)
                  end

                  module VerificationMaterial = struct
                    include
                      Json_schema.Additional_properties.Make
                        (Json_schema.Empty_obj)
                        (Json_schema.Obj)
                  end

                  type t = {
                    dsseenvelope : DsseEnvelope.t option; [@default None] [@key "dsseEnvelope"]
                    mediatype : string option; [@default None] [@key "mediaType"]
                    verificationmaterial : VerificationMaterial.t option;
                        [@default None] [@key "verificationMaterial"]
                  }
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t = {
                bundle : Bundle.t option; [@default None]
                bundle_url : string option; [@default None]
                initiator : string option; [@default None]
                repository_id : int option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = { attestations : Attestations.t option [@default None] }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/attestations/{subject_digest}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("subject_digest", Var (params.subject_digest, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("predicate_type", Var (params.predicate_type, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_attestation = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Bundle = struct
        module Primary = struct
          module DsseEnvelope = struct
            include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
          end

          module VerificationMaterial = struct
            include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
          end

          type t = {
            dsseenvelope : DsseEnvelope.t option; [@default None] [@key "dsseEnvelope"]
            mediatype : string option; [@default None] [@key "mediaType"]
            verificationmaterial : VerificationMaterial.t option;
                [@default None] [@key "verificationMaterial"]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = { bundle : Bundle.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "attestations"

  module Responses = struct
    module Created = struct
      module Primary = struct
        type t = { id : int option [@default None] }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Forbidden = struct
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
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/attestations"

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

module List_activities = struct
  module Parameters = struct
    module Activity_type = struct
      let t_of_yojson = function
        | `String "branch_creation" -> Ok `Branch_creation
        | `String "branch_deletion" -> Ok `Branch_deletion
        | `String "force_push" -> Ok `Force_push
        | `String "merge_queue_merge" -> Ok `Merge_queue_merge
        | `String "pr_merge" -> Ok `Pr_merge
        | `String "push" -> Ok `Push
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Branch_creation -> `String "branch_creation"
        | `Branch_deletion -> `String "branch_deletion"
        | `Force_push -> `String "force_push"
        | `Merge_queue_merge -> `String "merge_queue_merge"
        | `Pr_merge -> `String "pr_merge"
        | `Push -> `String "push"

      type t =
        ([ `Branch_creation
         | `Branch_deletion
         | `Force_push
         | `Merge_queue_merge
         | `Pr_merge
         | `Push
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

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

    module Time_period = struct
      let t_of_yojson = function
        | `String "day" -> Ok `Day
        | `String "month" -> Ok `Month
        | `String "quarter" -> Ok `Quarter
        | `String "week" -> Ok `Week
        | `String "year" -> Ok `Year
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Day -> `String "day"
        | `Month -> `String "month"
        | `Quarter -> `String "quarter"
        | `Week -> `String "week"
        | `Year -> `String "year"

      type t =
        ([ `Day
         | `Month
         | `Quarter
         | `Week
         | `Year
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      activity_type : Activity_type.t option; [@default None]
      actor : string option; [@default None]
      after : string option; [@default None]
      before : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      owner : string;
      per_page : int; [@default 30]
      ref_ : string option; [@default None] [@key "ref"]
      repo : string;
      time_period : Time_period.t option; [@default None]
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
    / "activity"
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")
    /? option (string "ref")
    /? option (string "actor")
    /? option
         (ud "time_period" (fun value ->
              CCResult.to_opt (Parameters.Time_period.t_of_yojson (`String value))))
    /? option
         (ud "activity_type" (fun value ->
              CCResult.to_opt (Parameters.Activity_type.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Activity.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error_simple.t
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

  let url = "/repos/{owner}/{repo}/activity"

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
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("ref", Var (params.ref_, Option String));
           ("actor", Var (params.actor, Option String));
           ("time_period", Var (params.time_period, Option (Enum Time_period.t_to_yojson)));
           ("activity_type", Var (params.activity_type, Option (Enum Activity_type.t_to_yojson)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Merge_commit_message = struct
        let t_of_yojson = function
          | `String "BLANK" -> Ok `BLANK
          | `String "PR_BODY" -> Ok `PR_BODY
          | `String "PR_TITLE" -> Ok `PR_TITLE
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `BLANK -> `String "BLANK"
          | `PR_BODY -> `String "PR_BODY"
          | `PR_TITLE -> `String "PR_TITLE"

        type t =
          ([ `BLANK
           | `PR_BODY
           | `PR_TITLE
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Merge_commit_title = struct
        let t_of_yojson = function
          | `String "MERGE_MESSAGE" -> Ok `MERGE_MESSAGE
          | `String "PR_TITLE" -> Ok `PR_TITLE
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `MERGE_MESSAGE -> `String "MERGE_MESSAGE"
          | `PR_TITLE -> `String "PR_TITLE"

        type t =
          ([ `MERGE_MESSAGE
           | `PR_TITLE
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Pull_request_creation_policy = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "collaborators_only" -> Ok `Collaborators_only
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `Collaborators_only -> `String "collaborators_only"

        type t =
          ([ `All
           | `Collaborators_only
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Security_and_analysis = struct
        module Primary = struct
          module Advanced_security = struct
            module Primary = struct
              type t = { status : string option [@default None] }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Code_security = struct
            module Primary = struct
              type t = { status : string option [@default None] }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Secret_scanning = struct
            module Primary = struct
              type t = { status : string option [@default None] }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Secret_scanning_ai_detection = struct
            module Primary = struct
              type t = { status : string option [@default None] }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Secret_scanning_delegated_alert_dismissal = struct
            module Primary = struct
              type t = { status : string option [@default None] }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Secret_scanning_delegated_bypass = struct
            module Primary = struct
              type t = { status : string option [@default None] }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Secret_scanning_delegated_bypass_options = struct
            module Primary = struct
              module Reviewers = struct
                module Items = struct
                  module Primary = struct
                    module Mode = struct
                      let t_of_yojson = function
                        | `String "ALWAYS" -> Ok `ALWAYS
                        | `String "EXEMPT" -> Ok `EXEMPT
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `ALWAYS -> `String "ALWAYS"
                        | `EXEMPT -> `String "EXEMPT"

                      type t =
                        ([ `ALWAYS
                         | `EXEMPT
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    module Reviewer_type = struct
                      let t_of_yojson = function
                        | `String "ROLE" -> Ok `ROLE
                        | `String "TEAM" -> Ok `TEAM
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `ROLE -> `String "ROLE"
                        | `TEAM -> `String "TEAM"

                      type t =
                        ([ `ROLE
                         | `TEAM
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    type t = {
                      mode : Mode.t; [@default `ALWAYS]
                      reviewer_id : int;
                      reviewer_type : Reviewer_type.t;
                    }
                    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              type t = { reviewers : Reviewers.t option [@default None] }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Secret_scanning_non_provider_patterns = struct
            module Primary = struct
              type t = { status : string option [@default None] }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Secret_scanning_push_protection = struct
            module Primary = struct
              type t = { status : string option [@default None] }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = {
            advanced_security : Advanced_security.t option; [@default None]
            code_security : Code_security.t option; [@default None]
            secret_scanning : Secret_scanning.t option; [@default None]
            secret_scanning_ai_detection : Secret_scanning_ai_detection.t option; [@default None]
            secret_scanning_delegated_alert_dismissal :
              Secret_scanning_delegated_alert_dismissal.t option;
                [@default None]
            secret_scanning_delegated_bypass : Secret_scanning_delegated_bypass.t option;
                [@default None]
            secret_scanning_delegated_bypass_options :
              Secret_scanning_delegated_bypass_options.t option;
                [@default None]
            secret_scanning_non_provider_patterns : Secret_scanning_non_provider_patterns.t option;
                [@default None]
            secret_scanning_push_protection : Secret_scanning_push_protection.t option;
                [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Squash_merge_commit_message = struct
        let t_of_yojson = function
          | `String "BLANK" -> Ok `BLANK
          | `String "COMMIT_MESSAGES" -> Ok `COMMIT_MESSAGES
          | `String "PR_BODY" -> Ok `PR_BODY
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `BLANK -> `String "BLANK"
          | `COMMIT_MESSAGES -> `String "COMMIT_MESSAGES"
          | `PR_BODY -> `String "PR_BODY"

        type t =
          ([ `BLANK
           | `COMMIT_MESSAGES
           | `PR_BODY
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Squash_merge_commit_title = struct
        let t_of_yojson = function
          | `String "COMMIT_OR_PR_TITLE" -> Ok `COMMIT_OR_PR_TITLE
          | `String "PR_TITLE" -> Ok `PR_TITLE
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `COMMIT_OR_PR_TITLE -> `String "COMMIT_OR_PR_TITLE"
          | `PR_TITLE -> `String "PR_TITLE"

        type t =
          ([ `COMMIT_OR_PR_TITLE
           | `PR_TITLE
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Visibility = struct
        let t_of_yojson = function
          | `String "private" -> Ok `Private
          | `String "public" -> Ok `Public
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Private -> `String "private"
          | `Public -> `String "public"

        type t =
          ([ `Private
           | `Public
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        allow_auto_merge : bool; [@default false]
        allow_forking : bool; [@default false]
        allow_merge_commit : bool; [@default true]
        allow_rebase_merge : bool; [@default true]
        allow_squash_merge : bool; [@default true]
        allow_update_branch : bool; [@default false]
        archived : bool; [@default false]
        default_branch : string option; [@default None]
        delete_branch_on_merge : bool; [@default false]
        description : string option; [@default None]
        has_issues : bool; [@default true]
        has_projects : bool; [@default true]
        has_pull_requests : bool; [@default true]
        has_wiki : bool; [@default true]
        homepage : string option; [@default None]
        is_template : bool; [@default false]
        merge_commit_message : Merge_commit_message.t option; [@default None]
        merge_commit_title : Merge_commit_title.t option; [@default None]
        name : string option; [@default None]
        private_ : bool; [@default false] [@key "private"]
        pull_request_creation_policy : Pull_request_creation_policy.t option; [@default None]
        security_and_analysis : Security_and_analysis.t option; [@default None]
        squash_merge_commit_message : Squash_merge_commit_message.t option; [@default None]
        squash_merge_commit_title : Squash_merge_commit_title.t option; [@default None]
        use_squash_pr_title_as_default : bool; [@default false]
        visibility : Visibility.t option; [@default None]
        web_commit_signoff_required : bool; [@default false]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Full_repository.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Temporary_redirect = struct
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

    type t =
      [ `OK of OK.t
      | `Temporary_redirect of Temporary_redirect.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("307", Openapi.of_json_body (fun v -> `Temporary_redirect v) Temporary_redirect.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string

  module Responses = struct
    module No_content = struct end

    module Temporary_redirect = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      module Primary = struct
        type t = {
          documentation_url : string option; [@default None]
          message : string option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Temporary_redirect of Temporary_redirect.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("307", Openapi.of_json_body (fun v -> `Temporary_redirect v) Temporary_redirect.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Full_repository.t
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

    type t =
      [ `OK of OK.t
      | `Moved_permanently of Moved_permanently.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("301", Openapi.of_json_body (fun v -> `Moved_permanently v) Moved_permanently.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_org_ruleset = struct
  module Parameters = struct
    type t = {
      org : string;
      ruleset_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "rulesets" /% Path.int

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/orgs/{org}/rulesets/{ruleset_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("ruleset_id", Var (params.ruleset_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_org_ruleset = struct
  module Parameters = struct
    type t = {
      org : string;
      ruleset_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Bypass_actors = struct
        type t = Githubc2_components.Repository_ruleset_bypass_actor.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Rules = struct
        type t = Githubc2_components.Org_rules.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Target = struct
        let t_of_yojson = function
          | `String "branch" -> Ok `Branch
          | `String "push" -> Ok `Push
          | `String "repository" -> Ok `Repository
          | `String "tag" -> Ok `Tag
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Branch -> `String "branch"
          | `Push -> `String "push"
          | `Repository -> `String "repository"
          | `Tag -> `String "tag"

        type t =
          ([ `Branch
           | `Push
           | `Repository
           | `Tag
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        bypass_actors : Bypass_actors.t option; [@default None]
        conditions : Githubc2_components.Org_ruleset_conditions.t option; [@default None]
        enforcement : Githubc2_components.Repository_rule_enforcement.t option; [@default None]
        name : string option; [@default None]
        rules : Rules.t option; [@default None]
        target : Target.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "rulesets" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_ruleset.t
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

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/orgs/{org}/rulesets/{ruleset_id}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("ruleset_id", Var (params.ruleset_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_org_ruleset = struct
  module Parameters = struct
    type t = {
      org : string;
      ruleset_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "rulesets" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_ruleset.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/orgs/{org}/rulesets/{ruleset_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("ruleset_id", Var (params.ruleset_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_org_rule_suite = struct
  module Parameters = struct
    type t = {
      org : string;
      rule_suite_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "rulesets" / "rule-suites" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Rule_suite.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/orgs/{org}/rulesets/rule-suites/{rule_suite_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("rule_suite_id", Var (params.rule_suite_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_org_rule_suites = struct
  module Parameters = struct
    module Evaluate_status = struct
      let t_of_yojson = function
        | `String "active" -> Ok `Active
        | `String "all" -> Ok `All
        | `String "evaluate" -> Ok `Evaluate
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Active -> `String "active"
        | `All -> `String "all"
        | `Evaluate -> `String "evaluate"

      type t =
        ([ `Active
         | `All
         | `Evaluate
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Rule_suite_result = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "bypass" -> Ok `Bypass
        | `String "fail" -> Ok `Fail
        | `String "pass" -> Ok `Pass
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Bypass -> `String "bypass"
        | `Fail -> `String "fail"
        | `Pass -> `String "pass"

      type t =
        ([ `All
         | `Bypass
         | `Fail
         | `Pass
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Time_period = struct
      let t_of_yojson = function
        | `String "day" -> Ok `Day
        | `String "hour" -> Ok `Hour
        | `String "month" -> Ok `Month
        | `String "week" -> Ok `Week
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Day -> `String "day"
        | `Hour -> `String "hour"
        | `Month -> `String "month"
        | `Week -> `String "week"

      type t =
        ([ `Day
         | `Hour
         | `Month
         | `Week
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      actor_name : string option; [@default None]
      evaluate_status : Evaluate_status.t; [@default `All]
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      ref_ : string option; [@default None] [@key "ref"]
      repository_name : string option; [@default None]
      rule_suite_result : Rule_suite_result.t; [@default `All]
      time_period : Time_period.t; [@default `Day]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "rulesets"
    / "rule-suites"
    /? option (string "ref")
    /? option (string "repository_name")
    /? option_default
         `Day
         (ud "time_period" (fun value ->
              CCResult.to_opt (Parameters.Time_period.t_of_yojson (`String value))))
    /? option (string "actor_name")
    /? option_default
         `All
         (ud "rule_suite_result" (fun value ->
              CCResult.to_opt (Parameters.Rule_suite_result.t_of_yojson (`String value))))
    /? option_default
         `All
         (ud "evaluate_status" (fun value ->
              CCResult.to_opt (Parameters.Evaluate_status.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Rule_suites.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/orgs/{org}/rulesets/rule-suites"

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
           ("ref", Var (params.ref_, Option String));
           ("repository_name", Var (params.repository_name, Option String));
           ("time_period", Var (params.time_period, Enum Time_period.t_to_yojson));
           ("actor_name", Var (params.actor_name, Option String));
           ("rule_suite_result", Var (params.rule_suite_result, Enum Rule_suite_result.t_to_yojson));
           ("evaluate_status", Var (params.evaluate_status, Enum Evaluate_status.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_org_ruleset = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Bypass_actors = struct
        type t = Githubc2_components.Repository_ruleset_bypass_actor.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Rules = struct
        type t = Githubc2_components.Org_rules.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Target = struct
        let t_of_yojson = function
          | `String "branch" -> Ok `Branch
          | `String "push" -> Ok `Push
          | `String "repository" -> Ok `Repository
          | `String "tag" -> Ok `Tag
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Branch -> `String "branch"
          | `Push -> `String "push"
          | `Repository -> `String "repository"
          | `Tag -> `String "tag"

        type t =
          ([ `Branch
           | `Push
           | `Repository
           | `Tag
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        bypass_actors : Bypass_actors.t option; [@default None]
        conditions : Githubc2_components.Org_ruleset_conditions.t option; [@default None]
        enforcement : Githubc2_components.Repository_rule_enforcement.t;
        name : string;
        rules : Rules.t option; [@default None]
        target : Target.t; [@default `Branch]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "rulesets"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Repository_ruleset.t
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

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/orgs/{org}/rulesets"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_org_rulesets = struct
  module Parameters = struct
    type t = {
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      targets : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "rulesets"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option (string "targets")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_ruleset.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Internal_server_error of Internal_server_error.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "500",
          Openapi.of_json_body (fun v -> `Internal_server_error v) Internal_server_error.of_yojson
        );
      ]
  end

  let url = "/orgs/{org}/rulesets"

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
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("targets", Var (params.targets, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_in_org = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Custom_properties = struct
        include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
      end

      module Merge_commit_message = struct
        let t_of_yojson = function
          | `String "BLANK" -> Ok `BLANK
          | `String "PR_BODY" -> Ok `PR_BODY
          | `String "PR_TITLE" -> Ok `PR_TITLE
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `BLANK -> `String "BLANK"
          | `PR_BODY -> `String "PR_BODY"
          | `PR_TITLE -> `String "PR_TITLE"

        type t =
          ([ `BLANK
           | `PR_BODY
           | `PR_TITLE
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Merge_commit_title = struct
        let t_of_yojson = function
          | `String "MERGE_MESSAGE" -> Ok `MERGE_MESSAGE
          | `String "PR_TITLE" -> Ok `PR_TITLE
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `MERGE_MESSAGE -> `String "MERGE_MESSAGE"
          | `PR_TITLE -> `String "PR_TITLE"

        type t =
          ([ `MERGE_MESSAGE
           | `PR_TITLE
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Squash_merge_commit_message = struct
        let t_of_yojson = function
          | `String "BLANK" -> Ok `BLANK
          | `String "COMMIT_MESSAGES" -> Ok `COMMIT_MESSAGES
          | `String "PR_BODY" -> Ok `PR_BODY
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `BLANK -> `String "BLANK"
          | `COMMIT_MESSAGES -> `String "COMMIT_MESSAGES"
          | `PR_BODY -> `String "PR_BODY"

        type t =
          ([ `BLANK
           | `COMMIT_MESSAGES
           | `PR_BODY
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Squash_merge_commit_title = struct
        let t_of_yojson = function
          | `String "COMMIT_OR_PR_TITLE" -> Ok `COMMIT_OR_PR_TITLE
          | `String "PR_TITLE" -> Ok `PR_TITLE
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `COMMIT_OR_PR_TITLE -> `String "COMMIT_OR_PR_TITLE"
          | `PR_TITLE -> `String "PR_TITLE"

        type t =
          ([ `COMMIT_OR_PR_TITLE
           | `PR_TITLE
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Visibility = struct
        let t_of_yojson = function
          | `String "private" -> Ok `Private
          | `String "public" -> Ok `Public
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Private -> `String "private"
          | `Public -> `String "public"

        type t =
          ([ `Private
           | `Public
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        allow_auto_merge : bool; [@default false]
        allow_merge_commit : bool; [@default true]
        allow_rebase_merge : bool; [@default true]
        allow_squash_merge : bool; [@default true]
        auto_init : bool; [@default false]
        custom_properties : Custom_properties.t option; [@default None]
        delete_branch_on_merge : bool; [@default false]
        description : string option; [@default None]
        gitignore_template : string option; [@default None]
        has_downloads : bool; [@default true]
        has_issues : bool; [@default true]
        has_projects : bool; [@default true]
        has_wiki : bool; [@default true]
        homepage : string option; [@default None]
        is_template : bool; [@default false]
        license_template : string option; [@default None]
        merge_commit_message : Merge_commit_message.t option; [@default None]
        merge_commit_title : Merge_commit_title.t option; [@default None]
        name : string;
        private_ : bool; [@default false] [@key "private"]
        squash_merge_commit_message : Squash_merge_commit_message.t option; [@default None]
        squash_merge_commit_title : Squash_merge_commit_title.t option; [@default None]
        team_id : int option; [@default None]
        use_squash_pr_title_as_default : bool; [@default false]
        visibility : Visibility.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "repos"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Full_repository.t
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

    type t =
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/repos"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
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

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "full_name" -> Ok `Full_name
        | `String "pushed" -> Ok `Pushed
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Full_name -> `String "full_name"
        | `Pushed -> `String "pushed"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Full_name
         | `Pushed
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Type = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "forks" -> Ok `Forks
        | `String "member" -> Ok `Member
        | `String "private" -> Ok `Private
        | `String "public" -> Ok `Public
        | `String "sources" -> Ok `Sources
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Forks -> `String "forks"
        | `Member -> `String "member"
        | `Private -> `String "private"
        | `Public -> `String "public"
        | `Sources -> `String "sources"

      type t =
        ([ `All
         | `Forks
         | `Member
         | `Private
         | `Public
         | `Sources
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t option; [@default None]
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      sort : Sort.t; [@default `Created]
      type_ : Type.t; [@default `All] [@key "type"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "repos"
    /? option_default
         `All
         (ud "type" (fun value -> CCResult.to_opt (Parameters.Type.t_of_yojson (`String value))))
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Minimal_repository.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/repos"

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
           ("type", Var (params.type_, Enum Type.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Option (Enum Direction.t_to_yojson)));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
