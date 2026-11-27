(* Tests of [Sg_caps]. The judgment is [entails]: two capability sets are the same when each entails
   the other, which is what [equivalent] asks. Each property test comes right after a unit test
   that shows examples of the same property. *)

module C = Sg_caps
module R = Sg_caps_reach
module Scope = Sg_caps_trie_scope
module Q = QCheck2
module Gen = Sg_caps_gen

let reach ~tenants ~states ~addresses =
  let scope texts = Oth.Assert.ok (Scope.of_strings texts) in
  R.make ~tenants:(scope tenants) ~states:(scope states) ~addresses:(scope addresses)

let scope texts = Oth.Assert.ok (Scope.of_strings texts)
let admin tenants = { C.empty with C.admin = scope tenants }
let users_manage tenants = { C.empty with C.users_manage = scope tenants }
let sudo users = { C.empty with C.sudo = scope users }
let commit reach = { C.empty with C.commit = { C.modified = reach; pulled_in = reach } }
let preview reach = { C.empty with C.preview = { C.modified = reach; pulled_in = reach } }

(* The judgment: [left] and [right] allow the same atoms. *)
let check_equivalent left right =
  Oth.Assert.true_
    ~fail_msg:(Format.asprintf "@[<v>left:  %a@,right: %a@]" C.pp left C.pp right)
    (C.equivalent left right)

let print_caps caps = Format.asprintf "%a" C.pp caps
let print_reach reach = Format.asprintf "%a" R.pp reach

let starts_with_the_star_rule = function
  | (Sg_caps_trie.Pattern.Prefix "", _) :: _ -> true
  | _ -> false

let count = 500

let check ~name ~print gen prop =
  Q.Test.check_exn ~rand:(Random.State.make_self_init ()) (Q.Test.make ~count ~name ~print gen prop)

(* Three capability sets that overlap without containing each other. *)
let a = admin [ "t1" ]

let b =
  commit
    (reach
       ~tenants:[ "t1"; "t2" ]
       ~states:[ "s2" ]
       ~addresses:[ "aws_instance.*"; "!aws_instance.db.*" ])

let c =
  C.union
    (users_manage [ "t3" ])
    (C.union (sudo [ "u1" ]) (preview (reach ~tenants:[ "t2" ] ~states:[ "*" ] ~addresses:[ "*" ])))

(* [web] refuses a part of what it allows, and [dba] allows exactly that part. They reach the same
   tenant and the same states, so only the address decides. *)
let web =
  commit
    (reach ~tenants:[ "t1" ] ~states:[ "*" ] ~addresses:[ "aws_instance.*"; "!aws_instance.db.*" ])

let dba = commit (reach ~tenants:[ "t1" ] ~states:[ "*" ] ~addresses:[ "aws_instance.db.*" ])

let commits caps address =
  C.authorizes
    caps
    (C.Act { action = `Commit; axis = `Modified; tenant = "t1"; state = "s1"; address })

(* {1 union} *)

let union_commutative_examples =
  Oth.test ~name:"union_commutative_examples" (fun _ ->
      check_equivalent (C.union a b) (C.union b a);
      check_equivalent (C.union b c) (C.union c b);
      let authorizes_commit caps ~tenant ~state ~address =
        C.authorizes caps (C.Act { action = `Commit; axis = `Modified; tenant; state; address })
      in
      Oth.Assert.true_
        (authorizes_commit (C.union a b) ~tenant:"t1" ~state:"s9" ~address:"anything");
      Oth.Assert.true_
        (authorizes_commit (C.union a b) ~tenant:"t2" ~state:"s2" ~address:"aws_instance.web");
      Oth.Assert.not_true
        (authorizes_commit (C.union a b) ~tenant:"t2" ~state:"s9" ~address:"aws_instance.web");
      ())

let union_negation_in_pattern =
  Oth.test ~name:"union_negation_in_pattern" (fun _ ->
      Oth.Assert.not_true (commits web "aws_instance.db.main");
      Oth.Assert.true_ (commits dba "aws_instance.db.main");
      let web_union_dba = C.union web dba in
      (* The refusal written in [web] does not cancel what [dba] allows. *)
      Oth.Assert.true_ (commits web_union_dba "aws_instance.db.main");
      Oth.Assert.true_ (commits web_union_dba "aws_instance.web");
      Oth.Assert.not_true (commits web_union_dba "google_sql.db");
      ())

let prop_union_commutative =
  Oth.test ~name:"prop_union_commutative" (fun _ ->
      check
        ~name:"union a b and union b a allow the same"
        ~print:(Q.Print.pair print_caps print_caps)
        (Q.Gen.pair Gen.caps Gen.caps)
        (fun (a, b) -> C.equivalent (C.union a b) (C.union b a));
      ())

let union_associative_examples =
  Oth.test ~name:"union_associative_examples" (fun _ ->
      check_equivalent (C.union (C.union a b) c) (C.union a (C.union b c));
      ())

let prop_union_associative =
  Oth.test ~name:"prop_union_associative" (fun _ ->
      check
        ~name:"union (union a b) c is equivalent to union a (union b c)"
        ~print:(Q.Print.triple print_caps print_caps print_caps)
        (Q.Gen.triple Gen.caps Gen.caps Gen.caps)
        (fun (a, b, c) -> C.equivalent (C.union (C.union a b) c) (C.union a (C.union b c)));
      ())

let union_neutral_examples =
  Oth.test ~name:"union_neutral_examples" (fun _ ->
      check_equivalent a (C.union a C.empty);
      check_equivalent a (C.union C.empty a);
      check_equivalent C.empty (C.union C.empty C.empty);
      ())

let prop_union_neutral =
  Oth.test ~name:"prop_union_neutral" (fun _ ->
      check ~name:"empty is the neutral element of union" ~print:print_caps Gen.caps (fun a ->
          C.equivalent (C.union a C.empty) a && C.equivalent (C.union C.empty a) a);
      ())

(* {1 inter} *)

let inter_commutative_examples =
  Oth.test ~name:"inter_commutative_examples" (fun _ ->
      check_equivalent (C.inter a b) (C.inter b a);
      check_equivalent (C.inter b c) (C.inter c b);
      ())

let inter_negation_in_pattern =
  Oth.test ~name:"inter_negation_in_pattern" (fun _ ->
      let web_inter_dba = C.inter web dba in
      (* Intersection keeps only what both allow, which is nothing here: [web] refuses every address
         [dba] allows, and [dba] reaches no other address. *)
      Oth.Assert.not_true (commits web_inter_dba "aws_instance.db.main");
      Oth.Assert.not_true (commits web_inter_dba "aws_instance.web");
      (* The refusal is what empties the meet: the same grant without it keeps what [dba] allows. *)
      let everything_under_aws =
        commit (reach ~tenants:[ "t1" ] ~states:[ "*" ] ~addresses:[ "aws_instance.*" ])
      in
      Oth.Assert.true_ (commits (C.inter everything_under_aws dba) "aws_instance.db.main");
      ())

let prop_inter_commutative =
  Oth.test ~name:"prop_inter_commutative" (fun _ ->
      check
        ~name:"inter a b and inter b a allow the same"
        ~print:(Q.Print.pair print_caps print_caps)
        (Q.Gen.pair Gen.caps Gen.caps)
        (fun (a, b) -> C.equivalent (C.inter a b) (C.inter b a));
      ())

let inter_associative_examples =
  Oth.test ~name:"inter_associative_examples" (fun _ ->
      check_equivalent (C.inter (C.inter a b) c) (C.inter a (C.inter b c));
      ())

let prop_inter_associative =
  Oth.test ~name:"prop_inter_associative" (fun _ ->
      check
        ~name:"the two groupings of inter allow the same"
        ~print:(Q.Print.triple print_caps print_caps print_caps)
        (Q.Gen.triple Gen.caps Gen.caps Gen.caps)
        (fun (a, b, c) -> C.equivalent (C.inter (C.inter a b) c) (C.inter a (C.inter b c)));
      ())

let inter_empty_examples =
  Oth.test ~name:"inter_empty_examples" (fun _ ->
      (* [empty] allows nothing, so meeting it allows nothing: it absorbs, where it is neutral for
         union. *)
      check_equivalent C.empty (C.inter a C.empty);
      check_equivalent C.empty (C.inter C.empty a);
      check_equivalent a (C.inter a a);
      ())

let prop_inter_empty =
  Oth.test ~name:"prop_inter_empty" (fun _ ->
      check
        ~name:"empty absorbs inter, and inter of a capability set with itself allows the same"
        ~print:print_caps
        Gen.caps
        (fun a ->
          C.equivalent (C.inter a C.empty) C.empty
          && C.equivalent (C.inter C.empty a) C.empty
          && C.equivalent (C.inter a a) a);
      ())

let inter_keeps_admin_apart_examples =
  Oth.test ~name:"inter_keeps_admin_apart_examples" (fun _ ->
      (* [a] commits in t1 through [admin] only. Meeting it with [everything] must not write that
         implied commit into the commit grant: once t1 is taken out of [admin], the commit goes too,
         as it does on [a] itself. See https://github.com/stategraph/mono/pull/2340#issuecomment-5716558886 *)
      let m = C.inter a C.everything in
      let revoke caps = { caps with C.admin = Scope.empty } in
      Oth.Assert.true_ (commits a "aws_instance.web");
      Oth.Assert.true_ (commits m "aws_instance.web");
      Oth.Assert.not_true (commits (revoke a) "aws_instance.web");
      Oth.Assert.not_true (commits (revoke m) "aws_instance.web");
      (* A commit the meet owes to neither side's [admin] is kept. *)
      let explicit = C.inter web C.everything in
      Oth.Assert.true_ (commits (revoke explicit) "aws_instance.web");
      ())

let prop_inter_keeps_admin_apart =
  Oth.test ~name:"prop_inter_keeps_admin_apart" (fun _ ->
      check
        ~name:"taking a tenant out of the admin of an inter takes away the actions it implied"
        ~print:(Q.Print.pair (Q.Print.pair print_caps print_caps) Q.Print.string)
        (Q.Gen.pair (Q.Gen.pair Gen.caps Gen.caps) Gen.text)
        (fun ((a, b), tenant) ->
          let m = C.inter a b in
          let revoked = { m with C.admin = Scope.empty } in
          let act action axis =
            C.Act { action; axis; tenant; state = "any state"; address = "any address" }
          in
          (not (Scope.mem m.C.admin tenant))
          || not
               (C.authorizes revoked (act `Commit `Modified)
               || C.authorizes revoked (act `Commit `Pulled_in)
               || C.authorizes revoked (act `Preview `Modified)
               || C.authorizes revoked (act `Preview `Pulled_in)));
      ())

(* {1 everything} *)

let everything_examples =
  Oth.test ~name:"everything_examples" (fun _ ->
      (* [everything] allows every atom, whatever it names. *)
      Oth.Assert.true_ (C.authorizes C.everything (C.Admin "any tenant"));
      Oth.Assert.true_ (C.authorizes C.everything (C.Sudo "any user"));
      Oth.Assert.true_
        (C.authorizes
           C.everything
           (C.Act
              {
                action = `Preview;
                axis = `Pulled_in;
                tenant = "any tenant";
                state = "any state";
                address = "any address";
              }));
      check_equivalent a (C.inter a C.everything);
      check_equivalent a (C.inter C.everything a);
      check_equivalent C.everything (C.union a C.everything);
      Oth.Assert.true_ (C.entails C.everything a);
      Oth.Assert.not_true (C.entails a C.everything);
      ())

let prop_everything =
  Oth.test ~name:"prop_everything" (fun _ ->
      check
        ~name:"everything is the neutral element of inter, absorbs union, and entails anything"
        ~print:print_caps
        Gen.caps
        (fun a ->
          C.equivalent (C.inter a C.everything) a
          && C.equivalent (C.inter C.everything a) a
          && C.equivalent (C.union a C.everything) C.everything
          && C.entails C.everything a);
      ())

(* {1 entails} *)

let entails_transitive_examples =
  Oth.test ~name:"entails_transitive_examples" (fun _ ->
      let a_union_b = C.union a b in
      let a_union_b_union_c = C.union a_union_b c in
      Oth.Assert.true_ (C.entails a_union_b_union_c a_union_b);
      Oth.Assert.true_ (C.entails a_union_b a);
      Oth.Assert.true_ (C.entails a_union_b_union_c a);
      (* And it does not hold the other way round. *)
      Oth.Assert.not_true (C.entails a a_union_b);
      ())

let prop_entails_transitive =
  Oth.test ~name:"prop_entails_transitive" (fun _ ->
      check
        ~name:"entails a b and entails b c imply entails a c"
        ~print:(Q.Print.triple print_caps print_caps print_caps)
        (Q.Gen.triple Gen.caps Gen.caps Gen.caps)
        (fun (a, b, c) ->
          (* The generated triples rarely entail each other, so the unions below build a chain. *)
          let a_union_b = C.union a b in
          let a_union_b_union_c = C.union (C.union a b) c in
          ((not (C.entails a b && C.entails b c)) || C.entails a c)
          && C.entails a_union_b_union_c a_union_b
          && C.entails a_union_b a
          && C.entails a_union_b_union_c a);
      ())

(* {1 equivalent} *)

let equivalent_examples =
  Oth.test ~name:"equivalent_examples" (fun _ ->
      (* The same triples, written as one product or as the union of two. *)
      let one = commit (reach ~tenants:[ "t1" ] ~states:[ "s1"; "s2" ] ~addresses:[ "*" ]) in
      let two =
        C.union
          (commit (reach ~tenants:[ "t1" ] ~states:[ "s1" ] ~addresses:[ "*" ]))
          (commit (reach ~tenants:[ "t1" ] ~states:[ "s2" ] ~addresses:[ "*" ]))
      in
      Oth.Assert.true_ (C.equivalent one two);
      Oth.Assert.true_ (C.equivalent one one);
      Oth.Assert.true_ (C.equivalent two one);
      Oth.Assert.not_true (C.equivalent one (C.union one b));
      ())

let prop_equivalent =
  Oth.test ~name:"prop_equivalent" (fun _ ->
      check
        ~name:"equivalent is reflexive, symmetric and transitive"
        ~print:(Q.Print.triple print_caps print_caps print_caps)
        (Q.Gen.triple Gen.caps Gen.caps Gen.caps)
        (fun (a, b, c) ->
          C.equivalent a a
          && CCBool.equal (C.equivalent a b) (C.equivalent b a)
          && ((not (C.equivalent a b && C.equivalent b c)) || C.equivalent a c)
          (* A chain the generators do reach: unions of the same sets, grouped differently. *)
          && C.equivalent (C.union a (C.union b c)) (C.union (C.union a b) c));
      ())

(* {1 state_rules} *)

let state_rules_examples =
  Oth.test ~name:"state_rules_examples" (fun _ ->
      let one_state = reach ~tenants:[ "t1" ] ~states:[ "s1" ] ~addresses:[ "aws_instance.*" ] in
      (* The rule for the states no other rule names is written even where it reaches nothing, so
         reading the rules of a tenant never leaves what happens outside them to the reader. *)
      Oth.Assert.true_ (starts_with_the_star_rule (R.state_rules one_state ~tenant:"t1"));
      Oth.Assert.true_ (starts_with_the_star_rule (R.state_rules one_state ~tenant:"t2"));
      Oth.Assert.true_ (starts_with_the_star_rule (R.state_rules R.empty ~tenant:"t1"));
      Oth.Assert.true_ (starts_with_the_star_rule (R.state_rules R.everything ~tenant:"t1"));
      (* A refusal is where that rule carries the grant rather than restating a denial: it answers
         for every state the refusal does not name, and the named rule is the exception. Read the
         rules without it and "every state but s1" becomes "no state at all". *)
      let all_but_s1 =
        reach ~tenants:[ "t1" ] ~states:[ "*"; "!s1" ] ~addresses:[ "aws_instance.*" ]
      in
      (match R.state_rules all_but_s1 ~tenant:"t1" with
      | [
       (Sg_caps_trie.Pattern.Prefix "", every_other_state);
       (Sg_caps_trie.Pattern.Literal "s1", refused);
      ] ->
          Oth.Assert.String_list.eq
            ~expected:[ "aws_instance.*" ]
            ~actual:(Scope.to_strings every_other_state);
          Oth.Assert.true_ (Scope.is_empty refused)
      | rules ->
          Oth.Assert.false_
            (Format.asprintf
               "expected the [*] rule and the refusal of s1, got %d rule(s)"
               (CCList.length rules)));
      (* [to_rules] is where that rule is left out when it reaches nothing, which is what makes the
         two disagree on the same tenant. *)
      match R.to_rules one_state with
      | [ (_, states) ] -> Oth.Assert.not_true (starts_with_the_star_rule states)
      | rules ->
          Oth.Assert.false_
            (Printf.sprintf "expected one tenant rule, got %d" (CCList.length rules)))

let prop_state_rules_starts_with_the_star_rule =
  Oth.test ~name:"prop_state_rules_starts_with_the_star_rule" (fun _ ->
      check
        ~name:"the state rules of a tenant start with the rule for the states no other rule names"
        ~print:(Q.Print.pair print_reach Q.Print.string)
        (Q.Gen.pair Gen.reach Gen.text)
        (fun (reach, tenant) -> starts_with_the_star_rule (R.state_rules reach ~tenant));
      ())

let test =
  Oth.parallel
    [
      union_commutative_examples;
      union_negation_in_pattern;
      prop_union_commutative;
      union_associative_examples;
      prop_union_associative;
      union_neutral_examples;
      prop_union_neutral;
      inter_commutative_examples;
      inter_negation_in_pattern;
      prop_inter_commutative;
      inter_associative_examples;
      prop_inter_associative;
      inter_empty_examples;
      prop_inter_empty;
      inter_keeps_admin_apart_examples;
      prop_inter_keeps_admin_apart;
      everything_examples;
      prop_everything;
      entails_transitive_examples;
      prop_entails_transitive;
      equivalent_examples;
      prop_equivalent;
      state_rules_examples;
      prop_state_rules_starts_with_the_star_rule;
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
