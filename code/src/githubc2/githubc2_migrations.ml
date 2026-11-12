module List_repos_for_authenticated_user = struct
  module Parameters = struct
    type t = {
      migration_id : int;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "migrations"
    /% Path.int
    / "repositories"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Minimal_repository.t list
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

  let url = "/user/migrations/{migration_id}/repositories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("migration_id", Var (params.migration_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Unlock_repo_for_authenticated_user = struct
  module Parameters = struct
    type t = {
      migration_id : int;
      repo_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "user" / "migrations" /% Path.int / "repos" /% Path.string / "lock"

  module Responses = struct
    module No_content = struct end
    module Not_modified = struct end

    module Unauthorized = struct
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

    type t =
      [ `No_content
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/migrations/{migration_id}/repos/{repo_name}/lock"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("migration_id", Var (params.migration_id, Int));
           ("repo_name", Var (params.repo_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Delete_archive_for_authenticated_user = struct
  module Parameters = struct
    type t = { migration_id : int } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "user" / "migrations" /% Path.int / "archive"

  module Responses = struct
    module No_content = struct end
    module Not_modified = struct end

    module Unauthorized = struct
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

    type t =
      [ `No_content
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/migrations/{migration_id}/archive"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("migration_id", Var (params.migration_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Get_archive_for_authenticated_user = struct
  module Parameters = struct
    type t = { migration_id : int } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "user" / "migrations" /% Path.int / "archive"

  module Responses = struct
    module Found = struct end
    module Not_modified = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Found
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("302", fun _ -> Ok `Found);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/user/migrations/{migration_id}/archive"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("migration_id", Var (params.migration_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_status_for_authenticated_user = struct
  module Parameters = struct
    module Exclude = struct
      type t = string list [@@deriving show, eq]
    end

    type t = {
      exclude : Exclude.t option; [@default None]
      migration_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "user" / "migrations" /% Path.int /? option (array (string "exclude"))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Migration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Unauthorized = struct
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

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/user/migrations/{migration_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("migration_id", Var (params.migration_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("exclude", Var (params.exclude, Option (Array String))) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Start_for_authenticated_user = struct
  module Parameters = struct end

  module Request_body = struct
    module Primary = struct
      module Exclude = struct
        module Items = struct
          let t_of_yojson = function
            | `String "repositories" -> Ok `Repositories
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Repositories -> `String "repositories"

          type t = ([ `Repositories ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Repositories = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        exclude : Exclude.t option; [@default None]
        exclude_attachments : bool option; [@default None]
        exclude_git_data : bool option; [@default None]
        exclude_metadata : bool option; [@default None]
        exclude_owner_projects : bool option; [@default None]
        exclude_releases : bool option; [@default None]
        lock_repositories : bool option; [@default None]
        org_metadata_only : bool; [@default false]
        repositories : Repositories.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "user" / "migrations"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Migration.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/user/migrations"

  let make ~body =
   fun () ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:[]
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_for_authenticated_user = struct
  module Parameters = struct
    type t = {
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "user"
    / "migrations"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Migration.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_modified = struct end

    module Unauthorized = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Forbidden = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_modified
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("304", fun _ -> Ok `Not_modified);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
      ]
  end

  let url = "/user/migrations"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Set_lfs_preference = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Use_lfs = struct
        let t_of_yojson = function
          | `String "opt_in" -> Ok `Opt_in
          | `String "opt_out" -> Ok `Opt_out
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Opt_in -> `String "opt_in"
          | `Opt_out -> `String "opt_out"

        type t =
          ([ `Opt_in
           | `Opt_out
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { use_lfs : Use_lfs.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "import" / "lfs"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Import.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/import/lfs"

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
      `Patch
end

module Get_large_files = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "import" / "large_files"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Porter_large_file.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/import/large_files"

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

module Map_commit_author = struct
  module Parameters = struct
    type t = {
      author_id : int;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = {
      email : string option; [@default None]
      name : string option; [@default None]
    }
    [@@deriving make, yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "import" / "authors" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Porter_author.t
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

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/import/authors/{author_id}"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("author_id", Var (params.author_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Get_commit_authors = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      since : int option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "import" / "authors" /? option (int "since")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Porter_author.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/import/authors"

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
         [ ("since", Var (params.since, Option Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Update_import = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Vcs = struct
        let t_of_yojson = function
          | `String "git" -> Ok `Git
          | `String "mercurial" -> Ok `Mercurial
          | `String "subversion" -> Ok `Subversion
          | `String "tfvc" -> Ok `Tfvc
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Git -> `String "git"
          | `Mercurial -> `String "mercurial"
          | `Subversion -> `String "subversion"
          | `Tfvc -> `String "tfvc"

        type t =
          ([ `Git
           | `Mercurial
           | `Subversion
           | `Tfvc
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        tfvc_project : string option; [@default None]
        vcs : Vcs.t option; [@default None]
        vcs_password : string option; [@default None]
        vcs_username : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "import"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Import.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/import"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Cancel_import = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "import"

  module Responses = struct
    module No_content = struct end

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/import"

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
      `Delete
end

module Start_import = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Vcs = struct
        let t_of_yojson = function
          | `String "git" -> Ok `Git
          | `String "mercurial" -> Ok `Mercurial
          | `String "subversion" -> Ok `Subversion
          | `String "tfvc" -> Ok `Tfvc
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Git -> `String "git"
          | `Mercurial -> `String "mercurial"
          | `Subversion -> `String "subversion"
          | `Tfvc -> `String "tfvc"

        type t =
          ([ `Git
           | `Mercurial
           | `Subversion
           | `Tfvc
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        tfvc_project : string option; [@default None]
        vcs : Vcs.t option; [@default None]
        vcs_password : string option; [@default None]
        vcs_url : string;
        vcs_username : string option; [@default None]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "import"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Import.t
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

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/import"

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
      `Put
end

module Get_import_status = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "import"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Import.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Service_unavailable = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Service_unavailable of Service_unavailable.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("503", Openapi.of_json_body (fun v -> `Service_unavailable v) Service_unavailable.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/import"

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

module List_repos_for_org = struct
  module Parameters = struct
    type t = {
      migration_id : int;
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "migrations"
    /% Path.int
    / "repositories"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Minimal_repository.t list
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

  let url = "/orgs/{org}/migrations/{migration_id}/repositories"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("migration_id", Var (params.migration_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("per_page", Var (params.per_page, Int)); ("page", Var (params.page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Unlock_repo_for_org = struct
  module Parameters = struct
    type t = {
      migration_id : int;
      org : string;
      repo_name : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "migrations" /% Path.int / "repos" /% Path.string / "lock"

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/migrations/{migration_id}/repos/{repo_name}/lock"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("org", Var (params.org, String));
           ("migration_id", Var (params.migration_id, Int));
           ("repo_name", Var (params.repo_name, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Delete_archive_for_org = struct
  module Parameters = struct
    type t = {
      migration_id : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "migrations" /% Path.int / "archive"

  module Responses = struct
    module No_content = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `No_content
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/migrations/{migration_id}/archive"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("migration_id", Var (params.migration_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Download_archive_for_org = struct
  module Parameters = struct
    type t = {
      migration_id : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "migrations" /% Path.int / "archive"

  module Responses = struct
    module Found = struct end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Found
      | `Not_found of Not_found.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("302", fun _ -> Ok `Found);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
      ]
  end

  let url = "/orgs/{org}/migrations/{migration_id}/archive"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("migration_id", Var (params.migration_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_status_for_org = struct
  module Parameters = struct
    module Exclude = struct
      module Items = struct
        let t_of_yojson = function
          | `String "repositories" -> Ok `Repositories
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Repositories -> `String "repositories"

        type t = ([ `Repositories ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving show, eq]
      end

      type t = Items.t list [@@deriving show, eq]
    end

    type t = {
      exclude : Exclude.t option; [@default None]
      migration_id : int;
      org : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "migrations"
    /% Path.int
    /? option
         (array
            (ud "exclude" (fun value ->
                 CCResult.to_opt (Parameters.Exclude.Items.t_of_yojson (`String value)))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Migration.t
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

  let url = "/orgs/{org}/migrations/{migration_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("org", Var (params.org, String)); ("migration_id", Var (params.migration_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("exclude", Var (params.exclude, Option (Array (Enum Exclude.Items.t_to_yojson)))) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Start_for_org = struct
  module Parameters = struct
    type t = { org : string } [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Exclude = struct
        module Items = struct
          let t_of_yojson = function
            | `String "repositories" -> Ok `Repositories
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Repositories -> `String "repositories"

          type t = ([ `Repositories ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      module Repositories = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        exclude : Exclude.t option; [@default None]
        exclude_attachments : bool; [@default false]
        exclude_git_data : bool; [@default false]
        exclude_metadata : bool; [@default false]
        exclude_owner_projects : bool; [@default false]
        exclude_releases : bool; [@default false]
        lock_repositories : bool; [@default false]
        org_metadata_only : bool; [@default false]
        repositories : Repositories.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "orgs" /% Path.string / "migrations"

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Migration.t
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
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/orgs/{org}/migrations"

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
      `Post
end

module List_for_org = struct
  module Parameters = struct
    module Exclude = struct
      module Items = struct
        let t_of_yojson = function
          | `String "repositories" -> Ok `Repositories
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Repositories -> `String "repositories"

        type t = ([ `Repositories ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving show, eq]
      end

      type t = Items.t list [@@deriving show, eq]
    end

    type t = {
      exclude : Exclude.t option; [@default None]
      org : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "orgs"
    /% Path.string
    / "migrations"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option
         (array
            (ud "exclude" (fun value ->
                 CCResult.to_opt (Parameters.Exclude.Items.t_of_yojson (`String value)))))

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Migration.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t = [ `OK of OK.t ] [@@deriving show, eq]

    let t = [ ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson) ]
  end

  let url = "/orgs/{org}/migrations"

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
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("exclude", Var (params.exclude, Option (Array (Enum Exclude.Items.t_to_yojson))));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
