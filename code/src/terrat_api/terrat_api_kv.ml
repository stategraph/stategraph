module Size = struct
  module Parameters = struct
    type t = {
      committed : bool option; [@default None]
      idx : int option; [@default None]
      installation_id : string;
      key : string;
      vcs : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    /% Path.string
    / "kv"
    /% Path.string
    / "size"
    / "key"
    /% Path.string
    /? option (bool "committed")
    /? option (int "idx")

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Kv_size.t
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

  let url = "/api/v1/{vcs}/kv/{installation_id}/size/key/{key}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("vcs", Var (params.vcs, String));
           ("installation_id", Var (params.installation_id, String));
           ("key", Var (params.key, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("committed", Var (params.committed, Option Bool)); ("idx", Var (params.idx, Option Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete = struct
  module Parameters = struct
    type t = {
      idx : int option; [@default None]
      installation_id : string;
      key : string;
      vcs : string;
      version : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    /% Path.string
    / "kv"
    /% Path.string
    / "key"
    /% Path.string
    /? option (int "idx")
    /? option (int "version")

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Kv_delete.t
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

  let url = "/api/v1/{vcs}/kv/{installation_id}/key/{key}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("vcs", Var (params.vcs, String));
           ("installation_id", Var (params.installation_id, String));
           ("key", Var (params.key, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("idx", Var (params.idx, Option Int)); ("version", Var (params.version, Option Int)) ])
      ~url
      ~responses:Responses.t
      `Delete
end

module Set = struct
  module Parameters = struct
    type t = {
      installation_id : string;
      key : string;
      vcs : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Terrat_api_components.Kv_set.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" /% Path.string / "kv" /% Path.string / "key" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Kv_record.t
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

  let url = "/api/v1/{vcs}/kv/{installation_id}/key/{key}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("vcs", Var (params.vcs, String));
           ("installation_id", Var (params.installation_id, String));
           ("key", Var (params.key, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get = struct
  module Parameters = struct
    module Select = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      committed : bool option; [@default None]
      idx : int option; [@default None]
      installation_id : string;
      key : string;
      select : Select.t option; [@default None]
      vcs : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    /% Path.string
    / "kv"
    /% Path.string
    / "key"
    /% Path.string
    /? option (bool "committed")
    /? option (int "idx")
    /? option (array (string "select"))

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Kv_record.t
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

  let url = "/api/v1/{vcs}/kv/{installation_id}/key/{key}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("vcs", Var (params.vcs, String));
           ("installation_id", Var (params.installation_id, String));
           ("key", Var (params.key, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("committed", Var (params.committed, Option Bool));
           ("idx", Var (params.idx, Option Int));
           ("select", Var (params.select, Option (Array String)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Iter = struct
  module Parameters = struct
    module Select = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      committed : bool option; [@default None]
      idx : int option; [@default None]
      include_data : bool option; [@default None]
      inclusive : bool option; [@default None]
      installation_id : string;
      key : string;
      limit : int option; [@default None]
      prefix : bool option; [@default None]
      select : Select.t option; [@default None]
      vcs : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    /% Path.string
    / "kv"
    /% Path.string
    / "iter"
    /% Path.string
    /? option (bool "committed")
    /? option (int "idx")
    /? option (int "limit")
    /? option (bool "include_data")
    /? option (bool "inclusive")
    /? option (bool "prefix")
    /? option (array (string "select"))

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Kv_record_list.t
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

  let url = "/api/v1/{vcs}/kv/{installation_id}/iter/{key}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("vcs", Var (params.vcs, String));
           ("installation_id", Var (params.installation_id, String));
           ("key", Var (params.key, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("committed", Var (params.committed, Option Bool));
           ("idx", Var (params.idx, Option Int));
           ("limit", Var (params.limit, Option Int));
           ("include_data", Var (params.include_data, Option Bool));
           ("inclusive", Var (params.inclusive, Option Bool));
           ("prefix", Var (params.prefix, Option Bool));
           ("select", Var (params.select, Option (Array String)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Count = struct
  module Parameters = struct
    type t = {
      committed : bool option; [@default None]
      installation_id : string;
      key : string;
      vcs : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v1"
    /% Path.string
    / "kv"
    /% Path.string
    / "count"
    / "key"
    /% Path.string
    /? option (bool "committed")

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Kv_count.t
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

  let url = "/api/v1/{vcs}/kv/{installation_id}/count/key/{key}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("vcs", Var (params.vcs, String));
           ("installation_id", Var (params.installation_id, String));
           ("key", Var (params.key, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("committed", Var (params.committed, Option Bool)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Commit = struct
  module Parameters = struct
    type t = {
      installation_id : string;
      vcs : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Terrat_api_components.Kv_commit.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" /% Path.string / "kv" /% Path.string / "commit"

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Kv_commit_result.t
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

  let url = "/api/v1/{vcs}/kv/{installation_id}/commit"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("vcs", Var (params.vcs, String));
           ("installation_id", Var (params.installation_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Cas = struct
  module Parameters = struct
    type t = {
      installation_id : string;
      key : string;
      vcs : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Terrat_api_components.Kv_cas.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" /% Path.string / "kv" /% Path.string / "cas" / "key" /% Path.string

  module Responses = struct
    module OK = struct
      type t = Terrat_api_components.Kv_record.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct end
    module Forbidden = struct end

    type t =
      [ `OK of OK.t
      | `Bad_request
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v1/{vcs}/kv/{installation_id}/cas/key/{key}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("vcs", Var (params.vcs, String));
           ("installation_id", Var (params.installation_id, String));
           ("key", Var (params.key, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end
