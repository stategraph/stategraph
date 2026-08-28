module Make (Abb : Abb_intf.S) = struct
  module Fut_comb = Abb_future_combinators.Make (Abb.Future)

  type t = Abb.Socket.tcp Abb.Socket.t Abb.Chan.t

  type errors =
    [ Abb_intf.Errors.bind
    | Abb_intf.Errors.sock_create
    | Abb_intf.Errors.listen
    ]

  let rec tcp_accept_loop sock wc =
    let open Abb.Future.Infix_monad in
    Abb.Socket.accept sock
    >>= function
    | Ok conn -> send_conn sock wc conn
    | Error `E_connection_aborted ->
        (* In the case the client disconnected between accepting and getting here,
           just ignore the error. *)
        tcp_accept_loop sock wc
    | Error `E_file_closed | Error `E_bad_file ->
        (* This should never happen. *)
        assert false
    | Error `E_file_table_full ->
        (* FIXME: Find a better way to handle this.  It would be nice to be able to
           propagate this error up. *)
        Abb.Chan.close wc;
        failwith "file table full"
    | Error `E_invalid ->
        (* This should never happen. *)
        assert false
    | Error (`Unexpected _) ->
        (* This should never happen. *)
        assert false

  and send_conn sock wc conn =
    let open Abb.Future.Infix_monad in
    Abb.Chan.send wc conn
    >>= function
    | Ok () -> tcp_accept_loop sock wc
    | Error `Chan_closed ->
        Fut_comb.ignore (Abb.Socket.close sock)
        >>= fun () -> Fut_comb.ignore (Abb.Socket.close conn)

  let run ?(backlog = 128) sockaddr =
    let open Fut_comb.Infix_result_monad in
    Abb.Future.return (Abb.Socket.Tcp.create ~domain:Abb_intf.Socket.Domain.Inet4)
    >>= fun tcp ->
    Abb.Future.return (Abb.Socket.Tcp.bind tcp sockaddr)
    >>= fun () ->
    Abb.Future.return (Abb.Socket.listen tcp ~backlog)
    >>= fun () ->
    let ch = Abb.Chan.create ~capacity:1000 () in
    Fut_comb.to_result (Abb.Future.fork (tcp_accept_loop tcp ch)) >>| fun _ -> ch
end
