module DeleteApiV4UsersUserIdImpersonationTokensImpersonationTokenId = struct
  module Parameters = struct
    type t = {
      impersonation_token_id : int;
      user_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "users" /% Path.int / "impersonation_tokens" /% Path.int

  module Responses = struct
    module No_content = struct end

    type t = [ `No_content ] [@@deriving show, eq]

    let t = [ ("204", fun _ -> Ok `No_content) ]
  end

  let url = "/api/v4/users/{user_id}/impersonation_tokens/{impersonation_token_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("user_id", Var (params.user_id, Int));
           ("impersonation_token_id", Var (params.impersonation_token_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Delete
end

module GetApiV4UsersUserIdImpersonationTokensImpersonationTokenId = struct
  module Parameters = struct
    type t = {
      impersonation_token_id : int;
      user_id : int;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "users" /% Path.int / "impersonation_tokens" /% Path.int

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/users/{user_id}/impersonation_tokens/{impersonation_token_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("user_id", Var (params.user_id, Int));
           ("impersonation_token_id", Var (params.impersonation_token_id, Int));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module PostApiV4UsersUserIdImpersonationTokens = struct
  module Parameters = struct
    type t = { user_id : int } [@@deriving make, show, eq]
  end

  module Request_body = struct
    type t = Gitlabc_components.PostApiV4UsersUserIdImpersonationTokens.t
    [@@deriving yojson { strict = false; meta = true }, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "api" / "v4" / "users" /% Path.int / "impersonation_tokens"

  module Responses = struct
    module Created = struct end

    type t = [ `Created ] [@@deriving show, eq]

    let t = [ ("201", fun _ -> Ok `Created) ]
  end

  let url = "/api/v4/users/{user_id}/impersonation_tokens"

  let make ?body =
   fun params ->
    Openapi.Request.make
      ?body:(CCOption.map Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module GetApiV4UsersUserIdImpersonationTokens = struct
  module Parameters = struct
    module State = struct
      let t_of_yojson = function
        | `String "active" -> Ok `Active
        | `String "all" -> Ok `All
        | `String "inactive" -> Ok `Inactive
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Active -> `String "active"
        | `All -> `String "all"
        | `Inactive -> `String "inactive"

      type t =
        ([ `Active
         | `All
         | `Inactive
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      page : int; [@default 1]
      per_page : int; [@default 20]
      state : State.t; [@default `All]
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
    / "users"
    /% Path.int
    / "impersonation_tokens"
    /? option_default 1 (int "page")
    /? option_default 20 (int "per_page")
    /? option_default
         `All
         (ud "state" (fun value -> CCResult.to_opt (Parameters.State.t_of_yojson (`String value))))

  module Responses = struct
    module OK = struct end

    type t = [ `OK ] [@@deriving show, eq]

    let t = [ ("200", fun _ -> Ok `OK) ]
  end

  let url = "/api/v4/users/{user_id}/impersonation_tokens"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("user_id", Var (params.user_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("page", Var (params.page, Int));
           ("per_page", Var (params.per_page, Int));
           ("state", Var (params.state, Enum State.t_to_yojson));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
