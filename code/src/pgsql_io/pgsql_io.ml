let src = Logs.Src.create "pgsql.io"

module Logs = (val Logs.src_log src : Logs.LOG)

let buf_size = 1024 * 8
let buf_size_threshold = 1024 * 8

exception Nested_tx_not_supported

module Backend_key_data = struct
  (* Captured for the unimplemented PostgreSQL CancelRequest flow. *)
  type t = {
    pid : int32;
    secret_key : int32;
  }
  [@@warning "-69"]
end

type notification = {
  pid : int32;
  channel : string;
  payload : string;
}

type t = {
  mutable connected : bool;
  decoder : Pgsql_codec.Decode.t;
  buf : Bytes.t;
  scratch : Buffer.t;
  r : Abbs_io_buffered.reader Abbs_io_buffered.t;
  w : Abbs_io_buffered.writer Abbs_io_buffered.t;
  backend_key_data : Backend_key_data.t;
  mutable unique_id : int;
  notice_response : (char * string) list -> unit;
  (* Asynchronous NotificationResponse frames (LISTEN/NOTIFY) are enqueued here as
     they are decoded -- during [wait_for_notification] and during any ordinary
     query/fetch on this connection.  [wait_for_notification] pops the front (or
     blocks for the next); [get_notification] pops without blocking. *)
  notifications : notification Queue.t;
  (* Set once [listen] has been issued on this connection; a conservative "this
     connection may have active LISTENs" flag (not a per-channel set).  Lets the
     pool skip an [UNLISTEN *] round trip on return when no LISTEN was ever used.
     Cleared by [unlisten_all]. *)
  mutable listening : bool;
  mutable expected_frames : (Pgsql_codec.Frame.Backend.t -> bool) list;
  mutable in_tx : bool;
  (* Atomic so that concurrent claim attempts from different domains
     resolve via a single CAS — at most one wins and proceeds, the
     others see [busy=true] and raise. *)
  busy : bool Atomic.t;
  buf_size_threshold : int;
  id : Uuidm.t;
  (* Per-connection prepared-statement cache: query text -> server-side
     statement name.  A PostgreSQL prepared statement created by [Parse] lives
     for the session, so a query executed more than once on the same connection
     can skip re-parsing (and re-planning) by reusing its cached name.  The cache
     is cleared on transaction rollback (a statement first parsed inside a
     rolled-back transaction is dropped by the server) and evicted on a
     stale-statement error. *)
  stmt_cache : (string, string) Hashtbl.t;
}
[@@warning "-69"]

let add_expected_frame t frame = t.expected_frames <- frame :: t.expected_frames
let add_expected_frames t frames = t.expected_frames <- List.rev frames @ t.expected_frames

let consume_expected_frames t =
  let expected_frames = t.expected_frames in
  t.expected_frames <- [];
  List.rev expected_frames

let gen_unique_id t prefix =
  let ret = prefix ^ string_of_int t.unique_id in
  t.unique_id <- t.unique_id + 1;
  ret

let stmt_cache_find t query = Hashtbl.find_opt t.stmt_cache query
let stmt_cache_add t query name = Hashtbl.replace t.stmt_cache query name
let stmt_cache_remove t query = Hashtbl.remove t.stmt_cache query
let stmt_cache_clear t = Hashtbl.reset t.stmt_cache

(* Defined up here (rather than near the other lifecycle functions) so the Io
   module can call it directly when it needs to fail a connection. *)
let destroy t =
  (* Destroy is idempotent *)
  if t.connected then (
    t.connected <- false;
    Abbs_future_combinators.ignore (Abbs_io_buffered.close_writer t.w))
  else Abb.Future.return ()

type integrity_err = {
  code : string;
  message : string;
  detail : string option;
  constraint_name : string option;
  table_name : string option;
  schema_name : string option;
  column_name : string option;
}
[@@deriving show]

type pgsql_err = {
  code : string;
  message : string;
  detail : string option;
  hint : string option;
}
[@@deriving show]

module Io = struct
  type err = [ `Parse_error of Pgsql_codec.Decode.err ] [@@deriving show]

  let encode_frame buf frame =
    Buffer.clear buf;
    Pgsql_codec.Encode.frontend_msg buf frame;
    Buffer.to_bytes buf

  let write_buf bytes = Abb_intf.Write_buf.{ buf = bytes; pos = 0; len = Bytes.length bytes }

  let send_frame conn frame =
    if conn.connected then (
      let send_frame' =
        Logs.debug (fun m ->
            m "%s Tx %a" (Uuidm.to_string conn.id) Pgsql_codec.Frame.Frontend.pp frame);
        let open Abbs_future_combinators.Infix_result_monad in
        let bytes = encode_frame conn.scratch frame in
        Abbs_io_buffered.write conn.w ~bufs:[ write_buf bytes ]
        >>= fun _ -> Abbs_io_buffered.flushed conn.w
      in
      let open Abb.Future.Infix_monad in
      send_frame'
      >>| function
      | Ok _ as r -> r
      | Error `E_io | Error `E_no_space | Error (`Unexpected _) ->
          conn.connected <- false;
          Error `Disconnected)
    else Abb.Future.return (Error `Disconnected)

  (* Send several frames as a single buffered write + flush.  Each frame is
     encoded into its own fresh byte buffer (encode_frame copies out via
     Buffer.to_bytes), so reusing [conn.scratch] across frames is safe.  This
     keeps a Parse/Bind/Execute/Sync batch in one socket write rather than one
     write+flush per frame, which avoids the latency of many small TLS records
     and Nagle/delayed-ACK stalls between them. *)
  let send_frames conn frames =
    if conn.connected then (
      let send_frames' =
        List.iter
          (fun frame ->
            Logs.debug (fun m ->
                m "%s Tx %a" (Uuidm.to_string conn.id) Pgsql_codec.Frame.Frontend.pp frame))
          frames;
        let open Abbs_future_combinators.Infix_result_monad in
        let bufs = List.map (fun frame -> write_buf (encode_frame conn.scratch frame)) frames in
        Abbs_io_buffered.write conn.w ~bufs >>= fun _ -> Abbs_io_buffered.flushed conn.w
      in
      let open Abb.Future.Infix_monad in
      send_frames'
      >>| function
      | Ok _ as r -> r
      | Error `E_io | Error `E_no_space | Error (`Unexpected _) ->
          conn.connected <- false;
          Error `Disconnected)
    else Abb.Future.return (Error `Disconnected)

  let backend_msg conn len buf =
    if Pgsql_codec.Decode.buffer_length conn.decoder > conn.buf_size_threshold then
      Abb.Thread.run (fun () -> Pgsql_codec.Decode.backend_msg conn.decoder ~pos:0 ~len buf)
    else Abb.Future.return (Pgsql_codec.Decode.backend_msg conn.decoder ~pos:0 ~len buf)

  (* Pull asynchronous NotificationResponse frames out of a freshly decoded frame
     list, delivering each (in arrival order) to the connection's registered
     handler and dropping it when none is registered.  This is the single point
     every decoded frame passes through, so centralising it here means no
     downstream consume loop ever sees a NotificationResponse: a notification
     interleaved into any query/fetch/copy stream is enqueued here instead of
     being mistaken for an unexpected frame and tearing down the connection.
     Returns the remaining frames. *)
  let dispatch_notifications conn frames =
    CCList.filter
      (function
        | Pgsql_codec.Frame.Backend.NotificationResponse { pid; channel; payload } ->
            Queue.add { pid; channel; payload } conn.notifications;
            false
        | _ -> true)
      frames

  (* [backend_msg] with notification extraction folded in.  Used by every frame
     consumer so notifications are queued (never delivered to a consume loop). *)
  let backend_msg_dispatch conn len buf =
    let open Abb.Future.Infix_monad in
    backend_msg conn len buf
    >>| function
    | Ok frames -> Ok (dispatch_notifications conn frames)
    | Error _ as err -> err

  (* Decode synchronously, never via [Abb.Thread.run].  [wait_for_notification]
     relies on read -> decode -> enqueue running as one uninterruptible step on the
     scheduler's single domain: an abort (from a wrapping [Abbs_future_combinators
     .timeout]) is then processed as a separate step that can only land while we are
     blocked on the socket read -- where no bytes have been consumed -- and never
     between consuming bytes off the socket and enqueueing the notification they
     decode to.  Offloading the decode to another domain would open exactly that
     gap (the bytes get consumed and the enqueue continuation gets skipped on
     abort), so we decode inline.  Notification traffic is small, so this never
     blocks the loop the way a large query response could. *)
  let backend_msg_sync conn len buf =
    Abb.Future.return (Pgsql_codec.Decode.backend_msg conn.decoder ~pos:0 ~len buf)

  let rec wait_for_frames conn =
    let open Abb.Future.Infix_monad in
    backend_msg_dispatch conn 0 conn.buf
    >>= fun ret ->
    match ret with
    | Ok [] -> (
        Abbs_io_buffered.read conn.r ~buf:conn.buf ~pos:0 ~len:(Bytes.length conn.buf)
        >>= function
        | Ok 0 | Error `E_io | Error (`Unexpected _) ->
            conn.connected <- false;
            Abb.Future.return (Error `Disconnected)
        | Ok n ->
            (* Logs.debug (fun m -> m "Rx = %S%!" (Bytes.to_string (Bytes.sub conn.buf 0 n))); *)
            backend_msg_dispatch conn n conn.buf >>= fun ret -> wait_for_frames' conn ret)
    | r -> wait_for_frames' conn r

  and wait_for_frames' conn = function
    | Ok [] when Pgsql_codec.Decode.needed_bytes conn.decoder = None -> wait_for_frames conn
    | Ok [] -> wait_for_frame_needed_bytes conn
    | Ok fs as r ->
        List.iter
          (fun frame ->
            Logs.debug (fun m ->
                m "%s Rx %a" (Uuidm.to_string conn.id) Pgsql_codec.Frame.Backend.pp frame))
          fs;
        Abb.Future.return r
    | Error err -> Abb.Future.return (Error (`Parse_error err))

  and wait_for_frame_needed_bytes conn =
    (* Read all the needed bytes, this is an important performance optimization
       for large queries responses. *)
    match Pgsql_codec.Decode.needed_bytes conn.decoder with
    | Some needed_bytes -> (
        let open Abb.Future.Infix_monad in
        let b = Buffer.create needed_bytes in
        let buf = Bytes.create buf_size in
        let needed_bytes = ref needed_bytes in
        Abbs_future_combinators.retry
          ~f:(fun () ->
            let open Abbs_future_combinators.Infix_result_monad in
            Abbs_io_buffered.read conn.r ~buf ~pos:0 ~len:(Bytes.length buf)
            >>= fun n ->
            Buffer.add_subbytes b buf 0 n;
            needed_bytes := !needed_bytes - n;
            Abb.Future.return (Ok n))
          ~while_:(function
            | Ok 0 | Error _ -> false
            | Ok _ -> !needed_bytes > 0)
          ~betwixt:(fun _ -> Abbs_future_combinators.unit)
        >>= function
        | Ok 0 | Error `E_io | Error (`Unexpected _) ->
            conn.connected <- false;
            Abb.Future.return (Error `Disconnected)
        | Ok _ -> (
            let buf = Buffer.to_bytes b in
            backend_msg_dispatch conn (Bytes.length buf) buf
            >>= fun ret ->
            match ret with
            | Ok [] -> wait_for_frames conn
            | Ok _ as r -> Abb.Future.return r
            | Error err -> Abb.Future.return (Error (`Parse_error err))))
    | None -> assert false

  let rec consume_until ?(fs = []) conn f =
    let open Abbs_future_combinators.Infix_result_monad in
    (if fs <> [] then Abb.Future.return (Ok fs) else wait_for_frames conn)
    >>= fun received_fs ->
    match CCList.drop_while (fun fr -> not (f fr)) received_fs with
    | [] -> consume_until conn f
    | _fr :: fs ->
        (* Printf.printf "fr = %s\n%!" (Pgsql_codec.Frame.Backend.show fr);
         * List.iter (fun frame -> Printf.printf "Fs %s\n%!" (Pgsql_codec.Frame.Backend.show frame)) fs; *)
        Abb.Future.return (Ok fs)

  (* The backend's ReadyForQuery status byte ('I' idle, 'T' in tx, 'E' failed
     tx) is the authoritative transaction state.  Trust it over our own in_tx
     flag.  Gating the drain on in_tx (rather than resyncing from the server)
     means a stale in_tx makes us reject the real ReadyForQuery and wait forever
     for one that will never come -- a permanent idle-in-transaction hang.  Loud
     log on disagreement so the desync is visible in production. *)
  let resync_in_tx conn status =
    let backend_in_tx = status = 'T' || status = 'E' in
    if backend_in_tx <> conn.in_tx then (
      (* The connection was in an unexpected state: our in_tx flag disagreed with
         the backend's authoritative transaction status.  Resync the flag so this
         op fails fast (instead of hanging on a ReadyForQuery that never comes),
         but also FAIL THE CONNECTION -- a desync means we can no longer trust the
         frame stream, so mark it dead.  The pool destroys dead connections on
         return rather than handing the corruption to the next caller. *)
      Logs.err (fun m ->
          m
            "%s CONNECTION DESYNC DETECTED : in_tx=%b backend_status=%c : failing and closing the \
             connection"
            (Uuidm.to_string conn.id)
            conn.in_tx
            status);
      conn.in_tx <- backend_in_tx;
      (* Fail the connection: a desync means we can no longer trust the frame
         stream.  [destroy] flips [connected] AND closes the writer, so the
         underlying socket is released (not leaked) and the connection is never
         reused.  Idempotent, so a later [destroy] from the pool is a safe
         no-op. *)
      destroy conn)
    else (
      conn.in_tx <- backend_in_tx;
      Abb.Future.return ())

  (* Drain frames up to the next ReadyForQuery -- [consume] runs the actual
     consume loop with the status-capturing predicate we pass it -- then resync
     conn.in_tx from the backend's authoritative status.  Shared by
     [error_response] and [reset] so the ReadyForQuery / in_tx handling lives in
     exactly one place. *)
  let drain_to_ready_for_query conn ~consume =
    let open Abbs_future_combinators.Infix_result_monad in
    conn.expected_frames <- [];
    let status = ref None in
    consume (function
      | Pgsql_codec.Frame.Backend.ReadyForQuery { status = s } ->
          status := Some s;
          true
      | _ -> false)
    >>= fun res ->
    let open Abb.Future.Infix_monad in
    (match !status with
      | Some s -> resync_in_tx conn s
      | None -> Abb.Future.return ())
    >>= fun () ->
    assert (res = []);
    Abb.Future.return (Ok ())

  let error_response conn fs = drain_to_ready_for_query conn ~consume:(consume_until ~fs conn)

  let handle_err_frame msgs =
    let c = CCList.Assoc.get_exn ~eq:Char.equal 'C' msgs in
    let m = CCList.Assoc.get_exn ~eq:Char.equal 'M' msgs in
    let d = CCList.Assoc.get ~eq:Char.equal 'D' msgs in
    let h = CCList.Assoc.get ~eq:Char.equal 'H' msgs in
    let n = CCList.Assoc.get ~eq:Char.equal 'n' msgs in
    let t = CCList.Assoc.get ~eq:Char.equal 't' msgs in
    let s = CCList.Assoc.get ~eq:Char.equal 's' msgs in
    let col = CCList.Assoc.get ~eq:Char.equal 'c' msgs in
    let pgsql_err = { code = c; message = m; detail = d; hint = h } in
    let integrity_err =
      {
        code = c;
        message = m;
        detail = d;
        constraint_name = n;
        table_name = t;
        schema_name = s;
        column_name = col;
      }
    in
    match c with
    (* Unique/exclusion violations *)
    | "23505" | "23P01" -> `Unique_violation_err integrity_err
    (* Foreign key / restrict *)
    | "23503" | "23001" -> `Foreign_key_err integrity_err
    (* Other integrity constraints *)
    | "23000" | "23502" | "23514" | "40002" -> `Integrity_err integrity_err
    (* Deadlock / serialization failure *)
    | "40001" | "40P01" -> `Deadlock_detected pgsql_err
    (* Lock timeout *)
    | "55P03" -> `Lock_timeout pgsql_err
    (* Statement timeout *)
    | "57014" -> `Statement_timeout
    (* Syntax / access errors *)
    | c when String.length c >= 2 && String.sub c 0 2 = "42" -> `Syntax_err pgsql_err
    (* All other SQLSTATE codes *)
    | _ -> `Pgsql_err pgsql_err

  let rec consume_matching ?(skip_leading_unmatched = false) conn fs =
    let open Abbs_future_combinators.Infix_result_monad in
    wait_for_frames conn
    >>= fun received_fs -> match_frames ~skip_leading_unmatched conn fs received_fs

  and match_frames ~skip_leading_unmatched conn fs received_fs =
    match (fs, received_fs) with
    | [], _ -> Abb.Future.return (Ok received_fs)
    | _, [] -> consume_matching ~skip_leading_unmatched conn fs
    | f :: fs, r_f :: r_fs when f r_f -> match_frames ~skip_leading_unmatched:false conn fs r_fs
    | _, Pgsql_codec.Frame.Backend.NoticeResponse { msgs } :: rfs ->
        conn.notice_response msgs;
        match_frames ~skip_leading_unmatched conn fs rfs
    | _, (Pgsql_codec.Frame.Backend.ErrorResponse { msgs } :: _ as r_fs) ->
        let open Abb.Future.Infix_monad in
        error_response conn r_fs >>= fun _ -> Abb.Future.return (Error (handle_err_frame msgs))
    | _, _ :: r_fs when skip_leading_unmatched -> match_frames ~skip_leading_unmatched conn fs r_fs
    | _, _ ->
        let open Abb.Future.Infix_monad in
        reset conn >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame received_fs))

  and reset conn =
    let open Abbs_future_combinators.Infix_result_monad in
    send_frame conn Pgsql_codec.Frame.Frontend.Sync
    >>= fun () ->
    drain_to_ready_for_query conn ~consume:(fun is_ready ->
        consume_matching ~skip_leading_unmatched:true conn [ is_ready ])

  (* Pop the oldest queued notification, or -- if the queue is empty -- block
     reading from the connection (enqueueing every NotificationResponse via
     [dispatch_notifications]) until one arrives, then return it.
     [`Disconnected] if the connection drops.  Any non-notification frame -- which
     should not occur on a connection used solely for listening -- resets and
     reports [`Unmatching_frame].  Takes no timeout: callers wrap it in
     [Abbs_future_combinators.timeout].

     Abort safety (a wrapping [timeout] aborts this future as a notification may be
     arriving): the only suspension point is the [Abbs_io_buffered.read] below.
     Everything from a completed read through [backend_msg_sync] (synchronous
     decode) and [dispatch_notifications] (synchronous enqueue) runs inline in a
     single scheduler step on the one driving domain, so an abort -- handled as a
     separate step -- can only land *while blocked on the read*, before any bytes
     are consumed off the socket.  It can never land after bytes are consumed but
     before the notification they decode to is enqueued.  Hence an aborted wait
     either consumed nothing (the notification is still on the socket for the next
     read) or fully enqueued it; the connection and decoder are never left
     half-consumed.  [backend_msg_sync] (not [backend_msg]) is essential here: a
     threaded decode would break this single-step atomicity. *)
  let rec wait_for_notification conn =
    match Queue.take_opt conn.notifications with
    | Some n -> Abb.Future.return (Ok n)
    | None ->
        let open Abb.Future.Infix_monad in
        backend_msg_sync conn 0 conn.buf >>= fun ret -> wait_for_notification_frames conn ret

  and wait_for_notification_frames conn ret =
    let open Abb.Future.Infix_monad in
    match ret with
    | Error err -> Abb.Future.return (Error (`Parse_error err))
    | Ok frames -> (
        let remaining = dispatch_notifications conn frames in
        match Queue.take_opt conn.notifications with
        | Some n -> Abb.Future.return (Ok n)
        | None -> (
            match remaining with
            | [] -> (
                Abbs_io_buffered.read conn.r ~buf:conn.buf ~pos:0 ~len:(Bytes.length conn.buf)
                >>= function
                | Ok 0 | Error `E_io | Error (`Unexpected _) ->
                    conn.connected <- false;
                    Abb.Future.return (Error `Disconnected)
                | Ok n ->
                    backend_msg_sync conn n conn.buf
                    >>= fun ret -> wait_for_notification_frames conn ret)
            | fs -> reset conn >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame fs))))
end

type frame_err =
  [ `Unmatching_frame of Pgsql_codec.Frame.Backend.t list
  | Io.err
  | `Disconnected
  ]
[@@deriving show]

type sql_parse_err =
  [ `Empty_variable_name
  | `Unclosed_quote of string
  | `Unknown_variable of string
  ]
[@@deriving show]

type err =
  [ `Pgsql_err of pgsql_err
  | frame_err
  | `Disconnected
  | `Bad_result of string option list
  | `Integrity_err of integrity_err
  | `Unique_violation_err of integrity_err
  | `Foreign_key_err of integrity_err
  | `Deadlock_detected of pgsql_err
  | `Lock_timeout of pgsql_err
  | `Statement_timeout
  | `Syntax_err of pgsql_err
  | sql_parse_err
  ]
[@@deriving show]

let binary_of_numeric z =
  let module Bv = Pgsql_codec.Binary_value.Encode in
  if Z.equal z Z.zero then (
    let buf = Bytes.create 8 in
    Bytes.fill buf 0 8 '\000';
    Bytes.to_string buf)
  else
    let sign = if Z.sign z < 0 then 0x4000 else 0x0000 in
    let abs_z = Z.abs z in
    let base = Z.of_int 10000 in
    let rec collect_digits z acc =
      if Z.equal z Z.zero then acc
      else
        let q, r = Z.div_rem z base in
        collect_digits q (Z.to_int r :: acc)
    in
    let digits = collect_digits abs_z [] in
    let ndigits = List.length digits in
    let weight = ndigits - 1 in
    let buf = Buffer.create (8 + (ndigits * 2)) in
    Buffer.add_string buf (Bv.int2 ndigits);
    Buffer.add_string buf (Bv.int2 weight);
    Buffer.add_string buf (Bv.int2 sign);
    Buffer.add_string buf (Bv.int2 0);
    List.iter (fun d -> Buffer.add_string buf (Bv.int2 d)) digits;
    Buffer.contents buf

module Typed_sql = struct
  module Var = struct
    module Oid = Pgsql_codec_type.Oid

    type 'a t = {
      name : string;
      oid : Pgsql_codec_type.Oid.t;
      oid_num : int;
      binary : bool;
      f : 'a -> string option list -> string option list;
    }

    type 'a v = string -> 'a t

    let make oid f name = { name; oid; f; oid_num = oid.Pgsql_codec_type.Oid.oid; binary = true }

    let make_text oid f name =
      { name; oid; f; oid_num = oid.Pgsql_codec_type.Oid.oid; binary = false }

    let make_array oid f name =
      { name; oid; f; oid_num = oid.Pgsql_codec_type.Oid.array_oid; binary = true }

    module Bv = Pgsql_codec.Binary_value.Encode

    let smallint = make Oid.int2 (fun n vs -> Some (Bv.int2 n) :: vs)
    let integer = make Oid.int4 (fun n vs -> Some (Bv.int4 n) :: vs)
    let bigint = make Oid.int8 (fun n vs -> Some (Bv.int8 n) :: vs)
    let decimal = make Oid.numeric (fun n vs -> Some (binary_of_numeric n) :: vs)
    let numeric = decimal
    let real = make Oid.float4 (fun n vs -> Some (Bv.float4 n) :: vs)
    let double = make Oid.float8 (fun n vs -> Some (Bv.float8 n) :: vs)
    let smallserial = smallint
    let serial = integer
    let bigserial = bigint
    let money = make Oid.money (fun n vs -> Some (Bv.int8 n) :: vs)
    let text = make Oid.text (fun s vs -> Some s :: vs)
    let varchar = make Oid.varchar (fun s vs -> Some s :: vs)
    let char = make Oid.char (fun s vs -> Some s :: vs)
    let bytea = make Oid.bytea (fun s vs -> Some s :: vs)
    let json = make Oid.json (fun v vs -> Some (Yojson.Safe.to_string v) :: vs)
    let jsonpath = make_text Oid.jsonpath (fun s vs -> Some s :: vs)
    let tsquery = make_text Oid.tsquery (fun s vs -> Some s :: vs)
    let uuid = make Oid.uuid (fun uuid vs -> Some (Uuidm.to_binary_string uuid) :: vs)
    let boolean = make Oid.bool (fun b vs -> Some (Bv.bool b) :: vs)
    let date = make_text Oid.date (fun s vs -> Some s :: vs)
    let time = make_text Oid.time (fun s vs -> Some s :: vs)
    let timetz = make_text Oid.timetz (fun s vs -> Some s :: vs)
    let timestamp = make_text Oid.timestamp (fun s vs -> Some s :: vs)
    let timestamptz = make_text Oid.timestamptz (fun s vs -> Some s :: vs)
    let ud t f = { t with f = (fun v vs -> t.f (f v) vs) }

    let option t =
      {
        t with
        f =
          (fun o vs ->
            match o with
            | None -> None :: vs
            | Some v -> t.f v vs);
      }

    let array t =
      make_array
        t.oid
        (fun arr vs ->
          let module Bv = Pgsql_codec.Binary_value.Encode in
          let buf = Buffer.create 64 in
          Buffer.add_string buf (Bv.int4 1l);
          Buffer.add_string buf (Bv.int4 0l);
          Buffer.add_string buf (Bv.int4 (Int32.of_int t.oid_num));
          Buffer.add_string buf (Bv.int4 (Int32.of_int (List.length arr)));
          Buffer.add_string buf (Bv.int4 1l);
          List.iter
            (fun v ->
              match t.f v [] with
              | [ Some encoded ] ->
                  Buffer.add_string buf (Bv.int4 (Int32.of_int (String.length encoded)));
                  Buffer.add_string buf encoded
              | [ None ] -> Buffer.add_string buf (Bv.int4 (-1l))
              | _ -> assert false)
            arr;
          Some (Buffer.contents buf) :: vs)
        t.name

    let str_array = array
  end

  (* We use text format for most return types rather than binary. Because
     pgsql_io does not control the SQL query, it is easy to specify the wrong
     Ret type for a column. With binary format, integer types are not robust to
     mismatches: a smallint and an integer have different binary encodings, so
     using the wrong Ret type causes runtime failures. With text format, parsing
     a text "42" works the same whether the column is smallint, integer, or
     bigint. We use binary format only for types where text parsing would lose
     information or be significantly less efficient (text, bytea, uuid). *)
  module Ret = struct
    module B = struct
      let text s = Some s
      let bytea s = Some s
      let uuid s = Uuidm.of_binary_string s
      let int s = Pgsql_codec.Binary_value.Decode.int2 s
      let int32 s = Pgsql_codec.Binary_value.Decode.int4 s
      let int64 s = Pgsql_codec.Binary_value.Decode.int8 s
      let float s = Pgsql_codec.Binary_value.Decode.float4 s
      let double s = Pgsql_codec.Binary_value.Decode.float8 s
      let bool s = Pgsql_codec.Binary_value.Decode.bool s
    end

    type 'a t = {
      binary : bool;
      f : string option list -> ('a * string option list) option;
    }

    let text_ret parse =
      {
        binary = false;
        f =
          (function
          | Some s :: rest -> CCOption.map (fun v -> (v, rest)) (parse s)
          | _ -> None);
      }

    let bin_ret parse =
      {
        binary = true;
        f =
          (function
          | Some s :: rest -> CCOption.map (fun v -> (v, rest)) (parse s)
          | _ -> None);
      }

    let u t f =
      {
        binary = t.binary;
        f =
          (fun xs ->
            match t.f xs with
            | Some (v, rest) -> (
                match f v with
                | Some v' -> Some (v', rest)
                | None -> None)
            | None -> None);
      }

    let smallint = text_ret (fun s -> CCOption.wrap int_of_string s)
    let integer = text_ret (fun s -> Int32.of_string_opt s)
    let bigint = text_ret (fun s -> Int64.of_string_opt s)

    let decimal =
      text_ret (fun s ->
          match CCOption.wrap Z.of_string s with
          | Some z -> Some z
          | None -> None)

    let numeric = decimal
    let real = text_ret (fun s -> float_of_string_opt s)
    let double = text_ret (fun s -> float_of_string_opt s)
    let smallserial = smallint
    let serial = integer
    let bigserial = bigint
    let money = text_ret (fun s -> Int64.of_string_opt s)
    let text = bin_ret B.text
    let varchar = text_ret (fun s -> Some s)
    let char = text_ret (fun s -> Some s)
    let bytea = bin_ret B.bytea
    let json = text_ret (fun s -> CCOption.wrap Yojson.Safe.from_string s)
    let jsonb = text_ret (fun s -> CCOption.wrap Yojson.Safe.from_string s)
    let uuid = bin_ret B.uuid

    let boolean =
      text_ret (fun s ->
          match s with
          | "t" -> Some true
          | "f" -> Some false
          | _ -> None)

    let smallint_b = bin_ret B.int
    let integer_b = bin_ret B.int32
    let bigint_b = bin_ret B.int64
    let real_b = bin_ret B.float
    let double_b = bin_ret B.double
    let smallserial_b = smallint_b
    let serial_b = integer_b
    let bigserial_b = bigint_b
    let money_b = bigint_b
    let boolean_b = bin_ret B.bool
    let varchar_b = bin_ret B.text
    let char_b = bin_ret B.text
    let ud f = { binary = false; f = (fun xs -> f xs) }

    let ud' f =
      {
        binary = false;
        f =
          (function
          | Some s :: rest -> CCOption.map (fun v -> (v, rest)) (f s)
          | _ -> None);
      }

    let option t =
      {
        binary = t.binary;
        f =
          (function
          | None :: xs -> Some (None, xs)
          | xs -> (
              match t.f xs with
              | Some (v, xs) -> Some (Some v, xs)
              | None -> None));
      }

    let debug f t =
      {
        binary = t.binary;
        f =
          (fun v ->
            f v;
            t.f v);
      }
  end

  type ('q, 'qr, 'p, 'pr) t =
    | Sql : ('qr, 'qr, 'pr, 'pr) t
    | Const : (('q, 'qr, 'p, 'pr) t * string) -> ('q, 'qr, 'p, 'pr) t
    | Variable : (('q, 'a -> 'qr, 'p, 'pr) t * 'a Var.t) -> ('q, 'qr, 'p, 'pr) t
    | Ret : (('q, 'qr, 'p, 'a -> 'pr) t * 'a Ret.t) -> ('q, 'qr, 'p, 'pr) t

  let sql = Sql
  let ( /^ ) t s = Const (t, s)
  let ( /% ) t v = Variable (t, v)
  let ( // ) t r = Ret (t, r)

  let rec concat : type q qr p pr qr' pr'.
      (q, qr, p, pr) t -> (qr, qr', pr, pr') t -> (q, qr', p, pr') t =
   fun t1 t2 ->
    match t2 with
    | Sql -> t1
    | Ret (t, r) -> Ret (concat t1 t, r)
    | Const (t, s) -> Const (concat t1 t, s)
    | Variable (t, v) -> Variable (concat t1 t, v)

  let ( /^^ ) t1 t2 = concat t1 t2

  let rec kbind' : type q qr p pr. (string option list -> qr) -> (q, qr, p, pr) t -> q =
   fun k t ->
    match t with
    | Sql -> k []
    | Ret (t, _) -> kbind' k t
    | Const (t, _s) -> kbind' k t
    | Variable (t, v) ->
        kbind'
          (fun vs v' ->
            let ret = v.Var.f v' vs in
            k ret)
          t

  let kbind : type q qr p pr. (string option list -> qr) -> (q, qr, p, pr) t -> q =
   fun f t -> kbind' (fun vs -> f (List.rev vs)) t

  let rec extract_variables : type q qr p pr. (q, qr, p, pr) t -> string list = function
    | Sql -> []
    | Ret (t, _) -> extract_variables t
    | Variable (t, v) -> v.Var.name :: extract_variables t
    | Const (t, _s) -> extract_variables t

  let rec to_query' : type q qr p pr. (q, qr, p, pr) t -> string = function
    | Sql -> ""
    | Ret (t, _) -> to_query' t
    | Variable (t, _) -> to_query' t
    | Const (t, s) ->
        let str = to_query' t in
        if str <> "" then str ^ " " ^ s else s

  let read_variable_name str idx len =
    let rec rvn' idx =
      if idx < len then
        match str.[idx] with
        | ('_' | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9') as ch -> ch :: rvn' (idx + 1)
        | _ -> []
      else []
    in
    match rvn' idx with
    | [] -> Error `Empty_variable_name
    | name -> Ok (CCString.of_list name)

  let rec replace_variables vars query buf idx len =
    if idx < len then (
      match query.[idx] with
      | ('"' | '\'') as ch ->
          Buffer.add_char buf ch;
          consume_until ch vars query buf (idx + 1) len
      | '\\' ->
          Buffer.add_char buf query.[idx + 1];
          replace_variables vars query buf (idx + 2) len
      | '$' when idx + 1 < len && query.[idx + 1] = '$' ->
          (* Variables start with $ but $$ unchanged, since it is used in
             postgresql for dollar-quoted string delims *)
          Buffer.add_string buf "$$";
          replace_variables vars query buf (idx + 2) len
      | '$' -> replace_variable_name vars query buf (idx + 1) len
      | ch ->
          Buffer.add_char buf ch;
          replace_variables vars query buf (idx + 1) len)
    else Ok (Buffer.contents buf)

  and consume_until chr vars query buf idx len =
    if idx < len then (
      match query.[idx] with
      | '\\' ->
          Buffer.add_char buf '\\';
          Buffer.add_char buf query.[idx + 1];
          consume_until chr vars query buf (idx + 2) len
      | ch when ch = chr ->
          Buffer.add_char buf ch;
          replace_variables vars query buf (idx + 1) len
      | ch ->
          Buffer.add_char buf ch;
          consume_until chr vars query buf (idx + 1) len)
    else Error (`Unclosed_quote (Buffer.contents buf))

  and replace_variable_name vars query buf idx len =
    let open CCResult.Infix in
    read_variable_name query idx len
    >>= fun name ->
    match CCArray.find_idx (CCString.equal name) vars with
    | Some (var_idx, _) ->
        Buffer.add_string buf ("$" ^ CCInt.to_string (var_idx + 1));
        replace_variables vars query buf (idx + CCString.length name) len
    | None -> Error (`Unknown_variable name)

  let to_query t =
    let query =
      to_query' t
      |> CCString.split_on_char '\n'
      |> CCList.filter (fun line -> not (CCString.prefix ~pre:"--" (CCString.trim line)))
      |> CCString.concat "\n"
    in
    let variables = CCArray.of_list (CCList.rev (extract_variables t)) in
    replace_variables
      variables
      query
      (Buffer.create (CCString.length query))
      0
      (CCString.length query)

  let rec to_data_type_list' : type q qr p pr. (q, qr, p, pr) t -> int32 list = function
    | Sql -> []
    | Ret (t, _) -> to_data_type_list' t
    | Variable (t, v) -> Int32.of_int v.Var.oid_num :: to_data_type_list' t
    | Const (t, _s) -> to_data_type_list' t

  let to_data_type_list t = List.rev (to_data_type_list' t)

  let rec to_format_codes' : type q qr p pr. (q, qr, p, pr) t -> bool list = function
    | Sql -> []
    | Ret (t, _) -> to_format_codes' t
    | Variable (t, v) -> v.Var.binary :: to_format_codes' t
    | Const (t, _) -> to_format_codes' t

  let to_format_codes t = List.rev (to_format_codes' t)

  let rec to_result_format_codes' : type q qr p pr. (q, qr, p, pr) t -> bool list = function
    | Sql -> []
    | Ret (t, r) -> r.Ret.binary :: to_result_format_codes' t
    | Variable (t, _) -> to_result_format_codes' t
    | Const (t, _) -> to_result_format_codes' t

  let to_result_format_codes t = List.rev (to_result_format_codes' t)
end

module Row_func = struct
  module F = struct
    type ('f, 'r) t =
      | Sql : ('r, 'r) t
      | Ret : (('f, 'a -> 'r) t * 'a Typed_sql.Ret.t) -> ('f, 'r) t

    let rec t_of_sql : type q qr f r. (q, qr, f, r) Typed_sql.t -> (f, r) t = function
      | Typed_sql.Sql -> Sql
      | Typed_sql.Ret (t, r) -> Ret (t_of_sql t, r)
      | Typed_sql.Const (t, _) -> t_of_sql t
      | Typed_sql.Variable (t, _) -> t_of_sql t

    let rec kbind' : type f r. f -> string option list -> (f, r) t -> r option =
     fun f vs t ->
      match t with
      | Sql when vs = [] -> Some f
      | Sql -> None
      | Ret (t', r) ->
          let open CCOption.Infix in
          r.Typed_sql.Ret.f vs >>= fun (v, vs') -> kbind' f vs' t' >>= fun f' -> Some (f' v)

    let kbind f data t = kbind' f (List.rev data) t
  end

  type ('f, 'fr, 'acc, 'r) t = {
    func : ('f, 'fr) F.t;
    f : 'acc -> 'f;
    post_f : 'acc -> 'fr -> 'acc;
    init : 'acc;
    fin : 'acc -> 'r;
  }

  let make sql ~init ~f ~post_f ~fin =
    let func = F.t_of_sql sql in
    { func; f; init; post_f; fin }

  let ignore sql = make sql ~init:() ~f:(fun () -> ()) ~post_f:(fun () () -> ()) ~fin:(fun () -> ())
  let fold sql ~init ~f = make sql ~init ~f ~post_f:(fun _ acc -> acc) ~fin:(fun v -> v)
  let map sql ~f = make sql ~init:[] ~f:(fun _ -> f) ~post_f:(fun acc fr -> fr :: acc) ~fin:List.rev
end

module Cursor = struct
  type conn = t

  type ('p, 'pr, 'acc, 'qr) t = {
    conn : conn;
    row_func : ('p, 'pr, 'acc, 'qr) Row_func.t;
    portal : string;
  }

  let make conn row_func portal = { conn; row_func; portal }

  let rec consume_exec conn row_func st =
    let open Abbs_future_combinators.Infix_result_monad in
    Io.wait_for_frames conn >>= fun frames -> consume_exec_frames conn row_func st frames

  and consume_exec_frames conn row_func st = function
    | [] -> consume_exec conn row_func st
    | Pgsql_codec.Frame.Backend.CommandComplete _ :: fs -> consume_exec_end conn row_func st fs
    | Pgsql_codec.Frame.Backend.DataRow _ :: _ as fs ->
        let open Abb.Future.Infix_monad in
        Io.reset conn >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame fs))
    | Pgsql_codec.Frame.Backend.ErrorResponse { msgs } :: _ as fs ->
        let open Abb.Future.Infix_monad in
        Io.error_response conn fs >>= fun _ -> Abb.Future.return (Error (Io.handle_err_frame msgs))
    | Pgsql_codec.Frame.Backend.NoticeResponse { msgs } :: fs ->
        conn.notice_response msgs;
        consume_exec_frames conn row_func st fs
    | fs ->
        let open Abb.Future.Infix_monad in
        Io.reset conn >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame fs))

  and consume_exec_end conn row_func st = function
    | [] ->
        let open Abbs_future_combinators.Infix_result_monad in
        Io.wait_for_frames conn >>= fun frames -> consume_exec_end conn row_func st frames
    | [ Pgsql_codec.Frame.Backend.ReadyForQuery _ ] ->
        Abb.Future.return (Ok (row_func.Row_func.fin st))
    | Pgsql_codec.Frame.Backend.ErrorResponse { msgs } :: _ as fs ->
        let open Abb.Future.Infix_monad in
        Io.error_response conn fs >>= fun _ -> Abb.Future.return (Error (Io.handle_err_frame msgs))
    | fs ->
        let open Abb.Future.Infix_monad in
        Io.reset conn >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame fs))

  (* Consume the response to an already-sent Execute (+ its preceding frames).
     The frames for the portal must already be flushed; this only reads. *)
  let consume_execute t =
    let open Abbs_future_combinators.Infix_result_monad in
    Io.consume_matching t.conn (consume_expected_frames t.conn)
    >>= fun fs ->
    let st = t.row_func.Row_func.init in
    (consume_exec_frames t.conn t.row_func st fs
      : (unit, err) result Abb.Future.t
      :> (unit, [> err ]) result Abb.Future.t)

  let execute t =
    let open Abbs_future_combinators.Infix_result_monad in
    Io.send_frames
      t.conn
      Pgsql_codec.Frame.Frontend.[ Execute { portal = t.portal; max_rows = Int32.zero }; Sync ]
    >>= fun () -> consume_execute t

  let rec consume_fetch conn row_func st =
    let open Abbs_future_combinators.Infix_result_monad in
    Io.wait_for_frames conn >>= fun frames -> consume_fetch_frames conn row_func st frames

  and consume_fetch_frames conn row_func st = function
    | [] -> consume_fetch conn row_func st
    | Pgsql_codec.Frame.Backend.CommandComplete _ :: fs -> consume_fetch_end conn row_func st fs
    | Pgsql_codec.Frame.Backend.DataRow { data } :: fs ->
        consume_fetch_process_frame conn row_func st fs data
    | Pgsql_codec.Frame.Backend.ErrorResponse { msgs } :: _ as fs ->
        let open Abb.Future.Infix_monad in
        Io.error_response conn fs >>= fun _ -> Abb.Future.return (Error (Io.handle_err_frame msgs))
    | Pgsql_codec.Frame.Backend.NoticeResponse { msgs } :: fs ->
        conn.notice_response msgs;
        consume_fetch_frames conn row_func st fs
    | fs ->
        let open Abb.Future.Infix_monad in
        Io.reset conn >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame fs))

  and consume_fetch_process_frame conn row_func st fs data =
    let open Abb.Future.Infix_monad in
    (* A row decode failure (None) OR a raising row function (e.g. one that uses
       get_or_failwith / get_exn) must NOT abandon the rest of the response: the
       remaining DataRows + CommandComplete + ReadyForQuery would be left on the
       wire, desyncing the next operation and leaving the connection idle in an
       open transaction.  So drain to ReadyForQuery first, then surface the
       failure.  Note: run_db's serializer propagates a raised exception but does
       NOT clean up the connection, so cleaning up here is the only safe place. *)
    match
      try `Ok (Row_func.F.kbind (row_func.Row_func.f st) data row_func.Row_func.func)
      with exn -> `Exn (exn, Printexc.get_raw_backtrace ())
    with
    | `Ok (Some fr) -> consume_fetch_frames conn row_func (row_func.Row_func.post_f st fr) fs
    | `Ok None ->
        drain_fetch_response conn fs >>= fun () -> Abb.Future.return (Error (`Bad_result data))
    | `Exn (exn, bt) ->
        drain_fetch_response conn fs >>= fun () -> Printexc.raise_with_backtrace exn bt

  (* Consume and discard frames up to (and including) the next ReadyForQuery,
     WITHOUT sending a Sync (the fetch's own Sync is already outstanding, so its
     ReadyForQuery is already on its way).  Best effort: a read error just ends
     the drain. *)
  and drain_fetch_response conn fs =
    let open Abb.Future.Infix_monad in
    Io.consume_until ~fs conn (function
      | Pgsql_codec.Frame.Backend.ReadyForQuery _ -> true
      | _ -> false)
    >>= fun _ -> Abb.Future.return ()

  and consume_fetch_end conn row_func st = function
    | [] ->
        let open Abbs_future_combinators.Infix_result_monad in
        Io.wait_for_frames conn >>= fun frames -> consume_fetch_end conn row_func st frames
    | [ Pgsql_codec.Frame.Backend.ReadyForQuery _ ] ->
        Abb.Future.return (Ok (row_func.Row_func.fin st))
    | Pgsql_codec.Frame.Backend.ErrorResponse { msgs } :: _ as fs ->
        let open Abb.Future.Infix_monad in
        Io.error_response conn fs >>= fun _ -> Abb.Future.return (Error (Io.handle_err_frame msgs))
    | fs ->
        let open Abb.Future.Infix_monad in
        Io.reset conn >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame fs))

  (* Consume the response to an already-sent Execute (+ its preceding frames),
     processing returned rows. *)
  let consume_fetch t =
    let open Abbs_future_combinators.Infix_result_monad in
    Io.consume_matching t.conn (consume_expected_frames t.conn)
    >>= fun fs ->
    let st = t.row_func.Row_func.init in
    (consume_fetch_frames t.conn t.row_func st fs
      : ('a list, err) result Abb.Future.t
      :> ('a list, [> err ]) result Abb.Future.t)

  let fetch ?(n = 0) t =
    let open Abbs_future_combinators.Infix_result_monad in
    Io.send_frames
      t.conn
      Pgsql_codec.Frame.Frontend.[ Execute { portal = t.portal; max_rows = Int32.of_int n }; Sync ]
    >>= fun () -> consume_fetch t

  let destroy t =
    let open Abbs_future_combinators.Infix_result_monad in
    Io.send_frames t.conn Pgsql_codec.Frame.Frontend.[ Close { typ = 'P'; name = t.portal }; Sync ]
    >>= fun () ->
    add_expected_frames
      t.conn
      Pgsql_codec.Frame.Backend.
        [
          equal CloseComplete;
          (function
          | ReadyForQuery _ -> true
          | _ -> false);
        ];
    Io.consume_matching t.conn (consume_expected_frames t.conn)
    >>= fun _ -> Abb.Future.return (Ok ())

  let with_cursor t ~f =
    Abbs_future_combinators.with_finally
      (fun () -> f t)
      ~finally:(fun () -> Abbs_future_combinators.ignore (destroy t))
end

module Prepared_stmt = struct
  type conn = t

  type ('q, 'qr, 'p, 'pr) t = {
    conn : conn;
    sql : ('q, 'qr, 'p, 'pr) Typed_sql.t;
    id : string;
  }

  (* Create *)
  let create conn sql =
    let open Abbs_future_combinators.Infix_result_monad in
    let stmt = gen_unique_id conn "s" in
    Abb.Future.return (Typed_sql.to_query sql)
    >>= fun query ->
    let frame =
      Pgsql_codec.Frame.Frontend.(
        Parse { stmt; query; data_types = Typed_sql.to_data_type_list sql })
    in
    Io.send_frame conn frame
    >>= fun () ->
    add_expected_frame conn Pgsql_codec.Frame.Backend.(equal ParseComplete);
    Abb.Future.return (Ok { conn; sql; id = stmt })

  let bind t rf =
    Typed_sql.kbind
      (fun vs ->
        let open Abbs_future_combinators.Infix_result_monad in
        let portal = gen_unique_id t.conn "p" in
        let bind_frame =
          Pgsql_codec.Frame.Frontend.(
            Bind
              {
                portal;
                stmt = t.id;
                format_codes = Typed_sql.to_format_codes t.sql;
                values = vs;
                result_format_codes = Typed_sql.to_result_format_codes t.sql;
              })
        in
        Io.send_frame t.conn bind_frame
        >>= fun () ->
        add_expected_frame t.conn Pgsql_codec.Frame.Backend.(equal BindComplete);
        Abb.Future.return (Ok (Cursor.make t.conn rf portal)))
      t.sql

  let destroy t =
    let open Abbs_future_combinators.Infix_result_monad in
    Io.send_frames t.conn Pgsql_codec.Frame.Frontend.[ Close { typ = 'S'; name = t.id }; Sync ]
    >>= fun () ->
    add_expected_frames
      t.conn
      Pgsql_codec.Frame.Backend.
        [
          equal CloseComplete;
          (function
          | ReadyForQuery _ -> true
          | _ -> false);
        ];
    Io.consume_matching t.conn (consume_expected_frames t.conn)
    >>= fun _ -> Abb.Future.return (Ok ())

  (* A server-side prepared statement that no longer exists (26000, e.g. dropped
     by a rolled-back transaction) or whose cached plan is stale after DDL
     (0A000) means our cached name is no longer usable. *)
  let is_stale_stmt = function
    | `Pgsql_err { code; _ } -> CCString.equal code "26000" || CCString.equal code "0A000"
    | _ -> false

  (* On a cache hit only Bind/Execute/Sync are sent, so a single BindComplete is
     expected; on a miss the prepended Parse also yields a ParseComplete. *)
  let add_expected_run_frames conn ~cached =
    match cached with
    | Some _ -> add_expected_frame conn Pgsql_codec.Frame.Backend.(equal BindComplete)
    | None ->
        add_expected_frames
          conn
          Pgsql_codec.Frame.Backend.[ equal ParseComplete; equal BindComplete ]

  (* After a successful run remember a freshly parsed statement so later queries
     can reuse it; a cache hit is already stored. *)
  let cache_run_stmt conn ~cached query stmt =
    match cached with
    | None -> stmt_cache_add conn query stmt
    | Some _ -> ()

  (* Run a one-shot query through the connection's prepared-statement cache.  On
     a cache hit only Bind/Execute/Sync are sent (reusing the server-side
     statement and its plan); on a miss a Parse is prepended and the name is
     cached after a successful execution.  The statement is intentionally NOT
     closed so it can be reused, and the unnamed portal (auto-closed at Sync /
     end of transaction) avoids a portal Close.  On a stale-statement error the
     entry is evicted and, when not inside a transaction, the query is retried
     once with a fresh Parse. *)
  let rec run_cached conn sql vs ~row_func ~consume ~force_fresh =
    let open Abbs_future_combinators.Infix_result_monad in
    Abb.Future.return (Typed_sql.to_query sql)
    >>= fun query ->
    let cached = if force_fresh then None else stmt_cache_find conn query in
    let stmt =
      match cached with
      | Some s -> s
      | None -> gen_unique_id conn "s"
    in
    let portal = "" in
    let bind_frame =
      Pgsql_codec.Frame.Frontend.(
        Bind
          {
            portal;
            stmt;
            format_codes = Typed_sql.to_format_codes sql;
            values = vs;
            result_format_codes = Typed_sql.to_result_format_codes sql;
          })
    in
    let exec_frame = Pgsql_codec.Frame.Frontend.(Execute { portal; max_rows = Int32.zero }) in
    let frames =
      match cached with
      | Some _ -> Pgsql_codec.Frame.Frontend.[ bind_frame; exec_frame; Sync ]
      | None ->
          Pgsql_codec.Frame.Frontend.(
            Parse { stmt; query; data_types = Typed_sql.to_data_type_list sql }
            :: [ bind_frame; exec_frame; Sync ])
    in
    Io.send_frames conn frames
    >>= fun () ->
    add_expected_run_frames conn ~cached;
    let cursor = Cursor.make conn row_func portal in
    let open Abb.Future.Infix_monad in
    consume cursor
    >>= function
    | Ok _ as ok ->
        cache_run_stmt conn ~cached query stmt;
        Abb.Future.return ok
    | Error e when Option.is_some cached && is_stale_stmt e ->
        stmt_cache_remove conn query;
        if conn.in_tx then Abb.Future.return (Error e)
        else run_cached conn sql vs ~row_func ~consume ~force_fresh:true
    | Error _ as err -> Abb.Future.return err

  let execute conn sql =
    Typed_sql.kbind
      (fun vs ->
        if Atomic.compare_and_set conn.busy false true then
          Abbs_future_combinators.with_finally
            (fun () ->
              run_cached
                conn
                sql
                vs
                ~row_func:(Row_func.ignore sql)
                ~consume:Cursor.consume_execute
                ~force_fresh:false)
            ~finally:(fun () ->
              Atomic.set conn.busy false;
              Abb.Future.return ())
        else raise (Failure ("SQL connection busy: " ^ CCResult.get_exn @@ Typed_sql.to_query sql)))
      sql

  let bind_execute t =
    Typed_sql.kbind
      (fun vs ->
        let open Abbs_future_combinators.Infix_result_monad in
        let portal = gen_unique_id t.conn "p" in
        let bind_frame =
          Pgsql_codec.Frame.Frontend.(
            Bind
              {
                portal;
                stmt = t.id;
                format_codes = Typed_sql.to_format_codes t.sql;
                values = vs;
                result_format_codes = Typed_sql.to_result_format_codes t.sql;
              })
        in
        Io.send_frame t.conn bind_frame
        >>= fun () ->
        add_expected_frame t.conn Pgsql_codec.Frame.Backend.(equal BindComplete);
        let cursor = Cursor.make t.conn (Row_func.ignore t.sql) portal in
        Cursor.execute cursor)
      t.sql

  let fetch conn sql ~f =
    Typed_sql.kbind
      (fun vs ->
        if Atomic.compare_and_set conn.busy false true then
          Abbs_future_combinators.with_finally
            (fun () ->
              run_cached
                conn
                sql
                vs
                ~row_func:(Row_func.map sql ~f)
                ~consume:Cursor.consume_fetch
                ~force_fresh:false)
            ~finally:(fun () ->
              Atomic.set conn.busy false;
              Abb.Future.return ())
        else raise (Failure ("SQL connection busy: " ^ CCResult.get_exn @@ Typed_sql.to_query sql)))
      sql

  let kbind :
      conn ->
      ('q, ('ret, [> err ]) result Abb.Future.t, 'p, 'pr) Typed_sql.t ->
      ('p, 'pr, 'acc, 'r) Row_func.t ->
      (('p, 'pr, 'acc, 'r) Cursor.t -> ('ret, [> err ]) result Abb.Future.t) ->
      'q =
   fun conn sql rf f ->
    Typed_sql.kbind
      (fun vs ->
        let open Abbs_future_combinators.Infix_result_monad in
        create conn sql
        >>= fun stmt ->
        Abbs_future_combinators.with_finally
          (fun () ->
            let portal = gen_unique_id conn "p" in
            let bind_frame =
              Pgsql_codec.Frame.Frontend.(
                Bind
                  {
                    portal;
                    stmt = stmt.id;
                    format_codes = Typed_sql.to_format_codes sql;
                    values = vs;
                    result_format_codes = Typed_sql.to_result_format_codes sql;
                  })
            in
            Io.send_frame conn bind_frame
            >>= fun () ->
            add_expected_frame conn Pgsql_codec.Frame.Backend.(equal BindComplete);
            let cursor = Cursor.make conn rf portal in
            f cursor)
          ~finally:(fun () -> Abbs_future_combinators.ignore (destroy stmt)))
      sql
end

module Auth_scram = struct
  type auth_mechanism =
    | SCRAM_SHA256
    | SCRAM_SHA256_PLUS (* Placeholder for future channel-binding support; never constructed yet. *)
  [@@warning "-37"]

  (* SCRAM protocol intermediate values. Some fields are populated for completeness
     but not yet read because the channel-binding flow is unimplemented (see
     SCRAM_SHA256_PLUS above). *)
  type client_first = {
    channel_binding : string option;
    user : string;
    passwd : string;
    nonce : string;
    message : string;
  }
  [@@warning "-69"]

  type server_first = {
    nonce : string;
    salt : string;
    iter : int;
    message : string;
  }
  [@@warning "-69"]

  type client_final = {
    server_key : string;
    auth_message : string;
    message : string;
  }
  [@@warning "-69"]

  (* Notation and function naming come from RFC 5802, to avoid
     messing up the implementation:
        https://www.rfc-editor.org/rfc/rfc5802#section-2.2 *)
  let hmac key msg =
    let hash = Cryptokit.MAC.hmac_sha256 key in
    Cryptokit.hash_string hash msg

  let h hf msg = Cryptokit.hash_string hf msg

  let hi str salt iter =
    let ui = hmac str (salt ^ "\x00\x00\x00\x01") in
    let u = Bytes.of_string ui in
    let rec loop it ui =
      match it with
      | 0 -> String.of_bytes u
      | _k ->
          let ui = hmac str ui in
          Cryptokit.xor_string ui 0 u 0 (Bytes.length u);
          loop (it - 1) ui
    in
    loop (iter - 1) ui

  (* The next functions are an implementation of
        https://www.rfc-editor.org/rfc/rfc5802#page-7 *)
  let salt_passwd passwd server_first = hi passwd server_first.salt server_first.iter

  let auth_message client_first_message_bare server_first_message client_final_message_without_proof
      =
    (* client_first_message_bare = n=$USER,r=$CLIENT_NONCE
       server_first_message = r=$NONCE,s=$SALT,i=$ITER
       client_final_message_without_proof = c=$CHANNEL_BINDING,r=$NONCE *)
    Printf.sprintf
      "%s,%s,%s"
      client_first_message_bare
      server_first_message
      client_final_message_without_proof

  let client_key salted_passwd = hmac salted_passwd "Client Key"
  let server_key salted_passwd = hmac salted_passwd "Server Key"

  let server_signature server_key auth_message =
    hmac server_key auth_message |> Base64.encode_string

  let stored_key client_key =
    let hash = Cryptokit.Hash.sha256 () in
    h hash client_key

  let client_proof client_key client_signature =
    let result = Bytes.of_string client_signature in
    Cryptokit.xor_string client_key 0 result 0 (Bytes.length result);
    result |> String.of_bytes |> Base64.encode_string

  (* SCRAM Steps

     Check RFCs 5802 or 7677 to get a better idea on each 
     exchange format.

     https://www.rfc-editor.org/rfc/rfc5802#section-5
     https://www.rfc-editor.org/rfc/rfc7677.html#section-3 *)
  let client_first auth_mechanism user passwd =
    let nonce_len = 16 in
    let random_data = CCString.init nonce_len (fun _ -> Char.chr @@ Random.int 256) in
    let nonce = Base64.encode_string random_data in
    let channel_binding =
      match auth_mechanism with
      | SCRAM_SHA256 -> None
      | SCRAM_SHA256_PLUS -> Some "p=tls-server-end-point"
    in
    let prefix = CCOption.value channel_binding ~default:"n" in
    let message = Printf.sprintf "%s,,n=%s,r=%s" prefix user nonce in
    let client_request = { channel_binding; nonce; user; passwd; message } in
    (client_request, message)

  let parse_server_reply message =
    (* The first server response looks like this:
        |----------nonce-----------|
      r=<client_nonce><server_nonce>,s=<salt>,i=<iter> *)
    let fields = CCString.split ~by:"," message in
    let prefixes = [ "r="; "s="; "i=" ] in
    let remove_prefix prefix item =
      if CCString.prefix ~pre:prefix item then Some (CCString.drop (String.length prefix) item)
      else None
    in
    let extract prefixes fields =
      match List.map2 remove_prefix prefixes fields with
      | [ Some n; Some s; Some i ] ->
          let salt = Base64.decode_exn s in
          let iter = int_of_string i in
          Some (n, salt, iter)
      | _ -> None
    in
    match extract prefixes fields with
    | Some (nonce, salt, iter) -> Some { nonce; salt; iter; message }
    | _ -> None

  let client_final client_first server_first =
    let salted_password = salt_passwd client_first.passwd server_first in
    let client_first_message_bare =
      Printf.sprintf "n=%s,r=%s" client_first.user client_first.nonce
    in
    let client_final_without_proof = Printf.sprintf "c=biws,r=%s" server_first.nonce in
    let auth_message =
      auth_message client_first_message_bare server_first.message client_final_without_proof
    in
    let client_key = client_key salted_password in
    let server_key = server_key salted_password in
    let stored_key = stored_key client_key in
    let client_signature = hmac stored_key auth_message in
    let proof = client_proof client_key client_signature in
    let message = Printf.sprintf "%s,p=%s" client_final_without_proof proof in
    let record = { server_key; auth_message; message } in
    (record, message)

  let verify_server_final client_final server_final =
    let is_verifier = CCString.chop_prefix ~pre:"v=" server_final in
    let is_error = CCString.chop_prefix ~pre:"e=" server_final in
    match (is_verifier, is_error) with
    | Some signature_from_server, _ ->
        let signature_from_client =
          server_signature client_final.server_key client_final.auth_message
        in
        (* If both match then it's proof that the server has access to the
           client's key *)
        if signature_from_client = signature_from_server then Ok ()
        else Error "Invalid server signature"
    | _, Some error_reason -> Error error_reason
    | _ -> Error "Unsuported final server message format for AuthenticationSASLFinal"
end

type create_err =
  [ `Unexpected of (exn[@printer fun fmt v -> fprintf fmt "%s" (Printexc.to_string v)])
  | `Connection_failed
  | `Connect_missing_password_err
  | `Tls_negotiate_err of Abb_tls.err
  | `Tls_required_but_denied_err
  | `Tls_unexpected_response of int * string
  | `Unsupported_auth_gss_err
  | `Unsupported_auth_sasl_err
  | `Unsupported_auth_scm_credential_err
  | `Unsupported_auth_sspi_err
  | frame_err
  ]
[@@deriving show]

(* Disable Nagle's algorithm.  The extended-query protocol sends several small
   frames (Parse/Bind/Execute/Sync) per query; with Nagle on, these small writes
   interact badly with delayed ACKs and stall ~40ms each. *)
let set_tcp_nodelay ~host tcp =
  match Abb.Socket.Tcp.nodelay tcp true with
  | Ok () -> ()
  | Error _ -> Logs.warn (fun m -> m "Failed to set TCP_NODELAY on connection to %s" host)

let rec create_sm
    ?tls_config
    ?passwd
    ~notice_response
    ~buf_size_threshold
    ~host
    ~port
    ~user
    database =
  let open Abbs_future_combinators.Infix_result_monad in
  Logs.info (fun m -> m "Connecting to %s" host);
  Abbs_happy_eyeballs.connect host [ port ]
  >>= fun (_, tcp) ->
  set_tcp_nodelay ~host tcp;
  match tls_config with
  | None ->
      let r, w = Abbs_io_buffered.Of.of_tcp_socket ~size:buf_size tcp in
      Logs.info (fun m -> m "Initiating clear text protocol");
      create_sm_perform_login r w ?passwd ~notice_response ~buf_size_threshold ~user database
  | Some (`Require tls_config) ->
      Logs.info (fun m -> m "Requiring encrypted protocol");
      create_sm_ssl_conn
        ?passwd
        ~buf_size_threshold
        ~required:true
        ~notice_response
        ~host
        ~port
        ~user
        tls_config
        tcp
        database
  | Some (`Prefer tls_config) ->
      Logs.info (fun m -> m "Preferring encrypted protocol");
      create_sm_ssl_conn
        ?passwd
        ~buf_size_threshold
        ~required:false
        ~notice_response
        ~host
        ~port
        ~user
        tls_config
        tcp
        database

and create_sm_ssl_conn
    ?passwd
    ~buf_size_threshold
    ~required
    ~notice_response
    ~host
    ~port:_
    ~user
    tls_config
    tcp
    database =
  let open Abbs_future_combinators.Infix_result_monad in
  let buf = Buffer.create 5 in
  let bytes = Io.encode_frame buf Pgsql_codec.Frame.Frontend.SSLRequest in
  let r, w = Abbs_io_buffered.Of.of_tcp_socket ~size:buf_size tcp in
  Abbs_io_buffered.write w ~bufs:[ Io.write_buf bytes ]
  >>= fun _ ->
  Abbs_io_buffered.flushed w
  >>= fun () ->
  let bytes = Bytes.create 5 in
  Abbs_io_buffered.read r ~buf:bytes ~pos:0 ~len:(Bytes.length bytes)
  >>= function
  | n when n = 1 && Bytes.get bytes 0 = 'S' -> (
      Logs.info (fun m -> m "Secure connection state machine initiated");
      match Abbs_tls.client_tcp ~size:buf_size tcp tls_config host with
      | Ok (r, w) ->
          create_sm_perform_login r w ?passwd ~notice_response ~buf_size_threshold ~user database
      | Error (#Abb_tls.err as err) -> Abb.Future.return (Error (`Tls_negotiate_err err)))
  | n when n = 1 && Bytes.get bytes 0 = 'N' && not required ->
      Logs.info (fun m -> m "Clear text connection state machine initiated");
      create_sm_perform_login r w ?passwd ~notice_response ~buf_size_threshold ~user database
  | n when n = 1 && Bytes.get bytes 0 = 'N' && required ->
      Logs.info (fun m -> m "Secure connection denied");
      Abb.Future.return (Error `Tls_required_but_denied_err)
  | n ->
      Logs.info (fun m -> m "Create connection unexpected response");
      Abb.Future.return (Error (`Tls_unexpected_response (n, Bytes.sub_string bytes 0 n)))

and create_sm_perform_login r w ?passwd ~notice_response ~buf_size_threshold ~user database =
  let open Abbs_future_combinators.Infix_result_monad in
  let decoder = Pgsql_codec.Decode.create () in
  let buf = Bytes.create buf_size in
  let scratch = Buffer.create buf_size in
  let t =
    {
      connected = true;
      decoder;
      buf;
      scratch;
      r;
      w;
      backend_key_data = Backend_key_data.{ pid = Int32.zero; secret_key = Int32.zero };
      unique_id = 0;
      notice_response;
      notifications = Queue.create ();
      listening = false;
      expected_frames = [];
      in_tx = false;
      busy = Atomic.make false;
      buf_size_threshold;
      id = Ouuid.v4 ();
      stmt_cache = Hashtbl.create 64;
    }
  in
  let msgs = [ ("user", user); ("database", database) ] in
  let startup = Pgsql_codec.Frame.Frontend.(StartupMessage { msgs }) in
  Logs.debug (fun m -> m "Sent startup frame");
  Io.send_frame t startup >>= fun () -> create_sm_login ?passwd ~user t

and create_sm_login ?passwd ~user t =
  let open Abbs_future_combinators.Infix_result_monad in
  Io.wait_for_frames t
  >>= fun frames ->
  Logs.debug (fun m -> m "Received frames");
  create_sm_process_login_frames ?passwd ~user t frames

(* TODO: Maybe it's worth aglutinating step_02 and step_03
   under the same recursive function, left it for a future
   refactor *)
and create_sm_scram_sha256_step_03 ?passwd ~user client_final t =
  let module B = Pgsql_codec.Frame.Backend in
  let open Abbs_future_combinators.Infix_result_monad in
  Io.wait_for_frames t
  >>= function
  | B.AuthenticationSASLFinal { data } :: fs -> (
      Logs.debug (fun m -> m "Received AuthenticationSASLFinal");
      match Auth_scram.verify_server_final client_final data with
      | Ok _ ->
          (* Should be waiting for the next frame as an AuthenticationOk *)
          create_sm_process_login_frames ?passwd ~user t fs
      | _ -> Abb.Future.return (Error `Unsupported_auth_sasl_err))
  | fs -> Abb.Future.return (Error (`Unmatching_frame fs))

and create_sm_scram_sha256_step_02 ?passwd ~user client_request t =
  let module B = Pgsql_codec.Frame.Backend in
  let open Abbs_future_combinators.Infix_result_monad in
  Io.wait_for_frames t
  >>= function
  | B.AuthenticationSASLContinue { data } :: _fs -> (
      Logs.debug (fun m -> m "Received AuthenticationSASLContinue %S" data);
      match Auth_scram.parse_server_reply data with
      | Some server_response ->
          let client_final, data = Auth_scram.client_final client_request server_response in
          Logs.debug (fun m -> m "Sending SASLResponse");
          Io.send_frame t Pgsql_codec.Frame.Frontend.(SASLResponse { data })
          >>= fun () -> create_sm_scram_sha256_step_03 ?passwd ~user client_final t
      | _ ->
          Logs.debug (fun m -> m "Received unexpected SASL response");
          Abb.Future.return (Error `Unsupported_auth_sasl_err))
  | fs -> Abb.Future.return (Error (`Unmatching_frame fs))

and create_sm_process_login_frames ?passwd ~user t =
  let open Pgsql_codec.Frame.Backend in
  function
  | [] -> create_sm_login ?passwd ~user t
  | AuthenticationOk :: fs ->
      Logs.info (fun m -> m "Received AuthenticationOk");
      create_sm_process_login_frames ?passwd ~user t fs
  | AuthenticationCleartextPassword :: fs -> (
      Logs.info (fun m -> m "Received AuthenticationCleartextPassword");
      let open Abbs_future_combinators.Infix_result_monad in
      match passwd with
      | Some password ->
          Io.send_frame t Pgsql_codec.Frame.Frontend.(PasswordMessage { password })
          >>= fun () -> create_sm_process_login_frames ?passwd ~user t fs
      | None -> Abb.Future.return (Error `Connect_missing_password_err))
  | AuthenticationMD5Password { salt } :: fs -> (
      Logs.info (fun m -> m "Received AuthenticationMD5Password");
      let open Abbs_future_combinators.Infix_result_monad in
      match passwd with
      | Some password ->
          let passuser = Digest.to_hex (Digest.string (password ^ user)) in
          let passusersalt = Digest.to_hex (Digest.string (passuser ^ salt)) in
          let password = "md5" ^ passusersalt in
          Io.send_frame t Pgsql_codec.Frame.Frontend.(PasswordMessage { password })
          >>= fun () -> create_sm_process_login_frames ?passwd ~user t fs
      | None -> Abb.Future.return (Error `Connect_missing_password_err))
  | ParameterStatus _ :: fs -> create_sm_process_login_frames ?passwd ~user t fs
  | BackendKeyData { pid; secret_key } :: fs ->
      let t = { t with backend_key_data = Backend_key_data.{ pid; secret_key } } in
      create_sm_process_login_frames ?passwd ~user t fs
  | [ ReadyForQuery _ ] ->
      Logs.info (fun m -> m "Received ReadyForQuery");
      Abb.Future.return (Ok t)
  | AuthenticationSCMCredential :: _ ->
      Abb.Future.return (Error `Unsupported_auth_scm_credential_err)
  | AuthenticationGSS :: _ -> Abb.Future.return (Error `Unsupported_auth_gss_err)
  | AuthenticationSASL { auth_mechanisms } :: _fs
    when CCList.mem ~eq:CCString.equal "SCRAM-SHA-256" auth_mechanisms -> (
      match passwd with
      | Some password ->
          Logs.info (fun m -> m "Received AuthenticationSASL");
          let open Abbs_future_combinators.Infix_result_monad in
          let client_first, data = Auth_scram.client_first Auth_scram.SCRAM_SHA256 user password in
          let auth_mechanism = "SCRAM-SHA-256" in
          Logs.debug (fun m -> m "Sending SASLInitialResponse");
          Io.send_frame t Pgsql_codec.Frame.Frontend.(SASLInitialResponse { auth_mechanism; data })
          >>= fun () -> create_sm_scram_sha256_step_02 ?passwd ~user client_first t
      | None -> Abb.Future.return (Error `Connect_missing_password_err))
  | AuthenticationSASL { auth_mechanisms = _ } :: _ ->
      Abb.Future.return (Error `Unsupported_auth_sasl_err)
  | AuthenticationSSPI :: _ -> Abb.Future.return (Error `Unsupported_auth_sspi_err)
  | fs -> Abb.Future.return (Error (`Unmatching_frame fs))

let create
    ?tls_config
    ?passwd
    ?(port = 5432)
    ?(notice_response = fun _ -> ())
    ?(buf_size_threshold = buf_size_threshold)
    ~host
    ~user
    database =
  let open Abb.Future.Infix_monad in
  assert (buf_size_threshold > 0);
  create_sm ?tls_config ?passwd ~notice_response ~buf_size_threshold ~host ~port ~user database
  >>= function
  | Ok _ as r -> Abb.Future.return r
  | Error `Disconnected | Error #Abb_happy_eyeballs.connect_err | Error `E_io | Error `E_no_space ->
      Abb.Future.return (Error `Connection_failed)
  | ( Error `Connect_missing_password_err
    | Error (`Tls_negotiate_err _)
    | Error `Tls_required_but_denied_err
    | Error (`Tls_unexpected_response _)
    | Error (`Unmatching_frame _)
    | Error `Unsupported_auth_gss_err
    | Error `Unsupported_auth_sasl_err
    | Error `Unsupported_auth_scm_credential_err
    | Error `Unsupported_auth_sspi_err
    | Error (`Unexpected _)
    | Error (`Parse_error _) ) as err -> Abb.Future.return err

let connected t = t.connected
let id t = t.id

let ping t =
  if t.connected then (
    let open Abb.Future.Infix_monad in
    Io.reset t
    >>= function
    | Ok () -> Abb.Future.return true
    | Error _ ->
        (* Reset didn't work?  End this connection.  There are just too many
           possible reasons it could have failed. *)
        t.connected <- false;
        Abb.Future.return false)
  else Abb.Future.return false

let tx_commit t =
  let open Abbs_future_combinators.Infix_result_monad in
  Io.send_frame t Pgsql_codec.Frame.Frontend.(Query { query = "COMMIT" })
  >>= fun () ->
  t.in_tx <- false;
  add_expected_frames
    t
    Pgsql_codec.Frame.Backend.
      [ equal (CommandComplete { tag = "COMMIT" }); equal (ReadyForQuery { status = 'I' }) ];
  Io.consume_matching t (consume_expected_frames t)

let tx_rollback t =
  let open Abbs_future_combinators.Infix_result_monad in
  (* A prepared statement first created inside this transaction is dropped by the
     server on rollback, so any cached name may now be stale.  Clear the whole
     cache (re-Parse on next use is cheap) rather than tracking per-statement
     transaction membership. *)
  stmt_cache_clear t;
  Io.reset t
  >>= fun () ->
  t.in_tx <- false;
  Io.send_frame t Pgsql_codec.Frame.Frontend.(Query { query = "ROLLBACK" })
  >>= fun () ->
  Io.consume_matching
    ~skip_leading_unmatched:true
    t
    Pgsql_codec.Frame.Backend.
      [ equal (CommandComplete { tag = "ROLLBACK" }); equal (ReadyForQuery { status = 'I' }) ]

let tx t ~f =
  if t.in_tx then (
    Logs.info (fun m -> m "%s In tx already, failing" (Uuidm.to_string t.id));
    raise Nested_tx_not_supported);
  Abbs_future_combinators.on_failure
    (fun () ->
      let open Abb.Future.Infix_monad in
      t.in_tx <- true;
      Logs.info (fun m -> m "Starting tx");
      Io.send_frame t Pgsql_codec.Frame.Frontend.(Query { query = "BEGIN" })
      >>= fun _ ->
      Io.consume_matching
        ~skip_leading_unmatched:true
        t
        Pgsql_codec.Frame.Backend.
          [ equal (CommandComplete { tag = "BEGIN" }); equal (ReadyForQuery { status = 'T' }) ]
      >>= function
      | Ok [] -> (
          Logs.debug (fun m -> m "%s Tx code executing" (Uuidm.to_string t.id));
          f ()
          >>= function
          | Ok _ as r ->
              let open Abbs_future_combinators.Infix_result_monad in
              tx_commit t >>= fun _ -> Abb.Future.return r
          | Error _ as r -> tx_rollback t >>= fun _ -> Abb.Future.return r)
      | Ok fs ->
          Logs.debug (fun m -> m "%s Tx received unexpected frames, failing" (Uuidm.to_string t.id));
          tx_rollback t >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame fs))
      | Error _ as err -> tx_rollback t >>= fun _ -> Abb.Future.return err)
    ~failure:(fun () ->
      Logs.info (fun m -> m "%s Tx failed, rolling back" (Uuidm.to_string t.id));
      Abbs_future_combinators.ignore (tx_rollback t))

(* PostgreSQL identifiers cannot be passed as bind parameters, so LISTEN/UNLISTEN
   channel names are interpolated as a quoted identifier: wrap in double quotes
   and double any embedded double quote. *)
let quote_ident ident = "\"" ^ CCString.concat "\"\"" (CCString.split_on_char '"' ident) ^ "\""

(* Run [f] while holding the connection's single-op guard, releasing it on
   success, failure, or abort.  [with_finally] registers the release as the
   promise's abort handler, so a caller that bounds a blocked op with
   [Abbs_future_combinators.timeout] still releases the guard when the timeout
   aborts the op.  Mirrors the guard inlined by [Prepared_stmt.execute]/[fetch]. *)
let with_busy conn ~what f =
  if Atomic.compare_and_set conn.busy false true then
    Abbs_future_combinators.with_finally f ~finally:(fun () ->
        Atomic.set conn.busy false;
        Abb.Future.return ())
  else raise (Failure ("SQL connection busy: " ^ what))

let listen conn ~channel =
  with_busy conn ~what:"listen" (fun () ->
      let open Abbs_future_combinators.Infix_result_monad in
      (* Mark before issuing: even if the consume below fails, the server may have
         registered the LISTEN, so we must remember to clean it up on return. *)
      conn.listening <- true;
      Io.send_frame
        conn
        Pgsql_codec.Frame.Frontend.(Query { query = "LISTEN " ^ quote_ident channel })
      >>= fun () ->
      add_expected_frames
        conn
        Pgsql_codec.Frame.Backend.
          [ equal (CommandComplete { tag = "LISTEN" }); equal (ReadyForQuery { status = 'I' }) ];
      Io.consume_matching conn (consume_expected_frames conn) >>= fun _ -> Abb.Future.return (Ok ()))

let unlisten conn ~channel =
  with_busy conn ~what:"unlisten" (fun () ->
      let open Abbs_future_combinators.Infix_result_monad in
      Io.send_frame
        conn
        Pgsql_codec.Frame.Frontend.(Query { query = "UNLISTEN " ^ quote_ident channel })
      >>= fun () ->
      add_expected_frames
        conn
        Pgsql_codec.Frame.Backend.
          [ equal (CommandComplete { tag = "UNLISTEN" }); equal (ReadyForQuery { status = 'I' }) ];
      Io.consume_matching conn (consume_expected_frames conn) >>= fun _ -> Abb.Future.return (Ok ()))

let unlisten_all conn =
  with_busy conn ~what:"unlisten_all" (fun () ->
      let open Abbs_future_combinators.Infix_result_monad in
      Io.send_frame conn Pgsql_codec.Frame.Frontend.(Query { query = "UNLISTEN *" })
      >>= fun () ->
      add_expected_frames
        conn
        Pgsql_codec.Frame.Backend.
          [ equal (CommandComplete { tag = "UNLISTEN" }); equal (ReadyForQuery { status = 'I' }) ];
      Io.consume_matching conn (consume_expected_frames conn)
      >>= fun _ ->
      conn.listening <- false;
      Abb.Future.return (Ok ()))

let notify conn ~channel ?(payload = "") () =
  let open Abbs_future_combinators.Infix_result_monad in
  (* pg_notify takes both arguments as values, so they ride the normal bind path
     -- no identifier/literal escaping.  The void result column decodes as empty
     text and is discarded.  Goes through [Prepared_stmt.fetch], which holds the
     busy guard itself. *)
  let sql =
    Typed_sql.(
      sql
      // Ret.text
      /^ "SELECT pg_notify($channel, $payload)"
      /% Var.text "channel"
      /% Var.text "payload")
  in
  Prepared_stmt.fetch conn sql ~f:(fun (_ : string) -> ()) channel payload
  >>= fun (_ : unit list) -> Abb.Future.return (Ok ())

let wait_for_notification conn =
  with_busy conn ~what:"wait_for_notification" (fun () -> Io.wait_for_notification conn)

let get_notification conn = Queue.take_opt conn.notifications
let has_listens conn = conn.listening
let drain_notifications conn = Queue.clear conn.notifications

module Copy_to = struct
  type t = string option

  let null = None
  let smallint n = Some (Pgsql_codec.Binary_value.Encode.int2 n)
  let integer n = Some (Pgsql_codec.Binary_value.Encode.int4 n)
  let bigint n = Some (Pgsql_codec.Binary_value.Encode.int8 n)
  let real f = Some (Pgsql_codec.Binary_value.Encode.float4 f)
  let double f = Some (Pgsql_codec.Binary_value.Encode.float8 f)
  let money n = Some (Pgsql_codec.Binary_value.Encode.int8 n)
  let boolean b = Some (Pgsql_codec.Binary_value.Encode.bool b)
  let text s = Some s
  let varchar = text
  let char = text
  let json v = text (Yojson.Safe.to_string v)
  let jsonb v = Some ("\x01" ^ Yojson.Safe.to_string v)
  let bytea s = Some s
  let uuid u = Some (Uuidm.to_binary_string u)
end

let binary_copy_header = "PGCOPY\n\xff\r\n\000" ^ "\000\000\000\000" ^ "\000\000\000\000"
let binary_copy_trailer = "\xff\xff"

let encode_binary_tuple buf fields =
  Buffer.add_string buf (Pgsql_codec.Binary_value.Encode.int2 (List.length fields));
  List.iter
    (function
      | None -> Buffer.add_string buf "\xff\xff\xff\xff"
      | Some data ->
          Buffer.add_string
            buf
            (Pgsql_codec.Binary_value.Encode.int4 (Int32.of_int (String.length data)));
          Buffer.add_string buf data)
    fields

let copy_data_flush_size = 1024 * 1024

let rec send_copy_rows conn iter =
  let buf = Buffer.create copy_data_flush_size in
  send_copy_rows' conn buf iter

and send_copy_rows' conn buf = function
  | [] ->
      Buffer.add_string buf binary_copy_trailer;
      let data = Buffer.contents buf in
      Io.send_frame conn (Pgsql_codec.Frame.Frontend.CopyData { data })
  | row :: rest ->
      encode_binary_tuple buf row;
      if Buffer.length buf >= copy_data_flush_size then (
        let open Abbs_future_combinators.Infix_result_monad in
        let data = Buffer.contents buf in
        Buffer.clear buf;
        Io.send_frame conn (Pgsql_codec.Frame.Frontend.CopyData { data })
        >>= fun () -> send_copy_rows' conn buf rest)
      else send_copy_rows' conn buf rest

let rec consume_copy conn =
  let open Abbs_future_combinators.Infix_result_monad in
  Io.wait_for_frames conn >>= fun frames -> consume_copy_frames conn frames

and consume_copy_frames conn = function
  | [] -> consume_copy conn
  | Pgsql_codec.Frame.Backend.CommandComplete { tag } :: fs -> consume_copy_end conn tag fs
  | Pgsql_codec.Frame.Backend.ErrorResponse { msgs } :: _ as fs ->
      let open Abb.Future.Infix_monad in
      Io.error_response conn fs >>= fun _ -> Abb.Future.return (Error (Io.handle_err_frame msgs))
  | Pgsql_codec.Frame.Backend.NoticeResponse { msgs } :: fs ->
      conn.notice_response msgs;
      consume_copy_frames conn fs
  | fs ->
      let open Abb.Future.Infix_monad in
      Io.reset conn >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame fs))

and consume_copy_end conn tag = function
  | [] ->
      let open Abbs_future_combinators.Infix_result_monad in
      Io.wait_for_frames conn >>= fun frames -> consume_copy_end conn tag frames
  | Pgsql_codec.Frame.Backend.ReadyForQuery _ :: _ ->
      let n = Scanf.sscanf tag "COPY %d" Fun.id in
      Abb.Future.return (Ok n)
  | Pgsql_codec.Frame.Backend.NoticeResponse { msgs } :: fs ->
      conn.notice_response msgs;
      consume_copy_end conn tag fs
  | fs ->
      let open Abb.Future.Infix_monad in
      Io.reset conn >>= fun _ -> Abb.Future.return (Error (`Unmatching_frame fs))

let copy_to ~table ~cols t iter =
  let open Abbs_future_combinators.Infix_result_monad in
  let cols_str = String.concat ", " cols in
  let query = Printf.sprintf "COPY %s (%s) FROM STDIN WITH (FORMAT binary)" table cols_str in
  Io.send_frame t (Pgsql_codec.Frame.Frontend.Query { query })
  >>= fun () ->
  Io.consume_matching
    t
    Pgsql_codec.Frame.Backend.
      [
        (function
        | CopyInResponse _ -> true
        | _ -> false);
      ]
  >>= fun _fs ->
  Io.send_frame t (Pgsql_codec.Frame.Frontend.CopyData { data = binary_copy_header })
  >>= fun () ->
  send_copy_rows t iter
  >>= fun () ->
  Io.send_frame t Pgsql_codec.Frame.Frontend.CopyDone
  >>= fun () ->
  (consume_copy_frames t [] : (int, err) result Abb.Future.t :> (int, [> err ]) result Abb.Future.t)

let clean_string s =
  s
  |> CCString.split_on_char '\n'
  |> CCList.filter (fun line -> not (CCString.prefix ~pre:"--" (CCString.trim line)))
  |> CCString.concat "\n"

let split_statements script =
  script
  |> CCString.split ~by:";\n\n"
  |> CCList.map CCString.trim
  |> CCList.filter (fun s -> not (CCString.is_empty s))

let execute_script db script =
  Abbs_future_combinators.List_result.iter
    ~f:(fun stmt -> Prepared_stmt.execute db Typed_sql.(sql /^ stmt))
    (split_statements script)
