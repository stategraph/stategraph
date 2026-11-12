module DeleteApiV4ProjectsIdRunnersRunnerId = struct
  module Parameters = struct
    type t = {
      id : string;
      runner_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "runners" /% Path.int

  module Responses = struct
    module No_content = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Precondition_failed = struct end

    type t =
      [ `No_content
      | `Bad_request
      | `Forbidden
      | `Not_found
      | `Precondition_failed
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("412", fun _ -> Ok `Precondition_failed);
      ]
  end

  let url = "/api/v4/projects/{id}/runners/{runner_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("runner_id", Var (params.runner_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PostApiV4ProjectsIdRunnersResetRegistrationToken = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "runners" / "reset_registration_token"

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

  let url = "/api/v4/projects/{id}/runners/reset_registration_token"

  let make params =
    Openapi.Request.make
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

module PostApiV4ProjectsIdRunners = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdRunners.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "runners"

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/runners"

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

module GetApiV4ProjectsIdRunners = struct
  module Parameters = struct
    module Scope = struct
      let t_of_yojson = function
        | `String "active" -> Ok `Active
        | `String "group_type" -> Ok `Group_type
        | `String "instance_type" -> Ok `Instance_type
        | `String "never_contacted" -> Ok `Never_contacted
        | `String "offline" -> Ok `Offline
        | `String "online" -> Ok `Online
        | `String "paused" -> Ok `Paused
        | `String "project_type" -> Ok `Project_type
        | `String "shared" -> Ok `Shared
        | `String "specific" -> Ok `Specific
        | `String "stale" -> Ok `Stale
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Active -> `String "active"
        | `Group_type -> `String "group_type"
        | `Instance_type -> `String "instance_type"
        | `Never_contacted -> `String "never_contacted"
        | `Offline -> `String "offline"
        | `Online -> `String "online"
        | `Paused -> `String "paused"
        | `Project_type -> `String "project_type"
        | `Shared -> `String "shared"
        | `Specific -> `String "specific"
        | `Stale -> `String "stale"

      type t =
        ([ `Active
         | `Group_type
         | `Instance_type
         | `Never_contacted
         | `Offline
         | `Online
         | `Paused
         | `Project_type
         | `Shared
         | `Specific
         | `Stale
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Status = struct
      let t_of_yojson = function
        | `String "active" -> Ok `Active
        | `String "never_contacted" -> Ok `Never_contacted
        | `String "offline" -> Ok `Offline
        | `String "online" -> Ok `Online
        | `String "paused" -> Ok `Paused
        | `String "stale" -> Ok `Stale
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Active -> `String "active"
        | `Never_contacted -> `String "never_contacted"
        | `Offline -> `String "offline"
        | `Online -> `String "online"
        | `Paused -> `String "paused"
        | `Stale -> `String "stale"

      type t =
        ([ `Active
         | `Never_contacted
         | `Offline
         | `Online
         | `Paused
         | `Stale
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Tag_list = struct
      type t = string list [@@deriving show, eq]
    end

    module Type = struct
      let t_of_yojson = function
        | `String "group_type" -> Ok `Group_type
        | `String "instance_type" -> Ok `Instance_type
        | `String "project_type" -> Ok `Project_type
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Group_type -> `String "group_type"
        | `Instance_type -> `String "instance_type"
        | `Project_type -> `String "project_type"

      type t =
        ([ `Group_type
         | `Instance_type
         | `Project_type
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      id : string;
      page : int; [@default 1]
      paused : bool option; [@default None]
      per_page : int; [@default 20]
      scope : Scope.t option; [@default None]
      status : Status.t option; [@default None]
      tag_list : Tag_list.t option; [@default None]
      type_ : Type.t option; [@default None] [@key "type"]
      version_prefix : string option; [@default None]
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
    / "runners"
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option
         (ud "type" (fun value -> CCResult.to_opt (Parameters.Type.t_of_yojson (`String value))))
    /? option (bool "paused")
    /? option
         (ud "status" (fun value -> CCResult.to_opt (Parameters.Status.t_of_yojson (`String value))))
    /? option (array (string "tag_list"))
    /? option (string "version_prefix")
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("400", fun _ -> Ok `Bad_request); ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v4/projects/{id}/runners"

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
           ("scope", Var (params.scope, Option (Enum Scope.t_to_yojson)));
           ("type", Var (params.type_, Option (Enum Type.t_to_yojson)));
           ("paused", Var (params.paused, Option Bool));
           ("status", Var (params.status, Option (Enum Status.t_to_yojson)));
           ("tag_list", Var (params.tag_list, Option (Array String)));
           ("version_prefix", Var (params.version_prefix, Option String));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
