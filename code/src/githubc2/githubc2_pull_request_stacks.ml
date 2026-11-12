module Unstack = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      stack_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "stacks" /% Path.int / "unstack"

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Base = struct
          module Primary = struct
            type t = { ref_ : string [@key "ref"] }
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Pull_requests = struct
          type t = Githubc2_components.Pull_request_stack_pull_request.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          base : Base.t;
          created_at : string;
          id : int;
          node_id : string;
          number : int;
          open_ : bool; [@key "open"]
          pull_requests : Pull_requests.t;
          url : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module No_content = struct end

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
      | `No_content
      | `Not_found of Not_found.t
      | `Conflict of Conflict.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("204", fun _ -> Ok `No_content);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("409", Openapi.of_json_body (fun v -> `Conflict v) Conflict.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/stacks/{stack_number}/unstack"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("stack_number", Var (params.stack_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Add = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      stack_number : int;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Pull_requests = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { pull_requests : Pull_requests.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "stacks" /% Path.int / "add"

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Base = struct
          module Primary = struct
            type t = { ref_ : string [@key "ref"] }
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Pull_requests = struct
          type t = Githubc2_components.Pull_request_stack_pull_request.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          base : Base.t;
          created_at : string;
          id : int;
          node_id : string;
          number : int;
          open_ : bool; [@key "open"]
          pull_requests : Pull_requests.t;
          url : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Value = struct
                module V0 = struct
                  type t = string option
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module V1 = struct
                  type t = int option [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module V2 = struct
                  module Items = struct
                    module V0 = struct
                      type t = string [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module V1 = struct
                      type t = int [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t =
                      | V0 of V0.t
                      | V1 of V1.t
                    [@@deriving show, eq]

                    let of_yojson =
                      Json_schema.one_of
                        (let open CCResult in
                         [
                           (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                           (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                         ])

                    let to_yojson = function
                      | V0 v -> V0.to_yojson v
                      | V1 v -> V1.to_yojson v
                  end

                  type t = Items.t list
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                type t =
                  | V0 of V0.t
                  | V1 of V1.t
                  | V2 of V2.t
                [@@deriving show, eq]

                let of_yojson =
                  Json_schema.one_of
                    (let open CCResult in
                     [
                       (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                       (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                       (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
                     ])

                let to_yojson = function
                  | V0 v -> V0.to_yojson v
                  | V1 v -> V1.to_yojson v
                  | V2 v -> V2.to_yojson v
              end

              type t = {
                code : string;
                field : string option; [@default None]
                index : int option; [@default None]
                message : string option; [@default None]
                resource : string option; [@default None]
                value : Value.t option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/repos/{owner}/{repo}/stacks/{stack_number}/add"

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
           ("stack_number", Var (params.stack_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module Get = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      stack_number : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "stacks" /% Path.int

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Base = struct
          module Primary = struct
            type t = { ref_ : string [@key "ref"] }
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Pull_requests = struct
          type t = Githubc2_components.Pull_request_stack_pull_request.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          base : Base.t;
          created_at : string;
          id : int;
          node_id : string;
          number : int;
          open_ : bool; [@key "open"]
          pull_requests : Pull_requests.t;
          url : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/repos/{owner}/{repo}/stacks/{stack_number}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("stack_number", Var (params.stack_number, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      module Pull_requests = struct
        type t = int list [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      type t = { pull_requests : Pull_requests.t }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "repos" /% Path.string /% Path.string / "stacks"

  module Responses = struct
    module Created = struct
      module Primary = struct
        module Base = struct
          module Primary = struct
            type t = { ref_ : string [@key "ref"] }
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Pull_requests = struct
          type t = Githubc2_components.Pull_request_stack_pull_request.t list
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          base : Base.t;
          created_at : string;
          id : int;
          node_id : string;
          number : int;
          open_ : bool; [@key "open"]
          pull_requests : Pull_requests.t;
          url : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Unprocessable_entity = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Value = struct
                module V0 = struct
                  type t = string option
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module V1 = struct
                  type t = int option [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module V2 = struct
                  module Items = struct
                    module V0 = struct
                      type t = string [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module V1 = struct
                      type t = int [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t =
                      | V0 of V0.t
                      | V1 of V1.t
                    [@@deriving show, eq]

                    let of_yojson =
                      Json_schema.one_of
                        (let open CCResult in
                         [
                           (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                           (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                         ])

                    let to_yojson = function
                      | V0 v -> V0.to_yojson v
                      | V1 v -> V1.to_yojson v
                  end

                  type t = Items.t list
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                type t =
                  | V0 of V0.t
                  | V1 of V1.t
                  | V2 of V2.t
                [@@deriving show, eq]

                let of_yojson =
                  Json_schema.one_of
                    (let open CCResult in
                     [
                       (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                       (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                       (fun v -> map (fun v -> V2 v) (V2.of_yojson v));
                     ])

                let to_yojson = function
                  | V0 v -> V0.to_yojson v
                  | V1 v -> V1.to_yojson v
                  | V2 v -> V2.to_yojson v
              end

              type t = {
                code : string;
                field : string option; [@default None]
                index : int option; [@default None]
                message : string option; [@default None]
                resource : string option; [@default None]
                value : Value.t option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
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

  let url = "/repos/{owner}/{repo}/stacks"

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

module List = struct
  module Parameters = struct
    type t = {
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      pull_request : int option; [@default None]
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "repos"
    /% Path.string
    /% Path.string
    / "stacks"
    /? option (int "pull_request")
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Pull_request_stack_minimal.t list
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
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/repos/{owner}/{repo}/stacks"

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
           ("pull_request", Var (params.pull_request, Option Int));
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
