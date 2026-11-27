module Make (Abb : Abb_intf.S) = struct
  module Oth_abb = Abb_test_oth.Make (Abb)
  module Fut_comb = Abb_fc.Make (Abb.Future)

  (* Future-state comparisons here only ever check the state tag
     ([`Undet]/[`Aborted]); no [`Det] value is present, so its eq/pp
     are placeholders. *)
  let assert_state expected actual =
    Oth.Assert.eq
      ~eq:(Abb_intf.Future.State.equal (fun _ _ -> false))
      ~pp:(Abb_intf.Future.State.pp (fun fmt _ -> Format.pp_print_string fmt "<det>"))
      expected
      actual

  let pp_chan_err fmt = function
    | `Chan_closed -> Format.pp_print_string fmt "`Chan_closed"

  (* Helpers to flatten the result-monad nesting in tests.  [ok_or_fail]
     unwraps an [Ok], asserting on [Error] with a typed printout. *)
  let ok_or_fail r = Oth.Assert.ok_pp ~pp:pp_chan_err r

  let assert_chan_closed r =
    match r with
    | Ok _ -> Oth.Assert.false_ "expected `Chan_closed, got Ok"
    | Error `Chan_closed -> ()

  let send_ok ch v =
    let open Abb.Future.Infix_monad in
    Abb.Chan.send ch v >>| ok_or_fail

  let recv_ok ch =
    let open Abb.Future.Infix_monad in
    Abb.Chan.recv ch >>| ok_or_fail

  let basic =
    Oth_abb.test ~name:"Chan: basic send/recv" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:4 () in
        send_ok ch 1
        >>= fun () ->
        send_ok ch 2
        >>= fun () ->
        recv_ok ch
        >>= fun v1 ->
        Oth.Assert.Eq.int ~expected:1 ~actual:v1;
        recv_ok ch >>| fun v2 -> Oth.Assert.Eq.int ~expected:2 ~actual:v2)

  let fifo =
    Oth_abb.test ~name:"Chan: FIFO ordering" (fun () ->
        let open Abb.Future.Infix_monad in
        let n = 16 in
        let ch = Abb.Chan.create ~capacity:n () in
        Fut_comb.List.iter ~f:(fun i -> send_ok ch i) (CCList.init n (fun i -> i))
        >>= fun () ->
        Fut_comb.List.map ~f:(fun _ -> recv_ok ch) (CCList.init n (fun _ -> ()))
        >>| fun received ->
        Oth.Assert.Int_list.eq ~expected:(CCList.init n (fun i -> i)) ~actual:received)

  (* Empty channel: recv parks until a producer sends. *)
  let recv_parks =
    Oth_abb.test ~name:"Chan: recv parks until send" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        Abb.Future.fork (Abb.Chan.recv ch)
        >>= fun deq_fut ->
        assert_state `Undet (Abb.Future.state deq_fut);
        Abb.Sys.sleep 0.02
        >>= fun () ->
        assert_state `Undet (Abb.Future.state deq_fut);
        send_ok ch "hello"
        >>= fun () ->
        deq_fut >>| fun r -> Oth.Assert.Eq.string ~expected:"hello" ~actual:(ok_or_fail r))

  (* Full channel: send parks until a consumer recvs. *)
  let send_parks =
    Oth_abb.test ~name:"Chan: send parks until recv" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        send_ok ch 1
        >>= fun () ->
        Abb.Future.fork (Abb.Chan.send ch 2)
        >>= fun enq_fut ->
        assert_state `Undet (Abb.Future.state enq_fut);
        Abb.Sys.sleep 0.02
        >>= fun () ->
        assert_state `Undet (Abb.Future.state enq_fut);
        recv_ok ch
        >>= fun v ->
        Oth.Assert.Eq.int ~expected:1 ~actual:v;
        enq_fut
        >>= fun r ->
        ok_or_fail r;
        recv_ok ch >>| fun v -> Oth.Assert.Eq.int ~expected:2 ~actual:v)

  let close_parked_recv =
    Oth_abb.test ~name:"Chan: close wakes parked recv" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        Abb.Future.fork (Abb.Chan.recv ch)
        >>= fun deq_fut ->
        Abb.Sys.sleep 0.02
        >>= fun () ->
        Abb.Chan.close ch;
        deq_fut >>| assert_chan_closed)

  let close_parked_send =
    Oth_abb.test ~name:"Chan: close wakes parked send" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        send_ok ch 1
        >>= fun () ->
        Abb.Future.fork (Abb.Chan.send ch 2)
        >>= fun enq_fut ->
        Abb.Sys.sleep 0.02
        >>= fun () ->
        Abb.Chan.close ch;
        enq_fut >>| assert_chan_closed)

  (* Closed channel still drains buffered items, then errors. *)
  let close_drains_then_errors =
    Oth_abb.test ~name:"Chan: closed channel drains then errors" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:4 () in
        send_ok ch 1
        >>= fun () ->
        send_ok ch 2
        >>= fun () ->
        Abb.Chan.close ch;
        Abb.Chan.send ch 3
        >>= fun r3 ->
        assert_chan_closed r3;
        recv_ok ch
        >>= fun v1 ->
        Oth.Assert.Eq.int ~expected:1 ~actual:v1;
        recv_ok ch
        >>= fun v2 ->
        Oth.Assert.Eq.int ~expected:2 ~actual:v2;
        Abb.Chan.recv ch >>| assert_chan_closed)

  (* Cross-domain hammer: every send runs from a [Thread.run]
     payload, so the channel's internal state is touched concurrently
     by N worker domains.  All values must be received exactly once on
     the scheduler-domain consumer. *)
  let cross_domain_producers =
    Oth_abb.test ~name:"Chan: cross-domain producers, single consumer" (fun () ->
        let open Abb.Future.Infix_monad in
        let n_producers = 8 in
        let per_producer = 50 in
        let total = n_producers * per_producer in
        let ch = Abb.Chan.create ~capacity:16 () in
        let producer_chain pid =
          let rec loop i =
            if i = per_producer then Abb.Future.return ()
            else
              Abb.Thread.run (fun () -> (pid * per_producer) + i)
              >>= fun v -> send_ok ch v >>= fun () -> loop (i + 1)
          in
          loop 0
        in
        let rec drain acc k =
          if k = 0 then Abb.Future.return acc else recv_ok ch >>= fun v -> drain (v :: acc) (k - 1)
        in
        (* Fork the consumer FIRST so producers don't deadlock on a full
           buffer waiting for a consumer that hasn't started. *)
        Abb.Future.fork (drain [] total)
        >>= fun consumer_fut ->
        Fut_comb.List.iter_par ~f:(fun pid -> producer_chain pid) (CCList.init n_producers CCFun.id)
        >>= fun () ->
        consumer_fut
        >>| fun received ->
        let sorted = CCList.sort CCInt.compare received in
        Oth.Assert.Int_list.eq ~expected:(CCList.init total (fun i -> i)) ~actual:sorted)

  (* Smaller buffer, more concurrency: the channel is full most of the
     time, forcing producer parking; the consumer also blocks
     occasionally.  This exercises the lost-wakeup window the mutex
     protects against. *)
  let many_producers_small_buffer =
    Oth_abb.test ~name:"Chan: many producers + small buffer (race)" (fun () ->
        let open Abb.Future.Infix_monad in
        let n = 200 in
        let ch = Abb.Chan.create ~capacity:4 () in
        let producer i = Abb.Thread.run (fun () -> i * i) >>= fun v -> send_ok ch v in
        let consumer () =
          let rec loop acc k =
            if k = 0 then Abb.Future.return acc else recv_ok ch >>= fun v -> loop (v :: acc) (k - 1)
          in
          loop [] n
        in
        Abb.Future.fork (consumer ())
        >>= fun consumer_fut ->
        Fut_comb.List.iter_par ~f:producer (CCList.init n CCFun.id)
        >>= fun () ->
        consumer_fut
        >>| fun received ->
        let expected = CCList.init n (fun i -> i * i) in
        let sorted = CCList.sort CCInt.compare received in
        Oth.Assert.Int_list.eq ~expected:(CCList.sort CCInt.compare expected) ~actual:sorted)

  (* Regression: a parked consumer must NOT spuriously receive
     [Chan_closed] when the buffer is drained by a racing fast-path
     [recv] between a [send] and the loop-domain [wake_parked_dequeue].
     The wake op should re-park the consumer and let the next send
     deliver to it.  Pre-fix the wake had two identical
     [Error `Chan_closed] branches and would always fail the parked
     consumer in this case. *)
  let wake_race_reparks =
    Oth_abb.test ~name:"Chan: wake race re-parks parked consumer" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        Abb.Future.fork (Abb.Chan.recv ch)
        >>= fun deq_fut ->
        Abb.Sys.sleep 0.02
        >>= fun () ->
        assert_state `Undet (Abb.Future.state deq_fut);
        send_ok ch 1
        >>= fun () ->
        recv_ok ch
        >>= fun v_fast ->
        Oth.Assert.Eq.int ~expected:1 ~actual:v_fast;
        Abb.Sys.sleep 0.02
        >>= fun () ->
        assert_state `Undet (Abb.Future.state deq_fut);
        send_ok ch 2
        >>= fun () -> deq_fut >>| fun r -> Oth.Assert.Eq.int ~expected:2 ~actual:(ok_or_fail r))

  let abort_parked_recv =
    Oth_abb.test ~name:"Chan: abort parked recv" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:2 () in
        Abb.Future.fork (Abb.Chan.recv ch)
        >>= fun deq_fut ->
        Abb.Sys.sleep 0.02
        >>= fun () ->
        assert_state `Undet (Abb.Future.state deq_fut);
        Abb.Future.abort deq_fut
        >>= fun () ->
        assert_state `Aborted (Abb.Future.state deq_fut);
        send_ok ch 99 >>= fun () -> recv_ok ch >>| fun v -> Oth.Assert.Eq.int ~expected:99 ~actual:v)

  let abort_parked_send =
    Oth_abb.test ~name:"Chan: abort parked send" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        send_ok ch 1
        >>= fun () ->
        Abb.Future.fork (Abb.Chan.send ch 2)
        >>= fun enq_fut ->
        Abb.Sys.sleep 0.02
        >>= fun () ->
        assert_state `Undet (Abb.Future.state enq_fut);
        Abb.Future.abort enq_fut
        >>= fun () ->
        assert_state `Aborted (Abb.Future.state enq_fut);
        recv_ok ch
        >>= fun v1 ->
        Oth.Assert.Eq.int ~expected:1 ~actual:v1;
        send_ok ch 3 >>= fun () -> recv_ok ch >>| fun v -> Oth.Assert.Eq.int ~expected:3 ~actual:v)

  let test =
    Oth_abb.serial
      [
        basic;
        fifo;
        recv_parks;
        send_parks;
        close_parked_recv;
        close_parked_send;
        close_drains_then_errors;
        cross_domain_producers;
        many_producers_small_buffer;
        abort_parked_recv;
        abort_parked_send;
        wake_race_reparks;
      ]
end
