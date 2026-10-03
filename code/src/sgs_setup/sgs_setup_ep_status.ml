let src = Logs.Src.create "ep_status"

module Logs = (val Logs.src_log src : Logs.LOG)

module Sql = struct
  let select_system_setting () =
    Pgsql_io.Typed_sql.(
      sql // Ret.jsonb /^ [%blob "./sql/select_system_setting.sql"] /% Var.text "key")
end

let response ~needs_setup ~mode =
  let body =
    Yojson.Safe.to_string
    @@ Sgs_api_components_setup_status_response.to_yojson
         { Sgs_api_components_setup_status_response.mode; needs_setup }
  in
  Brtl_rspnc.create ~status:`OK body

let internal_server_error () = Brtl_rspnc.create ~status:`Internal_server_error ""

module Make (Cloud : Sgs_cloud.S) = struct
  let run storage =
    Brtl_ep.run_json ~f:(fun ctx ->
        let open Abb.Future.Infix_monad in
        let token = Brtl_ctx.token ctx in
        let mode = Cloud.api_mode () in
        match Cloud.setup () with
        | `Out_of_band ->
            Logs.debug (fun m -> m "%s : SETUP_STATUS_OUT_OF_BAND" token);
            Abb.Future.return (Brtl_ctx.set_response (response ~needs_setup:false ~mode) ctx)
        | `In_app -> (
            Pgsql_pool.with_conn storage ~f:(fun db ->
                Pgsql_io.Prepared_stmt.fetch
                  db
                  (Sql.select_system_setting ())
                  ~f:CCFun.id
                  "setup_completed")
            >>= function
            | Ok (value :: _) ->
                let needs_setup = not (Yojson.Safe.equal value (`Bool true)) in
                Abb.Future.return (Brtl_ctx.set_response (response ~needs_setup ~mode) ctx)
            | Ok [] ->
                Abb.Future.return (Brtl_ctx.set_response (response ~needs_setup:true ~mode) ctx)
            | Error (#Pgsql_pool.err as err) ->
                Logs.err (fun m -> m "%s : DB_POOL_ERR : %a" token Pgsql_pool.pp_err err);
                Abb.Future.return (Brtl_ctx.set_response (internal_server_error ()) ctx)
            | Error (#Pgsql_io.err as err) ->
                Logs.err (fun m -> m "%s : DB_IO_ERR : %a" token Pgsql_io.pp_err err);
                Abb.Future.return (Brtl_ctx.set_response (internal_server_error ()) ctx)))
end
