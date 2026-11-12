module DeleteApiV4ProjectsIdAlertManagementAlertsAlertIidMetricImagesMetricImageId = struct
  module Parameters = struct
    type t = {
      alert_iid : int;
      id : string;
      metric_image_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "alert_management_alerts"
    /% Path.int
    / "metric_images"
    /% Path.int

  module Responses = struct
    module No_content = struct end
    module Forbidden = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `No_content
      | `Forbidden
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", fun _ -> Ok `Forbidden);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url =
    "/api/v4/projects/{id}/alert_management_alerts/{alert_iid}/metric_images/{metric_image_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("alert_iid", Var (params.alert_iid, Int));
           ("metric_image_id", Var (params.metric_image_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdAlertManagementAlertsAlertIidMetricImagesMetricImageId = struct
  module Parameters = struct
    type t = {
      alert_iid : int;
      id : string;
      metric_image_id : int;
      url : string option; [@default None]
      url_text : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "alert_management_alerts"
    /% Path.int
    / "metric_images"
    /% Path.int

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK
      | `Forbidden
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("403", fun _ -> Ok `Forbidden);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url =
    "/api/v4/projects/{id}/alert_management_alerts/{alert_iid}/metric_images/{metric_image_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("alert_iid", Var (params.alert_iid, Int));
           ("metric_image_id", Var (params.metric_image_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module PostApiV4ProjectsIdAlertManagementAlertsAlertIidMetricImagesAuthorize = struct
  module Parameters = struct
    type t = {
      alert_iid : int;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "alert_management_alerts"
    /% Path.int
    / "metric_images"
    / "authorize"

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

  let url = "/api/v4/projects/{id}/alert_management_alerts/{alert_iid}/metric_images/authorize"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("alert_iid", Var (params.alert_iid, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module PostApiV4ProjectsIdAlertManagementAlertsAlertIidMetricImages = struct
  module Parameters = struct
    type t = {
      alert_iid : int;
      file : string;
      id : string;
      url : string option; [@default None]
      url_text : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "alert_management_alerts"
    /% Path.int
    / "metric_images"

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

  let url = "/api/v4/projects/{id}/alert_management_alerts/{alert_iid}/metric_images"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("alert_iid", Var (params.alert_iid, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdAlertManagementAlertsAlertIidMetricImages = struct
  module Parameters = struct
    type t = {
      alert_iid : int;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "alert_management_alerts"
    /% Path.int
    / "metric_images"

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

  let url = "/api/v4/projects/{id}/alert_management_alerts/{alert_iid}/metric_images"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("alert_iid", Var (params.alert_iid, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
