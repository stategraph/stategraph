type err = [ `Error ] [@@deriving show, eq]

external int_of_fd : Unix.file_descr -> int = "%identity"

module Make (Abb : Abb_intf.S with type Native.t = Unix.file_descr) = struct
  module Fut_comb = Abb_future_combinators.Make (Abb.Future)
  module Buffered = Abb_io_buffered.Make (Abb.Future)

  (* libtls holds the descriptor NUMBER it was handed at [connect_socket] time,
     not [sock], so it cannot tell that the handle has been closed underneath
     it.  If that number has since been recycled onto a live socket, libtls'
     read or write gets [EAGAIN] and asks us to wait again -- and
     [Abb.Socket.readable]/[writable] carry no error channel, so on a closed
     handle they resolve at once.  The pair spins.  Stop at the handle instead,
     which is the one thing that stays true once it is closed. *)
  let make_buffered ?size sock tls =
    let closed () = Fut_comb.return_err `E_io in
    let rec read ~buf ~pos ~len =
      assert (pos >= 0);
      assert (len > 0);
      match Otls.Tls.read tls ~pos ~len buf with
      | Ok n -> Fut_comb.return_ok n
      | Error (`Want_pollin | `Want_pollout) when Abb.Socket.is_closed sock -> closed ()
      | Error `Want_pollin ->
          let open Abb.Future.Infix_monad in
          Abb.Socket.readable sock >>= fun () -> read ~buf ~pos ~len
      | Error `Want_pollout ->
          let open Abb.Future.Infix_monad in
          Abb.Socket.writable sock >>= fun () -> read ~buf ~pos ~len
      | Error `Error ->
          let err = Otls.Tls.error tls in
          Fut_comb.return_err (`Unexpected (Failure err))
    in
    let rec write ~bufs =
      match bufs with
      | [] -> Fut_comb.return_ok 0
      | { Abb_intf.Write_buf.buf; pos; len } :: bs -> (
          assert (pos >= 0);
          assert (len > 0);
          match Otls.Tls.write tls ~pos ~len buf with
          | Ok n when n = len ->
              let open Fut_comb.Infix_result_monad in
              write ~bufs:bs >>| fun n' -> n + n'
          | Ok n ->
              let open Fut_comb.Infix_result_monad in
              write ~bufs:Abb_intf.Write_buf.({ buf; pos = pos + n; len = len - n } :: bs)
              >>| fun n' -> n + n'
          | Error (`Want_pollin | `Want_pollout) when Abb.Socket.is_closed sock -> closed ()
          | Error `Want_pollin ->
              let open Abb.Future.Infix_monad in
              Abb.Socket.readable sock >>= fun () -> write ~bufs
          | Error `Want_pollout ->
              let open Abb.Future.Infix_monad in
              Abb.Socket.writable sock >>= fun () -> write ~bufs
          | Error `Error ->
              let err = Otls.Tls.error tls in
              Fut_comb.return_err (`Unexpected (Failure err)))
    in
    let close () =
      let open Abb.Future.Infix_monad in
      Otls.Tls.destroy tls;
      Abb.Socket.close sock >>| fun _ -> Ok ()
    in
    Buffered.of_view ?size Buffered.View.{ read; write; close }

  let client_tcp ?size sock conf servername =
    let open CCResult.Infix in
    let client = Otls.Tls.client () in
    Otls.configure client conf
    >>= fun () ->
    Otls.Tls.connect_socket client (int_of_fd (Abb.Socket.Tcp.to_native sock)) servername
    >>= fun () -> Ok (make_buffered ?size sock client)

  let server_tcp ?size server client_sock =
    let open CCResult.Infix in
    Otls.Tls.accept_socket server (int_of_fd (Abb.Socket.Tcp.to_native client_sock))
    >>= fun client -> Ok (make_buffered ?size client_sock client)
end
