module GetApiV4GroupsIdProvisionedUsers = struct
  module Parameters = struct
    type t = {
      active : bool; [@default false]
      blocked : bool; [@default false]
      created_after : string option; [@default None]
      created_before : string option; [@default None]
      id : int;
      page : int; [@default 1]
      per_page : int; [@default 20]
      search : string option; [@default None]
      username : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route base_route =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    base_route
    /? option (string "username")
    /? option (string "search")
    /? option_default false (bool "active")
    /? option_default false (bool "blocked")
    /? option (string "created_after")
    /? option (string "created_before")
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/groups/{id}/provisioned_users"

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
           ("username", Var (params.username, Option String));
           ("search", Var (params.search, Option String));
           ("active", Var (params.active, Bool));
           ("blocked", Var (params.blocked, Bool));
           ("created_after", Var (params.created_after, Option String));
           ("created_before", Var (params.created_before, Option String));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
