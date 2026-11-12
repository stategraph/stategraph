module Unlink_vcs_installation = struct
  module Parameters = struct
    type t = {
      installation_core_id : string;
      provider : string;
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "vcs-installations" /% Path.string /% Path.uuid

  module Responses = struct
    module No_content = struct end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `No_content
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{installation_core_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("tenant_id", Var (params.tenant_id, String));
           ("provider", Var (params.provider, String));
           ("installation_core_id", Var (params.installation_core_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Link_vcs_installation = struct
  module Parameters = struct
    type t = {
      installation_core_id : string;
      provider : string;
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "vcs-installations" /% Path.string /% Path.uuid

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Vcs_installation.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/vcs-installations/{provider}/{installation_core_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("tenant_id", Var (params.tenant_id, String));
           ("provider", Var (params.provider, String));
           ("installation_core_id", Var (params.installation_core_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Rotate_gitlab_installation = struct
  module Parameters = struct
    type t = {
      group_id : int;
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Gitlab_rotate_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "vcs-installations" / "gitlab" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Gitlab_rotate_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/vcs-installations/gitlab/{group_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)); ("group_id", Var (params.group_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Provision_gitlab_installation = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Gitlab_provision_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "vcs-installations" / "gitlab"

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.Gitlab_provision_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      | `Conflict of Conflict.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/vcs-installations/gitlab"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_claimable_github_installations = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "vcs-installations" / "github" / "claimable"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Github_claimable_installations.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Precondition_failed = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Precondition_failed of Precondition_failed.t
      | `Internal_server_error
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("412", Openapi.of_json_body (fun v -> `Precondition_failed v) Precondition_failed.of_yojson);
        ("500", fun _ -> Ok `Internal_server_error);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/vcs-installations/github/claimable"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Start_github_claim = struct
  module Parameters = struct
    type t = {
      rd : string option; [@default None]
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    / "tenants"
    /% Path.uuid
    / "vcs-installations"
    / "github"
    / "claim"
    / "start"
    /? option (string "rd")

  module Responses = struct
    module Found = struct end
    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Found
      | `Unauthorized
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("302", fun _ -> Ok `Found);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/vcs-installations/github/claim/start"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("rd", Var (params.rd, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Claim_github_installation = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Github_claim_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "vcs-installations" / "github" / "claim"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Vcs_installation.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Precondition_failed = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Internal_server_error = struct end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Conflict of Conflict.t
      | `Precondition_failed of Precondition_failed.t
      | `Internal_server_error
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ("412", Openapi.of_json_body (fun v -> `Precondition_failed v) Precondition_failed.of_yojson);
        ("500", fun _ -> Ok `Internal_server_error);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/vcs-installations/github/claim"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_vcs_installations = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "vcs-installations"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Vcs_installation_list_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/vcs-installations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Tx_create = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Tags = struct
      type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      params : Sgs_api_components.Tx_params.t option; [@default None]
      state_schema_version : int;
      tags : Tags.t option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "tx" / "create"

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.Tx.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/tx/create"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Tx_list = struct
  module Parameters = struct
    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      from : string option; [@default None]
      limit : int; [@default 20]
      page : Page.t option; [@default None]
      tenant_id : string;
      to_ : string option; [@default None] [@key "to"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    / "tenants"
    /% Path.uuid
    / "tx"
    /? option (array (string "page"))
    /? option_default 20 (int "limit")
    /? option (string "from")
    /? option (string "to")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Txs.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/tx"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Option (Array String)));
           ("limit", Var (params.limit, Int));
           ("from", Var (params.from, Option String));
           ("to", Var (params.to_, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Summary = struct
  module Parameters = struct
    type t = {
      state_id : string option; [@default None]
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "summary" /? option (string "state_id")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_summary.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/summary"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Import_state = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module State = struct
      type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    module Tags = struct
      type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
    end

    type t = {
      group_id : string option; [@default None]
      name : string;
      state : State.t;
      tags : Tags.t option; [@default None]
      workspace : string; [@default "default"]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "states" / "import"

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.State.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/states/import"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Create_state = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = {
      group_id : string option; [@default None]
      name : string;
      workspace : string; [@default "default"]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "states"

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.State.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Unauthorized
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/states"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_states = struct
  module Parameters = struct
    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      limit : int; [@default 20]
      page : Page.t option; [@default None]
      q : string option; [@default None]
      tenant_id : string;
      tz : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    / "tenants"
    /% Path.uuid
    / "states"
    /? option (array (string "page"))
    /? option (string "q")
    /? option (string "tz")
    /? option_default 20 (int "limit")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_states.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/states"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Option (Array String)));
           ("q", Var (params.q, Option String));
           ("tz", Var (params.tz, Option String));
           ("limit", Var (params.limit, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Security_findings_history = struct
  module Parameters = struct
    type t = {
      from : string option; [@default None]
      tenant_id : string;
      to_ : string option; [@default None] [@key "to"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    / "tenants"
    /% Path.uuid
    / "security"
    / "findings"
    / "history"
    /? option (string "from")
    /? option (string "to")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_security_history.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Service_unavailable = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/security/findings/history"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("from", Var (params.from, Option String)); ("to", Var (params.to_, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Resource_types = struct
  module Parameters = struct
    type t = {
      state_id : string option; [@default None]
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "resource-types" /? option (string "state_id")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_resource_types.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/resource-types"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("state_id", Var (params.state_id, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Set_member_role = struct
  module Parameters = struct
    type t = {
      tenant_id : string;
      user_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Tenant_member_set_role_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "members" / "set-role" /? string "user_id"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_member.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/members/set-role"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, String)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module Remove_member = struct
  module Parameters = struct
    type t = {
      tenant_id : string;
      user_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "members" /? string "user_id"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_member_remove_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/members"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, String)) ])
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_member = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Tenant_member_add_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "members"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_member.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Created = struct
      type t = Sgs_api_components.Tenant_member.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/members"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_members = struct
  module Parameters = struct
    type t = {
      cursor : string option; [@default None]
      limit : int; [@default 25]
      role : string option; [@default None]
      search : string option; [@default None]
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    / "tenants"
    /% Path.uuid
    / "members"
    /? option (string "search")
    /? option (string "role")
    /? option (string "cursor")
    /? option_default 25 (int "limit")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_members_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/members"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("search", Var (params.search, Option String));
           ("role", Var (params.role, Option String));
           ("cursor", Var (params.cursor, Option String));
           ("limit", Var (params.limit, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Revoke_invitation = struct
  module Parameters = struct
    type t = {
      id : string;
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "invitations" / "revoke" /? string "id"

  module Responses = struct
    module No_content = struct end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/invitations/revoke"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module Reissue_invitation = struct
  module Parameters = struct
    type t = {
      id : string;
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "invitations" / "reissue" /? string "id"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Invitation_create_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Too_many_requests = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Too_many_requests of Too_many_requests.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ("429", Openapi.of_json_body (fun v -> `Too_many_requests v) Too_many_requests.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/invitations/reissue"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)) ])
      ~url
      ~responses:Responses.t
      `Post
end

module Create_invitation = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Invitation_create_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "invitations"

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.Invitation_create_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Too_many_requests = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Conflict of Conflict.t
      | `Too_many_requests of Too_many_requests.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ("429", Openapi.of_json_body (fun v -> `Too_many_requests v) Too_many_requests.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/invitations"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_invitations = struct
  module Parameters = struct
    type t = {
      cursor : string option; [@default None]
      limit : int; [@default 25]
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    / "tenants"
    /% Path.uuid
    / "invitations"
    /? option (string "cursor")
    /? option_default 25 (int "limit")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_invitations_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/invitations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("cursor", Var (params.cursor, Option String)); ("limit", Var (params.limit, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Gaps_import = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Gap_import_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "gaps" / "import"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Gap_import_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end
    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/gaps/import"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Gaps_config = struct
  module Parameters = struct
    type t = {
      provider : string;
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "gaps" / "config" /? string "provider"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Gap_analysis_config_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/gaps/config"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("provider", Var (params.provider, String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Gaps = struct
  module Parameters = struct
    module Source = struct
      let t_of_yojson = function
        | `String "cache" -> Ok `Cache
        | `String "no-cache" -> Ok `No_cache
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Cache -> `String "cache"
        | `No_cache -> `String "no-cache"

      type t =
        ([ `Cache
         | `No_cache
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      provider : string;
      source : Source.t; [@default `Cache]
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    / "tenants"
    /% Path.uuid
    / "gaps"
    /? string "provider"
    /? option_default
         `Cache
         (ud "source" (fun value -> CCResult.to_opt (Parameters.Source.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Gap_analysis_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Accepted = struct
      type t = Sgs_api_components.Gap_analysis_job_status.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Accepted of Accepted.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/gaps"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("provider", Var (params.provider, String));
           ("source", Var (params.source, Enum Source.t_to_yojson));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Costs_unmanaged = struct
  module Parameters = struct
    module Page = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      limit : int; [@default 20]
      page : Page.t option; [@default None]
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    / "tenants"
    /% Path.uuid
    / "costs"
    / "unmanaged"
    /? option (array (string "page"))
    /? option_default 20 (int "limit")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_cost_unmanaged.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Bad_request_err.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/costs/unmanaged"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Option (Array String))); ("limit", Var (params.limit, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Costs_tag_keys = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "costs" / "tag-keys"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_cost_tag_keys.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/costs/tag-keys"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Costs_history = struct
  module Parameters = struct
    type t = {
      from : string option; [@default None]
      group_by : string option; [@default None]
      tag_key : string option; [@default None]
      tenant_id : string;
      to_ : string option; [@default None] [@key "to"]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    / "tenants"
    /% Path.uuid
    / "costs"
    / "history"
    /? option (string "from")
    /? option (string "to")
    /? option (string "group_by")
    /? option (string "tag_key")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_cost_history.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/costs/history"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("from", Var (params.from, Option String));
           ("to", Var (params.to_, Option String));
           ("group_by", Var (params.group_by, Option String));
           ("tag_key", Var (params.tag_key, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Costs_attribution = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "costs" / "attribution"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_cost_attribution.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/costs/attribution"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Costs = struct
  module Parameters = struct
    type t = {
      tag_key : string option; [@default None]
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "costs" /? option (string "tag_key")

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant_costs.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/costs"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tag_key", Var (params.tag_key, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Sync_billing_source = struct
  module Parameters = struct
    type t = {
      billing_source_id : string;
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Billing_source_sync_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "billing-sources" /% Path.uuid / "sync"

  module Responses = struct
    module Accepted = struct
      type t = Sgs_api_components.Billing_source_sync_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `Accepted of Accepted.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/billing-sources/{billing_source_id}/sync"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("tenant_id", Var (params.tenant_id, String));
           ("billing_source_id", Var (params.billing_source_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Delete_billing_source = struct
  module Parameters = struct
    type t = {
      billing_source_id : string;
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "billing-sources" /% Path.uuid

  module Responses = struct
    module No_content = struct end
    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `No_content
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/billing-sources/{billing_source_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("tenant_id", Var (params.tenant_id, String));
           ("billing_source_id", Var (params.billing_source_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Update_billing_source = struct
  module Parameters = struct
    type t = {
      billing_source_id : string;
      tenant_id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Billing_source_update_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "billing-sources" /% Path.uuid

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Billing_source.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", fun _ -> Ok `Not_found);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/billing-sources/{billing_source_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("tenant_id", Var (params.tenant_id, String));
           ("billing_source_id", Var (params.billing_source_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Create_billing_source = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Billing_source_create_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "billing-sources"

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.Billing_source.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/billing-sources"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_billing_sources = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid / "billing-sources"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Billing_source_list_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}/billing-sources"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Update = struct
  module Parameters = struct
    type t = { tenant_id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Sgs_api_components.Tenant_update_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants" /% Path.uuid

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Tenant.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/api/v1/tenants/{tenant_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("tenant_id", Var (params.tenant_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Create = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Sgs_api_components.Tenant_create_request.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tenants"

  module Responses = struct
    module Created = struct
      type t = Sgs_api_components.Tenant.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_capability_denied_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/api/v1/tenants"

  let make ~body =
   fun () ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end
