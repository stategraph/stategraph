(* Per-fixture tests:

   - Positive fixtures ([name.hcl]) share a single [name.hcl.expected] file.
     Both the Menhir and shim parsers must produce the AST it records.

   - Negative fixtures ([name_bad.hcl]) keep per-parser expected files
     ([name_bad.hcl.expected.menhir] and [name_bad.hcl.expected.shim])
     because the two parsers emit different diagnostic wording. A [_bad]
     fixture may contain multiple cases separated by [\n---\n]; we
     compare the first erroring case's message against the expected file.

   Both parsers always run — calls to [Hcl_ast.Tests.Shim.*] fail loudly
   if the shim isn't available in the current build, so the test report
   never gives a false sense of safety by silently skipping the shim.

   The four lists below enumerate fixtures where Menhir and the shim
   currently disagree. Each list is a TODO that should shrink to empty
   as we align the Menhir parser with the shim. *)

let oth_create_expected_files =
  String.equal (CCOption.get_or ~default:"0" (Sys.getenv_opt "OTH_CREATE_EXPECTED_FILES")) "1"

(* TODO(hcl-parser-alignment): positive fixtures on which the Menhir and
   shim parsers both succeed but produce a different AST. Tracked
   per-parser via [.expected.menhir] and [.expected.shim] so future
   changes to either parser's output still surface as a test failure
   even while the divergence is being investigated. This list should
   become empty as the Menhir parser catches up with the shim. *)
let ast_divergent_positive_fixtures = []

(* Positive fixtures that the shim parses successfully but the Menhir
   parser rejects, *and that we have decided to leave divergent on
   purpose*. The shim's AST is pinned in [.expected.shim] and Menhir's
   error is pinned in [.expected.menhir] so drift in either parser
   still surfaces as a test failure. *)
let verdict_divergent_positive_fixtures =
  [
    (* hclsyntax accepts collection literals as object keys via
       [ObjectConsKeyExpr] (e.g. [{ [1,2] = "a" }] or [{ {a=1} = "b" }]),
       but the resulting object never evaluates: cty requires object
       keys to be strings, so any program that actually uses such a
       literal fails at evaluation anyway. Supporting it in Menhir
       would require teaching [obj_k_first] about [collection_expr]
       and updating the LR error states; not worth the grammar
       complexity for a form no one uses. We tolerate the parse-time
       rejection and let evaluation be the failure point. *)
    "statically_crafted_collection_as_obj_key.hcl";
    (* hclsyntax accepts [(for) = "v"] as an object key — inside parens
       [for] falls back to a bare identifier reference, same as [in] /
       [if]. Menhir's [obj_k_expr] reaches a state where the
       [LPAREN FOR ...] lookahead doesn't admit
       [expr_paren -> simple_expr -> FOR], so the case rejects. *)
    "statically_crafted_paren_obj_key_for.hcl";
  ]

(* TODO(hcl-parser-alignment): [_bad] fixtures that the shim correctly
   rejects but the Menhir parser incorrectly accepts. Menhir's (wrong)
   AST is pinned in [.expected.menhir] and the shim's error is pinned
   in [.expected.shim] so drift in either parser surfaces as a test
   failure. This list should become empty once Menhir's grammar tightens
   to reject them; at that point these fixtures can be promoted to
   regular [_bad] handling. *)
let verdict_divergent_bad_fixtures =
  [
    (* These 5 first aren't "bad" fixtures at all. The Go shim parses them successfully and emits e.g. ["Int", 9223372036854775807] as JSON. The Menhir parser
       also accepts them — its lexer falls back from int_of_string to float_of_string when the literal overflows OCaml's int, producing an
       Expr.Float. The failure is in Hcl_native.decode_with: of_yojson on Hcl_parser_value.Expr.t refuses to decode ["Int", 9223372036854775807] into
       OCaml's Int of int, because OCaml's 63-bit native int tops out at 4611686018427387903 (≈ 4.6 × 10¹⁸). The error surfaces as hcl_native:
       shim/OCaml shape mismatch: Expr.t, giving these fixtures the appearance of shim rejection

       Three plausible shapes for a fix:
       1. Shim-side: in walker.go's encodeLiteral, emit Float when the int64 doesn't fit in OCaml's 63-bit range (i.e., also require i >= -(1<<62) and
        i < (1<<62)). This would make the shim match Menhir's existing lexer behavior — the simplest path to verdict parity.
       2. AST-side: change Hcl_parser_value.Expr.Int of int to Int of int64 (or an arbitrary-precision type). Preserves full fidelity but ripples
       through every consumer.
       3. Decoder-side: make Hcl_native's of_yojson tolerant — when an Int payload overflows OCaml int, promote to Float. Hides the truncation inside
       the shim bridge.

       For now we don't want to fix those 5. *)
    "ghfail_GoogleCloudPlatform_accelerated-platforms__platforms__gke__base___shared_config__cluster_variables_bad.hcl";
    "ghfail_terraform-yacloud-modules_terraform-yandex-mdb-kafka__examples__complete__main_bad.hcl";
    "ghfail_terraform-yacloud-modules_terraform-yandex-mdb-kafka__variables_bad.hcl";
    "ghfail_trailofbits_algo-ng__modules__user-data__ipsec_bad.hcl";
    "ghfail_zheli_harmony-cloudwatch-synthetic-canary-scripts__terraform__expected_results_bad.hcl";
  ]

(* TODO(hcl-parser-alignment): positive fixtures where Menhir and the
   shim currently agree, but the agreed-upon AST is known to be
   incomplete. Example: heredoc bodies are stored as a raw string rather
   than decomposed into template parts (so [${...}] interpolations and
   [%{...}] directives inside a heredoc are opaque). These fixtures are
   not skipped; they're run with per-parser [.expected.menhir] and
   [.expected.shim] files (like [_bad] fixtures).

   This list should become empty once the AST gains variants that
   represent the finer structure and both parsers populate them. *)
let incomplete_positive_fixtures = [ "template_directives_heredoc.hcl" ]
let ast_to_string ast = Yojson.Safe.pretty_to_string (Hcl_ast.to_yojson ast)

type backend = {
  suffix : string;
  of_string : string -> (Hcl_ast.t, Hcl_ast.err) result;
}

let menhir_backend = { suffix = "menhir"; of_string = Hcl_ast.Tests.Menhir.of_string }
let shim_backend = { suffix = "shim"; of_string = Hcl_ast.Tests.Shim.of_string }

(* In testing environments, the shim should be there; so hardcoding the two backends being active *)
let active_backends = [ menhir_backend; shim_backend ]

let read_expected_ast path =
  Hcl_ast.of_yojson (Yojson.Safe.from_string (CCIO.with_in path CCIO.read_all))
  |> Oth.Assert.ok_pp ~pp:Format.pp_print_string

let check_success_backend path contents backend =
  let expected_path = path ^ ".expected" in
  match (backend.of_string contents, oth_create_expected_files) with
  (* oth_create_expected_files=true *)
  | Ok ast, true -> CCIO.with_out expected_path (CCFun.flip CCIO.write_line (ast_to_string ast))
  | Error err, true ->
      Printf.eprintf
        "CREATE skipped (%s rejected success fixture %s): %s\n"
        backend.suffix
        (Filename.basename path)
        (Hcl_ast.show_err err)
  (* oth_create_expected_files=false *)
  | Ok ast, false ->
      let expected = read_expected_ast expected_path in
      if not (Hcl_ast.equal ast expected) then (
        let obtained_path = path ^ ".obtained" in
        CCIO.with_out obtained_path (CCFun.flip CCIO.write_line (ast_to_string ast));
        let abs p = if Filename.is_relative p then Filename.concat (Sys.getcwd ()) p else p in
        let show_path p = p |> abs |> Sln_fs.normalize_path in
        Oth.Assert.false_
          (Printf.sprintf
             "%s: AST did not match %s. Run this command to see the diff: diff -u %s %s"
             backend.suffix
             (Filename.basename expected_path)
             (show_path expected_path)
             (show_path obtained_path)))
  | Error err, false ->
      Oth.Assert.false_
        (Printf.sprintf "%s: unexpected parse error: %s" backend.suffix (Hcl_ast.show_err err))

let first_error backend contents =
  CCList.find_map
    (fun chunk ->
      match backend.of_string chunk with
      | Ok _ -> None
      | Error (`Error (_, _, msg)) -> Some msg)
    (CCString.split ~by:"\n---\n" contents)

let check_fail_backend path contents backend =
  let expected_path = path ^ ".expected." ^ backend.suffix in
  match (first_error backend contents, oth_create_expected_files) with
  (* oth_create_expected_files=true *)
  | Some msg, true -> CCIO.with_out expected_path (fun oc -> CCIO.write_line oc msg)
  | None, true ->
      Printf.eprintf
        "CREATE skipped (%s accepted all cases in bad fixture %s)\n"
        backend.suffix
        (Filename.basename path)
  (* oth_create_expected_files=false *)
  | Some msg, false ->
      let expected = CCString.trim (CCIO.with_in expected_path CCIO.read_all) in
      if not (CCString.equal expected msg) then
        Oth.Assert.false_
          (Printf.sprintf
             "%s: error did not match %s\n  expected: %s\n    actual: %s"
             backend.suffix
             (Filename.basename expected_path)
             expected
             msg)
  | None, false ->
      Oth.Assert.false_
        (Printf.sprintf
           "%s: bad fixture was accepted by the parser (expected %s to fail parsing)"
           backend.suffix
           (Filename.basename expected_path))

(* Variant of [check_success_backend] for fixtures in
   [per_parser_positive_fixtures]: same semantics (parser must accept
   and produce the recorded AST), but the expected file is per-parser
   so [.expected.menhir] and [.expected.shim] can hold different ASTs
   (AST divergence between parsers) or identical-but-incomplete ASTs *)
let check_per_parser_positive_backend path contents backend =
  let expected_path = path ^ ".expected." ^ backend.suffix in
  match (backend.of_string contents, oth_create_expected_files) with
  | Ok ast, true -> CCIO.with_out expected_path (CCFun.flip CCIO.write_line (ast_to_string ast))
  | Error err, true ->
      Printf.eprintf
        "CREATE skipped (%s rejected per-parser positive fixture %s): %s\n"
        backend.suffix
        (Filename.basename path)
        (Hcl_ast.show_err err)
  | Ok ast, false ->
      let expected = read_expected_ast expected_path in
      if not (Hcl_ast.equal ast expected) then
        Oth.Assert.false_
          (Printf.sprintf
             "%s: AST did not match %s"
             backend.suffix
             (Filename.basename expected_path))
  | Error err, false ->
      Oth.Assert.false_
        (Printf.sprintf "%s: unexpected parse error: %s" backend.suffix (Hcl_ast.show_err err))

let is_bad_fixture = CCString.suffix ~suf:"_bad.hcl"

(* For [_bad] fixtures that Menhir wrongly accepts but the shim correctly
   rejects: Menhir is checked as a positive fixture against
   [.expected.menhir] (an AST JSON), and the shim is checked as a
   failing fixture against [.expected.shim] (an error message). *)
let check_verdict_divergent_bad_backend path contents backend =
  match backend.suffix with
  | "menhir" -> check_per_parser_positive_backend path contents backend
  | "shim" -> check_fail_backend path contents backend
  | suffix ->
      Oth.Assert.false_
        (Printf.sprintf "unexpected backend for verdict-divergent bad fixture: %s" suffix)

(* Mirror of [check_verdict_divergent_bad_backend] for positive fixtures
   the shim parses but Menhir rejects. Menhir's error is pinned in
   [.expected.menhir], the shim's AST in [.expected.shim]. *)
let check_verdict_divergent_positive_backend path contents backend =
  match backend.suffix with
  | "menhir" -> check_fail_backend path contents backend
  | "shim" -> check_per_parser_positive_backend path contents backend
  | suffix ->
      Oth.Assert.false_
        (Printf.sprintf "unexpected backend for verdict-divergent positive fixture: %s" suffix)

let make_fixture_test path =
  let name = Filename.basename path in
  Oth.test ~name (fun _ ->
      let contents = CCIO.with_in path CCIO.read_all in
      if List.mem name verdict_divergent_bad_fixtures then
        List.iter (check_verdict_divergent_bad_backend path contents) active_backends
      else if List.mem name verdict_divergent_positive_fixtures then
        List.iter (check_verdict_divergent_positive_backend path contents) active_backends
      else if is_bad_fixture path then List.iter (check_fail_backend path contents) active_backends
      else if
        List.mem name ast_divergent_positive_fixtures || List.mem name incomplete_positive_fixtures
      then List.iter (check_per_parser_positive_backend path contents) active_backends
      else List.iter (check_success_backend path contents) active_backends)

let parse_tests =
  let src_dir = Sys.getenv "SRC_DIR" in
  let files_dir = Filename.concat src_dir "files" in
  Sys.readdir (Filename.concat src_dir "files")
  |> CCArray.to_list
  |> CCList.sort CCString.compare
  |> CCList.filter (CCString.suffix ~suf:".hcl")
  |> CCList.map (fun fname -> make_fixture_test (Filename.concat files_dir fname))

(* Ground-truth invariant: the Go shim wraps hclsyntax, and so does [tofu fmt].
   They must agree on accept/reject for every fixture. If they disagreed, we'd
   be aligning Menhir to idiosyncrasies of our shim wrapper rather than to the
   upstream reference parser, so that agreement is worth pinning. *)

(* The 5 ghfail fixtures listed here encode integers that overflow OCaml's 63-bit
   native int. The Go shim happily emits them as ["Int", 9223372036854775807],
   the [Hcl_native] decoder then rejects the payload because it can't fit
   [Int of int]. Result: [Hcl_ast.Tests.Shim.of_string] returns Error whereas
   [tofu fmt] accepts. This is a decoder-side mismatch, not a real shim-vs-tofu
   disagreement, so we skip these fixtures from the parity check — we don't
   even generate the test case. See the long comment on
   [verdict_divergent_bad_fixtures] for the fix options. *)
let tofu_parity_skipped_fixtures =
  [
    "ghfail_GoogleCloudPlatform_accelerated-platforms__platforms__gke__base___shared_config__cluster_variables_bad.hcl";
    "ghfail_terraform-yacloud-modules_terraform-yandex-mdb-kafka__examples__complete__main_bad.hcl";
    "ghfail_terraform-yacloud-modules_terraform-yandex-mdb-kafka__variables_bad.hcl";
    "ghfail_trailofbits_algo-ng__modules__user-data__ipsec_bad.hcl";
    "ghfail_zheli_harmony-cloudwatch-synthetic-canary-scripts__terraform__expected_results_bad.hcl";
  ]

(* The tag every test in this group carries, so a build that deliberately ships no
   OpenTofu can turn the whole group off with
   [OTH_EXCLUDE_TAGS=HCL_AST_TESTS_NEEDING_TOFU] instead of carrying known-red tests.
   The terrateam image does exactly that. *)
let tofu_tag = "HCL_AST_TESTS_NEEDING_TOFU"

(* [tofu fmt] is the ground truth this group compares the shim against, so its
   absence is a broken environment, not a verdict -- and [Sys.command] cannot tell
   the two apart.

   Probed once and memoised, and [lazy] rather than eager so the probe only fires if a
   test in this group actually runs. *)
let tofu_missing_msg =
  Printf.sprintf
    "[tofu] is not on PATH, so [tofu fmt] cannot provide the reference verdict the tofu_fmt_parity \
     group compares the shim against. Install OpenTofu, or exclude the group with \
     OTH_EXCLUDE_TAGS=%s."
    tofu_tag

let tofu_available =
  lazy
    (match Sys.command "command -v tofu >/dev/null 2>&1" with
    | 0 -> true
    | _ ->
        prerr_endline ("hcl_ast tests: " ^ tofu_missing_msg);
        false)

let assert_tofu_available () =
  if not (Lazy.force tofu_available) then Oth.Assert.false_ tofu_missing_msg

(* [run_tofu_fmt content] writes [content] to a temp [.tf] file (tofu only
   accepts [.tf] / [.tfvars] / [.tftest.hcl] extensions) and runs
   [tofu fmt -write=false] on it. The [-write=false] flag tells tofu not to
   touch the file; without [-check] the exit code is 0 whenever the file
   parses, non-zero only on a real parse error — so we only learn
   accept/reject, not whether the file was already canonically formatted (we
   don't want to force canonical formatting on the fixture corpus: a variety
   of formatting styles is part of what we test parsers against). *)
let run_tofu_fmt content =
  let tmpfile = Filename.temp_file "tofu_parity_" ".tf" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove tmpfile with _ -> ())
    (fun () ->
      CCIO.with_out tmpfile (fun oc -> output_string oc content);
      let cmd =
        Printf.sprintf "tofu fmt -write=false %s >/dev/null 2>&1" (Filename.quote tmpfile)
      in
      match Sys.command cmd with
      | 0 -> `Accept
      | _ -> `Reject)

(* A fixture may contain multiple cases separated by [\n---\n]; the
   [---] line is not valid HCL anywhere, so handing the whole file to
   either parser would produce trivial agreement (both reject) and
   miss the per-case parity signal. Split first, then check each chunk
   independently. *)
let make_tofu_parity_test path =
  let name = "tofu_fmt_parity: " ^ Filename.basename path in
  Oth.test ~tags:[ tofu_tag ] ~name (fun _ ->
      assert_tofu_available ();
      let contents = CCIO.with_in path CCIO.read_all in
      let chunks = CCString.split ~by:"\n---\n" contents in
      CCList.iteri
        (fun i chunk ->
          let label =
            match chunks with
            | [ _ ] -> Filename.basename path
            | _ -> Printf.sprintf "%s [case %d]" (Filename.basename path) (i + 1)
          in
          let shim = Hcl_ast.Tests.Shim.of_string chunk in
          let tofu = run_tofu_fmt chunk in
          match (shim, tofu) with
          | Ok _, `Accept -> ()
          | Error _, `Reject -> ()
          | Ok _, `Reject ->
              Oth.Assert.false_
                (Printf.sprintf "%s: shim accepts the fixture but [tofu fmt] rejects it" label)
          | Error err, `Accept ->
              Oth.Assert.false_
                (Printf.sprintf
                   "%s: [tofu fmt] accepts the fixture but shim rejects it: %s"
                   label
                   (Hcl_ast.show_err err)))
        chunks)

let tofu_fmt_parity_tests =
  let src_dir = Sys.getenv "SRC_DIR" in
  let files_dir = Filename.concat src_dir "files" in
  Sys.readdir files_dir
  |> CCArray.to_list
  |> CCList.sort CCString.compare
  |> CCList.filter (CCString.suffix ~suf:".hcl")
  |> CCList.filter (fun fname -> not (List.mem fname tofu_parity_skipped_fixtures))
  |> CCList.map (fun fname -> make_tofu_parity_test (Filename.concat files_dir fname))

(* --- Hcl_ast.Normalize unit tests --------------------------------------- *)

let normalize_parse s = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string s)
let normalize s = Hcl_ast.To_string.ast (Hcl_ast.Normalize.ast (normalize_parse s))

(* [a] and [b] must normalize to the same source. *)
let normalize_eq_test ~name a b =
  Oth.test ~name (fun _ -> Oth.Assert.Eq.string ~expected:(normalize a) ~actual:(normalize b))

(* [a] and [b] must NOT normalize to the same source (guards against
   over-normalization that would hide a real difference). *)
let normalize_neq_test ~name a b =
  Oth.test ~name (fun _ ->
      let na = normalize a and nb = normalize b in
      if CCString.equal na nb then
        Oth.Assert.false_ (Printf.sprintf "expected normalized forms to differ, both were:@.%s" na))

(* The examples below pin specific cases; [Normalize_prop] covers the same module
   with randomized property tests. *)
let normalize_tests =
  [
    (* Object/map key order collapses. *)
    normalize_eq_test
      ~name:"normalize: object key order"
      "x = { b = 1, a = 2 }"
      "x = { a = 2, b = 1 }";
    (* Nested objects are normalized recursively (top-down walker recurses into values). *)
    normalize_eq_test
      ~name:"normalize: nested object key order"
      "x = { outer = { b = 1, a = 2 } }"
      "x = { outer = { a = 2, b = 1 } }";
    (* Bare and quoted keys fold to one form. *)
    normalize_eq_test ~name:"normalize: bare vs quoted key" "x = { foo = 1 }" "x = { \"foo\" = 1 }";
    (* Numeric bareword [007] is the key "7", same as quoted "7". *)
    normalize_eq_test
      ~name:"normalize: numeric bare key equals quoted number"
      "x = { 007 = 1 }"
      "x = { \"7\" = 1 }";
    (* ...but NOT the same as quoted "007" (a literal string key). *)
    normalize_neq_test
      ~name:"normalize: numeric bare key differs from quoted zero-padded"
      "x = { 007 = 1 }"
      "x = { \"007\" = 1 }";
    (* Duplicate keys are last-wins: stable sort keeps them, never folds. *)
    normalize_neq_test
      ~name:"normalize: duplicate key not folded"
      "x = { a = 1, a = 2 }"
      "x = { a = 2 }";
    (* Stability: reordered duplicates have different last-wins, must not collapse. *)
    normalize_neq_test
      ~name:"normalize: duplicate order (last-wins) preserved"
      "x = { a = 1, a = 2 }"
      "x = { a = 2, a = 1 }";
    (* A computed key is a barrier: keys don't sort across it. *)
    normalize_neq_test
      ~name:"normalize: computed key is a sort barrier"
      "x = { b = 1, a = 2, (var.x) = 3 }"
      "x = { (var.x) = 3, b = 1, a = 2 }";
    (* Attribute order within a block body collapses. *)
    normalize_eq_test
      ~name:"normalize: body attribute order"
      "resource \"aws_x\" \"y\" {\n  b = 1\n  a = 2\n}"
      "resource \"aws_x\" \"y\" {\n  a = 2\n  b = 1\n}";
    (* Repeated child blocks keep their source order (ordered list). *)
    normalize_neq_test
      ~name:"normalize: repeated block order preserved"
      "resource \"x\" \"y\" {\n  provisioner \"b\" {}\n  provisioner \"a\" {}\n}"
      "resource \"x\" \"y\" {\n  provisioner \"a\" {}\n  provisioner \"b\" {}\n}";
    (* Bareword vs quoted block label folds. *)
    normalize_eq_test
      ~name:"normalize: block label id vs lit"
      "resource aws_x \"y\" {}"
      "resource \"aws_x\" \"y\" {}";
    (* Tuple order is NOT normalized (list vs set is indistinguishable in the AST). *)
    normalize_neq_test ~name:"normalize: tuple order preserved" "x = [1, 2]" "x = [2, 1]";
    (* Normalization is idempotent. *)
    Oth.test ~name:"normalize: idempotent" (fun _ ->
        let once = normalize "x = { b = 1, a = 2, foo = { d = 4, c = 3 } }" in
        let twice = Hcl_ast.To_string.ast (Hcl_ast.Normalize.ast (normalize_parse once)) in
        Oth.Assert.Eq.string ~expected:once ~actual:twice);
  ]

(* Pins the exact normalized output shown in the [Hcl_ast_normalize] doc comment,
   so a doc example that drifts from what [Normalize.ast] produces fails here. *)
let normalize_doc_example ~name ~input ~expected =
  Oth.test ~name (fun _ -> Oth.Assert.Eq.string ~expected ~actual:(normalize input))

let normalize_doc_examples =
  [
    normalize_doc_example
      ~name:"normalize doc: object key sort and bare/quoted fold"
      ~input:"x = { b = 1, \"a\" = 2 }"
      ~expected:"x = {\n  \"a\" = 2\n  \"b\" = 1\n}";
    normalize_doc_example
      ~name:"normalize doc: numeric bareword key"
      ~input:"x = { 007 = 1 }"
      ~expected:"x = {\n  \"7\" = 1\n}";
    normalize_doc_example
      ~name:"normalize doc: body attribute sort, label fold, block order"
      ~input:
        "resource aws_x \"y\" {\n\
        \  z = 3\n\
        \  provisioner \"b\" {}\n\
        \  a = 1\n\
        \  provisioner \"a\" {}\n\
         }"
      ~expected:
        "resource \"aws_x\" \"y\" {\n\
        \  a = 1\n\
        \  z = 3\n\n\
        \  provisioner \"b\" {\n\
        \  }\n\n\
        \  provisioner \"a\" {\n\
        \  }\n\
         }";
  ]

(* Parse a single-attribute source, apply [Normalize.template] to its expression,
   and render it back — the pipeline the [template] doc examples describe. *)
let normalize_template s =
  match normalize_parse s with
  | [ Hcl_parser_value.Attribute (_, e) ] -> Hcl_ast.To_string.expr (Hcl_ast.Normalize.template e)
  | _ -> failwith "expected a single top-level attribute"

(* Pins the exact output shown in the [Hcl_ast_normalize.template] doc comment. *)
let template_doc_example ~name ~input ~expected =
  Oth.test ~name (fun _ -> Oth.Assert.Eq.string ~expected ~actual:(normalize_template input))

let template_doc_examples =
  [
    template_doc_example
      ~name:"template doc: core single-template unwrap"
      ~input:"x = \"${\"${foo}\"}\""
      ~expected:"\"${foo}\"";
    template_doc_example
      ~name:"template doc: splice among other parts"
      ~input:"x = \"${a}${\"${b}\"}c\""
      ~expected:"\"${a}${b}c\"";
    template_doc_example
      ~name:"template doc: inner template with a literal part"
      ~input:"x = \"${\"${foo}bar\"}\""
      ~expected:"\"${foo}bar\"";
    template_doc_example
      ~name:"template doc: recurses into function-call args"
      ~input:"x = upper(\"${\"${foo}\"}\")"
      ~expected:"upper(\"${foo}\")";
    template_doc_example
      ~name:"template doc: recurses into tuple elements"
      ~input:"x = [\"${\"${a}\"}\", \"${\"${b}\"}\"]"
      ~expected:"[\"${a}\", \"${b}\"]";
    template_doc_example
      ~name:"template doc: wrapper inside a conditional arm is left as-is"
      ~input:"x = foo ? \"${\"${a}\"}\" : b"
      ~expected:"(foo ? \"${\"${a}\"}\" : b)";
  ]

(* The printer's output is what tofu is handed, and what we read back ourselves — from the DB, and on
   the actuator's restore path. So over the whole corpus, printing must produce something loadable,
   and printing what was loaded must not drift again. A body the printer mangles into unparseable
   text turns into a failed plan rather than a diff, which is how the [%{ endfor ~}] heredoc case
   reached the field.

   This is the cheap half of printer/tofu parity: it pins loadability and stability, not formatting.
   Terraform's own writer preserves source tokens (comments, line structure, redundant parens), which
   an AST printer cannot reproduce, so byte parity with [tofu fmt] is not the goal here. Value parity
   is pinned where values are produced: [flush_after_trim_markers] and the float-literal cases in
   [tests/hcl_ast_to_string], both with expectations taken from tofu. *)
let printer_reparse_divergent_fixtures =
  [
    (* [x = for + 1] uses a keyword as a bare identifier, which hclsyntax and we both accept. The
       printer parenthesizes the operand, and [(for] then hits the grammar's [LPAREN FOR RPAREN]
       production, which admits only [)] after [for] — so our own reader rejects what we wrote, while
       tofu parses it. Dropping that production makes two parser error states collapse into one and
       needs the [hcl_parser_errors.messages] catalog regenerated by hand, for an input tofu itself
       rejects at reference validation. *)
    "statically_crafted_keyword_ident_for.hcl";
    (* Parenthesized object keys ([(3 + 4) = 7]) gain one paren layer on the first round trip, from
       the key's own parens plus the binop's; stable from the second on. Fixing it means printing
       parens by precedence instead of unconditionally. *)
    "compare_different_key_kinds.hcl";
  ]

let make_printer_reparse_test path =
  let name = "printer_reparse: " ^ Filename.basename path in
  Oth.test ~name (fun _ ->
      let contents = CCIO.with_in path CCIO.read_all in
      match Hcl_ast.of_string contents with
      (* Fixtures the parser rejects are covered by the parse tests above; nothing to print. *)
      | Error _ -> ()
      | Ok ast -> (
          let printed = Hcl_ast.To_string.ast ast in
          match Hcl_ast.of_string printed with
          | Error err ->
              Oth.Assert.false_
                (Printf.sprintf
                   "printed HCL does not re-parse: %s\nprinted:\n%s"
                   (Hcl_ast.show_err err)
                   printed)
          | Ok reparsed ->
              Oth.Assert.Eq.string ~expected:printed ~actual:(Hcl_ast.To_string.ast reparsed)))

let printer_reparse_tests =
  let src_dir = Sys.getenv "SRC_DIR" in
  let files_dir = Filename.concat src_dir "files" in
  Sys.readdir files_dir
  |> CCArray.to_list
  |> CCList.sort CCString.compare
  |> CCList.filter (fun f -> CCString.suffix ~suf:".hcl" f || CCString.suffix ~suf:".tf" f)
  |> CCList.filter (fun f ->
      not (CCList.mem ~eq:CCString.equal f printer_reparse_divergent_fixtures))
  |> CCList.map (fun fname -> make_printer_reparse_test (Filename.concat files_dir fname))

let test =
  Oth.parallel
    (parse_tests
    @ tofu_fmt_parity_tests
    @ normalize_tests
    @ template_doc_examples
    @ normalize_doc_examples
    @ printer_reparse_tests
    @ Normalize_prop.tests)

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
