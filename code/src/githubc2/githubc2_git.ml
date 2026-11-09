module Get_tree = struct
  module Parameters = struct
    type t = {
      owner : string;
      recursive : string option; [@default None]
      repo : string;
      tree_sha : string;
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route /? option (string "recursive")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Git_tree.t
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
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/git/trees/{tree_sha}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("tree_sha", Var (params.tree_sha, String));
         ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("recursive", Var (params.recursive, Option String)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Create_tree = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Tree = struct
        module Items = struct
          module Primary = struct
            module Mode = struct
              let t_of_yojson = function
                | `String "040000" -> Ok `V_040000
                | `String "100644" -> Ok `V_100644
                | `String "100755" -> Ok `V_100755
                | `String "120000" -> Ok `V_120000
                | `String "160000" -> Ok `V_160000
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `V_040000 -> `String "040000"
                | `V_100644 -> `String "100644"
                | `V_100755 -> `String "100755"
                | `V_120000 -> `String "120000"
                | `V_160000 -> `String "160000"

              type t =
                ([ `V_040000
                 | `V_100644
                 | `V_100755
                 | `V_120000
                 | `V_160000
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            module Type = struct
              let t_of_yojson = function
                | `String "blob" -> Ok `Blob
                | `String "commit" -> Ok `Commit
                | `String "tree" -> Ok `Tree
                | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

              let t_to_yojson = function
                | `Blob -> `String "blob"
                | `Commit -> `String "commit"
                | `Tree -> `String "tree"

              type t =
                ([ `Blob
                 | `Commit
                 | `Tree
                 ]
                [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            type t = {
              content : string option; [@default None]
              mode : Mode.t option; [@default None]
              path : string option; [@default None]
              sha : string option; [@default None]
              type_ : Type.t option; [@default None] [@key "type"]
            }
            [@@deriving make, yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        type t = Items.t list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        base_tree : string option; [@default None]
        tree : Tree.t;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Git_tree.t
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
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/git/trees"

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

module Get_tag = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      tag_sha : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Git_tag.t
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

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/git/tags/{tag_sha}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("tag_sha", Var (params.tag_sha, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_tag = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Tagger = struct
        module Primary = struct
          type t = {
            date : string option; [@default None]
            email : string;
            name : string;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Type = struct
        let t_of_yojson = function
          | `String "blob" -> Ok `Blob
          | `String "commit" -> Ok `Commit
          | `String "tree" -> Ok `Tree
          | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

        let t_to_yojson = function
          | `Blob -> `String "blob"
          | `Commit -> `String "commit"
          | `Tree -> `String "tree"

        type t =
          ([ `Blob
           | `Commit
           | `Tree
           ]
          [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        message : string;
        object_ : string; [@key "object"]
        tag : string;
        tagger : Tagger.t option; [@default None]
        type_ : Type.t; [@key "type"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Git_tag.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/git/tags"

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

module Update_ref = struct
  module Parameters = struct
    type t = {
      owner : string;
      ref_ : string; [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        force : bool; [@default false]
        sha : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Git_ref.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/git/refs/{ref}"

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
           ("ref", Var (params.ref_, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Patch
end

module Delete_ref = struct
  module Parameters = struct
    type t = {
      owner : string;
      ref_ : string; [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module No_content = struct end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct end

    type t =
      [ `No_content
      | `Conflict of Conflict.t
      | `Unprocessable_entity
      ]
    [@@deriving show, eq]

    let t =
      [
        ("204", fun _ -> Ok `No_content);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ("422", fun _ -> Ok `Unprocessable_entity);
      ]
  end

  let url = "/repos/{owner}/{repo}/git/refs/{ref}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ref", Var (params.ref_, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module Create_ref = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        ref_ : string; [@key "ref"]
        sha : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Git_ref.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/git/refs"

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

module Get_ref = struct
  module Parameters = struct
    type t = {
      owner : string;
      ref_ : string; [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Git_ref.t
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

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/git/ref/{ref}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ref", Var (params.ref_, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_matching_refs = struct
  module Parameters = struct
    type t = {
      owner : string;
      ref_ : string; [@key "ref"]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Git_ref.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Conflict = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/git/matching-refs/{ref}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("ref", Var (params.ref_, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Get_commit = struct
  module Parameters = struct
    type t = {
      commit_sha : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Git_commit.t
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

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
      ]
  end

  let url = "/repos/{owner}/{repo}/git/commits/{commit_sha}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("commit_sha", Var (params.commit_sha, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_commit = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Author = struct
        module Primary = struct
          type t = {
            date : string option; [@default None]
            email : string;
            name : string;
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Committer = struct
        module Primary = struct
          type t = {
            date : string option; [@default None]
            email : string option; [@default None]
            name : string option; [@default None]
          }
          [@@deriving make, yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module Parents = struct
        type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = {
        author : Author.t option; [@default None]
        committer : Committer.t option; [@default None]
        message : string;
        parents : Parents.t option; [@default None]
        signature : string option; [@default None]
        tree : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Git_commit.t
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
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `Created of Created.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/git/commits"

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

module Get_blob = struct
  module Parameters = struct
    type t = {
      file_sha : string;
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Blob.t
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
      type t = Githubc2_components.Validation_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/git/blobs/{file_sha}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("file_sha", Var (params.file_sha, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_blob = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        content : string;
        encoding : string; [@default "utf-8"]
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  module Responses = struct
    module Created = struct
      type t = Githubc2_components.Short_blob.t
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
      type t =
        | Validation_error of Githubc2_components.Validation_error.t
        | Repository_rule_violation_error of Githubc2_components.Repository_rule_violation_error.t
      [@@deriving show, eq]

      let of_yojson =
        Json_schema.one_of
          (let open CCResult in
           [
             (fun v ->
               map (fun v -> Validation_error v) (Githubc2_components.Validation_error.of_yojson v));
             (fun v ->
               map
                 (fun v -> Repository_rule_violation_error v)
                 (Githubc2_components.Repository_rule_violation_error.of_yojson v));
           ])

      let to_yojson = function
        | Validation_error v -> Githubc2_components.Validation_error.to_yojson v
        | Repository_rule_violation_error v ->
            Githubc2_components.Repository_rule_violation_error.to_yojson v
    end

    type t =
      [ `Created of Created.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/git/blobs"

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
