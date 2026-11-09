module GetApiV4ProjectsIdDebianDistributionsCodenameKeyAsc = struct
  module Parameters = struct
    type t = {
      codename : string;
      id : string;
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

  let url = "/api/v4/projects/{id}/debian_distributions/{codename}/key.asc"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("codename", Var (params.codename, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4ProjectsIdDebianDistributionsCodename = struct
  module Parameters = struct
    module Architectures = struct
      type t = string list [@@deriving show, eq]
    end

    module Components = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      architectures : Architectures.t option; [@default None]
      codename : string;
      components : Components.t option; [@default None]
      description : string option; [@default None]
      id : string;
      label : string option; [@default None]
      origin : string option; [@default None]
      suite : string option; [@default None]
      valid_time_duration_seconds : int option; [@default None]
      version : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "suite")
    /? option (string "origin")
    /? option (string "label")
    /? option (string "version")
    /? option (string "description")
    /? option (int "valid_time_duration_seconds")
    /? option (array (string "components"))
    /? option (array (string "architectures"))

  module Responses = struct
    module Accepted = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Accepted
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", fun _ -> Ok `Accepted);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/debian_distributions/{codename}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("codename", Var (params.codename, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("suite", Var (params.suite, Option String));
           ("origin", Var (params.origin, Option String));
           ("label", Var (params.label, Option String));
           ("version", Var (params.version, Option String));
           ("description", Var (params.description, Option String));
           ("valid_time_duration_seconds", Var (params.valid_time_duration_seconds, Option Int));
           ("components", Var (params.components, Option (Array String)));
           ("architectures", Var (params.architectures, Option (Array String)));
         ])
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdDebianDistributionsCodename = struct
  module Parameters = struct
    type t = {
      codename : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdDebianDistributionsCodename.t
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

  let url = "/api/v4/projects/{id}/debian_distributions/{codename}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("codename", Var (params.codename, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdDebianDistributionsCodename = struct
  module Parameters = struct
    type t = {
      codename : string;
      id : string;
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

  let url = "/api/v4/projects/{id}/debian_distributions/{codename}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("codename", Var (params.codename, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdDebianDistributions = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdDebianDistributions.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/debian_distributions"

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

module GetApiV4ProjectsIdDebianDistributions = struct
  module Parameters = struct
    module Architectures = struct
      type t = string list [@@deriving show, eq]
    end

    module Components = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      architectures : Architectures.t option; [@default None]
      codename : string option; [@default None]
      components : Components.t option; [@default None]
      description : string option; [@default None]
      id : string;
      label : string option; [@default None]
      origin : string option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 20]
      suite : string option; [@default None]
      valid_time_duration_seconds : int option; [@default None]
      version : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option (string "codename")
    /? option (string "suite")
    /? option (string "origin")
    /? option (string "label")
    /? option (string "version")
    /? option (string "description")
    /? option (int "valid_time_duration_seconds")
    /? option (array (string "components"))
    /? option (array (string "architectures"))

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

  let url = "/api/v4/projects/{id}/debian_distributions"

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
           ("codename", Var (params.codename, Option String));
           ("suite", Var (params.suite, Option String));
           ("origin", Var (params.origin, Option String));
           ("label", Var (params.label, Option String));
           ("version", Var (params.version, Option String));
           ("description", Var (params.description, Option String));
           ("valid_time_duration_seconds", Var (params.valid_time_duration_seconds, Option Int));
           ("components", Var (params.components, Option (Array String)));
           ("architectures", Var (params.architectures, Option (Array String)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
