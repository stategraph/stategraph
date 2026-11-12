module GetApiV4ProjectsIdGroups = struct
  module Parameters = struct
    module Skip_groups = struct
      type t = int list [@@deriving show, eq]
    end

    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      search : string option; [@default None]
      shared_min_access_level : int option; [@default None]
      shared_visible_only : bool; [@default false]
      skip_groups : Skip_groups.t option; [@default None]
      with_shared : bool; [@default false]
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
    / "groups"
    /? option (string "search")
    /? option (array (int "skip_groups"))
    /? option_default false (bool "with_shared")
    /? option_default false (bool "shared_visible_only")
    /? option
         (ud
            "shared_min_access_level"
            (fun value ->
               match CCInt.of_string value with
               | Some 10 -> Some 10
               | Some 15 -> Some 15
               | Some 20 -> Some 20
               | Some 30 -> Some 30
               | Some 40 -> Some 40
               | Some 50 -> Some 50
               | _ -> None
              : string -> int option))
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

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

  let url = "/api/v4/projects/{id}/groups"

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
           ("search", Var (params.search, Option String));
           ("skip_groups", Var (params.skip_groups, Option (Array Int)));
           ("with_shared", Var (params.with_shared, Bool));
           ("shared_visible_only", Var (params.shared_visible_only, Bool));
           ("shared_min_access_level", Var (params.shared_min_access_level, Option Int));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
