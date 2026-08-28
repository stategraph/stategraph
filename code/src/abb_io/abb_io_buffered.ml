module Bytes = BytesLabels

type read_err =
  [ `E_io
  | Abb_intf.Errors.unexpected
  ]
[@@deriving show, eq]

type write_err =
  [ `E_io
  | `E_no_space
  | Abb_intf.Errors.unexpected
  ]
[@@deriving show, eq]

type close_err =
  [ `E_io
  | Abb_intf.Errors.unexpected
  ]
[@@deriving show, eq]

module Make (Fut : Abb_intf.Future.S) = struct
  module Fut_comb = Abb_future_combinators.Make (Fut)

  module View = struct
    type t = {
      read : buf:bytes -> pos:int -> len:int -> (int, read_err) result Fut.t;
      write : bufs:Abb_intf.Write_buf.t list -> (int, write_err) result Fut.t;
      close : unit -> (unit, close_err) result Fut.t;
    }
  end

  module Bytes_io = struct
    type t = {
      mutable r_buf : bytes;
      mutable r_pos : int;
      w_buf : Buffer.t;
    }

    let create b =
      let t = { r_buf = b; r_pos = 0; w_buf = Buffer.create 1024 } in
      let rec read ~buf ~pos ~len =
        if t.r_pos = Bytes.length t.r_buf && Buffer.length t.w_buf > 0 then (
          t.r_buf <- Buffer.to_bytes t.w_buf;
          t.r_pos <- 0;
          Buffer.reset t.w_buf;
          read ~buf ~pos ~len)
        else if t.r_pos = Bytes.length t.r_buf then Fut.return (Ok 0)
        else
          let len = min len (Bytes.length t.r_buf - t.r_pos) in
          Bytes.blit ~src:t.r_buf ~src_pos:t.r_pos ~dst:buf ~dst_pos:pos ~len;
          t.r_pos <- t.r_pos + len;
          Fut.return (Ok len)
      in
      let rec write ~bufs =
        match bufs with
        | [] -> Fut.return (Ok 0)
        | { Abb_intf.Write_buf.buf; pos; len } :: bs -> (
            let open Fut.Infix_monad in
            Buffer.add_subbytes t.w_buf buf pos len;
            write ~bufs:bs
            >>| function
            | Ok n -> Ok (len + n)
            | Error _ -> assert false)
      in
      let close () = Fut.return (Ok ()) in
      View.{ read; write; close }
  end

  type 'a t = {
    cb : View.t;
    buf : bytes;
    mutable pos : int;
    mutable length : int;
  }

  type reader
  type writer

  let of_view ?(size = 1024) cb =
    let r = { cb; buf = Bytes.create size; pos = 0; length = 0 } in
    let w = { cb; buf = Bytes.create size; pos = 0; length = 0 } in
    (r, w)

  let of_bytes ?(size = 1024) b =
    let cb = Bytes_io.create b in
    of_view ~size cb

  let fill_buffer t =
    assert (t.pos >= t.length);
    let open Fut_comb.Infix_result_monad in
    t.cb.View.read ~buf:t.buf ~pos:0 ~len:(Bytes.length t.buf)
    >>| fun n ->
    t.length <- n;
    t.pos <- 0;
    n

  let rec read' t ~buf ~pos ~len =
    assert (pos >= 0);
    assert (len > 0);
    if t.length = 0 || t.pos >= t.length then
      let open Fut_comb.Infix_result_monad in
      fill_buffer t
      >>= function
      | 0 -> Fut.return (Ok 0)
      | _ -> read' t ~buf ~pos ~len
    else
      let len = min (t.length - t.pos) len in
      Bytes.blit ~src:t.buf ~src_pos:t.pos ~dst:buf ~dst_pos:pos ~len;
      t.pos <- t.pos + len;
      Fut.return (Ok len)

  let read t ~buf ~pos ~len =
    (read' t ~buf ~pos ~len : (int, read_err) result Fut.t :> (int, [> read_err ]) result Fut.t)

  let rec read_line_buffer' t b =
    if t.length > 0 && t.pos < t.length then (
      (* Only perform an operation if the buffer has contents, otherwise fill it. *)
      match CCString.find ~start:t.pos ~sub:"\n" (Bytes.unsafe_to_string t.buf) with
      | n when n = -1 || n >= t.length -> (
          let open Fut_comb.Infix_result_monad in
          let len = t.length - t.pos in
          (* We want to be careful here because we want to know when we've hit
             EOF so we can return it, so we only want to enter here if we know
             there is something in the buffer. *)
          Buffer.add_subbytes b t.buf t.pos len;
          t.pos <- t.pos + len;
          fill_buffer t
          >>= function
          | 0 -> Fut.return (Ok `Ok)
          | _ -> read_line_buffer' t b)
      | 0 ->
          t.pos <- 1;
          Fut.return (Ok `Ok)
      | 1 when Bytes.get t.buf 0 = '\r' ->
          t.pos <- 2;
          Fut.return (Ok `Ok)
      | n when Bytes.get t.buf (n - 1) = '\r' ->
          Buffer.add_subbytes b t.buf t.pos (n - t.pos - 1);
          t.pos <- n + 1;
          Fut.return (Ok `Ok)
      | n ->
          Buffer.add_subbytes b t.buf t.pos (n - t.pos);
          t.pos <- n + 1;
          Fut.return (Ok `Ok))
    else
      let open Fut_comb.Infix_result_monad in
      fill_buffer t
      >>= function
      | 0 -> Fut.return (Ok `Eof)
      | _ -> read_line_buffer' t b

  let read_line_buffer t b =
    (read_line_buffer' t b
      : ([ `Ok | `Eof ], read_err) result Fut.t
      :> ([ `Ok | `Eof ], [> read_err ]) result Fut.t)

  let read_line_bytes t =
    let open Fut_comb.Infix_result_monad in
    let b = Buffer.create (Bytes.length t.buf) in
    read_line_buffer t b
    >>| function
    | `Ok -> Some (Buffer.to_bytes b)
    | `Eof -> None

  let read_line t =
    let open Fut_comb.Infix_result_monad in
    read_line_bytes t >>| fun v -> CCOption.map Bytes.to_string v

  let rec flushed' t =
    let open Fut_comb.Infix_result_monad in
    match t.length with
    | 0 -> Fut.return (Ok ())
    | n -> (
        assert (n > 0);
        let buf = Abb_intf.Write_buf.{ buf = t.buf; pos = t.pos; len = t.length } in
        t.cb.View.write ~bufs:[ buf ]
        >>= function
        | n when n = buf.Abb_intf.Write_buf.len ->
            t.pos <- 0;
            t.length <- 0;
            Fut.return (Ok ())
        | n ->
            assert (n < buf.Abb_intf.Write_buf.len);
            t.pos <- t.pos + n;
            t.length <- t.length - n;
            flushed' t)

  let flushed t =
    (flushed' t : (unit, write_err) result Fut.t :> (unit, [> write_err ]) result Fut.t)

  let rec write t ~bufs =
    let open Fut_comb.Infix_result_monad in
    if t.length = Bytes.length t.buf then flushed t >>= fun () -> write t ~bufs
    else
      let open Abb_intf.Write_buf in
      match bufs with
      | [] -> Fut.return (Ok 0)
      | { buf; pos; len } :: bs when len <= Bytes.length t.buf - t.length ->
          (* The entire input buffer can fit in the buffer we are maintaining *)
          Bytes.blit ~src:buf ~src_pos:pos ~dst:t.buf ~dst_pos:t.length ~len;
          t.length <- t.length + len;
          write t ~bufs:bs >>| fun n -> len + n
      | { buf; pos; len } :: bs ->
          assert (len > Bytes.length t.buf - t.length);
          let blit_len = Bytes.length t.buf - t.length in
          Bytes.blit ~src:buf ~src_pos:pos ~dst:t.buf ~dst_pos:t.length ~len:blit_len;
          t.length <- t.length + blit_len;
          write t ~bufs:({ buf; pos = pos + blit_len; len = len - blit_len } :: bs)
          >>| fun n -> blit_len + n

  let close t =
    (t.cb.View.close () : (unit, close_err) result Fut.t :> (unit, [> close_err ]) result Fut.t)

  let close_writer' t =
    let open Fut.Infix_monad in
    flushed t >>= fun _ -> close t

  let close_writer t =
    (close_writer' t
      : (unit, [ close_err | write_err ]) result Fut.t
      :> (unit, [> close_err | write_err ]) result Fut.t)
end

module Of (Abb : Abb_intf.S) = struct
  module T = Make (Abb.Future)

  let of_file ?(size = 1024) file =
    let open Abb.Future.Infix_monad in
    let read ~buf ~pos ~len =
      Abb.File.read file ~buf ~pos ~len
      >>| function
      | Ok n -> Ok n
      | Error `E_bad_file | Error `E_io | Error `E_invalid | Error `E_is_dir -> Error `E_io
      | Error (`Unexpected _) as err -> err
    in
    let write ~bufs =
      Abb.File.write file bufs
      >>| function
      | Ok n -> Ok n
      | Error `E_bad_file | Error `E_io | Error `E_invalid | Error `E_permission | Error `E_pipe ->
          Error `E_io
      | (Error `E_no_space | Error (`Unexpected _)) as err -> err
    in
    let close () =
      Abb.File.close file
      >>| function
      | Ok () -> Ok ()
      | Error _ -> Error `E_io
    in
    let cb = T.View.{ read; write; close } in
    T.of_view ~size cb

  let of_tcp_socket ?(size = 1024) sock =
    let open Abb.Future.Infix_monad in
    let read ~buf ~pos ~len =
      Abb.Socket.Tcp.recv sock ~buf ~pos ~len
      >>| function
      | Ok n -> Ok n
      | Error `E_file_closed
      | Error `E_bad_file
      | Error `E_connection_reset
      | Error `E_not_connected -> Error `E_io
      | Error (`Unexpected _) as err -> err
    in
    let write ~bufs =
      Abb.Socket.Tcp.send sock ~bufs
      >>| function
      | Ok n -> Ok n
      | Error `E_file_closed
      | Error `E_bad_file
      | Error `E_access
      | Error `E_no_buffers
      | Error `E_host_unreachable
      | Error `E_host_down
      | Error `E_network_down
      | Error `E_pipe -> Error `E_io
      | Error (`Unexpected _) as err -> err
    in
    let close () =
      Abb.Socket.close sock
      >>| function
      | Ok () -> Ok ()
      | Error _ -> Error `E_io
    in
    let cb = T.View.{ read; write; close } in
    T.of_view ~size cb
end
