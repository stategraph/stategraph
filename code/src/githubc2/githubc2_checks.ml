module List_suites_for_ref = struct
  module Parameters = struct
    type t = {
      app_id : int option; [@default None]
      check_name : string option; [@default None]
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
    / "check-suites"
    /? option (int "app_id")
    /? option (string "check_name")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Check_suites = struct
          type t = Githubc2_components.Check_suite.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          check_suites : Check_suites.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/commits/{ref}/check-suites"

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
         [
           ("app_id", Var (params.app_id, Option Int));
           ("check_name", Var (params.check_name, Option String));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_for_ref = struct
  module Parameters = struct
    module Filter = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "latest" -> Ok `Latest
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Latest -> `String "latest"

      type t =
        ([ `All
         | `Latest
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Status = struct
      let t_of_yojson = function
        | `String "completed" -> Ok `Completed
        | `String "in_progress" -> Ok `In_progress
        | `String "queued" -> Ok `Queued
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Completed -> `String "completed"
        | `In_progress -> `String "in_progress"
        | `Queued -> `String "queued"

      type t =
        ([ `Completed
         | `In_progress
         | `Queued
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      app_id : int option; [@default None]
      check_name : string option; [@default None]
      filter : Filter.t; [@default `Latest]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      ref_ : string; [@key "ref"]
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
    / "commits"
    /% Path.string
    / "check-runs"
    /? option (string "check_name")
    /? option
         (ud "status" (fun value -> CCResult.to_opt (Parameters.Status.t_of_yojson (`String value))))
    /? option_default
         `Latest
         (ud "filter" (fun value -> CCResult.to_opt (Parameters.Filter.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option (int "app_id")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Check_runs = struct
          type t = Githubc2_components.Check_run.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          check_runs : Check_runs.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/commits/{ref}/check-runs"

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
         [
           ("check_name", Var (params.check_name, Option String));
           ("status", Var (params.status, Option (Enum Status.t_to_yojson)));
           ("filter", Var (params.filter, Enum Filter.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("app_id", Var (params.app_id, Option Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Rerequest_suite = struct
  module Parameters = struct
    type t = {
      check_suite_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "check-suites" /% Path.int / "rerequest"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Empty_object.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/check-suites/{check_suite_id}/rerequest"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("check_suite_id", Var (params.check_suite_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_for_suite = struct
  module Parameters = struct
    module Filter = struct
      let t_of_yojson = function
        | `String "all" -> Ok `All
        | `String "latest" -> Ok `Latest
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `All -> `String "all"
        | `Latest -> `String "latest"

      type t =
        ([ `All
         | `Latest
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Status = struct
      let t_of_yojson = function
        | `String "completed" -> Ok `Completed
        | `String "in_progress" -> Ok `In_progress
        | `String "queued" -> Ok `Queued
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Completed -> `String "completed"
        | `In_progress -> `String "in_progress"
        | `Queued -> `String "queued"

      type t =
        ([ `Completed
         | `In_progress
         | `Queued
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      check_name : string option; [@default None]
      check_suite_id : int;
      filter : Filter.t; [@default `Latest]
      owner : string;
      page : int; [@default 1]
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
    / "check-suites"
    /% Path.int
    / "check-runs"
    /? option (string "check_name")
    /? option
         (ud "status" (fun value -> CCResult.to_opt (Parameters.Status.t_of_yojson (`String value))))
    /? option_default
         `Latest
         (ud "filter" (fun value -> CCResult.to_opt (Parameters.Filter.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Check_runs = struct
          type t = Githubc2_components.Check_run.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          check_runs : Check_runs.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/check-suites/{check_suite_id}/check-runs"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("check_suite_id", Var (params.check_suite_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("check_name", Var (params.check_name, Option String));
           ("status", Var (params.status, Option (Enum Status.t_to_yojson)));
           ("filter", Var (params.filter, Enum Filter.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_suite = struct
  module Parameters = struct
    type t = {
      check_suite_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "check-suites" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Check_suite.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/check-suites/{check_suite_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("check_suite_id", Var (params.check_suite_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Set_suites_preferences = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Auto_trigger_checks = struct
        module Items = struct
          module Primary = struct
            type t = {
              app_id : int;
              setting : bool; [@default true]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { auto_trigger_checks : Auto_trigger_checks.t option [@default None] }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "check-suites" / "preferences"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Check_suite_preference.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/check-suites/preferences"

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

module Create_suite = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = { head_sha : string }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "check-suites"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Check_suite.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Githubc2_components.Check_suite.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Created of Created.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/check-suites"

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

module Rerequest_run = struct
  module Parameters = struct
    type t = {
      check_run_id : int64;
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
    / "check-runs"
    /% Path.ud CCInt64.of_string
    / "rerequest"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Empty_object.t
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
      type t = Githubc2_components.Basic_error.t
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

  let url = "/repos/{owner}/{repo}/check-runs/{check_run_id}/rerequest"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("check_run_id", Var (params.check_run_id, Int64));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_annotations = struct
  module Parameters = struct
    type t = {
      check_run_id : int64;
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
    / "check-runs"
    /% Path.ud CCInt64.of_string
    / "annotations"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Check_annotation.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/check-runs/{check_run_id}/annotations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("check_run_id", Var (params.check_run_id, Int64));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update = struct
  module Parameters = struct
    type t = {
      check_run_id : int64;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Primary = struct
        module Actions = struct
          module Items = struct
            module Primary = struct
              type t = {
                description : string;
                identifier : string;
                label : string;
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Conclusion = struct
          let t_of_yojson = function
            | `String "action_required" -> Ok `Action_required
            | `String "cancelled" -> Ok `Cancelled
            | `String "failure" -> Ok `Failure
            | `String "neutral" -> Ok `Neutral
            | `String "skipped" -> Ok `Skipped
            | `String "stale" -> Ok `Stale
            | `String "success" -> Ok `Success
            | `String "timed_out" -> Ok `Timed_out
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Action_required -> `String "action_required"
            | `Cancelled -> `String "cancelled"
            | `Failure -> `String "failure"
            | `Neutral -> `String "neutral"
            | `Skipped -> `String "skipped"
            | `Stale -> `String "stale"
            | `Success -> `String "success"
            | `Timed_out -> `String "timed_out"

          type t =
            ([ `Action_required
             | `Cancelled
             | `Failure
             | `Neutral
             | `Skipped
             | `Stale
             | `Success
             | `Timed_out
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Output = struct
          module Primary = struct
            module Annotations = struct
              module Items = struct
                module Primary = struct
                  module Annotation_level = struct
                    let t_of_yojson = function
                      | `String "failure" -> Ok `Failure
                      | `String "notice" -> Ok `Notice
                      | `String "warning" -> Ok `Warning
                      | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                    let t_to_yojson = function
                      | `Failure -> `String "failure"
                      | `Notice -> `String "notice"
                      | `Warning -> `String "warning"

                    type t =
                      ([ `Failure
                       | `Notice
                       | `Warning
                       ]
                      [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  type t = {
                    annotation_level : Annotation_level.t;
                    end_column : int option; [@default None]
                    end_line : int;
                    message : string;
                    path : string;
                    raw_details : string option; [@default None]
                    start_column : int option; [@default None]
                    start_line : int;
                    title : string option; [@default None]
                  }
                  [@@deriving make, yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module Images = struct
              module Items = struct
                module Primary = struct
                  type t = {
                    alt : string;
                    caption : string option; [@default None]
                    image_url : string;
                  }
                  [@@deriving make, yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              annotations : Annotations.t option; [@default None]
              images : Images.t option; [@default None]
              summary : string;
              text : string option; [@default None]
              title : string option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Status = struct
          let t_of_yojson = function
            | `String "completed" -> Ok `Completed
            | `String "in_progress" -> Ok `In_progress
            | `String "pending" -> Ok `Pending
            | `String "queued" -> Ok `Queued
            | `String "requested" -> Ok `Requested
            | `String "waiting" -> Ok `Waiting
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Completed -> `String "completed"
            | `In_progress -> `String "in_progress"
            | `Pending -> `String "pending"
            | `Queued -> `String "queued"
            | `Requested -> `String "requested"
            | `Waiting -> `String "waiting"

          type t =
            ([ `Completed
             | `In_progress
             | `Pending
             | `Queued
             | `Requested
             | `Waiting
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          actions : Actions.t option; [@default None]
          completed_at : string option; [@default None]
          conclusion : Conclusion.t;
          details_url : string option; [@default None]
          external_id : string option; [@default None]
          name : string option; [@default None]
          output : Output.t option; [@default None]
          started_at : string option; [@default None]
          status : Status.t option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      module Primary = struct
        module Actions = struct
          module Items = struct
            module Primary = struct
              type t = {
                description : string;
                identifier : string;
                label : string;
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Conclusion = struct
          let t_of_yojson = function
            | `String "action_required" -> Ok `Action_required
            | `String "cancelled" -> Ok `Cancelled
            | `String "failure" -> Ok `Failure
            | `String "neutral" -> Ok `Neutral
            | `String "skipped" -> Ok `Skipped
            | `String "stale" -> Ok `Stale
            | `String "success" -> Ok `Success
            | `String "timed_out" -> Ok `Timed_out
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Action_required -> `String "action_required"
            | `Cancelled -> `String "cancelled"
            | `Failure -> `String "failure"
            | `Neutral -> `String "neutral"
            | `Skipped -> `String "skipped"
            | `Stale -> `String "stale"
            | `Success -> `String "success"
            | `Timed_out -> `String "timed_out"

          type t =
            ([ `Action_required
             | `Cancelled
             | `Failure
             | `Neutral
             | `Skipped
             | `Stale
             | `Success
             | `Timed_out
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Output = struct
          module Primary = struct
            module Annotations = struct
              module Items = struct
                module Primary = struct
                  module Annotation_level = struct
                    let t_of_yojson = function
                      | `String "failure" -> Ok `Failure
                      | `String "notice" -> Ok `Notice
                      | `String "warning" -> Ok `Warning
                      | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                    let t_to_yojson = function
                      | `Failure -> `String "failure"
                      | `Notice -> `String "notice"
                      | `Warning -> `String "warning"

                    type t =
                      ([ `Failure
                       | `Notice
                       | `Warning
                       ]
                      [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  type t = {
                    annotation_level : Annotation_level.t;
                    end_column : int option; [@default None]
                    end_line : int;
                    message : string;
                    path : string;
                    raw_details : string option; [@default None]
                    start_column : int option; [@default None]
                    start_line : int;
                    title : string option; [@default None]
                  }
                  [@@deriving make, yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module Images = struct
              module Items = struct
                module Primary = struct
                  type t = {
                    alt : string;
                    caption : string option; [@default None]
                    image_url : string;
                  }
                  [@@deriving make, yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              annotations : Annotations.t option; [@default None]
              images : Images.t option; [@default None]
              summary : string;
              text : string option; [@default None]
              title : string option; [@default None]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Status = struct
          let t_of_yojson = function
            | `String "completed" -> Ok `Completed
            | `String "in_progress" -> Ok `In_progress
            | `String "pending" -> Ok `Pending
            | `String "queued" -> Ok `Queued
            | `String "requested" -> Ok `Requested
            | `String "waiting" -> Ok `Waiting
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Completed -> `String "completed"
            | `In_progress -> `String "in_progress"
            | `Pending -> `String "pending"
            | `Queued -> `String "queued"
            | `Requested -> `String "requested"
            | `Waiting -> `String "waiting"

          type t =
            ([ `Completed
             | `In_progress
             | `Pending
             | `Queued
             | `Requested
             | `Waiting
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          actions : Actions.t option; [@default None]
          completed_at : string option; [@default None]
          conclusion : Conclusion.t option; [@default None]
          details_url : string option; [@default None]
          external_id : string option; [@default None]
          name : string option; [@default None]
          output : Output.t option; [@default None]
          started_at : string option; [@default None]
          status : Status.t option; [@default None]
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
    rel / "repos" /% Path.string /% Path.string / "check-runs" /% Path.ud CCInt64.of_string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Check_run.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/check-runs/{check_run_id}"

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
           ("check_run_id", Var (params.check_run_id, Int64));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Get = struct
  module Parameters = struct
    type t = {
      check_run_id : int64;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "check-runs" /% Path.ud CCInt64.of_string

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Check_run.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/check-runs/{check_run_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("check_run_id", Var (params.check_run_id, Int64));
         ])
      ~query_params:[]
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
    module V0 = struct
      module Primary = struct
        module Actions = struct
          module Items = struct
            module Primary = struct
              type t = {
                description : string;
                identifier : string;
                label : string;
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Conclusion = struct
          let t_of_yojson = function
            | `String "action_required" -> Ok `Action_required
            | `String "cancelled" -> Ok `Cancelled
            | `String "failure" -> Ok `Failure
            | `String "neutral" -> Ok `Neutral
            | `String "skipped" -> Ok `Skipped
            | `String "stale" -> Ok `Stale
            | `String "success" -> Ok `Success
            | `String "timed_out" -> Ok `Timed_out
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Action_required -> `String "action_required"
            | `Cancelled -> `String "cancelled"
            | `Failure -> `String "failure"
            | `Neutral -> `String "neutral"
            | `Skipped -> `String "skipped"
            | `Stale -> `String "stale"
            | `Success -> `String "success"
            | `Timed_out -> `String "timed_out"

          type t =
            ([ `Action_required
             | `Cancelled
             | `Failure
             | `Neutral
             | `Skipped
             | `Stale
             | `Success
             | `Timed_out
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Output = struct
          module Primary = struct
            module Annotations = struct
              module Items = struct
                module Primary = struct
                  module Annotation_level = struct
                    let t_of_yojson = function
                      | `String "failure" -> Ok `Failure
                      | `String "notice" -> Ok `Notice
                      | `String "warning" -> Ok `Warning
                      | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                    let t_to_yojson = function
                      | `Failure -> `String "failure"
                      | `Notice -> `String "notice"
                      | `Warning -> `String "warning"

                    type t =
                      ([ `Failure
                       | `Notice
                       | `Warning
                       ]
                      [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  type t = {
                    annotation_level : Annotation_level.t;
                    end_column : int option; [@default None]
                    end_line : int;
                    message : string;
                    path : string;
                    raw_details : string option; [@default None]
                    start_column : int option; [@default None]
                    start_line : int;
                    title : string option; [@default None]
                  }
                  [@@deriving make, yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module Images = struct
              module Items = struct
                module Primary = struct
                  type t = {
                    alt : string;
                    caption : string option; [@default None]
                    image_url : string;
                  }
                  [@@deriving make, yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              annotations : Annotations.t option; [@default None]
              images : Images.t option; [@default None]
              summary : string;
              text : string option; [@default None]
              title : string;
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Status = struct
          let t_of_yojson = function
            | `String "completed" -> Ok `Completed
            | `String "in_progress" -> Ok `In_progress
            | `String "pending" -> Ok `Pending
            | `String "queued" -> Ok `Queued
            | `String "requested" -> Ok `Requested
            | `String "waiting" -> Ok `Waiting
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Completed -> `String "completed"
            | `In_progress -> `String "in_progress"
            | `Pending -> `String "pending"
            | `Queued -> `String "queued"
            | `Requested -> `String "requested"
            | `Waiting -> `String "waiting"

          type t =
            ([ `Completed
             | `In_progress
             | `Pending
             | `Queued
             | `Requested
             | `Waiting
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          actions : Actions.t option; [@default None]
          completed_at : string option; [@default None]
          conclusion : Conclusion.t;
          details_url : string option; [@default None]
          external_id : string option; [@default None]
          head_sha : string;
          name : string;
          output : Output.t option; [@default None]
          started_at : string option; [@default None]
          status : Status.t; [@default `Queued]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module V1 = struct
      module Primary = struct
        module Actions = struct
          module Items = struct
            module Primary = struct
              type t = {
                description : string;
                identifier : string;
                label : string;
              }
              [@@deriving make, yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Conclusion = struct
          let t_of_yojson = function
            | `String "action_required" -> Ok `Action_required
            | `String "cancelled" -> Ok `Cancelled
            | `String "failure" -> Ok `Failure
            | `String "neutral" -> Ok `Neutral
            | `String "skipped" -> Ok `Skipped
            | `String "stale" -> Ok `Stale
            | `String "success" -> Ok `Success
            | `String "timed_out" -> Ok `Timed_out
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Action_required -> `String "action_required"
            | `Cancelled -> `String "cancelled"
            | `Failure -> `String "failure"
            | `Neutral -> `String "neutral"
            | `Skipped -> `String "skipped"
            | `Stale -> `String "stale"
            | `Success -> `String "success"
            | `Timed_out -> `String "timed_out"

          type t =
            ([ `Action_required
             | `Cancelled
             | `Failure
             | `Neutral
             | `Skipped
             | `Stale
             | `Success
             | `Timed_out
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        module Output = struct
          module Primary = struct
            module Annotations = struct
              module Items = struct
                module Primary = struct
                  module Annotation_level = struct
                    let t_of_yojson = function
                      | `String "failure" -> Ok `Failure
                      | `String "notice" -> Ok `Notice
                      | `String "warning" -> Ok `Warning
                      | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                    let t_to_yojson = function
                      | `Failure -> `String "failure"
                      | `Notice -> `String "notice"
                      | `Warning -> `String "warning"

                    type t =
                      ([ `Failure
                       | `Notice
                       | `Warning
                       ]
                      [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  type t = {
                    annotation_level : Annotation_level.t;
                    end_column : int option; [@default None]
                    end_line : int;
                    message : string;
                    path : string;
                    raw_details : string option; [@default None]
                    start_column : int option; [@default None]
                    start_line : int;
                    title : string option; [@default None]
                  }
                  [@@deriving make, yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module Images = struct
              module Items = struct
                module Primary = struct
                  type t = {
                    alt : string;
                    caption : string option; [@default None]
                    image_url : string;
                  }
                  [@@deriving make, yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              annotations : Annotations.t option; [@default None]
              images : Images.t option; [@default None]
              summary : string;
              text : string option; [@default None]
              title : string;
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Status = struct
          let t_of_yojson = function
            | `String "completed" -> Ok `Completed
            | `String "in_progress" -> Ok `In_progress
            | `String "pending" -> Ok `Pending
            | `String "queued" -> Ok `Queued
            | `String "requested" -> Ok `Requested
            | `String "waiting" -> Ok `Waiting
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Completed -> `String "completed"
            | `In_progress -> `String "in_progress"
            | `Pending -> `String "pending"
            | `Queued -> `String "queued"
            | `Requested -> `String "requested"
            | `Waiting -> `String "waiting"

          type t =
            ([ `Completed
             | `In_progress
             | `Pending
             | `Queued
             | `Requested
             | `Waiting
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = {
          actions : Actions.t option; [@default None]
          completed_at : string option; [@default None]
          conclusion : Conclusion.t option; [@default None]
          details_url : string option; [@default None]
          external_id : string option; [@default None]
          head_sha : string;
          name : string;
          output : Output.t option; [@default None]
          started_at : string option; [@default None]
          status : Status.t; [@default `Queued]
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

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "check-runs"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Check_run.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/check-runs"

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
