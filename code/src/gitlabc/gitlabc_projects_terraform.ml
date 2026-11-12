module DeleteApiV4ProjectsIdTerraformStateNameVersionsSerial = struct
  module Parameters = struct
    type t = {
      id : string;
      name : int;
      serial : int;
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
    / "terraform"
    / "state"
    /% Path.int
    / "versions"
    /% Path.int

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

  let url = "/api/v4/projects/{id}/terraform/state/{name}/versions/{serial}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("name", Var (params.name, Int));
           ("serial", Var (params.serial, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module GetApiV4ProjectsIdTerraformStateNameVersionsSerial = struct
  module Parameters = struct
    type t = {
      id : string;
      name : string;
      serial : int;
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
    / "terraform"
    / "state"
    /% Path.string
    / "versions"
    /% Path.int

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [ ("200", fun _ -> Ok `OK); ("403", fun _ -> Ok `Forbidden); ("404", fun _ -> Ok `Not_found) ]
  end

  let url = "/api/v4/projects/{id}/terraform/state/{name}/versions/{serial}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("id", Var (params.id, String));
           ("name", Var (params.name, String));
           ("serial", Var (params.serial, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4ProjectsIdTerraformStateNameLock = struct
  module Parameters = struct
    type t = {
      id : string option; [@default None] [@key "ID"]
      id_ : string;
      name : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "terraform"
    / "state"
    /% Path.int
    / "lock"
    /? option (string "ID")

  module Responses = struct
    module No_content = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Conflict = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `No_content
      | `Forbidden
      | `Not_found
      | `Conflict
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("409", fun _ -> Ok `Conflict);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id_}/terraform/state/{name}/lock"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id_", Var (params.id_, String)); ("name", Var (params.name, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("ID", Var (params.id, Option String)) ])
      ~url
      ~responses:Responses.t
      `Delete
end

module PostApiV4ProjectsIdTerraformStateNameLock = struct
  module Parameters = struct
    type t = {
      id_ : string;
      name : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4ProjectsIdTerraformStateNameLock.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "terraform" / "state" /% Path.int / "lock"

  module Responses = struct
    module OK = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Conflict = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK
      | `Forbidden
      | `Not_found
      | `Conflict
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("409", fun _ -> Ok `Conflict);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id_}/terraform/state/{name}/lock"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id_", Var (params.id_, String)); ("name", Var (params.name, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module DeleteApiV4ProjectsIdTerraformStateName = struct
  module Parameters = struct
    type t = {
      id_ : string;
      name : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "terraform" / "state" /% Path.int

  module Responses = struct
    module No_content = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `No_content
      | `Forbidden
      | `Not_found
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id_}/terraform/state/{name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id_", Var (params.id_, String)); ("name", Var (params.name, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PostApiV4ProjectsIdTerraformStateName = struct
  module Parameters = struct
    type t = {
      id_ : string;
      name : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "projects" /% Path.string / "terraform" / "state" /% Path.int

  module Responses = struct
    module OK = struct end
    module No_content = struct end
    module Forbidden = struct end
    module Request_entity_too_large = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK
      | `No_content
      | `Forbidden
      | `Request_entity_too_large
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("204", fun _ -> Ok `No_content);
        ("403", fun _ -> Ok `Forbidden);
        ("413", fun _ -> Ok `Request_entity_too_large);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id_}/terraform/state/{name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id_", Var (params.id_, String)); ("name", Var (params.name, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4ProjectsIdTerraformStateName = struct
  module Parameters = struct
    type t = {
      id : string option; [@default None] [@key "ID"]
      id_ : string;
      name : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "projects"
    /% Path.string
    / "terraform"
    / "state"
    /% Path.string
    /? option (string "ID")

  module Responses = struct
    module OK = struct end
    module No_content = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `OK
      | `No_content
      | `Forbidden
      | `Not_found
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("204", fun _ -> Ok `No_content);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/projects/{id_}/terraform/state/{name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id_", Var (params.id_, String)); ("name", Var (params.name, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("ID", Var (params.id, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end
