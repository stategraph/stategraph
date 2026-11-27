(* The decision a staleness comparison takes about a commit whose stored tree it needs (RFD 2356).
   The comparison reads only stored trees, thus with the tree builder on a tree read from the forge
   does not answer, and a caller that must answer now gives up instead of fetching. *)

module Gate = Terrat_vcs_event_evaluator2.Repo_tree_gate

(* [label] says what the case is.  [Oth.Assert.eq] prints both values when they differ, and the
   label goes on the line before them. *)
let assert_decision label expected ~missing_tree ~tree_builder ~built =
  let actual = Gate.decide ~missing_tree ~tree_builder ~built in
  if not (Gate.equal expected actual) then Format.eprintf "%s@." label;
  Oth.Assert.eq ~eq:Gate.equal ~pp:Gate.pp expected actual

let test_rows =
  Oth.test
    ~name:"tree gate: a stored tree is used, and a missing one either fetches or gives up"
    (fun _ ->
      assert_decision
        "a stored tree is used"
        Gate.Use
        ~missing_tree:`Fetch
        ~tree_builder:true
        ~built:true;
      assert_decision
        "a stored tree is used with the tree builder off"
        Gate.Use
        ~missing_tree:`Fetch
        ~tree_builder:false
        ~built:true;
      assert_decision
        "`Unknown gives up on a missing tree"
        Gate.Give_up
        ~missing_tree:`Unknown
        ~tree_builder:false
        ~built:false;
      assert_decision
        "the tree builder gives up on a missing tree"
        Gate.Give_up
        ~missing_tree:`Fetch
        ~tree_builder:true
        ~built:false;
      assert_decision
        "the forge answers a missing tree with the tree builder off"
        Gate.Fetch
        ~missing_tree:`Fetch
        ~tree_builder:false
        ~built:false;
      ())

let test = Oth.parallel [ test_rows ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
