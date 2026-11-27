(* Tests for the pool-saturation fallback path and for the
   pinned-stays-on-loop / unpinned-can-leave-loop guarantees.

   When [Abb_domain_pool.try_enqueue] sees no idle worker the scheduler
   runs unpinned task work on the loop domain instead of queueing it
   behind whatever is occupying the pool.  These tests construct
   saturation deliberately by parking [Thread.run] payloads on a held
   [Mutex], then Oth.Assert.true_ (a) where the work actually ran (using
   [Domain.self ()]) and (b) that it completed.

   A separate test, on multi-core machines, asserts that unpinned task
   bodies do reach worker domains when the pool has idle slots — the
   parallelism payoff that motivated the unpinned model in the first
   place.  And a final test asserts that pinned tasks {b never} leave
   the loop, even when workers are available. *)
module Make (Abb : Abb_intf.S) = struct
  module Fut_comb = Abb_fc.Make (Abb.Future)

  let is_multi_domain =
    CCList.mem ~eq:Abb_intf.Scheduler_capability.equal `Multi_domain Abb.Scheduler.capabilities

  (* Bypass [Oth_abb] so we can pick the pool size per test. *)
  let run_sched ~thread_pool_size f =
    match Abb.Scheduler.run_with_state ~thread_pool_size (fun () -> f ()) with
    | `Det () -> ()
    | `Aborted -> Oth.Assert.false_ "scheduler run unexpectedly aborted"
    | `Exn (exn, Some bt) -> Printexc.raise_with_backtrace exn bt
    | `Exn (exn, None) -> raise exn

  (* Park [n] [Thread.run] payloads on [mu] (which the caller must
     already hold).  Returns the futures so the caller can await them
     after unlocking [mu].  After the small settle sleep every worker
     is guaranteed to be blocked inside [Mutex.lock mu], so
     [try_enqueue] will see [idle = 0]. *)
  let saturate_pool n mu =
    let open Abb.Future.Infix_monad in
    let blocker () =
      (* [Abb.Thread.run] is built with [Future.with_state] — its
         [Op.Thread] isn't submitted until something binds the future.
         [Future.fork] advances it once, which is enough to dispatch
         the op so a worker actually picks up the thunk and parks on
         the mutex. *)
      Abb.Future.fork
        (Abb.Thread.run (fun () ->
             Mutex.lock mu;
             Mutex.unlock mu))
    in
    Fut_comb.List.map ~f:(fun _ -> blocker ()) (CCList.init n CCFun.id)
    >>= fun blockers -> Abb.Sys.sleep 0.05 >>| fun () -> blockers

  (* Pool size 2, both workers blocked on a held mutex.  Pinned tasks
     don't touch the pool, but this confirms the scheduler isn't
     itself blocked by [Thread.run] saturation, and that pinned-task
     work stays on the loop domain regardless. *)
  let pinned_progress_under_saturation =
    Oth.test ~name:"Pool pressure: pinned tasks progress while pool is saturated" (fun _state ->
        run_sched ~thread_pool_size:2 (fun () ->
            let open Abb.Future.Infix_monad in
            let loop_dom = Domain.self () in
            let mu = Mutex.create () in
            Mutex.lock mu;
            saturate_pool 2 mu
            >>= fun blockers ->
            let n = 10 in
            Fut_comb.List.map
              ~f:(fun i ->
                Abb.Task.run ~pinned:true (fun () ->
                    Oth.Assert.true_ (Domain.self () = loop_dom);
                    Abb.Sys.sleep 0.01
                    >>| fun () ->
                    Oth.Assert.true_ (Domain.self () = loop_dom);
                    i)
                >>= fun fut -> fut)
              (CCList.init n CCFun.id)
            >>= fun results ->
            Oth.Assert.Int_list.eq
              ~expected:(CCList.init n CCFun.id)
              ~actual:(CCList.sort CCInt.compare results);
            Mutex.unlock mu;
            Fut_comb.List.iter ~f:CCFun.id blockers))

  (* Same setup, but with unpinned tasks.  Every worker is parked, so
     [try_enqueue] misses for every body and every callback drain; the
     task work runs on the loop domain instead.  Assertions inside the
     body confirm that [Domain.self ()] is the loop, and the surrounding
     bind chain confirms the work also produced the right values. *)
  let unpinned_progress_under_saturation =
    Oth.test ~name:"Pool pressure: unpinned tasks progress while pool is saturated" (fun _state ->
        run_sched ~thread_pool_size:2 (fun () ->
            let open Abb.Future.Infix_monad in
            let loop_dom = Domain.self () in
            let mu = Mutex.create () in
            Mutex.lock mu;
            saturate_pool 2 mu
            >>= fun blockers ->
            let n = 10 in
            Fut_comb.List.map
              ~f:(fun i ->
                Abb.Task.run ~pinned:false (fun () ->
                    (* Body fallback: ran on loop. *)
                    Oth.Assert.true_ (Domain.self () = loop_dom);
                    Abb.Sys.sleep 0.005
                    >>= fun () ->
                    (* run_callback fallback after first sleep: drained
                       inline on the loop. *)
                    Oth.Assert.true_ (Domain.self () = loop_dom);
                    Abb.Sys.sleep 0.005
                    >>| fun () ->
                    Oth.Assert.true_ (Domain.self () = loop_dom);
                    i)
                >>= fun fut -> fut)
              (CCList.init n CCFun.id)
            >>= fun results ->
            Oth.Assert.Int_list.eq
              ~expected:(CCList.init n CCFun.id)
              ~actual:(CCList.sort CCInt.compare results);
            Mutex.unlock mu;
            Fut_comb.List.iter ~f:CCFun.id blockers))

  (* No saturation: pinned tasks must still run on the loop, even when
     workers are sitting idle.  Pinned semantics don't depend on pool
     state — this guards against a future change accidentally letting a
     pinned task migrate. *)
  let pinned_stays_on_loop_when_pool_idle =
    Oth.test ~name:"Pool: pinned task always runs on loop even with idle workers" (fun _state ->
        run_sched ~thread_pool_size:4 (fun () ->
            let open Abb.Future.Infix_monad in
            let loop_dom = Domain.self () in
            let n = 30 in
            Fut_comb.List.iter_par
              ~f:(fun _ ->
                Abb.Task.run ~pinned:true (fun () ->
                    Oth.Assert.true_ (Domain.self () = loop_dom);
                    Abb.Sys.sleep 0.002 >>| fun () -> Oth.Assert.true_ (Domain.self () = loop_dom))
                >>= fun fut -> fut)
              (CCList.init n CCFun.id)))

  (* When the pool has idle workers, unpinned task bodies should at
     least sometimes land on a worker domain.  Capture [Domain.self ()]
     inside each body; assert at least one differs from the loop
     domain.  Skipped on single-core hosts (no other domain available). *)
  let unpinned_uses_worker_domains =
    Oth.test ~name:"Pool: unpinned task body sometimes runs on a worker domain" (fun _state ->
        (* A single-domain scheduler has no worker domain to land on; fast-succeed
           rather than fail an assertion it structurally cannot satisfy.  Also
           skipped on single-core hosts (no other domain available). *)
        if (not is_multi_domain) || Domain.recommended_domain_count () < 2 then ()
        else
          run_sched ~thread_pool_size:4 (fun () ->
              let open Abb.Future.Infix_monad in
              let loop_dom = Domain.self () in
              let saw_other = Atomic.make false in
              let n = 80 in
              Fut_comb.List.iter_par
                ~f:(fun _ ->
                  Abb.Task.run ~pinned:false (fun () ->
                      if Domain.self () <> loop_dom then Atomic.set saw_other true;
                      Abb.Sys.sleep 0.005)
                  >>= fun fut -> fut)
                (CCList.init n CCFun.id)
              >>| fun () -> Oth.Assert.true_ (Atomic.get saw_other)))

  let test =
    Oth.serial
      [
        pinned_progress_under_saturation;
        unpinned_progress_under_saturation;
        pinned_stays_on_loop_when_pool_idle;
        unpinned_uses_worker_domains;
      ]
end
