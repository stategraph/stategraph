module Delete_repo_secret = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/repos/{owner}/{repo}/dependabot/secrets/{secret_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("secret_name", Var (params.secret_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_or_update_repo_secret = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        encrypted_value : string option; [@default None]
        key_id : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Empty_object.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module No_content = struct end

    type t =
      [ `Created of Created.t
      | `No_content
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("204", fun _ -> Ok `No_content);
      ]
  end

  let url = "/repos/{owner}/{repo}/dependabot/secrets/{secret_name}"

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
           ("secret_name", Var (params.secret_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_repo_secret = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_secret.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/dependabot/secrets/{secret_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("secret_name", Var (params.secret_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_repo_public_key = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_public_key.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/dependabot/secrets/public-key"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_repo_secrets = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 30 (int "per_page") /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Secrets = struct
          type t = Githubc2_components.Dependabot_secret.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          secrets : Secrets.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/repos/{owner}/{repo}/dependabot/secrets"

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
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_alert = struct
  module Parameters = struct
    type t = {
      alert_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module V0 = struct
      module Agent_assignment = struct
        type t = {
          custom_agent : string option; [@default None]
          custom_instructions : string option; [@default None]
          model : string option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      module Assignees = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Dismissed_reason = struct
        let t_of_yojson = function
          | `String "fix_started" -> Ok `Fix_started
          | `String "inaccurate" -> Ok `Inaccurate
          | `String "no_bandwidth" -> Ok `No_bandwidth
          | `String "not_used" -> Ok `Not_used
          | `String "tolerable_risk" -> Ok `Tolerable_risk
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Fix_started -> `String "fix_started"
          | `Inaccurate -> `String "inaccurate"
          | `No_bandwidth -> `String "no_bandwidth"
          | `Not_used -> `String "not_used"
          | `Tolerable_risk -> `String "tolerable_risk"

        type t =
          ([ `Fix_started
           | `Inaccurate
           | `No_bandwidth
           | `Not_used
           | `Tolerable_risk
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module State = struct
        let t_of_yojson = function
          | `String "dismissed" -> Ok `Dismissed
          | `String "open" -> Ok `Open
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Dismissed -> `String "dismissed"
          | `Open -> `String "open"

        type t =
          ([ `Dismissed
           | `Open
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        agent_assignment : Agent_assignment.t option; [@default None]
        assignees : Assignees.t option; [@default None]
        dismissed_comment : string option; [@default None]
        dismissed_reason : Dismissed_reason.t option; [@default None]
        state : State.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    module V1 = struct
      module Agent_assignment = struct
        type t = {
          custom_agent : string option; [@default None]
          custom_instructions : string option; [@default None]
          model : string option; [@default None]
        }
        [@@deriving make, yojson { strict = false; meta = true }, show, eq]
      end

      module Assignees = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Dismissed_reason = struct
        let t_of_yojson = function
          | `String "fix_started" -> Ok `Fix_started
          | `String "inaccurate" -> Ok `Inaccurate
          | `String "no_bandwidth" -> Ok `No_bandwidth
          | `String "not_used" -> Ok `Not_used
          | `String "tolerable_risk" -> Ok `Tolerable_risk
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Fix_started -> `String "fix_started"
          | `Inaccurate -> `String "inaccurate"
          | `No_bandwidth -> `String "no_bandwidth"
          | `Not_used -> `String "not_used"
          | `Tolerable_risk -> `String "tolerable_risk"

        type t =
          ([ `Fix_started
           | `Inaccurate
           | `No_bandwidth
           | `Not_used
           | `Tolerable_risk
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module State = struct
        let t_of_yojson = function
          | `String "dismissed" -> Ok `Dismissed
          | `String "open" -> Ok `Open
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Dismissed -> `String "dismissed"
          | `Open -> `String "open"

        type t =
          ([ `Dismissed
           | `Open
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        agent_assignment : Agent_assignment.t option; [@default None]
        assignees : Assignees.t;
        dismissed_comment : string option; [@default None]
        dismissed_reason : Dismissed_reason.t option; [@default None]
        state : State.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    type t =
      | V0 of V0.t
      | V1 of V1.t
    [@@deriving show, eq]

    let of_yojson =
      Json_schema.any_of
        (let open CCResult in
         [
           (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
           (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
         ])

    let to_yojson = function
      | V0 v -> V0.to_yojson v
      | V1 v -> V1.to_yojson v
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_alert.t
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

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error_simple.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/dependabot/alerts/{alert_number}"

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
           ("alert_number", Var (params.alert_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Get_alert = struct
  module Parameters = struct
    type t = {
      alert_number : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_alert.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

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
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/dependabot/alerts/{alert_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("alert_number", Var (params.alert_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_alerts_for_repo = struct
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

    module Has = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        module Items = struct
          let t_of_yojson = function
            | `String "patch" -> Ok `Patch
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Patch -> `String "patch"

          type t = ([ `Patch ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving show, eq]
        end

        type t = Items.t list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    module Scope = struct
      let t_of_yojson = function
        | `String "development" -> Ok `Development
        | `String "runtime" -> Ok `Runtime
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Development -> `String "development"
        | `Runtime -> `String "runtime"

      type t =
        ([ `Development
         | `Runtime
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "epss_percentage" -> Ok `Epss_percentage
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Epss_percentage -> `String "epss_percentage"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Epss_percentage
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      assignee : string option; [@default None]
      before : string option; [@default None]
      classification : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      ecosystem : string option; [@default None]
      epss_percentage : string option; [@default None]
      has : Has.t option; [@default None]
      manifest : string option; [@default None]
      owner : string;
      package : string option; [@default None]
      per_page : int; [@default 30]
      relationship : string option; [@default None]
      repo : string;
      scope : Scope.t option; [@default None]
      severity : string option; [@default None]
      sort : Sort.t; [@default `Created]
      state : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "classification")
    /? option (string "state")
    /? option (string "severity")
    /? option (string "ecosystem")
    /? option (string "package")
    /? option (string "manifest")
    /? option (string "epss_percentage")
    /? option
         (ud_array "has" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Has.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Has.V1 v)
                    (CCOption.sequence_l
                       (CCList.map
                          (fun value ->
                            CCResult.to_opt (Parameters.Has.V1.Items.t_of_yojson (`String value)))
                          values));
                ]))
    /? option (string "assignee")
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option (string "relationship")
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_alert.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

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
      type t = Githubc2_components.Validation_error_simple.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/dependabot/alerts"

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
           ("classification", Var (params.classification, Option String));
           ("state", Var (params.state, Option String));
           ("severity", Var (params.severity, Option String));
           ("ecosystem", Var (params.ecosystem, Option String));
           ("package", Var (params.package, Option String));
           ("manifest", Var (params.manifest, Option String));
           ("epss_percentage", Var (params.epss_percentage, Option String));
           ( "has",
             match params.has with
             | Some (Has.V0 v) -> Var (v, String)
             | Some (Has.V1 v) -> Var (v, Array (Enum Has.V1.Items.t_to_yojson))
             | None -> Var ((), Null) );
           ("assignee", Var (params.assignee, Option String));
           ("scope", Var (params.scope, Option (Enum Scope.t_to_yojson)));
           ("relationship", Var (params.relationship, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Remove_selected_repo_from_org_secret = struct
  module Parameters = struct
    type t = {
      org : string;
      repository_id : int;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end
    module Conflict = struct end

    type t =
      [ `No_content
      | `Conflict
      ]
    [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content); ("409", fun _ -> Ok `Conflict) ]
  end

  let url = "/orgs/{org}/dependabot/secrets/{secret_name}/repositories/{repository_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("secret_name", Var (params.secret_name, String));
           ("repository_id", Var (params.repository_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Add_selected_repo_to_org_secret = struct
  module Parameters = struct
    type t = {
      org : string;
      repository_id : int;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end
    module Conflict = struct end

    type t =
      [ `No_content
      | `Conflict
      ]
    [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content); ("409", fun _ -> Ok `Conflict) ]
  end

  let url = "/orgs/{org}/dependabot/secrets/{secret_name}/repositories/{repository_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("secret_name", Var (params.secret_name, String));
           ("repository_id", Var (params.repository_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Set_selected_repos_for_org_secret = struct
  module Parameters = struct
    type t = {
      org : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Selected_repository_ids = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { selected_repository_ids : Selected_repository_ids.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/orgs/{org}/dependabot/secrets/{secret_name}/repositories"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("secret_name", Var (params.secret_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module List_selected_repos_for_org_secret = struct
  module Parameters = struct
    type t = {
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 1 (int "page") /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Repositories = struct
          type t = Githubc2_components.Minimal_repository.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          repositories : Repositories.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/dependabot/secrets/{secret_name}/repositories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("secret_name", Var (params.secret_name, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Delete_org_secret = struct
  module Parameters = struct
    type t = {
      org : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/orgs/{org}/dependabot/secrets/{secret_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("secret_name", Var (params.secret_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_or_update_org_secret = struct
  module Parameters = struct
    type t = {
      org : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Selected_repository_ids = struct
        module Items = struct
          module V0 = struct
            type t = int [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          module V1 = struct
            type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          type t =
            | V0 of V0.t
            | V1 of V1.t
          [@@deriving show, eq]

          let of_yojson =
            Json_schema.any_of
              (let open CCResult in
               [
                 (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                 (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
               ])

          let to_yojson = function
            | V0 v -> V0.to_yojson v
            | V1 v -> V1.to_yojson v
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Visibility = struct
        let t_of_yojson = function
          | `String "all" -> Ok `All
          | `String "private" -> Ok `Private
          | `String "selected" -> Ok `Selected
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `All -> `String "all"
          | `Private -> `String "private"
          | `Selected -> `String "selected"

        type t =
          ([ `All
           | `Private
           | `Selected
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        encrypted_value : string option; [@default None]
        key_id : string option; [@default None]
        selected_repository_ids : Selected_repository_ids.t option; [@default None]
        visibility : Visibility.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Empty_object.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module No_content = struct end

    type t =
      [ `Created of Created.t
      | `No_content
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("204", fun _ -> Ok `No_content);
      ]
  end

  let url = "/orgs/{org}/dependabot/secrets/{secret_name}"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("secret_name", Var (params.secret_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Get_org_secret = struct
  module Parameters = struct
    type t = {
      org : string;
      secret_name : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Organization_dependabot_secret.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/dependabot/secrets/{secret_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("secret_name", Var (params.secret_name, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_org_public_key = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_public_key.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/dependabot/secrets/public-key"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_org_secrets = struct
  module Parameters = struct
    type t = {
      org : string;
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
      module Primary = struct
        module Secrets = struct
          type t = Githubc2_components.Organization_dependabot_secret.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          secrets : Secrets.t;
          total_count : int;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/dependabot/secrets"

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
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Set_repository_access_default_level = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Default_level = struct
        let t_of_yojson = function
          | `String "internal" -> Ok `Internal
          | `String "public" -> Ok `Public
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Internal -> `String "internal"
          | `Public -> `String "public"

        type t =
          ([ `Internal
           | `Public
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { default_level : Default_level.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/dependabot/repository-access/default-level"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Update_repository_access_for_org = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Repository_ids_to_add = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Repository_ids_to_remove = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        repository_ids_to_add : Repository_ids_to_add.t option; [@default None]
        repository_ids_to_remove : Repository_ids_to_remove.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/dependabot/repository-access"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Repository_access_for_org = struct
  module Parameters = struct
    type t = {
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 1 (int "page") /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_repository_access_details.t
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

  let url = "/orgs/{org}/dependabot/repository-access"

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
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_alerts_for_org = struct
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

    module Has = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        module Items = struct
          let t_of_yojson = function
            | `String "deployment" -> Ok `Deployment
            | `String "patch" -> Ok `Patch
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Deployment -> `String "deployment"
            | `Patch -> `String "patch"

          type t =
            ([ `Deployment
             | `Patch
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving show, eq]
        end

        type t = Items.t list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    module Scope = struct
      let t_of_yojson = function
        | `String "development" -> Ok `Development
        | `String "runtime" -> Ok `Runtime
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Development -> `String "development"
        | `Runtime -> `String "runtime"

      type t =
        ([ `Development
         | `Runtime
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "epss_percentage" -> Ok `Epss_percentage
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Epss_percentage -> `String "epss_percentage"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Epss_percentage
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      artifact_registry : string option; [@default None]
      artifact_registry_url : string option; [@default None]
      assignee : string option; [@default None]
      before : string option; [@default None]
      classification : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      ecosystem : string option; [@default None]
      epss_percentage : string option; [@default None]
      has : Has.t option; [@default None]
      org : string;
      package : string option; [@default None]
      per_page : int; [@default 30]
      relationship : string option; [@default None]
      runtime_risk : string option; [@default None]
      scope : Scope.t option; [@default None]
      severity : string option; [@default None]
      sort : Sort.t; [@default `Created]
      state : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "classification")
    /? option (string "state")
    /? option (string "severity")
    /? option (string "ecosystem")
    /? option (string "package")
    /? option (string "epss_percentage")
    /? option (string "artifact_registry_url")
    /? option (string "artifact_registry")
    /? option
         (ud_array "has" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Has.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Has.V1 v)
                    (CCOption.sequence_l
                       (CCList.map
                          (fun value ->
                            CCResult.to_opt (Parameters.Has.V1.Items.t_of_yojson (`String value)))
                          values));
                ]))
    /? option (string "assignee")
    /? option (string "runtime_risk")
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option (string "relationship")
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_alert_with_repository.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

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
      type t = Githubc2_components.Validation_error_simple.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Bad_request of Bad_request.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/dependabot/alerts"

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
           ("classification", Var (params.classification, Option String));
           ("state", Var (params.state, Option String));
           ("severity", Var (params.severity, Option String));
           ("ecosystem", Var (params.ecosystem, Option String));
           ("package", Var (params.package, Option String));
           ("epss_percentage", Var (params.epss_percentage, Option String));
           ("artifact_registry_url", Var (params.artifact_registry_url, Option String));
           ("artifact_registry", Var (params.artifact_registry, Option String));
           ( "has",
             match params.has with
             | Some (Has.V0 v) -> Var (v, String)
             | Some (Has.V1 v) -> Var (v, Array (Enum Has.V1.Items.t_to_yojson))
             | None -> Var ((), Null) );
           ("assignee", Var (params.assignee, Option String));
           ("runtime_risk", Var (params.runtime_risk, Option String));
           ("scope", Var (params.scope, Option (Enum Scope.t_to_yojson)));
           ("relationship", Var (params.relationship, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Set_repository_access_default_level_for_enterprise = struct
  module Parameters = struct
    type t = { enterprise : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Default_level = struct
        let t_of_yojson = function
          | `String "internal" -> Ok `Internal
          | `String "public" -> Ok `Public
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Internal -> `String "internal"
          | `Public -> `String "public"

        type t =
          ([ `Internal
           | `Public
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { default_level : Default_level.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/dependabot/repository-access/default-level"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("enterprise", Var (params.enterprise, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module Update_repository_access_for_enterprise = struct
  module Parameters = struct
    type t = { enterprise : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Repository_ids_to_add = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Repository_ids_to_remove = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        repository_ids_to_add : Repository_ids_to_add.t option; [@default None]
        repository_ids_to_remove : Repository_ids_to_remove.t option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module No_content = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/enterprises/{enterprise}/dependabot/repository-access"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("enterprise", Var (params.enterprise, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Repository_access_for_enterprise = struct
  module Parameters = struct
    type t = {
      enterprise : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 1 (int "page") /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_repository_access_details.t
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

  let url = "/enterprises/{enterprise}/dependabot/repository-access"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("enterprise", Var (params.enterprise, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module List_alerts_for_enterprise = struct
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

    module Has = struct
      module V0 = struct
        type t = string [@@deriving show, eq]
      end

      module V1 = struct
        module Items = struct
          let t_of_yojson = function
            | `String "patch" -> Ok `Patch
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Patch -> `String "patch"

          type t = ([ `Patch ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving show, eq]
        end

        type t = Items.t list [@@deriving show, eq]
      end

      type t =
        | V0 of V0.t
        | V1 of V1.t
      [@@deriving show, eq]
    end

    module Scope = struct
      let t_of_yojson = function
        | `String "development" -> Ok `Development
        | `String "runtime" -> Ok `Runtime
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Development -> `String "development"
        | `Runtime -> `String "runtime"

      type t =
        ([ `Development
         | `Runtime
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "created" -> Ok `Created
        | `String "epss_percentage" -> Ok `Epss_percentage
        | `String "updated" -> Ok `Updated
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created -> `String "created"
        | `Epss_percentage -> `String "epss_percentage"
        | `Updated -> `String "updated"

      type t =
        ([ `Created
         | `Epss_percentage
         | `Updated
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      after : string option; [@default None]
      assignee : string option; [@default None]
      before : string option; [@default None]
      classification : string option; [@default None]
      direction : Direction.t; [@default `Desc]
      ecosystem : string option; [@default None]
      enterprise : string;
      epss_percentage : string option; [@default None]
      has : Has.t option; [@default None]
      package : string option; [@default None]
      per_page : int; [@default 30]
      relationship : string option; [@default None]
      scope : Scope.t option; [@default None]
      severity : string option; [@default None]
      sort : Sort.t; [@default `Created]
      state : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "classification")
    /? option (string "state")
    /? option (string "severity")
    /? option (string "ecosystem")
    /? option (string "package")
    /? option (string "epss_percentage")
    /? option
         (ud_array "has" (fun values ->
              CCOption.choice
                [
                  CCOption.map
                    (fun v -> Parameters.Has.V0 v)
                    (match values with
                    | value :: [] -> CCOption.return value
                    | _ -> None);
                  CCOption.map
                    (fun v -> Parameters.Has.V1 v)
                    (CCOption.sequence_l
                       (CCList.map
                          (fun value ->
                            CCResult.to_opt (Parameters.Has.V1.Items.t_of_yojson (`String value)))
                          values));
                ]))
    /? option (string "assignee")
    /? option
         (ud "scope" (fun value -> CCResult.to_opt (Parameters.Scope.t_of_yojson (`String value))))
    /? option (string "relationship")
    /? option_default
         `Created
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "before")
    /? option (string "after")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Dependabot_alert_with_repository.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error_simple.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/enterprises/{enterprise}/dependabot/alerts"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("enterprise", Var (params.enterprise, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("classification", Var (params.classification, Option String));
           ("state", Var (params.state, Option String));
           ("severity", Var (params.severity, Option String));
           ("ecosystem", Var (params.ecosystem, Option String));
           ("package", Var (params.package, Option String));
           ("epss_percentage", Var (params.epss_percentage, Option String));
           ( "has",
             match params.has with
             | Some (Has.V0 v) -> Var (v, String)
             | Some (Has.V1 v) -> Var (v, Array (Enum Has.V1.Items.t_to_yojson))
             | None -> Var ((), Null) );
           ("assignee", Var (params.assignee, Option String));
           ("scope", Var (params.scope, Option (Enum Scope.t_to_yojson)));
           ("relationship", Var (params.relationship, Option String));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("before", Var (params.before, Option String));
           ("after", Var (params.after, Option String));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
