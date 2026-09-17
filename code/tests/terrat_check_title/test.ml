(* Commit-check title branding (#1442 Phase 3): titles are canonical
   ("terrateam ...") internally; [branded_with] rewrites on the way out per
   brand, [canonical] normalizes on the way in so consumers accept both
   brands. Customers' branch-protection required checks key on these exact
   strings, so the pure functions are pinned here. *)

module Ct = Terrat_check_title

let test =
  Oth.parallel
    [
      Oth.test ~tags:[ "brand" ] ~name:"terrateam brand is the identity" (fun _ ->
          Oth.Assert.Eq.string
            ~expected:"terrateam apply"
            ~actual:(Ct.branded_with ~brand:Terrat_brand.Terrateam "terrateam apply");
          ());
      Oth.test ~tags:[ "brand" ] ~name:"stategraph brand rewrites the canonical prefix" (fun _ ->
          Oth.Assert.Eq.string
            ~expected:"stategraph apply"
            ~actual:(Ct.branded_with ~brand:Terrat_brand.Stategraph "terrateam apply");
          Oth.Assert.Eq.string
            ~expected:"stategraph plan: dir workspace"
            ~actual:(Ct.branded_with ~brand:Terrat_brand.Stategraph "terrateam plan: dir workspace");
          ());
      Oth.test ~tags:[ "brand" ] ~name:"branding leaves foreign titles untouched" (fun _ ->
          Oth.Assert.Eq.string
            ~expected:"ci/customer-check"
            ~actual:(Ct.branded_with ~brand:Terrat_brand.Stategraph "ci/customer-check");
          (* Only the word-prefix form is a check title; no space, no match. *)
          Oth.Assert.Eq.string
            ~expected:"terrateam"
            ~actual:(Ct.branded_with ~brand:Terrat_brand.Stategraph "terrateam");
          ());
      Oth.test ~tags:[ "brand" ] ~name:"canonical maps stategraph titles back" (fun _ ->
          Oth.Assert.Eq.string ~expected:"terrateam apply" ~actual:(Ct.canonical "stategraph apply");
          Oth.Assert.Eq.string
            ~expected:"terrateam apply pre-hooks"
            ~actual:(Ct.canonical "stategraph apply pre-hooks");
          ());
      Oth.test
        ~tags:[ "brand" ]
        ~name:"canonical leaves canonical and foreign titles untouched"
        (fun _ ->
          Oth.Assert.Eq.string ~expected:"terrateam apply" ~actual:(Ct.canonical "terrateam apply");
          Oth.Assert.Eq.string
            ~expected:"ci/customer-check"
            ~actual:(Ct.canonical "ci/customer-check");
          ());
      Oth.test
        ~tags:[ "brand" ]
        ~name:"round trip: branded then canonical is the identity"
        (fun _ ->
          CCList.iter
            (fun title ->
              Oth.Assert.Eq.string
                ~expected:title
                ~actual:(Ct.canonical (Ct.branded_with ~brand:Terrat_brand.Stategraph title)))
            [
              "terrateam apply";
              "terrateam plan: dir default";
              "terrateam apply pre-hooks";
              "terrateam index";
              "terrateam build-tree somebranch";
              "terrateam external";
            ];
          ());
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
