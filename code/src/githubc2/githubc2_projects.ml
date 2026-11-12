module List_view_items_for_user = struct
  module Parameters = struct
    module Fields = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        type t = string list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      fields : Fields.t option; [@default None]
      per_page : int; [@default 30]
      project_number : int;
      username : string;
      view_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "users"
    /% Path.string
    / "projectsV2"
    /% Path.int
    / "views"
    /% Path.int
    / "items"
    /? option
         (ud_array "fields" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Fields.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Fields.V1 v)
                    (CCOption.sequence_l (CCList.map CCOption.return values));
                ]))
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_item_with_content.t list
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

  let url = "/users/{username}/projectsV2/{project_number}/views/{view_number}/items"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("username", Var (params.username, String));
           ("view_number", Var (params.view_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ( "fields",
             match params.fields with
             | Some (Fields.V0 v) -> Var (v, String)
             | Some (Fields.V1 v) -> Var (v, Array String)
             | None -> Var ((), Null) );
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_item_for_user = struct
  module Parameters = struct
    type t = {
      item_id : int;
      project_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Fields = struct
        module Items = struct
          module Primary = struct
            module Value = struct
              module V0 = struct
                type t = string option [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              module V1 = struct
                type t = float option [@@deriving yojson { strict = false; meta = true }, show, eq]
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
              id : int;
              value : Value.t option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { fields : Fields.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "projectsV2" /% Path.int / "items" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_item_with_content.t
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
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/users/{username}/projectsV2/{project_number}/items/{item_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("username", Var (params.username, String));
           ("item_id", Var (params.item_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_item_for_user = struct
  module Parameters = struct
    type t = {
      item_id : int;
      project_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "projectsV2" /% Path.int / "items" /% Path.int

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

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/projectsV2/{project_number}/items/{item_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("username", Var (params.username, String));
           ("item_id", Var (params.item_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_user_item = struct
  module Parameters = struct
    module Fields = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        type t = string list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    type t = {
      fields : Fields.t option; [@default None]
      item_id : int;
      project_number : int;
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
    / "projectsV2"
    /% Path.int
    / "items"
    /% Path.int
    /? option
         (ud_array "fields" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Fields.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Fields.V1 v)
                    (CCOption.sequence_l (CCList.map CCOption.return values));
                ]))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_item_with_content.t
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/projectsV2/{project_number}/items/{item_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("username", Var (params.username, String));
           ("item_id", Var (params.item_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ( "fields",
             match params.fields with
             | Some (Fields.V0 v) -> Var (v, String)
             | Some (Fields.V1 v) -> Var (v, Array String)
             | None -> Var ((), Null) );
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Add_item_for_user = struct
  module Parameters = struct
    type t = {
      project_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Type = struct
        let t_of_yojson = function
          | `String "Issue" -> Ok `Issue
          | `String "PullRequest" -> Ok `PullRequest
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Issue -> `String "Issue"
          | `PullRequest -> `String "PullRequest"

        type t =
          ([ `Issue
           | `PullRequest
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        id : int;
        number : int option; [@default None]
        owner : string option; [@default None]
        repo : string option; [@default None]
        type_ : Type.t; [@key "type"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    module V1 = struct
      module Type = struct
        let t_of_yojson = function
          | `String "Issue" -> Ok `Issue
          | `String "PullRequest" -> Ok `PullRequest
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Issue -> `String "Issue"
          | `PullRequest -> `String "PullRequest"

        type t =
          ([ `Issue
           | `PullRequest
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        id : int option; [@default None]
        number : int;
        owner : string;
        repo : string;
        type_ : Type.t; [@key "type"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
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
    rel / "users" /% Path.string / "projectsV2" /% Path.int / "items"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Projects_v2_item_simple.t
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

    type t =
      [ `Created of Created.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/projectsV2/{project_number}/items"

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
           ("project_number", Var (params.project_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_items_for_user = struct
  module Parameters = struct
    module Fields = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        type t = string list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      fields : Fields.t option; [@default None]
      per_page : int; [@default 30]
      project_number : int;
      q : string option; [@default None]
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
    / "projectsV2"
    /% Path.int
    / "items"
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")
    /? option (string "q")
    /? option
         (ud_array "fields" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Fields.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Fields.V1 v)
                    (CCOption.sequence_l (CCList.map CCOption.return values));
                ]))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_item_with_content.t list
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/projectsV2/{project_number}/items"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("username", Var (params.username, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
           ("q", Var (params.q, Option String));
           ( "fields",
             match params.fields with
             | Some (Fields.V0 v) -> Var (v, String)
             | Some (Fields.V1 v) -> Var (v, Array String)
             | None -> Var ((), Null) );
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_field_for_user = struct
  module Parameters = struct
    type t = {
      field_id : int;
      project_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "projectsV2" /% Path.int / "fields" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_field.t
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/projectsV2/{project_number}/fields/{field_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("field_id", Var (params.field_id, Int));
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Add_field_for_user = struct
  module Parameters = struct
    type t = {
      project_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Data_type = struct
          let t_of_yojson = function
            | `String "date" -> Ok `Date
            | `String "number" -> Ok `Number
            | `String "text" -> Ok `Text
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Date -> `String "date"
            | `Number -> `String "number"
            | `Text -> `String "text"

          type t =
            ([ `Date
             | `Number
             | `Text
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          data_type : Data_type.t;
          name : string;
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      module Primary = struct
        module Data_type = struct
          let t_of_yojson = function
            | `String "single_select" -> Ok `Single_select
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Single_select -> `String "single_select"

          type t = ([ `Single_select ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Single_select_options = struct
          type t = Githubc2_components.Projects_v2_field_single_select_option.t list
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          data_type : Data_type.t;
          name : string;
          single_select_options : Single_select_options.t;
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V2 = struct
      module Primary = struct
        module Data_type = struct
          let t_of_yojson = function
            | `String "iteration" -> Ok `Iteration
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Iteration -> `String "iteration"

          type t = ([ `Iteration ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          data_type : Data_type.t;
          iteration_configuration : Githubc2_components.Projects_v2_field_iteration_configuration.t;
          name : string;
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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
    rel / "users" /% Path.string / "projectsV2" /% Path.int / "fields"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Projects_v2_field.t
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
      [ `Created of Created.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/users/{username}/projectsV2/{project_number}/fields"

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
           ("project_number", Var (params.project_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_fields_for_user = struct
  module Parameters = struct
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      per_page : int; [@default 30]
      project_number : int;
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
    / "projectsV2"
    /% Path.int
    / "fields"
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_field.t list
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/projectsV2/{project_number}/fields"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("username", Var (params.username, String));
         ])
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

module Get_for_user = struct
  module Parameters = struct
    type t = {
      project_number : int;
      username : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "projectsV2" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2.t
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/projectsV2/{project_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("username", Var (params.username, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_for_user = struct
  module Parameters = struct
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      per_page : int; [@default 30]
      q : string option; [@default None]
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
    / "projectsV2"
    /? option (string "q")
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2.t list
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/users/{username}/projectsV2"

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
           ("q", Var (params.q, Option String));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_view_for_user = struct
  module Parameters = struct
    type t = {
      project_number : int;
      user_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Group_by = struct
      type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Layout = struct
      let t_of_yojson = function
        | `String "board" -> Ok `Board
        | `String "roadmap" -> Ok `Roadmap
        | `String "table" -> Ok `Table
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Board -> `String "board"
        | `Roadmap -> `String "roadmap"
        | `Table -> `String "table"

      type t =
        ([ `Board
         | `Roadmap
         | `Table
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Sort_by = struct
      module Items = struct
        module Items = struct
          module V0 = struct
            type t = int [@@deriving yojson { strict = false; meta = true }, show, eq]
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

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Vertical_group_by = struct
      type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Visible_fields = struct
      type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      filter : string option; [@default None]
      group_by : Group_by.t option; [@default None]
      layout : Layout.t;
      name : string;
      sort_by : Sort_by.t option; [@default None]
      vertical_group_by : Vertical_group_by.t option; [@default None]
      visible_fields : Visible_fields.t option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "users" /% Path.string / "projectsV2" /% Path.int / "views"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Projects_v2_view.t
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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/users/{user_id}/projectsV2/{project_number}/views"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("user_id", Var (params.user_id, String));
           ("project_number", Var (params.project_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Create_draft_item_for_authenticated_user = struct
  module Parameters = struct
    type t = {
      project_number : int;
      user_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        body : string option; [@default None]
        title : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "user" /% Path.string / "projectsV2" /% Path.int / "drafts"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Projects_v2_item_simple.t
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

    type t =
      [ `Created of Created.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/user/{user_id}/projectsV2/{project_number}/drafts"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("user_id", Var (params.user_id, String));
           ("project_number", Var (params.project_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_view_items_for_org = struct
  module Parameters = struct
    module Fields = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        type t = string list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      fields : Fields.t option; [@default None]
      org : string;
      per_page : int; [@default 30]
      project_number : int;
      view_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "projectsV2"
    /% Path.int
    / "views"
    /% Path.int
    / "items"
    /? option
         (ud_array "fields" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Fields.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Fields.V1 v)
                    (CCOption.sequence_l (CCList.map CCOption.return values));
                ]))
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_item_with_content.t list
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

  let url = "/orgs/{org}/projectsV2/{project_number}/views/{view_number}/items"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("org", Var (params.org, String));
           ("view_number", Var (params.view_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ( "fields",
             match params.fields with
             | Some (Fields.V0 v) -> Var (v, String)
             | Some (Fields.V1 v) -> Var (v, Array String)
             | None -> Var ((), Null) );
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_view_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Group_by = struct
      type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Layout = struct
      let t_of_yojson = function
        | `String "board" -> Ok `Board
        | `String "roadmap" -> Ok `Roadmap
        | `String "table" -> Ok `Table
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Board -> `String "board"
        | `Roadmap -> `String "roadmap"
        | `Table -> `String "table"

      type t =
        ([ `Board
         | `Roadmap
         | `Table
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Sort_by = struct
      module Items = struct
        module Items = struct
          module V0 = struct
            type t = int [@@deriving yojson { strict = false; meta = true }, show, eq]
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

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Vertical_group_by = struct
      type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Visible_fields = struct
      type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      filter : string option; [@default None]
      group_by : Group_by.t option; [@default None]
      layout : Layout.t;
      name : string;
      sort_by : Sort_by.t option; [@default None]
      vertical_group_by : Vertical_group_by.t option; [@default None]
      visible_fields : Visible_fields.t option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "projectsV2" /% Path.int / "views"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Projects_v2_view.t
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

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/views"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("project_number", Var (params.project_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Update_item_for_org = struct
  module Parameters = struct
    type t = {
      item_id : int;
      org : string;
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Fields = struct
        module Items = struct
          module Primary = struct
            module Value = struct
              module V0 = struct
                type t = string option [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              module V1 = struct
                type t = float option [@@deriving yojson { strict = false; meta = true }, show, eq]
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
              id : int;
              value : Value.t option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { fields : Fields.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "projectsV2" /% Path.int / "items" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_item_with_content.t
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
      [ `OK of OK.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/items/{item_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("org", Var (params.org, String));
           ("item_id", Var (params.item_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_item_for_org = struct
  module Parameters = struct
    type t = {
      item_id : int;
      org : string;
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "projectsV2" /% Path.int / "items" /% Path.int

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

    type t =
      [ `No_content
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/items/{item_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("org", Var (params.org, String));
           ("item_id", Var (params.item_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_org_item = struct
  module Parameters = struct
    module Fields = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        type t = string list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    type t = {
      fields : Fields.t option; [@default None]
      item_id : int;
      org : string;
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "projectsV2"
    /% Path.int
    / "items"
    /% Path.int
    /? option
         (ud_array "fields" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Fields.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Fields.V1 v)
                    (CCOption.sequence_l (CCList.map CCOption.return values));
                ]))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_item_with_content.t
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/items/{item_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("org", Var (params.org, String));
           ("item_id", Var (params.item_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ( "fields",
             match params.fields with
             | Some (Fields.V0 v) -> Var (v, String)
             | Some (Fields.V1 v) -> Var (v, Array String)
             | None -> Var ((), Null) );
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Add_item_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Type = struct
        let t_of_yojson = function
          | `String "Issue" -> Ok `Issue
          | `String "PullRequest" -> Ok `PullRequest
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Issue -> `String "Issue"
          | `PullRequest -> `String "PullRequest"

        type t =
          ([ `Issue
           | `PullRequest
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        id : int;
        number : int option; [@default None]
        owner : string option; [@default None]
        repo : string option; [@default None]
        type_ : Type.t; [@key "type"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    module V1 = struct
      module Type = struct
        let t_of_yojson = function
          | `String "Issue" -> Ok `Issue
          | `String "PullRequest" -> Ok `PullRequest
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Issue -> `String "Issue"
          | `PullRequest -> `String "PullRequest"

        type t =
          ([ `Issue
           | `PullRequest
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        id : int option; [@default None]
        number : int;
        owner : string;
        repo : string;
        type_ : Type.t; [@key "type"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
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
    rel / "orgs" /% Path.string / "projectsV2" /% Path.int / "items"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Projects_v2_item_simple.t
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

    type t =
      [ `Created of Created.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/items"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("project_number", Var (params.project_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_items_for_org = struct
  module Parameters = struct
    module Fields = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        type t = string list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      fields : Fields.t option; [@default None]
      org : string;
      per_page : int; [@default 30]
      project_number : int;
      q : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "projectsV2"
    /% Path.int
    / "items"
    /? option (string "q")
    /? option
         (ud_array "fields" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Fields.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Fields.V1 v)
                    (CCOption.sequence_l (CCList.map CCOption.return values));
                ]))
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_item_with_content.t list
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/items"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("project_number", Var (params.project_number, Int)); ("org", Var (params.org, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("q", Var (params.q, Option String));
           ( "fields",
             match params.fields with
             | Some (Fields.V0 v) -> Var (v, String)
             | Some (Fields.V1 v) -> Var (v, Array String)
             | None -> Var ((), Null) );
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_field_for_org = struct
  module Parameters = struct
    type t = {
      field_id : int;
      org : string;
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "projectsV2" /% Path.int / "fields" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_field.t
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/fields/{field_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("project_number", Var (params.project_number, Int));
           ("field_id", Var (params.field_id, Int));
           ("org", Var (params.org, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Add_field_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        type t = { issue_field_id : int }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      module Primary = struct
        module Data_type = struct
          let t_of_yojson = function
            | `String "date" -> Ok `Date
            | `String "number" -> Ok `Number
            | `String "text" -> Ok `Text
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Date -> `String "date"
            | `Number -> `String "number"
            | `Text -> `String "text"

          type t =
            ([ `Date
             | `Number
             | `Text
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          data_type : Data_type.t;
          name : string;
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V2 = struct
      module Primary = struct
        module Data_type = struct
          let t_of_yojson = function
            | `String "single_select" -> Ok `Single_select
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Single_select -> `String "single_select"

          type t = ([ `Single_select ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Single_select_options = struct
          type t = Githubc2_components.Projects_v2_field_single_select_option.t list
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          data_type : Data_type.t;
          name : string;
          single_select_options : Single_select_options.t;
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V3 = struct
      module Primary = struct
        module Data_type = struct
          let t_of_yojson = function
            | `String "iteration" -> Ok `Iteration
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Iteration -> `String "iteration"

          type t = ([ `Iteration ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          data_type : Data_type.t;
          iteration_configuration : Githubc2_components.Projects_v2_field_iteration_configuration.t;
          name : string;
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
    [@@deriving show, eq]

    let of_yojson =
      Json_schema.one_of
        (let open CCResult in
         [
           (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
           (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
           (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
           (fun v -> map (fun v -> V3 v) (V3.of_yojson v));
         ])

    let to_yojson = function
      | V0 v -> V0.to_yojson v
      | V1 v -> V1.to_yojson v
      | V2 v -> V2.to_yojson v
      | V3 v -> V3.to_yojson v
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "projectsV2" /% Path.int / "fields"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Projects_v2_field.t
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
      [ `Created of Created.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/fields"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("project_number", Var (params.project_number, Int)); ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_fields_for_org = struct
  module Parameters = struct
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      org : string;
      per_page : int; [@default 30]
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "projectsV2"
    /% Path.int
    / "fields"
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2_field.t list
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/fields"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("project_number", Var (params.project_number, Int)); ("org", Var (params.org, String)) ])
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

module Create_draft_item_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        body : string option; [@default None]
        title : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "projectsV2" /% Path.int / "drafts"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Projects_v2_item_simple.t
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

    type t =
      [ `Created of Created.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}/drafts"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("project_number", Var (params.project_number, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      project_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "projectsV2" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2.t
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2/{project_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("project_number", Var (params.project_number, Int)); ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_for_org = struct
  module Parameters = struct
    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      org : string;
      per_page : int; [@default 30]
      q : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "projectsV2"
    /? option (string "q")
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Projects_v2.t list
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/orgs/{org}/projectsV2"

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
           ("q", Var (params.q, Option String));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
