module Fut = Abb_fut.Make (struct
  type data = unit

  let zero_data = ()

  type t = unit
end)

module Fut_comb = Abb_future_combinators.Make (Fut)

let first1 =
  Oth.test ~desc:"first returns determined future" ~name:"first with one determined" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let p1 = Fut.Promise.create () in
      let p2 = Fut.Promise.create () in
      let res = Fut_comb.first (Fut.Promise.future p1) (Fut.Promise.future p2) in
      ignore (Fut.run_with_state res dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set p1 1) dummy_state);
      match Fut.state res with
      | `Det (v, fut) ->
          Oth.Assert.Eq.int ~expected:1 ~actual:v;
          Oth.Assert.true_ "Fut.state fut = `Undet" (Fut.state fut = `Undet)
      | `Undet | `Aborted | `Exn _ ->
          Oth.Assert.false_ "first with one determined: unexpected value")

let first2 =
  Oth.test ~desc:"first returns determined future" ~name:"first with both determined" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let p1 = Fut.Promise.create () in
      let p2 = Fut.Promise.create () in
      let res = Fut_comb.first (Fut.Promise.future p1) (Fut.Promise.future p2) in
      ignore (Fut.run_with_state res dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set p1 1) dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set p2 2) dummy_state);
      match Fut.state res with
      | `Det (v, fut) -> (
          Oth.Assert.Eq.int ~expected:1 ~actual:v;
          match Fut.state fut with
          | `Det v -> Oth.Assert.Eq.int ~expected:2 ~actual:v
          | `Undet | `Aborted | `Exn _ ->
              Oth.Assert.false_ "first with both determined: unexpected value")
      | `Undet | `Aborted | `Exn _ ->
          Oth.Assert.false_ "first with both determined: unexpected value")

let first3 =
  Oth.test ~desc:"Abort aborts the whole thing" ~name:"Abort first" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let p1 = Fut.Promise.create () in
      let p2 = Fut.Promise.create () in
      let res = Fut_comb.first (Fut.Promise.future p1) (Fut.Promise.future p2) in
      ignore (Fut.run_with_state res dummy_state);
      ignore (Fut.run_with_state (Fut.abort res) dummy_state);
      Oth.Assert.true_ "Fut.state res = `Aborted" (Fut.state res = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p1) = `Aborted"
        (Fut.state (Fut.Promise.future p1) = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p2) = `Aborted"
        (Fut.state (Fut.Promise.future p2) = `Aborted))

let firstl1 =
  Oth.test ~desc:"firstl returns determined future" ~name:"firstl with one determined" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let p1 = Fut.Promise.create () in
      let p2 = Fut.Promise.create () in
      let res = Fut_comb.firstl [ Fut.Promise.future p1; Fut.Promise.future p2 ] in
      ignore (Fut.run_with_state res dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set p1 1) dummy_state);
      match Fut.state res with
      | `Det (v, [ fut ]) ->
          Oth.Assert.Eq.int ~expected:1 ~actual:v;
          Oth.Assert.true_ "Fut.state fut = `Undet" (Fut.state fut = `Undet)
      | `Det _ -> Oth.Assert.false_ "firstl with one determined: unexpected value"
      | `Undet | `Aborted | `Exn _ ->
          Oth.Assert.false_ "firstl with one determined: unexpected value")

let firstl2 =
  Oth.test ~desc:"firstl returns determined future" ~name:"firstl with both determined" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let p1 = Fut.Promise.create () in
      let p2 = Fut.Promise.create () in
      let res = Fut_comb.firstl [ Fut.Promise.future p1; Fut.Promise.future p2 ] in
      ignore (Fut.run_with_state res dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set p1 1) dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set p2 2) dummy_state);
      match Fut.state res with
      | `Det (v, [ fut ]) -> (
          Oth.Assert.Eq.int ~expected:1 ~actual:v;
          match Fut.state fut with
          | `Det v -> Oth.Assert.Eq.int ~expected:2 ~actual:v
          | `Undet | `Aborted | `Exn _ ->
              Oth.Assert.false_ "firstl with both determined: unexpected value")
      | `Det _ -> Oth.Assert.false_ "firstl with both determined: unexpected value"
      | `Undet | `Aborted | `Exn _ ->
          Oth.Assert.false_ "firstl with both determined: unexpected value")

let firstl3 =
  Oth.test ~desc:"Abort aborts the whole thing" ~name:"Abort firstl" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let p1 = Fut.Promise.create () in
      let p2 = Fut.Promise.create () in
      let res = Fut_comb.firstl [ Fut.Promise.future p1; Fut.Promise.future p2 ] in
      ignore (Fut.run_with_state res dummy_state);
      ignore (Fut.run_with_state (Fut.abort res) dummy_state);
      Oth.Assert.true_ "Fut.state res = `Aborted" (Fut.state res = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p1) = `Aborted"
        (Fut.state (Fut.Promise.future p1) = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p2) = `Aborted"
        (Fut.state (Fut.Promise.future p2) = `Aborted))

let map1 =
  Oth.test ~desc:"Simple map test" ~name:"Simple map" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let vs = [ 1; 2; 3 ] in
      let fut = Fut_comb.List.map ~f:Fut.return vs in
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Det [ 1; 2; 3 ]" (Fut.state fut = `Det [ 1; 2; 3 ]))

let map2 =
  Oth.test ~desc:"Simple map test" ~name:"Simple map" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let vs = [ 1; 2; 3 ] in
      let fut = Fut_comb.List.map ~f:Fut.return vs in
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Det [ 1; 2; 3 ]" (Fut.state fut = `Det [ 1; 2; 3 ]))

let firstl4 =
  Oth.test
    ~desc:"Aborting one of the inputs aborts the whole thing"
    ~name:"Abort firstl input"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let p1 = Fut.Promise.create () in
      let p2 = Fut.Promise.create () in
      let res = Fut_comb.firstl [ Fut.Promise.future p1; Fut.Promise.future p2 ] in
      ignore (Fut.run_with_state res dummy_state);
      ignore (Fut.run_with_state (Fut.abort (Fut.Promise.future p1)) dummy_state);
      Oth.Assert.true_ "Fut.state res = `Aborted" (Fut.state res = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p1) = `Aborted"
        (Fut.state (Fut.Promise.future p1) = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p2) = `Aborted"
        (Fut.state (Fut.Promise.future p2) = `Aborted))

let first4 =
  Oth.test
    ~desc:"Aborting one of the inputs aborts the whole thing"
    ~name:"Abort first input"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let p1 = Fut.Promise.create () in
      let p2 = Fut.Promise.create () in
      let res = Fut_comb.first (Fut.Promise.future p1) (Fut.Promise.future p2) in
      ignore (Fut.run_with_state res dummy_state);
      ignore (Fut.run_with_state (Fut.abort (Fut.Promise.future p1)) dummy_state);
      Oth.Assert.true_ "Fut.state res = `Aborted" (Fut.state res = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p1) = `Aborted"
        (Fut.state (Fut.Promise.future p1) = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p2) = `Aborted"
        (Fut.state (Fut.Promise.future p2) = `Aborted))

let with_finally_success =
  Oth.test ~desc:"Test the finally block is run on success" ~name:"with_finally success" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let finally_exec = ref 0 in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.with_finally
          (fun () -> Fut.Promise.future p)
          ~finally:(fun () ->
            incr finally_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set p ()) dummy_state);
      Oth.Assert.true_ "!finally_exec > 0" (!finally_exec > 0);
      Oth.Assert.Eq.int ~expected:1 ~actual:!finally_exec;
      Oth.Assert.true_ "Fut.state fut = `Det ()" (Fut.state fut = `Det ()))

let with_finally_aborted =
  Oth.test ~desc:"Test the finally block is run on abort" ~name:"with_finally aborted" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let finally_exec = ref 0 in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.with_finally
          (fun () -> Fut.Promise.future p)
          ~finally:(fun () ->
            incr finally_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort (Fut.Promise.future p)) dummy_state);
      Oth.Assert.true_ "!finally_exec > 0" (!finally_exec > 0);
      Oth.Assert.Eq.int ~expected:1 ~actual:!finally_exec;
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted))

let with_finally_aborted_complete =
  Oth.test
    ~desc:"Test the finally block finishes before next step"
    ~name:"with_finally aborted complete"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let finally_exec = ref 0 in
      let next_step_finally_count = ref 0 in
      let trigger_finally_step = Fut.Promise.create () in
      let p = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut.await
          (Fut_comb.with_finally
             (fun () -> Fut.Promise.future p)
             ~finally:(fun () ->
               Fut.Promise.future trigger_finally_step
               >>= fun () ->
               incr finally_exec;
               Fut.return ()))
        >>| fun _ -> next_step_finally_count := !finally_exec
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort (Fut.Promise.future p)) dummy_state);
      Oth.Assert.Eq.int ~expected:0 ~actual:!finally_exec;
      Oth.Assert.Eq.int ~expected:0 ~actual:!next_step_finally_count;
      ignore (Fut.run_with_state (Fut.Promise.set trigger_finally_step ()) dummy_state);
      Oth.Assert.Eq.int ~expected:1 ~actual:!finally_exec;
      Oth.Assert.Eq.int ~expected:1 ~actual:!next_step_finally_count;
      Oth.Assert.true_ "Fut.state fut = `Det ()" (Fut.state fut = `Det ()))

let with_finally_exn =
  Oth.test
    ~desc:"Test the finally block is run on a fut determining to an exn"
    ~name:"with_finally exn"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let finally_exec = ref 0 in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.with_finally
          (fun () -> Fut.Promise.future p)
          ~finally:(fun () ->
            incr finally_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set_exn p (Failure "foo", None)) dummy_state);
      Oth.Assert.true_ "!finally_exec > 0" (!finally_exec > 0);
      Oth.Assert.Eq.int ~expected:1 ~actual:!finally_exec;
      match Fut.state fut with
      | `Exn (Failure _, None) -> ()
      | _ -> Oth.Assert.false_ "with_finally exn: unexpected value")

let with_finally_raise =
  Oth.test
    ~desc:"Test the finally block is run on raising in the function"
    ~name:"with_finally raise"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let finally_exec = ref 0 in
      let fut =
        Fut_comb.with_finally
          (fun () -> failwith "foo")
          ~finally:(fun () ->
            incr finally_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_ "!finally_exec > 0" (!finally_exec > 0);
      Oth.Assert.Eq.int ~expected:1 ~actual:!finally_exec;
      match Fut.state fut with
      | `Exn (Failure _, Some _) -> ()
      | _ -> Oth.Assert.false_ "with_finally raise: unexpected value")

let with_finally_exn_in_finally =
  Oth.test
    ~desc:"Test the finally block where the finally throws an exception"
    ~name:"with_finally exn in finally"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let fut =
        Fut_comb.with_finally (fun () -> Fut.return ()) ~finally:(fun () -> failwith "finally")
      in
      ignore (Fut.run_with_state fut dummy_state);
      match Fut.state fut with
      | `Exn (Failure msg, Some _) ->
          Oth.Assert.Eq.string ~expected:"finally" ~actual:msg;
          ()
      | `Aborted -> Oth.Assert.false_ "with_finally exn in finally: unexpected value"
      | `Undet -> Oth.Assert.false_ "with_finally exn in finally: unexpected value"
      | `Exn _ -> Oth.Assert.false_ "with_finally exn in finally: unexpected value"
      | `Det _ -> Oth.Assert.false_ "with_finally exn in finally: unexpected value")

let with_finally_exn_in_body_and_finally =
  Oth.test
    ~desc:"Test the finally block where the body and finally throws an exception"
    ~name:"with_finally exn in body and finally"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let fut =
        Fut_comb.with_finally (fun () -> failwith "body") ~finally:(fun () -> failwith "finally")
      in
      ignore (Fut.run_with_state fut dummy_state);
      match Fut.state fut with
      | `Exn (Failure msg, Some _) ->
          Oth.Assert.Eq.string ~expected:"finally" ~actual:msg;
          ()
      | `Aborted -> Oth.Assert.false_ "with_finally exn in body and finally: unexpected value"
      | `Undet -> Oth.Assert.false_ "with_finally exn in body and finally: unexpected value"
      | `Exn _ -> Oth.Assert.false_ "with_finally exn in body and finally: unexpected value"
      | `Det _ -> Oth.Assert.false_ "with_finally exn in body and finally: unexpected value")

let with_finally_aborted_from_outside =
  Oth.test
    ~desc:"Test the finally block is run on abort from the outside"
    ~name:"with_finally aborted outside"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let finally_exec = ref 0 in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.with_finally
          (fun () -> Fut.Promise.future p)
          ~finally:(fun () ->
            incr finally_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "!finally_exec > 0" (!finally_exec > 0);
      Oth.Assert.Eq.int ~expected:1 ~actual:!finally_exec;
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p) = `Aborted"
        (Fut.state (Fut.Promise.future p) = `Aborted))

let with_finally_nested_raise =
  Oth.test ~name:"with_finally nested raise" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let inner_first = ref false in
      let inner_finally = ref false in
      let outer_finally = ref false in
      let start = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.with_finally
          (fun () ->
            Fut_comb.with_finally
              (fun () -> Fut.Promise.future start >>= fun () -> raise (Failure "fail"))
              ~finally:(fun () ->
                if not !outer_finally then (
                  inner_first := true;
                  inner_finally := true);
                Fut.return ()))
          ~finally:(fun () ->
            outer_finally := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set start ()) dummy_state);
      Oth.Assert.true_ "!inner_first" !inner_first;
      Oth.Assert.true_ "!outer_finally" !outer_finally)

let with_finally_nested_abort =
  Oth.test ~name:"with_finally nested abort" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let inner_first = ref false in
      let inner_finally = ref false in
      let outer_finally = ref false in
      let start = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.with_finally
          (fun () ->
            Fut_comb.with_finally
              (fun () -> Fut.Promise.future start)
              ~finally:(fun () ->
                if not !outer_finally then (
                  inner_first := true;
                  inner_finally := true);
                Fut.return ()))
          ~finally:(fun () ->
            outer_finally := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state Fut.(abort (Promise.future start)) dummy_state);
      Oth.Assert.true_ "!inner_first" !inner_first;
      Oth.Assert.true_ "!outer_finally" !outer_finally;
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted))

let with_finally_nested_abort_outside =
  Oth.test ~name:"with_finally nested abort outside" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let inner_first = ref false in
      let inner_finally = ref false in
      let outer_finally = ref false in
      let start = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.with_finally
          (fun () ->
            Fut_comb.with_finally
              (fun () -> Fut.Promise.future start)
              ~finally:(fun () ->
                if not !outer_finally then (
                  inner_first := true;
                  inner_finally := true);
                Fut.return ()))
          ~finally:(fun () ->
            outer_finally := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "!inner_first" !inner_first;
      Oth.Assert.true_ "!outer_finally" !outer_finally;
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted))

let with_finally_nested_abort_sequenced =
  Oth.test ~name:"with_finally nested abort sequenced" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let inner_first = ref false in
      let inner_finally = ref false in
      let outer_finally = ref false in
      let start = Fut.Promise.create () in
      let trigger_inner = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.with_finally
          (fun () ->
            Fut_comb.with_finally
              (fun () -> Fut.Promise.future start)
              ~finally:(fun () ->
                Fut.Promise.future trigger_inner
                >>= fun () ->
                if not !outer_finally then (
                  inner_first := true;
                  inner_finally := true);
                Fut.return ()))
          ~finally:(fun () ->
            outer_finally := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger_inner ()) dummy_state);
      Oth.Assert.true_ "!inner_first" !inner_first;
      Oth.Assert.true_ "!outer_finally" !outer_finally;
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future start) = `Aborted"
        (Fut.state (Fut.Promise.future start) = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future trigger_inner) = `Det ()"
        (Fut.state (Fut.Promise.future trigger_inner) = `Det ());
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted))

let with_finally_nested_exn_sequenced =
  Oth.test ~name:"with_finally nested exn sequenced" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let inner_first = ref false in
      let inner_finally = ref false in
      let outer_finally = ref false in
      let start = Fut.Promise.create () in
      let wait = Fut.Promise.create () in
      let trigger_inner = Fut.Promise.create () in
      let business_end =
        let open Fut.Infix_monad in
        Fut_comb.with_finally
          (fun () ->
            Fut_comb.with_finally
              (fun () -> Fut.Promise.future wait)
              ~finally:(fun () ->
                Fut.Promise.future trigger_inner
                >>= fun () ->
                if not !outer_finally then (
                  inner_first := true;
                  inner_finally := true);
                Fut.return ()))
          ~finally:(fun () ->
            outer_finally := true;
            Fut.return ())
      in
      let fut =
        Fut.Infix_app.(
          (fun _ _ -> ())
          <$> (let open Fut.Infix_monad in
               Fut.Promise.future start >>= fun () -> failwith "exn")
          <*> business_end)
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set start ()) dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger_inner ()) dummy_state);
      Oth.Assert.true_ "!inner_first" !inner_first;
      Oth.Assert.true_ "!outer_finally" !outer_finally;
      (match Fut.state fut with
      | `Aborted -> Oth.Assert.false_ "with_finally nested exn sequenced: unexpected value"
      | `Det _ -> Oth.Assert.false_ "with_finally nested exn sequenced: unexpected value"
      | `Undet -> Oth.Assert.false_ "with_finally nested exn sequenced: unexpected value"
      | `Exn (Failure _, _) -> ()
      | `Exn _ -> Oth.Assert.false_ "with_finally nested exn sequenced: unexpected value");
      match Fut.state business_end with
      | `Aborted -> Oth.Assert.false_ "with_finally nested exn sequenced: unexpected value"
      | `Det _ -> Oth.Assert.false_ "with_finally nested exn sequenced: unexpected value"
      | `Undet -> Oth.Assert.false_ "with_finally nested exn sequenced: unexpected value"
      | `Exn (Failure _, _) -> ()
      | `Exn _ -> Oth.Assert.false_ "with_finally nested exn sequenced: unexpected value")

let on_failure_success =
  Oth.test ~desc:"Test the failure block is not run on success" ~name:"on_failure success" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let failure_exec = ref 0 in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.on_failure
          (fun () -> Fut.Promise.future p)
          ~failure:(fun () ->
            incr failure_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set p ()) dummy_state);
      Oth.Assert.Eq.int ~expected:0 ~actual:!failure_exec;
      Oth.Assert.true_ "Fut.state fut = `Det ()" (Fut.state fut = `Det ()))

let on_failure_aborted =
  Oth.test ~desc:"Test the failure block is run on abort" ~name:"on_failure aborted" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let failure_exec = ref 0 in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.on_failure
          (fun () -> Fut.Promise.future p)
          ~failure:(fun () ->
            incr failure_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort (Fut.Promise.future p)) dummy_state);
      Oth.Assert.true_ "!failure_exec > 0" (!failure_exec > 0);
      Oth.Assert.Eq.int ~expected:1 ~actual:!failure_exec;
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted))

let on_failure_aborted_from_outside =
  Oth.test
    ~desc:"Test the failure block is run on abort from the outside"
    ~name:"on_failure aborted outside"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let failure_exec = ref 0 in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.on_failure
          (fun () -> Fut.Promise.future p)
          ~failure:(fun () ->
            incr failure_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "!failure_exec > 0" (!failure_exec > 0);
      Oth.Assert.Eq.int ~expected:1 ~actual:!failure_exec;
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p) = `Aborted"
        (Fut.state (Fut.Promise.future p) = `Aborted))

let on_failure_exn =
  Oth.test
    ~desc:"Test the failure block is run on a fut determining to an exn"
    ~name:"on_failure exn"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let failure_exec = ref 0 in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.on_failure
          (fun () -> Fut.Promise.future p)
          ~failure:(fun () ->
            incr failure_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set_exn p (Failure "foo", None)) dummy_state);
      Oth.Assert.true_ "!failure_exec > 0" (!failure_exec > 0);
      Oth.Assert.Eq.int ~expected:1 ~actual:!failure_exec;
      match Fut.state fut with
      | `Exn (Failure _, None) -> ()
      | _ -> Oth.Assert.false_ "on_failure exn: unexpected value")

let on_failure_raise =
  Oth.test
    ~desc:"Test the failure block is run on raising in the function"
    ~name:"on_failure raise"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let failure_exec = ref 0 in
      let fut =
        Fut_comb.on_failure
          (fun () -> failwith "foo")
          ~failure:(fun () ->
            incr failure_exec;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_ "!failure_exec > 0" (!failure_exec > 0);
      Oth.Assert.Eq.int ~expected:1 ~actual:!failure_exec;
      match Fut.state fut with
      | `Exn (Failure _, Some _) -> ()
      | _ -> Oth.Assert.false_ "on_failure raise: unexpected value")

let timeout_timeout =
  Oth.test ~desc:"Test timeout when the timeout function fires" ~name:"timeout timeout" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let timeout = Fut.Promise.create () in
      let call = Fut.Promise.create () in
      let wait = Fut_comb.timeout ~timeout:(Fut.Promise.future timeout) (Fut.Promise.future call) in
      ignore (Fut.run_with_state wait dummy_state);
      Oth.Assert.true_ "Fut.state wait = `Undet" (Fut.state wait = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set timeout ()) dummy_state);
      Oth.Assert.true_ "Fut.state wait = `Det `Timeout" (Fut.state wait = `Det `Timeout);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future call) = `Aborted"
        (Fut.state (Fut.Promise.future call) = `Aborted))

let timeout_success =
  Oth.test ~desc:"Test timeout when the operation succeeds" ~name:"timeout success" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let timeout = Fut.Promise.create () in
      let call = Fut.Promise.create () in
      let wait = Fut_comb.timeout ~timeout:(Fut.Promise.future timeout) (Fut.Promise.future call) in
      ignore (Fut.run_with_state wait dummy_state);
      Oth.Assert.true_ "Fut.state wait = `Undet" (Fut.state wait = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set call ()) dummy_state);
      Oth.Assert.true_ "Fut.state wait = `Det (`Ok ())" (Fut.state wait = `Det (`Ok ()));
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future timeout) = `Aborted"
        (Fut.state (Fut.Promise.future timeout) = `Aborted))

let protect_test =
  Oth.test ~name:"protect" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let protected = Fut.Promise.create () in
      let trigger = Fut.Promise.create () in
      let fut =
        Fut_comb.protect (fun () ->
            let open Fut.Infix_monad in
            Fut.Promise.future trigger >>= fun () -> Fut.Promise.set protected ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set trigger ()) dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Det ()"
        (Fut.state (Fut.Promise.future protected) = `Det ()))

let protect_fork_finally_abort_in_protect_test =
  Oth.test ~name:"protect fork_finally pattern abort in protect" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let hit_finally = ref false in
      let protected = Fut.Promise.create () in
      let trigger1 = Fut.Promise.create () in
      let trigger2 = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.protect (fun () ->
            Fut.Promise.future trigger1
            >>= fun () ->
            Fut.fork
              (Fut_comb.with_finally
                 (fun () -> Fut.Promise.future trigger2 >>= fun () -> Fut.Promise.set protected ())
                 ~finally:(fun () ->
                   hit_finally := true;
                   Fut.return ())))
        >>= fun fut -> fut
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set trigger1 ()) dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger2 ()) dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Det ()"
        (Fut.state (Fut.Promise.future protected) = `Det ());
      Oth.Assert.true_ "!hit_finally" !hit_finally)

let protect_fork_finally_abort_in_finally_test =
  Oth.test ~name:"protect fork_finally pattern abort in finally" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let hit_finally = ref false in
      let protected = Fut.Promise.create () in
      let trigger1 = Fut.Promise.create () in
      let trigger2 = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.protect (fun () ->
            Fut.Promise.future trigger1
            >>= fun () ->
            Fut.fork
              (Fut_comb.with_finally
                 (fun () -> Fut.Promise.future trigger2 >>= fun () -> Fut.Promise.set protected ())
                 ~finally:(fun () ->
                   hit_finally := true;
                   Fut.return ())))
        >>= fun fut -> fut
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger1 ()) dummy_state);
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set trigger2 ()) dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      Oth.Assert.true_ "!hit_finally" !hit_finally)

let protect_fork_finally_abort_in_on_failure_test =
  Oth.test ~name:"protect fork_on_failure pattern abort in on_failure" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let hit_failure = ref false in
      let protected = Fut.Promise.create () in
      let trigger1 = Fut.Promise.create () in
      let trigger2 = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.protect (fun () ->
            Fut.Promise.future trigger1
            >>= fun () ->
            Fut.fork
              (Fut_comb.on_failure
                 (fun () -> Fut.Promise.future trigger2 >>= fun () -> Fut.Promise.set protected ())
                 ~failure:(fun () ->
                   hit_failure := true;
                   Fut.return ())))
        >>= fun fut -> fut
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger1 ()) dummy_state);
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set trigger2 ()) dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      Oth.Assert.true_ "!hit_failure" !hit_failure)

let protect_finally_abort_in_protect_test =
  Oth.test ~name:"protect_finally abort in protect" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let hit_finally = ref false in
      let protected = Fut.Promise.create () in
      let trigger1 = Fut.Promise.create () in
      let trigger2 = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.protect_finally
          ~setup:(fun () -> Fut.Promise.future trigger1)
          (fun () -> Fut.Promise.future trigger2 >>= fun () -> Fut.Promise.set protected ())
          ~finally:(fun () ->
            hit_finally := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger1 ()) dummy_state);
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set trigger2 ()) dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      Oth.Assert.true_ "!hit_finally" !hit_finally)

let protect_finally_abort_in_body_test =
  Oth.test ~name:"protect_finally abort in body" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let hit_finally = ref false in
      let protected = Fut.Promise.create () in
      let trigger1 = Fut.Promise.create () in
      let trigger2 = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.protect_finally
          ~setup:(fun () -> Fut.Promise.future trigger1)
          (fun () -> Fut.Promise.future trigger2 >>= fun () -> Fut.Promise.set protected ())
          ~finally:(fun () ->
            hit_finally := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger1 ()) dummy_state);
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set trigger2 ()) dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      Oth.Assert.true_ "!hit_finally" !hit_finally)

let protect_finally_exn_in_body_test =
  Oth.test ~name:"protect_finally exn in body" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let hit_finally = ref false in
      let trigger1 = Fut.Promise.create () in
      let trigger2 = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.protect_finally
          ~setup:(fun () -> Fut.Promise.future trigger1)
          (fun () -> Fut.Promise.future trigger2 >>= fun () -> raise (Failure "foo"))
          ~finally:(fun () ->
            hit_finally := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger1 ()) dummy_state);
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger2 ()) dummy_state);
      (match Fut.state fut with
      | `Exn _ -> ()
      | `Undet -> Oth.Assert.false_ "protect_finally exn in body: unexpected value"
      | `Det _ -> Oth.Assert.false_ "protect_finally exn in body: unexpected value"
      | `Aborted -> Oth.Assert.false_ "protect_finally exn in body: unexpected value");
      Oth.Assert.true_ "!hit_finally" !hit_finally)

let protect_finally_abort_in_finally_test =
  Oth.test ~name:"protect_finally abort in finally" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let hit_finally = ref false in
      let protected = Fut.Promise.create () in
      let trigger1 = Fut.Promise.create () in
      let trigger2 = Fut.Promise.create () in
      let trigger3 = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.protect_finally
          ~setup:(fun () -> Fut.Promise.future trigger1)
          (fun () -> Fut.Promise.future trigger2 >>= fun () -> Fut.Promise.set protected ())
          ~finally:(fun () ->
            Fut.Promise.future trigger3
            >>= fun () ->
            hit_finally := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger1 ()) dummy_state);
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set trigger2 ()) dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Det ()"
        (Fut.state (Fut.Promise.future protected) = `Det ());
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      ignore (Fut.run_with_state (Fut.Promise.set trigger3 ()) dummy_state);
      Oth.Assert.true_ "!hit_finally" !hit_finally)

let protect_finally_success_test =
  Oth.test ~name:"protect_finally success" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let hit_finally = ref false in
      let protected = Fut.Promise.create () in
      let trigger1 = Fut.Promise.create () in
      let trigger2 = Fut.Promise.create () in
      let fut =
        let open Fut.Infix_monad in
        Fut_comb.protect_finally
          ~setup:(fun () -> Fut.Promise.future trigger1)
          (fun () -> Fut.Promise.future trigger2 >>= fun () -> Fut.Promise.set protected ())
          ~finally:(fun () ->
            hit_finally := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set trigger1 ()) dummy_state);
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Undet"
        (Fut.state (Fut.Promise.future protected) = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set trigger2 ()) dummy_state);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future protected) = `Det ()"
        (Fut.state (Fut.Promise.future protected) = `Det ());
      Oth.Assert.true_ "Fut.state fut = `Det ()" (Fut.state fut = `Det ());
      Oth.Assert.true_ "!hit_finally" !hit_finally)

let tap_det =
  Oth.test ~desc:"tap observes and propagates a determined value" ~name:"tap det" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let observed = ref None in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.tap
          (function
            | `Det v -> observed := Some v
            | `Exn _ | `Aborted -> Oth.Assert.false_ "tap det: unexpected value")
          (Fut.Promise.future p)
      in
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Undet" (Fut.state fut = `Undet);
      ignore (Fut.run_with_state (Fut.Promise.set p 42) dummy_state);
      Oth.Assert.true_ "!observed = Some 42" (!observed = Some 42);
      Oth.Assert.true_ "Fut.state fut = `Det 42" (Fut.state fut = `Det 42))

let tap_det_error =
  Oth.test
    ~desc:"tap propagates a determined value unchanged regardless of its contents"
    ~name:"tap det error"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let observed = ref false in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.tap
          (function
            | `Det (Error `Boom) -> observed := true
            | `Det (Ok _) | `Exn _ | `Aborted -> Oth.Assert.false_ "tap det error: unexpected value")
          (Fut.Promise.future p)
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set p (Error `Boom)) dummy_state);
      Oth.Assert.true_ "!observed" !observed;
      Oth.Assert.true_ "Fut.state fut = `Det (Error `Boom)" (Fut.state fut = `Det (Error `Boom)))

(* [while_] runs entirely on already-determined futures, so one [run_with_state]
   drives the whole loop to completion. *)
let while_state =
  Oth.test
    ~desc:"while_ threads state through iterations and returns the final state"
    ~name:"while_ state"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      (* Sum 1..5: the state is (next addend, running total), the value is the
         addend just consumed. *)
      let fut =
        Fut_comb.while_
          ~init:(1, 0)
          ~f:(fun (i, total) -> Fut.return ((i + 1, total + i), i))
          ~while_:(fun ((_, _), i) -> i < 5)
          ~betwixt:(fun _ -> Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Det ((6, 15), 5)" (Fut.state fut = `Det ((6, 15), 5)))

let while_betwixt_sees_state =
  Oth.test
    ~desc:"while_ passes the state/value pair to betwixt, once per continuation"
    ~name:"while_ betwixt"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let seen = ref [] in
      let fut =
        Fut_comb.while_
          ~init:0
          ~f:(fun i -> Fut.return (i + 1, i))
          ~while_:(fun (_, i) -> i < 3)
          ~betwixt:(fun pair ->
            seen := pair :: !seen;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Det (4, 3)" (Fut.state fut = `Det (4, 3));
      (* betwixt runs between iterations, not after the last one. *)
      Oth.Assert.true_
        "betwixt saw [(1, 0); (2, 1); (3, 2)]"
        (CCList.rev !seen = [ (1, 0); (2, 1); (3, 2) ]))

let while_finite_tries =
  Oth.test
    ~desc:"finite_tries caps while_ at n + 1 iterations of f"
    ~name:"while_ finite_tries"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let calls = ref 0 in
      (* [while_] never says stop, so only finite_tries ends the loop. *)
      let fut =
        Fut_comb.while_
          ~init:0
          ~f:(fun i ->
            incr calls;
            Fut.return (i + 1, i))
          ~while_:(Fut_comb.finite_tries 4 (fun _ -> true))
          ~betwixt:(fun _ -> Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.Eq.int ~expected:5 ~actual:!calls;
      Oth.Assert.true_ "Fut.state fut = `Det (5, 4)" (Fut.state fut = `Det (5, 4)))

let while_stops_immediately =
  Oth.test
    ~desc:"while_ runs f once when while_ is false from the start"
    ~name:"while_ stops immediately"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let betwixt_ran = ref false in
      let fut =
        Fut_comb.while_
          ~init:7
          ~f:(fun i -> Fut.return (i + 1, i))
          ~while_:(fun _ -> false)
          ~betwixt:(fun _ ->
            betwixt_ran := true;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      Oth.Assert.true_ "Fut.state fut = `Det (8, 7)" (Fut.state fut = `Det (8, 7));
      Oth.Assert.true_ "betwixt did not run" (not !betwixt_ran))

let retry_over_while_ =
  Oth.test
    ~desc:"retry, now built on while_, still loops until while_ is false"
    ~name:"retry over while_"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let calls = ref 0 in
      let betwixt_calls = ref 0 in
      let fut =
        Fut_comb.retry
          ~f:(fun () ->
            incr calls;
            Fut.return !calls)
          ~while_:(fun n -> n < 3)
          ~betwixt:(fun _ ->
            incr betwixt_calls;
            Fut.return ())
      in
      ignore (Fut.run_with_state fut dummy_state);
      (* retry returns the bare value, not the (state, value) pair. *)
      Oth.Assert.true_ "Fut.state fut = `Det 3" (Fut.state fut = `Det 3);
      Oth.Assert.Eq.int ~expected:3 ~actual:!calls;
      Oth.Assert.Eq.int ~expected:2 ~actual:!betwixt_calls)

let tap_exn =
  Oth.test ~desc:"tap observes and propagates an exception" ~name:"tap exn" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let observed = ref false in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.tap
          (function
            | `Exn (Failure _, _) -> observed := true
            | `Exn _ | `Det _ | `Aborted -> Oth.Assert.false_ "tap exn: unexpected value")
          (Fut.Promise.future p)
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.Promise.set_exn p (Failure "boom", None)) dummy_state);
      Oth.Assert.true_ "!observed" !observed;
      match Fut.state fut with
      | `Exn (Failure _, None) -> ()
      | _ -> Oth.Assert.false_ "tap exn: unexpected value")

let tap_aborted =
  Oth.test ~desc:"tap observes and propagates an abort of the input" ~name:"tap aborted" (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let observed = ref false in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.tap
          (function
            | `Aborted -> observed := true
            | `Det _ | `Exn _ -> Oth.Assert.false_ "tap aborted: unexpected value")
          (Fut.Promise.future p)
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort (Fut.Promise.future p)) dummy_state);
      Oth.Assert.true_ "!observed" !observed;
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted))

let tap_aborted_from_outside =
  Oth.test
    ~desc:"aborting the tapped future propagates the abort down to the input"
    ~name:"tap aborted outside"
    (fun _ ->
      let dummy_state = Abb_fut.State.create () in
      let observed = ref false in
      let p = Fut.Promise.create () in
      let fut =
        Fut_comb.tap
          (function
            | `Aborted -> observed := true
            | `Det _ | `Exn _ -> Oth.Assert.false_ "tap aborted outside: unexpected value")
          (Fut.Promise.future p)
      in
      ignore (Fut.run_with_state fut dummy_state);
      ignore (Fut.run_with_state (Fut.abort fut) dummy_state);
      Oth.Assert.true_ "!observed" !observed;
      Oth.Assert.true_ "Fut.state fut = `Aborted" (Fut.state fut = `Aborted);
      Oth.Assert.true_
        "Fut.state (Fut.Promise.future p) = `Aborted"
        (Fut.state (Fut.Promise.future p) = `Aborted))

let () =
  Oth.(
    run
      ~file:__FILE__
      ~setup:(fun () -> Ok ())
      ~teardown:(fun _ -> ())
      (fun _ ->
        parallel
          [
            first1;
            first2;
            first3;
            firstl1;
            firstl2;
            firstl3;
            map1;
            map2;
            firstl4;
            first4;
            with_finally_success;
            with_finally_aborted;
            with_finally_aborted_complete;
            with_finally_exn;
            with_finally_raise;
            with_finally_exn_in_finally;
            with_finally_exn_in_body_and_finally;
            with_finally_aborted_from_outside;
            with_finally_nested_raise;
            with_finally_nested_abort;
            with_finally_nested_abort_outside;
            with_finally_nested_abort_sequenced;
            with_finally_nested_exn_sequenced;
            on_failure_success;
            on_failure_aborted;
            on_failure_aborted_from_outside;
            on_failure_exn;
            on_failure_raise;
            timeout_timeout;
            timeout_success;
            protect_test;
            protect_fork_finally_abort_in_protect_test;
            protect_fork_finally_abort_in_finally_test;
            protect_fork_finally_abort_in_on_failure_test;
            protect_finally_abort_in_protect_test;
            protect_finally_abort_in_body_test;
            protect_finally_exn_in_body_test;
            protect_fork_finally_abort_in_finally_test;
            protect_finally_success_test;
            tap_det;
            tap_det_error;
            tap_exn;
            tap_aborted;
            tap_aborted_from_outside;
            while_state;
            while_betwixt_sees_state;
            while_finite_tries;
            while_stops_immediately;
            retry_over_while_;
          ]))
