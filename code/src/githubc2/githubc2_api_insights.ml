module Get_user_stats = struct
  module Parameters = struct
    module Direction = struct
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

    module Sort = struct
      module Items = struct
        let t_of_yojson = function
          | `String "last_rate_limited_timestamp" -> Ok `Last_rate_limited_timestamp
          | `String "last_request_timestamp" -> Ok `Last_request_timestamp
          | `String "rate_limited_request_count" -> Ok `Rate_limited_request_count
          | `String "subject_name" -> Ok `Subject_name
          | `String "total_request_count" -> Ok `Total_request_count
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Last_rate_limited_timestamp -> `String "last_rate_limited_timestamp"
          | `Last_request_timestamp -> `String "last_request_timestamp"
          | `Rate_limited_request_count -> `String "rate_limited_request_count"
          | `Subject_name -> `String "subject_name"
          | `Total_request_count -> `String "total_request_count"

        type t =
          ([ `Last_rate_limited_timestamp
           | `Last_request_timestamp
           | `Rate_limited_request_count
           | `Subject_name
           | `Total_request_count
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving show, eq]
      end

      type t = Items.t list [@@deriving show, eq]
    end

    type t = {
      actor_name_substring : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      max_timestamp : string option; [@default None]
      min_timestamp : string;
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      sort : Sort.t option; [@default None]
      user_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "min_timestamp"
    /? option (string "max_timestamp")
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option
         (array
            (ud "sort" (fun value ->
                 CCResult.to_opt (Parameters.Sort.Items.t_of_yojson (`String value)))))
    /? option (string "actor_name_substring")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Api_insights_user_stats.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/insights/api/user-stats/{user_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("user_id", Var (params.user_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("min_timestamp", Var (params.min_timestamp, String));
           ("max_timestamp", Var (params.max_timestamp, Option String));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("sort", Var (params.sort, Option (Array (Enum Sort.Items.t_to_yojson))));
           ("actor_name_substring", Var (params.actor_name_substring, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_time_stats_by_actor = struct
  module Parameters = struct
    module Actor_type = struct
      let t_of_yojson = function
        | `String "classic_pat" -> Ok `Classic_pat
        | `String "fine_grained_pat" -> Ok `Fine_grained_pat
        | `String "github_app_user_to_server" -> Ok `Github_app_user_to_server
        | `String "installation" -> Ok `Installation
        | `String "oauth_app" -> Ok `Oauth_app
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Classic_pat -> `String "classic_pat"
        | `Fine_grained_pat -> `String "fine_grained_pat"
        | `Github_app_user_to_server -> `String "github_app_user_to_server"
        | `Installation -> `String "installation"
        | `Oauth_app -> `String "oauth_app"

      type t =
        ([ `Classic_pat
         | `Fine_grained_pat
         | `Github_app_user_to_server
         | `Installation
         | `Oauth_app
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      actor_id : int;
      actor_type : Actor_type.t;
      max_timestamp : string option; [@default None]
      min_timestamp : string;
      org : string;
      timestamp_increment : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "min_timestamp"
    /? option (string "max_timestamp")
    /? string "timestamp_increment"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Api_insights_time_stats.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/insights/api/time-stats/{actor_type}/{actor_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("actor_type", Var (params.actor_type, Enum Actor_type.t_to_yojson));
           ("actor_id", Var (params.actor_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("min_timestamp", Var (params.min_timestamp, String));
           ("max_timestamp", Var (params.max_timestamp, Option String));
           ("timestamp_increment", Var (params.timestamp_increment, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_time_stats_by_user = struct
  module Parameters = struct
    type t = {
      max_timestamp : string option; [@default None]
      min_timestamp : string;
      org : string;
      timestamp_increment : string;
      user_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "min_timestamp"
    /? option (string "max_timestamp")
    /? string "timestamp_increment"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Api_insights_time_stats.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/insights/api/time-stats/users/{user_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("user_id", Var (params.user_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("min_timestamp", Var (params.min_timestamp, String));
           ("max_timestamp", Var (params.max_timestamp, Option String));
           ("timestamp_increment", Var (params.timestamp_increment, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_time_stats = struct
  module Parameters = struct
    type t = {
      max_timestamp : string option; [@default None]
      min_timestamp : string;
      org : string;
      timestamp_increment : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "min_timestamp"
    /? option (string "max_timestamp")
    /? string "timestamp_increment"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Api_insights_time_stats.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/insights/api/time-stats"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("min_timestamp", Var (params.min_timestamp, String));
           ("max_timestamp", Var (params.max_timestamp, Option String));
           ("timestamp_increment", Var (params.timestamp_increment, String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_summary_stats_by_actor = struct
  module Parameters = struct
    module Actor_type = struct
      let t_of_yojson = function
        | `String "classic_pat" -> Ok `Classic_pat
        | `String "fine_grained_pat" -> Ok `Fine_grained_pat
        | `String "github_app_user_to_server" -> Ok `Github_app_user_to_server
        | `String "installation" -> Ok `Installation
        | `String "oauth_app" -> Ok `Oauth_app
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Classic_pat -> `String "classic_pat"
        | `Fine_grained_pat -> `String "fine_grained_pat"
        | `Github_app_user_to_server -> `String "github_app_user_to_server"
        | `Installation -> `String "installation"
        | `Oauth_app -> `String "oauth_app"

      type t =
        ([ `Classic_pat
         | `Fine_grained_pat
         | `Github_app_user_to_server
         | `Installation
         | `Oauth_app
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      actor_id : int;
      actor_type : Actor_type.t;
      max_timestamp : string option; [@default None]
      min_timestamp : string;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "min_timestamp" /? option (string "max_timestamp")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Api_insights_summary_stats.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/insights/api/summary-stats/{actor_type}/{actor_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("actor_type", Var (params.actor_type, Enum Actor_type.t_to_yojson));
           ("actor_id", Var (params.actor_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("min_timestamp", Var (params.min_timestamp, String));
           ("max_timestamp", Var (params.max_timestamp, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_summary_stats_by_user = struct
  module Parameters = struct
    type t = {
      max_timestamp : string option; [@default None]
      min_timestamp : string;
      org : string;
      user_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "min_timestamp" /? option (string "max_timestamp")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Api_insights_summary_stats.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/insights/api/summary-stats/users/{user_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("user_id", Var (params.user_id, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("min_timestamp", Var (params.min_timestamp, String));
           ("max_timestamp", Var (params.max_timestamp, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_summary_stats = struct
  module Parameters = struct
    type t = {
      max_timestamp : string option; [@default None]
      min_timestamp : string;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? string "min_timestamp" /? option (string "max_timestamp")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Api_insights_summary_stats.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/insights/api/summary-stats"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("min_timestamp", Var (params.min_timestamp, String));
           ("max_timestamp", Var (params.max_timestamp, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_subject_stats = struct
  module Parameters = struct
    module Direction = struct
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

    module Sort = struct
      module Items = struct
        let t_of_yojson = function
          | `String "last_rate_limited_timestamp" -> Ok `Last_rate_limited_timestamp
          | `String "last_request_timestamp" -> Ok `Last_request_timestamp
          | `String "rate_limited_request_count" -> Ok `Rate_limited_request_count
          | `String "subject_name" -> Ok `Subject_name
          | `String "total_request_count" -> Ok `Total_request_count
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Last_rate_limited_timestamp -> `String "last_rate_limited_timestamp"
          | `Last_request_timestamp -> `String "last_request_timestamp"
          | `Rate_limited_request_count -> `String "rate_limited_request_count"
          | `Subject_name -> `String "subject_name"
          | `Total_request_count -> `String "total_request_count"

        type t =
          ([ `Last_rate_limited_timestamp
           | `Last_request_timestamp
           | `Rate_limited_request_count
           | `Subject_name
           | `Total_request_count
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving show, eq]
      end

      type t = Items.t list [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t; [@default `Desc]
      max_timestamp : string option; [@default None]
      min_timestamp : string;
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      sort : Sort.t option; [@default None]
      subject_name_substring : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "min_timestamp"
    /? option (string "max_timestamp")
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option
         (array
            (ud "sort" (fun value ->
                 CCResult.to_opt (Parameters.Sort.Items.t_of_yojson (`String value)))))
    /? option (string "subject_name_substring")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Api_insights_subject_stats.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/insights/api/subject-stats"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("min_timestamp", Var (params.min_timestamp, String));
           ("max_timestamp", Var (params.max_timestamp, Option String));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("sort", Var (params.sort, Option (Array (Enum Sort.Items.t_to_yojson))));
           ("subject_name_substring", Var (params.subject_name_substring, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_route_stats_by_actor = struct
  module Parameters = struct
    module Actor_type = struct
      let t_of_yojson = function
        | `String "classic_pat" -> Ok `Classic_pat
        | `String "fine_grained_pat" -> Ok `Fine_grained_pat
        | `String "github_app_user_to_server" -> Ok `Github_app_user_to_server
        | `String "installation" -> Ok `Installation
        | `String "oauth_app" -> Ok `Oauth_app
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Classic_pat -> `String "classic_pat"
        | `Fine_grained_pat -> `String "fine_grained_pat"
        | `Github_app_user_to_server -> `String "github_app_user_to_server"
        | `Installation -> `String "installation"
        | `Oauth_app -> `String "oauth_app"

      type t =
        ([ `Classic_pat
         | `Fine_grained_pat
         | `Github_app_user_to_server
         | `Installation
         | `Oauth_app
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Direction = struct
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

    module Sort = struct
      module Items = struct
        let t_of_yojson = function
          | `String "api_route" -> Ok `Api_route
          | `String "http_method" -> Ok `Http_method
          | `String "last_rate_limited_timestamp" -> Ok `Last_rate_limited_timestamp
          | `String "last_request_timestamp" -> Ok `Last_request_timestamp
          | `String "rate_limited_request_count" -> Ok `Rate_limited_request_count
          | `String "total_request_count" -> Ok `Total_request_count
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Api_route -> `String "api_route"
          | `Http_method -> `String "http_method"
          | `Last_rate_limited_timestamp -> `String "last_rate_limited_timestamp"
          | `Last_request_timestamp -> `String "last_request_timestamp"
          | `Rate_limited_request_count -> `String "rate_limited_request_count"
          | `Total_request_count -> `String "total_request_count"

        type t =
          ([ `Api_route
           | `Http_method
           | `Last_rate_limited_timestamp
           | `Last_request_timestamp
           | `Rate_limited_request_count
           | `Total_request_count
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving show, eq]
      end

      type t = Items.t list [@@deriving show, eq]
    end

    type t = {
      actor_id : int;
      actor_type : Actor_type.t;
      api_route_substring : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      max_timestamp : string option; [@default None]
      min_timestamp : string;
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      sort : Sort.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? string "min_timestamp"
    /? option (string "max_timestamp")
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option
         (array
            (ud "sort" (fun value ->
                 CCResult.to_opt (Parameters.Sort.Items.t_of_yojson (`String value)))))
    /? option (string "api_route_substring")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Api_insights_route_stats.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/insights/api/route-stats/{actor_type}/{actor_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("actor_type", Var (params.actor_type, Enum Actor_type.t_to_yojson));
           ("actor_id", Var (params.actor_id, Int));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("min_timestamp", Var (params.min_timestamp, String));
           ("max_timestamp", Var (params.max_timestamp, Option String));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("sort", Var (params.sort, Option (Array (Enum Sort.Items.t_to_yojson))));
           ("api_route_substring", Var (params.api_route_substring, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
