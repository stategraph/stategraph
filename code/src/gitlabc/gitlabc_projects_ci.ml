module PostApiV4ProjectsIdCiLint = struct
  module Parameters = struct
    type t = { id : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdCiLint.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/projects/{id}/ci/lint"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdCiLint = struct
  module Parameters = struct
    type t = {
      content_ref : string option; [@default None]
      dry_run : bool; [@default false]
      dry_run_ref : string option; [@default None]
      id : int;
      include_jobs : bool option; [@default None]
      ref_ : string option; [@default None] [@key "ref"]
      sha : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "sha")
    /? option (string "content_ref")
    /? option_default false (bool "dry_run")
    /? option (bool "include_jobs")
    /? option (string "ref")
    /? option (string "dry_run_ref")

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

  let url = "/api/v4/projects/{id}/ci/lint"

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
           ("sha", Var (params.sha, Option String));
           ("content_ref", Var (params.content_ref, Option String));
           ("dry_run", Var (params.dry_run, Bool));
           ("include_jobs", Var (params.include_jobs, Option Bool));
           ("ref", Var (params.ref_, Option String));
           ("dry_run_ref", Var (params.dry_run_ref, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
