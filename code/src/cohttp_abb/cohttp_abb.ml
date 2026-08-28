let src = Logs.Src.create "cohttp_abb"

module Logs = (val Logs.src_log src : Logs.LOG)

type connect_err =
  [ Abb_happy_eyeballs.connect_err
  | `E_connection_refused
  | `Unknown_scheme of string
  | `Unexpected_err of string
  | `Error
  ]
[@@deriving show]

type request_err =
  [ connect_err
  | `Invalid_request of string
  ]
[@@deriving show]

type run_err =
  [ `Exn of (exn[@printer fun fmt v -> fprintf fmt "%s" (Printexc.to_string v)])
  | `E_address_family_not_supported
  | `E_address_in_use
  | `E_address_not_available
  ]
[@@deriving show]

module Make (Abb : Abb_intf.S with type Native.t = Unix.file_descr) = struct
  module Happy_eyeballs = Abb_happy_eyeballs.Make (Abb)
  module Fut_comb = Abb_future_combinators.Make (Abb.Future)
  module Io = Cohttp_abb_io.Make (Abb)
  module Buffered = Abb_io_buffered.Make (Abb.Future)
  module Buffered_of = Abb_io_buffered.Of (Abb)
  module Abb_tls = Abb_tls.Make (Abb)
  module Request = Cohttp.Request
  module Response = Cohttp.Response
  module Body = Cohttp.Body
  module Request_io = Cohttp.Request.Make (Io)
  module Response_io = Cohttp.Response.Make (Io)

  module Client = struct
    module Transport = struct
      type t = {
        write_request :
          ?flush:bool ->
          ?body:(Request_io.writer -> unit Abb.Future.t) ->
          Request.t ->
          (Response.t, request_err) result Abb.Future.t;
        read_body_chunk : unit -> (string option, request_err) result Abb.Future.t;
        destroy : unit -> unit Abb.Future.t;
      }

      let create ~write_request ~read_body_chunk ~destroy =
        { write_request; read_body_chunk; destroy }

      let write_request ?flush ?body t request =
        (t.write_request ?flush ?body request
          : (Response.t, request_err) result Abb.Future.t
          :> (Response.t, [> request_err ]) result Abb.Future.t)

      let read_body_chunk t =
        (t.read_body_chunk ()
          : (string option, request_err) result Abb.Future.t
          :> (string option, [> request_err ]) result Abb.Future.t)

      let destroy t = t.destroy ()

      let default reader writer =
        let state :
            [ `Idle | `In_request | `Consuming_body of Response_io.reader | `Body_consumed ] ref =
          ref `Idle
        in
        let write_request ?(flush = false) ?body req =
          assert (!state = `Idle);
          state := `In_request;
          let open Abb.Future.Infix_monad in
          Logs.debug (fun m ->
              m "write_request : writing_request : %s" (Uri.to_string (Request.uri req)));
          Request_io.write
            ~flush
            (fun writer ->
              match body with
              | Some body -> body writer
              | None -> Abb.Future.return ())
            req
            writer
          >>= fun () ->
          Logs.debug (fun m -> m "write_request : flushing : %s" (Uri.to_string (Request.uri req)));
          Fut_comb.ignore (Buffered.flushed writer)
          >>= fun () ->
          Logs.debug (fun m ->
              m "write_request : reading_response : %s" (Uri.to_string (Request.uri req)));
          Response_io.read reader
          >>| function
          | `Ok resp ->
              (match Response_io.has_body resp with
              | `Yes | `Unknown ->
                  state := `Consuming_body (Response_io.make_body_reader resp reader)
              | `No -> state := `Body_consumed);
              Logs.debug (fun m ->
                  m "write_request : success : %s" (Uri.to_string (Request.uri req)));
              Ok resp
          | `Eof ->
              state := `Idle;
              Logs.debug (fun m -> m "write_request : eof : %s" (Uri.to_string (Request.uri req)));
              Error `Error
          | `Invalid err ->
              state := `Idle;
              Logs.debug (fun m ->
                  m "write_request : invalid : %s : %s" (Uri.to_string (Request.uri req)) err);
              Error (`Invalid_request err)
        in
        let read_body_chunk () =
          match !state with
          | `Consuming_body r -> (
              let open Abb.Future.Infix_monad in
              Response_io.read_body_chunk r
              >>| function
              | Cohttp.Transfer.Chunk s -> Ok (Some s)
              | Cohttp.Transfer.Final_chunk s ->
                  state := `Body_consumed;
                  Ok (Some s)
              | Cohttp.Transfer.Done ->
                  state := `Body_consumed;
                  Ok None)
          | `Body_consumed -> Fut_comb.return_ok None
          | _ -> assert false
        in
        let destroy () =
          Logs.debug (fun m -> m "closing");
          Fut_comb.ignore (Buffered.close_writer writer)
        in
        create ~write_request ~read_body_chunk ~destroy
    end

    module Connector = struct
      type t = Request.t -> (Transport.t, connect_err) result Abb.Future.t

      let connect_to_port host port =
        let open Abb.Future.Infix_monad in
        Logs.debug (fun m -> m "CONNECT : %s : %d" host port);
        Happy_eyeballs.connect host [ port ]
        >>= function
        | Ok (_, sock) ->
            Logs.debug (fun m -> m "CONNECT : success :  %s : %d" host port);
            Fut_comb.return_ok sock
        | Error (#Abb_happy_eyeballs.connect_err as err) ->
            Logs.debug (fun m ->
                m "CONNECT : error :  %s : %d : %a" host port Abb_happy_eyeballs.pp_connect_err err);
            Fut_comb.return_err err

      let connect_with_sock tls_config uri =
        let open Fut_comb.Infix_result_monad in
        match Uri.scheme uri with
        | Some "http" ->
            let host = CCOption.get_exn_or "get host" (Uri.host uri) in
            let port = CCOption.get_or ~default:80 (Uri.port uri) in
            connect_to_port host port
            >>| fun sock ->
            let reader, writer = Buffered_of.of_tcp_socket sock in
            (sock, reader, writer)
        | Some "https" ->
            let host = CCOption.get_exn_or "get host" (Uri.host uri) in
            let port = CCOption.get_or ~default:443 (Uri.port uri) in
            Fut_comb.protect_finally
              ~setup:(fun () -> Abb.Future.return (tls_config host))
              (fun tls_config ->
                connect_to_port host port
                >>= fun sock ->
                Abb.Future.return (Abb_tls.client_tcp sock tls_config host)
                >>| fun (reader, writer) -> (sock, reader, writer))
              ~finally:(fun tls_config ->
                Otls.Tls_config.destroy tls_config;
                Fut_comb.unit)
        | Some scheme -> Fut_comb.return_err (`Unknown_scheme scheme)
        | _ -> assert false

      let connect tls_config request =
        let open Fut_comb.Infix_result_monad in
        connect_with_sock tls_config (Request.uri request)
        >>| fun (_, reader, writer) -> Transport.default reader writer

      let make ?(tls_config = fun _ -> Otls.Tls_config.create ()) ?(connect = connect) () =
        connect tls_config

      let of_env ?tls_config () =
        let maybe_add_proxy_auth uri =
          match (Uri.user uri, Uri.password uri) with
          | Some user, Some password ->
              Some ("proxy-authorization: Basic " ^ Base64.encode_string (user ^ ":" ^ password))
          | _, _ -> None
        in
        let rec read_remaining_headers uri reader =
          let open Fut_comb.Infix_result_monad in
          Buffered.read_line reader
          >>= function
          | None | Some "" ->
              Logs.debug (fun m -> m "proxy : %s : " (Uri.to_string uri));
              Fut_comb.return_ok ()
          | Some line ->
              Logs.debug (fun m -> m "proxy : %s : %s" (Uri.to_string uri) line);
              read_remaining_headers uri reader
        in
        let finish_proxy_response tls_config uri sock scheme host reader writer =
          let open Fut_comb.Infix_result_monad in
          Buffered.read_line reader
          >>= function
          | Some line -> (
              Logs.debug (fun m -> m "proxy : %s : %s" (Uri.to_string uri) line);
              read_remaining_headers uri reader
              >>= fun () ->
              match CCString.split_on_char ' ' line with
              | "HTTP/1.1" :: status :: _ -> (
                  match CCInt.of_string status with
                  | Some status when Cohttp.Code.is_success status && CCString.equal scheme "https"
                    ->
                      Abb.Future.return (Abb_tls.client_tcp sock (tls_config host) host)
                      >>| fun (reader, writer) -> Transport.default reader writer
                  | Some status when Cohttp.Code.is_success status && CCString.equal scheme "http"
                    -> Fut_comb.return_ok (Transport.default reader writer)
                  | _ -> Fut_comb.return_err (`Unexpected_err ("PROXY:RESPONSE:" ^ status)))
              | _ -> Fut_comb.return_err (`Unexpected_err ("PROXY:RESPONSE:" ^ line)))
          | None -> Fut_comb.return_err (`Unexpected_err "PROXY:RESPONSE:EOF")
        in
        let port uri =
          CCOption.get_or
            ~default:
              (match Uri.scheme uri with
              | Some "http" -> 80
              | Some "https" -> 443
              | _ -> assert false)
            (Uri.port uri)
        in
        let get_env name =
          CCOption.or_
            ~else_:(Sys.getenv_opt (CCString.uppercase_ascii name))
            (Sys.getenv_opt (CCString.lowercase_ascii name))
        in
        let http_proxy = CCOption.map Uri.of_string (get_env "http_proxy") in
        let https_proxy = CCOption.map Uri.of_string (get_env "https_proxy") in
        let no_proxy =
          CCOption.map_or
            ~default:[]
            CCFun.(CCString.split_on_char ',' %> CCList.map CCString.trim)
            (get_env "no_proxy")
        in
        let no_verify_tls_cert =
          CCOption.map_or
            ~default:[]
            CCFun.(CCString.split_on_char ',' %> CCList.map CCString.trim)
            (get_env "no_verify_tls_cert")
        in
        let no_verify_tls_name =
          CCOption.map_or
            ~default:[]
            CCFun.(CCString.split_on_char ',' %> CCList.map CCString.trim)
            (get_env "no_verify_tls_name")
        in
        let local_certs_dir = Sys.getenv_opt "CERTS_DIR" in
        let connect tls_config request =
          let tls_config host =
            let config = tls_config host in
            ignore (Otls.Tls_config.set_alpn config "http/1.1");
            CCOption.iter
              (fun local_certs_dir ->
                Logs.debug (fun m -> m "CERTS_DIR : %s" local_certs_dir);
                ignore (Otls.Tls_config.set_ca_path config local_certs_dir))
              local_certs_dir;
            if CCList.mem ~eq:CCString.equal host no_verify_tls_cert || no_verify_tls_cert = [ "*" ]
            then (
              Logs.debug (fun m ->
                  m "NO_VERIFY_CERT : %s : %s" host (CCString.concat " " no_verify_tls_cert));
              Otls.Tls_config.insecure_noverifycert config);
            if CCList.mem ~eq:CCString.equal host no_verify_tls_name || no_verify_tls_name = [ "*" ]
            then (
              Logs.debug (fun m ->
                  m "NO_VERIFY_NAME : %s : %s" host (CCString.concat " " no_verify_tls_name));
              Otls.Tls_config.insecure_noverifyname config);
            config
          in
          let request_host = Uri.host_with_default ~default:"" (Request.uri request) in
          match (Uri.scheme (Request.uri request), http_proxy, https_proxy) with
          | (Some ("http" as scheme), Some proxy, _ | Some ("https" as scheme), _, Some proxy)
            when (not (CCList.mem ~eq:CCString.equal request_host no_proxy)) && no_proxy <> [ "*" ]
            -> (
              (* Proxy only those hosts that are not in the no_proxy list. *)
              Logs.debug (fun m ->
                  m "PROXY : %s : %s" (Uri.to_string (Request.uri request)) (Uri.to_string proxy));
              let run =
                let open Fut_comb.Infix_result_monad in
                connect_with_sock tls_config proxy
                >>= fun (sock, reader, writer) ->
                let host =
                  match Uri.host (Request.uri request) with
                  | Some host -> host
                  | None -> assert false
                in
                let port = port (Request.uri request) in
                let b = Buffer.create 50 in
                Buffer.add_string
                  b
                  (Printf.sprintf "CONNECT %s:%d HTTP/1.1\r\nhost: %s:%d" host port host port);
                (match maybe_add_proxy_auth proxy with
                | Some header ->
                    Buffer.add_string b "\r\n";
                    Buffer.add_string b header
                | None -> ());
                Buffer.add_string b "\r\n\r\n";
                Logs.debug (fun m ->
                    m "proxy : %s : %s" (Uri.to_string (Request.uri request)) (Buffer.contents b));
                let contents = Buffer.to_bytes b in
                Buffered.write
                  writer
                  ~bufs:
                    Abb_intf.Write_buf.[ { buf = contents; pos = 0; len = Bytes.length contents } ]
                >>= fun _ ->
                Buffered.flushed writer
                >>= fun () ->
                finish_proxy_response
                  tls_config
                  (Request.uri request)
                  sock
                  scheme
                  host
                  reader
                  writer
              in
              let open Abb.Future.Infix_monad in
              run
              >>= function
              | Ok _ as res ->
                  Logs.debug (fun m -> m "connected : %s" (Uri.to_string (Request.uri request)));
                  Abb.Future.return res
              | Error (#connect_err as err) ->
                  Logs.debug (fun m ->
                      m
                        "connect_err : %s : %a"
                        (Uri.to_string (Request.uri request))
                        pp_connect_err
                        err);
                  Fut_comb.return_err err
              | Error `E_io | Error `E_no_space ->
                  Logs.debug (fun m ->
                      m "connection_refused : %s" (Uri.to_string (Request.uri request)));
                  Fut_comb.return_err `E_connection_refused
              | Error (`Unexpected exn) ->
                  Logs.debug (fun m ->
                      m
                        "unexpected : %s : %s"
                        (Uri.to_string (Request.uri request))
                        (Printexc.to_string exn));
                  raise exn)
          | _, _, _ -> connect tls_config request
        in
        make ?tls_config ~connect ()
    end

    let connect connector request =
      (connector request
        : (Transport.t, connect_err) result Abb.Future.t
        :> (Transport.t, [> connect_err ]) result Abb.Future.t)

    let do_request ?flush ?body transport request =
      Transport.write_request ?flush ?body transport request

    let read_body_chunk transport = Transport.read_body_chunk transport
    let close transport = Transport.destroy transport

    let read_whole_body transport =
      let rec read' transport b =
        let open Fut_comb.Infix_result_monad in
        read_body_chunk transport
        >>= function
        | Some chunk ->
            Buffer.add_string b chunk;
            read' transport b
        | None -> Fut_comb.return_ok (Buffer.contents b)
      in
      let b = Buffer.create 10 in
      read' transport b

    let call ?flush ?headers ?chunked ?body ?(connector = Connector.of_env ()) meth uri =
      let open Fut_comb.Infix_result_monad in
      let request = Request.make_for_client ?headers ?chunked meth uri in
      Fut_comb.protect_finally
        ~setup:(fun () -> connect connector request)
        (function
          | Ok transport ->
              do_request
                ?flush
                ?body:
                  (CCOption.map (fun body -> fun writer -> Request_io.write_body writer body) body)
                transport
                request
              >>= fun response -> read_whole_body transport >>| fun body -> (response, body)
          | Error _ as err -> Abb.Future.return err)
        ~finally:(function
          | Ok transport -> Transport.destroy transport
          | Error _ -> Fut_comb.unit)

    let get ?headers ?connector uri = call ?headers ?connector `GET uri
    let put ?headers ?body ?connector uri = call ?headers ?body ?connector `PUT uri
    let post ?headers ?body ?connector uri = call ?headers ?body ?connector `POST uri
    let delete ?headers ?connector uri = call ?headers ?connector `DELETE uri
  end

  module Server = struct
    module Scheme = struct
      type t =
        | Http
        | Https of Otls.Tls_config.t
    end

    type handler =
      Abb.Socket.tcp Abb.Socket.t ->
      Request.t ->
      Request_io.IO.ic ->
      Response_io.IO.oc ->
      [ `Stop | `Ok ] Abb.Future.t

    type on_handler_err =
      Request.t ->
      [ `Timeout | `Exn of exn * Printexc.raw_backtrace option ] ->
      [ `Stop | `Ok ] Abb.Future.t

    type on_protocol_err = [ `Timeout | `Error of string ] -> [ `Stop | `Ok ] Abb.Future.t

    module Config = struct
      module View = struct
        type t = {
          scheme : Scheme.t;
          on_handler_err : on_handler_err;
          on_protocol_err : on_protocol_err;
          port : int;
          handler : handler;
          read_header_timeout : Duration.t option;
          handler_timeout : Duration.t option;
        }
      end

      type t = View.t
      type err = [ `Invalid_port ]

      let of_view = function
        | { View.port; _ } when port <= 0 -> Error `Invalid_port
        | t -> Ok t

      let scheme t = t.View.scheme
      let on_handler_err t = t.View.on_handler_err
      let on_protocol_err t = t.View.on_protocol_err
      let port t = t.View.port
      let handler t = t.View.handler
      let read_header_timeout t = t.View.read_header_timeout
      let handler_timeout t = t.View.handler_timeout
    end

    let read_request timeout_opt r =
      match timeout_opt with
      | Some timeout -> (
          let open Abb.Future.Infix_monad in
          Fut_comb.timeout ~timeout:(Abb.Sys.sleep (Duration.to_f timeout)) (Request_io.read r)
          >>| function
          | `Ok r -> `Req r
          | `Timeout -> `Timeout)
      | None ->
          let open Abb.Future.Infix_monad in
          Request_io.read r >>| fun req -> `Req req

    let rec run_handler config conn r w wc =
      let open Abb.Future.Infix_monad in
      read_request (Config.read_header_timeout config) r
      >>= function
      | `Req (`Ok req) -> (
          Logs.debug (fun m -> m "read request : %a" Request.pp_hum req);
          Abb.Future.await
            (Fut_comb.on_failure
               (fun () ->
                 match Config.handler_timeout config with
                 | Some timeout ->
                     let timeout = Abb.Sys.sleep (Duration.to_f timeout) >>| fun () -> `Timeout in
                     let handler = Config.handler config conn req r w >>| fun res -> `Res res in
                     Fut_comb.first timeout handler
                     >>= fun (ret, fut) -> Abb.Future.abort fut >>| fun () -> ret
                 | None -> Config.handler config conn req r w >>| fun res -> `Res res)
               ~failure:(fun () -> Fut_comb.ignore (Abb.Socket.close conn)))
          >>= function
          | `Det (`Res (`Ok as ret)) | `Det (`Res (`Stop as ret)) ->
              Fut_comb.ignore (Buffered.flushed w)
              >>= fun () ->
              Fut_comb.ignore (Abb.Chan.send wc ret) >>= fun () -> run_handler config conn r w wc
          | `Det (`Timeout as err) | (`Exn _ as err) -> (
              (* If it was a timeout, then close the connection.  If it was an
                 exception, this will be done for us in the [failure]
                 handler. *)
              (if err = `Timeout then Fut_comb.ignore (Abb.Socket.close conn)
               else Abb.Future.return ())
              >>= fun () ->
              (* On timeout or error, run the error handler, which can only make
                 decisions about whether to continue or stop the server. *)
              Abb.Future.await
                (Fut_comb.on_failure
                   (fun () -> Config.on_handler_err config req err)
                   ~failure:(fun () -> Fut_comb.unit))
              >>= function
              | `Det (`Ok as ret) | `Det (`Stop as ret) -> Fut_comb.ignore (Abb.Chan.send wc ret)
              | `Aborted -> Abb.Future.return ()
              | `Exn (exn, _) -> Fut_comb.ignore (Abb.Chan.send wc (`Exn exn)))
          | `Aborted -> Abb.Future.return ())
      | `Req `Eof ->
          Fut_comb.ignore (Abb.Socket.close conn)
          >>= fun () -> Fut_comb.ignore (Abb.Future.fork (Abb.Chan.send wc `Ok))
      | `Req (`Invalid str) -> (
          Fut_comb.ignore (Abb.Socket.close conn)
          >>= fun () ->
          Config.on_protocol_err config (`Error str)
          >>= function
          | `Ok -> Fut_comb.ignore (Abb.Chan.send wc `Ok)
          | `Stop -> Fut_comb.ignore (Abb.Chan.send wc `Stop))
      | `Timeout -> (
          Fut_comb.ignore (Abb.Socket.close conn)
          >>= fun () ->
          Config.on_protocol_err config `Timeout
          >>= function
          | `Ok -> Fut_comb.ignore (Abb.Chan.send wc `Ok)
          | `Stop -> Fut_comb.ignore (Abb.Chan.send wc `Stop))

    let rec tcp_accept_loop sock config bf wc =
      let open Abb.Future.Infix_monad in
      Abb.Socket.accept sock
      >>= function
      | Ok conn ->
          bf conn
          >>= fun (r, w) ->
          Abb.Future.fork (run_handler config conn r w wc)
          >>= fun _ -> tcp_accept_loop sock config bf wc
      | Error `E_connection_aborted ->
          (* In the case the client disconnected between accepting and getting
             here, just ignore the error. *)
          tcp_accept_loop sock config bf wc
      | Error `E_file_closed | Error `E_bad_file ->
          (* This should never happen. *)
          assert false
      | Error `E_file_table_full ->
          (* TODO: Find a better way to handle this.  It would be nice to be able
             to propogate this error up. *)
          failwith "file table full"
      | Error `E_invalid ->
          (* This should never happen. *)
          assert false
      | Error (`Unexpected _) ->
          (* This should never happen. *)
          assert false

    let rec handler_response_loop config rc =
      let open Abb.Future.Infix_monad in
      Abb.Chan.recv rc
      >>= function
      | Ok `Ok -> handler_response_loop config rc
      | Ok `Stop -> Fut_comb.return_ok ()
      | Ok (`Exn exn) -> Fut_comb.return_err (`Exn exn)
      | Error `Chan_closed -> Fut_comb.return_ok ()

    let run_tcp_server config bf =
      let open Fut_comb.Infix_result_monad in
      let addr =
        Abb_intf.Socket.Sockaddr.(Inet { addr = Unix.inet_addr_any; port = Config.port config })
      in
      let tcp = CCResult.get_exn (Abb.Socket.Tcp.create ~domain:Abb_intf.Socket.Domain.Inet4) in
      Abb.Future.return (Abb.Socket.Tcp.bind tcp addr)
      >>= fun () ->
      Abb.Future.return (Abb.Socket.listen tcp ~backlog:128)
      >>= fun () ->
      let rc = Abb.Chan.create ~capacity:1000 () in
      let accept_loop = tcp_accept_loop tcp config bf rc in
      Fut_comb.with_finally
        (fun () ->
          let open Abb.Future.Infix_monad in
          Abb.Future.fork accept_loop >>= fun _ -> handler_response_loop config rc)
        ~finally:(fun () ->
          Abb.Chan.close rc;
          Abb.Future.return ())

    let run config =
      let open Abb.Future.Infix_monad in
      let bf conn =
        match Config.scheme config with
        | Scheme.Http -> Abb.Future.return (Buffered_of.of_tcp_socket ~size:4096 conn)
        | Scheme.Https tls_config -> (
            let server = Otls.Tls.server () in
            (* TODO: This can error *)
            ignore (Otls.configure server tls_config);
            match Abb_tls.server_tcp server conn with
            | Ok rw -> Abb.Future.return rw
            | Error `Error -> assert false)
        (* | Ok rw -> Abb.Future.return rw *)
        (* | Error `E_bad_file *)
        (* | Error `E_invalid *)
        (* | Error `E_io *)
        (* | Error `E_is_dir *)
        (* | Error `E_no_space *)
        (* | Error `E_permission *)
        (* | Error `E_pipe *)
        (* | Error `Error *)
        (* | Error (`Unexpected _) -> *)
        (*   (\* Should be impossible *\) *)
        (*   assert false *)
      in
      run_tcp_server config bf
      >>| function
      | Ok () -> Ok ()
      | ( Error (`Exn _)
        | Error `E_address_family_not_supported
        | Error `E_address_in_use
        | Error `E_address_not_available ) as err -> err
      | Error `E_access
      | Error `E_again
      | Error `E_file_closed
      | Error `E_bad_file
      | Error `E_dest_address_required
      | Error `E_invalid
      | Error `E_io
      | Error `E_is_dir
      | Error `E_loop
      | Error `E_name_too_long
      | Error `E_no_entity
      | Error `E_not_dir
      | Error `E_op_not_supported
      | Error `E_permission
      | Error (`Unexpected _) ->
          (* TODO: Handle these. *)
          assert false
  end
end
