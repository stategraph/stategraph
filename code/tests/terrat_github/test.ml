(* The call timeout the tests bound against.  It matches the shipped default of
   [TERRAT_VCS_CALL_TIMEOUT] so that the cases read the way a deployment
   behaves. *)
let max_wait = 20.0

let decision ?(status = 403) ?(now = 1000.0) headers =
  Terrat_github.rate_limit_decision ~headers ~status ~now ~max_wait

let assert_wait ~expected = function
  | `Wait w -> Oth.Assert.true_ ~fail_msg:"unexpected wait" (CCFloat.abs (w -. expected) < 0.001)
  | `Fail _ -> Oth.Assert.false_ "expected `Wait, got `Fail"
  | `No_wait -> Oth.Assert.false_ "expected `Wait, got `No_wait"

let assert_fail = function
  | `Fail _ -> ()
  | `Wait _ -> Oth.Assert.false_ "expected `Fail, got `Wait"
  | `No_wait -> Oth.Assert.false_ "expected `Fail, got `No_wait"

let assert_no_wait = function
  | `No_wait -> ()
  | `Wait _ -> Oth.Assert.false_ "expected `No_wait, got `Wait"
  | `Fail _ -> Oth.Assert.false_ "expected `No_wait, got `Fail"

let test_success_is_not_a_rate_limit =
  Oth.test ~name:"a 200 is not a rate limit" (fun _ ->
      assert_no_wait (decision ~status:200 [ ("x-ratelimit-remaining", "0") ]);
      ())

let test_403_without_headers_is_not_a_rate_limit =
  Oth.test ~name:"a 403 with no rate limit headers is not a rate limit" (fun _ ->
      assert_no_wait (decision [ ("content-type", "application/json") ]);
      ())

let test_retry_after_within_timeout_waits =
  Oth.test ~name:"retry-after inside the call timeout waits" (fun _ ->
      assert_wait ~expected:5.0 (decision [ ("retry-after", "5") ]);
      ())

let test_retry_after_beyond_timeout_fails_fast =
  Oth.test ~name:"retry-after beyond the call timeout fails fast" (fun _ ->
      assert_fail (decision [ ("retry-after", "3600") ]);
      ())

(* The 30s substitute for an unreadable header is above the 20s call timeout on
   purpose: a wait we cannot read is a wait we will not gamble on. *)
let test_unparseable_retry_after_fails_fast =
  Oth.test ~name:"unparseable retry-after fails fast" (fun _ ->
      assert_fail (decision [ ("retry-after", "soon") ]);
      ())

let test_reset_within_timeout_waits =
  Oth.test ~name:"a reset inside the call timeout waits" (fun _ ->
      assert_wait
        ~expected:5.0
        (decision ~now:1000.0 [ ("x-ratelimit-remaining", "0"); ("x-ratelimit-reset", "1005") ]);
      ())

let test_reset_already_past_is_a_zero_wait =
  Oth.test ~name:"a reset already past is a zero wait, not a negative one" (fun _ ->
      assert_wait
        ~expected:0.0
        (decision ~now:1000.0 [ ("x-ratelimit-remaining", "0"); ("x-ratelimit-reset", "900") ]);
      ())

let test_reset_beyond_timeout_fails_fast =
  Oth.test ~name:"a reset beyond the call timeout fails fast" (fun _ ->
      assert_fail
        (decision ~now:1000.0 [ ("x-ratelimit-remaining", "0"); ("x-ratelimit-reset", "4600") ]);
      ())

(* Remaining quota above zero is not a rate limit, whatever the reset says. *)
let test_remaining_above_zero_is_not_a_rate_limit =
  Oth.test ~name:"remaining above zero is not a rate limit" (fun _ ->
      assert_no_wait
        (decision ~now:1000.0 [ ("x-ratelimit-remaining", "17"); ("x-ratelimit-reset", "4600") ]);
      ())

let test_headers_are_case_insensitive =
  Oth.test ~name:"header lookup ignores case" (fun _ ->
      assert_wait ~expected:5.0 (decision [ ("Retry-After", "5") ]);
      ())

(* retry-after wins over the reset pair, so a short retry-after still waits even
   when the reset instant is far away. *)
let test_retry_after_takes_precedence =
  Oth.test ~name:"retry-after is preferred over the reset pair" (fun _ ->
      assert_wait
        ~expected:5.0
        (decision
           ~now:1000.0
           [ ("retry-after", "5"); ("x-ratelimit-remaining", "0"); ("x-ratelimit-reset", "4600") ]);
      ())

let selected ?override_path workflows =
  CCOption.map (fun (id, _, _) -> id) (Terrat_github.Workflow.select ?override_path workflows)

let assert_selected ~expected actual =
  Oth.Assert.true_
    ~fail_msg:
      (Printf.sprintf
         "expected %s, got %s"
         (CCOption.map_or ~default:"none" CCInt.to_string expected)
         (CCOption.map_or ~default:"none" CCInt.to_string actual))
    (CCOption.equal CCInt.equal expected actual)

let terrateam = (1, "Terrateam Workflow", ".github/workflows/terrateam.yml")
let stategraph = (2, "Stategraph", ".github/workflows/stategraph.yml")
let unrelated = (3, "CI", ".github/workflows/ci.yml")

let test_workflow_old_name =
  Oth.test ~name:"the Terrateam workflow name matches" (fun _ ->
      assert_selected
        ~expected:(Some 1)
        (selected [ unrelated; (1, "Terrateam Workflow", ".github/workflows/other.yml") ]);
      ())

let test_workflow_old_path =
  Oth.test ~name:"the terrateam.yml path matches" (fun _ ->
      assert_selected
        ~expected:(Some 1)
        (selected [ unrelated; (1, "Other", ".github/workflows/terrateam.yml") ]);
      ())

let test_workflow_new_name =
  Oth.test ~name:"the Stategraph workflow name matches" (fun _ ->
      assert_selected
        ~expected:(Some 2)
        (selected [ unrelated; (2, "Stategraph", ".github/workflows/other.yml") ]);
      assert_selected
        ~expected:(Some 2)
        (selected [ terrateam; (2, "Stategraph", ".github/workflows/other.yml") ]);
      ())

let test_workflow_new_path =
  Oth.test ~name:"the stategraph.yml path matches" (fun _ ->
      assert_selected
        ~expected:(Some 2)
        (selected [ unrelated; (2, "Other", ".github/workflows/stategraph.yml") ]);
      ())

let test_workflow_neither =
  Oth.test ~name:"an unrelated workflow does not match" (fun _ ->
      assert_selected ~expected:None (selected [ unrelated ]);
      ())

let test_workflow_prefers_stategraph =
  Oth.test ~name:"the Stategraph workflow wins when both are present" (fun _ ->
      assert_selected ~expected:(Some 2) (selected [ terrateam; stategraph ]);
      assert_selected ~expected:(Some 2) (selected [ stategraph; terrateam ]);
      ())

let test_workflow_override_path =
  Oth.test ~name:"an override path selects that path alone" (fun _ ->
      assert_selected
        ~expected:(Some 1)
        (selected ~override_path:".github/workflows/terrateam.yml" [ stategraph; terrateam ]);
      assert_selected
        ~expected:None
        (selected ~override_path:".github/workflows/custom.yml" [ stategraph; terrateam ]);
      ())

let () =
  Oth.run
    ~file:__FILE__
    ~setup:(fun () -> Ok ())
    ~teardown:(fun _ -> ())
    (fun _ ->
      Oth.serial
        [
          test_workflow_old_name;
          test_workflow_old_path;
          test_workflow_new_name;
          test_workflow_new_path;
          test_workflow_neither;
          test_workflow_prefers_stategraph;
          test_workflow_override_path;
          test_success_is_not_a_rate_limit;
          test_403_without_headers_is_not_a_rate_limit;
          test_retry_after_within_timeout_waits;
          test_retry_after_beyond_timeout_fails_fast;
          test_unparseable_retry_after_fails_fast;
          test_reset_within_timeout_waits;
          test_reset_already_past_is_a_zero_wait;
          test_reset_beyond_timeout_fails_fast;
          test_remaining_above_zero_is_not_a_rate_limit;
          test_headers_are_case_insensitive;
          test_retry_after_takes_precedence;
        ])
