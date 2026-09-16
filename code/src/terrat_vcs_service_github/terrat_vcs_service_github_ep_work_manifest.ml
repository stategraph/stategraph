let src = Logs.Src.create "vcs_service_github_ep_work_manifest"

module Logs = (val Logs.src_log src : Logs.LOG)

module Make (P : Terrat_vcs_provider2_github.S) = struct
  (* module Evaluator = Terrat_vcs_event_evaluator.Make (P) *)
  module Evaluator2 = Terrat_vcs_event_evaluator2.Make (P)

  module Sql = struct
    let select_running_work_manifest () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ "select id from work_manifests where id = $id and state in ('queued', 'running')"
        /% Var.uuid "id")
  end

  let enforce_work_manifest_access access_token_id work_manifest_id storage ctx =
    let open Abb.Future.Infix_monad in
    match access_token_id with
    | Some access_token_id when Uuidm.equal access_token_id work_manifest_id -> (
        Pgsql_pool.with_conn storage ~f:(fun db ->
            Pgsql_io.Prepared_stmt.fetch
              db
              (Sql.select_running_work_manifest ())
              ~f:CCFun.id
              work_manifest_id)
        >>= function
        | Ok [] -> Abbs_future_combinators.return_err (Brtl_ctx.set_response `Forbidden ctx)
        | Ok (_ :: _) -> Abbs_future_combinators.return_ok ()
        | Error (#Pgsql_pool.err | #Pgsql_io.err) ->
            Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx))
    | Some _ | None -> Abbs_future_combinators.return_err (Brtl_ctx.set_response `Forbidden ctx)

  module Initiate = struct
    (* [work_token] is the value the run was given to ask for work with.  Two
       routes reach here.  On compute-node/<uuid>/initiate it is a compute node
       id, which is what a run of this server gets.  On
       work-manifests/<uuid>/initiate it is a work manifest id, which is what a
       released action and a legacy run still send.  [compute_node_poll] tells
       the two apart. *)
    let post' config storage exec work_token initiate ctx =
      let request_id = Brtl_ctx.token ctx in
      Evaluator2.compute_node_poll
        ~request_id
        ~config
        ~storage
        ~exec
        ~compute_node_id:work_token
        initiate

    let post config storage exec work_token initiate =
      Brtl_ep.run_result_json ~f:(fun ctx ->
          let open Abb.Future.Infix_monad in
          post' config storage exec work_token initiate ctx
          >>= function
          | Ok response ->
              let body =
                response
                |> Terrat_api_work_manifest.Initiate.Responses.OK.to_yojson
                |> Yojson.Safe.to_string
              in
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
          | Error `Forbidden ->
              Logs.err (fun m -> m "%s : ACCESS_TOKEN : FORBIDDEN" (Brtl_ctx.token ctx));
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Forbidden "") ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m ->
                  m "%s : ACCESS_TOKEN : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
          | Error (#Pgsql_io.err as err) ->
              Logs.err (fun m ->
                  m "%s : ACCESS_TOKEN : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
          | Error `Error ->
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx))
  end

  module Plans = struct
    let post _config storage work_manifest_id plan =
      Brtl_ep.run_result_json ~f:(fun ctx ->
          let open Abbs_future_combinators.Infix_result_monad in
          (* TODO: Uncomment once all runs are on new work manifest access tokens *)
          (* Terrat_session.with_session ctx *)
          (* >>= fun user -> *)
          (* enforce_work_manifest_access *)
          (*   (Terrat_user.access_token_id user) *)
          (*   work_manifest_id *)
          (*   storage *)
          (*   ctx *)
          (* >>= fun () -> *)
          enforce_work_manifest_access (Some work_manifest_id) work_manifest_id storage ctx
          >>= fun () ->
          let open Abb.Future.Infix_monad in
          let request_id = Brtl_ctx.token ctx in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              let module Pc = Terrat_api_components.Plan_create in
              let { Pc.path; workspace; plan_data; has_changes } = plan in
              P.Db.store_plan
                ~request_id
                db
                work_manifest_id
                { Terrat_dirspace.dir = path; workspace }
                (Base64.decode_exn plan_data)
                has_changes)
          >>= function
          | Ok () ->
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m -> m "%s : %a" request_id Pgsql_pool.pp_err err);
              Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx)
          | Error `Error ->
              Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx))

    let get _config storage work_manifest_id dir workspace =
      Brtl_ep.run_result_json ~f:(fun ctx ->
          let open Abbs_future_combinators.Infix_result_monad in
          (* TODO: Uncomment once all runs are on new work manifest access tokens *)
          (* Terrat_session.with_session ctx *)
          (* >>= fun user -> *)
          (* enforce_work_manifest_access *)
          (*   (Terrat_user.access_token_id user) *)
          (*   work_manifest_id *)
          (*   storage *)
          (*   ctx *)
          (* >>= fun () -> *)
          enforce_work_manifest_access (Some work_manifest_id) work_manifest_id storage ctx
          >>= fun () ->
          let open Abb.Future.Infix_monad in
          let request_id = Brtl_ctx.token ctx in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              P.Db.query_plan ~request_id db work_manifest_id { Terrat_dirspace.dir; workspace })
          >>= function
          | Ok (Some data) ->
              let response =
                Terrat_api_work_manifest.Plan_get.Responses.OK.({ data } |> to_yojson)
                |> Yojson.Safe.to_string
              in
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK response) ctx)
          | Ok None ->
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m -> m "%s : %a" request_id Pgsql_pool.pp_err err);
              Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx)
          | Error `Error ->
              Abbs_future_combinators.return_err (Brtl_ctx.set_response `Internal_server_error ctx))
  end

  module Results = struct
    let put config storage exec work_manifest_id result =
      Brtl_ep.run_result_json ~f:(fun ctx ->
          let open Abbs_future_combinators.Infix_result_monad in
          (* TODO: Uncomment once all runs are on new work manifest access tokens *)
          (* Terrat_session.with_session ctx *)
          (* >>= fun user -> *)
          (* enforce_work_manifest_access *)
          (*   (Terrat_user.access_token_id user) *)
          (*   work_manifest_id *)
          (*   storage *)
          (*   ctx *)
          (* >>= fun () -> *)
          let request_id = Brtl_ctx.token ctx in
          Logs.info (fun m ->
              m
                "%s : WORK_MANIFEST_RESULT : work_manifest_id=%a"
                request_id
                Uuidm.pp
                work_manifest_id);
          enforce_work_manifest_access (Some work_manifest_id) work_manifest_id storage ctx
          >>= fun () ->
          let open Abb.Future.Infix_monad in
          Evaluator2.work_manifest_result
            ~request_id
            ~config
            ~storage
            ~exec
            ~work_manifest_id
            result
          >>= fun r ->
          match r with
          | Ok () ->
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx)
          | Error `Error ->
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx))
  end

  module Access_token = struct
    module Cache = Abbs_cache.Expiring.Make (struct
      type k = int64 [@@deriving eq]
      type v = string
      type err = Terrat_github.get_installation_access_token_err
      type args = unit -> (v, err) result Abb.Future.t

      let fetch f = f ()
      let weight = CCString.length
    end)

    (*  Cache it for slightly less time than it lives *)
    let cache =
      Cache.create
        {
          Abbs_cache.Expiring.on_hit = CCFun.const ();
          on_miss = CCFun.const ();
          on_evict = CCFun.const ();
          duration = Duration.of_sec 50;
          capacity = 100;
        }

    module Sql = struct
      let read s = Pgsql_io.clean_string s

      let select_installation_id () =
        Pgsql_io.Typed_sql.(
          sql
          //
          (* id *)
          Ret.bigint
          /^ read [%blob "sql/select_installation_id_from_work_manifest.sql"]
          /% Var.uuid "id")
    end

    let github_permissions =
      let module P = Githubc2_components.App_permissions in
      P.make
        {
          (CCResult.get_or_failwith @@ P.Primary.of_yojson (`Assoc [])) with
          P.Primary.contents = Some `Read;
          issues = Some `Write;
          pull_requests = Some `Write;
          statuses = Some `Write;
        }

    let post config storage work_manifest_id =
      Brtl_ep.run_result_json ~f:(fun ctx ->
          let open Abbs_future_combinators.Infix_result_monad in
          Terrat_session.with_session ctx
          >>= fun user ->
          enforce_work_manifest_access
            (Terrat_user.access_token_id user)
            work_manifest_id
            storage
            ctx
          >>= fun () ->
          let run =
            let open Abb.Future.Infix_monad in
            Pgsql_pool.with_conn storage ~f:(fun db ->
                Pgsql_io.Prepared_stmt.fetch
                  db
                  (Sql.select_installation_id ())
                  ~f:CCFun.id
                  work_manifest_id)
            >>= function
            | Ok (installation_id :: _) -> (
                Cache.fetch cache installation_id (fun () ->
                    Terrat_github.get_installation_access_token
                      ~permissions:github_permissions
                      (P.Api.Config.vcs_config config)
                      (CCInt64.to_int installation_id))
                >>= function
                | Ok access_token ->
                    let body =
                      Terrat_api_work_manifest.Get_access_token.Responses.OK.(
                        to_yojson { access_token })
                      |> Yojson.Safe.to_string
                    in
                    Abb.Future.return
                      (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
                | Error (#Terrat_github.get_installation_access_token_err as err) ->
                    Logs.err (fun m ->
                        m
                          "%s : ACCESS_TOKEN : %a"
                          (Brtl_ctx.token ctx)
                          Terrat_github.pp_get_installation_access_token_err
                          err);
                    Abb.Future.return
                      (Brtl_ctx.set_response
                         (Brtl_rspnc.create ~status:`Internal_server_error "")
                         ctx))
            | Ok [] ->
                Abb.Future.return
                  (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Bad_request "") ctx)
            | Error (#Pgsql_pool.err as err) ->
                Logs.err (fun m ->
                    m "%s : ACCESS_TOKEN : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
                Abb.Future.return
                  (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
            | Error (#Pgsql_io.err as err) ->
                Logs.err (fun m ->
                    m "%s : ACCESS_TOKEN : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
                Abb.Future.return
                  (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
          in
          Abbs_future_combinators.to_result run)
  end

  module Workspaces = struct
    module Sql = struct
      let dirspaces =
        let module P = struct
          type t = Terrat_api_components.Work_manifest_workspaces.t [@@deriving yojson]
        end in
        CCFun.(P.of_yojson %> CCResult.to_opt)

      let select_workspaces =
        Pgsql_io.Typed_sql.(
          sql
          //
          (* dirspaces *)
          Ret.(u json dirspaces)
          /^ "select dirspaces from work_manifests where id = $id and state in ('queued', \
              'running')"
          /% Var.uuid "id")
    end

    let get _config storage work_manifest_id =
      Brtl_ep.run_result_json ~f:(fun ctx ->
          let open Abbs_future_combinators.Infix_result_monad in
          (* TODO: Uncomment once all runs are on new work manifest access tokens *)
          (* Terrat_session.with_session ctx *)
          (* >>= fun user -> *)
          (* enforce_work_manifest_access *)
          (*   (Terrat_user.access_token_id user) *)
          (*   work_manifest_id *)
          (*   storage *)
          (*   ctx *)
          (* >>= fun () -> *)
          enforce_work_manifest_access (Some work_manifest_id) work_manifest_id storage ctx
          >>= fun () ->
          let open Abb.Future.Infix_monad in
          Pgsql_pool.with_conn storage ~f:(fun db ->
              Pgsql_io.Prepared_stmt.fetch db Sql.select_workspaces ~f:CCFun.id work_manifest_id)
          >>= function
          | Ok [] ->
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Not_found "") ctx)
          | Ok (workspaces :: _) ->
              let body =
                Terrat_api_components.Work_manifest_workspaces.to_yojson workspaces
                |> Yojson.Safe.to_string
              in
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
          | Error (#Pgsql_pool.err as err) ->
              Logs.err (fun m ->
                  m "%s : WORKSPACES : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
          | Error (#Pgsql_io.err as err) ->
              Logs.err (fun m -> m "%s : WORKSPACES : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
              Abbs_future_combinators.return_ok
                (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx))
  end
end
