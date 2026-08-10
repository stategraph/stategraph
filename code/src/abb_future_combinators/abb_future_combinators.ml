module Std_list = ListLabels

module Make (Fut : Abb_intf.Future.S) = struct
  open Fut.Infix_monad

  module List = struct
    let rec fold_left ~f ~init = function
      | [] -> Fut.return init
      | l :: ls -> f init l >>= fun acc -> fold_left ~f ~init:acc ls

    let map ~f l =
      fold_left ~f:(fun acc l -> f l >>= fun v -> Fut.return (v :: acc)) ~init:[] l
      >>= fun l -> Fut.return (Std_list.rev l)

    let map_par ~f l = map ~f:(fun v -> Fut.fork (f v)) l >>= fun l -> map ~f:Fun.id l
    let iter ~f l = fold_left ~f:(fun () l -> f l) ~init:() l

    let iter_par ~f l =
      (* Execute all of the futures and background them. *)
      map ~f:(fun v -> Fut.fork (f v)) l
      >>= fun l ->
      (* Now iterate through that list of background work, waiting for each one
         to finish. *)
      iter ~f:Fun.id l

    let filter ~f l =
      fold_left
        ~f:(fun acc v ->
          f v
          >>| function
          | true -> v :: acc
          | false -> acc)
        ~init:[]
        l
      >>| fun ls -> Std_list.rev ls

    let filter_map ~f l =
      fold_left
        ~f:(fun acc v ->
          f v
          >>= function
          | Some r -> Fut.return (r :: acc)
          | None -> Fut.return acc)
        ~init:[]
        l
      >>| fun l -> Std_list.rev l
  end

  let link f1 f2 =
    Fut.add_dep ~dep:f1 f2;
    Fut.add_dep ~dep:f2 f1

  let unit = Fut.return ()
  let ignore fut = fut >>= fun _ -> unit
  let background fut = ignore (Fut.fork fut)

  let first f1 f2 =
    let p = Fut.Promise.create () in
    link f1 (Fut.Promise.future p);
    link f2 (Fut.Promise.future p);
    Fut.fork (f1 >>= fun v -> Fut.Promise.set p (v, f2))
    >>= fun r1 ->
    Fut.fork (f2 >>= fun v -> Fut.Promise.set p (v, f1))
    >>= fun r2 ->
    Fut.fork (r1 >>= fun () -> Fut.cancel r2)
    >>= fun _ -> Fut.fork (r2 >>= fun () -> Fut.cancel r1) >>= fun _ -> Fut.Promise.future p

  let firstl l =
    let p = Fut.Promise.create () in
    Std_list.iter ~f:(fun dep -> link dep (Fut.Promise.future p)) l;
    let futl = Std_list.mapi ~f:(fun idx fut -> fut >>= fun v -> Fut.Promise.set p (idx, v)) l in
    List.iter ~f:(fun fut -> ignore (Fut.fork fut)) futl
    >>= fun () ->
    Fut.Promise.future p
    >>= fun (idx, v) ->
    let _, rest_rev =
      Std_list.fold_left
        ~f:(fun (i, l) fut -> if i = idx then (i + 1, l) else (i + 1, fut :: l))
        ~init:(0, [])
        l
    in
    (* Cancel those other ones *)
    List.iter ~f:Fut.cancel futl >>| fun () -> (v, Std_list.rev rest_rev)

  let all l =
    List.iter ~f:(fun fut -> ignore (Fut.fork fut)) l
    >>= fun () ->
    let fut = List.map ~f:(fun x -> x) l in
    Std_list.iter ~f:(fun d -> link d fut) l;
    fut

  let all2 a b = Fut.Infix_app.((fun a b -> (a, b)) <$> a <*> b)
  let all3 a b c = Fut.Infix_app.((fun a b c -> (a, b, c)) <$> a <*> b <*> c)
  let all4 a b c d = Fut.Infix_app.((fun a b c d -> (a, b, c, d)) <$> a <*> b <*> c <*> d)

  let all5 a b c d e =
    Fut.Infix_app.((fun a b c d e -> (a, b, c, d, e)) <$> a <*> b <*> c <*> d <*> e)

  let all6 a b c d e f =
    Fut.Infix_app.((fun a b c d e f -> (a, b, c, d, e, f)) <$> a <*> b <*> c <*> d <*> e <*> f)

  let all7 a b c d e f g =
    Fut.Infix_app.(
      (fun a b c d e f g -> (a, b, c, d, e, f, g)) <$> a <*> b <*> c <*> d <*> e <*> f <*> g)

  let with_finally f ~finally =
    try
      let fut = f () in
      (* Tracking if finally was called is necessary because we could fail while
         executing the finally, so we do not want to call it again. (see [Double
         Fail Here] below.) *)
      let finally_called = ref false in
      let finally () =
        if not !finally_called then (
          finally_called := true;
          finally ())
        else Fut.return ()
      in
      let p = Fut.Promise.create ~abort:finally () in
      Fut.add_dep ~dep:fut (Fut.Promise.future p);
      Fut.fork
        (Fut.await_bind
           (function
             | `Det v -> (
                 try
                   Fut.await_bind
                     (function
                       | `Det () -> Fut.Promise.set p v
                       | `Exn exn -> Fut.Promise.set_exn p exn
                       | `Aborted -> Fut.abort (Fut.Promise.future p))
                     (finally ())
                 with exn ->
                   (* Double Fail Here.  In order to get here, we have executed
                      [finally] however it threw an exception, in which case the
                      promise [p] will be set to the exception, which will cause
                      its [abort] function to be executed, but we've already
                      executed that, which is why we're failing it. *)
                   Fut.Promise.set_exn p (exn, Some (Printexc.get_raw_backtrace ())))
             | `Exn exn -> Fut.Promise.set_exn p exn
             | `Aborted -> Fut.abort (Fut.Promise.future p))
           fut)
      >>= fun _ -> Fut.Promise.future p
    with exn -> (
      try
        finally ()
        >>= fun () ->
        let p = Fut.Promise.create () in
        Fut.Promise.set_exn p (exn, Some (Printexc.get_raw_backtrace ()))
        >>= fun () -> Fut.Promise.future p
      with exn ->
        (* Calling the finally function failed *)
        let p = Fut.Promise.create () in
        Fut.Promise.set_exn p (exn, Some (Printexc.get_raw_backtrace ()))
        >>= fun () -> Fut.Promise.future p)

  let on_failure f ~failure =
    let succeeded = ref false in
    with_finally
      (fun () ->
        f ()
        >>| fun ret ->
        succeeded := true;
        ret)
      ~finally:(fun () -> if not !succeeded then failure () else unit)

  let protect f =
    let open Fut.Infix_monad in
    let ret = Fut.Promise.create () in
    Fut.fork
      (try
         Fut.await_bind
           (function
             | `Det v -> Fut.Promise.set ret v
             | `Exn exn -> Fut.Promise.set_exn ret exn
             | `Aborted -> Fut.abort (Fut.Promise.future ret))
           (f ())
       with exn -> Fut.Promise.set_exn ret (exn, Some (Printexc.get_raw_backtrace ())))
    >>= fun _ -> Fut.Promise.future ret

  let protect_finally ~setup ~finally body =
    let open Fut.Infix_monad in
    (* Create a promise which we want to return immediately.  We will use that
       to track if we have been aborted in any way during the protected setup
       phase, so that we can execute the finally block. *)
    let p = Fut.Promise.create () in
    Fut.fork
      (protect (fun () ->
           setup ()
           >>= fun v ->
           match Fut.state (Fut.Promise.future p) with
           | `Det _ -> assert false
           | `Undet ->
               (* Need fork executing the body so that we can exit the protected
                  block. We want running the body to abortable.  Forking lets us
                  spin the work off to the background, get a future connected to
                  it out of the [protect] and then add it as a dependency to the
                  future we returned, thus propagating any aborts to the
                  underlying future executing the body. *)
               Fut.fork
                 (with_finally
                    (fun () -> body v >>= Fut.Promise.set p)
                    ~finally:(fun () -> finally v))
           | `Aborted | `Exn _ ->
               (* The future we returned while doing the setup has been aborted,
                  so execute finally. *)
               Fut.fork (finally v))
      >>= fun fut ->
      Fut.add_dep ~dep:fut (Fut.Promise.future p);
      Fut.await_bind
        (function
          | `Det _ -> Fut.return ()
          | `Exn exn -> Fut.Promise.set_exn p exn
          | `Aborted -> Fut.abort (Fut.Promise.future p))
        fut)
    >>= fun _ -> Fut.Promise.future p

  let tap f fut =
    let open Fut.Infix_monad in
    (* Mirror [protect_finally]: hand back a fresh promise whose future is wired to [fut] via
       [add_dep] so an abort of the returned future flows down to [fut], then re-propagate [fut]'s
       outcome (value, exception, or abort) unchanged after handing it to [f]. [f] is purely an
       observer -- it does not alter what propagates. *)
    let p = Fut.Promise.create () in
    Fut.add_dep ~dep:fut (Fut.Promise.future p);
    Fut.fork
      (Fut.await_bind
         (fun set ->
           f set;
           match set with
           | `Det v -> Fut.Promise.set p v
           | `Exn exn -> Fut.Promise.set_exn p exn
           | `Aborted -> Fut.abort (Fut.Promise.future p))
         fut)
    >>= fun _ -> Fut.Promise.future p

  let to_result fut = fut >>= fun v -> Fut.return (Ok v)

  let of_option = function
    | Some fut -> fut >>| fun r -> Some r
    | None -> Fut.return None

  let with_cancel ~cancel fut =
    let open Fut.Infix_monad in
    let cancel_fut = cancel >>| fun () -> Error `Cancelled in
    first cancel_fut (fut >>| fun r -> Ok r)
    >>= function
    | ret, fut -> Fut.cancel fut >>| fun () -> ret

  let timeout ~timeout fut =
    let open Fut.Infix_monad in
    let t_fut = timeout >>| fun () -> `Timeout in
    let call = fut >>| fun r -> `Ok r in
    first call t_fut
    >>= function
    | (`Ok _ as r), fut -> Fut.abort fut >>| fun () -> r
    | `Timeout, fut -> Fut.abort fut >>| fun () -> `Timeout

  let rec while_ ~init ~f ~while_:w ~betwixt =
    let open Fut.Infix_monad in
    f init
    >>= function
    | (state, _) as r when w r -> betwixt r >>= fun () -> while_ ~init:state ~f ~while_:w ~betwixt
    | r -> Fut.return r

  let retry ~f ~while_:w ~betwixt =
    let open Fut.Infix_monad in
    while_
      ~init:()
      ~f:(fun () -> f () >>| fun r -> ((), r))
      ~while_:(fun (_, r) -> w r)
      ~betwixt:(fun (_, r) -> betwixt r)
    >>| snd

  let finite_tries num_tries while_ =
    assert (num_tries > 0);
    let num_tries = ref num_tries in
    function
    | r when !num_tries > 0 ->
        decr num_tries;
        while_ r
    | _ -> false

  let series ~start ~step f =
    let start = ref start in
    fun v ->
      let start' = !start in
      start := step !start;
      f start' v

  let of_exn exn =
    let open Fut.Infix_monad in
    let p = Fut.Promise.create () in
    Fut.Promise.set_exn p (exn, None) >>= fun () -> Fut.Promise.future p

  let guard f = try f () with exn -> of_exn exn
  let when_ b f = if b then f () else unit
  let when_m mb f = mb >>= fun b -> when_ b f

  module Infix_result_monad = struct
    type ('a, 'b) t = ('a, 'b) result Fut.t

    let ( >>= ) t f =
      t
      >>= function
      | Ok v -> f v
      | Error _ as err -> Fut.return err

    let ( >>| ) t f =
      t
      >>| function
      | Ok v -> Ok (f v)
      | Error _ as err -> err

    let when_ b f = if b then f () else Fut.return (Ok ())
    let when_m mb f = mb >>= fun b -> when_ b f
  end

  module Infix_result_app = struct
    type ('a, 'b) t = ('a, 'b) result Fut.t

    let ( <*> ) ft v =
      Fut.Infix_app.(
        (let open Fut.Infix_monad in
         ft
         >>| function
         | Ok f -> (
             function
             | Ok ok -> Ok (f ok)
             | Error _ as err -> err)
         | Error _ as err -> fun _ -> err)
        <*> v)

    let ( <$> ) f v = Fut.return (Ok f) <*> v
  end

  module List_result = struct
    open Infix_result_monad

    let rec fold_left ~f ~init = function
      | [] -> Fut.return (Ok init)
      | l :: ls -> f init l >>= fun acc -> fold_left ~f ~init:acc ls

    let map ~f l =
      fold_left ~f:(fun acc l -> f l >>= fun v -> Fut.return (Ok (v :: acc))) ~init:[] l
      >>| fun l -> Std_list.rev l

    let iter ~f l = fold_left ~f:(fun () l -> f l) ~init:() l

    let filter ~f l =
      fold_left
        ~f:(fun acc v ->
          f v
          >>| function
          | true -> v :: acc
          | false -> acc)
        ~init:[]
        l
      >>| fun ls -> Std_list.rev ls

    let filter_map ~f l =
      fold_left
        ~f:(fun acc v ->
          f v
          >>= function
          | Some r -> Fut.return (Ok (r :: acc))
          | None -> Fut.return (Ok acc))
        ~init:[]
        l
      >>| fun l -> Std_list.rev l
  end

  module Result = struct
    let map_err ~f fut =
      fut
      >>= function
      | Ok _ as r -> Fut.return r
      | Error err -> Fut.return (Error (f err))

    let ignore fut =
      fut
      >>= function
      | Ok _ -> Fut.return (Ok ())
      | Error _ as err -> Fut.return err

    let all2 a b = Infix_result_app.((fun a b -> (a, b)) <$> a <*> b)
    let all3 a b c = Infix_result_app.((fun a b c -> (a, b, c)) <$> a <*> b <*> c)
    let all4 a b c d = Infix_result_app.((fun a b c d -> (a, b, c, d)) <$> a <*> b <*> c <*> d)

    let all5 a b c d e =
      Infix_result_app.((fun a b c d e -> (a, b, c, d, e)) <$> a <*> b <*> c <*> d <*> e)

    let all6 a b c d e f =
      Infix_result_app.((fun a b c d e f -> (a, b, c, d, e, f)) <$> a <*> b <*> c <*> d <*> e <*> f)

    let all7 a b c d e f g =
      Infix_result_app.(
        (fun a b c d e f g -> (a, b, c, d, e, f, g)) <$> a <*> b <*> c <*> d <*> e <*> f <*> g)
  end
end
