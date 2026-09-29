(* The security decision at the heart of #1795: which installations may this
   GitHub user claim? Pure, so every case here is exercised without a GitHub
   account. *)

module Identity = Sgs_service_orchestration_github_identity

let inst = Identity.Tests.installation
let provable = Identity.Tests.provable_installation_ids

(* GitHub's own numbering, kept distinct so a test that confuses an
   installation id with an account id fails rather than passes by luck. *)
let me = 900
let someone_else = 901
let my_org = 500
let other_org = 501
let org_install ~github_id ~target_id = inst ~github_id ~target_id ~target_type:"Organization"
let user_install ~github_id ~target_id = inst ~github_id ~target_id ~target_type:"User"

let test_org_admin_is_provable =
  Oth.test ~name:"an org I administer is provable" (fun _ ->
      Oth.Assert.true_
        (provable
           ~user_id:me
           ~admin_org_ids:[ my_org ]
           [ org_install ~github_id:1 ~target_id:my_org ]
        = [ 1 ]))

(* The whole reason /user/installations cannot be the authority: GitHub returns
   installations to plain members and to outside collaborators too. *)
let test_org_membership_is_not_enough =
  Oth.test ~name:"an org I merely belong to is not provable" (fun _ ->
      Oth.Assert.true_
        (provable ~user_id:me ~admin_org_ids:[] [ org_install ~github_id:1 ~target_id:my_org ] = []))

let test_other_orgs_admin_does_not_help =
  Oth.test ~name:"administering one org does not prove another" (fun _ ->
      Oth.Assert.true_
        (provable
           ~user_id:me
           ~admin_org_ids:[ other_org ]
           [ org_install ~github_id:1 ~target_id:my_org ]
        = []))

let test_own_user_install_is_provable =
  Oth.test ~name:"my own account's installation is provable" (fun _ ->
      Oth.Assert.true_
        (provable ~user_id:me ~admin_org_ids:[] [ user_install ~github_id:1 ~target_id:me ] = [ 1 ]))

let test_other_user_install_is_not_provable =
  Oth.test ~name:"another account's installation is not provable" (fun _ ->
      Oth.Assert.true_
        (provable
           ~user_id:me
           ~admin_org_ids:[ my_org ]
           [ user_install ~github_id:1 ~target_id:someone_else ]
        = []))

(* An org id that happens to equal my user id must not let a User install pass
   as an Organization one, or the reverse. The branches key on target_type
   first for exactly this reason. *)
let test_target_type_decides_which_check_applies =
  Oth.test ~name:"target type selects the check, ids are not interchangeable" (fun _ ->
      Oth.Assert.true_
        (provable ~user_id:me ~admin_org_ids:[] [ org_install ~github_id:1 ~target_id:me ] = []);
      Oth.Assert.true_
        (provable
           ~user_id:me
           ~admin_org_ids:[ my_org ]
           [ user_install ~github_id:1 ~target_id:my_org ]
        = []))

(* Anything we cannot reason about (Enterprise today, whatever GitHub adds
   later) must fail closed rather than fall through. *)
let test_unknown_target_type_refused =
  Oth.test ~name:"an unknown target type is refused" (fun _ ->
      Oth.Assert.true_
        (provable
           ~user_id:me
           ~admin_org_ids:[ my_org ]
           [ inst ~github_id:1 ~target_id:my_org ~target_type:"Enterprise" ]
        = []))

let test_mixed_set_is_filtered_not_all_or_nothing =
  Oth.test ~name:"a mixed set yields exactly the provable ones" (fun _ ->
      Oth.Assert.true_
        (provable
           ~user_id:me
           ~admin_org_ids:[ my_org ]
           [
             org_install ~github_id:1 ~target_id:my_org;
             org_install ~github_id:2 ~target_id:other_org;
             user_install ~github_id:3 ~target_id:me;
             user_install ~github_id:4 ~target_id:someone_else;
             inst ~github_id:5 ~target_id:my_org ~target_type:"Enterprise";
           ]
        = [ 1; 3 ]))

let test_no_installations =
  Oth.test ~name:"no installations yields nothing" (fun _ ->
      Oth.Assert.true_ (provable ~user_id:me ~admin_org_ids:[ my_org ] [] = []))

let test =
  Oth.parallel
    [
      test_org_admin_is_provable;
      test_org_membership_is_not_enough;
      test_other_orgs_admin_does_not_help;
      test_own_user_install_is_provable;
      test_other_user_install_is_not_provable;
      test_target_type_decides_which_check_applies;
      test_unknown_target_type_refused;
      test_mixed_set_is_filtered_not_all_or_nothing;
      test_no_installations;
    ]

let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
