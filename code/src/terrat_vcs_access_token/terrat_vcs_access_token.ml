module type S = sig
  val vcs : string
end

module Make (_ : Terrat_vcs_provider2.S) (S : S) = struct
  let src = Logs.Src.create ("vcs_access_control_" ^ S.vcs)

  module Logs = (val Logs.src_log src : Logs.LOG)

  module Sql = struct
    let insert_access_token () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ "insert into access_tokens (capabilities, name, user_id) values ($capabilities, $name, \
            $user_id) returning id"
        /% Var.(ud (json "capabilities") [%to_yojson: Terrat_user.Capability.t list])
        /% Var.text "name"
        /% Var.uuid "user_id")

    let select_access_tokens () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* name *)
        Ret.text
        //
        (* capabilities *)
        Ret.u Ret.json CCFun.([%of_yojson: Terrat_user.Capability.t list] %> CCOption.of_result)
        /^ "select id, name, capabilities from access_tokens where user_id = $user_id order by \
            name limit 100"
        /% Var.uuid "user_id")

    let delete_access_token () =
      Pgsql_io.Typed_sql.(
        sql
        /^ "delete from access_tokens where user_id = $user_id and id = $id"
        /% Var.uuid "user_id"
        /% Var.uuid "id")
  end

  module List = struct
    (* Not implementing pagination now, but the API is designed for it. *)
    let run _config storage _page _limit =
      Brtl_ep.run_result_json ~f:(fun ctx ->
          let open Abbs_future_combinators.Infix_result_monad in
          Terrat_session.with_session ~caps:[ Terrat_user.Capability.Access_token_create ] ctx
          >>= fun user ->
          let run =
            Pgsql_pool.with_conn storage ~f:(fun db ->
                Pgsql_io.Prepared_stmt.fetch
                  db
                  (Sql.select_access_tokens ())
                  ~f:(fun id name capabilities ->
                    {
                      Terrat_api_components.Access_token_item.id = Uuidm.to_string id;
                      name;
                      capabilities = CCList.map Terrat_user.Capability.to_yojson capabilities;
                    })
                  (Terrat_user.id user))
          in
          let open Abb.Future.Infix_monad in
          run
          >>= function
          | Ok results ->
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response
                   (Brtl_rspnc.create
                      ~status:`OK
                      (Yojson.Safe.to_string
                      @@ Terrat_api_components.Access_token_page.(to_yojson { results })))
                   ctx)
          | Error (#Pgsql_io.err as err) ->
              Logs.err (fun m -> m "%s : LIST : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
              Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m -> m "%s : LIST : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
              Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx))
  end

  module Create = struct
    let run _config storage body =
      Brtl_ep.run_result_json ~f:(fun ctx ->
          let module C = Terrat_api_components.Access_token_create in
          let open Abbs_future_combinators.Infix_result_monad in
          Terrat_session.with_session ~caps:[ Terrat_user.Capability.Access_token_create ] ctx
          >>= fun user ->
          let run =
            let { C.name; capabilities } = body in
            (* Because the naming was getting messy, we moved all external
                 representation of capabilities to [Terrat_user] module rather
                 than in the api definition.  *)
            match
              [%of_yojson: Terrat_user.Capability.t list]
              @@ Terrat_api_components.Access_token_capabilities.to_yojson capabilities
            with
            | Ok capabilities ->
                (* Ensure that the requested capabilities are not more than what
                   this token can do. *)
                let capabilities =
                  Terrat_user.Capability.Vcs S.vcs
                  :: Terrat_user.Capability.mask ~mask:(Terrat_user.capabilities user) capabilities
                in
                Pgsql_pool.with_conn storage ~f:(fun db ->
                    Pgsql_io.Prepared_stmt.fetch
                      db
                      (Sql.insert_access_token ())
                      ~f:CCFun.id
                      capabilities
                      name
                      (Terrat_user.id user)
                    >>= function
                    | [] -> assert false
                    | access_token_id :: _ ->
                        (* The access token we return is only capable of
                           refreshing.  On a refresh a new access token will be
                           created that has the capabilities requested by the
                           user in this call. *)
                        let user =
                          Terrat_user.rem_capability
                            Terrat_user.Capability.Access_token_create
                            (Terrat_user.make
                               ~access_token_id
                               ~capabilities:[ Terrat_user.Capability.Access_token_refresh ]
                               ~id:(Terrat_user.id user)
                               ())
                        in
                        Terrat_user.Token.to_token db user
                        >>| fun refresh_token ->
                        let module At = Terrat_api_components.Access_token in
                        Brtl_ctx.set_response
                          (Brtl_rspnc.create
                             ~status:`OK
                             (Yojson.Safe.to_string @@ At.to_yojson { At.refresh_token }))
                          ctx)
            | Error err ->
                Logs.info (fun m -> m "%s : CREATE : %s" (Brtl_ctx.token ctx) err);
                Abbs_future_combinators.return_ok
                  (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request "") ctx)
          in
          let open Abb.Future.Infix_monad in
          run
          >>= function
          | Ok _ as r -> Abb.Future.return r
          | Error (#Terrat_user.Token.to_token_err as err) ->
              Logs.err (fun m ->
                  m "%s : CREATE : %a" (Brtl_ctx.token ctx) Terrat_user.Token.pp_to_token_err err);
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request "") ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m -> m "%s : CREATE : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
              Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx))
  end

  module Delete = struct
    let run _config storage access_token_id =
      Brtl_ep.run_result_json ~f:(fun ctx ->
          let open Abbs_future_combinators.Infix_result_monad in
          Terrat_session.with_session ~caps:[ Terrat_user.Capability.Access_token_create ] ctx
          >>= fun user ->
          let run =
            Pgsql_pool.with_conn storage ~f:(fun db ->
                Pgsql_io.Prepared_stmt.execute
                  db
                  (Sql.delete_access_token ())
                  (Terrat_user.id user)
                  access_token_id)
          in
          let open Abb.Future.Infix_monad in
          run
          >>= function
          | Ok () ->
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
          | Error (#Pgsql_io.err as err) ->
              Logs.err (fun m -> m "%s : DELETE : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
              Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m -> m "%s : DELETE : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
              Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx))
  end

  module Rt = struct
    let api () = Brtl_rtng.Route.(rel / "api" / "v1" / S.vcs / "access-token")
    let delete () = Brtl_rtng.Route.(api () /? Query.ud "id" Uuidm.of_string)

    let list_page () =
      Brtl_rtng.Route.(
        api ()
        /? Query.(option (ud_array "page" Brtl_ep_paginate.Param.(of_param Typ.string)))
        /? Query.(option_default 20 (int "limit")))

    let create () =
      Brtl_rtng.Route.(
        api () /* Body.decode ~json:Terrat_api_components.Access_token_create.of_yojson ())
  end

  let routes config storage =
    Brtl_rtng.Route.
      [
        (`GET, Rt.list_page () --> List.run config storage);
        (`POST, Rt.create () --> Create.run config storage);
        (`DELETE, Rt.delete () --> Delete.run config storage);
      ]
end
