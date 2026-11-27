let matches_positive =
  Oth.test ~name:"matches_positive" (fun _ ->
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:(Sg_caps_match.matches ~patterns:[ "module.foo.*" ] "module.foo.bar");
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:(Sg_caps_match.matches ~patterns:[ "module.foo.*" ] "module.bar.baz");
      ())

let matches_star_all =
  Oth.test ~name:"matches_star_all" (fun _ ->
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:(Sg_caps_match.matches ~patterns:[ "*" ] "anything.at.all");
      ())

let matches_negation =
  Oth.test ~name:"matches_negation" (fun _ ->
      (* allow everything under module.foo except its outputs *)
      let pats = [ "module.foo.*"; "!module.foo.output.*" ] in
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:(Sg_caps_match.matches ~patterns:pats "module.foo.aws_s3_bucket.b");
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:(Sg_caps_match.matches ~patterns:pats "module.foo.output.url");
      ())

let matches_implicit_star =
  Oth.test ~name:"matches_implicit_star" (fun _ ->
      (* an all-negation list implies a leading "*" *)
      let pats = [ "!module.foo.*" ] in
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:(Sg_caps_match.matches ~patterns:pats "module.bar.baz");
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:(Sg_caps_match.matches ~patterns:pats "module.foo.bar");
      ())

let matches_empty_denies =
  Oth.test ~name:"matches_empty_denies" (fun _ ->
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.matches ~patterns:[] "anything");
      (* [] is equivalent to ["!*"] *)
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:(Sg_caps_match.matches ~patterns:[ "!*" ] "anything");
      ())

let matches_glob_negation =
  Oth.test ~name:"matches_glob_negation" (fun _ ->
      (* negations may themselves be globs *)
      let pats = [ "*"; "!aws_*" ] in
      Oth.Assert.Eq.bool
        ~expected:true
        ~actual:(Sg_caps_match.matches ~patterns:pats "google_storage.b");
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:(Sg_caps_match.matches ~patterns:pats "aws_instance.web");
      ())

let normalize_list_cases =
  Oth.test ~name:"normalize_list_cases" (fun _ ->
      Oth.Assert.String_list.eq ~expected:[] ~actual:(Sg_caps_match.normalize_list []);
      Oth.Assert.String_list.eq
        ~expected:[ "*"; "!a" ]
        ~actual:(Sg_caps_match.normalize_list [ "!a" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "a"; "b" ]
        ~actual:(Sg_caps_match.normalize_list [ "a"; "b" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "a"; "!b" ]
        ~actual:(Sg_caps_match.normalize_list [ "a"; "!b" ]);
      ())

let canonicalize_list_cases =
  Oth.test ~name:"canonicalize_list_cases" (fun _ ->
      Oth.Assert.String_list.eq ~expected:[ "!*" ] ~actual:(Sg_caps_match.canonicalize_list []);
      Oth.Assert.String_list.eq
        ~expected:[ "*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "foo.bar"; "baz.zoom"; "*" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "*"; "!a" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "!a" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "!*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "*"; "!*" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "!*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "foo"; "!*" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "a"; "b" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "a"; "b"; "a" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "*"; "!bar" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "*"; "foo"; "!bar" ]);
      (* same-polarity superset absorbs subsets *)
      Oth.Assert.String_list.eq
        ~expected:[ "foo.bar.*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "foo.bar.*"; "foo.bar.baz.*" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "a.*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "a.*"; "a.b"; "a.b.c" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "*"; "!a.*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "*"; "!a.*"; "!a.b.*" ]);
      (* cross-polarity: a negation removes a positive it covers; the negation is then dead against
         the remaining positive and is itself dropped *)
      Oth.Assert.String_list.eq
        ~expected:[ "x.*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "a.b.*"; "x.*"; "!a.*" ]);
      (* a negation is kept when it still excludes part of a surviving positive *)
      Oth.Assert.String_list.eq
        ~expected:[ "a.*"; "!a.b.*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "a.*"; "a.c.*"; "!a.b.*" ]);
      (* landmine: emptying the positives is deny-all, NOT allow-all-except *)
      Oth.Assert.String_list.eq
        ~expected:[ "!*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "a.*"; "!a.*" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "!*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "a.b.*"; "!a.*" ]);
      (* cross-polarity: a negation disjoint from every positive is dropped *)
      Oth.Assert.String_list.eq
        ~expected:[ "a.*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "a.*"; "!b.*" ]);
      Oth.Assert.String_list.eq
        ~expected:[ "a.*"; "!a.b.*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "a.*"; "!a.b.*" ]);
      (* unrelated positives are untouched *)
      Oth.Assert.String_list.eq
        ~expected:[ "a.*"; "b.*" ]
        ~actual:(Sg_caps_match.canonicalize_list [ "a.*"; "b.*" ]);
      (* result is independent of input order *)
      Oth.Assert.String_list.eq
        ~expected:(Sg_caps_match.canonicalize_list [ "foo.bar.*"; "foo.bar.baz.*" ])
        ~actual:(Sg_caps_match.canonicalize_list [ "foo.bar.baz.*"; "foo.bar.*" ]);
      ())

(* canonicalize preserves the meaning evaluated by [matches] *)
let canonicalize_preserves_matches =
  Oth.test ~name:"canonicalize_preserves_matches" (fun _ ->
      let inputs = [ []; [ "!a" ]; [ "foo"; "*" ]; [ "*"; "foo"; "!bar" ]; [ "*"; "!*" ] ] in
      let values = [ "a"; "foo"; "bar"; "other" ] in
      CCList.iter
        (fun pats ->
          let canon = Sg_caps_match.canonicalize_list pats in
          CCList.iter
            (fun v ->
              Oth.Assert.Eq.bool
                ~expected:(Sg_caps_match.matches ~patterns:pats v)
                ~actual:(Sg_caps_match.matches ~patterns:canon v))
            values)
        inputs;
      ())

let grants_all_cases =
  Oth.test ~name:"grants_all_cases" (fun _ ->
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.grants_all [ "*" ]);
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.grants_all []);
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.grants_all [ "!*" ]);
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.grants_all [ "*"; "!a" ]);
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.grants_all [ "a" ]);
      ())

let lookup_cases =
  Oth.test ~name:"lookup_cases" (fun _ ->
      let m = [ ("*", 1); ("a-b-c-d", 2) ] in
      Oth.Assert.Eq.option
        ~eq:Int.equal
        ~pp:CCInt.pp
        ~expected:(Some 2)
        ~actual:(Sg_caps_match.lookup m "a-b-c-d");
      Oth.Assert.Eq.option
        ~eq:Int.equal
        ~pp:CCInt.pp
        ~expected:(Some 1)
        ~actual:(Sg_caps_match.lookup m "other");
      Oth.Assert.none_pp ~pp:CCInt.pp (Sg_caps_match.lookup [ ("a", 2) ] "other");
      ())

let is_negation_cases =
  Oth.test ~name:"is_negation_cases" (fun _ ->
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.is_negation "!a");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.is_negation "a");
      ())

let is_valid_pattern_cases =
  Oth.test ~name:"is_valid_pattern_cases" (fun _ ->
      (* prefix-globs, including partial-segment prefixes *)
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.is_valid_pattern "aws_*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.is_valid_pattern "foo*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.is_valid_pattern "foo.bar.*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.is_valid_pattern "foo.bar");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.is_valid_pattern "*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.is_valid_pattern "!a.*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.is_valid_pattern "");
      (* mid-string stars are rejected *)
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.is_valid_pattern "a*b");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.is_valid_pattern "*.foo");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.is_valid_pattern "foo.*.bar");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.is_valid_pattern "!a*b");
      (* repeated stars are rejected *)
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.is_valid_pattern "a**");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.is_valid_pattern "**");
      (* over-length is rejected *)
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:
          (Sg_caps_match.is_valid_pattern
             (CCString.make (Sg_caps_match.max_pattern_length + 1) 'a'));
      ())

let subsumes_cases =
  Oth.test ~name:"subsumes_cases" (fun _ ->
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.subsumes "*" "x");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.subsumes "aws_*" "aws_s3.*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.subsumes "foo.bar.*" "foo.bar.baz.*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.subsumes "a.*" "a.b");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.subsumes "a" "a");
      Oth.Assert.Eq.bool
        ~expected:false
        ~actual:(Sg_caps_match.subsumes "foo.bar.baz.*" "foo.bar.*");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.subsumes "aws_*" "gcp_*");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.subsumes "a" "b");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.subsumes "a" "ab");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.subsumes "a.b.*" "a.*");
      ())

let intersects_cases =
  Oth.test ~name:"intersects_cases" (fun _ ->
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.intersects "a.*" "a.b.*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.intersects "a.*" "*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.intersects "a.b" "a.*");
      Oth.Assert.Eq.bool ~expected:true ~actual:(Sg_caps_match.intersects "a" "a");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.intersects "a.*" "b.*");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.intersects "a" "b");
      Oth.Assert.Eq.bool ~expected:false ~actual:(Sg_caps_match.intersects "a.b" "a.c");
      (* symmetry *)
      Oth.Assert.Eq.bool
        ~expected:(Sg_caps_match.intersects "a.b" "a.*")
        ~actual:(Sg_caps_match.intersects "a.*" "a.b");
      Oth.Assert.Eq.bool
        ~expected:(Sg_caps_match.intersects "a.*" "b.*")
        ~actual:(Sg_caps_match.intersects "b.*" "a.*");
      ())

module Q = QCheck2

(* A prefix-glob: a short literal over {a, b, .} with an optional trailing "*", optionally negated.
   QCheck2 derives shrinking from these generators, so failures report a minimal counterexample. *)
let alphabet_gen = Q.Gen.oneof_list [ 'a'; 'b'; '.' ]
let literal_gen = Q.Gen.string_size ~gen:alphabet_gen (Q.Gen.int_bound 4)

let pos_glob_gen =
  Q.Gen.map
    (fun (base, star) -> if star then base ^ "*" else base)
    (Q.Gen.pair literal_gen Q.Gen.bool)

let glob_gen =
  Q.Gen.map (fun (neg, g) -> if neg then "!" ^ g else g) (Q.Gen.pair Q.Gen.bool pos_glob_gen)

let list_gen = Q.Gen.list_size (Q.Gen.int_bound 4) glob_gen
let value_gen = Q.Gen.string_size ~gen:alphabet_gen (Q.Gen.int_bound 6)
let count = 1000
let pr_s = Q.Print.string
let pr_list = Q.Print.list Q.Print.string

(* [subsumes a b] must imply containment: anything [b] matches, [a] matches too. *)
let prop_subsumes_containment =
  Oth.test ~name:"prop_subsumes_containment" (fun _ ->
      Q.Test.check_exn
        (Q.Test.make
           ~count
           ~name:"subsumes implies containment"
           ~print:(Q.Print.triple pr_s pr_s pr_s)
           (Q.Gen.triple pos_glob_gen pos_glob_gen value_gen)
           (fun (a, b, v) ->
             (not (Sg_caps_match.subsumes a b))
             || (not (Sg_caps_match.matches ~patterns:[ b ] v))
             || Sg_caps_match.matches ~patterns:[ a ] v)))

(* If a value matches both globs, [intersects] must report them as overlapping. *)
let prop_intersects_sound =
  Oth.test ~name:"prop_intersects_sound" (fun _ ->
      Q.Test.check_exn
        (Q.Test.make
           ~count
           ~name:"intersects is sound"
           ~print:(Q.Print.triple pr_s pr_s pr_s)
           (Q.Gen.triple pos_glob_gen pos_glob_gen value_gen)
           (fun (a, b, v) ->
             (not
                (Sg_caps_match.matches ~patterns:[ a ] v && Sg_caps_match.matches ~patterns:[ b ] v))
             || Sg_caps_match.intersects a b)))

(* THE security invariant: canonicalization never changes who is allowed. *)
let prop_canonicalize_preserves =
  Oth.test ~name:"prop_canonicalize_preserves" (fun _ ->
      Q.Test.check_exn
        (Q.Test.make
           ~count
           ~name:"canonicalize preserves matches"
           ~print:(Q.Print.pair pr_list pr_s)
           (Q.Gen.pair list_gen value_gen)
           (fun (pats, v) ->
             Bool.equal
               (Sg_caps_match.matches ~patterns:pats v)
               (Sg_caps_match.matches ~patterns:(Sg_caps_match.canonicalize_list pats) v))))

(* canonicalization is idempotent *)
let prop_canonicalize_idempotent =
  Oth.test ~name:"prop_canonicalize_idempotent" (fun _ ->
      Q.Test.check_exn
        (Q.Test.make ~count ~name:"canonicalize is idempotent" ~print:pr_list list_gen (fun pats ->
             let canon = Sg_caps_match.canonicalize_list pats in
             CCList.equal CCString.equal canon (Sg_caps_match.canonicalize_list canon))))

(* the canonical form is minimal: no redundant entry remains *)
let prop_canonicalize_minimal =
  let body n = CCString.drop 1 n in
  let distinct_pairs l =
    CCList.flat_map (fun a -> CCList.filter_map (fun b -> if a == b then None else Some (a, b)) l) l
  in
  let minimal canon =
    (* the deny-all form has no positives, so the postconditions below do not apply *)
    CCList.equal CCString.equal canon [ "!*" ]
    ||
    let negs, poss = CCList.partition Sg_caps_match.is_negation canon in
    (* no entry subsumes another of the same polarity *)
    (not (CCList.exists (fun (a, b) -> Sg_caps_match.subsumes a b) (distinct_pairs poss)))
    && (not (CCList.exists (fun (a, b) -> Sg_caps_match.subsumes a b) (distinct_pairs negs)))
    (* no positive is subsumed by a negation, and no negation is disjoint from all positives *)
    && CCList.for_all
         (fun n ->
           (not (CCList.exists (fun p -> Sg_caps_match.subsumes (body n) p) poss))
           && CCList.exists (fun p -> Sg_caps_match.intersects (body n) p) poss)
         negs
  in
  Oth.test ~name:"prop_canonicalize_minimal" (fun _ ->
      Q.Test.check_exn
        (Q.Test.make ~count ~name:"canonicalize is minimal" ~print:pr_list list_gen (fun pats ->
             minimal (Sg_caps_match.canonicalize_list pats))))

(* The cases shared with the TypeScript port of this matcher
   (code/src/hermes/lib/api/capsMatch.test.ts).  This suite is the authority for the semantics; the
   port exists only to gate UI affordances.  Keeping the cases in one file means a change to either
   implementation that alters behaviour fails both suites, instead of the two drifting until a hidden
   button or a spurious 403 surfaces it.

   Add cases to caps-match-fixtures.json, not here. *)
let shared_fixtures =
  let json = Yojson.Safe.from_string [%blob "caps-match-fixtures.json"] in
  let field name json = CCList.assoc ~eq:CCString.equal name (Yojson.Safe.Util.to_assoc json) in
  let strings json = CCList.map Yojson.Safe.Util.to_string (Yojson.Safe.Util.to_list json) in
  let cases name = Yojson.Safe.Util.to_list (field name json) in
  let matches_tests =
    CCList.map
      (fun case ->
        let patterns = strings (field "patterns" case) in
        let value = Yojson.Safe.Util.to_string (field "value" case) in
        let expected = Yojson.Safe.Util.to_bool (field "matches" case) in
        Oth.test
          ~name:(Printf.sprintf "matches [%s] %S" (CCString.concat "; " patterns) value)
          (fun _ -> Oth.Assert.Eq.bool ~expected ~actual:(Sg_caps_match.matches ~patterns value)))
      (cases "matches")
  in
  let grants_all_tests =
    CCList.map
      (fun case ->
        let patterns = strings (field "patterns" case) in
        let expected = Yojson.Safe.Util.to_bool (field "grants_all" case) in
        Oth.test
          ~name:(Printf.sprintf "grants_all [%s]" (CCString.concat "; " patterns))
          (fun _ -> Oth.Assert.Eq.bool ~expected ~actual:(Sg_caps_match.grants_all patterns)))
      (cases "grants_all")
  in
  Oth.parallel (matches_tests @ grants_all_tests)

let test =
  Oth.parallel
    [
      matches_positive;
      matches_star_all;
      matches_negation;
      matches_implicit_star;
      matches_empty_denies;
      matches_glob_negation;
      normalize_list_cases;
      canonicalize_list_cases;
      canonicalize_preserves_matches;
      is_valid_pattern_cases;
      subsumes_cases;
      intersects_cases;
      prop_subsumes_containment;
      prop_intersects_sound;
      prop_canonicalize_preserves;
      prop_canonicalize_idempotent;
      prop_canonicalize_minimal;
      grants_all_cases;
      lookup_cases;
      is_negation_cases;
      shared_fixtures;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
