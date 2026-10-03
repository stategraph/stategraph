let src = Logs.Src.create "ep_complete"

module Logs = (val Logs.src_log src : Logs.LOG)
module Fc = Abbs_fc

module Sql = struct
  let upsert_system_setting () =
    Pgsql_io.Typed_sql.(
      sql /^ [%blob "./sql/upsert_system_setting.sql"] /% Var.text "key" /% Var.json "value")
end

let json_error ~status ~id ?data ctx =
  let error_response = { Sgs_api_components_error_response.id; data } in
  let body = Yojson.Safe.to_string @@ Sgs_api_components_error_response.to_yojson error_response in
  Brtl_ctx.set_response (Brtl_rspnc.create ~status body) ctx

(* Gate setup completion on a valid license, then mark setup complete. The
   license is expected to have been stored already via POST /api/v1/license, or
   to be present via the STATEGRAPH_LICENSE_KEY env var / a managed deployment. *)
let run' ~requirement config db =
  let open Fc.Infix_result_monad in
  Sgs_service_license.passes_license_gate ~requirement config db
  >>= fun licensed ->
  if not licensed then Abbs_fc.return_ok `License_required
  else
    Pgsql_io.Prepared_stmt.execute db (Sql.upsert_system_setting ()) "setup_completed" (`Bool true)
    >>| fun () -> `Completed

let run ~requirement config storage =
  Brtl_ep.run_json ~f:(fun ctx ->
      let open Abb.Future.Infix_monad in
      let token = Brtl_ctx.token ctx in
      Pgsql_pool.with_conn storage ~f:(fun db -> run' ~requirement config db)
      >>= function
      | Ok `Completed ->
          let body = Yojson.Safe.to_string (`Assoc [ ("success", `Bool true) ]) in
          Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)
      | Ok `License_required ->
          Logs.warn (fun m -> m "%s : LICENSE_REQUIRED" token);
          Abb.Future.return
            (json_error
               ~status:`Forbidden
               ~id:"LICENSE_REQUIRED"
               ~data:"A valid license key is required to complete setup."
               ctx)
      | Error (#Pgsql_pool.err as err) ->
          Logs.err (fun m -> m "%s : %a" token Pgsql_pool.pp_err err);
          Abb.Future.return (Sgs_eplib.respond_internal_error ctx)
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "%s : %a" token Pgsql_io.pp_err err);
          Abb.Future.return (Sgs_eplib.respond_internal_error ctx))
