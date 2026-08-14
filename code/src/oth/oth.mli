(** {1 Assertions}

    Assertions are pure and synchronous: they either return a value or raise, and the raise is
    caught by whichever backend's [catch] is running the test. They are therefore backend-
    independent and live OUTSIDE {!S}, so {!Make} does not expose them.

    The vocabulary is named as a signature rather than only bound as a module so that a backend can
    EXTEND it instead of redeclaring it: {!Oth_abb.ASSERT} is [ASSERT] plus the assertions that name
    an [Abb_intf] type, which keeps this library free of a dependency on [abb_intf]. An async test
    can therefore reach every assertion through one module path, [Oth_abb.Assert.*], while a
    synchronous one uses [Oth.Assert.*]; the two share this implementation. *)
module type ASSERT = sig
  (** Asserts that a result is [Ok v] and returns [v], otherwise prints the given message and fails
      the test. *)
  val ok : ?fail_msg:string -> ('a, 'err) result -> 'a

  (** Asserts that a result is [Ok v] and returns [v], otherwise prints the error and fails the
      test. *)
  val ok_pp : pp:(Format.formatter -> 'err -> unit) -> ('a, 'err) result -> 'a

  (** Asserts that a result is [Error v] and returns [v], otherwise prints the given message and
      fails the test. *)
  val error : ?fail_msg:string -> ('a, 'err) result -> 'err

  (** Asserts that a result is [Error v] and returns [v], otherwise prints the error and fails the
      test. *)
  val error_pp : pp:(Format.formatter -> 'a -> unit) -> ('a, 'err) result -> 'err

  (** Asserts that an option is [Some v] and returns [v], otherwise prints a message and fails the
      test. *)
  val some : ?fail_msg:string -> 'a option -> 'a

  (** Asserts that an option is [None], otherwise prints the message and fails the test. *)
  val none : ?fail_msg:string -> 'a option -> unit

  (** Asserts that an option is [None], otherwise prints the unexpected value with [pp] and fails
      the test. *)
  val none_pp : pp:(Format.formatter -> 'a -> unit) -> 'a option -> unit

  (** Asserts that two values are equal based on a provided equality function [eq], otherwise prints
      both values and fails the test. *)
  val eq : eq:('a -> 'a -> bool) -> pp:(Format.formatter -> 'a -> unit) -> 'a -> 'a -> unit

  (** Asserts that the value is [true], otherwise fails the test displaying [msg]. *)
  val true_ : string -> bool -> unit

  (** Asserts that the value is [false], otherwise fails the test displaying [msg]. Distinct from
      {!false_}, which asserts nothing and always fails: this one takes the value to check. *)
  val not_true : string -> bool -> unit

  (** Fails the test, displaying [msg] *)
  val false_ : string -> 'a

  (** Asserts that [haystack] contains the substring [needle], otherwise fails the test. *)
  val str_contains : haystack:string -> needle:string -> unit

  (** Asserts that [haystack] contains every substring in [needles], otherwise fails the test on the
      first one that is missing. *)
  val str_contains_all : haystack:string -> needles:string list -> unit

  (** Asserts that [haystack] does not contain the substring [needle], otherwise fails the test. *)
  val str_doesnt_contain : haystack:string -> needle:string -> unit

  module List : sig
    (** Asserts that the list has the [expected] length, otherwise fails the test. *)
    val length : expected:int -> 'a list -> unit

    (** Asserts that the list has exactly one element and returns it, otherwise fails the test. *)
    val length_one : 'a list -> 'a

    (** Asserts that the list is non-empty and return the first element, otherwise fails the test.
    *)
    val non_empty : 'a list -> 'a

    (** Asserts that the list is empty, otherwise fails the test. *)
    val empty : 'a list -> unit
  end

  module Eq : sig
    (** Asserts that two strings are equal. *)
    val string : expected:string -> actual:string -> unit

    (** Asserts that two ints are equal. *)
    val int : expected:int -> actual:int -> unit

    (** Asserts that two bools are equal. *)
    val bool : expected:bool -> actual:bool -> unit

    (** Asserts that two option values are equal, using the given equality and pretty-printer for
        the underlying type. *)
    val option :
      eq:('a -> 'a -> bool) ->
      pp:(Format.formatter -> 'a -> unit) ->
      expected:'a option ->
      actual:'a option ->
      unit

    (** Asserts that two string options are equal. *)
    val string_option : expected:string option -> actual:string option -> unit

    (** Asserts that two lists are equal, element by element. On failure, reports each differing
        item with its index, and flags extra or missing items, making it easy to spot which element
        is wrong. *)
    val list :
      eq:('a -> 'a -> bool) ->
      pp:(Format.formatter -> 'a -> unit) ->
      expected:'a list ->
      actual:'a list ->
      unit

    (** Asserts that two string lists are equal. *)
    val string_list : expected:string list -> actual:string list -> unit

    (** Asserts that two int lists are equal. *)
    val int_list : expected:int list -> actual:int list -> unit

    (** Asserts that two bool lists are equal. *)
    val bool_list : expected:bool list -> actual:bool list -> unit
  end

  module String : sig
    (** Asserts that the string is empty, otherwise fails the test. *)
    val empty : string -> unit

    (** Asserts that [haystack] does not contain any member of [needles], otherwise fails the test.
    *)
    val doesnt_contain_any : haystack:string -> needles:string list -> unit
  end
end

module Assert : ASSERT

module Diff : sig
  (** Function used in regression tests, to check that [actual_content] is equal to the content of
      the file at [expected_file_path]. The intended use is that [expected_file_path] is a versioned
      "expected output" file, and [actual_content] is the output generated by the test. If they
      differ, this means something unexpected changed, and the test fails.

      To make it easy to regenerate expected output files when code changes cause a regresson, set
      the environment variable [OTH_CREATE_EXPECTED_FILES] to "1". In that case, this function
      writes [actual_content] to [expected_file_path], instead of checking anything. *)
  val check : tmp_dir_name:string -> expected_file_path:string -> actual_content:string -> unit
end

(** Tag-filtering helpers shared by the runner and by callers that want to predict the runner's
    selection (e.g. to skip an expensive per-phase setup when every test of that phase is filtered
    out). *)
module Tag : sig
  (** Whether a test carrying [tags] would run under the current [OTH_TAGS] / [OTH_EXCLUDE_TAGS]
      environment -- exactly the filter the runner applies to each test. Combine with
      {!S.collect_tags} to predict a run's selection. *)
  val should_run_env : tags:string list -> bool
end

module type T = sig
  type +'a t

  (** Per-run backend state created once at the start of a test run (via [create_state]) and
      threaded through to every [run_test] call. Examples: the synchronous backend has no state
      (uses [unit]); the Abb backend holds a single [Abb_bounded_executor.t] here. *)
  type state

  val return : 'a -> 'a t
  val bind : 'a t -> ('a -> 'b t) -> 'b t

  (** [catch f h] runs [f ()]; if [f] raises synchronously or the resulting monadic value fails with
      an exception, [h] is called with that exception and an optional backtrace. *)
  val catch : (unit -> 'a t) -> (exn * Printexc.raw_backtrace option -> 'a t) -> 'a t

  (** Build the single piece of backend state that lives for one run. Called exactly once by
      [Make(T).run]. *)
  val create_state : unit -> state t

  (** [run_test state ~name f] runs a single leaf test body through the backend's bounded executor
      (if any). For the synchronous backend this is just [f ()]; for the Abb backend it acquires a
      slot on the shared [Abb_bounded_executor.t] for the duration of [f]. *)
  val run_test : state -> name:string -> (unit -> 'a t) -> 'a t

  (** [parallel xs] runs every thunk in [xs] concurrently and collects the results in input order.
      This is a pure combinator — it does not itself consume any executor slot, so combinators can
      nest arbitrarily without deadlocking against the slot bound. Only [run_test] consumes slots.
  *)
  val parallel : (unit -> 'a t) list -> 'a list t

  (** Drive a top-level monadic action to completion. The synchronous backend simply applies [f];
      the Abb backend spins up [Abb.Scheduler.run_with_state] and translates the result — logging
      and exiting 1 on [`Exn]/[`Aborted]. Called once by [Make(T).run]. *)
  val run_suite : (unit -> unit t) -> unit
end

module type S = sig
  type +'a m

  module Test : sig
    type t
  end

  (** A phase pairs its own [setup]/[teardown] with a subtree of tests, for suites whose test groups
      need distinct lifecycles (e.g. boot a differently-configured server per group). Phases run
      serially in list order under {!run_phases}: a phase's [teardown] completes before the next
      phase's [setup] starts. *)
  module Phase : sig
    type 'g t

    (** [setup] receives the value produced by the run-level [setup] given to {!run_phases}. On
        [Error msg] the run stops (remaining phases never start) and the process exits 1; [teardown]
        runs after the phase's tests complete, whether or not any test failed. *)
    val make :
      name:string ->
      setup:('g -> ('a, string) result m) ->
      teardown:('a -> unit m) ->
      ('a -> Test.t) ->
      'g t
  end

  val parallel : Test.t list -> Test.t
  val serial : Test.t list -> Test.t
  val loop : int -> Test.t -> Test.t

  (** Invert a test's outcome: it passes when the wrapped test FAILS, and fails when it passes.

      For a KNOWN GAP — behaviour that is specified but does not work yet. Write the test asserting
      what the code SHOULD do, wrap it here, and the suite stays green while the gap is open. The
      specification then lives in the assertions rather than in a comment, and the day the behaviour
      starts working this fails and tells you to remove the wrapper. The alternatives are worse: a
      test that asserts the DEFECT encodes the wrong thing and has to be rewritten to close the gap,
      and a permanently-red test becomes noise nobody reads.

      [~reason] is quoted in that failure message; say what the gap was.

      [OTH_DISABLE_EXPECT_FAILURE=1] disables the inversion, so a run reports what each test
      ACTUALLY did. Use it to see the true state: which gaps are still open, and — the case
      inversion hides — a gap that has started passing for the WRONG reason, because its fixture
      broke or its assertions stopped reaching the interesting code. A suite of wrapped tests is
      uniformly green either way, so that variable is the only way to tell those apart.

      [`Timedout] and [`Skipped] are NOT inverted. A timeout is not evidence the expected assertion
      failed, only that the test never reached it; a skip means tag filtering excluded the body, and
      inverting it would manufacture a pass. *)
  val expect_failure : ?reason:string -> Test.t -> Test.t

  val timeout : Duration.t -> Test.t -> Test.t
  val test : ?tags:string list -> ?desc:string -> name:string -> (unit -> unit m) -> Test.t

  (** Run a test suite. [setup] runs once before the test tree is built; on [Ok v] its value is
      threaded into the producer [f] and into [teardown], on [Error msg] no tests run -- the message
      is printed and the process exits 1. [teardown] runs after tests complete. Exceptions from
      tests or [teardown] are surfaced by the backend's [run_suite] (exit 1 for the Abb backend).
      Drives the scheduler itself via [T.run_suite] and returns [unit] so Cmdliner terms can call it
      directly.

      Pass [fun () -> return (Ok ())] / [fun _ -> return ()] if a suite needs no lifecycle. *)
  val run :
    file:string ->
    setup:(unit -> ('a, string) result m) ->
    teardown:('a -> unit m) ->
    ('a -> Test.t) ->
    unit

  (** Run a multi-phase suite. The run-level [setup]/[teardown] bracket the whole run, as in {!run};
      each phase's own [setup]/[teardown] bracket that phase's tests, and phases run serially in
      list order. Results from all phases aggregate into the single TAP/summary output. A failed
      run-level or phase setup prints the message and exits 1 (the run-level [teardown] still runs
      when a phase setup fails, and completed phases' teardowns have already run). {!run} is
      [run_phases] with a single lifecycle-less phase. *)
  val run_phases :
    file:string ->
    setup:(unit -> ('g, string) result m) ->
    teardown:('g -> unit m) ->
    'g Phase.t list ->
    unit

  (** Evaluate [Test.t] without running any test body, returning each leaf test's full tag list --
      the same tags the runner filters on ([default], the test name, declared tags, and tags derived
      from [file], which must be the same value later given to {!run}/{!run_phases}). Combine with
      {!Tag.should_run_env} to predict which tests a run would execute, e.g. to skip booting a
      phase's server when the whole phase is filtered out. *)
  val collect_tags : file:string -> Test.t -> string list list m
end

module Make (T : T) : S with type 'a m = 'a T.t

(** {1 Synchronous default}

    [Oth] bundles a sync instance for tests that don't need an async backend. It matches {!Oth}
    semantics minus the Domainslib pool — [parallel] runs sequentially. *)
include S with type 'a m = 'a
