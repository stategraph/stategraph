module GetApiV4ProjectsIdJobsJobIdTrace = struct
  module Parameters = struct
    type t = {
      id : int;
      job_id : int;
    }
    [@@deriving make, show, eq]
  end

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

  let url = "/api/v4/projects/{id}/jobs/{job_id}/trace"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("job_id", Var (params.job_id, Int)); ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdJobsJobIdRetry = struct
  module Parameters = struct
    type t = {
      id : int;
      job_id : int;
    }
    [@@deriving make, show, eq]
  end

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

  let url = "/api/v4/projects/{id}/jobs/{job_id}/retry"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("job_id", Var (params.job_id, Int)); ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsIdJobsJobIdPlay = struct
  module Parameters = struct
    type t = {
      id : int;
      job_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdJobsJobIdPlay.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

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

  let url = "/api/v4/projects/{id}/jobs/{job_id}/play"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("job_id", Var (params.job_id, Int)); ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsIdJobsJobIdErase = struct
  module Parameters = struct
    type t = {
      id : int;
      job_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Conflict = struct end

    type t =
      [ `Created
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Conflict
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("409", fun _ -> Ok `Conflict);
      ]
  end

  let url = "/api/v4/projects/{id}/jobs/{job_id}/erase"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("job_id", Var (params.job_id, Int)); ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsIdJobsJobIdCancel = struct
  module Parameters = struct
    type t = {
      id : int;
      job_id : int;
    }
    [@@deriving make, show, eq]
  end

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

  let url = "/api/v4/projects/{id}/jobs/{job_id}/cancel"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("job_id", Var (params.job_id, Int)); ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsIdJobsJobIdArtifactsKeep = struct
  module Parameters = struct
    type t = {
      id : string;
      job_id : int;
    }
    [@@deriving make, show, eq]
  end

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

  let url = "/api/v4/projects/{id}/jobs/{job_id}/artifacts/keep"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("job_id", Var (params.job_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdJobsJobIdArtifacts_artifactPath = struct
  module Parameters = struct
    type t = {
      artifact_path : string;
      id : string;
      job_id : int;
      job_token : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "artifact_path" /? option (string "job_token")

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

  let url = "/api/v4/projects/{id}/jobs/{job_id}/artifacts/*artifact_path"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("job_id", Var (params.job_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("artifact_path", Var (params.artifact_path, String));
           ("job_token", Var (params.job_token, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4ProjectsIdJobsJobIdArtifacts = struct
  module Parameters = struct
    type t = {
      id : string;
      job_id : int;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Conflict = struct end

    type t =
      [ `No_content
      | `Unauthorized
      | `Forbidden
      | `Conflict
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("409", fun _ -> Ok `Conflict);
      ]
  end

  let url = "/api/v4/projects/{id}/jobs/{job_id}/artifacts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("job_id", Var (params.job_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module GetApiV4ProjectsIdJobsJobIdArtifacts = struct
  module Parameters = struct
    type t = {
      id : string;
      job_id : int;
      job_token : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (string "job_token")

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

  let url = "/api/v4/projects/{id}/jobs/{job_id}/artifacts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("job_id", Var (params.job_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("job_token", Var (params.job_token, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdJobsJobId = struct
  module Parameters = struct
    type t = {
      id : int;
      job_id : int;
    }
    [@@deriving make, show, eq]
  end

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

  let url = "/api/v4/projects/{id}/jobs/{job_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("job_id", Var (params.job_id, Int)); ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdJobsArtifactsRefNameRaw_artifactPath = struct
  module Parameters = struct
    type t = {
      artifact_path : string;
      id : string;
      job : string;
      job_token : string option; [@default None]
      ref_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "job" /? string "artifact_path" /? option (string "job_token")

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

  let url = "/api/v4/projects/{id}/jobs/artifacts/{ref_name}/raw/*artifact_path"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("ref_name", Var (params.ref_name, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("job", Var (params.job, String));
           ("artifact_path", Var (params.artifact_path, String));
           ("job_token", Var (params.job_token, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdJobsArtifactsRefNameDownload = struct
  module Parameters = struct
    type t = {
      id : string;
      job : string;
      job_token : string option; [@default None]
      ref_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "job" /? option (string "job_token")

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

  let url = "/api/v4/projects/{id}/jobs/artifacts/{ref_name}/download"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("ref_name", Var (params.ref_name, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("job", Var (params.job, String)); ("job_token", Var (params.job_token, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4ProjectsIdJobs = struct
  module Parameters = struct
    module Scope = struct
      module Items = struct
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

      type t = Items.t list [@@deriving show, eq]
    end

    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      scope : Scope.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (array
            (ud "scope" (fun value ->
                 CCResult.to_opt (Parameters.Scope.Items.t_of_yojson (`String value)))))
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

  let url = "/api/v4/projects/{id}/jobs"

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
           ("scope", Var (params.scope, Option (Array (Enum Scope.Items.t_to_yojson))));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
