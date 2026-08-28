module Oauth = struct
  module Http = Abb_curl.Make (Abb)

  module Sql = struct
    let read s = Pgsql_io.clean_string s

    let select_user_token () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* token *)
        Ret.text
        //
        (* expired *)
        Ret.boolean
        //
        (* refresh_token *)
        Ret.text
        /^ read [%blob "sql/select_gitlab_user2_tokens.sql"]
        /% Var.uuid "user_id")

    let update_gitlab_user2_tokens () =
      Pgsql_io.Typed_sql.(
        sql
        /^ read [%blob "sql/update_gitlab_user2_tokens.sql"]
        /% Var.uuid "user_id"
        /% Var.text "token"
        /% Var.(option (timestamptz "expiration"))
        /% Var.(option (text "refresh_token"))
        /% Var.(option (timestamptz "refresh_expiration")))
  end

  type authorize_err =
    [ `Authorize_err of string
    | Http.request_err
    ]
  [@@deriving show]

  type access_token_err =
    [ `Refresh_err of string
    | `Bad_refresh_token
    | `User_not_found of Terrat_user.t
    | Pgsql_io.err
    | Http.request_err
    ]
  [@@deriving show]

  module Response = struct
    type t = {
      access_token : string;
      scope : string;
      token_type : string;
      refresh_token : string option; [@default None]
      refresh_token_expires_in : int option; [@default None]
      expires_in : int option; [@default None]
    }
    [@@deriving of_yojson { strict = false }, show]
  end

  let authorize ~config ~server_api_base code =
    let open Abb.Future.Infix_monad in
    let headers =
      Http.Headers.of_list
        [
          ("user-agent", "Terrateam");
          ("content-type", "application/json");
          ("accept", "application/json");
        ]
    in
    let uri =
      Uri.of_string
        (Printf.sprintf "%s/oauth/token" (Uri.to_string (Terrat_config.Gitlab.web_base_url config)))
    in
    let body =
      Yojson.Safe.to_string
        (`Assoc
           [
             ("client_id", `String (Terrat_config.Gitlab.app_id config));
             ("client_secret", `String (Terrat_config.Gitlab.app_secret config));
             ("code", `String code);
             ("grant_type", `String "authorization_code");
             ("redirect_uri", `String (Printf.sprintf "%s/v1/gitlab/callback" server_api_base));
           ])
    in
    Http.post ~headers ~body uri
    >>| function
    | Ok (resp, body) when Http.Status.is_success (Http.Response.status resp) -> (
        match Response.of_yojson (Yojson.Safe.from_string body) with
        | Ok value -> Ok value
        | Error _ -> Error (`Authorize_err body))
    | Ok (_resp, body) -> Error (`Authorize_err body)
    | Error err -> Error err

  let refresh ~config refresh_token =
    let open Abb.Future.Infix_monad in
    let headers =
      Http.Headers.of_list
        [
          ("user-agent", "Terrateam");
          ("accept", "application/json");
          ("content-type", "application/json");
        ]
    in
    let uri =
      Uri.of_string
        (Printf.sprintf "%s/oauth/token" (Uri.to_string (Terrat_config.Gitlab.web_base_url config)))
    in
    let body =
      Yojson.Safe.to_string
        (`Assoc
           [
             ("client_id", `String (Terrat_config.Gitlab.app_id config));
             ("client_secret", `String (Terrat_config.Gitlab.app_secret config));
             ("grant_type", `String "refresh_token");
             ("refresh_token", `String refresh_token);
           ])
    in
    Http.post ~headers ~body uri
    >>| function
    | Ok (resp, body) when Http.Status.is_success (Http.Response.status resp) -> (
        match Response.of_yojson (Yojson.Safe.from_string body) with
        | Ok value -> Ok value
        | Error err -> Error (`Refresh_err err))
    | Ok (_resp, body) -> Error (`Refresh_err body)
    | Error err -> Error err

  let access_token ~config db user =
    let open Abbs_future_combinators.Infix_result_monad in
    Pgsql_io.Prepared_stmt.fetch
      db
      (Sql.select_user_token ())
      ~f:(fun token expired refresh_token -> (token, expired, refresh_token))
      (Terrat_user.id user)
    >>= function
    | [] -> Abbs_future_combinators.return_err (`User_not_found user)
    | (_, true, refresh_token) :: _ ->
        refresh ~config refresh_token
        >>= fun oauth ->
        Abbs_future_combinators.to_result (Abb.Sys.time ())
        >>= fun now ->
        let expiration =
          CCOption.map
            (fun exp -> ISO8601.Permissive.string_of_datetime (now +. CCFloat.of_int exp))
            oauth.Response.expires_in
        in
        let refresh_expiration =
          CCOption.map
            (fun exp -> ISO8601.Permissive.string_of_datetime (now +. CCFloat.of_int exp))
            oauth.Response.refresh_token_expires_in
        in
        Pgsql_io.Prepared_stmt.execute
          db
          (Sql.update_gitlab_user2_tokens ())
          (Terrat_user.id user)
          oauth.Response.access_token
          expiration
          oauth.Response.refresh_token
          refresh_expiration
        >>| fun () -> oauth.Response.access_token
    | (token, _, _) :: _ -> Abbs_future_combinators.return_ok token
end

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_gitlab_user_id () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* username *)
      Ret.text
      //
      (* email *)
      Ret.(option text)
      //
      (* name *)
      Ret.(option text)
      //
      (* avatar_url *)
      Ret.(option text)
      //
      (* gitlab_user_id *)
      Ret.bigint
      /^ read [%blob "sql/select_gitlab_user2_by_user_id.sql"]
      /% Var.uuid "user_id")
end

type query_user_id_err =
  [ Pgsql_io.err
  | `User_not_found_err of Terrat_user.t
  ]
[@@deriving show]

type query_user_id_ex_err = Pgsql_io.err [@@deriving show]

let query_user_id' db user =
  let open Abbs_future_combinators.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_gitlab_user_id ())
    ~f:(fun _ _ _ _ user_id -> user_id)
    (Terrat_user.id user)
  >>| function
  | [] -> None
  | user_id :: _ -> Some (CCInt64.to_int user_id)

let query_user_id db user =
  let open Abbs_future_combinators.Infix_result_monad in
  query_user_id' db user
  >>? function
  | Some user_id -> Ok user_id
  | None -> Error (`User_not_found_err user)
