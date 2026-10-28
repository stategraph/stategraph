module Abb = Abb_scheduler_select
module Oth_abb = Oth_abb.Make (Abb)
module Http = Cohttp_abb.Make (Abb)
module Buffered = Abb_io_buffered.Make (Abb.Future)
module Fut_comb = Abb_fc.Make (Abb.Future)

let loopback port = Abb_intf.Socket.Sockaddr.(Inet { addr = Unix.inet_addr_loopback; port })

(* A socket listening on a loopback port chosen by the kernel. *)
let listen () =
  let sock = CCResult.get_exn (Abb.Socket.Tcp.create ~domain:Abb_intf.Socket.Domain.Inet4) in
  CCResult.get_exn (Abb.Socket.Tcp.bind sock (loopback 0));
  CCResult.get_exn (Abb.Socket.listen sock ~backlog:1);
  match Abb.Socket.getsockname sock with
  | Abb_intf.Socket.Sockaddr.Inet { Abb_intf.Socket.Sockaddr.port; _ } -> (sock, port)
  | Abb_intf.Socket.Sockaddr.Unix _ -> Oth.Assert.false_ "Expected an inet address"

(* Read from [sock] and fail unless the peer has closed it. The timeout turns a socket that is
   never closed into a failure instead of a hang. *)
let assert_closed_by_peer sock =
  let open Abb.Future.Infix_monad in
  let buf = Bytes.create 1 in
  Fut_comb.timeout ~timeout:(Abb.Sys.sleep 5.0) (Abb.Socket.Tcp.recv sock ~buf ~pos:0 ~len:1)
  >>= fun res ->
  Fut_comb.ignore (Abb.Socket.close sock)
  >>| fun () ->
  match res with
  | `Ok (Ok 0) -> ()
  | `Ok (Ok _) -> Oth.Assert.false_ "Expected the peer to close the connection, got data"
  | `Ok (Error _) -> Oth.Assert.false_ "Expected the peer to close the connection, got an error"
  | `Timeout -> Oth.Assert.false_ "Expected the peer to close the connection"

let basic =
  Oth_abb.test ~desc:"Basic http test" ~name:"Basic" (fun () ->
      let open Abb.Future.Infix_monad in
      let rc, _ = Buffered.of_bytes (Bytes.of_string "HTTP/1.1 200 OK\r\nFoo: bar\r\n\r\n") in
      let rs, wc = Buffered.of_bytes (Bytes.of_string "") in
      let transport = Http.Client.Transport.default rc wc in
      Http.Client.do_request ~flush:true transport (Http.Request.make_for_client `GET (Uri.make ()))
      >>= function
      | Ok res ->
          Oth.Assert.Eq.string
            ~expected:"200 OK"
            ~actual:(Cohttp.Code.string_of_status res.Http.Response.status);
          Buffered.read_line rs
          >>= fun ret ->
          Oth.Assert.true_ (ret = Ok (Some "GET / HTTP/1.1"));
          Abb.Future.return ()
      | Error _ -> Oth.Assert.false_ "Basic: unexpected value")

let tls_not_configured =
  Oth_abb.test
    ~desc:"A https request without a TLS channel fails before connecting"
    ~name:"Tls_not_configured"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let connector = Http.Client.Connector.Tests.make () in
      Http.Client.get ~connector (Uri.of_string "https://example.com")
      >>| function
      | Ok _ -> Oth.Assert.false_ "Expected a https request without a TLS channel to fail"
      | Error `E_tls_not_configured -> ()
      | Error (#Cohttp_abb.request_err as err) ->
          Oth.Assert.false_ (Cohttp_abb.show_request_err err))

let client_channel_err =
  Oth_abb.test
    ~desc:"A https request whose channel fails closes the socket and returns the error"
    ~name:"Client_channel_err"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let srv, port = listen () in
      let connector =
        Http.Client.Connector.Tests.make ~channel:(fun ~host:_ _ -> Error `Error) ()
      in
      Http.Client.get ~connector (Uri.make ~scheme:"https" ~host:"127.0.0.1" ~port ())
      >>= fun res ->
      (match res with
      | Error `Error -> ()
      | Ok _ -> Oth.Assert.false_ "Expected the request to fail"
      | Error (#Cohttp_abb.request_err as err) ->
          Oth.Assert.false_ (Cohttp_abb.show_request_err err));
      Abb.Socket.accept srv
      >>= fun conn ->
      Fut_comb.ignore (Abb.Socket.close srv)
      >>= fun () ->
      match conn with
      | Ok conn -> assert_closed_by_peer conn
      | Error _ -> Oth.Assert.false_ "Expected to accept the client connection")

let server_channel_err =
  Oth_abb.test
    ~desc:"The server closes a connection whose channel fails and keeps accepting connections"
    ~name:"Server_channel_err"
    (fun () ->
      let open Abb.Future.Infix_monad in
      (* [Server.run] needs a fixed port: take a free one from the kernel. *)
      let probe, port = listen () in
      Fut_comb.ignore (Abb.Socket.close probe)
      >>= fun () ->
      let failed = ref false in
      let channel conn =
        if !failed then Http.Server.http_channel conn
        else (
          failed := true;
          Error `Error)
      in
      let handler _ _ _ oc =
        let headers = Cohttp.Header.init_with "content-length" "0" in
        Http.Response_io.write
          (fun _ -> Abb.Future.return ())
          (Http.Response.make ~status:`OK ~headers ())
          oc
        >>| fun () -> `Stop
      in
      let config =
        CCResult.get_exn
          (Http.Server.Config.of_view
             {
               Http.Server.Config.View.channel;
               on_handler_err = (fun _ _ -> Abb.Future.return `Stop);
               on_protocol_err = (fun _ -> Abb.Future.return `Ok);
               port;
               handler;
               read_header_timeout = None;
               handler_timeout = None;
             })
      in
      Abb.Future.fork (Http.Server.run config)
      >>= fun server ->
      let client = CCResult.get_exn (Abb.Socket.Tcp.create ~domain:Abb_intf.Socket.Domain.Inet4) in
      Abb.Socket.Tcp.connect client (loopback port)
      >>= function
      | Error _ -> Oth.Assert.false_ "Expected to connect to the server"
      | Ok () -> (
          assert_closed_by_peer client
          >>= fun () ->
          Fut_comb.timeout
            ~timeout:(Abb.Sys.sleep 5.0)
            (Http.Client.get
               ~connector:(Http.Client.Connector.Tests.make ())
               (Uri.make ~scheme:"http" ~host:"127.0.0.1" ~port ()))
          >>= fun res ->
          (match res with
          | `Ok (Ok (resp, _)) ->
              Oth.Assert.Eq.string
                ~expected:"200 OK"
                ~actual:(Cohttp.Code.string_of_status resp.Http.Response.status)
          | `Ok (Error err) -> Oth.Assert.false_ (Cohttp_abb.show_request_err err)
          | `Timeout -> Oth.Assert.false_ "Expected the server to answer the next connection");
          server
          >>| function
          | Ok () -> ()
          | Error err -> Oth.Assert.false_ (Cohttp_abb.show_run_err err)))

let test = Oth_abb.(parallel [ basic; tls_not_configured; client_channel_err; server_channel_err ])

let () =
  Random.self_init ();
  Oth_abb.run
    ~file:__FILE__
    ~setup:(fun () -> Abb.Future.return (Ok ()))
    ~teardown:(fun () -> Abb.Future.return ())
    (fun () -> test)
