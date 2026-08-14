let src = Logs.Src.create "oth"

module Logs = (val Logs.src_log src : Logs.LOG)

(* The carrier for a failed assertion. Deliberately OUTSIDE [Assert] and absent from oth.mli:
   callers may only raise it, never match on it, and keeping it out of the module means
   [module type of Assert] is exactly the assertion vocabulary -- which is what lets oth.mli name
   it as [ASSERT] and oth_abb extend that rather than redeclare it. *)
exception Assert_failure_msg of string

module Assert = struct
  let ok ?fail_msg r =
    match r with
    | Ok v -> v
    | Error _ ->
        raise (Assert_failure_msg (CCOption.get_or ~default:"Expected Ok, got Error" fail_msg))

  let ok_pp ~pp r =
    match r with
    | Ok v -> v
    | Error e -> raise (Assert_failure_msg (Format.asprintf "Expected Ok (_), got Error:\n%a" pp e))

  let error ?fail_msg r =
    match r with
    | Ok _ ->
        raise (Assert_failure_msg (CCOption.get_or ~default:"Expected Error, got Ok" fail_msg))
    | Error e -> e

  let error_pp ~pp r =
    match r with
    | Ok v -> raise (Assert_failure_msg (Format.asprintf "Expected Error (_), got Ok:\n%a" pp v))
    | Error e -> e

  let some ?fail_msg opt =
    match opt with
    | Some v -> v
    | None ->
        raise (Assert_failure_msg (CCOption.get_or ~default:"Expected Some, got None" fail_msg))

  let none ?fail_msg opt =
    match opt with
    | None -> ()
    | Some _ ->
        raise (Assert_failure_msg (CCOption.get_or ~default:"Expected None, got Some" fail_msg))

  let none_pp ~pp opt =
    match opt with
    | None -> ()
    | Some v -> raise (Assert_failure_msg (Format.asprintf "Expected None, got Some:@.@[%a@]" pp v))

  let eq ~eq ~pp expected actual =
    if not (eq expected actual) then
      raise
        (Assert_failure_msg
           (Format.asprintf "Expected:@.@[%a@]@.Got:@.@[%a@]" pp expected pp actual))

  let true_ msg v = if not v then raise (Assert_failure_msg msg)
  let not_true msg v = if v then raise (Assert_failure_msg msg)
  let false_ msg = raise (Assert_failure_msg msg)

  let str_contains ~haystack ~needle =
    if not (CCString.find ~sub:needle haystack >= 0) then
      raise
        (Assert_failure_msg
           (Format.asprintf
              "Expected HAYSTACK to contain NEEDLE, but it doesn't! See \
               below.@.HAYSTACK:@.%s@.NEEDLE:@.%s"
              haystack
              needle))

  let str_contains_all ~haystack ~needles =
    CCList.iter (fun needle -> str_contains ~haystack ~needle) needles

  let str_doesnt_contain ~haystack ~needle =
    if CCString.find ~sub:needle haystack >= 0 then
      raise
        (Assert_failure_msg
           (Format.asprintf
              "Expected HAYSTACK to not contain NEEDLE, but it does! See \
               below.@.HAYSTACK:@.%s@.NEEDLE:@.%s"
              haystack
              needle))

  module List = struct
    let length ~expected l =
      let actual = CCList.length l in
      if actual <> expected then
        raise
          (Assert_failure_msg (Format.asprintf "Expected list of length %d, got %d" expected actual))

    let length_one = function
      | [ x ] -> x
      | l ->
          raise
            (Assert_failure_msg
               (Format.asprintf "Expected list of length 1, got %d" (CCList.length l)))

    let non_empty = function
      | [] -> raise (Assert_failure_msg "Expected list to be non-empty, got empty list")
      | x :: _ -> x

    let empty l =
      if not (CCList.is_empty l) then
        false_
          (Format.asprintf "Expected list to be empty, got list of length %d" (CCList.length l))
  end

  module Eq = struct
    let string ~expected ~actual = eq ~eq:String.equal ~pp:Format.pp_print_string expected actual
    let int ~expected ~actual = eq ~eq:Int.equal ~pp:Format.pp_print_int expected actual
    let bool ~expected ~actual = eq ~eq:Bool.equal ~pp:Format.pp_print_bool expected actual

    let option ~eq:eq_inner ~pp:pp_inner ~expected ~actual =
      let eq_opt = CCOption.equal eq_inner in
      let pp_opt fmt = function
        | Some v -> Format.fprintf fmt "Some(%a)" pp_inner v
        | None -> Format.fprintf fmt "None"
      in
      eq ~eq:eq_opt ~pp:pp_opt expected actual

    let string_option ~expected ~actual =
      option ~eq:String.equal ~pp:Format.pp_print_string ~expected ~actual

    let list ~eq:eq_item ~pp:pp_item ~expected ~actual =
      if not (CCList.equal eq_item expected actual) then (
        let buf = Buffer.create 256 in
        let fmt = Format.formatter_of_buffer buf in
        let n_exp = CCList.length expected in
        let n_act = CCList.length actual in
        let n_common = min n_exp n_act in
        (* Compare common items *)
        for i = 0 to n_common - 1 do
          let e = CCList.nth expected i in
          let a = CCList.nth actual i in
          if not (eq_item e a) then
            Format.fprintf
              fmt
              "Item %d differs:@.  expected: %a@.  got:      %a@."
              i
              pp_item
              e
              pp_item
              a
        done;
        (* Report length difference with the extra/missing items *)
        if n_exp <> n_act then (
          let label, n_diff, items =
            if n_act > n_exp then ("extra", n_act - n_exp, actual)
            else ("missing", n_exp - n_act, expected)
          in
          Format.fprintf fmt "%d %s item(s) (expected %d, got %d):@." n_diff label n_exp n_act;
          for i = n_common to CCList.length items - 1 do
            Format.fprintf fmt "  [%d]: %a@." i pp_item (CCList.nth items i)
          done);
        Format.pp_print_flush fmt ();
        raise (Assert_failure_msg (Buffer.contents buf)))

    let string_list = list ~eq:CCString.equal ~pp:Format.pp_print_string
    let int_list = list ~eq:Int.equal ~pp:Format.pp_print_int
    let bool_list = list ~eq:Bool.equal ~pp:Format.pp_print_bool
  end

  module String = struct
    let empty s =
      if not (CCString.is_empty s) then
        false_ (Format.asprintf "Expected string to be empty, but got: %s" s)

    let doesnt_contain_any ~haystack ~needles =
      CCList.iter (fun needle -> str_doesnt_contain ~haystack ~needle) needles
  end
end

module type ASSERT = module type of Assert

module Diff = struct
  let diff_files ~expected_file_path ~actual_file_path =
    let command = Printf.sprintf "diff -u %s %s" expected_file_path actual_file_path in
    match Sys.command command with
    | 0 -> ()
    | _ ->
        print_endline
          (Format.sprintf
             {|Output does not match expected. Run the following command to see the diff:
diff -u %s %s
To regenerate the expected files, run the test with OTH_CREATE_EXPECTED_FILES=1.|}
             expected_file_path
             actual_file_path);
        assert false

  let check ~tmp_dir_name ~expected_file_path ~actual_content =
    if String.equal (CCOption.get_or ~default:"0" (Sys.getenv_opt "OTH_CREATE_EXPECTED_FILES")) "1"
    then CCIO.with_out expected_file_path (fun oc -> output_string oc actual_content)
    else
      let tmp_dir = Filename.temp_dir (tmp_dir_name ^ "-") "-XXX" in
      let actual_file_path = Filename.concat tmp_dir "actual.txt" in
      CCIO.with_out actual_file_path (fun oc -> output_string oc actual_content);
      diff_files ~expected_file_path ~actual_file_path
end

module type T = sig
  type +'a t
  type state

  val return : 'a -> 'a t
  val bind : 'a t -> ('a -> 'b t) -> 'b t
  val catch : (unit -> 'a t) -> (exn * Printexc.raw_backtrace option -> 'a t) -> 'a t
  val create_state : unit -> state t

  (** Run a single leaf test body through the backend's bounded executor (if any). The [name] is
      used by the executor for logging / accounting. *)
  val run_test : state -> name:string -> (unit -> 'a t) -> 'a t

  (** Combinator: run every thunk concurrently and collect the results in input order. Has no
      backend state and does not hold any executor resource itself — only [run_test] does. *)
  val parallel : (unit -> 'a t) list -> 'a list t

  (** Drive a top-level monadic action to completion. The synchronous backend simply applies [f];
      the Abb backend spins up its scheduler and translates the result. *)
  val run_suite : (unit -> unit t) -> unit
end

module Tag = struct
  module Set = CCSet.Make (CCString)

  let default = "default"

  let file_dir_tags file =
    let parts = CCString.split_on_char '/' file in
    let rec drop_prefix = function
      | [] -> []
      | ("src" | "tests") :: rest -> rest
      | _ :: rest -> drop_prefix rest
    in
    drop_prefix parts

  let of_env_opt env_name =
    match Sys.getenv_opt env_name with
    | Some s when CCString.length (CCString.trim s) > 0 ->
        let tags_list =
          s
          |> CCString.trim
          |> CCString.Split.list_cpy ~by:" "
          |> CCList.filter (fun s -> not (CCString.is_empty s))
        in
        Some (Set.of_list tags_list)
    | Some _ | None -> None

  let should_run ~include_tags ~exclude_tags ~tags =
    let tag_set = Set.of_list tags in
    let included =
      match include_tags with
      | None -> true
      | Some inc -> not (Set.is_empty (Set.inter tag_set inc))
    in
    let excluded =
      match exclude_tags with
      | None -> false
      | Some exc -> not (Set.is_empty (Set.inter tag_set exc))
    in
    included && not excluded

  let should_run_env ~tags =
    let include_tags = of_env_opt "OTH_TAGS" in
    let exclude_tags = of_env_opt "OTH_EXCLUDE_TAGS" in
    should_run ~include_tags ~exclude_tags ~tags
end

module State = struct
  (* How the runner evaluates each leaf [test]: [Run] executes it (subject to the tag filter),
     [Print_tags] prints its tags instead (OTH_PRINT_TAGS), [Collect] skips the body so that
     only the tags carried by the result matter (backing [collect_tags]). *)
  type mode =
    | Run
    | Print_tags
    | Collect

  type t = {
    file_dir_tags : string list;
    mode : mode;
  }

  let create ~mode ~file () =
    let file_dir_tags = Tag.file_dir_tags file in
    { file_dir_tags; mode }

  let file_dir_tags t = t.file_dir_tags
  let mode t = t.mode
end

let all_tags ~name ~tags state = (Tag.default :: name :: tags) @ State.file_dir_tags state

let print_test_tags ~tags =
  Printf.printf "%s\n" (CCString.concat " " (CCList.sort CCString.compare tags))

module Test_result = struct
  type t = {
    name : string;
    desc : string option;
    tags : string list;
    duration : Duration.t;
    res : [ `Ok | `Exn of exn * Printexc.raw_backtrace option | `Timedout | `Skipped ];
  }
end

(* Raised by {!expect_failure} when the wrapped test passed, i.e. the gap it guards has closed. Its
   own exception rather than a generic [Failure] so the message reads as the instruction it is, and
   so a reader grepping for it finds the combinator. *)
exception Expect_failure_passed of string

(* [exn] is extensible, so a printer must have a catch-all -- this is the one place a wildcard is not
   a shortcut. *)
let () =
  Printexc.register_printer (function
    | Expect_failure_passed msg -> Some msg
    (* Without this, the default printer renders the payload with %S-style escaping, so an
       assertion's carefully formatted multi-line "Expected: ... Got: ..." collapses into one
       quoted line with literal \n, and [basic_tap]'s "# Exn:" line-splitter has nothing to split
       on.  A printer rather than a case in [Outputter_impl.string_of_exn] because
       [Printexc.to_string] is also what the per-test debug log and the Abb backend's
       suite-failure log use. *)
    | Assert_failure_msg msg -> Some msg
    | _ -> None)

module Outputter_impl = struct
  let string_of_exn exn = Printexc.to_string exn

  let basic_stdout =
    CCList.iter (fun tr ->
        match tr.Test_result.res with
        (* Skipped tests are intentionally silent on stdout: with many tag
           filters in play the per-test SKIPPED lines drown out the actual
           result.  The summary line printed by [run] still reports the
           total skipped count, and [basic_tap] continues to emit `ok N ...
           # SKIP tag filtered` so the TAP aggregator's view is unchanged. *)
        | `Skipped -> ()
        | `Timedout -> Printf.printf "Test: %s\t\tTIMEDOUT\n" tr.Test_result.name
        | `Ok ->
            Printf.printf
              "Test: %s\t\tPASSED (%0.02f sec)\n"
              tr.Test_result.name
              (Duration.to_f tr.Test_result.duration)
        | `Exn (exn, bt_opt) ->
            Printf.printf
              "Test: %s\t\tFAILED (%0.02f sec)\n"
              tr.Test_result.name
              (Duration.to_f tr.Test_result.duration);
            CCOption.iter (Printf.printf "Description: %s\n") tr.Test_result.desc;
            Printf.printf "Exn: %s\n" (string_of_exn exn);
            CCOption.iter
              (Printf.printf "Backtrace: %s\n")
              (CCOption.map Printexc.raw_backtrace_to_string bt_opt))

  let basic_tap out rr =
    let oc, close =
      match out with
      | `Filename s -> (open_out s, close_out)
      | `Out_channel oc -> (oc, CCFun.const ())
    in
    let num_tests = CCList.length rr in
    let start_test = 1 in
    let end_test = num_tests in
    Printf.fprintf oc "%d..%d\n" start_test end_test;
    let rec output_test n = function
      | [] -> ()
      | tr :: trs ->
          assert (n <= end_test);
          (match tr.Test_result.res with
          | `Ok ->
              Printf.fprintf
                oc
                "ok %d %s\n# Elapsed %0.02f sec\n"
                n
                tr.Test_result.name
                (Duration.to_f tr.Test_result.duration)
          | `Skipped -> Printf.fprintf oc "ok %d %s # SKIP tag filtered\n" n tr.Test_result.name
          | `Timedout ->
              Printf.fprintf
                oc
                "not ok %d %s\n# Elapsed %0.02f sec\n"
                n
                tr.Test_result.name
                (Duration.to_f tr.Test_result.duration);
              Printf.fprintf oc "# TIMEDOUT\n"
          | `Exn (exn, bt_opt) ->
              Printf.fprintf
                oc
                "not ok %d %s\n# Elapsed %0.02f sec\n"
                n
                tr.Test_result.name
                (Duration.to_f tr.Test_result.duration);
              Printf.fprintf
                oc
                "# Description: %s\n"
                (CCString.replace
                   ~which:`All
                   ~sub:"\n"
                   ~by:"\n# "
                   (CCOption.get_or ~default:"" tr.Test_result.desc));
              Printf.fprintf
                oc
                "# Exn: %s\n"
                (CCString.replace ~which:`All ~sub:"\n" ~by:"\n# " (string_of_exn exn));
              Printf.fprintf
                oc
                "# Backtrace: %s\n"
                (CCString.replace
                   ~which:`All
                   ~sub:"\n"
                   ~by:"\n# "
                   (CCOption.get_or
                      ~default:""
                      (CCOption.map Printexc.raw_backtrace_to_string bt_opt))));
          output_test (n + 1) trs
    in
    output_test start_test rr;
    close oc

  let of_env ?(default = []) env_name outputter_map rr =
    let outputters =
      let outputter_names =
        try CCString.Split.list_cpy ~by:" " (Sys.getenv env_name) with Not_found -> default
      in
      CCList.map
        (fun on -> CCList.Assoc.get_exn ~eq:CCString.equal on outputter_map)
        outputter_names
    in
    CCList.iter (fun outputter -> outputter rr) outputters
end

module type S = sig
  type +'a m

  module Test : sig
    type t
  end

  module Phase : sig
    type 'g t

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

  (* Invert a test's outcome, for a KNOWN GAP: the test asserts what the code SHOULD do and passes
     while that fails. See the .mli for why a gap ships this way rather than as a red test. *)
  val expect_failure : ?reason:string -> Test.t -> Test.t
  val timeout : Duration.t -> Test.t -> Test.t
  val test : ?tags:string list -> ?desc:string -> name:string -> (unit -> unit m) -> Test.t

  val run :
    file:string ->
    setup:(unit -> ('a, string) result m) ->
    teardown:('a -> unit m) ->
    ('a -> Test.t) ->
    unit

  val run_phases :
    file:string ->
    setup:(unit -> ('g, string) result m) ->
    teardown:('g -> unit m) ->
    'g Phase.t list ->
    unit

  val collect_tags : file:string -> Test.t -> string list list m
end

module Make (T : T) : S with type 'a m = 'a T.t = struct
  type 'a m = 'a T.t

  let ( >>= ) = T.bind
  let return = T.return

  module Run_state = struct
    type t = {
      oth : State.t;
      backend : T.state;
    }
  end

  module Test = struct
    type t = Run_state.t -> Test_result.t list T.t
  end

  module Outputter = Outputter_impl

  let time_test f =
    let start = Unix.gettimeofday () in
    T.catch
      (fun () ->
        f ()
        >>= fun () ->
        let stop = Unix.gettimeofday () in
        return (Duration.of_f (stop -. start), `Ok))
      (fun (exn, bt) ->
        let stop = Unix.gettimeofday () in
        return (Duration.of_f (stop -. start), `Exn (exn, bt)))

  let test ?(tags = []) ?desc ~name f rs =
    let tags = all_tags ~name ~tags rs.Run_state.oth in
    match State.mode rs.Run_state.oth with
    | State.Print_tags ->
        print_test_tags ~tags;
        return []
    | State.Collect ->
        return Test_result.[ { name; desc; tags; duration = Duration.of_f 0.0; res = `Skipped } ]
    | State.Run when not (Tag.should_run_env ~tags) ->
        Logs.debug (fun m -> m "test : skip : %s" name);
        return Test_result.[ { name; desc; tags; duration = Duration.of_f 0.0; res = `Skipped } ]
    | State.Run ->
        Logs.debug (fun m -> m "test : start : %s" name);
        T.run_test rs.Run_state.backend ~name (fun () -> time_test f)
        >>= fun (duration, res) ->
        let outcome =
          match res with
          | `Ok -> "OK"
          | `Exn (exn, _) -> Printf.sprintf "EXN(%s)" (Printexc.to_string exn)
        in
        Logs.debug (fun m ->
            m "test : end : %s : %s : %0.03fs" name outcome (Duration.to_f duration));
        let res : [ `Ok | `Exn of exn * Printexc.raw_backtrace option | `Timedout | `Skipped ] =
          match res with
          | `Ok -> `Ok
          | `Exn (e, bt) -> `Exn (e, bt)
        in
        return Test_result.[ { name; desc; tags; duration; res } ]

  let serial tests rs =
    Logs.debug (fun m -> m "serial : begin : n=%d" (CCList.length tests));
    let rec loop acc = function
      | [] -> return (CCList.rev acc |> CCList.flatten)
      | t :: ts -> t rs >>= fun r -> loop (r :: acc) ts
    in
    loop [] tests
    >>= fun r ->
    Logs.debug (fun m -> m "serial : end");
    return r

  let parallel tests rs =
    Logs.debug (fun m -> m "parallel : begin : n=%d" (CCList.length tests));
    T.parallel (CCList.map (fun t () -> t rs) tests)
    >>= fun rss ->
    Logs.debug (fun m -> m "parallel : end");
    return (CCList.flatten rss)

  let loop n test rs =
    let rec loop' acc = function
      | 0 -> return (List.rev acc |> List.concat)
      | k -> test rs >>= fun r -> loop' (r :: acc) (k - 1)
    in
    loop' [] n

  let expect_failure ?reason test rs =
    (* [OTH_DISABLE_EXPECT_FAILURE=1] turns this into a pass-through, so a run reports what each test
       ACTUALLY did. Without it a suite of known gaps is uniformly green and says nothing about which
       gaps are still open -- and a gap that starts passing for the WRONG reason (the fixture broke,
       the assertion stopped reaching the interesting code) is indistinguishable from one that is
       genuinely still failing. Read on every call rather than cached so it can be set per run. *)
    if
      CCString.equal
        "1"
        (CCOption.get_or ~default:"0" (Sys.getenv_opt "OTH_DISABLE_EXPECT_FAILURE"))
    then test rs
    else
      let msg =
        Printf.sprintf
          "expect_failure: this test PASSED, but it is wrapped as an expected failure.%s\n\
           If the behaviour it asserts is now correct, remove the expect_failure wrapper so the \
           test stands on its own."
          (CCOption.map_or ~default:"" (Printf.sprintf "\nExpected failure: %s") reason)
      in
      test rs
      >>= fun trs ->
      return
        (CCList.map
           (fun tr ->
             match tr.Test_result.res with
             (* Inverted: the assertions describe behaviour that does not work yet, so their failure is
              the expected outcome and their success is the news. *)
             | `Ok -> { tr with Test_result.res = `Exn (Expect_failure_passed msg, None) }
             | `Exn _ -> { tr with Test_result.res = `Ok }
             (* NOT inverted. A timeout is not evidence that the expected assertion failed -- only that
              the test never reached it -- and a skip means tag filtering excluded the body, which
              inverting would turn into a manufactured pass. *)
             | `Timedout | `Skipped -> tr)
           trs)

  let timeout _duration _test = failwith "nyi"

  module Phase = struct
    type 'g t = Run_state.t -> 'g -> (Test_result.t list, string) result T.t

    let make ~name ~setup ~teardown test_fn rs g =
      Logs.debug (fun m -> m "phase : start : %s" name);
      setup g
      >>= function
      | Ok v ->
          test_fn v rs
          >>= fun rr ->
          teardown v
          >>= fun () ->
          Logs.debug (fun m -> m "phase : end : %s" name);
          return (Ok rr)
      | Error msg -> return (Error (Printf.sprintf "Phase %s setup failed:\n%s" name msg))
  end

  (* Returns [Error msg] when the run-level [setup] or a phase setup failed; test evaluation
     stops at the failed phase. The run-level [teardown] runs unless the run-level [setup]
     itself failed. Each phase's teardown completes before the next phase's setup starts. *)
  let eval_phases ~mode ~file ~setup ~teardown phases =
    T.create_state ()
    >>= fun backend ->
    let oth = State.create ~mode ~file () in
    let rs = { Run_state.oth; backend } in
    setup ()
    >>= function
    | Error msg -> return (Error msg)
    | Ok setup_value ->
        let rec go acc = function
          | [] -> teardown setup_value >>= fun () -> return (Ok (CCList.flatten (CCList.rev acc)))
          | phase :: phases -> (
              phase rs setup_value
              >>= function
              | Ok rr -> go (rr :: acc) phases
              | Error msg -> teardown setup_value >>= fun () -> return (Error msg))
        in
        go [] phases

  let run_phases ~file ~setup ~teardown phases =
    let tap_output_base_name =
      let exec_name = Filename.basename Sys.executable_name in
      match Sys.getenv_opt "OTH_TAP_DIR" with
      | Some dir ->
          let dirname_enclosing_execution = Filename.basename (Sys.getcwd ()) in
          Filename.concat dir (dirname_enclosing_execution ^ "-" ^ exec_name)
      | None -> exec_name
    in
    let tap_output_name = tap_output_base_name ^ ".tap" in
    let outputter =
      Outputter.of_env
        ~default:[ "stdout"; "tap" ]
        "OTH_OUTPUTTER"
        [
          ("stdout", Outputter.basic_stdout);
          ("tap", Outputter.basic_tap (`Filename tap_output_name));
        ]
    in
    T.run_suite (fun () ->
        let mode =
          if CCOption.is_some (Sys.getenv_opt "OTH_PRINT_TAGS") then State.Print_tags else State.Run
        in
        eval_phases ~mode ~file ~setup ~teardown phases
        >>= function
        | Error msg ->
            (* setup failed: no tests ran. Surface the message and exit 1
               rather than letting a raised exception vanish in the backend. *)
            Printf.printf "Setup failed:\n%s\n" msg;
            return (exit 1)
        | Ok _ when mode = State.Print_tags -> return (exit 0)
        | Ok trs ->
            outputter trs;
            let non_skipped =
              CCList.filter
                (fun tr ->
                  match tr.Test_result.res with
                  | `Skipped -> false
                  | _ -> true)
                trs
            in
            let total_tests = CCList.length non_skipped in
            let passed_tests =
              CCList.filter
                (fun tr ->
                  match tr.Test_result.res with
                  | `Ok -> true
                  | _ -> false)
                non_skipped
              |> CCList.length
            in
            let skipped_tests = CCList.length trs - CCList.length non_skipped in
            let success_percentage =
              if total_tests > 0 then float_of_int passed_tests /. float_of_int total_tests *. 100.0
              else 0.0
            in
            let skipped_suffix =
              if skipped_tests > 0 then Printf.sprintf ", %d skipped" skipped_tests else ""
            in
            Printf.printf
              "Tests passed: %d/%d (%.2f%%)%s\n"
              passed_tests
              total_tests
              success_percentage
              skipped_suffix;
            let has_failure =
              CCList.exists
                (fun tr ->
                  match tr.Test_result.res with
                  | `Ok | `Skipped -> false
                  | _ -> true)
                trs
            in
            if has_failure then return (exit 1) else return (exit 0))

  let run ~file ~setup ~teardown test_fn =
    run_phases
      ~file
      ~setup
      ~teardown
      [
        Phase.make
          ~name:"main"
          ~setup:(fun v -> return (Ok v))
          ~teardown:(fun _ -> return ())
          test_fn;
      ]

  let collect_tags ~file test =
    T.create_state ()
    >>= fun backend ->
    let oth = State.create ~mode:State.Collect ~file () in
    test { Run_state.oth; backend }
    >>= fun trs -> return (CCList.map (fun tr -> tr.Test_result.tags) trs)
end

module Sync_monad : T with type 'a t = 'a and type state = unit = struct
  type 'a t = 'a
  type state = unit

  let return x = x
  let bind x f = f x
  let catch f h = try f () with exn -> h (exn, Some (Printexc.get_raw_backtrace ()))
  let create_state () = ()
  let run_test () ~name:_ f = f ()
  let parallel fs = CCList.map (fun f -> f ()) fs
  let run_suite f = f ()
end

include Make (Sync_monad)
