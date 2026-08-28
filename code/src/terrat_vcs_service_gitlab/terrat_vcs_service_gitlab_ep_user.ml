let src = Logs.Src.create "vcs_service_gitlab_ep_user"

module Logs = (val Logs.src_log src : Logs.LOG)

module Whoami = struct
  module Sql = struct
    let read s = Pgsql_io.clean_string s

    let select_gitlab_user () =
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
        (* gitlab user id *)
        Ret.bigint
        /^ read [%blob "sql/select_gitlab_user2_by_user_id.sql"]
        /% Var.uuid "user_id")
  end

  let get _config storage =
    Brtl_ep.run_result_json ~f:(fun ctx ->
        let open Abbs_future_combinators.Infix_result_monad in
        Terrat_session.with_session ctx
        >>= fun user ->
        let run =
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Pgsql_io.Prepared_stmt.fetch
                db
                (Sql.select_gitlab_user ())
                ~f:(fun username _ _ avatar_url _ -> (username, avatar_url))
                (Terrat_user.id user))
          >>| fun res -> CCOption.of_list res
        in
        let open Abb.Future.Infix_monad in
        run
        >>= function
        | Ok None ->
            Logs.debug (fun m ->
                m
                  "%s : WHOAMI : user_id=%a : NOT_FOUND"
                  (Brtl_ctx.token ctx)
                  Uuidm.pp
                  (Terrat_user.id user));
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Forbidden "") ctx)
        | Ok (Some (username, avatar_url)) ->
            let body =
              Terrat_api_components.Gitlab_user.(
                { avatar_url; username } |> to_yojson |> Yojson.Safe.to_string)
            in
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
        | Error (#Pgsql_pool.err as err) ->
            Logs.err (fun m -> m "%s : WHOAMI : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "%s : WHOAMI : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
            Abbs_future_combinators.return_ok
              (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx))
end
