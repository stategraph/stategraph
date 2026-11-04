(* Tests for [wake_pending_compute], the helper that forks the dispatcher when
   an arm of the evaluator is done.

   [work_manifest_job_failed] and [run_stale_work_manifest_cleanup] cannot run
   in this suite. Both open with [with_conn storage], and [Terrat_storage.t] is
   [Pgsql_pool.t], which needs a real pool. So the helper takes the body as a
   parameter, and the cases exercise the body outcomes the helper's
   [Fc.with_finally] has to cover: a determination to [Ok], to an error, to an
   exception, and an abort.

   What this file does not observe: the drain-count property each entry point
   provides. In both entry points the helper wraps the whole body once, so the
   count is 1 per call unconditionally, and a path that calls the helper twice
   -- as [work_manifest_result]'s suspend arm does -- passes every case in this
   file by construction. Counting one drain per dispatch needs a real pool,
   which this suite does not have. *)

module Oth_abb = Oth_abb.Make (Abb)
module Ee2 = Terrat_vcs_event_evaluator2

let pp_int : Format.formatter -> int -> unit = fun fmt n -> Format.fprintf fmt "%d" n
let assert_count ~expected ~actual = Oth_abb.Assert.eq ~eq:( = ) ~pp:pp_int expected actual

(* The drain is a stub that counts its calls. The side effect is in its body,
   and [Fc.with_finally] awaits a determined future eagerly, so the count is
   observed when the result of the helper is observed.  The cases observe the
   outcome through [Abb.Future.await], because a determination to an exception
   or an abort does not run the [>>=] continuation. *)
let test_drain_runs_once ~name ~body ~expect =
  Oth_abb.test ~name (fun () ->
      let count = ref 0 in
      let drain () =
        incr count;
        Abb.Future.return ()
      in
      let open Abb.Future.Infix_monad in
      let helper = Ee2.wake_pending_compute ~drain body in
      Abb.Future.await helper
      >>= fun outcome ->
      (match (outcome, expect) with
      | `Det (Ok ()), `Ok | `Det (Error `Error), `Error | `Exn _, `Exn ->
          assert_count ~expected:1 ~actual:!count
      | `Det (Ok ()), _ ->
          Oth_abb.Assert.true_
            ~fail_msg:"the body determined to Ok where another outcome was expected"
            false
      | `Det (Error `Error), _ ->
          Oth_abb.Assert.true_
            ~fail_msg:"the body determined to an error where another outcome was expected"
            false
      | `Exn _, _ ->
          Oth_abb.Assert.true_ ~fail_msg:"the body raised where a determination was expected" false
      | `Aborted, _ ->
          Oth_abb.Assert.true_
            ~fail_msg:"the body was aborted where a determination was expected"
            false);
      Abb.Future.return ())

(* [Fc.ignore @@ Abb.Future.fork] exists so that an error of the drain can
   never reach the result of the body. This case pins that property. *)
let test_drain_error_is_not_the_result =
  Oth_abb.test
    ~name:"wake_pending_compute: an error from the drain does not reach the result of the body"
    (fun () ->
      let count = ref 0 in
      let drain () =
        incr count;
        Abb.Future.return (Error `Error)
      in
      let open Abb.Future.Infix_monad in
      let helper = Ee2.wake_pending_compute ~drain (fun () -> Abb.Future.return (Ok ())) in
      Abb.Future.await helper
      >>= fun outcome ->
      (match outcome with
      | `Det (Ok ()) -> assert_count ~expected:1 ~actual:!count
      | `Det (Error _) | `Exn _ | `Aborted ->
          Oth_abb.Assert.true_
            ~fail_msg:"an error of the drain reached the result of the body"
            false);
      Abb.Future.return ())

(* An abort of the body is the third outcome [Fc.with_finally] covers, and the
   drain must fork for it too: the dispatcher has to wake up for the slot the
   aborted work freed. *)
let test_aborted_body =
  Oth_abb.test ~name:"wake_pending_compute: the drain runs once when the body is aborted" (fun () ->
      let count = ref 0 in
      let drain () =
        incr count;
        Abb.Future.return ()
      in
      let open Abb.Future.Infix_monad in
      let p = Abb.Future.Promise.create ~abort:(fun _ -> Abb.Future.return ()) () in
      let helper = Ee2.wake_pending_compute ~drain (fun () -> Abb.Future.Promise.future p) in
      Abb.Future.abort (Abb.Future.Promise.future p)
      >>= fun () ->
      Abb.Future.await helper
      >>= fun outcome ->
      (match outcome with
      | `Aborted -> assert_count ~expected:1 ~actual:!count
      | `Det _ | `Exn _ ->
          Oth_abb.Assert.true_
            ~fail_msg:"the aborted body did not end the helper with an abort"
            false);
      Abb.Future.return ())

let test =
  Oth_abb.parallel
    [
      test_drain_runs_once
        ~name:"wake_pending_compute: the drain runs once when the body determines to Ok"
        ~body:(fun () -> Abb.Future.return (Ok ()))
        ~expect:`Ok;
      test_drain_runs_once
        ~name:"wake_pending_compute: the drain runs once when the body determines to an error"
        ~body:(fun () -> Abb.Future.return (Error `Error))
        ~expect:`Error;
      test_drain_runs_once
        ~name:"wake_pending_compute: the drain runs once when the body determines to an exception"
        ~body:(fun () -> raise (Failure "the body raised"))
        ~expect:`Exn;
      test_aborted_body;
      test_drain_error_is_not_the_result;
    ]

let () =
  Random.self_init ();
  Oth_abb.run
    ~file:__FILE__
    ~setup:(fun () -> Abbs_fc.return_ok ())
    ~teardown:(fun () -> Abb.Future.return ())
    (fun () -> test)
