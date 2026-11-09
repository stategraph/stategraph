module Get_scan_history = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_scan_history.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

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
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/secret-scanning/scan-history"

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

module Create_push_protection_bypass = struct
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
        placeholder_id : string;
        reason : Githubc2_components.Secret_scanning_push_protection_bypass_reason.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_push_protection_bypass.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

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
      | `Forbidden
      | `Not_found
      | `Unprocessable_entity
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/secret-scanning/push-protection-bypasses"

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

module Update_repo_custom_pattern = struct
  module Parameters = struct
    type t = {
      owner : string;
      pattern_id : int;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Githubc2_components.Secret_scanning_custom_pattern_to_update.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_custom_pattern.t
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

    module Precondition_failed = struct
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Precondition_failed of Precondition_failed.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("412", Openapi.of_json_body (fun v -> `Precondition_failed v) Precondition_failed.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/secret-scanning/custom-patterns/{pattern_id}"

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
           ("pattern_id", Var (params.pattern_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Bulk_delete_repo_custom_patterns = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Patterns = struct
        type t = Githubc2_components.Secret_scanning_custom_pattern_to_delete.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Post_delete_action = struct
        let t_of_yojson = function
          | `String "delete_alerts" -> Ok `Delete_alerts
          | `String "resolve_alerts" -> Ok `Resolve_alerts
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Delete_alerts -> `String "delete_alerts"
          | `Resolve_alerts -> `String "resolve_alerts"

        type t =
          ([ `Delete_alerts
           | `Resolve_alerts
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        patterns : Patterns.t;
        post_delete_action : Post_delete_action.t; [@default `Delete_alerts]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

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

    module Precondition_failed = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Precondition_failed of Precondition_failed.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("412", Openapi.of_json_body (fun v -> `Precondition_failed v) Precondition_failed.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/secret-scanning/custom-patterns"

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
      `Delete
end

module Bulk_create_repo_custom_patterns = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Patterns = struct
        type t = Githubc2_components.Secret_scanning_custom_pattern_to_create.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { patterns : Patterns.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      module Primary = struct
        module Created_patterns = struct
          type t = Githubc2_components.Secret_scanning_custom_pattern.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = { created_patterns : Created_patterns.t option [@default None] }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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
      module Primary = struct
        module Validation_errors = struct
          module Additional = struct
            module Primary = struct
              module Errors = struct
                type t = Githubc2_components.Secret_scanning_custom_pattern_validation_error.t list
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = { errors : Errors.t option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Additional)
        end

        type t = {
          message : string option; [@default None]
          validation_errors : Validation_errors.t option; [@default None]
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
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/secret-scanning/custom-patterns"

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

module List_repo_custom_patterns = struct
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

    module Push_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"

      type t =
        ([ `Disabled
         | `Enabled
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "name" -> Ok `Name
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Name -> `String "name"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Name
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "published" -> Ok `Published
        | `String "unpublished" -> Ok `Unpublished
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Published -> `String "published"
        | `Unpublished -> `String "unpublished"

      type t =
        ([ `Published
         | `Unpublished
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      owner : string;
      push_protection : Push_protection.t option; [@default None]
      repo : string;
      sort : Sort.t; [@default `Created]
      state : State.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option
         (ud "push_protection" (fun value ->
              CCResult.to_opt (Parameters.Push_protection.t_of_yojson (`String value))))
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "before")
    /? option (string "after")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_custom_pattern.t list
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

  let url = "/repos/{owner}/{repo}/secret-scanning/custom-patterns"

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
           ("state", Var (params.state, Option (Enum State.t_to_yojson)));
           ( "push_protection",
             Var (params.push_protection, Option (Enum Push_protection.t_to_yojson)) );
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_locations_for_alert = struct
  module Parameters = struct
    type t = {
      alert_number : int;
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
    base_route /? option_default 1 (int "page") /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_location.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

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
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/secret-scanning/alerts/{alert_number}/locations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("alert_number", Var (params.alert_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_alert = struct
  module Parameters = struct
    type t = {
      alert_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Validity = struct
          let t_of_yojson = function
            | `String "active" -> Ok `Active
            | `String "inactive" -> Ok `Inactive
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Active -> `String "active"
            | `Inactive -> `String "inactive"

          type t =
            ([ `Active
             | `Inactive
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          assignee : string option; [@default None]
          resolution : Githubc2_components.Secret_scanning_alert_resolution.t option;
              [@default None]
          resolution_comment : string option; [@default None]
          state : Githubc2_components.Secret_scanning_alert_state.t;
          validity : Validity.t option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      module Primary = struct
        module Validity = struct
          let t_of_yojson = function
            | `String "active" -> Ok `Active
            | `String "inactive" -> Ok `Inactive
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Active -> `String "active"
            | `Inactive -> `String "inactive"

          type t =
            ([ `Active
             | `Inactive
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          assignee : string option; [@default None]
          resolution : Githubc2_components.Secret_scanning_alert_resolution.t option;
              [@default None]
          resolution_comment : string option; [@default None]
          state : Githubc2_components.Secret_scanning_alert_state.t option; [@default None]
          validity : Validity.t option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V2 = struct
      module Primary = struct
        module Validity = struct
          let t_of_yojson = function
            | `String "active" -> Ok `Active
            | `String "inactive" -> Ok `Inactive
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Active -> `String "active"
            | `Inactive -> `String "inactive"

          type t =
            ([ `Active
             | `Inactive
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          assignee : string option; [@default None]
          resolution : Githubc2_components.Secret_scanning_alert_resolution.t option;
              [@default None]
          resolution_comment : string option; [@default None]
          state : Githubc2_components.Secret_scanning_alert_state.t option; [@default None]
          validity : Validity.t option; [@default None]
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
      Json_schema.any_of
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

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_alert_with_metadata.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

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
      | `Bad_request
      | `Forbidden
      | `Not_found
      | `Unprocessable_entity
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/secret-scanning/alerts/{alert_number}"

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
           ("alert_number", Var (params.alert_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Get_alert = struct
  module Parameters = struct
    type t = {
      alert_number : int;
      hide_secret : bool; [@default false]
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default false (bool "hide_secret")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_alert_with_metadata.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end
    module Not_found = struct end

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
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/secret-scanning/alerts/{alert_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("alert_number", Var (params.alert_number, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("hide_secret", Var (params.hide_secret, Bool)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_alerts_for_repo = struct
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

    module State = struct
      let t_of_yojson = function
        | `String "open" -> Ok `Open
        | `String "resolved" -> Ok `Resolved
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Open -> `String "open"
        | `Resolved -> `String "resolved"

      type t =
        ([ `Open
         | `Resolved
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      assignee : string option; [@default None]
      before : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      exclude_providers : string option; [@default None]
      exclude_secret_types : string option; [@default None]
      hide_secret : bool; [@default false]
      included_metadata : string option; [@default None]
      is_bypassed : bool option; [@default None]
      is_multi_repo : bool; [@default false]
      is_publicly_leaked : bool; [@default false]
      owner : string;
      owner_email_hash : string option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 30]
      providers : string option; [@default None]
      repo : string;
      resolution : string option; [@default None]
      secret_type : string option; [@default None]
      sort : Sort.t; [@default `Created]
      state : State.t option; [@default None]
      validity : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option (string "secret_type")
    /? option (string "exclude_secret_types")
    /? option (string "exclude_providers")
    /? option (string "providers")
    /? option (string "resolution")
    /? option (string "assignee")
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")
    /? option (string "validity")
    /? option_default false (bool "is_publicly_leaked")
    /? option_default false (bool "is_multi_repo")
    /? option_default false (bool "hide_secret")
    /? option (bool "is_bypassed")
    /? option (string "included_metadata")
    /? option (string "owner_email_hash")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_alert.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

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
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/secret-scanning/alerts"

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
           ("state", Var (params.state, Option (Enum State.t_to_yojson)));
           ("secret_type", Var (params.secret_type, Option String));
           ("exclude_secret_types", Var (params.exclude_secret_types, Option String));
           ("exclude_providers", Var (params.exclude_providers, Option String));
           ("providers", Var (params.providers, Option String));
           ("resolution", Var (params.resolution, Option String));
           ("assignee", Var (params.assignee, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("validity", Var (params.validity, Option String));
           ("is_publicly_leaked", Var (params.is_publicly_leaked, Bool));
           ("is_multi_repo", Var (params.is_multi_repo, Bool));
           ("hide_secret", Var (params.hide_secret, Bool));
           ("is_bypassed", Var (params.is_bypassed, Option Bool));
           ("included_metadata", Var (params.included_metadata, Option String));
           ("owner_email_hash", Var (params.owner_email_hash, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_org_pattern_configs = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Custom_pattern_settings = struct
        module Items = struct
          module Primary = struct
            module Push_protection_setting = struct
              let t_of_yojson = function
                | `String "disabled" -> Ok `Disabled
                | `String "enabled" -> Ok `Enabled
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `Disabled -> `String "disabled"
                | `Enabled -> `String "enabled"

              type t =
                ([ `Disabled
                 | `Enabled
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              custom_pattern_version : string option; [@default None]
              push_protection_setting : Push_protection_setting.t option; [@default None]
              token_type : string option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Provider_pattern_settings = struct
        module Items = struct
          module Primary = struct
            module Push_protection_setting = struct
              let t_of_yojson = function
                | `String "disabled" -> Ok `Disabled
                | `String "enabled" -> Ok `Enabled
                | `String "not-set" -> Ok `Not_set
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `Disabled -> `String "disabled"
                | `Enabled -> `String "enabled"
                | `Not_set -> `String "not-set"

              type t =
                ([ `Disabled
                 | `Enabled
                 | `Not_set
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              push_protection_setting : Push_protection_setting.t option; [@default None]
              token_type : string option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        custom_pattern_settings : Custom_pattern_settings.t option; [@default None]
        pattern_config_version : string option; [@default None]
        provider_pattern_settings : Provider_pattern_settings.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      module Primary = struct
        type t = { pattern_config_version : string option [@default None] }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/secret-scanning/pattern-configurations"

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
      `Patch
end

module List_org_pattern_configs = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_pattern_configuration.t
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

  let url = "/orgs/{org}/secret-scanning/pattern-configurations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Update_org_custom_pattern = struct
  module Parameters = struct
    type t = {
      org : string;
      pattern_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Githubc2_components.Secret_scanning_custom_pattern_to_update.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_custom_pattern.t
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

    module Precondition_failed = struct
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
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Precondition_failed of Precondition_failed.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("412", Openapi.of_json_body (fun v -> `Precondition_failed v) Precondition_failed.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/secret-scanning/custom-patterns/{pattern_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("pattern_id", Var (params.pattern_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Bulk_delete_org_custom_patterns = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Patterns = struct
        type t = Githubc2_components.Secret_scanning_custom_pattern_to_delete.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Post_delete_action = struct
        let t_of_yojson = function
          | `String "delete_alerts" -> Ok `Delete_alerts
          | `String "resolve_alerts" -> Ok `Resolve_alerts
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Delete_alerts -> `String "delete_alerts"
          | `Resolve_alerts -> `String "resolve_alerts"

        type t =
          ([ `Delete_alerts
           | `Resolve_alerts
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        patterns : Patterns.t;
        post_delete_action : Post_delete_action.t; [@default `Delete_alerts]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

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

    module Precondition_failed = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Precondition_failed of Precondition_failed.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("412", Openapi.of_json_body (fun v -> `Precondition_failed v) Precondition_failed.of_yojson);
      ]
  end

  let url = "/orgs/{org}/secret-scanning/custom-patterns"

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
      `Delete
end

module Bulk_create_org_custom_patterns = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Patterns = struct
        type t = Githubc2_components.Secret_scanning_custom_pattern_to_create.t list
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { patterns : Patterns.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      module Primary = struct
        module Created_patterns = struct
          type t = Githubc2_components.Secret_scanning_custom_pattern.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = { created_patterns : Created_patterns.t option [@default None] }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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
      module Primary = struct
        module Validation_errors = struct
          module Additional = struct
            module Primary = struct
              module Errors = struct
                type t = Githubc2_components.Secret_scanning_custom_pattern_validation_error.t list
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = { errors : Errors.t option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Additional)
        end

        type t = {
          message : string option; [@default None]
          validation_errors : Validation_errors.t option; [@default None]
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
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/secret-scanning/custom-patterns"

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

module List_org_custom_patterns = struct
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

    module Push_protection = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"

      type t =
        ([ `Disabled
         | `Enabled
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "name" -> Ok `Name
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Name -> `String "name"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Name
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "published" -> Ok `Published
        | `String "unpublished" -> Ok `Unpublished
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Published -> `String "published"
        | `Unpublished -> `String "unpublished"

      type t =
        ([ `Published
         | `Unpublished
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      org : string;
      push_protection : Push_protection.t option; [@default None]
      sort : Sort.t; [@default `Created]
      state : State.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option
         (ud "push_protection" (fun value ->
              CCResult.to_opt (Parameters.Push_protection.t_of_yojson (`String value))))
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "before")
    /? option (string "after")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Secret_scanning_custom_pattern.t list
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

  let url = "/orgs/{org}/secret-scanning/custom-patterns"

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
           ("state", Var (params.state, Option (Enum State.t_to_yojson)));
           ( "push_protection",
             Var (params.push_protection, Option (Enum Push_protection.t_to_yojson)) );
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_alerts_for_org = struct
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

    module State = struct
      let t_of_yojson = function
        | `String "open" -> Ok `Open
        | `String "resolved" -> Ok `Resolved
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Open -> `String "open"
        | `Resolved -> `String "resolved"

      type t =
        ([ `Open
         | `Resolved
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      assignee : string option; [@default None]
      before : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      exclude_providers : string option; [@default None]
      exclude_secret_types : string option; [@default None]
      hide_secret : bool; [@default false]
      included_metadata : string option; [@default None]
      is_bypassed : bool option; [@default None]
      is_multi_repo : bool; [@default false]
      is_publicly_leaked : bool; [@default false]
      org : string;
      owner_email_hash : string option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 30]
      providers : string option; [@default None]
      resolution : string option; [@default None]
      secret_type : string option; [@default None]
      sort : Sort.t; [@default `Created]
      state : State.t option; [@default None]
      validity : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))
    /? option (string "secret_type")
    /? option (string "exclude_secret_types")
    /? option (string "exclude_providers")
    /? option (string "providers")
    /? option (string "resolution")
    /? option (string "assignee")
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")
    /? option (string "before")
    /? option (string "after")
    /? option (string "validity")
    /? option_default false (bool "is_publicly_leaked")
    /? option_default false (bool "is_multi_repo")
    /? option_default false (bool "hide_secret")
    /? option (bool "is_bypassed")
    /? option (string "included_metadata")
    /? option (string "owner_email_hash")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Organization_secret_scanning_alert.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
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
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/orgs/{org}/secret-scanning/alerts"

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
           ("state", Var (params.state, Option (Enum State.t_to_yojson)));
           ("secret_type", Var (params.secret_type, Option String));
           ("exclude_secret_types", Var (params.exclude_secret_types, Option String));
           ("exclude_providers", Var (params.exclude_providers, Option String));
           ("providers", Var (params.providers, Option String));
           ("resolution", Var (params.resolution, Option String));
           ("assignee", Var (params.assignee, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("validity", Var (params.validity, Option String));
           ("is_publicly_leaked", Var (params.is_publicly_leaked, Bool));
           ("is_multi_repo", Var (params.is_multi_repo, Bool));
           ("hide_secret", Var (params.hide_secret, Bool));
           ("is_bypassed", Var (params.is_bypassed, Option Bool));
           ("included_metadata", Var (params.included_metadata, Option String));
           ("owner_email_hash", Var (params.owner_email_hash, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
