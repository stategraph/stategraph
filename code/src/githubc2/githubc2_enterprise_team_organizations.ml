module Delete = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      enterprise_team : string; [@key "enterprise-team"]
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/enterprises/{enterprise}/teams/{enterprise-team}/organizations/{org}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("enterprise-team", Var (params.enterprise_team, String));
           ("org", Var (params.org, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      enterprise_team : string; [@key "enterprise-team"]
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Organization_simple.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `Created of Created.t ] [@@deriving show, eq]

    let t = [ ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson) ]
  end

  let url = "/enterprises/{enterprise}/teams/{enterprise-team}/organizations/{org}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("enterprise-team", Var (params.enterprise_team, String));
           ("org", Var (params.org, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_assignment = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      enterprise_team : string; [@key "enterprise-team"]
      org : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Organization_simple.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct end

    type t =
      [ `OK of OK.t
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson); ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/enterprises/{enterprise}/teams/{enterprise-team}/organizations/{org}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("enterprise-team", Var (params.enterprise_team, String));
           ("org", Var (params.org, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Bulk_remove = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      enterprise_team : string; [@key "enterprise-team"]
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Organization_slugs = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { organization_slugs : Organization_slugs.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/enterprises/{enterprise}/teams/{enterprise-team}/organizations/remove"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("enterprise-team", Var (params.enterprise_team, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Bulk_add = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      enterprise_team : string; [@key "enterprise-team"]
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Organization_slugs = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { organization_slugs : Organization_slugs.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Organization_simple.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/enterprises/{enterprise}/teams/{enterprise-team}/organizations/add"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("enterprise-team", Var (params.enterprise_team, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get_assignments = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      enterprise_team : string; [@key "enterprise-team"]
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 30 (int "per_page") /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Organization_simple.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/enterprises/{enterprise}/teams/{enterprise-team}/organizations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("enterprise", Var (params.enterprise, String));
           ("enterprise-team", Var (params.enterprise_team, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end
