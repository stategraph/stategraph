(** Some common combinators over futures. *)
module Make (Fut : Abb_intf.Future.S) : sig
  (** A future that has been determined to the unit value. *)
  val unit : unit Fut.t

  (** [return_ok v] is [Fut.return (Ok v)]: a future already determined to [Ok v]. A convenience for
      the pervasive [result]-in-future idiom. *)
  val return_ok : 'a -> ('a, 'b) result Fut.t

  (** [return_err e] is [Fut.return (Error e)]: a future already determined to [Error e]. A
      convenience for the pervasive [result]-in-future idiom. *)
  val return_err : 'b -> ('a, 'b) result Fut.t

  (** Take a future value, wait for it to be determined and throw the value away. *)
  val ignore : 'a Fut.t -> unit Fut.t

  (** Take a future value and do not wait for it to finish before evaluating *)
  val background : 'a Fut.t -> unit Fut.t

  (** Takes two futures and return a tuple where the first element is the determined value of the
      first future to become determined and the second element is the undetermined future. If both
      futures are determined, it is not defined which future will be which element of the tuple.

      If the call to [first] is aborted with [Fut.abort], the futures in the input are aborted as
      well. *)
  val first : 'a Fut.t -> 'a Fut.t -> ('a * 'a Fut.t) Fut.t

  (** Takes a list of futures and returns a tuple where the first element is the value of the first
      future to be determined and the second element is the list of undetermined futures remaining.
      It is guaranteed that the length of the remaining list is one less than the length of the
      input list. If more than one future is determined, which future is in the first element of the
      value is not guaranteed. The order of the futures in the returned list is undefined.

      If the call to [firstl] is aborted with [Fut.abort], all of the futures in the input list are
      aborted.

      {e Warning:} Do not use this for large lists. It is designed for small lists, and is intended
      to be used like a [select] function. *)
  val firstl : 'a Fut.t list -> ('a * 'a Fut.t list) Fut.t

  (** Takes a list of futures and returns a future of list of values. These values are guaranteed to
      be in the same order as the input list. The entire operation is failed if any of the futures
      fail due to an abort or exception. All futures are aborted on failure or abort. *)
  val all : 'a Fut.t list -> 'a list Fut.t

  val all2 : 'a Fut.t -> 'b Fut.t -> ('a * 'b) Fut.t
  val all3 : 'a Fut.t -> 'b Fut.t -> 'c Fut.t -> ('a * 'b * 'c) Fut.t
  val all4 : 'a Fut.t -> 'b Fut.t -> 'c Fut.t -> 'd Fut.t -> ('a * 'b * 'c * 'd) Fut.t

  val all5 :
    'a Fut.t -> 'b Fut.t -> 'c Fut.t -> 'd Fut.t -> 'e Fut.t -> ('a * 'b * 'c * 'd * 'e) Fut.t

  val all6 :
    'a Fut.t ->
    'b Fut.t ->
    'c Fut.t ->
    'd Fut.t ->
    'e Fut.t ->
    'f Fut.t ->
    ('a * 'b * 'c * 'd * 'e * 'f) Fut.t

  val all7 :
    'a Fut.t ->
    'b Fut.t ->
    'c Fut.t ->
    'd Fut.t ->
    'e Fut.t ->
    'f Fut.t ->
    'g Fut.t ->
    ('a * 'b * 'c * 'd * 'e * 'f * 'g) Fut.t

  (** Execute a function which returns a future. The [finally] function is executed:

      - If the function throws an exception.

      - If the Fut the function returns is successfully evaluated.

      - If the Fut is aborted or fails because of an exception.

      In all cases, the Fut is returned. In the case of the function throwing an exception, a Fut
      will be returned that has been failed with the exception.

      If [finally] throws an exception then the future is failed with that exception. In the case
      that the future had failed and calling [finally] throws an exception, the exception thrown by
      [finally] replaced the failure of the body and is propagated. *)
  val with_finally : (unit -> 'a Fut.t) -> finally:(unit -> unit Fut.t) -> 'a Fut.t

  (** Like {!with_finally} but it only execute the [failure] function if the future fails. A failure
      is one of the following:

      - If the function throws an exception,
      - If the Fut is aborted or fails because of an exception.

      In all cases a Fut is returned. In the case of an exception, a Fut is returned that has been
      failed with the exception.

      {b Note} it is undefined what happens if [finally] throws an exception or fails. *)
  val on_failure : (unit -> 'a Fut.t) -> failure:(unit -> unit Fut.t) -> 'a Fut.t

  (** Executes a future such that it is protected from any abort operation. The future returned from
      this may still be aborted, however the work it is protecting will be executed to completion.
  *)
  val protect : (unit -> 'a Fut.t) -> 'a Fut.t

  (** Execute a [setup] phase that is protected, if the operation has been terminated due to an
      [abort] or exception, then execute [finally], otherwise execute the body in an unprotected
      section. [finally] is executed on completion. *)
  val protect_finally :
    setup:(unit -> 'a Fut.t) -> finally:('a -> unit Fut.t) -> ('a -> 'b Fut.t) -> 'b Fut.t

  (** [tap f fut] returns a future that propagates [fut]'s outcome unchanged -- its determined
      value, its exception, or its abort -- while calling [f] with that outcome as it passes
      through. [f] is a pure observer: it cannot alter what propagates. An abort of the returned
      future is propagated down to [fut]. [f] must not raise. *)
  val tap : ('a Abb_intf.Future.Set.t -> unit) -> 'a Fut.t -> 'a Fut.t

  (** Link two futures together. If one is aborted or fails the other one will be aborted or failed.
  *)
  val link : 'a Fut.t -> 'b Fut.t -> unit

  (** Given a future, return a future containing a result that is always successful. *)
  val to_result : 'a Fut.t -> ('a, 'b) result Fut.t

  (** Given an option containing a future, return a future containing an option. *)
  val of_option : 'a Fut.t option -> 'a option Fut.t

  (** Perform an operation with a cancel future. If the cancel future is determined first, the work
      is cancelled, if the work completes first the cancel future is cancelled. *)
  val with_cancel : cancel:unit Fut.t -> 'a Fut.t -> ('a, [> `Cancelled ]) result Fut.t

  (** Wait for a future to complete and if it does not in a specified time, abort it *)
  val timeout : timeout:unit Fut.t -> 'a Fut.t -> [ `Ok of 'a | `Timeout ] Fut.t

  (** Loop [f], threading a state through the iterations. [f] is applied to [init], and to the state
      each subsequent iteration returns, so a loop that accumulates needs no mutable variable. Every
      iteration produces a state paired with a value; that pair is what [while_] tests, what
      [betwixt] runs against, and what the loop returns once [while_] says to stop -- so the final
      state is available to the caller, not just the last value. Since the pair is a single
      argument, {!finite_tries} composes with [while_] here exactly as it does with {!retry}.
      Exceptions are not handled as part of the loop. *)
  val while_ :
    init:'s ->
    f:('s -> ('s * 'a) Fut.t) ->
    while_:('s * 'a -> bool) ->
    betwixt:('s * 'a -> unit Fut.t) ->
    ('s * 'a) Fut.t

  (** Perform an operation [f], and call [while_] on the result. If [while_] returns [true] it means
      to try again. If [false] then return the value. Otherwise run a function [betwixt] between
      runs and then call [f] again. Exceptions are not handled as part of the retry process.

      This is {!while_} with no state to thread. *)
  val retry : f:(unit -> 'a Fut.t) -> while_:('a -> bool) -> betwixt:('a -> unit Fut.t) -> 'a Fut.t

  (** Try, at most, the number of [tries] given. If there are remaining tries, call the test
      function which corresponds to the [while_] in the {!retry} function. *)
  val finite_tries : int -> ('a -> bool) -> 'a -> bool

  (** Given a [start] value and a [step] function, and a function which takes the current value in
      the series and another value, call it when given a new value and return the result of the
      function. Every call with a value will increment the series value by [step] *)
  val series : start:'a -> step:('a -> 'a) -> ('a -> 'b -> 'c Fut.t) -> 'b -> 'c Fut.t

  (** Given an exception, create a failed future with that exception. *)
  val of_exn : exn -> 'a Fut.t

  (** Execute a function that runs a future where the execution may raise an exception. If an
      exception is raised, catch the exception and return a failed future. *)
  val guard : (unit -> 'a Fut.t) -> 'a Fut.t

  (** [when_ b f] runs [f ()] if [b] is [true], otherwise returns a future determined to [()].
      Equivalent to Haskell's
      {{:https://hackage.haskell.org/package/base/docs/Control-Monad.html#v:when}
       [Control.Monad.when]}. *)
  val when_ : bool -> (unit -> unit Fut.t) -> unit Fut.t

  (** [when_m mb f] runs [f ()] if [mb] determines to [true], otherwise returns a future determined
      to [()]. Equivalent to Haskell's
      {{:https://hackage-content.haskell.org/package/extra-1.8.1/docs/Control-Monad-Extra.html#v:whenM}
       [whenM]}. *)
  val when_m : bool Fut.t -> (unit -> unit Fut.t) -> unit Fut.t

  module List : sig
    (** Map a list in serial *)
    val map : f:('a -> 'b Fut.t) -> 'a list -> 'b list Fut.t

    (** Map a list performing each operation in parallel. Every item in the list is executed
        concurrently. *)
    val map_par : f:('a -> 'b Fut.t) -> 'a list -> 'b list Fut.t

    val fold_left : f:('a -> 'b -> 'a Fut.t) -> init:'a -> 'b list -> 'a Fut.t

    (** Iterate a list of values executing a function in serial. *)
    val iter : f:('a -> unit Fut.t) -> 'a list -> unit Fut.t

    (** Iterate a list of values executing a function in parallel. *)
    val iter_par : f:('a -> unit Fut.t) -> 'a list -> unit Fut.t

    val filter : f:('a -> bool Fut.t) -> 'a list -> 'a list Fut.t
    val filter_map : f:('a -> 'b option Fut.t) -> 'a list -> 'b list Fut.t
  end

  module List_result : sig
    val map : f:('a -> ('b, 'e) result Fut.t) -> 'a list -> ('b list, 'e) result Fut.t

    val fold_left :
      f:('a -> 'b -> ('a, 'e) result Fut.t) -> init:'a -> 'b list -> ('a, 'e) result Fut.t

    val iter : f:('a -> (unit, 'e) result Fut.t) -> 'a list -> (unit, 'e) result Fut.t
    val filter : f:('a -> (bool, 'e) result Fut.t) -> 'a list -> ('a list, 'e) result Fut.t
    val filter_map : f:('a -> ('b option, 'e) result Fut.t) -> 'a list -> ('b list, 'e) result Fut.t
  end

  module Infix_result_monad : sig
    type ('a, 'b) t = ('a, 'b) result Fut.t

    val ( >>= ) : ('a, 'c) t -> ('a -> ('b, 'c) t) -> ('b, 'c) t
    val ( >>| ) : ('a, 'c) t -> ('a -> 'b) -> ('b, 'c) t

    (** [t >>? f] runs [f] on the [Ok] value of [t], flattening the [result] it returns into the
        error channel, so [f] may turn an [Ok] into an [Error] without a further asynchronous step.
        If [t] determines to [Error], [f] is not called and the error propagates unchanged. Like
        {!(>>=)}, but the continuation stays in the [result] monad rather than returning a future;
        the analogue of [Lwt_result.bind_result]. Contrast {!(>>|)}, whose continuation cannot fail.
    *)
    val ( >>? ) : ('a, 'c) t -> ('a -> ('b, 'c) result) -> ('b, 'c) t

    (** [when_ b f] runs [f ()] if [b] is [true], otherwise returns a future determined to [Ok ()].
        Equivalent to Haskell's
        {{:https://hackage.haskell.org/package/base/docs/Control-Monad.html#v:when}
         [Control.Monad.when]}. *)
    val when_ : bool -> (unit -> (unit, 'c) t) -> (unit, 'c) t

    (** [when_m mb f] runs [f ()] if [mb] determines to [Ok true], otherwise returns a future
        determined to [Ok ()] (or propagates the [Error]). Equivalent to Haskell's
        {{:https://hackage-content.haskell.org/package/extra-1.8.1/docs/Control-Monad-Extra.html#v:whenM}
         [whenM]}. *)
    val when_m : (bool, 'c) t -> (unit -> (unit, 'c) t) -> (unit, 'c) t
  end

  (** Applicative for result types. Execute all futures and execute the given function or return the
      error value of the first future to evaluate to [Error _]. The results of any successes are
      discarded. In the case of a future evaluating to [Error _], the other futures are NOT aborted.
  *)
  module Infix_result_app : sig
    type ('a, 'b) t = ('a, 'b) result Fut.t

    val ( <$> ) : ('a -> 'b) -> ('a, 'c) t -> ('b, 'c) t
    val ( <*> ) : ('a -> 'b, 'c) t -> ('a, 'c) t -> ('b, 'c) t
  end

  module Result : sig
    (** For a future that returns a result, map the error to a new value *)
    val map_err : f:('b -> 'c) -> ('a, 'b) result Fut.t -> ('a, 'c) result Fut.t

    (** Take a future result value, wait for it to be determined and throw the Ok value away, while
        maintaing the Error. *)
    val ignore : ('a, 'b) result Fut.t -> (unit, 'b) result Fut.t

    val all2 : ('a, 'e) result Fut.t -> ('b, 'e) result Fut.t -> ('a * 'b, 'e) result Fut.t

    val all3 :
      ('a, 'e) result Fut.t ->
      ('b, 'e) result Fut.t ->
      ('c, 'e) result Fut.t ->
      ('a * 'b * 'c, 'e) result Fut.t

    val all4 :
      ('a, 'e) result Fut.t ->
      ('b, 'e) result Fut.t ->
      ('c, 'e) result Fut.t ->
      ('d, 'e) result Fut.t ->
      ('a * 'b * 'c * 'd, 'e) result Fut.t

    val all5 :
      ('a, 'err) result Fut.t ->
      ('b, 'err) result Fut.t ->
      ('c, 'err) result Fut.t ->
      ('d, 'err) result Fut.t ->
      ('e, 'err) result Fut.t ->
      ('a * 'b * 'c * 'd * 'e, 'err) result Fut.t

    val all6 :
      ('a, 'err) result Fut.t ->
      ('b, 'err) result Fut.t ->
      ('c, 'err) result Fut.t ->
      ('d, 'err) result Fut.t ->
      ('e, 'err) result Fut.t ->
      ('f, 'err) result Fut.t ->
      ('a * 'b * 'c * 'd * 'e * 'f, 'err) result Fut.t

    val all7 :
      ('a, 'err) result Fut.t ->
      ('b, 'err) result Fut.t ->
      ('c, 'err) result Fut.t ->
      ('d, 'err) result Fut.t ->
      ('e, 'err) result Fut.t ->
      ('f, 'err) result Fut.t ->
      ('g, 'err) result Fut.t ->
      ('a * 'b * 'c * 'd * 'e * 'f * 'g, 'err) result Fut.t
  end
end
