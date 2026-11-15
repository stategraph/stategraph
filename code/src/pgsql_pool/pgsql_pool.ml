let src = Logs.Src.create "pgsql.pool"

module Logs = (val Logs.src_log src : Logs.LOG)
module Service = Abbs_service_local

exception Pgsql_pool_closed

type err = [ `Pgsql_pool_error ] [@@deriving show]

module Metrics = struct
  type t = {
    num_conns : int;
    idle_conns : int;
    queue_time : float option;
  }
end

module Conn = struct
  type t = {
    conn : Pgsql_io.t;
    last_used : float;
    uses : int;
  }
end

module Msg = struct
  (* Per-request reply envelopes (see RFD 675 "Safe cross-task patterns").
     [get_req] carries the caller's enqueue time as payload and returns
     a connection (or [Error ()] if the pool refuses).  [destroy_req]
     is a unit request whose response is a unit ack once draining
     completes. *)
  type get_req = (float, (Conn.t, unit) result) Service.Request.t
  type destroy_req = (unit, unit) Service.Request.t

  type t =
    | Get of get_req
    | Conn_timeout_check
    | Return of Conn.t
    | Destroy of destroy_req
end

module Waiting = struct
  type t = { req : Msg.get_req }
end

(* Try to deliver [`Det v] over a reply chan.  Returns [`Sent] on
   success, [`Closed] if the caller has already closed the chan
   (typically because its own future was aborted). *)
let deliver_chan req v =
  let open Abb.Future.Infix_monad in
  Abb.Chan.send (Service.Request.reply_chan req) (`Det v)
  >>= function
  | Ok () -> Abb.Future.return `Sent
  | Error `Chan_closed -> Abb.Future.return `Closed

let deliver_unit req = deliver_chan req ()

module Server = struct
  type t = {
    metrics : Metrics.t -> unit Abb.Future.t;
    idle_check : Duration.t;
    conn_timeout_check : Duration.t;
    tls_config : [ `Require of Otls.Tls_config.t | `Prefer of Otls.Tls_config.t ] option;
    passwd : string option;
    port : int option;
    host : string;
    user : string;
    max_conns : int;
    max_uses : int;
    connect_timeout : float;
    database : string;
    num_conns : int;
    conns : Conn.t list;
    waiting : Waiting.t Queue.t;
    on_connect : Pgsql_io.t -> unit Abb.Future.t;
  }

  let ping_timeout = Duration.to_f (Duration.of_sec 5)

  let rec conn_timeout_check' timeout w =
    let open Abb.Future.Infix_monad in
    Abb.Sys.sleep @@ Duration.to_f timeout
    >>= fun () ->
    Service.notify w Msg.Conn_timeout_check
    >>= function
    | Ok () -> conn_timeout_check' timeout w
    | Error `Chan_closed -> Abb.Future.return ()

  (* Try to hand [conn] to the next still-listening waiter.  Walks the
     waiting queue, sending [`Det (Ok conn)] over each waiter's reply
     chan; if a waiter has closed its chan (caller aborted), the send
     returns [`Chan_closed] and we try the next one.  Returns
     [`Handed_off t] if a waiter accepted the conn, or [`No_waiters
     (t, conn)] if the queue is empty. *)
  let rec hand_to_next_waiter t conn =
    let open Abb.Future.Infix_monad in
    match Queue.take_opt t.waiting with
    | None -> Abb.Future.return (`No_waiters (t, conn))
    | Some { Waiting.req } -> (
        deliver_chan req (Ok conn)
        >>= function
        | `Sent -> Abb.Future.return (`Handed_off t)
        | `Closed -> hand_to_next_waiter t conn)

  let verify_conn { Conn.conn; last_used = _; uses } =
    let open Abb.Future.Infix_monad in
    (* Don't let a ping eat up the whole pool indefinitely, timeout so we can at
       least make progress, even if it's slow.  *)
    Abbs_fc.timeout ~timeout:(Abb.Sys.sleep ping_timeout) (Pgsql_io.ping conn)
    >>= function
    | `Ok true ->
        Abb.Sys.monotonic ()
        >>= fun last_used -> Abb.Future.return (Some { Conn.conn; last_used; uses })
    | `Ok false | `Timeout -> Pgsql_io.destroy conn >>= fun () -> Abb.Future.return None

  let verify_conns t =
    Abbs_fc.List.fold_left
      ~f:(fun t conn ->
        let open Abb.Future.Infix_monad in
        verify_conn conn
        >>= function
        | Some conn -> Abb.Future.return { t with conns = conn :: t.conns }
        | None -> Abb.Future.return { t with num_conns = t.num_conns - 1 })
      ~init:{ t with conns = [] }
      t.conns

  let destroy_idle_conns t =
    let open Abb.Future.Infix_monad in
    let num_idle = CCList.length t.conns in
    Abbs_fc.List.iter
      ~f:(fun { Conn.conn; last_used = _; uses = _ } -> Pgsql_io.destroy conn)
      t.conns
    >>= fun () -> Abb.Future.return { t with conns = []; num_conns = t.num_conns - num_idle }

  let reject_waiting t =
    let reqs = Queue.fold (fun acc { Waiting.req } -> req :: acc) [] t.waiting in
    Queue.clear t.waiting;
    Abbs_fc.List.iter
      ~f:(fun req ->
        let open Abb.Future.Infix_monad in
        deliver_chan req (Error ()) >>= fun _ -> Abb.Future.return ())
      reqs

  let rec loop t chan =
    let open Abb.Future.Infix_monad in
    Abb.Chan.recv chan >>= handle_msg t chan

  and drain_loop ~drained t chan =
    let open Abb.Future.Infix_monad in
    if t.num_conns = 0 then deliver_unit drained >>= fun _ -> Abb.Future.return ()
    else Abb.Chan.recv chan >>= handle_drain_msg ~drained t chan

  and handle_drain_msg ~drained t chan =
    let open Abb.Future.Infix_monad in
    function
    | Ok (Msg.Destroy req) ->
        (* Already draining; ack this new destroy when the in-flight drain
           completes.  We send via the new caller's own reply chan so
           there is no shared promise across the two requests. *)
        Abb.Future.fork
          (Abb.Chan.recv (Service.Request.reply_chan drained)
          >>= fun _ -> deliver_unit req >>= fun _ -> Abb.Future.return ())
        >>= fun _ -> drain_loop ~drained t chan
    | Ok (Msg.Get req) -> deliver_chan req (Error ()) >>= fun _ -> drain_loop ~drained t chan
    | Ok (Msg.Return conn) ->
        Pgsql_io.destroy conn.Conn.conn
        >>= fun () -> drain_loop ~drained { t with num_conns = t.num_conns - 1 } chan
    | Ok Msg.Conn_timeout_check -> drain_loop ~drained t chan
    | Error `Chan_closed -> deliver_unit drained >>= fun _ -> Abb.Future.return ()

  and handle_msg t chan = function
    | Ok (Msg.Destroy req) -> handle_destroy t chan req
    | Ok (Msg.Get req) -> handle_get t chan req
    | Ok (Msg.Return conn) when Pgsql_io.connected conn.Conn.conn -> handle_return t chan conn
    | Ok (Msg.Return conn) -> handle_disconnected_return t chan conn
    | Ok Msg.Conn_timeout_check -> handle_conn_timeout_check t chan
    | Error `Chan_closed -> handle_shutdown t

  (* Begin draining: reject queued waiters, close idle connections, then loop in
     drain mode until every in-use connection has been returned. *)
  and handle_destroy t chan req =
    let open Abb.Future.Infix_monad in
    reject_waiting t >>= fun () -> destroy_idle_conns t >>= fun t -> drain_loop ~drained:req t chan

  (* Serve a connection request: record the caller's queue time, then either park
     the caller (the pool is full and every connection is in use) or give it a
     connection. *)
  and handle_get t chan req =
    let open Abb.Future.Infix_monad in
    let queued_at = Service.Request.payload req in
    Abb.Sys.monotonic ()
    >>= fun now ->
    let queue_time = now -. queued_at in
    t.metrics
      {
        Metrics.num_conns = t.num_conns;
        idle_conns = CCList.length t.conns;
        queue_time = Some queue_time;
      }
    >>= fun () ->
    if t.conns = [] && t.num_conns = t.max_conns then park_waiter t chan req
    else give_connection ~now t chan req

  (* The pool is at capacity with no idle connection: park the caller until one is
     returned. *)
  and park_waiter t chan req =
    Queue.add { Waiting.req } t.waiting;
    loop t chan

  (* Give the caller an idle connection, or create a new one if there is room.
     [now] is the monotonic time captured for this request. *)
  and give_connection ~now t chan req =
    let open Abb.Future.Infix_monad in
    match t.conns with
    | ({ Conn.conn; last_used; uses = _ } as c) :: cs
      when Pgsql_io.connected conn && now -. last_used >= Duration.to_f t.idle_check -> (
        (* Idle long enough to be worth checking: ping it, hand it back if alive,
           otherwise drop it and handle the request again against the rest. *)
        verify_conn c
        >>= function
        | Some conn -> hand_off t chan req conn cs
        | None ->
            handle_msg { t with num_conns = t.num_conns - 1; conns = cs } chan (Ok (Msg.Get req)))
    | ({ Conn.conn; last_used = _; uses = _ } as c) :: cs when Pgsql_io.connected conn ->
        hand_off t chan req c cs
    | _ :: _ ->
        (* If one connection is disconnected, maybe all of them are, so verify all
           the connections before handing out the next one.

           TODO: Find the next valid connection and hand it over and check valid
           connections in the background *)
        verify_conns t >>= fun t -> handle_msg t chan (Ok (Msg.Get req))
    | [] -> create_connection t chan req

  (* No idle connection but room to grow: create one (bounded by the connect
     timeout) and hand it to the caller. *)
  and create_connection t chan req =
    let open Abb.Future.Infix_monad in
    Abbs_fc.timeout
      ~timeout:(Abb.Sys.sleep t.connect_timeout)
      (Pgsql_io.create
         ?tls_config:t.tls_config
         ?passwd:t.passwd
         ?port:t.port
         ~host:t.host
         ~user:t.user
         t.database)
    >>= function
    | `Ok (Ok conn) ->
        Logs.debug (fun m -> m "CREATE : %s" (Uuidm.to_string @@ Pgsql_io.id conn));
        t.on_connect conn
        >>= fun () ->
        Abb.Sys.monotonic ()
        >>= fun last_used ->
        let c = { Conn.conn; last_used; uses = 0 } in
        (* The connection exists whether or not the caller still listens: [num_conns] counts it on
           both branches, and a closed chan leaves it in the idle list for the next request.  No
           idle connection is left behind, so [cs] is empty. *)
        hand_off { t with num_conns = t.num_conns + 1 } chan req c []
    | `Ok (Error (#Pgsql_io.create_err as err)) ->
        Logs.err (fun m -> m "ERROR : %s" (Pgsql_io.show_create_err err));
        deliver_chan req (Error ()) >>= fun _ -> loop t chan
    | `Timeout -> deliver_chan req (Error ()) >>= fun _ -> loop t chan

  (* A live connection was returned.  Bump its use count and either recycle it (it
     reached [max_uses]) or clean it up and make it available again. *)
  and handle_return t chan conn =
    let open Abb.Future.Infix_monad in
    let conn = { conn with Conn.uses = conn.Conn.uses + 1 } in
    t.metrics
      { Metrics.num_conns = t.num_conns; idle_conns = CCList.length t.conns; queue_time = None }
    >>= fun () ->
    if conn.Conn.uses >= t.max_uses then recycle_connection t chan conn
    else reuse_connection t chan conn

  (* The connection reached [max_uses]: destroy it and let the next waiter (if any)
     trigger a fresh one. *)
  and recycle_connection t chan conn =
    let open Abb.Future.Infix_monad in
    Logs.debug (fun m ->
        m "RECYCLE : %s : uses=%d" (Uuidm.to_string @@ Pgsql_io.id conn.Conn.conn) conn.Conn.uses);
    Pgsql_io.destroy conn.Conn.conn
    >>= fun () -> serve_next_waiter { t with num_conns = t.num_conns - 1 } chan

  (* Make a returned connection available again.  Before reuse, remove any LISTENs
     and drop any notifications it accumulated so the next user starts clean.  Fast
     path: a connection that never issued a LISTEN skips the [UNLISTEN *] round trip
     entirely; the queue drain is in-memory and always cheap.  If the cleanup fails
     the connection's listen state is unknown, so it is dropped rather than handed
     to the next user dirty. *)
  and reuse_connection t chan conn =
    let open Abb.Future.Infix_monad in
    let cleanup : (unit, Pgsql_io.err) result Abb.Future.t =
      if Pgsql_io.has_listens conn.Conn.conn then Pgsql_io.unlisten_all conn.Conn.conn
      else Abbs_fc.return_ok ()
    in
    cleanup
    >>= function
    | Ok () -> (
        Pgsql_io.drain_notifications conn.Conn.conn;
        hand_to_next_waiter t conn
        >>= function
        | `Handed_off t -> loop t chan
        | `No_waiters (t, conn) ->
            Abb.Sys.monotonic ()
            >>= fun last_used ->
            loop { t with conns = { conn with Conn.last_used } :: t.conns } chan)
    | Error err ->
        Logs.warn (fun m ->
            m
              "RETURN_CLEANUP_FAILED : %s : dropping connection : %s"
              (Uuidm.to_string @@ Pgsql_io.id conn.Conn.conn)
              (Pgsql_io.show_err err));
        Pgsql_io.destroy conn.Conn.conn
        >>= fun () -> serve_next_waiter { t with num_conns = t.num_conns - 1 } chan

  (* A disconnected connection was returned: drop it, re-verify the rest, and serve
     the next waiter. *)
  and handle_disconnected_return t chan conn =
    let open Abb.Future.Infix_monad in
    t.metrics
      { Metrics.num_conns = t.num_conns; idle_conns = CCList.length t.conns; queue_time = None }
    >>= fun () ->
    Pgsql_io.destroy conn.Conn.conn
    >>= fun () ->
    verify_conns { t with num_conns = t.num_conns - 1 } >>= fun t -> serve_next_waiter t chan

  (* Hand the next queued waiter a connection, or keep looping if there are none. *)
  and serve_next_waiter t chan =
    match Queue.take_opt t.waiting with
    | Some { Waiting.req } -> handle_msg t chan (Ok (Msg.Get req))
    | None -> loop t chan

  (* Hand a live connection to [req], whose connection has already left [t.conns].  A closed reply
     chan means the caller aborted (its own timeout fired) while the connection was in hand: the
     connection is live, so it goes to the next waiter or back to the idle list.  It must never be
     dropped.  The handoff does not count as a use: [max_uses] is enforced on the return path only. *)
  and hand_off t chan req conn cs =
    let open Abb.Future.Infix_monad in
    deliver_chan req (Ok conn)
    >>= function
    | `Sent -> loop { t with conns = cs } chan
    | `Closed -> (
        let t = { t with conns = cs } in
        hand_to_next_waiter t conn
        >>= function
        | `Handed_off t -> loop t chan
        | `No_waiters (t, conn) ->
            Abb.Sys.monotonic ()
            >>= fun last_used ->
            loop { t with conns = { conn with Conn.last_used } :: t.conns } chan)

  (* Periodically shrink the pool: close connections idle longer than
     [conn_timeout_check], giving an intense burst's connections back to the
     database over time. *)
  and handle_conn_timeout_check t chan =
    let open Abb.Future.Infix_monad in
    let conn_timeout_check = Duration.to_f t.conn_timeout_check in
    Logs.debug (fun m ->
        m
          "CONN_TIMEOUT_CHECK : STARTED : num_conns=%d : timeout=%0.0f"
          t.num_conns
          conn_timeout_check);
    Abb.Sys.monotonic ()
    >>= fun now ->
    Abbs_fc.List.fold_left
      ~f:(fun t ({ Conn.conn; last_used; uses = _ } as c) ->
        let age = now -. last_used in
        Logs.debug (fun m -> m "CONN_TIMEOUT_CHECK : TEST : age=%0.0f" age);
        if age >= conn_timeout_check then
          Pgsql_io.destroy conn
          >>= fun _ -> Abb.Future.return { t with num_conns = t.num_conns - 1 }
        else Abb.Future.return { t with conns = c :: t.conns })
      ~init:{ t with conns = [] }
      t.conns
    >>= fun t ->
    Logs.debug (fun m -> m "CONN_TIMEOUT_CHECK : COMPLETED : num_conns=%d" t.num_conns);
    loop t chan

  (* The request channel closed: tear down by destroying every idle connection. *)
  and handle_shutdown t =
    Abbs_fc.List.iter
      ~f:(fun { Conn.conn; last_used = _; uses = _ } -> Abbs_fc.ignore (Pgsql_io.destroy conn))
      t.conns

  let run t chan =
    let open Abb.Future.Infix_monad in
    Abb.Future.fork (conn_timeout_check' t.conn_timeout_check chan) >>= fun _ -> loop t chan
end

type t = Msg.t Service.t

let create
    ?(metrics = fun _ -> Abbs_fc.unit)
    ?(idle_check = Duration.of_min 5)
    ?(conn_timeout_check = Duration.of_min 1)
    ?(max_uses = 10)
    ?tls_config
    ?passwd
    ?port
    ?on_connect
    ~connect_timeout
    ~host
    ~user
    ~max_conns
    database =
  let on_connect = CCOption.get_or ~default:(fun _ -> Abbs_fc.unit) on_connect in
  let t =
    {
      Server.metrics;
      idle_check;
      conn_timeout_check;
      tls_config;
      passwd;
      port;
      host;
      user;
      max_conns;
      max_uses;
      connect_timeout;
      database;
      num_conns = 0;
      conns = [];
      waiting = Queue.create ();
      on_connect;
    }
  in
  Service.create (Server.run t)

let destroy ?(timeout = Duration.of_sec 30) t =
  let open Abb.Future.Infix_monad in
  Abbs_fc.timeout
    ~timeout:(Abb.Sys.sleep (Duration.to_f timeout))
    (Service.call t (fun req -> Msg.Destroy req) ())
  >>= function
  | `Ok (Ok ()) -> Abb.Future.return ()
  | `Ok (Error `Chan_closed) -> Abb.Future.return ()
  | `Timeout ->
      Logs.warn (fun m -> m "DESTROY_TIMEOUT : leaked connections detected, forcing pool shutdown");
      Abb.Chan.close t;
      Abb.Future.return ()

let with_conn t ~f =
  let open Abb.Future.Infix_monad in
  Abbs_fc.protect_finally
    ~setup:(fun () ->
      Abb.Sys.monotonic ()
      >>= fun queued_at ->
      Service.call t (fun req -> Msg.Get req) queued_at
      >>= function
      | Ok r -> Abb.Future.return r
      | Error `Chan_closed -> raise Pgsql_pool_closed)
    (function
      | Ok conn ->
          Logs.debug (fun m -> m "GET : %s" (Uuidm.to_string @@ Pgsql_io.id conn.Conn.conn));
          f conn.Conn.conn
      | Error () -> Abbs_fc.return_err `Pgsql_pool_error)
    ~finally:(function
      | Ok conn -> (
          Logs.debug (fun m -> m "RETURN : %s" (Uuidm.to_string @@ Pgsql_io.id conn.Conn.conn));
          Service.notify t (Msg.Return conn)
          >>= function
          | Ok () -> Abb.Future.return ()
          | Error `Chan_closed -> Abbs_fc.ignore (Pgsql_io.destroy conn.Conn.conn))
      | Error () -> Abb.Future.return ())
