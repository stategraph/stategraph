module GetApiV4ProjectsIdPipelinesPipelineIdVariables = struct
  module Parameters = struct
    type t = {
      id : string;
      pipeline_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "pipelines" /% Path.int / "variables"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}/variables"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPipelinesPipelineIdTestReportSummary = struct
  module Parameters = struct
    type t = {
      id : string;
      pipeline_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "pipelines" /% Path.int / "test_report_summary"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}/test_report_summary"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPipelinesPipelineIdTestReport = struct
  module Parameters = struct
    type t = {
      id : string;
      pipeline_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "pipelines" /% Path.int / "test_report"

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}/test_report"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdPipelinesPipelineIdRetry = struct
  module Parameters = struct
    type t = {
      id : string;
      pipeline_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "pipelines" /% Path.int / "retry"

  module Responses = struct
    module Created = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}/retry"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PutApiV4ProjectsIdPipelinesPipelineIdMetadata = struct
  module Parameters = struct
    type t = {
      id : string;
      pipeline_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdPipelinesPipelineIdMetadata.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "pipelines" /% Path.int / "metadata"

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}/metadata"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdPipelinesPipelineIdJobs = struct
  module Parameters = struct
    module Scope = struct
      let t_of_yojson = function
        | `String "canceled" -> Ok `Canceled
        | `String "canceling" -> Ok `Canceling
        | `String "created" -> Ok `Created
        | `String "failed" -> Ok `Failed
        | `String "manual" -> Ok `Manual
        | `String "pending" -> Ok `Pending
        | `String "preparing" -> Ok `Preparing
        | `String "running" -> Ok `Running
        | `String "scheduled" -> Ok `Scheduled
        | `String "skipped" -> Ok `Skipped
        | `String "success" -> Ok `Success
        | `String "waiting_for_callback" -> Ok `Waiting_for_callback
        | `String "waiting_for_resource" -> Ok `Waiting_for_resource
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Canceled -> `String "canceled"
        | `Canceling -> `String "canceling"
        | `Created -> `String "created"
        | `Failed -> `String "failed"
        | `Manual -> `String "manual"
        | `Pending -> `String "pending"
        | `Preparing -> `String "preparing"
        | `Running -> `String "running"
        | `Scheduled -> `String "scheduled"
        | `Skipped -> `String "skipped"
        | `Success -> `String "success"
        | `Waiting_for_callback -> `String "waiting_for_callback"
        | `Waiting_for_resource -> `String "waiting_for_resource"

      type t =
        ([ `Canceled
         | `Canceling
         | `Created
         | `Failed
         | `Manual
         | `Pending
         | `Preparing
         | `Running
         | `Scheduled
         | `Skipped
         | `Success
         | `Waiting_for_callback
         | `Waiting_for_resource
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      id : string;
      include_retried : bool; [@default false]
      page : int; [@default 1]
      per_page : int; [@default 20]
      pipeline_id : int;
      scope : Scope.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "pipelines"
    /% Path.int
    / "jobs"
    /? option_default false (bool "include_retried")
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}/jobs"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("include_retried", Var (params.include_retried, Bool));
           ("scope", Var (params.scope, Option (Enum Scope.t_to_yojson)));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdPipelinesPipelineIdCancel = struct
  module Parameters = struct
    type t = {
      id : string;
      pipeline_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "pipelines" /% Path.int / "cancel"

  module Responses = struct
    module Created = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}/cancel"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdPipelinesPipelineIdBridges = struct
  module Parameters = struct
    module Scope = struct
      let t_of_yojson = function
        | `String "canceled" -> Ok `Canceled
        | `String "canceling" -> Ok `Canceling
        | `String "created" -> Ok `Created
        | `String "failed" -> Ok `Failed
        | `String "manual" -> Ok `Manual
        | `String "pending" -> Ok `Pending
        | `String "preparing" -> Ok `Preparing
        | `String "running" -> Ok `Running
        | `String "scheduled" -> Ok `Scheduled
        | `String "skipped" -> Ok `Skipped
        | `String "success" -> Ok `Success
        | `String "waiting_for_callback" -> Ok `Waiting_for_callback
        | `String "waiting_for_resource" -> Ok `Waiting_for_resource
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Canceled -> `String "canceled"
        | `Canceling -> `String "canceling"
        | `Created -> `String "created"
        | `Failed -> `String "failed"
        | `Manual -> `String "manual"
        | `Pending -> `String "pending"
        | `Preparing -> `String "preparing"
        | `Running -> `String "running"
        | `Scheduled -> `String "scheduled"
        | `Skipped -> `String "skipped"
        | `Success -> `String "success"
        | `Waiting_for_callback -> `String "waiting_for_callback"
        | `Waiting_for_resource -> `String "waiting_for_resource"

      type t =
        ([ `Canceled
         | `Canceling
         | `Created
         | `Failed
         | `Manual
         | `Pending
         | `Preparing
         | `Running
         | `Scheduled
         | `Skipped
         | `Success
         | `Waiting_for_callback
         | `Waiting_for_resource
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      pipeline_id : int;
      scope : Scope.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "pipelines"
    /% Path.int
    / "bridges"
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}/bridges"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("scope", Var (params.scope, Option (Enum Scope.t_to_yojson)));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4ProjectsIdPipelinesPipelineId = struct
  module Parameters = struct
    type t = {
      id : string;
      pipeline_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "pipelines" /% Path.int

  module Responses = struct
    module No_content = struct end
    module Forbidden = struct end

    type t =
      [ `No_content
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content); ("403", fun _ -> Ok `Forbidden) ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module GetApiV4ProjectsIdPipelinesPipelineId = struct
  module Parameters = struct
    type t = {
      id : string;
      pipeline_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "pipelines" /% Path.int

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/{pipeline_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("pipeline_id", Var (params.pipeline_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPipelinesLatest = struct
  module Parameters = struct
    type t = {
      id : string;
      ref_ : string option; [@default None] [@key "ref"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "pipelines" / "latest" /? option (string "ref")

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines/latest"

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
         [ ("ref", Var (params.ref_, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdPipelines = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "id" -> Ok `Id
        | `String "ref" -> Ok `Ref
        | `String "status" -> Ok `Status
        | `String "updated_at" -> Ok `Updated_at
        | `String "user_id" -> Ok `User_id
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Id -> `String "id"
        | `Ref -> `String "ref"
        | `Status -> `String "status"
        | `Updated_at -> `String "updated_at"
        | `User_id -> `String "user_id"

      type t =
        ([ `Id
         | `Ref
         | `Status
         | `Updated_at
         | `User_id
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Scope = struct
      let t_of_yojson = function
        | `String "branches" -> Ok `Branches
        | `String "finished" -> Ok `Finished
        | `String "pending" -> Ok `Pending
        | `String "running" -> Ok `Running
        | `String "tags" -> Ok `Tags
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Branches -> `String "branches"
        | `Finished -> `String "finished"
        | `Pending -> `String "pending"
        | `Running -> `String "running"
        | `Tags -> `String "tags"

      type t =
        ([ `Branches
         | `Finished
         | `Pending
         | `Running
         | `Tags
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

    module Source = struct
      let t_of_yojson = function
        | `String "api" -> Ok `Api
        | `String "chat" -> Ok `Chat
        | `String "container_registry_push" -> Ok `Container_registry_push
        | `String "duo_workflow" -> Ok `Duo_workflow
        | `String "external" -> Ok `External
        | `String "external_pull_request_event" -> Ok `External_pull_request_event
        | `String "merge_request_event" -> Ok `Merge_request_event
        | `String "ondemand_dast_scan" -> Ok `Ondemand_dast_scan
        | `String "ondemand_dast_validation" -> Ok `Ondemand_dast_validation
        | `String "parent_pipeline" -> Ok `Parent_pipeline
        | `String "pipeline" -> Ok `Pipeline
        | `String "pipeline_execution_policy_schedule" -> Ok `Pipeline_execution_policy_schedule
        | `String "push" -> Ok `Push
        | `String "schedule" -> Ok `Schedule
        | `String "security_orchestration_policy" -> Ok `Security_orchestration_policy
        | `String "trigger" -> Ok `Trigger
        | `String "unknown" -> Ok `Unknown
        | `String "web" -> Ok `Web
        | `String "webide" -> Ok `Webide
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Api -> `String "api"
        | `Chat -> `String "chat"
        | `Container_registry_push -> `String "container_registry_push"
        | `Duo_workflow -> `String "duo_workflow"
        | `External -> `String "external"
        | `External_pull_request_event -> `String "external_pull_request_event"
        | `Merge_request_event -> `String "merge_request_event"
        | `Ondemand_dast_scan -> `String "ondemand_dast_scan"
        | `Ondemand_dast_validation -> `String "ondemand_dast_validation"
        | `Parent_pipeline -> `String "parent_pipeline"
        | `Pipeline -> `String "pipeline"
        | `Pipeline_execution_policy_schedule -> `String "pipeline_execution_policy_schedule"
        | `Push -> `String "push"
        | `Schedule -> `String "schedule"
        | `Security_orchestration_policy -> `String "security_orchestration_policy"
        | `Trigger -> `String "trigger"
        | `Unknown -> `String "unknown"
        | `Web -> `String "web"
        | `Webide -> `String "webide"

      type t =
        ([ `Api
         | `Chat
         | `Container_registry_push
         | `Duo_workflow
         | `External
         | `External_pull_request_event
         | `Merge_request_event
         | `Ondemand_dast_scan
         | `Ondemand_dast_validation
         | `Parent_pipeline
         | `Pipeline
         | `Pipeline_execution_policy_schedule
         | `Push
         | `Schedule
         | `Security_orchestration_policy
         | `Trigger
         | `Unknown
         | `Web
         | `Webide
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Status = struct
      let t_of_yojson = function
        | `String "canceled" -> Ok `Canceled
        | `String "canceling" -> Ok `Canceling
        | `String "created" -> Ok `Created
        | `String "failed" -> Ok `Failed
        | `String "manual" -> Ok `Manual
        | `String "pending" -> Ok `Pending
        | `String "preparing" -> Ok `Preparing
        | `String "running" -> Ok `Running
        | `String "scheduled" -> Ok `Scheduled
        | `String "skipped" -> Ok `Skipped
        | `String "success" -> Ok `Success
        | `String "waiting_for_callback" -> Ok `Waiting_for_callback
        | `String "waiting_for_resource" -> Ok `Waiting_for_resource
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Canceled -> `String "canceled"
        | `Canceling -> `String "canceling"
        | `Created -> `String "created"
        | `Failed -> `String "failed"
        | `Manual -> `String "manual"
        | `Pending -> `String "pending"
        | `Preparing -> `String "preparing"
        | `Running -> `String "running"
        | `Scheduled -> `String "scheduled"
        | `Skipped -> `String "skipped"
        | `Success -> `String "success"
        | `Waiting_for_callback -> `String "waiting_for_callback"
        | `Waiting_for_resource -> `String "waiting_for_resource"

      type t =
        ([ `Canceled
         | `Canceling
         | `Created
         | `Failed
         | `Manual
         | `Pending
         | `Preparing
         | `Running
         | `Scheduled
         | `Skipped
         | `Success
         | `Waiting_for_callback
         | `Waiting_for_resource
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      id : string;
      name : string option; [@default None]
      order_by : Order_by.t; [@default `Id]
      page : int; [@default 1]
      per_page : int; [@default 20]
      ref_ : string option; [@default None] [@key "ref"]
      scope : Scope.t option; [@default None]
      sha : string option; [@default None]
      sort : Sort.t; [@default `Desc]
      source : Source.t option; [@default None]
      status : Status.t option; [@default None]
      updated_after : string option; [@default None]
      updated_before : string option; [@default None]
      username : string option; [@default None]
      yaml_errors : bool option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "pipelines"
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option
         (ud "status" (fun value -> CCResult.to_opt (Parameters.Status.t_of_yojson (`String value))))
    /? option (string "ref")
    /? option (string "sha")
    /? option (bool "yaml_errors")
    /? option (string "username")
    /? option (string "updated_before")
    /? option (string "updated_after")
    /? option_default
         `Id
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option
         (ud "source" (fun value -> CCResult.to_opt (Parameters.Source.t_of_yojson (`String value))))
    /? option (string "name")

  module Responses = struct
    module OK = struct
      type t = Gitlabc_components.API_Entities_Ci_PipelineBasic.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end
    module Forbidden = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v4/projects/{id}/pipelines"

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
           ("scope", Var (params.scope, Option (Enum Scope.t_to_yojson)));
           ("status", Var (params.status, Option (Enum Status.t_to_yojson)));
           ("ref", Var (params.ref_, Option String));
           ("sha", Var (params.sha, Option String));
           ("yaml_errors", Var (params.yaml_errors, Option Bool));
           ("username", Var (params.username, Option String));
           ("updated_before", Var (params.updated_before, Option String));
           ("updated_after", Var (params.updated_after, Option String));
           ("order_by", Var (params.order_by, Enum Order_by.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("source", Var (params.source, Option (Enum Source.t_to_yojson)));
           ("name", Var (params.name, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
