module Get_work_manifest_outputs = struct
  module Parameters = struct
    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      installation_id : string;
      limit : int; [@default 20]
      lite : bool; [@default false]
      page : Page.t option; [@default None]
      q : string option; [@default None]
      tz : string option; [@default None]
      work_manifest_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "q")
    /? option (array (string "page"))
    /? option (string "tz")
    /? option_default 20 (int "limit")
    /? option_default false (bool "lite")

  module Responses = struct
    module OK = struct
      module Steps = struct
        type t = Terrat_api_components.Installation_workflow_step_output.t list
        [@@deriving yojson { strict = false; meta = false }, show, eq]
      end

      type t = { steps : Steps.t } [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Bad_request = struct
      type t = Terrat_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url =
    "/api/v1/gitlab/installations/{installation_id}/work-manifests/{work_manifest_id}/outputs"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("installation_id", Var (params.installation_id, String));
           ("work_manifest_id", Var (params.work_manifest_id, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("q", Var (params.q, Option String));
           ("page", Var (params.page, Option (Array String)));
           ("tz", Var (params.tz, Option String));
           ("limit", Var (params.limit, Int));
           ("lite", Var (params.lite, Bool));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_work_manifest = struct
  module Parameters = struct
    type t = {
      installation_id : string;
      work_manifest_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Installation_work_manifest.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/gitlab/installations/{installation_id}/work-manifests/{work_manifest_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("installation_id", Var (params.installation_id, String));
           ("work_manifest_id", Var (params.work_manifest_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_work_manifests = struct
  module Parameters = struct
    module D = struct
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

    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      d : D.t option; [@default None]
      installation_id : string;
      limit : int; [@default 20]
      page : Page.t option; [@default None]
      q : string option; [@default None]
      tz : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (array (string "page"))
    /? option (string "q")
    /? option (ud "d" (fun value -> CCResult.to_opt (Parameters.D.t_of_yojson (`String value))))
    /? option (string "tz")
    /? option_default 20 (int "limit")

  module Responses = struct
    module OK = struct
      module Work_manifests = struct
        type t = Terrat_api_components.Installation_work_manifest.t list
        [@@deriving yojson { strict = false; meta = false }, show, eq]
      end

      type t = { work_manifests : Work_manifests.t }
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Bad_request = struct
      type t = Terrat_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v1/gitlab/installations/{installation_id}/work-manifests"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Option (Array String)));
           ("q", Var (params.q, Option String));
           ("d", Var (params.d, Option (Enum D.t_to_yojson)));
           ("tz", Var (params.tz, Option String));
           ("limit", Var (params.limit, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_repo = struct
  module Parameters = struct
    type t = {
      installation_id : string;
      repo_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
    end

    module Bad_request = struct
      type t = Terrat_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct
      type t = Terrat_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v1/gitlab/installations/{installation_id}/repos/{repo_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("installation_id", Var (params.installation_id, String));
           ("repo_id", Var (params.repo_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module List_repos = struct
  module Parameters = struct
    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      installation_id : string;
      limit : int; [@default 20]
      page : Page.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (array (string "page")) /? option_default 20 (int "limit")

  module Responses = struct
    module OK = struct
      module Repositories = struct
        type t = Terrat_api_components.Installation_repo.t list
        [@@deriving yojson { strict = false; meta = false }, show, eq]
      end

      type t = { repositories : Repositories.t }
      [@@deriving yojson { strict = false; meta = true }, show, eq]
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

  let url = "/api/v1/gitlab/installations/{installation_id}/repos"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Option (Array String))); ("limit", Var (params.limit, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_dirspaces = struct
  module Parameters = struct
    module D = struct
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

    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      d : D.t option; [@default None]
      installation_id : string;
      limit : int; [@default 20]
      page : Page.t option; [@default None]
      q : string option; [@default None]
      tz : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (array (string "page"))
    /? option (string "q")
    /? option (ud "d" (fun value -> CCResult.to_opt (Parameters.D.t_of_yojson (`String value))))
    /? option (string "tz")
    /? option_default 20 (int "limit")

  module Responses = struct
    module OK = struct
      module Dirspaces = struct
        type t = Terrat_api_components.Installation_dirspace.t list
        [@@deriving yojson { strict = false; meta = false }, show, eq]
      end

      type t = { dirspaces : Dirspaces.t }
      [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Bad_request = struct
      type t = Terrat_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v1/gitlab/installations/{installation_id}/dirspaces"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Option (Array String)));
           ("q", Var (params.q, Option String));
           ("d", Var (params.d, Option (Enum D.t_to_yojson)));
           ("tz", Var (params.tz, Option String));
           ("limit", Var (params.limit, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_access_token = struct
  module Parameters = struct
    type t = { installation_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Terrat_api_components.Gitlab_access_token.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

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

  let url = "/api/v1/gitlab/installations/{installation_id}/access-token"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("installation_id", Var (params.installation_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_webhook = struct
  module Parameters = struct
    type t = { id : int } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Gitlab_webhook.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/api/v1/gitlab/installations/{id}/webhook"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List = struct
  module Parameters = struct end

  module Responses = struct
    module OK = struct
      module Installations = struct
        type t = Terrat_api_components.Installation.t list
        [@@deriving yojson { strict = false; meta = false }, show, eq]
      end

      type t = { installations : Installations.t }
      [@@deriving yojson { strict = false; meta = true }, show, eq]
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

  let url = "/api/v1/gitlab/installations"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
