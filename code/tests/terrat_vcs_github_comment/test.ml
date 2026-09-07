(* When a comment is too large, step output has to be trimmed. Terraform and its providers emit the
   error at the END of a step's output, so trimming must keep the tail -- keeping the head throws
   away the only part anyone needs (#1540). *)

module P = Terrat_vcs_github_comment_publishers

let marker = "[... earlier output trimmed to fit the comment ...]"

(* One workflow step output as the runner PUTs it. The payload is free form on both sides, so each
   fixture below is shaped like the dictionary the matching runner step module builds. *)
let step ~name ~success payload =
  let module O = Terrat_api_components.Workflow_step_output in
  CCResult.get_or_failwith
    (O.of_yojson
       (`Assoc
          [
            ("ignore_errors", `Bool false);
            ("payload", payload);
            ( "scope",
              `Assoc
                [ ("type", `String "run"); ("flow", `String "hooks"); ("subflow", `String "pre") ]
            );
            ("step", `String name);
            ("success", `Bool success);
          ]))

(* The template reads a list of assocs, one per step it is allowed to show. A step the visibility
   filter dropped is simply not in the list. *)
let kv_of_step ~overall_success s = P.steps_kv ~overall_success ~compact:false [ s ]
let shown ~overall_success s = kv_of_step ~overall_success s <> []

let field ~name s =
  match kv_of_step ~overall_success:false s with
  | [ `Assoc fields ] -> (
      match CCList.assoc_opt ~eq:CCString.equal name fields with
      | Some (`String v) -> v
      | Some _ | None -> Oth.Assert.false_ ("step has no " ^ name))
  | _ -> Oth.Assert.false_ "expected exactly one step"

(* [workflow_step_plan.py] always sends [plan]; it is the empty string for an engine whose [diff]
   returns [None], which is what stategraph and pulumi both do. *)
let plan_payload ?visible_on ?(plan = "+ create") () =
  `Assoc
    (("text", `String "plan stdout")
    :: ("plan", `String plan)
    :: ("has_changes", `Bool true)
    :: CCOption.map_or ~default:[] (fun v -> [ ("visible_on", `String v) ]) visible_on)

let run_payload ?visible_on () =
  `Assoc
    (("text", `String "run stdout")
    :: ("cmd", `List [ `String "echo" ])
    :: CCOption.map_or ~default:[] (fun v -> [ ("visible_on", `String v) ]) visible_on)

let test =
  Oth.parallel
    [
      Oth.test ~name:"short output is returned untouched" (fun _ ->
          let s = "line one\nline two\n" in
          Oth.Assert.Eq.string ~expected:s ~actual:(P.tail_of ~max_bytes:1000 s));
      Oth.test ~name:"output exactly at the budget is untouched" (fun _ ->
          let s = CCString.repeat "a" 100 in
          Oth.Assert.Eq.string ~expected:s ~actual:(P.tail_of ~max_bytes:100 s));
      Oth.test ~name:"the tail is kept, not the head" (fun _ ->
          (* The error is last, which is the whole point. *)
          let s = CCString.repeat "noise\n" 500 ^ "Error: 403 Forbidden: read-only dashboard\n" in
          let out = P.tail_of ~max_bytes:200 s in
          Oth.Assert.str_contains ~haystack:out ~needle:"Error: 403 Forbidden";
          Oth.Assert.true_ "trimmed output is bounded" (CCString.length out < 400));
      Oth.test ~name:"a trim is announced" (fun _ ->
          let s = CCString.repeat "x\n" 500 in
          Oth.Assert.str_contains ~haystack:(P.tail_of ~max_bytes:50 s) ~needle:marker);
      Oth.test ~name:"kept text resumes at a line boundary" (fun _ ->
          let s = CCString.repeat "abcdefghij\n" 100 in
          let out = P.tail_of ~max_bytes:35 s in
          (* Everything after the marker line must be whole lines. *)
          let body =
            match CCString.Split.left ~by:"\n" out with
            | Some (_marker_line, rest) -> rest
            | None -> out
          in
          CCString.split ~by:"\n" body
          |> CCList.filter (fun l -> l <> "")
          |> CCList.iter (fun l -> Oth.Assert.Eq.string ~expected:"abcdefghij" ~actual:l));
      Oth.test ~name:"output with no newline at all still trims" (fun _ ->
          let s = CCString.repeat "z" 1000 in
          let out = P.tail_of ~max_bytes:100 s in
          Oth.Assert.str_contains ~haystack:out ~needle:marker;
          Oth.Assert.true_ "bounded" (CCString.length out < 300));
      (* A plan, apply or init step can now carry visible_on, so the payload has to win over the
         step's default. *)
      Oth.test ~name:"a plan step obeys visible_on from the payload" (fun _ ->
          let s = step ~name:"tf/plan" ~success:true (plan_payload ~visible_on:"failure" ()) in
          Oth.Assert.not_true ~fail_msg:"hidden on a successful run" (shown ~overall_success:true s);
          Oth.Assert.true_ "shown on a failed run" (shown ~overall_success:false s);
          ());
      Oth.test ~name:"a plan step with no visible_on is always shown" (fun _ ->
          let s = step ~name:"tf/plan" ~success:true (plan_payload ()) in
          Oth.Assert.true_ "shown on a successful run" (shown ~overall_success:true s);
          Oth.Assert.true_ "shown on a failed run" (shown ~overall_success:false s);
          ());
      Oth.test ~name:"an apply step obeys visible_on from the payload" (fun _ ->
          let s = step ~name:"tf/apply" ~success:true (run_payload ~visible_on:"success" ()) in
          Oth.Assert.true_ "shown on a successful run" (shown ~overall_success:true s);
          Oth.Assert.not_true ~fail_msg:"hidden on a failed run" (shown ~overall_success:false s);
          ());
      Oth.test ~name:"an init step with no visible_on is shown only on failure" (fun _ ->
          let s = step ~name:"tf/init" ~success:true (run_payload ()) in
          Oth.Assert.not_true ~fail_msg:"hidden on a successful run" (shown ~overall_success:true s);
          Oth.Assert.true_ "shown on a failed run" (shown ~overall_success:false s);
          ());
      (* The stategraph engine names its steps stategraph/<action>, which the step dispatch used to
         miss: a plan then lost its diff and fell back to the raw stdout. *)
      Oth.test ~name:"a stategraph plan renders the diff" (fun _ ->
          let s = step ~name:"stategraph/plan" ~success:true (plan_payload ()) in
          Oth.Assert.Eq.string ~expected:"plan" ~actual:(field ~name:"name" s);
          Oth.Assert.Eq.string ~expected:"+ create" ~actual:(field ~name:"text" s);
          Oth.Assert.Eq.string ~expected:"diff" ~actual:(field ~name:"text_decorator" s);
          ());
      Oth.test ~name:"a plan with no diff falls back to the command output" (fun _ ->
          let s = step ~name:"stategraph/plan" ~success:true (plan_payload ~plan:"" ()) in
          Oth.Assert.Eq.string ~expected:"plan stdout" ~actual:(field ~name:"text" s);
          Oth.Assert.Eq.string ~expected:"" ~actual:(field ~name:"text_decorator" s);
          ());
      Oth.test ~name:"a stategraph plan obeys visible_on from the payload" (fun _ ->
          let s =
            step ~name:"stategraph/plan" ~success:true (plan_payload ~visible_on:"failure" ())
          in
          Oth.Assert.not_true ~fail_msg:"hidden on a successful run" (shown ~overall_success:true s);
          ());
      (* A payload that says nothing about visibility is still a payload the comment can read. The
         env step sends no visible_on at all, and used to come out as a JSON dump of its own
         payload. *)
      Oth.test ~name:"a step with no visible_on is not dumped as raw json" (fun _ ->
          let s =
            step
              ~name:"env"
              ~success:true
              (`Assoc
                 [
                   ("cmd", `List [ `String "echo" ]);
                   ("method", `String "exec");
                   ("text", `String "HELLO");
                 ])
          in
          Oth.Assert.Eq.string ~expected:"HELLO" ~actual:(field ~name:"text" s);
          ());
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
