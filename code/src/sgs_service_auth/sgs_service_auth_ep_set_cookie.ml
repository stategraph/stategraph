let src = Logs.Src.create "ep_set_cookie"

module Logs = (val Logs.src_log src : Logs.LOG)

let ok_response ctx redirect =
  match redirect with
  | Some path -> (
      match Sgs_redirect.path path with
      | Some path ->
          let headers = Cohttp.Header.of_list [ ("Location", path) ] in
          Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Found ~headers "") ctx
      | None ->
          Logs.warn (fun m -> m "%s : SET_COOKIE_UNSAFE_REDIRECT %s" (Brtl_ctx.token ctx) path);
          Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
  | None -> Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx

let run _config storage session_id redirect =
  Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx ->
      let run =
        let open Abbs_fc.Infix_result_monad in
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Sgs_user_session.Session.fetch_key db
            >>= fun keys ->
            Sgs_user_session.Session.of_token ~keys db session_id
            >>| fun session -> Sgs_user_session.set session ctx)
      in
      let open Abb.Future.Infix_monad in
      run
      >>= function
      | Ok ctx -> Abb.Future.return (ok_response ctx redirect)
      | Error (#Sgs_user_session.Session.of_token_err as err) ->
          Logs.err (fun m ->
              m "%s : %a" (Brtl_ctx.token ctx) Sgs_user_session.Session.pp_of_token_err err);
          Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request "") ctx)
      | Error (#Pgsql_pool.err as err) ->
          Logs.err (fun m -> m "%s : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
          Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
      | Error (#Sgs_user_session.Session.fetch_key_err as err) ->
          Logs.err (fun m ->
              m "%s : %a" (Brtl_ctx.token ctx) Sgs_user_session.Session.pp_fetch_key_err err);
          Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
      | Error `Error ->
          Logs.err (fun m -> m "%s : ERROR" (Brtl_ctx.token ctx));
          Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request "") ctx))
