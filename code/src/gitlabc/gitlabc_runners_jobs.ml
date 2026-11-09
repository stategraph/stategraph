module GetApiV4RunnersIdJobs = struct
  module Parameters = struct
    module Order_by = struct
      let t_of_yojson = function
        | `String "id" -> Ok `Id
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Id -> `String "id"

      type t = ([ `Id ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson]) [@@deriving show, eq]
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
      cursor : string option; [@default None]
      id : int;
      order_by : Order_by.t option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 20]
      sort : Sort.t; [@default `Desc]
      status : Status.t option; [@default None]
      system_id : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "system_id")
    /? option
         (ud "status" (fun value -> CCResult.to_opt (Parameters.Status.t_of_yojson (`String value))))
    /? option
         (ud "order_by" (fun value ->
              CCResult.to_opt (Parameters.Order_by.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option (string "cursor")
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

  let url = "/api/v4/runners/{id}/jobs"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("system_id", Var (params.system_id, Option String));
           ("status", Var (params.status, Option (Enum Status.t_to_yojson)));
           ("order_by", Var (params.order_by, Option (Enum Order_by.t_to_yojson)));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("cursor", Var (params.cursor, Option String));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
