module GetApiV4GroupsIdUsers = struct
  module Parameters = struct
    type t = {
      active : bool; [@default false]
      id : int;
      include_saml_users : bool option; [@default None]
      include_service_accounts : bool option; [@default None]
      page : int; [@default 1]
      per_page : int; [@default 20]
      search : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "api"
    / "v4"
    / "groups"
    /% Path.int
    / "users"
    /? option (string "search")
    /? option_default false (bool "active")
    /? option (bool "include_saml_users")
    /? option (bool "include_service_accounts")
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

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

  let url = "/api/v4/groups/{id}/users"

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
           ("search", Var (params.search, Option String));
           ("active", Var (params.active, Bool));
           ("include_saml_users", Var (params.include_saml_users, Option Bool));
           ("include_service_accounts", Var (params.include_service_accounts, Option Bool));
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
