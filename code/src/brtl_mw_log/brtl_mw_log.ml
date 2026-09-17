module Logs' = Logs

let src = Logs'.Src.create "brtl_mw_log"

module Logs = (val Logs'.src_log src : Logs'.LOG)

let src = Logs'.Src.create "brtl_mw_log.pre"

module Logs_pre = (val Logs'.src_log src : Logs'.LOG)

module Config = struct
  type t = {
    remote_ip_header : string option;
    metrics : Uri.t -> Cohttp.Code.meth -> float -> unit;
  }

  let make ?remote_ip_header ?(metrics = fun _ _ _ -> ()) () = { remote_ip_header; metrics }
end

let req_start_time = Hmap.Key.create ()

(* [Abb.Sys.sleep 0.0] yields to the loop, putting the continuation on a later
   iteration where the clock has been refreshed.  This guarantees that even if
   we only do computational work in the handler, the scheduler loop will be
   executing, updating the clock. *)
let pre_handler config ctx =
  let open Abb.Future.Infix_monad in
  let request = Brtl_ctx.request ctx in
  let uri = Brtl_ctx.Request.uri request in
  let meth = Cohttp.Code.string_of_method (Brtl_ctx.Request.meth request) in
  let token = Brtl_ctx.token ctx in
  let headers = Brtl_ctx.Request.headers request in
  let remote_addr =
    CCOption.get_or
      ~default:(Brtl_ctx.remote_addr ctx)
      (CCOption.flat_map (Cohttp.Header.get headers) config.Config.remote_ip_header)
  in
  Logs_pre.info (fun m -> m "%s : %s : %s : %s" remote_addr token meth (Uri.to_string uri));
  Abb.Sys.sleep 0.0
  >>= fun () ->
  Abb.Sys.monotonic ()
  >>= fun start_time ->
  let ctx = Brtl_ctx.md_add req_start_time start_time ctx in
  Abb.Future.return (Brtl_mw.Pre_handler.Cont ctx)

let post_handler config ctx =
  let open Abb.Future.Infix_monad in
  let rspnc = Brtl_ctx.response ctx in
  let request = Brtl_ctx.request ctx in
  let uri = Brtl_ctx.Request.uri request in
  let status = Cohttp.Code.string_of_status (Brtl_rspnc.status rspnc) in
  let meth_raw = Brtl_ctx.Request.meth request in
  let meth = Cohttp.Code.string_of_method meth_raw in
  let token = Brtl_ctx.token ctx in
  let headers = Brtl_ctx.Request.headers request in
  let remote_addr =
    CCOption.get_or
      ~default:(Brtl_ctx.remote_addr ctx)
      (CCOption.flat_map (Cohttp.Header.get headers) config.Config.remote_ip_header)
  in
  Abb.Sys.sleep 0.0
  >>= fun () ->
  Abb.Sys.monotonic ()
  >>= fun end_time ->
  let duration =
    match Brtl_ctx.md_find req_start_time ctx with
    | Some start_time -> end_time -. start_time
    | None -> 0.0
  in
  Logs.info (fun m ->
      m "%s : %s : %s : %f : %s : %s" remote_addr token meth duration (Uri.to_string uri) status);
  config.Config.metrics uri meth_raw duration;
  Abb.Future.return ctx

let early_exit_handler = Brtl_mw.early_exit_handler_noop
let create config = Brtl_mw.Mw.create (pre_handler config) (post_handler config) early_exit_handler
