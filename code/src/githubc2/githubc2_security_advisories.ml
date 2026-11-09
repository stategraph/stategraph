module Create_fork = struct
  module Parameters = struct
    type t = {
      ghsa_id : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module Accepted = struct
      type t = Githubc2_components.Full_repository.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Accepted of Accepted.t
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/security-advisories/{ghsa_id}/forks"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ghsa_id", Var (params.ghsa_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Create_repository_advisory_cve_request = struct
  module Parameters = struct
    type t = {
      ghsa_id : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module Accepted = struct
      include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Json_schema.Obj)
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Accepted of Accepted.t
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("202", Openapi.of_json_body (fun v -> `Accepted v) Accepted.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/security-advisories/{ghsa_id}/cve"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ghsa_id", Var (params.ghsa_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Update_repository_advisory = struct
  module Parameters = struct
    type t = {
      ghsa_id : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Githubc2_components.Repository_advisory_update.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_advisory.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/security-advisories/{ghsa_id}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ghsa_id", Var (params.ghsa_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Get_repository_advisory = struct
  module Parameters = struct
    type t = {
      ghsa_id : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_advisory.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/security-advisories/{ghsa_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ghsa_id", Var (params.ghsa_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_private_vulnerability_report = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Githubc2_components.Private_vulnerability_report_create.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Repository_advisory.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/security-advisories/reports"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Create_repository_advisory = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Githubc2_components.Repository_advisory_create.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Repository_advisory.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/security-advisories"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_repository_advisories = struct
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
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "published" -> Ok `Published
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Published -> `String "published"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Published
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "closed" -> Ok `Closed
        | `String "draft" -> Ok `Draft
        | `String "published" -> Ok `Published
        | `String "triage" -> Ok `Triage
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Closed -> `String "closed"
        | `Draft -> `String "draft"
        | `Published -> `String "published"
        | `Triage -> `String "triage"

      type t =
        ([ `Closed
         | `Draft
         | `Published
         | `Triage
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      owner : string;
      per_page : int; [@default 30]
      repo : string;
      sort : Sort.t; [@default `Created]
      state : State.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")
    /? option
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_advisory.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/security-advisories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
           ("state", Var (params.state, Option (Enum State.t_to_yojson)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_org_repository_advisories = struct
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
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "published" -> Ok `Published
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Published -> `String "published"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Published
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module State = struct
      let t_of_yojson = function
        | `String "closed" -> Ok `Closed
        | `String "draft" -> Ok `Draft
        | `String "published" -> Ok `Published
        | `String "triage" -> Ok `Triage
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Closed -> `String "closed"
        | `Draft -> `String "draft"
        | `Published -> `String "published"
        | `Triage -> `String "triage"

      type t =
        ([ `Closed
         | `Draft
         | `Published
         | `Triage
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      before : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      org : string;
      per_page : int; [@default 30]
      sort : Sort.t; [@default `Created]
      state : State.t option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")
    /? option
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Repository_advisory.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Bad_request = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/security-advisories"

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
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
           ("state", Var (params.state, Option (Enum State.t_to_yojson)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_global_advisory = struct
  module Parameters = struct
    type t = { ghsa_id : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Global_advisory.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/advisories/{ghsa_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("ghsa_id", Var (params.ghsa_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_global_advisories = struct
  module Parameters = struct
    module Affects = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        type t = string list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    module Cwes = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        type t = string list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
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

    module Severity = struct
      let t_of_yojson = function
        | `String "critical" -> Ok `Critical
        | `String "high" -> Ok `High
        | `String "low" -> Ok `Low
        | `String "medium" -> Ok `Medium
        | `String "unknown" -> Ok `Unknown
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Critical -> `String "critical"
        | `High -> `String "high"
        | `Low -> `String "low"
        | `Medium -> `String "medium"
        | `Unknown -> `String "unknown"

      type t =
        ([ `Critical
         | `High
         | `Low
         | `Medium
         | `Unknown
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "epss_percentage" -> Ok `Epss_percentage
        | `String "epss_percentile" -> Ok `Epss_percentile
        | `String "published" -> Ok `Published
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Epss_percentage -> `String "epss_percentage"
        | `Epss_percentile -> `String "epss_percentile"
        | `Published -> `String "published"
        | `Updated -> `String "updated"

      type t =
        ([ `Epss_percentage
         | `Epss_percentile
         | `Published
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Type = struct
      let t_of_yojson = function
        | `String "malware" -> Ok `Malware
        | `String "reviewed" -> Ok `Reviewed
        | `String "unreviewed" -> Ok `Unreviewed
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Malware -> `String "malware"
        | `Reviewed -> `String "reviewed"
        | `Unreviewed -> `String "unreviewed"

      type t =
        ([ `Malware
         | `Reviewed
         | `Unreviewed
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      affects : Affects.t option; [@default None]
      after : string option; [@default None]
      before : string option; [@default None]
      cve_id : string option; [@default None]
      cwes : Cwes.t option; [@default None]
      direction : Direction.t; [@default `Desc]
      ecosystem : Githubc2_components.Security_advisory_ecosystems.t option; [@default None]
      epss_percentage : string option; [@default None]
      epss_percentile : string option; [@default None]
      ghsa_id : string option; [@default None]
      is_withdrawn : bool option; [@default None]
      modified : string option; [@default None]
      per_page : int; [@default 30]
      published : string option; [@default None]
      severity : Severity.t option; [@default None]
      sort : Sort.t; [@default `Published]
      type_ : Type.t; [@default `Reviewed] [@key "type"]
      updated : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "ghsa_id")
    /? option_default
         `Reviewed
         (ud "type" (fun value -> CCResult.to_opt (Parameters.Type.t_of_yojson (`String value))))
    /? option (string "cve_id")
    /? option
         (ud "ecosystem" (fun value ->
              CCResult.to_opt
                (Githubc2_components.Security_advisory_ecosystems.t_of_yojson (`String value))))
    /? option
         (ud "severity" (fun value ->
              CCResult.to_opt (Parameters.Severity.t_of_yojson (`String value))))
    /? option
         (ud_array "cwes" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Cwes.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Cwes.V1 v)
                    (CCOption.sequence_l (CCList.map CCOption.return values));
                ]))
    /? option (bool "is_withdrawn")
    /? option
         (ud_array "affects" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Affects.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Affects.V1 v)
                    (CCOption.sequence_l (CCList.map CCOption.return values));
                ]))
    /? option (string "published")
    /? option (string "updated")
    /? option (string "modified")
    /? option (string "epss_percentage")
    /? option (string "epss_percentile")
    /? option (string "before")
    /? option (string "after")
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option_default 30 (int "per_page")
    /? option_default
         `Published
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Global_advisory.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error_simple.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Too_many_requests = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Too_many_requests of Too_many_requests.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("429", Openapi.of_json_body (fun v -> `Too_many_requests v) Too_many_requests.of_yojson);
      ]
  end

  let url = "/advisories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("ghsa_id", Var (params.ghsa_id, Option String));
           ("type", Var (params.type_, Enum Type.t_to_yojson));
           ("cve_id", Var (params.cve_id, Option String));
           ( "ecosystem",
             Var
               ( params.ecosystem,
                 Option (Enum Githubc2_components.Security_advisory_ecosystems.t_to_yojson) ) );
           ("severity", Var (params.severity, Option (Enum Severity.t_to_yojson)));
           ( "cwes",
             match params.cwes with
             | Some (Cwes.V0 v) -> Var (v, String)
             | Some (Cwes.V1 v) -> Var (v, Array String)
             | None -> Var ((), Null) );
           ("is_withdrawn", Var (params.is_withdrawn, Option Bool));
           ( "affects",
             match params.affects with
             | Some (Affects.V0 v) -> Var (v, String)
             | Some (Affects.V1 v) -> Var (v, Array String)
             | None -> Var ((), Null) );
           ("published", Var (params.published, Option String));
           ("updated", Var (params.updated, Option String));
           ("modified", Var (params.modified, Option String));
           ("epss_percentage", Var (params.epss_percentage, Option String));
           ("epss_percentile", Var (params.epss_percentile, Option String));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("per_page", Var (params.per_page, Int));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
