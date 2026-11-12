module GetApiV4GroupsIdBillableMembersUserIdMemberships = struct
  module Parameters = struct
    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      user_id : int;
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
    /% Path.string
    / "billable_members"
    /% Path.int
    / "memberships"
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/groups/{id}/billable_members/{user_id}/memberships"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("user_id", Var (params.user_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module GetApiV4GroupsIdBillableMembersUserIdIndirect = struct
  module Parameters = struct
    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      user_id : int;
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
    /% Path.string
    / "billable_members"
    /% Path.int
    / "indirect"
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/groups/{id}/billable_members/{user_id}/indirect"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("user_id", Var (params.user_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module DeleteApiV4GroupsIdBillableMembersUserId = struct
  module Parameters = struct
    type t = {
      id : string;
      user_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "groups" /% Path.string / "billable_members" /% Path.int

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/api/v4/groups/{id}/billable_members/{user_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("id", Var (params.id, String)); ("user_id", Var (params.user_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module GetApiV4GroupsIdBillableMembers = struct
  module Parameters = struct
    module Sort = struct
      let t_of_yojson = function
        | `String "access_level_asc" -> Ok `Access_level_asc
        | `String "access_level_desc" -> Ok `Access_level_desc
        | `String "last_activity_on_asc" -> Ok `Last_activity_on_asc
        | `String "last_activity_on_desc" -> Ok `Last_activity_on_desc
        | `String "last_joined" -> Ok `Last_joined
        | `String "name_asc" -> Ok `Name_asc
        | `String "name_desc" -> Ok `Name_desc
        | `String "oldest_joined" -> Ok `Oldest_joined
        | `String "oldest_sign_in" -> Ok `Oldest_sign_in
        | `String "recent_sign_in" -> Ok `Recent_sign_in
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Access_level_asc -> `String "access_level_asc"
        | `Access_level_desc -> `String "access_level_desc"
        | `Last_activity_on_asc -> `String "last_activity_on_asc"
        | `Last_activity_on_desc -> `String "last_activity_on_desc"
        | `Last_joined -> `String "last_joined"
        | `Name_asc -> `String "name_asc"
        | `Name_desc -> `String "name_desc"
        | `Oldest_joined -> `String "oldest_joined"
        | `Oldest_sign_in -> `String "oldest_sign_in"
        | `Recent_sign_in -> `String "recent_sign_in"

      type t =
        ([ `Access_level_asc
         | `Access_level_desc
         | `Last_activity_on_asc
         | `Last_activity_on_desc
         | `Last_joined
         | `Name_asc
         | `Name_desc
         | `Oldest_joined
         | `Oldest_sign_in
         | `Recent_sign_in
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      id : string;
      page : int; [@default 1]
      per_page : int; [@default 20]
      search : string option; [@default None]
      sort : Sort.t option; [@default None]
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
    /% Path.string
    / "billable_members"
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option (string "search")
    /? option
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/groups/{id}/billable_members"

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
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("search", Var (params.search, Option String));
           ("sort", Var (params.sort, Option (Enum Sort.t_to_yojson)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
