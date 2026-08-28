let src = Logs.Src.create "vcs_service_gitlab_ep_repo_delete"

module Logs = (val Logs.src_log src : Logs.LOG)

module type S = sig
  val enforce_installation_access :
    request_id:string ->
    Terrat_user.t ->
    int ->
    Pgsql_io.t ->
    (unit, [> `Forbidden ]) result Abb.Future.t
end

module Sql = struct
  let read s = Pgsql_io.clean_string s

  let select_username () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* username *)
      Ret.text
      /^ read [%blob "sql/select_username_for_repo_delete.sql"]
      /% Var.uuid "user_id")
end

module Make (P : Terrat_vcs_provider2_gitlab.S) (S : S) = struct
  let error_response id =
    let module Er = Terrat_api_components.Error_response in
    Er.{ id; data = None } |> Er.to_yojson |> Yojson.Safe.to_string

  let lookup_username db user =
    let open Abbs_future_combinators.Infix_result_monad in
    Pgsql_io.Prepared_stmt.fetch db (Sql.select_username ()) ~f:CCFun.id (Terrat_user.id user)
    >>? function
    | username :: _ -> Ok username
    | [] -> Error `Forbidden

  let enforce_org_admin ~request_id ~org username client =
    let open Abbs_future_combinators.Infix_result_monad in
    let vcs_user = P.Api.User.make username in
    P.Api.get_org_role ~request_id ~org vcs_user client
    >>? function
    | Some `Admin -> Ok ()
    | Some `User | None -> Error `Forbidden

  let ensure_archived ~request_id client repo =
    let open Abbs_future_combinators.Infix_result_monad in
    P.Api.fetch_remote_repo ~request_id client repo
    >>? fun remote_repo ->
    if P.Api.Remote_repo.is_archived remote_repo then Ok () else Error `Not_archived

  let perform_delete ~request_id config _storage installation_id repo_id user db =
    let open Abbs_future_combinators.Infix_result_monad in
    P.Db.query_repo_by_id ~request_id db installation_id repo_id
    >>= function
    | None -> Abbs_future_combinators.return_err `Not_found
    | Some repo ->
        let account = P.Api.Account.make installation_id in
        P.Api.create_client ~request_id config account db
        >>= fun client ->
        lookup_username db user
        >>= fun username ->
        enforce_org_admin ~request_id ~org:(P.Api.Repo.owner repo) username client
        >>= fun () ->
        ensure_archived ~request_id client repo
        >>= fun () ->
        Logs.info (fun m ->
            m "%s : DELETE_REPO : repo=%s : user=%s" request_id (P.Api.Repo.to_string repo) username);
        P.Db.delete_repo ~request_id db installation_id repo_id

  let delete config storage installation_id repo_id =
    Brtl_ep.run_result_json ~f:(fun ctx ->
        let open Abbs_future_combinators.Infix_result_monad in
        let request_id = Brtl_ctx.token ctx in
        Terrat_session.with_session ctx
        >>= fun user ->
        let open Abb.Future.Infix_monad in
        Pgsql_pool.with_conn storage ~f:(fun db ->
            S.enforce_installation_access ~request_id user installation_id db
            >>= function
            | Error `Forbidden -> Abbs_future_combinators.return_err `Forbidden
            | Ok () -> (
                match P.Api.Repo.Id.of_string repo_id with
                | None -> Abbs_future_combinators.return_err `Invalid_repo_id
                | Some repo_id ->
                    perform_delete ~request_id config storage installation_id repo_id user db))
        >>= function
        | Ok () ->
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "{}") ctx)
        | Error `Forbidden ->
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Forbidden "") ctx)
        | Error `Invalid_repo_id ->
            let body = error_response "INVALID_REPO_ID" in
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request body) ctx)
        | Error `Not_found ->
            let body = error_response "REPO_NOT_FOUND" in
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request body) ctx)
        | Error `Not_archived ->
            let body = error_response "REPO_NOT_ARCHIVED" in
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request body) ctx)
        | Error (`Vcs_api_timeout_err operation) ->
            Logs.err (fun m -> m "%s : VCS_API_TIMEOUT : %s" request_id operation);
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
        | Error `Error ->
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
        | Error (#Pgsql_pool.err as err) ->
            Logs.err (fun m -> m "%s : %a" request_id Pgsql_pool.pp_err err);
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "%s : %a" request_id Pgsql_io.pp_err err);
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx))
end
