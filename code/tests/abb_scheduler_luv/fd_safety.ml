(* Descriptor-lifetime safety, specific to the luv scheduler.

   libuv watches a descriptor by NUMBER: a [uv_poll_t] left armed over a close
   can go on reporting events for whatever takes that number next, and
   [uv_poll_init] hard-fails on a number that is closed ([EBADF]) or does not
   poll ([EPERM]).  The scheduler therefore refuses to arm a poll on a closed
   handle and tears down every armed poll before releasing the descriptor.
   These tests pin that behaviour.  They are not in [abb_test] because the
   select scheduler has no libuv handles and no equivalent contract. *)
module Abb = Abb_scheduler_luv
module Oth_abb = Abb_test_oth.Make (Abb)

let tags = [ "fd_safety" ]

(* A connected, quiet pair: a read on either end parks. *)
let socket_pair () =
  let a, b = Unix.socketpair ~cloexec:true Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Unix.set_nonblock a;
  Unix.set_nonblock b;
  (Abb.Socket.Tcp.of_native a, Abb.Socket.Tcp.of_native b)

let close_both a b =
  let open Abb.Future.Infix_monad in
  Abb.Socket.close a >>= fun _ -> Abb.Socket.close b >>= fun _ -> Abb.Future.return ()

(* Some tests below need a descriptor that is NOT a socket, and nothing about
   which file it is matters to them.  The suite makes its own rather than
   reaching into /etc: this was /etc/hostname, which does not exist on macOS, and
   the three tests using it failed there for five days before a release run
   happened to execute them (#2018).  Any system path is the same bet on the next
   platform.  It carries a few bytes so a poll for readability has something to
   report -- an empty file need not wake a kqueue reader. *)
let regular_file =
  let path = Filename.temp_file "abb_fd_safety" ".tmp" in
  let oc = open_out_bin path in
  output_string oc "fd_safety";
  close_out oc;
  at_exit (fun () -> try Sys.remove path with Sys_error _ -> ());
  path

(* [readable]/[writable] return a non-result future, so they cannot report the
   closure to the caller.  They must still not arm a poll on the descriptor. *)
let readable_on_closed_socket =
  Oth_abb.test
    ~tags
    ~desc:"readable on a closed socket resolves rather than arming a poll on a dead descriptor"
    ~name:"readable on a closed socket"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let a, b = socket_pair () in
      Abb.Socket.close a
      >>= fun _ ->
      Abb.Socket.readable a
      >>= fun () ->
      Abb.Socket.writable a >>= fun () -> close_both a b >>= fun () -> Abb.Future.return ())

(* The closed flag is read when the op is DISPATCHED, not when the future is
   built, so a close landing in between is caught. *)
let op_built_before_close =
  Oth_abb.test
    ~tags
    ~desc:"a recv built while the socket was open fails once the socket closes before it is driven"
    ~name:"socket op built before a close"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let a, b = socket_pair () in
      let buf = Bytes.create 8 in
      let recv = Abb.Socket.Tcp.recv a ~buf ~pos:0 ~len:8 in
      Abb.Socket.close a
      >>= fun _ ->
      recv
      >>= fun res ->
      ignore (Oth.Assert.error ~fail_msg:"recv built before the close must fail" res);
      close_both a b >>= fun () -> Abb.Future.return ())

(* The number is free the moment the close lands, so an unrelated open can take
   it.  Polling it then reaches a stranger -- a regular file rejects epoll
   outright, which used to abort the process. *)
let descriptor_number_recycled =
  Oth_abb.test
    ~tags
    ~desc:"a socket op whose descriptor number was recycled onto a regular file fails"
    ~name:"recycled descriptor number"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let a, b = socket_pair () in
      let buf = Bytes.create 8 in
      let recv = Abb.Socket.Tcp.recv a ~buf ~pos:0 ~len:8 in
      Abb.Socket.close a
      >>= fun _ ->
      Abb.File.open_file ~flags:Abb_intf.File.Flag.[ Read_only ] regular_file
      >>= fun opened ->
      (* Without this the test silently degenerates into a duplicate of
         [op_built_before_close] whenever the kernel hands out a different
         number. *)
      (match opened with
      | Ok f ->
          Oth.Assert.true_
            "the open must have taken the closed socket's descriptor number"
            (Abb.File.to_native f = Abb.Socket.Tcp.to_native a)
      | Error _ -> Oth.Assert.false_ "could not open the suite's regular file");
      recv
      >>= fun res ->
      ignore (Oth.Assert.error ~fail_msg:"recv on a recycled number must fail" res);
      (match opened with
        | Ok f -> Abb.File.close f >>= fun _ -> Abb.Future.return ()
        | Error _ -> Abb.Future.return ())
      >>= fun () -> close_both a b >>= fun () -> Abb.Future.return ())

(* A poll already armed when the close lands must be stopped AND its waiter
   woken: silently dropping it parks the caller on an event that can never
   arrive. *)
let armed_poll_is_failed =
  Oth_abb.test
    ~tags
    ~desc:"a poll armed when the close lands is torn down and its waiter is failed"
    ~name:"armed poll failed by close"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let a, b = socket_pair () in
      let buf = Bytes.create 8 in
      (* Nothing to read on the pair, so this parks in an armed READABLE poll. *)
      Abb.Future.fork (Abb.Socket.Tcp.recv a ~buf ~pos:0 ~len:8)
      >>= fun parked ->
      Abb.Sys.sleep 0.05
      >>= fun () ->
      Abb.Socket.close a
      >>= fun _ ->
      let rec settle n =
        match Abb.Future.state parked with
        | `Undet when n > 0 -> Abb.Sys.sleep 0.02 >>= fun () -> settle (n - 1)
        | `Undet | `Det _ | `Aborted | `Exn _ -> Abb.Future.return (Abb.Future.state parked)
      in
      settle 100
      >>= fun st ->
      Oth.Assert.true_
        "the parked recv must be failed by the close, not left waiting"
        (match st with
        | `Det res -> Result.is_error res
        | `Undet | `Aborted | `Exn _ -> false);
      close_both a b >>= fun () -> Abb.Future.return ())

(* A file is the same kind of handle as a socket: closed once, and closed means
   closed for every later operation. *)
let file_ops_after_close =
  Oth_abb.test
    ~tags
    ~desc:"file close is idempotent and later reads fail rather than touching a recycled number"
    ~name:"file ops after close"
    (fun () ->
      let open Abb.Future.Infix_monad in
      Abb.File.open_file ~flags:Abb_intf.File.Flag.[ Read_only ] regular_file
      >>= fun opened ->
      let f = Oth.Assert.ok ~fail_msg:"could not open the suite's regular file" opened in
      Abb.File.close f
      >>= fun _ ->
      Abb.File.close f
      >>= fun second ->
      ignore (Oth.Assert.ok ~fail_msg:"a second close must succeed" second);
      let buf = Bytes.create 8 in
      Abb.File.read f ~buf ~pos:0 ~len:8
      >>= fun res ->
      ignore (Oth.Assert.error ~fail_msg:"read on a closed file must fail" res);
      let pbuf = Bytes.create 8 in
      Abb.File.pread f ~offset:0 ~buf:pbuf ~pos:0 ~len:8
      >>= fun pres ->
      ignore (Oth.Assert.error ~fail_msg:"pread on a closed file must fail" pres);
      Abb.Future.return ())

(* The production crash: [uv_poll_init] itself failing.  Wrapping a regular file
   in a LIVE handle reaches it without going through the closed-flag check that
   short-circuits the other tests.

   Which path this takes is platform-dependent, and the assertions are written to
   hold on both.  On Linux a regular file is a perfectly good descriptor that
   epoll refuses ([EPERM]), so the poll never arms.  On macOS the backend is
   kqueue, where [EVFILT_READ] on a vnode is valid, so libuv may arm it and
   report the file readable at once.  Either way the invariant #1984 added is the
   same and is what this pins: the waiter resolves and the loop survives, rather
   than the process aborting. *)
let poll_init_failure_is_reported =
  Oth_abb.test
    ~tags
    ~desc:"a poll that libuv refuses to arm resolves the waiter instead of killing the loop"
    ~name:"poll init failure reported"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let raw = Unix.openfile regular_file [ Unix.O_RDONLY ] 0 in
      let not_pollable = Abb.Socket.Tcp.of_native raw in
      Abb.Socket.readable not_pollable
      >>= fun () ->
      Abb.Socket.writable not_pollable
      >>= fun () -> Abb.Socket.close not_pollable >>= fun _ -> Abb.Future.return ())

(* The dangerous recycle is onto another SOCKET, where the retry's syscall would
   succeed and hand back a stranger's bytes rather than failing. *)
let no_stranger_io_after_close =
  Oth_abb.test
    ~tags
    ~desc:"a recv outstanding over a close never returns bytes belonging to whoever took the number"
    ~name:"no stranger io after close"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let a, b = socket_pair () in
      let buf = Bytes.make 16 '\000' in
      Abb.Future.fork (Abb.Socket.Tcp.recv a ~buf ~pos:0 ~len:16)
      >>= fun parked ->
      Abb.Sys.sleep 0.05
      >>= fun () ->
      Abb.Socket.close a
      >>= fun _ ->
      (* Take the freed number with a fresh pair and put recognisable bytes in it. *)
      let c, d = socket_pair () in
      Oth.Assert.true_
        "the new pair must have taken the closed socket's descriptor number"
        (Abb.Socket.Tcp.to_native c = Abb.Socket.Tcp.to_native a
        || Abb.Socket.Tcp.to_native d = Abb.Socket.Tcp.to_native a);
      let payload = Bytes.of_string "STRANGERSTRANGER" in
      Abb.Socket.Tcp.send d ~bufs:Abb_intf.Write_buf.[ { buf = payload; pos = 0; len = 16 } ]
      >>= fun _ ->
      let rec settle n =
        match Abb.Future.state parked with
        | `Undet when n > 0 -> Abb.Sys.sleep 0.02 >>= fun () -> settle (n - 1)
        | `Undet | `Det _ | `Aborted | `Exn _ -> Abb.Future.return (Abb.Future.state parked)
      in
      settle 100
      >>= fun st ->
      Oth.Assert.true_
        "the outstanding recv must fail, not read the new socket"
        (match st with
        | `Det res -> Result.is_error res
        | `Undet | `Aborted | `Exn _ -> false);
      Oth.Assert.true_
        "the outstanding recv must not have written a stranger's bytes into the buffer"
        (not (CCString.mem ~sub:"STRANGER" (Bytes.to_string buf)));
      close_both c d >>= fun () -> close_both a b >>= fun () -> Abb.Future.return ())

(* The shape abb_tls uses: wait for readiness, retry, repeat.  The loop has to
   START while the handle is open and have the close land underneath it, or it
   proves nothing -- entering it already-closed exits on the first test without
   ever calling [readable]. *)
let readable_loop_stops_on_close =
  Oth_abb.test
    ~tags
    ~desc:"a wait-retry loop of abb_tls's shape terminates when the socket closes underneath it"
    ~name:"readable loop stops on close"
    (fun () ->
      let open Abb.Future.Infix_monad in
      let a, b = socket_pair () in
      let rec poll_loop n =
        match Abb.Socket.is_closed a with
        | true -> Abb.Future.return (`Stopped n)
        | false when n > 100_000 -> Abb.Future.return `Ran_away
        | false -> Abb.Socket.readable a >>= fun () -> poll_loop (n + 1)
      in
      Abb.Future.fork (poll_loop 0)
      >>= fun looping ->
      Abb.Sys.sleep 0.05
      >>= fun () ->
      Abb.Socket.close a
      >>= fun _ ->
      let rec settle n =
        match Abb.Future.state looping with
        | `Undet when n > 0 -> Abb.Sys.sleep 0.02 >>= fun () -> settle (n - 1)
        | `Undet | `Det _ | `Aborted | `Exn _ -> Abb.Future.return (Abb.Future.state looping)
      in
      settle 100
      >>= fun st ->
      Oth.Assert.true_
        "a readable loop guarded by is_closed must stop once the socket closes"
        (* [n >= 1] rather than any [`Stopped]: zero means the forked loop was
           only scheduled after the close and took the [is_closed] branch on its
           first check, without ever calling [readable].  That would pass even if
           [readable] went back to parking forever. *)
        (match st with
        | `Det (`Stopped n) -> n >= 1
        | `Det `Ran_away | `Undet | `Aborted | `Exn _ -> false);
      close_both a b >>= fun () -> Abb.Future.return ())

let test =
  Oth.serial
    [
      readable_on_closed_socket;
      op_built_before_close;
      descriptor_number_recycled;
      armed_poll_is_failed;
      poll_init_failure_is_reported;
      no_stranger_io_after_close;
      readable_loop_stops_on_close;
      file_ops_after_close;
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
