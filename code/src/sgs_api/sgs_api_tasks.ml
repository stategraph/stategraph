module Results = struct
  module Parameters = struct
    type t = { task_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tasks" /% Path.uuid / "results"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Task_results_count.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/api/v1/tasks/{task_id}/results"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("task_id", Var (params.task_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Result = struct
  module Parameters = struct
    type t = {
      idx : int option; [@default None]
      task_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tasks" /% Path.uuid / "result" /? option (int "idx")

  module Responses = struct
    module OK = struct
      type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unauthorized = struct end

    module Forbidden = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Sgs_api_components.Error_response.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unauthorized
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/api/v1/tasks/{task_id}/result"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("task_id", Var (params.task_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("idx", Var (params.idx, Option Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get = struct
  module Parameters = struct
    type t = { task_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tasks" /% Path.uuid

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Task.t
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

  let url = "/api/v1/tasks/{task_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("task_id", Var (params.task_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create = struct
  module Parameters = struct end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v1" / "tasks"

  module Responses = struct
    module OK = struct
      type t = Sgs_api_components.Task.t
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

  let url = "/api/v1/tasks"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end
