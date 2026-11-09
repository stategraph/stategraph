module DeleteApiV4ProjectsIdFeatureFlagsFeatureFlagName = struct
  module Parameters = struct
    type t = {
      feature_flag_name : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `No_content
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/feature_flags/{feature_flag_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("feature_flag_name", Var (params.feature_flag_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4ProjectsIdFeatureFlagsFeatureFlagName = struct
  module Parameters = struct
    type t = {
      feature_flag_name : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4ProjectsIdFeatureFlagsFeatureFlagName.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id}/feature_flags/{feature_flag_name}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("feature_flag_name", Var (params.feature_flag_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4ProjectsIdFeatureFlagsFeatureFlagName = struct
  module Parameters = struct
    type t = {
      feature_flag_name : string;
      id : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/feature_flags/{feature_flag_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("feature_flag_name", Var (params.feature_flag_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4ProjectsIdFeatureFlags = struct
  module Parameters = struct
    type t = { id : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdFeatureFlags.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Unauthorized = struct end
    module Forbidden = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Unauthorized
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v4/projects/{id}/feature_flags"

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

module GetApiV4ProjectsIdFeatureFlags = struct
  module Parameters = struct
    module Scope = struct
      let t_of_yojson = function
        | `String "disabled" -> Ok `Disabled
        | `String "enabled" -> Ok `Enabled
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Disabled -> `String "disabled"
        | `Enabled -> `String "enabled"

      type t =
        ([ `Disabled
         | `Enabled
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      scope : Scope.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/projects/{id}/feature_flags"

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
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
