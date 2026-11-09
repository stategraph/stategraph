module PostApiV4AdminMigrationsTimestampMark = struct
  module Parameters = struct
    type t = { timestamp : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4AdminMigrationsTimestampMark.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Unauthorized = struct end
    module Forbidden = struct end
    module Not_found = struct end
    module Unprocessable_entity = struct end

    type t =
      [ `Created
      | `Unauthorized
      | `Forbidden
      | `Not_found
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("401", fun _ -> Ok `Unauthorized);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/api/v4/admin/migrations/{timestamp}/mark"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("timestamp", Var (params.timestamp, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4AdminDatabasesDatabaseNameDictionaryTablesTableName = struct
  module Parameters = struct
    module Database_name = struct
      let t_of_yojson = function
        | `String "ci" -> Ok `Ci
        | `String "main" -> Ok `Main
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Ci -> `String "ci"
        | `Main -> `String "main"

      type t =
        ([ `Ci
         | `Main
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      database_name : Database_name.t;
      table_name : string;
    }
    [@@deriving make, show, eq]
  end

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

  let url = "/api/v4/admin/databases/{database_name}/dictionary/tables/{table_name}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("database_name", Var (params.database_name, Enum Database_name.t_to_yojson));
           ("table_name", Var (params.table_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4AdminClustersClusterId = struct
  module Parameters = struct
    type t = { cluster_id : int } [@@deriving make, show, eq]
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

  let url = "/api/v4/admin/clusters/{cluster_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("cluster_id", Var (params.cluster_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4AdminClustersClusterId = struct
  module Parameters = struct
    type t = { cluster_id : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4AdminClustersClusterId.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module OK = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `OK
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/admin/clusters/{cluster_id}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("cluster_id", Var (params.cluster_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4AdminClustersClusterId = struct
  module Parameters = struct
    type t = { cluster_id : int } [@@deriving make, show, eq]
  end

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

  let url = "/api/v4/admin/clusters/{cluster_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("cluster_id", Var (params.cluster_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4AdminClustersAdd = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4AdminClustersAdd.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end
    module Forbidden = struct end
    module Not_found = struct end

    type t =
      [ `Created
      | `Bad_request
      | `Forbidden
      | `Not_found
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", fun _ -> Ok `Created);
        ("400", fun _ -> Ok `Bad_request);
        ("403", fun _ -> Ok `Forbidden);
        ("404", fun _ -> Ok `Not_found);
      ]
  end

  let url = "/api/v4/admin/clusters/add"

  let make ?body =
   fun () ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4AdminClusters = struct
  module Parameters = struct end

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

  let url = "/api/v4/admin/clusters"

  let make () =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4AdminCiVariablesKey = struct
  module Parameters = struct
    type t = { key : string } [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/api/v4/admin/ci/variables/{key}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("key", Var (params.key, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module PutApiV4AdminCiVariablesKey = struct
  module Parameters = struct
    type t = { key : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4AdminCiVariablesKey.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

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

  let url = "/api/v4/admin/ci/variables/{key}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("key", Var (params.key, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Put
end

module GetApiV4AdminCiVariablesKey = struct
  module Parameters = struct
    type t = { key : string } [@@deriving make, show, eq]
  end

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

  let url = "/api/v4/admin/ci/variables/{key}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("key", Var (params.key, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4AdminCiVariables = struct
  module Parameters = struct end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4AdminCiVariables.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  module Responses = struct
    module Created = struct end
    module Bad_request = struct end

    type t =
      [ `Created
      | `Bad_request
      ]
    [@@deriving show, eq]

    let t = [ ("201", fun _ -> Ok `Created); ("400", fun _ -> Ok `Bad_request) ]
  end

  let url = "/api/v4/admin/ci/variables"

  let make ?body =
   fun () ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4AdminCiVariables = struct
  module Parameters = struct
    type t = {
      page : int; [@default 1]
      per_page : int; [@default 20]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option_default 1 (int "page") /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/admin/ci/variables"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module PutApiV4AdminBatchedBackgroundMigrationsIdResume = struct
  module Parameters = struct
    type t = { id : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4AdminBatchedBackgroundMigrationsIdResume.t
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

  let url = "/api/v4/admin/batched_background_migrations/{id}/resume"

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
      `Put
end

module PutApiV4AdminBatchedBackgroundMigrationsIdPause = struct
  module Parameters = struct
    type t = { id : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PutApiV4AdminBatchedBackgroundMigrationsIdPause.t
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

  let url = "/api/v4/admin/batched_background_migrations/{id}/pause"

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
      `Put
end

module GetApiV4AdminBatchedBackgroundMigrationsId = struct
  module Parameters = struct
    module Database = struct
      let t_of_yojson = function
        | `String "ci" -> Ok `Ci
        | `String "embedding" -> Ok `Embedding
        | `String "geo" -> Ok `Geo
        | `String "main" -> Ok `Main
        | `String "sec" -> Ok `Sec
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Ci -> `String "ci"
        | `Embedding -> `String "embedding"
        | `Geo -> `String "geo"
        | `Main -> `String "main"
        | `Sec -> `String "sec"

      type t =
        ([ `Ci
         | `Embedding
         | `Geo
         | `Main
         | `Sec
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      database : Database.t; [@default `Main]
      id : int;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default
         `Main
         (ud "database" (fun value ->
              CCResult.to_opt (Parameters.Database.t_of_yojson (`String value))))

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

  let url = "/api/v4/admin/batched_background_migrations/{id}"

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
         [ ("database", Var (params.database, Enum Database.t_to_yojson)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4AdminBatchedBackgroundMigrations = struct
  module Parameters = struct
    module Database = struct
      let t_of_yojson = function
        | `String "ci" -> Ok `Ci
        | `String "embedding" -> Ok `Embedding
        | `String "geo" -> Ok `Geo
        | `String "main" -> Ok `Main
        | `String "sec" -> Ok `Sec
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Ci -> `String "ci"
        | `Embedding -> `String "embedding"
        | `Geo -> `String "geo"
        | `Main -> `String "main"
        | `Sec -> `String "sec"

      type t =
        ([ `Ci
         | `Embedding
         | `Geo
         | `Main
         | `Sec
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = { database : Database.t [@default `Main] } [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option_default
         `Main
         (ud "database" (fun value ->
              CCResult.to_opt (Parameters.Database.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct end
    module Unauthorized = struct end
    module Forbidden = struct end

    type t =
      [ `OK
      | `Unauthorized
      | `Forbidden
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", fun _ -> Ok `OK); ("401", fun _ -> Ok `Unauthorized); ("403", fun _ -> Ok `Forbidden);
      ]
  end

  let url = "/api/v4/admin/batched_background_migrations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("database", Var (params.database, Enum Database.t_to_yojson)) ])
      ~url
      ~responses:Responses.t
      `Get
end
