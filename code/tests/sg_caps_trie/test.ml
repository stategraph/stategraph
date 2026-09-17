(* Tests of [Sg_caps_trie] and ([Sg_caps_trie_scope]). Each property test comes right after a unit test
   that shows examples of the same property. *)

module T = Sg_caps_trie
module P = Sg_caps_trie.Pattern
module S = Sg_caps_trie_scope
module Q = QCheck2

let pattern = Sg_caps_trie_rule_text.pattern
let render_rule = Sg_caps_trie_rule_text.render_rule
let scope = Sg_caps_trie_rule_text.scope

let pairs_to_trie ~default rules =
  T.of_rules ~equal:CCInt.equal ~default (CCList.map (fun (text, v) -> (pattern text, v)) rules)

(* The string is part of the compared text, so that a failure names it. *)
let check_answers ~trie ~expected =
  CCList.iter
    (fun (s, expected) ->
      Oth.Assert.Eq.string
        ~expected:(Printf.sprintf "%S -> %d" s expected)
        ~actual:(Printf.sprintf "%S -> %d" s (T.find trie s)))
    expected

let eq_int_tries = Oth.Assert.eq ~eq:(T.equal CCInt.equal) ~pp:(T.pp Format.pp_print_int)
let eq_scope = Oth.Assert.eq ~eq:S.equal ~pp:S.pp

let matches pattern s =
  match (pattern : P.t) with
  | P.Literal text -> CCString.equal text s
  | P.Prefix text -> CCString.prefix ~pre:text s

(* The reference the trie is checked against: the value of the most specific rule that matches [s],
   or [default] when no rule matches.  Two rules that match the same string with the same specificity
   have the same pattern, and [combine] folds their values in list order. *)
let reference ~default ~combine rules s =
  let specificity = function
    | P.Prefix text -> (CCString.length text, 0)
    | P.Literal text -> (CCString.length text, 1)
  in
  let more_specific a b =
    CCOrd.pair CCInt.compare CCInt.compare (specificity a) (specificity b) > 0
  in
  CCList.fold_left
    (fun best (pattern, v) ->
      match best with
      | _ when not (matches pattern s) -> best
      | None -> Some (pattern, v)
      | Some (best_pattern, w) when P.equal best_pattern pattern -> Some (best_pattern, combine w v)
      | Some (best_pattern, _) when more_specific pattern best_pattern -> Some (pattern, v)
      | Some _ -> best)
    None
    rules
  |> CCOption.map_or ~default snd

(* A small alphabet, so that generated patterns often overlap. *)
let alphabet = [ 'a'; 'b'; '.' ]

(* The strings every property checks: all the strings of at most three characters of [alphabet], and
   each of them followed by the byte 128, which no pattern can contain.

     ""  "a"  "b"  "."  "aa"  "ab"  ...  "b.."  "..."
     "\t"  "a\t"  "b\t"  ".\t"  "aa\t"  ...  "...\t"

   Generated patterns are texts of at most three characters of the same alphabet, so two tries built
   from them answer differently for some string only if they answer differently for one of these: for
   the text of a pattern, or for a string under that text that no other pattern names. *)
let values =
  let extend strings =
    CCList.flat_map (fun s -> CCList.map (fun c -> s ^ CCString.make 1 c) alphabet) strings
  in
  let one = extend [ "" ] in
  let two = extend one in
  let texts = ("" :: one) @ two @ extend two in
  texts @ CCList.map (fun s -> s ^ "\t") texts

let text_gen = Q.Gen.string_size ~gen:(Q.Gen.oneof_list alphabet) (Q.Gen.int_bound 3)

let pattern_gen =
  Q.Gen.map
    (fun (text, prefix) -> pattern (if prefix then text ^ "*" else text))
    (Q.Gen.pair text_gen Q.Gen.bool)

let int_rules_gen = Q.Gen.list_size (Q.Gen.int_bound 5) (Q.Gen.pair pattern_gen (Q.Gen.int_bound 2))
let scope_rules_gen = Q.Gen.list_size (Q.Gen.int_bound 5) (Q.Gen.pair pattern_gen Q.Gen.bool)
let print_int_rules = Q.Print.list (Q.Print.pair P.to_string Q.Print.int)
let print_scope_rules = Q.Print.list render_rule
let count = 1000

let check ~name ~print gen prop =
  Q.Test.check_exn ~rand:(Random.State.make_self_init ()) (Q.Test.make ~count ~name ~print gen prop)

let int_functions = [ ("v mod 2", fun v -> v mod 2); ("v + 1", succ); ("0", fun _ -> 0) ]

let int_operators =
  [ ("x + y", ( + )); ("max x y", CCInt.max); ("10 x + y", fun x y -> (10 * x) + y) ]

let int_predicates =
  [ ("v = 0", CCInt.equal 0); ("v <> 0", fun v -> v <> 0); ("v <= 1", fun v -> v <= 1) ]

(* {1 Patterns} *)

(* Test parsing of patterns *)
let pattern_of_string_examples =
  (* We don't want to expose Pattern's constructors, so we check expected values
     against strings, using this function. *)
  let describe = function
    | P.Literal text -> Printf.sprintf "Literal %S" text
    | P.Prefix text -> Printf.sprintf "Prefix %S" text
  in
  Oth.test ~name:"string_to_pattern" (fun _ ->
      let reads text expected = Oth.Assert.Eq.string ~expected ~actual:(describe (pattern text)) in
      reads "a.*" {|Prefix "a."|};
      reads "a" {|Literal "a"|};
      reads "*" {|Prefix ""|};
      reads "" {|Literal ""|};
      (* A leading "!" is an ordinary character: a pattern does not refuse anything. *)
      reads "!a" {|Literal "!a"|};
      (* A byte above 127 is an ordinary character too, so a pattern may hold UTF-8 text. *)
      reads "caf\195\169" {|Literal "caf\195\169"|};
      let longest = CCString.make P.max_length 'a' in
      reads longest (Printf.sprintf "Literal %S" longest);
      let refuses text =
        let (`Invalid_pattern_err rejected) = Oth.Assert.error (P.of_string text) in
        Oth.Assert.Eq.string ~expected:text ~actual:rejected
      in
      refuses "a*b";
      refuses "a**";
      refuses "*a";
      refuses "a\t";
      refuses (CCString.make (P.max_length + 1) 'a');
      CCList.iter
        (fun text -> Oth.Assert.Eq.string ~expected:text ~actual:(P.to_string (pattern text)))
        [ "a.*"; "a"; "*"; ""; "!a" ];
      ())

(* {1 The trie - structure}

   The canonical form: tries that answer alike are the same tree, and the rules it reads
   back to. Those properties are not essential to what we do with caps. It's nice to have
   a canonical representation of tries, but it's not required for correctness. I've left them
   here, because they hold, but they can be weakened in the future.

   The semantics part of properties is what's required for correctness. *)
module Trie_structure = struct
  let canonical_examples =
    Oth.test ~name:"canonical_examples" (fun _ ->
        let default = 0 in
        (* A rule that changes no answer leaves nothing behind. *)
        eq_int_tries
          (pairs_to_trie ~default [ ("a.*", 1) ])
          (pairs_to_trie ~default [ ("a.*", 1); ("a.b.c", 1) ]);
        eq_int_tries (T.const 0) (pairs_to_trie ~default [ ("a.*", 1); ("a.*", 0) ]);
        (* Tries built by different operations, with the same answers, are equal. *)
        eq_int_tries
          (pairs_to_trie ~default [ ("ab*", 1); ("ac*", 1) ])
          (T.merge
             ~equal:CCInt.equal
             CCInt.max
             (pairs_to_trie ~default [ ("ab*", 1) ])
             (pairs_to_trie ~default [ ("ac*", 1) ]));
        eq_int_tries
          (pairs_to_trie ~default [ ("a.*", 1); ("a.b", 0) ])
          (T.map
             ~equal:CCInt.equal
             (fun v -> v mod 2)
             (pairs_to_trie ~default [ ("a.*", 3); ("a.b", 2) ]));
        (* Answers that become equal leave no node behind. *)
        eq_int_tries
          (T.const 0)
          (T.map ~equal:CCInt.equal (fun _ -> 0) (pairs_to_trie ~default [ ("a.*", 1) ]));
        (* Different answers, different tries. *)
        Oth.Assert.not_true
          (T.equal
             CCInt.equal
             (pairs_to_trie ~default [ ("a", 1) ])
             (pairs_to_trie ~default [ ("a*", 1) ]));
        ())

  let prop_canonical =
    Oth.test ~name:"prop_canonical" (fun _ ->
        check
          ~name:"tries are structurally equal exactly when they give the same answers"
          ~print:(Q.Print.triple print_int_rules print_int_rules fst)
          (Q.Gen.triple int_rules_gen int_rules_gen (Q.Gen.oneof_list int_functions))
          (fun (rules_a, rules_b, (_, f)) ->
            let of_rules = T.of_rules ~equal:CCInt.equal ~default:0 in
            let a = of_rules rules_a in
            let b = of_rules rules_b in
            let same_answers =
              CCList.for_all (fun s -> CCInt.equal (T.find a s) (T.find b s)) values
            in
            CCBool.equal same_answers (T.equal CCInt.equal a b)
            (* The same answers, built in different ways. *)
            && T.equal
                 CCInt.equal
                 (T.map ~equal:CCInt.equal f a)
                 (T.of_rules
                    ~equal:CCInt.equal
                    ~default:(f 0)
                    (CCList.map (fun (p, v) -> (p, f v)) rules_a))
            && T.equal CCInt.equal (T.merge ~equal:CCInt.equal (fun x _ -> x) a b) a
            && T.equal
                 CCInt.equal
                 (T.merge ~equal:CCInt.equal CCInt.max a b)
                 (T.merge ~equal:CCInt.equal CCInt.max b a));
        ())

  let order_independent_examples =
    Oth.test ~name:"order_independent_examples" (fun _ ->
        eq_int_tries
          (pairs_to_trie ~default:0 [ ("a.*", 1); ("a.b", 2) ])
          (pairs_to_trie ~default:0 [ ("a.b", 2); ("a.*", 1) ]);
        eq_int_tries
          (pairs_to_trie ~default:0 [ ("ab", 2); ("a*", 1); ("abc*", 3) ])
          (pairs_to_trie ~default:0 [ ("abc*", 3); ("ab", 2); ("a*", 1) ]);
        ())

  let prop_order_independent =
    Oth.test ~name:"prop_order_independent" (fun _ ->
        check
          ~name:"of_rules does not depend on the order of rules with different patterns"
          ~print:print_int_rules
          int_rules_gen
          (fun rules ->
            (* A stable sort keeps rules with the same pattern in their order. *)
            let sorted =
              CCList.stable_sort
                (fun (a, _) (b, _) -> CCString.compare (P.to_string a) (P.to_string b))
                rules
            in
            T.equal
              CCInt.equal
              (T.of_rules ~equal:CCInt.equal ~default:0 rules)
              (T.of_rules ~equal:CCInt.equal ~default:0 sorted));
        ())

  let render_int_rules rules =
    CCList.map (fun (p, v) -> Printf.sprintf "%s -> %d" (P.to_string p) v) rules

  let to_rules_examples =
    Oth.test ~name:"to_rules_examples" (fun _ ->
        let rules_of t = render_int_rules (T.to_rules ~equal:CCInt.equal t) in
        Oth.Assert.Eq.string_list
          ~expected:[ "* -> 0"; "a.* -> 1"; "a.b -> 2" ]
          ~actual:(rules_of (pairs_to_trie ~default:0 [ ("a.*", 1); ("a.b", 2); ("a.b.c", 1) ]));
        Oth.Assert.Eq.string_list
          ~expected:[ "* -> 0"; "ab* -> 1"; "ab -> 2" ]
          ~actual:(rules_of (pairs_to_trie ~default:0 [ ("ab", 2); ("ab*", 1) ]));
        Oth.Assert.Eq.string_list ~expected:[ "* -> 5" ] ~actual:(rules_of (T.const 5));
        (* Reading the rules back gives the same trie, whatever the default. *)
        let t = pairs_to_trie ~default:0 [ ("a.*", 1); ("a.b", 2) ] in
        eq_int_tries t (T.of_rules ~equal:CCInt.equal ~default:7 (T.to_rules ~equal:CCInt.equal t));
        ())

  let prop_to_rules =
    Oth.test ~name:"prop_to_rules" (fun _ ->
        check
          ~name:"of_rules ~default (to_rules t) is t, whatever the default"
          ~print:(Q.Print.pair print_int_rules Q.Print.int)
          (Q.Gen.pair int_rules_gen (Q.Gen.int_bound 2))
          (fun (rules, default) ->
            let t = T.of_rules ~equal:CCInt.equal ~default:0 rules in
            T.equal
              CCInt.equal
              t
              (T.of_rules ~equal:CCInt.equal ~default (T.to_rules ~equal:CCInt.equal t)));
        ())

  let to_rules_minimal_examples =
    Oth.test ~name:"to_rules_minimal_examples" (fun _ ->
        (* to_rules gives [* -> 0; a.* -> 1; a.b -> 2]: dropping a rule after the first changes the trie. *)
        let t = pairs_to_trie ~default:0 [ ("a.*", 1); ("a.b", 2) ] in
        Oth.Assert.not_true
          (T.equal CCInt.equal t (pairs_to_trie ~default:0 [ ("*", 0); ("a.b", 2) ]));
        Oth.Assert.not_true
          (T.equal CCInt.equal t (pairs_to_trie ~default:0 [ ("*", 0); ("a.*", 1) ]));
        ())

  let prop_to_rules_minimal =
    Oth.test ~name:"prop_to_rules_minimal" (fun _ ->
        check
          ~name:"to_rules starts with the * rule, and every later rule changes the trie"
          ~print:print_int_rules
          int_rules_gen
          (fun rules ->
            let t = T.of_rules ~equal:CCInt.equal ~default:0 rules in
            match T.to_rules ~equal:CCInt.equal t with
            | [] -> false
            | ((first, _) as root) :: rest ->
                CCString.equal (P.to_string first) "*"
                && CCList.for_all
                     (fun i ->
                       not
                         (T.equal
                            CCInt.equal
                            t
                            (T.of_rules
                               ~equal:CCInt.equal
                               ~default:0
                               (root :: CCList.remove_at_idx i rest))))
                     (CCList.range' 0 (CCList.length rest)));
        ())

  let tests =
    [
      canonical_examples;
      prop_canonical;
      order_independent_examples;
      prop_order_independent;
      to_rules_examples;
      prop_to_rules;
      to_rules_minimal_examples;
      prop_to_rules_minimal;
    ]
end

(* {1 The trie - semantics}

   What a trie answers, judged by [find] against a reference, and the algebra of the
   operations, judged by the answers alone. *)
module Trie_semantics = struct
  let of_rules_examples =
    Oth.test ~name:"of_rules_examples" (fun _ ->
        let default = 0 in
        (* The most specific pattern that matches decides. No pattern matches: the default. *)
        check_answers
          ~trie:(pairs_to_trie ~default [ ("a.*", 1); ("a.b", 2) ])
          ~expected:
            [ ("a", 0); ("a.", 1); ("a.x", 1); ("a.b", 2); ("a.b.c", 1); ("a.\t", 1); ("b", 0) ];
        (* A rule inside a prefix can be overridden again inside its own prefix. *)
        check_answers
          ~trie:(pairs_to_trie ~default [ ("a.*", 1); ("a.b*", 2); ("a.b.c", 3) ])
          ~expected:[ ("a.b", 2); ("a.bx", 2); ("a.b.c", 3); ("a.b.cd", 2); ("a.c", 1) ];
        (* A literal is more specific than a prefix of the same text, whatever their order. *)
        check_answers
          ~trie:(pairs_to_trie ~default [ ("ab", 2); ("ab*", 1) ])
          ~expected:[ ("ab", 2); ("abc", 1); ("a", 0) ];
        check_answers
          ~trie:(pairs_to_trie ~default [ ("", 2); ("*", 1) ])
          ~expected:[ ("", 2); ("x", 1) ];
        (* The same pattern twice: the last one wins. *)
        check_answers ~trie:(pairs_to_trie ~default [ ("a", 1); ("a", 2) ]) ~expected:[ ("a", 2) ];
        ())

  let prop_of_rules =
    Oth.test ~name:"prop_of_rules" (fun _ ->
        check
          ~name:"find (of_rules rules) gives the value of the most specific matching rule"
          ~print:print_int_rules
          int_rules_gen
          (fun rules ->
            let t = T.of_rules ~equal:CCInt.equal ~default:0 rules in
            CCList.for_all
              (fun s ->
                CCInt.equal (T.find t s) (reference ~default:0 ~combine:(fun _ v -> v) rules s))
              values);
        ())

  let override_examples =
    Oth.test ~name:"override_examples" (fun _ ->
        let default = 0 in
        let t = pairs_to_trie ~default [ ("a.*", 1) ] in
        check_answers
          ~trie:(T.override ~equal:CCInt.equal ~answer:2 ~on:(pattern "a.b*") ~base:t)
          ~expected:[ ("a.x", 1); ("a.b", 2); ("a.bc", 2); ("b", 0) ];
        check_answers
          ~trie:(T.override ~equal:CCInt.equal ~answer:3 ~on:(pattern "a.") ~base:t)
          ~expected:[ ("a.", 3); ("a.x", 1) ];
        (* [override] also replaces the more specific answers already under the pattern. *)
        check_answers
          ~trie:
            (T.override
               ~equal:CCInt.equal
               ~answer:5
               ~on:(pattern "a*")
               ~base:(pairs_to_trie ~default [ ("a.b", 2) ]))
          ~expected:[ ("a.b", 5); ("b", 0) ];
        ())

  let prop_override =
    Oth.test ~name:"prop_override" (fun _ ->
        check
          ~name:
            "override ~answer:v ~on:p ~base:t answers v where p matches, and what t answers \
             elsewhere"
          ~print:(Q.Print.triple print_int_rules P.to_string Q.Print.int)
          (Q.Gen.triple int_rules_gen pattern_gen (Q.Gen.int_bound 2))
          (fun (rules, p, v) ->
            let t = T.of_rules ~equal:CCInt.equal ~default:0 rules in
            let updated = T.override ~equal:CCInt.equal ~answer:v ~on:p ~base:t in
            CCList.for_all
              (fun s -> CCInt.equal (T.find updated s) (if matches p s then v else T.find t s))
              values);
        ())

  let map_examples =
    Oth.test ~name:"map_examples" (fun _ ->
        let t = pairs_to_trie ~default:0 [ ("a.*", 1); ("a.b", 2) ] in
        check_answers
          ~trie:(T.map ~equal:CCInt.equal (fun v -> v * 10) t)
          ~expected:[ ("a.x", 10); ("a.b", 20); ("b", 0) ];
        ())

  let prop_map =
    Oth.test ~name:"prop_map" (fun _ ->
        check
          ~name:"map f t answers f of what t answers"
          ~print:(Q.Print.pair print_int_rules fst)
          (Q.Gen.pair int_rules_gen (Q.Gen.oneof_list int_functions))
          (fun (rules, (_, f)) ->
            let t = T.of_rules ~equal:CCInt.equal ~default:0 rules in
            let mapped = T.map ~equal:CCInt.equal f t in
            CCList.for_all (fun s -> CCInt.equal (T.find mapped s) (f (T.find t s))) values);
        ())

  let merge_examples =
    Oth.test ~name:"merge_examples" (fun _ ->
        let a = pairs_to_trie ~default:0 [ ("a.*", 1); ("a.x.*", 0) ] in
        let b = pairs_to_trie ~default:0 [ ("a.x.foo", 1) ] in
        check_answers
          ~trie:(T.merge ~equal:CCInt.equal CCInt.max a b)
          ~expected:[ ("a.x.foo", 1); ("a.x.bar", 0); ("a.y", 1); ("b", 0) ];
        (* Both answers reach the function: tens from [a], units from [b]. *)
        check_answers
          ~trie:(T.merge ~equal:CCInt.equal (fun x y -> (10 * x) + y) a b)
          ~expected:[ ("a.x.foo", 1); ("a.y", 10); ("b", 0) ];
        (* Edges that share only part of their label. *)
        check_answers
          ~trie:
            (T.merge
               ~equal:CCInt.equal
               ( + )
               (pairs_to_trie ~default:0 [ ("ab*", 1) ])
               (pairs_to_trie ~default:0 [ ("ac*", 2) ]))
          ~expected:[ ("a", 0); ("ab", 1); ("ac", 2); ("ad", 0) ];
        ())

  let prop_merge =
    Oth.test ~name:"prop_merge" (fun _ ->
        check
          ~name:"merge f a b answers f of what a and b answer"
          ~print:(Q.Print.triple print_int_rules print_int_rules fst)
          (Q.Gen.triple int_rules_gen int_rules_gen (Q.Gen.oneof_list int_operators))
          (fun (rules_a, rules_b, (_, f)) ->
            let a = T.of_rules ~equal:CCInt.equal ~default:0 rules_a in
            let b = T.of_rules ~equal:CCInt.equal ~default:0 rules_b in
            let merged = T.merge ~equal:CCInt.equal f a b in
            CCList.for_all
              (fun s -> CCInt.equal (T.find merged s) (f (T.find a s) (T.find b s)))
              values);
        ())

  let for_all_examples =
    Oth.test ~name:"for_all_examples" (fun _ ->
        let t = pairs_to_trie ~default:0 [ ("a.*", 1); ("a.b", 2) ] in
        Oth.Assert.true_ (T.for_all (fun v -> v <= 2) t);
        (* "b" answers the default 0. *)
        Oth.Assert.not_true (T.for_all (fun v -> v > 0) t);
        (* Only "a.b" answers 2. *)
        Oth.Assert.not_true (T.for_all (fun v -> v <> 2) t);
        Oth.Assert.true_ (T.for_all (CCInt.equal 3) (T.const 3));
        ())

  let prop_for_all =
    Oth.test ~name:"prop_for_all" (fun _ ->
        check
          ~name:"for_all p t holds exactly when p holds for every answer of t"
          ~print:(Q.Print.pair print_int_rules fst)
          (Q.Gen.pair int_rules_gen (Q.Gen.oneof_list int_predicates))
          (fun (rules, (_, p)) ->
            let t = T.of_rules ~equal:CCInt.equal ~default:0 rules in
            CCBool.equal (T.for_all p t) (CCList.for_all (fun s -> p (T.find t s)) values));
        ())

  (* The answers of [t] for every string of [values], as text, so that a failure names the string. *)
  let answers_of t = CCList.map (fun s -> Printf.sprintf "%S -> %d" s (T.find t s)) values
  let same_answers a b = Sln_list.String.equal (answers_of a) (answers_of b)

  let check_same_answers ~expected ~actual =
    Oth.Assert.Eq.string_list ~expected:(answers_of expected) ~actual:(answers_of actual)

  let commutative_operators = [ ("x + y", ( + )); ("max x y", CCInt.max) ]

  let associative_operators =
    [ ("x + y", ( + )); ("max x y", CCInt.max); ("x", fun x _ -> x); ("y", fun _ y -> y) ]

  let merge_commutative_examples =
    Oth.test ~name:"merge_commutative_examples" (fun _ ->
        let a = pairs_to_trie ~default:0 [ ("a.*", 1); ("a.x.*", 0) ] in
        let b = pairs_to_trie ~default:0 [ ("a.x.foo", 2) ] in
        check_same_answers
          ~expected:(T.merge ~equal:CCInt.equal CCInt.max a b)
          ~actual:(T.merge ~equal:CCInt.equal CCInt.max b a);
        (* [10 x + y] is not commutative, and the two merges answer differently. *)
        Oth.Assert.not_true
          (same_answers
             (T.merge ~equal:CCInt.equal (fun x y -> (10 * x) + y) a b)
             (T.merge ~equal:CCInt.equal (fun x y -> (10 * x) + y) b a));
        ())

  let prop_merge_commutative =
    Oth.test ~name:"prop_merge_commutative" (fun _ ->
        check
          ~name:"merge f a b and merge f b a answer alike when f is commutative"
          ~print:(Q.Print.triple print_int_rules print_int_rules fst)
          (Q.Gen.triple int_rules_gen int_rules_gen (Q.Gen.oneof_list commutative_operators))
          (fun (rules_a, rules_b, (_, f)) ->
            let a = T.of_rules ~equal:CCInt.equal ~default:0 rules_a in
            let b = T.of_rules ~equal:CCInt.equal ~default:0 rules_b in
            same_answers (T.merge ~equal:CCInt.equal f a b) (T.merge ~equal:CCInt.equal f b a));
        ())

  let merge_associative_examples =
    Oth.test ~name:"merge_associative_examples" (fun _ ->
        let a = pairs_to_trie ~default:0 [ ("a.*", 1) ] in
        let b = pairs_to_trie ~default:0 [ ("a.b*", 2) ] in
        let c = pairs_to_trie ~default:0 [ ("a.b.c", 3) ] in
        let merge = T.merge ~equal:CCInt.equal ( + ) in
        check_same_answers ~expected:(merge (merge a b) c) ~actual:(merge a (merge b c));
        check_answers
          ~trie:(merge (merge a b) c)
          ~expected:[ ("a.b.c", 6); ("a.b.x", 3); ("a.y", 1); ("b", 0) ];
        ())

  let prop_merge_associative =
    Oth.test ~name:"prop_merge_associative" (fun _ ->
        check
          ~name:"the two groupings of merge f answer alike when f is associative"
          ~print:(Q.Print.pair (Q.Print.triple print_int_rules print_int_rules print_int_rules) fst)
          (Q.Gen.pair
             (Q.Gen.triple int_rules_gen int_rules_gen int_rules_gen)
             (Q.Gen.oneof_list associative_operators))
          (fun ((rules_a, rules_b, rules_c), (_, f)) ->
            let of_rules = T.of_rules ~equal:CCInt.equal ~default:0 in
            let a = of_rules rules_a in
            let b = of_rules rules_b in
            let c = of_rules rules_c in
            let merge = T.merge ~equal:CCInt.equal f in
            same_answers (merge (merge a b) c) (merge a (merge b c)));
        ())

  let merge_idempotent_examples =
    Oth.test ~name:"merge_idempotent_examples" (fun _ ->
        let a = pairs_to_trie ~default:0 [ ("a.*", 1); ("a.b", 2) ] in
        check_same_answers ~expected:a ~actual:(T.merge ~equal:CCInt.equal CCInt.max a a);
        ())

  let prop_merge_idempotent =
    Oth.test ~name:"prop_merge_idempotent" (fun _ ->
        check
          ~name:"merge max a a answers like a"
          ~print:print_int_rules
          int_rules_gen
          (fun rules ->
            let a = T.of_rules ~equal:CCInt.equal ~default:0 rules in
            same_answers (T.merge ~equal:CCInt.equal CCInt.max a a) a);
        ())

  let merge_projections_examples =
    Oth.test ~name:"merge_projections_examples" (fun _ ->
        let a = pairs_to_trie ~default:0 [ ("a.*", 1); ("a.b", 2) ] in
        let b = pairs_to_trie ~default:0 [ ("a.b*", 3) ] in
        check_same_answers ~expected:a ~actual:(T.merge ~equal:CCInt.equal (fun x _ -> x) a b);
        check_same_answers ~expected:b ~actual:(T.merge ~equal:CCInt.equal (fun _ y -> y) a b);
        ())

  let prop_merge_projections =
    Oth.test ~name:"prop_merge_projections" (fun _ ->
        check
          ~name:"merge keeps one side when f keeps one side"
          ~print:(Q.Print.pair print_int_rules print_int_rules)
          (Q.Gen.pair int_rules_gen int_rules_gen)
          (fun (rules_a, rules_b) ->
            let a = T.of_rules ~equal:CCInt.equal ~default:0 rules_a in
            let b = T.of_rules ~equal:CCInt.equal ~default:0 rules_b in
            same_answers (T.merge ~equal:CCInt.equal (fun x _ -> x) a b) a
            && same_answers (T.merge ~equal:CCInt.equal (fun _ y -> y) a b) b);
        ())

  let map_over_merge_examples =
    Oth.test ~name:"map_over_merge_examples" (fun _ ->
        let a = pairs_to_trie ~default:0 [ ("a.*", 1) ] in
        let b = pairs_to_trie ~default:0 [ ("a.b*", 2) ] in
        let tenfold v = v * 10 in
        check_same_answers
          ~expected:(T.map ~equal:CCInt.equal tenfold (T.merge ~equal:CCInt.equal ( + ) a b))
          ~actual:(T.merge ~equal:CCInt.equal (fun x y -> tenfold (x + y)) a b);
        check_answers
          ~trie:(T.map ~equal:CCInt.equal tenfold (T.merge ~equal:CCInt.equal ( + ) a b))
          ~expected:[ ("a.b", 30); ("a.x", 10); ("b", 0) ];
        ())

  let prop_map_over_merge =
    Oth.test ~name:"prop_map_over_merge" (fun _ ->
        check
          ~name:"mapping the merge answers like merging with the mapped function"
          ~print:
            (Q.Print.pair (Q.Print.pair print_int_rules print_int_rules) (Q.Print.pair fst fst))
          (Q.Gen.pair
             (Q.Gen.pair int_rules_gen int_rules_gen)
             (Q.Gen.pair (Q.Gen.oneof_list int_operators) (Q.Gen.oneof_list int_functions)))
          (fun ((rules_a, rules_b), ((_, f), (_, g))) ->
            let a = T.of_rules ~equal:CCInt.equal ~default:0 rules_a in
            let b = T.of_rules ~equal:CCInt.equal ~default:0 rules_b in
            same_answers
              (T.map ~equal:CCInt.equal g (T.merge ~equal:CCInt.equal f a b))
              (T.merge ~equal:CCInt.equal (fun x y -> g (f x y)) a b));
        ())

  let override_last_wins_examples =
    Oth.test ~name:"override_last_wins_examples" (fun _ ->
        let t = pairs_to_trie ~default:0 [ ("a.*", 1) ] in
        let on = pattern "a.b*" in
        let override answer base = T.override ~equal:CCInt.equal ~answer ~on ~base in
        check_same_answers ~expected:(override 2 t) ~actual:(override 2 (override 1 t));
        check_answers ~trie:(override 2 (override 1 t)) ~expected:[ ("a.b", 2); ("a.x", 1) ];
        ())

  let prop_override_last_wins =
    Oth.test ~name:"prop_override_last_wins" (fun _ ->
        check
          ~name:"overriding twice on one pattern answers like overriding once with the last answer"
          ~print:
            (Q.Print.pair
               (Q.Print.pair print_int_rules P.to_string)
               (Q.Print.pair Q.Print.int Q.Print.int))
          (Q.Gen.pair
             (Q.Gen.pair int_rules_gen pattern_gen)
             (Q.Gen.pair (Q.Gen.int_bound 2) (Q.Gen.int_bound 2)))
          (fun ((rules, on), (first, last)) ->
            let base = T.of_rules ~equal:CCInt.equal ~default:0 rules in
            let override answer base = T.override ~equal:CCInt.equal ~answer ~on ~base in
            same_answers (override last (override first base)) (override last base));
        ())

  let override_everything_examples =
    Oth.test ~name:"override_everything_examples" (fun _ ->
        let t = pairs_to_trie ~default:0 [ ("a.*", 1); ("a.b", 2) ] in
        check_same_answers
          ~expected:(T.const 7)
          ~actual:(T.override ~equal:CCInt.equal ~answer:7 ~on:(pattern "*") ~base:t);
        ())

  let prop_override_everything =
    Oth.test ~name:"prop_override_everything" (fun _ ->
        check
          ~name:"overriding on * answers like the constant trie"
          ~print:(Q.Print.pair print_int_rules Q.Print.int)
          (Q.Gen.pair int_rules_gen (Q.Gen.int_bound 2))
          (fun (rules, answer) ->
            let base = T.of_rules ~equal:CCInt.equal ~default:0 rules in
            same_answers
              (T.override ~equal:CCInt.equal ~answer ~on:(pattern "*") ~base)
              (T.const answer));
        ())

  let tests =
    [
      of_rules_examples;
      prop_of_rules;
      override_examples;
      prop_override;
      map_examples;
      prop_map;
      merge_examples;
      prop_merge;
      for_all_examples;
      prop_for_all;
      merge_commutative_examples;
      prop_merge_commutative;
      merge_associative_examples;
      prop_merge_associative;
      merge_idempotent_examples;
      prop_merge_idempotent;
      merge_projections_examples;
      prop_merge_projections;
      map_over_merge_examples;
      prop_map_over_merge;
      override_last_wins_examples;
      prop_override_last_wins;
      override_everything_examples;
      prop_override_everything;
    ]
end

(* {1 Scopes - structure}

   The same laws, judged by structural equality: scopes that contain the same strings are
   the same tree.

   Those properties are not essential to what we do with caps. It's nice to have
   them, but they are not required for correctness. I've left them
   here, because they hold, but they can be weakened in the future.

   The semantics part of properties is what's required for correctness. *)
module Scope_structure = struct
  let lattice_laws_structure_examples =
    Oth.test ~name:"lattice_laws_structure_examples" (fun _ ->
        (* The grouping that made flat allow-lists non-associative (#2284). *)
        let a = scope [ "*"; "!b*" ] in
        let b = scope [ "ba" ] in
        let c = scope [ "*"; "!b" ] in
        eq_scope (scope [ "*"; "!b" ]) (S.union (S.union a b) c);
        eq_scope (scope [ "*"; "!b" ]) (S.union a (S.union b c));
        eq_scope (S.union a b) (S.union b a);
        eq_scope a (S.union a (S.inter a b));
        eq_scope (S.inter a (S.union b c)) (S.union (S.inter a b) (S.inter a c));
        ())

  let prop_lattice_laws_structure =
    Oth.test ~name:"prop_lattice_laws_structure" (fun _ ->
        check
          ~name:"union and inter are associative, commutative, idempotent, absorbing, distributive"
          ~print:(Q.Print.triple print_scope_rules print_scope_rules print_scope_rules)
          (Q.Gen.triple scope_rules_gen scope_rules_gen scope_rules_gen)
          (fun (rules_a, rules_b, rules_c) ->
            let a = S.of_rules rules_a in
            let b = S.of_rules rules_b in
            let c = S.of_rules rules_c in
            S.equal (S.union (S.union a b) c) (S.union a (S.union b c))
            && S.equal (S.inter (S.inter a b) c) (S.inter a (S.inter b c))
            && S.equal (S.union a b) (S.union b a)
            && S.equal (S.inter a b) (S.inter b a)
            && S.equal (S.union a a) a
            && S.equal (S.inter a a) a
            && S.equal (S.union a (S.inter a b)) a
            && S.equal (S.inter a (S.union a b)) a
            && S.equal (S.inter a (S.union b c)) (S.union (S.inter a b) (S.inter a c))
            && S.equal (S.union a (S.inter b c)) (S.inter (S.union a b) (S.union a c)));
        ())

  let complement_laws_structure_examples =
    Oth.test ~name:"complement_laws_structure_examples" (fun _ ->
        let a = scope [ "a.*"; "!a.b" ] in
        let b = scope [ "a.x*" ] in
        eq_scope a (S.union S.empty a);
        eq_scope S.empty (S.inter S.empty a);
        eq_scope a (S.inter S.full a);
        eq_scope S.full (S.union S.full a);
        eq_scope S.full (S.union a (S.compl a));
        eq_scope S.empty (S.inter a (S.compl a));
        eq_scope a (S.compl (S.compl a));
        eq_scope (S.inter (S.compl a) (S.compl b)) (S.compl (S.union a b));
        eq_scope (S.inter a (S.compl b)) (S.diff a b);
        ())

  let prop_complement_laws_structure =
    Oth.test ~name:"prop_complement_laws_structure" (fun _ ->
        check
          ~name:"empty and full are identities, compl and diff follow the laws of sets"
          ~print:(Q.Print.pair print_scope_rules print_scope_rules)
          (Q.Gen.pair scope_rules_gen scope_rules_gen)
          (fun (rules_a, rules_b) ->
            let a = S.of_rules rules_a in
            let b = S.of_rules rules_b in
            S.equal (S.union S.empty a) a
            && S.equal (S.inter S.empty a) S.empty
            && S.equal (S.inter S.full a) a
            && S.equal (S.union S.full a) S.full
            && S.equal (S.union a (S.compl a)) S.full
            && S.equal (S.inter a (S.compl a)) S.empty
            && S.equal (S.compl (S.compl a)) a
            && S.equal (S.compl (S.union a b)) (S.inter (S.compl a) (S.compl b))
            && S.equal (S.compl (S.inter a b)) (S.union (S.compl a) (S.compl b))
            && S.equal (S.diff a b) (S.inter a (S.compl b)));
        ())

  let tests =
    [
      lattice_laws_structure_examples;
      prop_lattice_laws_structure;
      complement_laws_structure_examples;
      prop_complement_laws_structure;
    ]
end

(* {1 Scopes - semantics}

   What a scope contains, judged by [mem], and the laws of the set operations. *)
module Scope_semantics = struct
  let members ~scope ~expected =
    CCList.iter
      (fun (s, expected) ->
        Oth.Assert.Eq.string
          ~expected:(Printf.sprintf "%S -> %b" s expected)
          ~actual:(Printf.sprintf "%S -> %b" s (S.mem scope s)))
      expected

  let scope_of_rules_examples =
    Oth.test ~name:"scope_of_rules_examples" (fun _ ->
        members
          ~scope:(scope [ "a.*"; "!a.b"; "a.b.c" ])
          ~expected:[ ("a.", true); ("a.x", true); ("a.b", false); ("a.b.c", true); ("b", false) ];
        members
          ~scope:(scope [ "a.*"; "!a.b*"; "a.b.c" ])
          ~expected:[ ("a.b", false); ("a.bc", false); ("a.b.c", true); ("a.c", true) ];
        (* A string that no rule matches is refused. *)
        members ~scope:(scope []) ~expected:[ ("", false); ("a", false); ("a.b", false) ];
        (* The same pattern both allowed and refused is refused, whatever the order. *)
        members ~scope:(scope [ "a"; "!a" ]) ~expected:[ ("a", false) ];
        members ~scope:(scope [ "!a"; "a" ]) ~expected:[ ("a", false) ];
        ())

  let prop_scope_of_rules =
    Oth.test ~name:"prop_scope_of_rules" (fun _ ->
        check
          ~name:"mem (of_rules rules) is the most specific matching rule, refusal first"
          ~print:print_scope_rules
          scope_rules_gen
          (fun rules ->
            let t = S.of_rules rules in
            CCList.for_all
              (fun s -> CCBool.equal (S.mem t s) (reference ~default:false ~combine:( && ) rules s))
              values);
        ())

  let set_operations_examples =
    Oth.test ~name:"set_operations_examples" (fun _ ->
        (* A string allowed by one scope, inside a prefix the other scope refuses, is kept, and only
           that string. *)
        members
          ~scope:(S.union (scope [ "a.*"; "!a.x.*" ]) (scope [ "a.x.foo" ]))
          ~expected:[ ("a.x.foo", true); ("a.x.bar", false); ("a.y", true) ];
        members
          ~scope:(S.inter (scope [ "a.*" ]) (scope [ "*"; "!a.b*" ]))
          ~expected:[ ("a.x", true); ("a.b", false); ("a.bc", false); ("b", false) ];
        members
          ~scope:(S.diff (scope [ "a.*" ]) (scope [ "a.b" ]))
          ~expected:[ ("a.b", false); ("a.bc", true); ("b", false) ];
        members
          ~scope:(S.compl (scope [ "a.*" ]))
          ~expected:[ ("a.x", false); ("a", true); ("", true) ];
        ())

  let prop_set_operations =
    Oth.test ~name:"prop_set_operations" (fun _ ->
        check
          ~name:"union, inter, diff and compl contain exactly the expected strings"
          ~print:(Q.Print.pair print_scope_rules print_scope_rules)
          (Q.Gen.pair scope_rules_gen scope_rules_gen)
          (fun (rules_a, rules_b) ->
            let a = S.of_rules rules_a in
            let b = S.of_rules rules_b in
            CCList.for_all
              (fun s ->
                CCBool.equal (S.mem (S.union a b) s) (S.mem a s || S.mem b s)
                && CCBool.equal (S.mem (S.inter a b) s) (S.mem a s && S.mem b s)
                && CCBool.equal (S.mem (S.diff a b) s) (S.mem a s && not (S.mem b s))
                && CCBool.equal (S.mem (S.compl a) s) (not (S.mem a s)))
              values);
        ())

  let subset_examples =
    Oth.test ~name:"subset_examples" (fun _ ->
        Oth.Assert.true_ (S.subset (scope [ "t1" ]) (scope [ "t*" ]));
        Oth.Assert.not_true (S.subset (scope [ "t*" ]) (scope [ "t1" ]));
        Oth.Assert.true_ (S.subset (scope [ "a.*"; "!a.b" ]) (scope [ "a.*" ]));
        Oth.Assert.not_true (S.subset (scope [ "a.*" ]) (scope [ "a.*"; "!a.b" ]));
        Oth.Assert.true_ (S.subset S.empty (scope [ "t1" ]));
        Oth.Assert.true_ (S.subset (scope [ "t1" ]) S.full);
        ())

  let prop_subset =
    Oth.test ~name:"prop_subset" (fun _ ->
        check
          ~name:"subset a b holds exactly when b contains every string of a"
          ~print:(Q.Print.pair print_scope_rules print_scope_rules)
          (Q.Gen.pair scope_rules_gen scope_rules_gen)
          (fun (rules_a, rules_b) ->
            let a = S.of_rules rules_a in
            let b = S.of_rules rules_b in
            let contained = CCList.for_all (fun s -> (not (S.mem a s)) || S.mem b s) values in
            CCBool.equal (S.subset a b) contained
            && CCBool.equal (S.subset a b) (S.equal (S.inter a b) a));
        ())

  let is_empty_is_full_examples =
    Oth.test ~name:"is_empty_is_full_examples" (fun _ ->
        Oth.Assert.true_ (S.is_empty S.empty);
        Oth.Assert.true_ (S.is_full S.full);
        Oth.Assert.not_true (S.is_empty (scope [ "a" ]));
        Oth.Assert.not_true (S.is_full (scope [ "a" ]));
        Oth.Assert.not_true (S.is_full (scope [ "*"; "!a" ]));
        Oth.Assert.true_ (S.is_empty (scope [ "a"; "!a" ]));
        Oth.Assert.true_ (S.is_full (S.union (scope [ "a*" ]) (scope [ "*"; "!a*" ])));
        ())

  let prop_is_empty_is_full =
    Oth.test ~name:"prop_is_empty_is_full" (fun _ ->
        check
          ~name:"is_empty and is_full hold exactly when no string, or every string, is contained"
          ~print:print_scope_rules
          scope_rules_gen
          (fun rules ->
            let t = S.of_rules rules in
            let contained = CCList.map (S.mem t) values in
            CCBool.equal (S.is_empty t) (CCList.for_all not contained)
            && CCBool.equal (S.is_full t) (CCList.for_all CCFun.id contained)
            && CCBool.equal (S.is_empty t) (S.equal t S.empty)
            && CCBool.equal (S.is_full t) (S.equal t S.full));
        ())

  let show_literals = function
    | `Literals literals -> Printf.sprintf "Literals [%s]" (CCString.concat "; " literals)
    | `Infinite -> "Infinite"

  let literals_examples =
    Oth.test ~name:"literals_examples" (fun _ ->
        let literals expected t =
          Oth.Assert.Eq.string ~expected ~actual:(show_literals (S.literals t))
        in
        literals "Literals [t1; t2]" (scope [ "t2"; "t1" ]);
        literals "Literals [a; a.b]" (scope [ "a.b"; "a" ]);
        literals "Literals []" S.empty;
        literals "Infinite" S.full;
        literals "Infinite" (scope [ "t*" ]);
        literals "Infinite" (scope [ "*"; "!t1" ]);
        ())

  let prop_literals =
    Oth.test ~name:"prop_literals" (fun _ ->
        check
          ~name:"literals lists the strings of a finite scope in order, or tells it is infinite"
          ~print:print_scope_rules
          scope_rules_gen
          (fun rules ->
            let t = S.of_rules rules in
            (* [literals] gives its strings in order, so the strings of [values] are sorted here. *)
            let contained = Sln_list.String.sort (CCList.filter (S.mem t) values) in
            (* A string that contains a byte no pattern contains is under a prefix rule. *)
            let under_a_prefix = CCList.exists (fun s -> CCString.contains s '\t') contained in
            match S.literals t with
            | `Infinite -> under_a_prefix
            | `Literals literals -> Sln_list.String.equal literals contained);
        ())

  (* What [scope] contains, for every string of [values], as text. *)
  let members_of scope = CCList.map (fun s -> Printf.sprintf "%S -> %b" s (S.mem scope s)) values
  let same_members a b = Sln_list.String.equal (members_of a) (members_of b)

  let check_same_members ~expected ~actual =
    Oth.Assert.Eq.string_list ~expected:(members_of expected) ~actual:(members_of actual)

  let lattice_laws_examples =
    Oth.test ~name:"lattice_laws_examples" (fun _ ->
        (* The grouping that made flat allow-lists non-associative (#2284). *)
        let a = scope [ "*"; "!b*" ] in
        let b = scope [ "ba" ] in
        let c = scope [ "*"; "!b" ] in
        check_same_members ~expected:(scope [ "*"; "!b" ]) ~actual:(S.union (S.union a b) c);
        check_same_members ~expected:(scope [ "*"; "!b" ]) ~actual:(S.union a (S.union b c));
        check_same_members ~expected:(S.union a b) ~actual:(S.union b a);
        check_same_members ~expected:a ~actual:(S.union a (S.inter a b));
        check_same_members
          ~expected:(S.inter a (S.union b c))
          ~actual:(S.union (S.inter a b) (S.inter a c));
        ())

  let prop_lattice_laws =
    Oth.test ~name:"prop_lattice_laws" (fun _ ->
        check
          ~name:"union and inter are associative, commutative, idempotent, absorbing, distributive"
          ~print:(Q.Print.triple print_scope_rules print_scope_rules print_scope_rules)
          (Q.Gen.triple scope_rules_gen scope_rules_gen scope_rules_gen)
          (fun (rules_a, rules_b, rules_c) ->
            let a = S.of_rules rules_a in
            let b = S.of_rules rules_b in
            let c = S.of_rules rules_c in
            same_members (S.union (S.union a b) c) (S.union a (S.union b c))
            && same_members (S.inter (S.inter a b) c) (S.inter a (S.inter b c))
            && same_members (S.union a b) (S.union b a)
            && same_members (S.inter a b) (S.inter b a)
            && same_members (S.union a a) a
            && same_members (S.inter a a) a
            && same_members (S.union a (S.inter a b)) a
            && same_members (S.inter a (S.union a b)) a
            && same_members (S.inter a (S.union b c)) (S.union (S.inter a b) (S.inter a c))
            && same_members (S.union a (S.inter b c)) (S.inter (S.union a b) (S.union a c)));
        ())

  let complement_laws_examples =
    Oth.test ~name:"complement_laws_examples" (fun _ ->
        let a = scope [ "a.*"; "!a.b" ] in
        let b = scope [ "a.x*" ] in
        check_same_members ~expected:a ~actual:(S.union S.empty a);
        check_same_members ~expected:S.empty ~actual:(S.inter S.empty a);
        check_same_members ~expected:a ~actual:(S.inter S.full a);
        check_same_members ~expected:S.full ~actual:(S.union S.full a);
        check_same_members ~expected:S.full ~actual:(S.union a (S.compl a));
        check_same_members ~expected:S.empty ~actual:(S.inter a (S.compl a));
        check_same_members ~expected:a ~actual:(S.compl (S.compl a));
        check_same_members
          ~expected:(S.inter (S.compl a) (S.compl b))
          ~actual:(S.compl (S.union a b));
        check_same_members ~expected:(S.inter a (S.compl b)) ~actual:(S.diff a b);
        ())

  let prop_complement_laws =
    Oth.test ~name:"prop_complement_laws" (fun _ ->
        check
          ~name:"empty and full are identities, compl and diff follow the laws of sets"
          ~print:(Q.Print.pair print_scope_rules print_scope_rules)
          (Q.Gen.pair scope_rules_gen scope_rules_gen)
          (fun (rules_a, rules_b) ->
            let a = S.of_rules rules_a in
            let b = S.of_rules rules_b in
            same_members (S.union S.empty a) a
            && same_members (S.inter S.empty a) S.empty
            && same_members (S.inter S.full a) a
            && same_members (S.union S.full a) S.full
            && same_members (S.union a (S.compl a)) S.full
            && same_members (S.inter a (S.compl a)) S.empty
            && same_members (S.compl (S.compl a)) a
            && same_members (S.compl (S.union a b)) (S.inter (S.compl a) (S.compl b))
            && same_members (S.compl (S.inter a b)) (S.union (S.compl a) (S.compl b))
            && same_members (S.diff a b) (S.inter a (S.compl b)));
        ())

  let tests =
    [
      scope_of_rules_examples;
      prop_scope_of_rules;
      set_operations_examples;
      prop_set_operations;
      lattice_laws_examples;
      prop_lattice_laws;
      complement_laws_examples;
      prop_complement_laws;
      subset_examples;
      prop_subset;
      is_empty_is_full_examples;
      prop_is_empty_is_full;
      literals_examples;
      prop_literals;
    ]
end

let test =
  Oth.parallel
    ((pattern_of_string_examples :: Trie_structure.tests)
    @ Trie_semantics.tests
    @ Scope_structure.tests
    @ Scope_semantics.tests)

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
