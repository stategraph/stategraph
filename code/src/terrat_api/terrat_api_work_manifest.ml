module Workspaces = struct
  module Parameters = struct
    type t = { work_manifest_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "github" / "v1" / "work-manifests" /% Path.string / "workspaces"

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Work_manifest_workspaces.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct end

    type t =
      [ `OK of OK.t
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/github/v1/work-manifests/{work_manifest_id}/workspaces"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("work_manifest_id", Var (params.work_manifest_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Plan_create = struct
  module Parameters = struct
    type t = { work_manifest_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Terrat_api_components.Plan_create.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "github" / "v1" / "work-manifests" /% Path.string / "plans"

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end

    type t =
      [ `OK
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("403", fun _ -> Ok `Forbidden) ]
  end

  let url = "/api/github/v1/work-manifests/{work_manifest_id}/plans"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("work_manifest_id", Var (params.work_manifest_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Plan_get = struct
  module Parameters = struct
    type t = {
      dir : string;
      work_manifest_id : string;
      workspace : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "github"
    / "v1"
    / "work-manifests"
    /% Path.string
    / "plans"
    /? string "dir"
    /? string "workspace"

  module Responses = struct
    module OK = struct
      type t = { data : string } [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/github/v1/work-manifests/{work_manifest_id}/plans"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("work_manifest_id", Var (params.work_manifest_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("dir", Var (params.dir, String)); ("workspace", Var (params.workspace, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Initiate = struct
  module Parameters = struct
    type t = { work_manifest_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Terrat_api_components.Work_manifest_initiate.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "github" / "v1" / "work-manifests" /% Path.string / "initiate"

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Work_manifest.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct end

    type t =
      [ `OK of OK.t
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/github/v1/work-manifests/{work_manifest_id}/initiate"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("work_manifest_id", Var (params.work_manifest_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_access_token = struct
  module Parameters = struct
    type t = { work_manifest_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "github" / "v1" / "work-manifests" /% Path.string / "access-token"

  module Responses = struct
    module OK = struct
      type t = { access_token : string }
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/github/v1/work-manifests/{work_manifest_id}/access-token"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("work_manifest_id", Var (params.work_manifest_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Results = struct
  module Parameters = struct
    type t = { work_manifest_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Terrat_api_components.Work_manifest_result.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "github" / "v1" / "work-manifests" /% Path.string

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end

    type t =
      [ `OK
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK); ("403", fun _ -> Ok `Forbidden) ]
  end

  let url = "/api/github/v1/work-manifests/{work_manifest_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("work_manifest_id", Var (params.work_manifest_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end
