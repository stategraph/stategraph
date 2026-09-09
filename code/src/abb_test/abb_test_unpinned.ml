module Make (Abb : Abb_intf.S) = struct
  module Oth_abb = Abb_test_oth.Make (Abb)
  module Fut_comb = Abb_future_combinators.Make (Abb.Future)

  (* Sanity check: an unpinned task that does no async work returns its
     value through the cross-domain delivery path. *)
  let basic =
    Oth_abb.test ~name:"Unpinned: basic return" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () -> Abb.Future.return 42)
        >>= fun fut -> fut >>| fun v -> Oth.Assert.Eq.int ~expected:42 ~actual:v)

  (* Async wait inside unpinned task body.  Exercises the
     dispatch-callback-to-worker path. *)
  let with_sleep =
    Oth_abb.test ~name:"Unpinned: sleep inside body" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () ->
            Abb.Sys.sleep 0.05 >>= fun () -> Abb.Future.return "done")
        >>= fun fut -> fut >>| fun v -> Oth.Assert.Eq.string ~expected:"done" ~actual:v)

  (* Long bind chain alternating CPU work and sleep. *)
  let bind_chain =
    Oth_abb.test ~name:"Unpinned: bind chain across waits" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () ->
            let rec loop k acc =
              if k = 0 then Abb.Future.return acc
              else Abb.Sys.sleep 0.005 >>= fun () -> loop (k - 1) (acc + k)
            in
            loop 10 0)
        >>= fun fut -> fut >>| fun v -> Oth.Assert.Eq.int ~expected:55 ~actual:v)

  (* Many concurrent unpinned tasks. *)
  let many_concurrent =
    Oth_abb.test ~name:"Unpinned: many concurrent" (fun () ->
        let open Abb.Future.Infix_monad in
        let n = 50 in
        let make_one i =
          Abb.Task.run ~pinned:false (fun () ->
              Abb.Sys.sleep 0.01 >>= fun () -> Abb.Future.return i)
          >>= fun fut -> fut
        in
        Fut_comb.List.map ~f:make_one (CCList.init n (fun i -> i))
        >>| fun results ->
        Oth.Assert.Eq.list
          ~eq:CCInt.equal
          ~pp:Format.pp_print_int
          ~expected:(CCList.init n (fun i -> i))
          ~actual:(CCList.sort CCInt.compare results))

  (* Exception in body surfaces back to the caller via Op.Run. *)
  let exception_in_body =
    Oth_abb.test ~name:"Unpinned: exception in body" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Future.fork
          (Abb.Task.run ~pinned:false (fun () ->
               Abb.Sys.sleep 0.01 >>= fun () -> raise (Failure "boom"))
          >>= fun fut -> fut)
        >>= fun outer ->
        Abb.Future.await outer
        >>| function
        | `Exn (Failure msg, _) when String.equal msg "boom" -> ()
        | `Exn (exn, _) ->
            Oth.Assert.false_
              (Printf.sprintf "expected Failure \"boom\", got %s" (Printexc.to_string exn))
        | `Det _ -> Oth.Assert.false_ "expected the body's exception, got a determined value"
        | `Aborted -> Oth.Assert.false_ "expected the body's exception, got an abort")

  (* Pinned task awaits an unpinned task's future and sees the right
     value.  Both directions of cross-pin Future-bind. *)
  let mixed_pin_states =
    Oth_abb.test ~name:"Unpinned: pinned awaits unpinned" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:true (fun () ->
            Abb.Task.run ~pinned:false (fun () ->
                Abb.Sys.sleep 0.01 >>= fun () -> Abb.Future.return 7)
            >>= fun inner -> inner)
        >>= fun outer -> outer >>| fun v -> Oth.Assert.Eq.int ~expected:7 ~actual:v)

  (* Thread.run inside an unpinned task body.  Confirms the unified Op
     path still delivers the result correctly when nested inside an
     unpinned context. *)
  let thread_run_inside_unpinned =
    Oth_abb.test ~name:"Unpinned: Thread.run inside body" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () ->
            Abb.Thread.run (fun () ->
                let s = ref 0 in
                for i = 1 to 100 do
                  s := !s + i
                done;
                !s)
            >>| fun v -> v)
        >>= fun fut -> fut >>| fun v -> Oth.Assert.Eq.int ~expected:5050 ~actual:v)

  (* Forks inside a single unpinned task must be serialized through
     that task's mailbox: even though each fork can have its own async
     waits, at most one of the task's callbacks runs at a time, on
     exactly one domain, regardless of how many workers are idle.
     This is the "as-if single-threaded scheduler within a task"
     invariant — concurrency between forks but no parallelism inside a
     single task.

     We launch [n] forks inside one unpinned task; each fork sleeps
     and then enters a critical section where it bumps an atomic
     [in_flight] counter, does CPU work to widen the window, and
     decrements.  If two of the task's callbacks ever ran in parallel
     on two domains, [in_flight] would briefly read 2 and the assert
     in [bump] would fire. *)
  let intra_task_serialization =
    Oth_abb.test ~name:"Unpinned: forks within a task are serialized" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () ->
            let in_flight = Atomic.make 0 in
            let critical_section () =
              let prev = Atomic.fetch_and_add in_flight 1 in
              Oth.Assert.Eq.int ~expected:0 ~actual:prev;
              let acc = ref 0 in
              for i = 1 to 200_000 do
                acc := !acc + i
              done;
              let _ = !acc in
              let prev = Atomic.fetch_and_add in_flight (-1) in
              Oth.Assert.Eq.int ~expected:1 ~actual:prev
            in
            let step () = Abb.Sys.sleep 0.001 >>| fun () -> critical_section () in
            let n = 8 in
            let rec loop k =
              if k = 0 then Abb.Future.return () else step () >>= fun () -> loop (k - 1)
            in
            let forks = CCList.init n (fun _ -> Abb.Future.fork (loop 5) >>= fun fut -> fut) in
            Fut_comb.List.iter ~f:CCFun.id forks
            >>| fun () -> Oth.Assert.Eq.int ~expected:0 ~actual:(Atomic.get in_flight))
        >>= fun fut -> fut)

  (* Aborting an unpinned task aborts the task itself: not just the
     scheduler-side awaiter but the worker body running on the thread
     pool.  After [Abb.Future.abort] on the task future the worker body
     stops at its next async suspension point and does not reach its
     end, and the task future resolves to [`Aborted]. *)
  let abort_stops_unpinned_worker =
    Oth_abb.test ~name:"Unpinned: abort stops the worker body" (fun () ->
        let open Abb.Future.Infix_monad in
        (* [reached_end] is written on the worker domain and read on the
           scheduler domain — [Atomic.t] keeps that cross-domain safe. *)
        let reached_end = Atomic.make false in
        let body () =
          let rec loop k =
            if k = 0 then Abb.Future.return () else Abb.Sys.sleep 0.005 >>= fun () -> loop (k - 1)
          in
          loop 20 >>| fun () -> Atomic.set reached_end true
        in
        Abb.Future.fork (Abb.Task.run ~pinned:false body >>= fun fut -> fut)
        >>= fun task_fut ->
        (* Let the worker get a few sleeps in before aborting. *)
        Abb.Sys.sleep 0.015
        >>= fun () ->
        Abb.Future.abort task_fut
        >>= fun () ->
        (* Wait past the body's total runtime (~100ms): the body must
           have stopped at the abort, not run to completion. *)
        Abb.Sys.sleep 0.2
        >>| fun () ->
        (* Awaiter side: the caller's future resolves to [`Aborted]. *)
        (match Abb.Future.state task_fut with
        | `Aborted -> ()
        | `Det _ | `Exn _ | `Undet ->
            Oth.Assert.false_ "expected the aborted task future to be in `Aborted state");
        (* Worker side: the body must not have run to completion. *)
        Oth.Assert.true_ "worker body stopped at the abort" (not (Atomic.get reached_end)))

  (* Aborting an unpinned task before the worker has advanced still
     stops it: the abort thunk waits in the task's mailbox and is
     drained as soon as the worker body runs. *)
  let abort_before_start =
    Oth_abb.test ~name:"Unpinned: abort before the worker starts" (fun () ->
        let open Abb.Future.Infix_monad in
        let reached_end = Atomic.make false in
        let body () = Abb.Sys.sleep 0.05 >>| fun () -> Atomic.set reached_end true in
        Abb.Future.fork (Abb.Task.run ~pinned:false body >>= fun fut -> fut)
        >>= fun task_fut ->
        (* Abort immediately, with no intervening suspension point. *)
        Abb.Future.abort task_fut
        >>= fun () ->
        Abb.Sys.sleep 0.1
        >>| fun () ->
        (match Abb.Future.state task_fut with
        | `Aborted -> ()
        | `Det _ | `Exn _ | `Undet ->
            Oth.Assert.false_ "expected the aborted task future to be in `Aborted state");
        Oth.Assert.true_ "worker body never started after abort" (not (Atomic.get reached_end)))

  (* An unpinned task (running on a worker domain) spawns a pinned
     child.  [~pinned:true] must place the child's body and callbacks on
     the loop domain regardless of where the caller runs.  Before the
     fix, [run_pinned] forked the "pinned" child inline into the
     unpinned parent's worker [State.t]; the child's [unpinned = None]
     op callbacks then ran on the loop domain against that same
     [State.t], racing two domains — caught by the [ABB_FUT_DEBUG]
     cross-domain detector under the dev profile. *)
  let pinned_child_basic =
    Oth_abb.test ~name:"Unpinned spawns pinned: basic return" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () ->
            Abb.Task.run ~pinned:true (fun () -> Abb.Future.return 42) >>= fun child -> child)
        >>= fun outer -> outer >>| fun v -> Oth.Assert.Eq.int ~expected:42 ~actual:v)

  (* The pinned child does async work: its body and every callback run
     on the loop domain while the parent runs on a worker. *)
  let pinned_child_with_sleep =
    Oth_abb.test ~name:"Unpinned spawns pinned: async work in child" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () ->
            Abb.Task.run ~pinned:true (fun () ->
                Abb.Sys.sleep 0.02 >>= fun () -> Abb.Future.return "done")
            >>= fun child -> child)
        >>= fun outer -> outer >>| fun v -> Oth.Assert.Eq.string ~expected:"done" ~actual:v)

  (* The unpinned parent aborts its pinned child mid-flight.  The abort
     is routed onto the loop domain, the child stops at its next async
     suspension point, and the child future resolves to [`Aborted]. *)
  let pinned_child_abort_midflight =
    Oth_abb.test ~name:"Unpinned spawns pinned: abort the child mid-flight" (fun () ->
        let open Abb.Future.Infix_monad in
        (* Written on the loop domain (child body), read on the parent's
           domain — [Atomic.t] keeps that cross-domain safe. *)
        let reached_end = Atomic.make false in
        Abb.Task.run ~pinned:false (fun () ->
            let body () =
              let rec loop k =
                if k = 0 then Abb.Future.return ()
                else Abb.Sys.sleep 0.005 >>= fun () -> loop (k - 1)
              in
              loop 20 >>| fun () -> Atomic.set reached_end true
            in
            Abb.Future.fork (Abb.Task.run ~pinned:true body >>= fun child -> child)
            >>= fun child_fut ->
            Abb.Sys.sleep 0.015
            >>= fun () ->
            Abb.Future.abort child_fut
            >>= fun () ->
            Abb.Sys.sleep 0.2
            >>| fun () ->
            (match Abb.Future.state child_fut with
            | `Aborted -> ()
            | `Det _ | `Exn _ | `Undet ->
                Oth.Assert.false_ "expected the aborted pinned child to be in `Aborted state");
            Oth.Assert.true_ "pinned child body stopped at the abort" (not (Atomic.get reached_end)))
        >>= fun outer -> outer)

  (* Aborting the pinned child before it has reached an async suspension
     point still stops it: the abort op is dispatched on the loop domain
     strictly after the body op, so it always finds the inner chain. *)
  let pinned_child_abort_immediately =
    Oth_abb.test ~name:"Unpinned spawns pinned: abort the child immediately" (fun () ->
        let open Abb.Future.Infix_monad in
        let reached_end = Atomic.make false in
        Abb.Task.run ~pinned:false (fun () ->
            let body () = Abb.Sys.sleep 0.05 >>| fun () -> Atomic.set reached_end true in
            Abb.Future.fork (Abb.Task.run ~pinned:true body >>= fun child -> child)
            >>= fun child_fut ->
            Abb.Future.abort child_fut
            >>= fun () ->
            Abb.Sys.sleep 0.1
            >>| fun () ->
            (match Abb.Future.state child_fut with
            | `Aborted -> ()
            | `Det _ | `Exn _ | `Undet ->
                Oth.Assert.false_ "expected the aborted pinned child to be in `Aborted state");
            Oth.Assert.true_
              "pinned child body never ran to completion"
              (not (Atomic.get reached_end)))
        >>= fun outer -> outer)

  (* An exception in the pinned child surfaces to the awaiting unpinned
     parent as [`Exn], and the parent's task id is intact afterwards. *)
  let pinned_child_exception =
    Oth_abb.test ~name:"Unpinned spawns pinned: exception in child" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () ->
            Abb.Task.id ()
            >>= fun parent_id ->
            Abb.Future.fork
              (Abb.Task.run ~pinned:true (fun () ->
                   Abb.Sys.sleep 0.01 >>= fun () -> raise (Failure "boom"))
              >>= fun child -> child)
            >>= fun child_fut ->
            Abb.Sys.sleep 0.05
            >>= fun () ->
            Abb.Task.id ()
            >>= fun parent_id' ->
            Oth.Assert.Eq.int ~expected:parent_id ~actual:parent_id';
            match Abb.Future.state child_fut with
            | `Exn (Failure msg, _) when String.equal msg "boom" -> Abb.Future.return ()
            | `Exn (exn, _) ->
                Oth.Assert.false_
                  (Printf.sprintf "expected Failure \"boom\", got %s" (Printexc.to_string exn))
            | `Det _ | `Undet | `Aborted ->
                Oth.Assert.false_ "expected the pinned child future to be in `Exn state")
        >>= fun outer -> outer)

  (* Deep nesting across the pin boundary: unpinned -> pinned -> unpinned.
     Each level gets a fresh task id and the chain data is restored on
     the way back out. *)
  let pinned_child_nesting =
    Oth_abb.test ~name:"Unpinned spawns pinned spawns unpinned" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () ->
            Abb.Task.id ()
            >>= fun id_unpinned ->
            Abb.Task.run ~pinned:true (fun () ->
                Abb.Task.id ()
                >>= fun id_pinned ->
                Abb.Task.run ~pinned:false (fun () ->
                    Abb.Task.id ()
                    >>= fun id_inner -> Abb.Sys.sleep 0.01 >>= fun () -> Abb.Future.return id_inner)
                >>= fun inner -> inner >>| fun id_inner -> (id_pinned, id_inner))
            >>= fun child ->
            child
            >>| fun (id_pinned, id_inner) ->
            Oth.Assert.true_
              "all three task ids are distinct"
              (id_unpinned <> id_pinned && id_pinned <> id_inner && id_unpinned <> id_inner))
        >>= fun outer -> outer)

  (* An unpinned task spawns an unpinned child as the very first action
     of its body.  This is the cross-pin mirror of [pinned_child_basic]
     for the unpinned/unpinned combination, and a regression test for
     the eager chain-data capture: when [Task.run] is the body's first
     action the caller's chain data is only reachable if it was captured
     at the call site, not inside the deferred [with_state] closure. *)
  let unpinned_child_first_action =
    Oth_abb.test ~name:"Unpinned spawns unpinned: child is first action" (fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Task.run ~pinned:false (fun () ->
            Abb.Task.run ~pinned:false (fun () ->
                Abb.Sys.sleep 0.02 >>= fun () -> Abb.Future.return 99)
            >>= fun child -> child)
        >>= fun outer -> outer >>| fun v -> Oth.Assert.Eq.int ~expected:99 ~actual:v)

  let test =
    Oth_abb.serial
      [
        basic;
        with_sleep;
        bind_chain;
        many_concurrent;
        exception_in_body;
        mixed_pin_states;
        thread_run_inside_unpinned;
        intra_task_serialization;
        abort_stops_unpinned_worker;
        abort_before_start;
        unpinned_child_first_action;
        pinned_child_basic;
        pinned_child_with_sleep;
        pinned_child_abort_midflight;
        pinned_child_abort_immediately;
        pinned_child_exception;
        pinned_child_nesting;
      ]
end
