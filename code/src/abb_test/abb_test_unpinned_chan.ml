(* Multi-domain channel / op cross-domain routing invariants.

   These exercise the rule that a parked operation's resume (and an async op's callback) is routed to
   the task that *drives* the operation -- read from the run state at act time -- not from where the
   operation was *constructed*.  A routing bug puts two domains on one [Abb_fut.State.t]; under the
   debug build ([ABB_FUT_DEBUG=1], the dev profile) the cross-domain owner-CAS aborts the whole
   process with exit 134, failing the suite.  (Same in-process mechanism as [abb_test_unpinned_send].)

   Multi-domain bugs come from the *interaction* of several pieces, so each scenario is a choreographed
   sequence: drive one piece to a known point (park, then hold its worker domain with a CPU spin),
   *then* have a counterparty act, using atomics as barriers to make the interleaving deterministic.

   Schedulers without [`Multi_domain] cannot exhibit the hazard, so the suite fast-succeeds there. *)
module Make (Abb : Abb_intf.S) = struct
  module Oth_abb = Abb_test_oth.Make (Abb)
  module Fut_comb = Abb_fc.Make (Abb.Future)

  let is_multi_domain =
    CCList.mem ~eq:Abb_intf.Scheduler_capability.equal `Multi_domain Abb.Scheduler.capabilities

  (* Hold the current worker domain (and thus this task's run state) busy: announce via [spinning],
     then spin until [release] is set.  Used inside an unpinned task to keep its [worker_state] owned
     while a counterparty on another domain fires a resume into it. *)
  let hold_worker ~spinning ~release =
    Atomic.set spinning true;
    while not (Atomic.get release) do
      Domain.cpu_relax ()
    done

  (* Generic overlap driver.  [op] is a future *constructed by the caller* (typically on the loop
     domain -- the out-of-context case).  An unpinned task forks [op] (so it is *driven* on the task's
     worker_state and parks there), then holds the worker with a spin.  The loop waits until the
     worker is spinning, runs [fire] (the counterparty that resumes [op]), gives the loop time to
     process the resume *while the worker still owns its state*, then releases the worker and awaits
     the task.  On buggy routing the resume runs inline on the loop -> two domains on the worker_state
     -> exit 134.

     Unpinned tasks are only *best-effort* parallel: under pool saturation the scheduler may run the
     body inline on the loop domain, where [hold_worker]'s spin would wedge the loop.  So the body
     first checks whether it landed on the loop domain and, if so, bails *before forking [op]* (a
     side-effect-free no-op, since Abb futures are lazy); the driver then retries until the body lands
     on a real worker domain.  With an idle pool the first attempt succeeds.  This keeps the test
     robust to scheduling decisions it does not control (e.g. transient saturation when the whole
     test tree runs in parallel). *)
  let overlap ~op ~fire =
    let open Abb.Future.Infix_monad in
    let loop_dom = Domain.self () in
    let rec attempt n =
      let spinning = Atomic.make false in
      let release = Atomic.make false in
      let fell_back = Atomic.make false in
      Abb.Task.run ~pinned:false (fun () ->
          let open Abb.Future.Infix_monad in
          if Domain.self () = loop_dom then (
            (* Body fell back onto the loop domain: announce and return without touching [op]. *)
            Atomic.set fell_back true;
            Abb.Future.return ())
          else
            Abb.Future.fork op
            >>= fun op_done ->
            hold_worker ~spinning ~release;
            op_done >>= fun _ -> Abb.Future.return ())
      >>= fun task_done ->
      (* The body sets exactly one of [spinning] (reached [hold_worker] on a worker) or [fell_back]
         (bailed on the loop); wait for whichever it is rather than racing the body's start. *)
      let rec wait_outcome () =
        if Atomic.get spinning then Abb.Future.return `Worker
        else if Atomic.get fell_back then Abb.Future.return `Fell_back
        else Abb.Sys.sleep 0.001 >>= wait_outcome
      in
      wait_outcome ()
      >>= function
      | `Fell_back ->
          task_done
          >>= fun () ->
          if n >= 1000 then
            Oth.Assert.false_
              "overlap: unpinned body never reached a worker domain (pool saturated?)"
          else Abb.Sys.sleep 0.001 >>= fun () -> attempt (n + 1)
      | `Worker ->
          fire ()
          >>= fun () ->
          Abb.Sys.sleep 0.2
          >>= fun () ->
          Atomic.set release true;
          task_done
    in
    attempt 1

  (* Counterparty actions. *)
  let from_loop f = f ()

  let from_worker f =
    let open Abb.Future.Infix_monad in
    Abb.Task.run ~pinned:false f >>= fun fut -> fut

  let ignore_send fut =
    let open Abb.Future.Infix_monad in
    fut >>| fun _ -> ()

  (* ---- A. Parked recv (dequeue) routing ---- *)

  (* THE original bug: recv built on the loop (out-of-context), driven/parked on a worker, woken by a
     loop-domain send while the worker is busy.  Pre-fix: exit 134. *)
  let recv_out_of_context_loop_send =
    Oth_abb.test ~name:"Chan: out-of-context recv, loop send, overlap" (fun () ->
        let ch = Abb.Chan.create ~capacity:1 () in
        overlap ~op:(Abb.Chan.recv ch) ~fire:(fun () ->
            from_loop (fun () -> ignore_send (Abb.Chan.send ch ()))))

  (* Same, but the waker is a *second worker domain* (worker -> worker hand-off). *)
  let recv_out_of_context_worker_send =
    Oth_abb.test ~name:"Chan: out-of-context recv, worker send, overlap" (fun () ->
        let ch = Abb.Chan.create ~capacity:1 () in
        overlap ~op:(Abb.Chan.recv ch) ~fire:(fun () ->
            from_worker (fun () -> ignore_send (Abb.Chan.send ch ()))))

  (* Out-of-context recv awaited via [Fc.first] against a never-resolving future: the recv is still
     driven on the worker via the combinator, not a bare fork. *)
  let recv_out_of_context_via_first =
    Oth_abb.test ~name:"Chan: out-of-context recv via Fc.first, loop send, overlap" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        let never = Abb.Future.Promise.future (Abb.Future.Promise.create ()) in
        let op = Fut_comb.first (Abb.Chan.recv ch >>| fun _ -> ()) never >>| fun _ -> () in
        overlap ~op ~fire:(fun () -> from_loop (fun () -> ignore_send (Abb.Chan.send ch ()))))

  (* ---- B. Parked send (enqueue) routing ---- the symmetric wake_one_parked_enqueue path ---- *)

  let send_parks_loop_recv =
    Oth_abb.test ~name:"Chan: out-of-context blocked send, loop recv frees it, overlap" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        (* Fill the single slot so the next send parks as a parked-enqueue. *)
        Abb.Chan.send ch 0
        >>= fun _ ->
        overlap ~op:(Abb.Chan.send ch 1) ~fire:(fun () ->
            from_loop (fun () -> Abb.Chan.recv ch >>| fun _ -> ())))

  let send_parks_worker_recv =
    Oth_abb.test ~name:"Chan: out-of-context blocked send, worker recv frees it, overlap" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        Abb.Chan.send ch 0
        >>= fun _ ->
        overlap ~op:(Abb.Chan.send ch 1) ~fire:(fun () ->
            from_worker (fun () -> Abb.Chan.recv ch >>| fun _ -> ())))

  (* ---- C. Channel close routing ---- *)

  let close_while_recv_parked =
    Oth_abb.test ~name:"Chan: close from loop while out-of-context recv parked, overlap" (fun () ->
        let ch = Abb.Chan.create ~capacity:1 () in
        overlap ~op:(Abb.Chan.recv ch) ~fire:(fun () ->
            Abb.Chan.close ch;
            Abb.Future.return ()))

  let close_while_send_parked =
    Oth_abb.test
      ~name:"Chan: close from loop while out-of-context blocked send parked, overlap"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        Abb.Chan.send ch 0
        >>= fun _ ->
        overlap ~op:(Abb.Chan.send ch 1) ~fire:(fun () ->
            Abb.Chan.close ch;
            Abb.Future.return ()))

  (* ---- D. Op-callback routing (Sleep, Thread) ---- the [Op.unpinned_ctx] read inside with_state ---- *)

  (* A sleep built on the loop, driven on a worker: the timer fires on the loop and its callback must
     be routed to the worker, not run inline -- exercised while the worker is held. *)
  let sleep_out_of_context =
    Oth_abb.test ~name:"Sleep: out-of-context timer callback routes to worker, overlap" (fun () ->
        overlap ~op:(Abb.Sys.sleep 0.05) ~fire:(fun () -> Abb.Future.return ()))

  (* A Thread.run built on the loop, driven on a worker: the pool worker's completion ([on_done]) must
     route to the issuing task's worker, not the loop. *)
  let thread_out_of_context =
    Oth_abb.test ~name:"Thread: out-of-context on_done routes to worker, overlap" (fun () ->
        let open Abb.Future.Infix_monad in
        let op =
          Abb.Thread.run (fun () ->
              Unix.sleepf 0.05;
              7)
          >>| fun _ -> ()
        in
        overlap ~op ~fire:(fun () -> Abb.Future.return ()))

  (* ---- E. Nested tasks & the result hand-off (deliver_result routing; band-aid removal) ---- *)

  (* An unpinned *caller* awaits an unpinned subtask while the caller holds its own worker domain.
     The subtask's result is delivered via the result channel; the caller's [Chan.recv result_ch] must
     resume on the caller's gate (this is what the removed [set_data outer_data] used to arrange). *)
  let unpinned_caller_awaits_unpinned_subtask =
    Oth_abb.test ~name:"Nested: unpinned caller awaits unpinned subtask, caller overlaps" (fun () ->
        let open Abb.Future.Infix_monad in
        let spinning = Atomic.make false in
        let release = Atomic.make false in
        Abb.Task.run ~pinned:false (fun () ->
            let open Abb.Future.Infix_monad in
            (* Spawn the subtask, fork-await it, and hold the caller's worker while it finishes. *)
            Abb.Future.fork
              (Abb.Task.run ~pinned:false (fun () ->
                   Abb.Sys.sleep 0.05 >>= fun () -> Abb.Future.return 11)
              >>= fun sub -> sub)
            >>= fun result ->
            hold_worker ~spinning ~release;
            result >>| fun v -> Oth.Assert.Eq.int ~expected:11 ~actual:v)
        >>= fun task_done ->
        let rec wait_spin () =
          if Atomic.get spinning then Abb.Future.return () else Abb.Sys.sleep 0.001 >>= wait_spin
        in
        wait_spin ()
        >>= fun () ->
        Abb.Sys.sleep 0.2
        >>= fun () ->
        Atomic.set release true;
        task_done)

  (* An unpinned caller awaits a *pinned* subtask (run_pinned_off_loop) while holding its worker. *)
  let unpinned_caller_awaits_pinned_subtask =
    Oth_abb.test ~name:"Nested: unpinned caller awaits pinned subtask, caller overlaps" (fun () ->
        let open Abb.Future.Infix_monad in
        let spinning = Atomic.make false in
        let release = Atomic.make false in
        Abb.Task.run ~pinned:false (fun () ->
            let open Abb.Future.Infix_monad in
            Abb.Future.fork
              (Abb.Task.run ~pinned:true (fun () ->
                   Abb.Sys.sleep 0.05 >>= fun () -> Abb.Future.return 13)
              >>= fun sub -> sub)
            >>= fun result ->
            hold_worker ~spinning ~release;
            result >>| fun v -> Oth.Assert.Eq.int ~expected:13 ~actual:v)
        >>= fun task_done ->
        let rec wait_spin () =
          if Atomic.get spinning then Abb.Future.return () else Abb.Sys.sleep 0.001 >>= wait_spin
        in
        wait_spin ()
        >>= fun () ->
        Abb.Sys.sleep 0.2
        >>= fun () ->
        Atomic.set release true;
        task_done)

  (* ---- F. Abort routing ---- *)

  (* Abort an unpinned task that is parked in a recv (built out-of-context): the abort must drive the
     worker chain only through the task's mailbox, and the task future resolves [`Aborted]. *)
  let abort_parked_recv =
    Oth_abb.test ~name:"Abort: unpinned task parked in out-of-context recv" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        let recv = Abb.Chan.recv ch in
        Abb.Future.fork (Abb.Task.run ~pinned:false (fun () -> recv >>| fun _ -> ()) >>= fun f -> f)
        >>= fun task_fut ->
        Abb.Sys.sleep 0.03
        >>= fun () ->
        Abb.Future.abort task_fut
        >>= fun () ->
        Abb.Sys.sleep 0.05
        >>| fun () ->
        match Abb.Future.state task_fut with
        | `Aborted -> ()
        | `Det _ | `Exn _ | `Undet ->
            Oth.Assert.false_ "expected aborted task to be in `Aborted state")

  (* Abort a task whose body has a *forked* sub-branch parked in a recv while the main branch sleeps:
     the abort must reach the forked branch's chain through the one gate. *)
  let abort_task_with_forked_recv =
    Oth_abb.test ~name:"Abort: unpinned task with a forked parked recv" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        Abb.Future.fork
          (Abb.Task.run ~pinned:false (fun () ->
               let open Abb.Future.Infix_monad in
               Abb.Future.fork (Abb.Chan.recv ch >>| fun _ -> ())
               >>= fun _branch -> Abb.Sys.sleep 1.0)
          >>= fun f -> f)
        >>= fun task_fut ->
        Abb.Sys.sleep 0.03
        >>= fun () ->
        Abb.Future.abort task_fut
        >>= fun () ->
        Abb.Sys.sleep 0.05
        >>| fun () ->
        match Abb.Future.state task_fut with
        | `Aborted -> ()
        | `Det _ | `Exn _ | `Undet ->
            Oth.Assert.false_ "expected aborted task to be in `Aborted state")

  (* ---- G. Task id/name correctness across domains (constraint 2) ---- *)

  (* A task's id/name must be intact after a cross-domain resume (a recv that parked on the worker and
     was woken by the loop). *)
  let id_name_after_cross_domain_resume =
    Oth_abb.test ~name:"Id/name: intact after a cross-domain recv resume" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch = Abb.Chan.create ~capacity:1 () in
        Abb.Task.run ~pinned:false (fun () ->
            let open Abb.Future.Infix_monad in
            Abb.Task.id ()
            >>= fun id0 ->
            Abb.Task.name ()
            >>= fun name0 ->
            Abb.Chan.recv ch
            >>= fun _ ->
            Abb.Task.id ()
            >>= fun id1 ->
            Abb.Task.name ()
            >>| fun name1 ->
            Oth.Assert.Eq.int ~expected:id0 ~actual:id1;
            Oth.Assert.true_ (name0 = name1))
        >>= fun task_fut ->
        Abb.Sys.sleep 0.02 >>= fun () -> Abb.Chan.send ch () >>= fun _ -> task_fut)

  (* Concurrent unpinned tasks reuse worker domains; their ids must stay distinct (no per-domain DLS
     bleed). *)
  let id_uniqueness_across_tasks =
    Oth_abb.test ~name:"Id: unique across many concurrent unpinned tasks" (fun () ->
        let open Abb.Future.Infix_monad in
        let n = 32 in
        let one _ =
          Abb.Task.run ~pinned:false (fun () -> Abb.Sys.sleep 0.005 >>= fun () -> Abb.Task.id ())
          >>= fun fut -> fut
        in
        Fut_comb.List.map ~f:one (CCList.init n (fun i -> i))
        >>| fun ids ->
        let uniq = CCList.sort_uniq ~cmp:CCInt.compare ids in
        Oth.Assert.Eq.int ~expected:n ~actual:(CCList.length uniq))

  (* ---- H. Multi-step interaction sequence ---- *)

  (* A multi-step worker->worker pipeline: the loop feeds ch1; unpinned task A forwards ch1 -> ch2
     (each step a cross-domain hand-off); unpinned task B drains ch2.  Exercises repeated park/resume
     across three domains in sequence and the parked-enqueue/parked-dequeue handshake when a parked
     producer's slot is freed by a parked consumer's wake (the channel lost-wakeup this regresses). *)
  let pipeline_through_two_tasks =
    Oth_abb.test ~name:"Sequence: loop -> taskA(forward) -> taskB(drain) pipeline" (fun () ->
        let open Abb.Future.Infix_monad in
        let ch1 = Abb.Chan.create ~capacity:1 () in
        let ch2 = Abb.Chan.create ~capacity:1 () in
        let n = 30 in
        let task_a =
          Abb.Task.run ~pinned:false (fun () ->
              let open Abb.Future.Infix_monad in
              let rec loop k =
                if k = 0 then Abb.Future.return ()
                else
                  Abb.Chan.recv ch1
                  >>= function
                  | Ok v -> Abb.Chan.send ch2 v >>= fun _ -> loop (k - 1)
                  | Error _ -> Abb.Future.return ()
              in
              loop n)
        in
        let collected = ref [] in
        let task_b =
          Abb.Task.run ~pinned:false (fun () ->
              let open Abb.Future.Infix_monad in
              let rec loop k acc =
                if k = 0 then Abb.Future.return (List.rev acc)
                else
                  Abb.Chan.recv ch2
                  >>= function
                  | Ok v -> loop (k - 1) (v :: acc)
                  | Error _ -> Abb.Future.return (List.rev acc)
              in
              loop n [] >>| fun xs -> collected := xs)
        in
        task_a
        >>= fun a ->
        task_b
        >>= fun b ->
        let rec feed k =
          if k = n then Abb.Future.return () else Abb.Chan.send ch1 k >>= fun _ -> feed (k + 1)
        in
        feed 0
        >>= fun () ->
        a
        >>= fun () ->
        b
        >>| fun () ->
        Oth.Assert.Int_list.eq ~expected:(CCList.init n (fun i -> i)) ~actual:!collected)

  (* ---- I. Stress / fuzz ---- *)

  (* Many unpinned tasks, each forking an out-of-context recv and then doing a *bounded* CPU spin
     (so the recv may be woken while the task still owns its worker), all woken by loop sends in a
     shuffled order.  A bounded spin -- rather than a global hold-until-released barrier -- lets the
     tasks cycle through the worker pool without requiring one worker per task, so this does not
     deadlock on a small pool.  It exercises routing under load with many interleavings. *)
  let stress_many_overlaps =
    Oth_abb.test ~name:"Stress: many concurrent out-of-context recv wakes under load" (fun () ->
        let open Abb.Future.Infix_monad in
        (* gcd(7, n) = 1 so [fun i -> i * 7 mod n] is a permutation -> a shuffled send order. *)
        let n = 24 in
        let chans = CCList.init n (fun _ -> Abb.Chan.create ~capacity:1 ()) in
        let recvs = CCList.map (fun ch -> Abb.Chan.recv ch) chans in
        let start recv =
          Abb.Task.run ~pinned:false (fun () ->
              let open Abb.Future.Infix_monad in
              Abb.Future.fork recv
              >>= fun done_ ->
              let acc = ref 0 in
              for i = 1 to 20_000_000 do
                acc := !acc + (i land 7)
              done;
              ignore !acc;
              done_ >>= fun _ -> Abb.Future.return ())
          >>= fun fut -> Abb.Future.return fut
        in
        Fut_comb.List.map ~f:start recvs
        >>= fun task_futs ->
        let order = CCList.init n (fun i -> i * 7 mod n) in
        Fut_comb.List.iter ~f:(fun i -> Abb.Chan.send (CCList.nth chans i) () >>| fun _ -> ()) order
        >>= fun () -> Fut_comb.List.iter ~f:CCFun.id task_futs)

  let skipped =
    Oth_abb.test ~name:"Chan cross-domain: skipped (single-domain scheduler)" (fun () ->
        Abb.Future.return ())

  let test =
    if is_multi_domain then
      Oth_abb.serial
        [
          recv_out_of_context_loop_send;
          recv_out_of_context_worker_send;
          recv_out_of_context_via_first;
          send_parks_loop_recv;
          send_parks_worker_recv;
          close_while_recv_parked;
          close_while_send_parked;
          sleep_out_of_context;
          thread_out_of_context;
          unpinned_caller_awaits_unpinned_subtask;
          unpinned_caller_awaits_pinned_subtask;
          abort_parked_recv;
          abort_task_with_forked_recv;
          id_name_after_cross_domain_resume;
          id_uniqueness_across_tasks;
          pipeline_through_two_tasks;
          stress_many_overlaps;
        ]
    else Oth_abb.serial [ skipped ]
end
