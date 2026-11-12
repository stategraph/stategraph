module DeleteApiV4ProjectsIdHooksHookIdUrlVariablesKey = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      id : int;
      key : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.int
    / "hooks"
    /% Path.int
    / "url_variables"
    /% Path.string

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}/url_variables/{key}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("hook_id", Var (params.hook_id, Int));
           ("key", Var (params.key, String));
           ("id", Var (params.id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdHooksHookIdUrlVariablesKey = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      id : int;
      key : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdHooksHookIdUrlVariablesKey.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.int
    / "hooks"
    /% Path.int
    / "url_variables"
    /% Path.string

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}/url_variables/{key}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("hook_id", Var (params.hook_id, Int));
           ("key", Var (params.key, String));
           ("id", Var (params.id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module PostApiV4ProjectsIdHooksHookIdTestTrigger = struct
  module Parameters = struct
    module Trigger = struct
      let t_of_yojson = function
        | `String "confidential_issues_events" -> Ok `Confidential_issues_events
        | `String "confidential_note_events" -> Ok `Confidential_note_events
        | `String "deployment_events" -> Ok `Deployment_events
        | `String "emoji_events" -> Ok `Emoji_events
        | `String "feature_flag_events" -> Ok `Feature_flag_events
        | `String "issues_events" -> Ok `Issues_events
        | `String "job_events" -> Ok `Job_events
        | `String "merge_requests_events" -> Ok `Merge_requests_events
        | `String "note_events" -> Ok `Note_events
        | `String "pipeline_events" -> Ok `Pipeline_events
        | `String "push_events" -> Ok `Push_events
        | `String "releases_events" -> Ok `Releases_events
        | `String "resource_access_token_events" -> Ok `Resource_access_token_events
        | `String "tag_push_events" -> Ok `Tag_push_events
        | `String "vulnerability_events" -> Ok `Vulnerability_events
        | `String "wiki_page_events" -> Ok `Wiki_page_events
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Confidential_issues_events -> `String "confidential_issues_events"
        | `Confidential_note_events -> `String "confidential_note_events"
        | `Deployment_events -> `String "deployment_events"
        | `Emoji_events -> `String "emoji_events"
        | `Feature_flag_events -> `String "feature_flag_events"
        | `Issues_events -> `String "issues_events"
        | `Job_events -> `String "job_events"
        | `Merge_requests_events -> `String "merge_requests_events"
        | `Note_events -> `String "note_events"
        | `Pipeline_events -> `String "pipeline_events"
        | `Push_events -> `String "push_events"
        | `Releases_events -> `String "releases_events"
        | `Resource_access_token_events -> `String "resource_access_token_events"
        | `Tag_push_events -> `String "tag_push_events"
        | `Vulnerability_events -> `String "vulnerability_events"
        | `Wiki_page_events -> `String "wiki_page_events"

      type t =
        ([ `Confidential_issues_events
         | `Confidential_note_events
         | `Deployment_events
         | `Emoji_events
         | `Feature_flag_events
         | `Issues_events
         | `Job_events
         | `Merge_requests_events
         | `Note_events
         | `Pipeline_events
         | `Push_events
         | `Releases_events
         | `Resource_access_token_events
         | `Tag_push_events
         | `Vulnerability_events
         | `Wiki_page_events
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      hook_id : int;
      id : int;
      trigger : Trigger.t;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.int
    / "hooks"
    /% Path.int
    / "test"
    /% Path.ud (fun value -> CCResult.to_opt (Parameters.Trigger.t_of_yojson (`String value)))

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end
    module Too_many_requests = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Not_found
      | `Unprocessable_entity
      | `Too_many_requests
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
        ("429", fun _ -> Ok `Too_many_requests);
      ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}/test/{trigger}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("hook_id", Var (params.hook_id, Int));
           ("trigger", Var (params.trigger, Enum Trigger.t_to_yojson));
           ("id", Var (params.id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsIdHooksHookIdEventsHookLogIdResend = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      hook_log_id : int;
      id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.int
    / "hooks"
    /% Path.int
    / "events"
    /% Path.int
    / "resend"

  module Responses = struct
    module Created = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end
    module Too_many_requests = struct end

    type t =
      [ `Created
      | `Not_found
      | `Unprocessable_entity
      | `Too_many_requests
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
        ("429", fun _ -> Ok `Too_many_requests);
      ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}/events/{hook_log_id}/resend"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, Int));
           ("hook_id", Var (params.hook_id, Int));
           ("hook_log_id", Var (params.hook_log_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdHooksHookIdEvents = struct
  module Parameters = struct
    module Status = struct
      module Items = struct
        let t_of_yojson = function
          | `String "100" -> Ok `V_100
          | `String "101" -> Ok `V_101
          | `String "102" -> Ok `V_102
          | `String "103" -> Ok `V_103
          | `String "200" -> Ok `V_200
          | `String "201" -> Ok `V_201
          | `String "202" -> Ok `V_202
          | `String "203" -> Ok `V_203
          | `String "204" -> Ok `V_204
          | `String "205" -> Ok `V_205
          | `String "206" -> Ok `V_206
          | `String "207" -> Ok `V_207
          | `String "208" -> Ok `V_208
          | `String "226" -> Ok `V_226
          | `String "300" -> Ok `V_300
          | `String "301" -> Ok `V_301
          | `String "302" -> Ok `V_302
          | `String "303" -> Ok `V_303
          | `String "304" -> Ok `V_304
          | `String "305" -> Ok `V_305
          | `String "306" -> Ok `V_306
          | `String "307" -> Ok `V_307
          | `String "308" -> Ok `V_308
          | `String "400" -> Ok `V_400
          | `String "401" -> Ok `V_401
          | `String "402" -> Ok `V_402
          | `String "403" -> Ok `V_403
          | `String "404" -> Ok `V_404
          | `String "405" -> Ok `V_405
          | `String "406" -> Ok `V_406
          | `String "407" -> Ok `V_407
          | `String "408" -> Ok `V_408
          | `String "409" -> Ok `V_409
          | `String "410" -> Ok `V_410
          | `String "411" -> Ok `V_411
          | `String "412" -> Ok `V_412
          | `String "413" -> Ok `V_413
          | `String "414" -> Ok `V_414
          | `String "415" -> Ok `V_415
          | `String "416" -> Ok `V_416
          | `String "417" -> Ok `V_417
          | `String "421" -> Ok `V_421
          | `String "422" -> Ok `V_422
          | `String "423" -> Ok `V_423
          | `String "424" -> Ok `V_424
          | `String "425" -> Ok `V_425
          | `String "426" -> Ok `V_426
          | `String "428" -> Ok `V_428
          | `String "429" -> Ok `V_429
          | `String "431" -> Ok `V_431
          | `String "451" -> Ok `V_451
          | `String "500" -> Ok `V_500
          | `String "501" -> Ok `V_501
          | `String "502" -> Ok `V_502
          | `String "503" -> Ok `V_503
          | `String "504" -> Ok `V_504
          | `String "505" -> Ok `V_505
          | `String "506" -> Ok `V_506
          | `String "507" -> Ok `V_507
          | `String "508" -> Ok `V_508
          | `String "509" -> Ok `V_509
          | `String "510" -> Ok `V_510
          | `String "511" -> Ok `V_511
          | `String "client_failure" -> Ok `Client_failure
          | `String "server_failure" -> Ok `Server_failure
          | `String "successful" -> Ok `Successful
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `V_100 -> `String "100"
          | `V_101 -> `String "101"
          | `V_102 -> `String "102"
          | `V_103 -> `String "103"
          | `V_200 -> `String "200"
          | `V_201 -> `String "201"
          | `V_202 -> `String "202"
          | `V_203 -> `String "203"
          | `V_204 -> `String "204"
          | `V_205 -> `String "205"
          | `V_206 -> `String "206"
          | `V_207 -> `String "207"
          | `V_208 -> `String "208"
          | `V_226 -> `String "226"
          | `V_300 -> `String "300"
          | `V_301 -> `String "301"
          | `V_302 -> `String "302"
          | `V_303 -> `String "303"
          | `V_304 -> `String "304"
          | `V_305 -> `String "305"
          | `V_306 -> `String "306"
          | `V_307 -> `String "307"
          | `V_308 -> `String "308"
          | `V_400 -> `String "400"
          | `V_401 -> `String "401"
          | `V_402 -> `String "402"
          | `V_403 -> `String "403"
          | `V_404 -> `String "404"
          | `V_405 -> `String "405"
          | `V_406 -> `String "406"
          | `V_407 -> `String "407"
          | `V_408 -> `String "408"
          | `V_409 -> `String "409"
          | `V_410 -> `String "410"
          | `V_411 -> `String "411"
          | `V_412 -> `String "412"
          | `V_413 -> `String "413"
          | `V_414 -> `String "414"
          | `V_415 -> `String "415"
          | `V_416 -> `String "416"
          | `V_417 -> `String "417"
          | `V_421 -> `String "421"
          | `V_422 -> `String "422"
          | `V_423 -> `String "423"
          | `V_424 -> `String "424"
          | `V_425 -> `String "425"
          | `V_426 -> `String "426"
          | `V_428 -> `String "428"
          | `V_429 -> `String "429"
          | `V_431 -> `String "431"
          | `V_451 -> `String "451"
          | `V_500 -> `String "500"
          | `V_501 -> `String "501"
          | `V_502 -> `String "502"
          | `V_503 -> `String "503"
          | `V_504 -> `String "504"
          | `V_505 -> `String "505"
          | `V_506 -> `String "506"
          | `V_507 -> `String "507"
          | `V_508 -> `String "508"
          | `V_509 -> `String "509"
          | `V_510 -> `String "510"
          | `V_511 -> `String "511"
          | `Client_failure -> `String "client_failure"
          | `Server_failure -> `String "server_failure"
          | `Successful -> `String "successful"

        type t =
          ([ `V_100
           | `V_101
           | `V_102
           | `V_103
           | `V_200
           | `V_201
           | `V_202
           | `V_203
           | `V_204
           | `V_205
           | `V_206
           | `V_207
           | `V_208
           | `V_226
           | `V_300
           | `V_301
           | `V_302
           | `V_303
           | `V_304
           | `V_305
           | `V_306
           | `V_307
           | `V_308
           | `V_400
           | `V_401
           | `V_402
           | `V_403
           | `V_404
           | `V_405
           | `V_406
           | `V_407
           | `V_408
           | `V_409
           | `V_410
           | `V_411
           | `V_412
           | `V_413
           | `V_414
           | `V_415
           | `V_416
           | `V_417
           | `V_421
           | `V_422
           | `V_423
           | `V_424
           | `V_425
           | `V_426
           | `V_428
           | `V_429
           | `V_431
           | `V_451
           | `V_500
           | `V_501
           | `V_502
           | `V_503
           | `V_504
           | `V_505
           | `V_506
           | `V_507
           | `V_508
           | `V_509
           | `V_510
           | `V_511
           | `Client_failure
           | `Server_failure
           | `Successful
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving show, eq]
      end

      type t = Items.t list [@@deriving show, eq]
    end

    type t = {
      hook_id : int;
      id : int;
      page : int; [@default 1]
      per_page : int; [@default 20]
      status : Status.t option; [@default None]
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
    /% Path.int
    / "hooks"
    /% Path.int
    / "events"
    /? option
         (array
            (ud "status" (fun value ->
                 CCResult.to_opt (Parameters.Status.Items.t_of_yojson (`String value)))))
    /? option_default 20 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}/events"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)); ("hook_id", Var (params.hook_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("status", Var (params.status, Option (Array (Enum Status.Items.t_to_yojson))));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4ProjectsIdHooksHookIdCustomHeadersKey = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      id : int;
      key : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.int
    / "hooks"
    /% Path.int
    / "custom_headers"
    /% Path.string

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}/custom_headers/{key}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("hook_id", Var (params.hook_id, Int));
           ("key", Var (params.key, String));
           ("id", Var (params.id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdHooksHookIdCustomHeadersKey = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      id : int;
      key : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdHooksHookIdCustomHeadersKey.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.int
    / "hooks"
    /% Path.int
    / "custom_headers"
    /% Path.string

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}/custom_headers/{key}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("hook_id", Var (params.hook_id, Int));
           ("key", Var (params.key, String));
           ("id", Var (params.id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module DeleteApiV4ProjectsIdHooksHookId = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "hooks" /% Path.int

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("hook_id", Var (params.hook_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdHooksHookId = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdHooksHookId.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "hooks" /% Path.int

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Not_found
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("hook_id", Var (params.hook_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdHooksHookId = struct
  module Parameters = struct
    type t = {
      hook_id : int;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "hooks" /% Path.int

  module Responses = struct
    module OK = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Not_found
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/api/v4/projects/{id}/hooks/{hook_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("hook_id", Var (params.hook_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdHooks = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdHooks.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "hooks"

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Not_found
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id}/hooks"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdHooks = struct
  module Parameters = struct
    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
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
    / "hooks"
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/hooks"

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
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end
