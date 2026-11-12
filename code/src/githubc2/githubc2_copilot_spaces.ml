module Delete_resource_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      space_resource_id : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int / "resources" /% Path.int

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

  let url = "/users/{username}/copilot-spaces/{space_number}/resources/{space_resource_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
           ("space_resource_id", Var (params.space_resource_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_resource_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      space_resource_id : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Metadata = struct
        include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
      end

      type t = { metadata : Metadata.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int / "resources" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space_resource.t
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

  let url = "/users/{username}/copilot-spaces/{space_number}/resources/{space_resource_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
           ("space_resource_id", Var (params.space_resource_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_resource_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      space_resource_id : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int / "resources" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space_resource.t
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

  let url = "/users/{username}/copilot-spaces/{space_number}/resources/{space_resource_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
           ("space_resource_id", Var (params.space_resource_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_resource_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Metadata = struct
        include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
      end

      module Resource_type = struct
        let t_of_yojson = function
          | `String "free_text" -> Ok `Free_text
          | `String "github_file" -> Ok `Github_file
          | `String "github_issue" -> Ok `Github_issue
          | `String "github_pull_request" -> Ok `Github_pull_request
          | `String "repository" -> Ok `Repository
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Free_text -> `String "free_text"
          | `Github_file -> `String "github_file"
          | `Github_issue -> `String "github_issue"
          | `Github_pull_request -> `String "github_pull_request"
          | `Repository -> `String "repository"

        type t =
          ([ `Free_text
           | `Github_file
           | `Github_issue
           | `Github_pull_request
           | `Repository
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        metadata : Metadata.t;
        resource_type : Resource_type.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int / "resources"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space_resource.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Githubc2_components.Copilot_space_resource.t
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
      | `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/users/{username}/copilot-spaces/{space_number}/resources"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_resources_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int / "resources"

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Resources = struct
          type t = Githubc2_components.Copilot_space_resource.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = { resources : Resources.t }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/users/{username}/copilot-spaces/{space_number}/resources"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_collaborator_for_user = struct
  module Parameters = struct
    module Actor_type = struct
      let t_of_yojson = function
        | `String "Team" -> Ok `Team
        | `String "User" -> Ok `User
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Team -> `String "Team"
        | `User -> `String "User"

      type t =
        ([ `Team
         | `User
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      actor_identifier : string;
      actor_type : Actor_type.t;
      space_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "copilot-spaces"
    /% Path.int
    / "collaborators"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Actor_type.t_of_yojson (`String value)))
    /% Path.string

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

  let url =
    "/users/{username}/copilot-spaces/{space_number}/collaborators/{actor_type}/{actor_identifier}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
           ("actor_type", Var (params.actor_type, Enum Actor_type.t_to_yojson));
           ("actor_identifier", Var (params.actor_identifier, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_collaborator_for_user = struct
  module Parameters = struct
    module Actor_type = struct
      let t_of_yojson = function
        | `String "Team" -> Ok `Team
        | `String "User" -> Ok `User
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Team -> `String "Team"
        | `User -> `String "User"

      type t =
        ([ `Team
         | `User
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      actor_identifier : string;
      actor_type : Actor_type.t;
      space_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Role = struct
        let t_of_yojson = function
          | `String "admin" -> Ok `Admin
          | `String "no_access" -> Ok `No_access
          | `String "reader" -> Ok `Reader
          | `String "writer" -> Ok `Writer
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Admin -> `String "admin"
          | `No_access -> `String "no_access"
          | `Reader -> `String "reader"
          | `Writer -> `String "writer"

        type t =
          ([ `Admin
           | `No_access
           | `Reader
           | `Writer
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { role : Role.t } [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "copilot-spaces"
    /% Path.int
    / "collaborators"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Actor_type.t_of_yojson (`String value)))
    /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space_collaborator.t
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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url =
    "/users/{username}/copilot-spaces/{space_number}/collaborators/{actor_type}/{actor_identifier}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
           ("actor_type", Var (params.actor_type, Enum Actor_type.t_to_yojson));
           ("actor_identifier", Var (params.actor_identifier, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Add_collaborator_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Actor_type = struct
        let t_of_yojson = function
          | `String "Team" -> Ok `Team
          | `String "User" -> Ok `User
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Team -> `String "Team"
          | `User -> `String "User"

        type t =
          ([ `Team
           | `User
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Role = struct
        let t_of_yojson = function
          | `String "admin" -> Ok `Admin
          | `String "reader" -> Ok `Reader
          | `String "writer" -> Ok `Writer
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Admin -> `String "admin"
          | `Reader -> `String "reader"
          | `Writer -> `String "writer"

        type t =
          ([ `Admin
           | `Reader
           | `Writer
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        actor_identifier : string;
        actor_type : Actor_type.t;
        role : Role.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int / "collaborators"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Copilot_space_collaborator.t
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

  let url = "/users/{username}/copilot-spaces/{space_number}/collaborators"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_collaborators_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int / "collaborators"

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Collaborators = struct
          type t = Githubc2_components.Copilot_space_collaborator.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = { collaborators : Collaborators.t }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/users/{username}/copilot-spaces/{space_number}/collaborators"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int

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

  let url = "/users/{username}/copilot-spaces/{space_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Base_role = struct
        let t_of_yojson = function
          | `String "no_access" -> Ok `No_access
          | `String "reader" -> Ok `Reader
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `No_access -> `String "no_access"
          | `Reader -> `String "reader"

        type t =
          ([ `No_access
           | `Reader
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Resources_attributes = struct
        module Items = struct
          module Primary = struct
            module Metadata = struct
              module Primary = struct
                type t = {
                  file_path : string option; [@default None]
                  name : string option; [@default None]
                  number : int option; [@default None]
                  repository_id : int option; [@default None]
                  text : string option; [@default None]
                }
                [@@deriving make, yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            module Resource_type = struct
              let t_of_yojson = function
                | `String "free_text" -> Ok `Free_text
                | `String "github_file" -> Ok `Github_file
                | `String "github_issue" -> Ok `Github_issue
                | `String "github_pull_request" -> Ok `Github_pull_request
                | `String "media_content" -> Ok `Media_content
                | `String "repository" -> Ok `Repository
                | `String "uploaded_text_file" -> Ok `Uploaded_text_file
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `Free_text -> `String "free_text"
                | `Github_file -> `String "github_file"
                | `Github_issue -> `String "github_issue"
                | `Github_pull_request -> `String "github_pull_request"
                | `Media_content -> `String "media_content"
                | `Repository -> `String "repository"
                | `Uploaded_text_file -> `String "uploaded_text_file"

              type t =
                ([ `Free_text
                 | `Github_file
                 | `Github_issue
                 | `Github_pull_request
                 | `Media_content
                 | `Repository
                 | `Uploaded_text_file
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              metadata : Metadata.t option; [@default None]
              resource_type : Resource_type.t option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        base_role : Base_role.t option; [@default None]
        description : string option; [@default None]
        general_instructions : string option; [@default None]
        name : string option; [@default None]
        resources_attributes : Resources_attributes.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space.t
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

  let url = "/users/{username}/copilot-spaces/{space_number}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_for_user = struct
  module Parameters = struct
    type t = {
      space_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space.t
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

  let url = "/users/{username}/copilot-spaces/{space_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("username", Var (params.username, String));
           ("space_number", Var (params.space_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_for_user = struct
  module Parameters = struct
    type t = { username : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Base_role = struct
        let t_of_yojson = function
          | `String "no_access" -> Ok `No_access
          | `String "reader" -> Ok `Reader
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `No_access -> `String "no_access"
          | `Reader -> `String "reader"

        type t =
          ([ `No_access
           | `Reader
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Resources_attributes = struct
        module Items = struct
          module Primary = struct
            module Metadata = struct
              module Primary = struct
                type t = {
                  file_path : string option; [@default None]
                  name : string option; [@default None]
                  number : int option; [@default None]
                  repository_id : int option; [@default None]
                  text : string option; [@default None]
                }
                [@@deriving make, yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            module Resource_type = struct
              let t_of_yojson = function
                | `String "free_text" -> Ok `Free_text
                | `String "github_file" -> Ok `Github_file
                | `String "github_issue" -> Ok `Github_issue
                | `String "github_pull_request" -> Ok `Github_pull_request
                | `String "media_content" -> Ok `Media_content
                | `String "repository" -> Ok `Repository
                | `String "uploaded_text_file" -> Ok `Uploaded_text_file
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `Free_text -> `String "free_text"
                | `Github_file -> `String "github_file"
                | `Github_issue -> `String "github_issue"
                | `Github_pull_request -> `String "github_pull_request"
                | `Media_content -> `String "media_content"
                | `Repository -> `String "repository"
                | `Uploaded_text_file -> `String "uploaded_text_file"

              type t =
                ([ `Free_text
                 | `Github_file
                 | `Github_issue
                 | `Github_pull_request
                 | `Media_content
                 | `Repository
                 | `Uploaded_text_file
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              metadata : Metadata.t option; [@default None]
              resource_type : Resource_type.t option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        base_role : Base_role.t; [@default `No_access]
        description : string option; [@default None]
        general_instructions : string option; [@default None]
        name : string;
        resources_attributes : Resources_attributes.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "copilot-spaces"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Copilot_space.t
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

  let url = "/users/{username}/copilot-spaces"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("username", Var (params.username, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_for_user = struct
  module Parameters = struct
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      per_page : int; [@default 30]
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
    / "copilot-spaces"
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Spaces = struct
          type t = Githubc2_components.Copilot_space.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = { spaces : Spaces.t } [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/users/{username}/copilot-spaces"

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
           ("per_page", Var (params.per_page, Int));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_resource_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
      space_resource_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int / "resources" /% Path.int

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

  let url = "/orgs/{org}/copilot-spaces/{space_number}/resources/{space_resource_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("space_number", Var (params.space_number, Int));
           ("space_resource_id", Var (params.space_resource_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_resource_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
      space_resource_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Metadata = struct
        include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
      end

      type t = { metadata : Metadata.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int / "resources" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space_resource.t
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

  let url = "/orgs/{org}/copilot-spaces/{space_number}/resources/{space_resource_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("space_number", Var (params.space_number, Int));
           ("space_resource_id", Var (params.space_resource_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_resource_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
      space_resource_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int / "resources" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space_resource.t
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

  let url = "/orgs/{org}/copilot-spaces/{space_number}/resources/{space_resource_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("space_number", Var (params.space_number, Int));
           ("space_resource_id", Var (params.space_resource_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_resource_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Metadata = struct
        include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
      end

      module Resource_type = struct
        let t_of_yojson = function
          | `String "free_text" -> Ok `Free_text
          | `String "github_file" -> Ok `Github_file
          | `String "github_issue" -> Ok `Github_issue
          | `String "github_pull_request" -> Ok `Github_pull_request
          | `String "repository" -> Ok `Repository
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Free_text -> `String "free_text"
          | `Github_file -> `String "github_file"
          | `Github_issue -> `String "github_issue"
          | `Github_pull_request -> `String "github_pull_request"
          | `Repository -> `String "repository"

        type t =
          ([ `Free_text
           | `Github_file
           | `Github_issue
           | `Github_pull_request
           | `Repository
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        metadata : Metadata.t;
        resource_type : Resource_type.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int / "resources"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space_resource.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Githubc2_components.Copilot_space_resource.t
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
      | `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/copilot-spaces/{space_number}/resources"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("space_number", Var (params.space_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_resources_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int / "resources"

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Resources = struct
          type t = Githubc2_components.Copilot_space_resource.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = { resources : Resources.t }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/orgs/{org}/copilot-spaces/{space_number}/resources"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("space_number", Var (params.space_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_collaborator_for_org = struct
  module Parameters = struct
    module Actor_type = struct
      let t_of_yojson = function
        | `String "Team" -> Ok `Team
        | `String "User" -> Ok `User
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Team -> `String "Team"
        | `User -> `String "User"

      type t =
        ([ `Team
         | `User
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      actor_identifier : string;
      actor_type : Actor_type.t;
      org : string;
      space_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "copilot-spaces"
    /% Path.int
    / "collaborators"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Actor_type.t_of_yojson (`String value)))
    /% Path.string

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

  let url =
    "/orgs/{org}/copilot-spaces/{space_number}/collaborators/{actor_type}/{actor_identifier}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("space_number", Var (params.space_number, Int));
           ("actor_type", Var (params.actor_type, Enum Actor_type.t_to_yojson));
           ("actor_identifier", Var (params.actor_identifier, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_collaborator_for_org = struct
  module Parameters = struct
    module Actor_type = struct
      let t_of_yojson = function
        | `String "Team" -> Ok `Team
        | `String "User" -> Ok `User
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Team -> `String "Team"
        | `User -> `String "User"

      type t =
        ([ `Team
         | `User
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      actor_identifier : string;
      actor_type : Actor_type.t;
      org : string;
      space_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Role = struct
        let t_of_yojson = function
          | `String "admin" -> Ok `Admin
          | `String "no_access" -> Ok `No_access
          | `String "reader" -> Ok `Reader
          | `String "writer" -> Ok `Writer
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Admin -> `String "admin"
          | `No_access -> `String "no_access"
          | `Reader -> `String "reader"
          | `Writer -> `String "writer"

        type t =
          ([ `Admin
           | `No_access
           | `Reader
           | `Writer
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { role : Role.t } [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "copilot-spaces"
    /% Path.int
    / "collaborators"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Actor_type.t_of_yojson (`String value)))
    /% Path.string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space_collaborator.t
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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url =
    "/orgs/{org}/copilot-spaces/{space_number}/collaborators/{actor_type}/{actor_identifier}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("space_number", Var (params.space_number, Int));
           ("actor_type", Var (params.actor_type, Enum Actor_type.t_to_yojson));
           ("actor_identifier", Var (params.actor_identifier, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Add_collaborator_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Actor_type = struct
        let t_of_yojson = function
          | `String "Team" -> Ok `Team
          | `String "User" -> Ok `User
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Team -> `String "Team"
          | `User -> `String "User"

        type t =
          ([ `Team
           | `User
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Role = struct
        let t_of_yojson = function
          | `String "admin" -> Ok `Admin
          | `String "reader" -> Ok `Reader
          | `String "writer" -> Ok `Writer
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Admin -> `String "admin"
          | `Reader -> `String "reader"
          | `Writer -> `String "writer"

        type t =
          ([ `Admin
           | `Reader
           | `Writer
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        actor_identifier : string;
        actor_type : Actor_type.t;
        role : Role.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int / "collaborators"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Copilot_space_collaborator.t
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

  let url = "/orgs/{org}/copilot-spaces/{space_number}/collaborators"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("space_number", Var (params.space_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_collaborators_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int / "collaborators"

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Collaborators = struct
          type t = Githubc2_components.Copilot_space_collaborator.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = { collaborators : Collaborators.t }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/orgs/{org}/copilot-spaces/{space_number}/collaborators"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("space_number", Var (params.space_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int

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

  let url = "/orgs/{org}/copilot-spaces/{space_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("space_number", Var (params.space_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Base_role = struct
        let t_of_yojson = function
          | `String "admin" -> Ok `Admin
          | `String "no_access" -> Ok `No_access
          | `String "reader" -> Ok `Reader
          | `String "writer" -> Ok `Writer
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Admin -> `String "admin"
          | `No_access -> `String "no_access"
          | `Reader -> `String "reader"
          | `Writer -> `String "writer"

        type t =
          ([ `Admin
           | `No_access
           | `Reader
           | `Writer
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Resources_attributes = struct
        module Items = struct
          module Primary = struct
            module Metadata = struct
              module Primary = struct
                type t = {
                  file_path : string option; [@default None]
                  name : string option; [@default None]
                  number : int option; [@default None]
                  repository_id : int option; [@default None]
                  text : string option; [@default None]
                }
                [@@deriving make, yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            module Resource_type = struct
              let t_of_yojson = function
                | `String "free_text" -> Ok `Free_text
                | `String "github_file" -> Ok `Github_file
                | `String "github_issue" -> Ok `Github_issue
                | `String "github_pull_request" -> Ok `Github_pull_request
                | `String "media_content" -> Ok `Media_content
                | `String "repository" -> Ok `Repository
                | `String "uploaded_text_file" -> Ok `Uploaded_text_file
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `Free_text -> `String "free_text"
                | `Github_file -> `String "github_file"
                | `Github_issue -> `String "github_issue"
                | `Github_pull_request -> `String "github_pull_request"
                | `Media_content -> `String "media_content"
                | `Repository -> `String "repository"
                | `Uploaded_text_file -> `String "uploaded_text_file"

              type t =
                ([ `Free_text
                 | `Github_file
                 | `Github_issue
                 | `Github_pull_request
                 | `Media_content
                 | `Repository
                 | `Uploaded_text_file
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              metadata : Metadata.t option; [@default None]
              resource_type : Resource_type.t option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        base_role : Base_role.t option; [@default None]
        description : string option; [@default None]
        general_instructions : string option; [@default None]
        name : string option; [@default None]
        resources_attributes : Resources_attributes.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space.t
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

  let url = "/orgs/{org}/copilot-spaces/{space_number}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("space_number", Var (params.space_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      space_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Copilot_space.t
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

  let url = "/orgs/{org}/copilot-spaces/{space_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("space_number", Var (params.space_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_for_org = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Base_role = struct
        let t_of_yojson = function
          | `String "admin" -> Ok `Admin
          | `String "no_access" -> Ok `No_access
          | `String "reader" -> Ok `Reader
          | `String "writer" -> Ok `Writer
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Admin -> `String "admin"
          | `No_access -> `String "no_access"
          | `Reader -> `String "reader"
          | `Writer -> `String "writer"

        type t =
          ([ `Admin
           | `No_access
           | `Reader
           | `Writer
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Resources_attributes = struct
        module Items = struct
          module Primary = struct
            module Metadata = struct
              module Primary = struct
                type t = {
                  file_path : string option; [@default None]
                  name : string option; [@default None]
                  number : int option; [@default None]
                  repository_id : int option; [@default None]
                  text : string option; [@default None]
                }
                [@@deriving make, yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            module Resource_type = struct
              let t_of_yojson = function
                | `String "free_text" -> Ok `Free_text
                | `String "github_file" -> Ok `Github_file
                | `String "github_issue" -> Ok `Github_issue
                | `String "github_pull_request" -> Ok `Github_pull_request
                | `String "media_content" -> Ok `Media_content
                | `String "repository" -> Ok `Repository
                | `String "uploaded_text_file" -> Ok `Uploaded_text_file
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `Free_text -> `String "free_text"
                | `Github_file -> `String "github_file"
                | `Github_issue -> `String "github_issue"
                | `Github_pull_request -> `String "github_pull_request"
                | `Media_content -> `String "media_content"
                | `Repository -> `String "repository"
                | `Uploaded_text_file -> `String "uploaded_text_file"

              type t =
                ([ `Free_text
                 | `Github_file
                 | `Github_issue
                 | `Github_pull_request
                 | `Media_content
                 | `Repository
                 | `Uploaded_text_file
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              metadata : Metadata.t option; [@default None]
              resource_type : Resource_type.t option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        base_role : Base_role.t; [@default `No_access]
        description : string option; [@default None]
        general_instructions : string option; [@default None]
        name : string;
        resources_attributes : Resources_attributes.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "copilot-spaces"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Copilot_space.t
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

  let url = "/orgs/{org}/copilot-spaces"

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
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      org : string;
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "copilot-spaces"
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Spaces = struct
          type t = Githubc2_components.Copilot_space.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = { spaces : Spaces.t } [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/orgs/{org}/copilot-spaces"

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
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
