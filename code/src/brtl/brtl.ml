module Fut_comb = Abbs_fc
module Http = Brtl_rspnc.Http
module Cfg = Brtl_cfg
module Ctx = Brtl_ctx
module Mw = Brtl_mw
module Rspnc = Brtl_rspnc
module Rtng = Brtl_rtng

let src = Logs.Src.create "brtl"

module Logs = (val Logs.src_log src : Logs.LOG)

let rec read_body_chunks r b =
  let open Abb.Future.Infix_monad in
  Http.Request_io.read_body_chunk r
  >>= function
  | Cohttp.Transfer.Chunk s ->
      Buffer.add_string b s;
      read_body_chunks r b
  | Cohttp.Transfer.Final_chunk s ->
      Buffer.add_string b s;
      Fut_comb.unit
  | Cohttp.Transfer.Done -> Fut_comb.unit

(* TODO: Limit size of body *)
let read_body req ic =
  let b = Buffer.create 1024 in
  match Http.Request_io.has_body req with
  | `Yes | `Unknown ->
      let open Abb.Future.Infix_monad in
      read_body_chunks (Http.Request_io.make_body_reader req ic) b
      >>= fun () -> Abb.Future.return (Buffer.contents b)
  | `No -> Abb.Future.return ""

let write_response oc rspnc =
  Http.Response_io.write (fun writer -> Rspnc.body rspnc writer) (Rspnc.response rspnc) oc

let run_handler hndlr ctx =
  Abb.Future.await_bind
    (function
      | `Det v -> Abb.Future.return v
      | `Aborted ->
          Abb.Future.return (Ctx.set_response (Rspnc.create ~status:`Internal_server_error "") ctx)
      | `Exn (exn, bt_opt) ->
          Logs.err (fun m -> m "Exception: %s" (Printexc.to_string exn));
          CCOption.iter
            (fun bt -> Logs.err (fun m -> m "Backtrace: %s" (Printexc.raw_backtrace_to_string bt)))
            bt_opt;
          Abb.Future.return (Ctx.set_response (Rspnc.create ~status:`Internal_server_error "") ctx))
    (Fut_comb.on_failure (fun () -> hndlr ctx) ~failure:(fun () -> Fut_comb.unit))

let compute_remote_addr conn =
  match Abb.Socket.getpeername conn with
  | Abb_intf.Socket.Sockaddr.Unix s -> s
  | Abb_intf.Socket.Sockaddr.Inet { Abb_intf.Socket.Sockaddr.addr; _ } ->
      Unix.string_of_inet_addr addr

let handler' mw rtng ctx req ic oc =
  let open Abb.Future.Infix_monad in
  Mw.exec_pre_handler ctx mw
  >>= function
  | Mw.Pre_handler.Cont ctx ->
      read_body req ic
      >>= fun body ->
      let ctx = Ctx.set_body body ctx in
      let hndlr = Rtng.route ctx rtng in
      run_handler hndlr ctx
      >>= fun ctx ->
      Mw.exec_post_handler ctx mw
      >>= fun ctx -> write_response oc (Ctx.response ctx) >>= fun () -> Abb.Future.return `Ok
  | Mw.Pre_handler.Stop ctx ->
      Mw.exec_early_exit_handler ctx mw
      >>= fun ctx -> write_response oc (Ctx.response ctx) >>= fun () -> Abb.Future.return `Ok

let handler mw rtng conn req ic oc =
  let open Abb.Future.Infix_monad in
  let remote_addr = compute_remote_addr conn in
  let ctx = Ctx.create remote_addr req in
  Abb.Task.run ~name:("brtl-req-" ^ Ctx.token ctx) (fun () -> handler' mw rtng ctx req ic oc)
  >>= fun task -> task

let on_handler_err req = function
  | `Exn (exn, bt_opt) ->
      Logs.err (fun m -> m "Request exn: %a" Cohttp.Request.pp_hum req);
      Logs.err (fun m -> m "Exception: %s" (Printexc.to_string exn));
      CCOption.iter
        (fun bt -> Logs.err (fun m -> m "Backtrace: %s" (Printexc.raw_backtrace_to_string bt)))
        bt_opt;
      Abb.Future.return `Ok
  | `Timeout ->
      Logs.err (fun m -> m "Request timeout %a" Cohttp.Request.pp_hum req);
      Abb.Future.return `Ok

let on_protocol_err = function
  | `Error str ->
      Logs.warn (fun m -> m "Bad request: %s" str);
      Abb.Future.return `Ok
  | `Timeout ->
      Logs.warn (fun m -> m "Timed out reading request");
      Abb.Future.return `Ok

let run cfg mw rtng =
  let config =
    Http.Server.(
      Config.of_view
        {
          Config.View.channel = Http.Server.http_channel;
          on_handler_err;
          on_protocol_err;
          port = Cfg.port cfg;
          handler = handler mw rtng;
          read_header_timeout = Cfg.read_header_timeout cfg;
          handler_timeout = Cfg.handler_timeout cfg;
        })
  in
  let open Abb.Future.Infix_monad in
  Abb.Task.run ~name:"brtl-server" (fun () -> Http.Server.run (CCResult.get_exn config))
  >>= fun task -> task
