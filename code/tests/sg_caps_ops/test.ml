(* Tests of [Sg_caps_ops]: what the endpoints ask of a capability set. Most questions here are about
   chosen shapes rather than laws -- who outranks whom, and which grants a tenant's administrator
   may write -- so they are examples. [reaches_every_address] is the exception: it answers for a
   whole tenant at once, and is held to what the reach itself says. *)

module C = Sg_caps
module Ops = Sg_caps_ops
module Q = QCheck2
module Gen = Sg_caps_gen
module Scope = Sg_caps_trie_scope

let scope texts = Oth.Assert.ok ~fail_msg:"not a scope" (Scope.of_strings texts)

let reach ~tenants ~states ~addresses =
  Sg_caps_reach.make ~tenants:(scope tenants) ~states:(scope states) ~addresses:(scope addresses)

let admin tenants = { C.empty with C.admin = scope tenants }
let users_manage tenants = { C.empty with C.users_manage = scope tenants }
let previewing reach = { C.empty with C.preview = { C.modified = reach; pulled_in = reach } }
let print_reach reach = Format.asprintf "%a" Sg_caps_reach.pp reach
let count = 500

let check ~name ~print gen prop =
  Q.Test.check_exn ~rand:(Random.State.make_self_init ()) (Q.Test.make ~count ~name ~print gen prop)

(* {1 How much of a tenant a grant covers} *)

let coverage_examples =
  let assert_scope_eq ~expected ~actual =
    Oth.Assert.eq
      ~eq:Ops.Tenant_scope.equal_coverage
      ~pp:Ops.Tenant_scope.pp_coverage
      expected
      actual
  in
  Oth.test ~name:"coverage_examples" (fun _ ->
      let coverage caps tenant = Ops.tenant_coverage caps `Admin ~tenant in
      assert_scope_eq ~expected:Ops.Tenant_scope.Exact ~actual:(coverage (admin [ "t1" ]) "t1");
      assert_scope_eq ~expected:Ops.Tenant_scope.Instance ~actual:(coverage (admin [ "*" ]) "t1");
      assert_scope_eq
        ~expected:Ops.Tenant_scope.Wider
        ~actual:(coverage (admin [ "t1"; "t2" ]) "t1");
      assert_scope_eq
        ~expected:Ops.Tenant_scope.Wider
        ~actual:(coverage (admin [ "*"; "!t2" ]) "t1");
      (* A prefix reaches many tenants without reaching every one; only the full grant is
         installation-wide. *)
      assert_scope_eq ~expected:Ops.Tenant_scope.Wider ~actual:(coverage (admin [ "t*" ]) "t1");
      assert_scope_eq
        ~expected:Ops.Tenant_scope.Not_covered
        ~actual:(coverage (admin [ "*"; "!t2" ]) "t2");
      assert_scope_eq
        ~expected:Ops.Tenant_scope.Not_covered
        ~actual:(coverage (admin [ "t2" ]) "t1");
      assert_scope_eq ~expected:Ops.Tenant_scope.Not_covered ~actual:(coverage C.empty "t1");
      ())

let instance_admin_examples =
  Oth.test ~name:"instance_admin_examples" (fun _ ->
      Oth.Assert.true_ (Ops.is_instance_admin (admin [ "*" ]));
      Oth.Assert.not_true (Ops.is_instance_admin (admin [ "t1" ]));
      (* Every tenant but one is not every tenant. *)
      Oth.Assert.not_true (Ops.is_instance_admin (admin [ "*"; "!t1" ]));
      Oth.Assert.not_true (Ops.is_instance_admin C.empty);
      Oth.Assert.true_ (Ops.is_some_tenants_admin (admin [ "t1" ]));
      Oth.Assert.true_ (Ops.is_some_tenants_admin (admin [ "*"; "!t1" ]));
      Oth.Assert.not_true (Ops.is_some_tenants_admin (admin [ "*" ]));
      Oth.Assert.not_true (Ops.is_some_tenants_admin C.empty);
      ())

(* {1 Who outranks whom over users} *)

let authority_examples =
  let assert_authority_eq ~expected ~actual =
    Oth.Assert.eq ~eq:Ops.equal_authority ~pp:Ops.pp_authority expected actual
  in
  Oth.test ~name:"authority_examples" (fun _ ->
      let authority ~actor ~target ~tenants =
        Ops.authority_over ~actor ~target ~target_tenants:tenants
      in
      (* An administrator of a tenant outranks a users-manage holder confined to it, and no amount
         of users-manage reaches an admin grant. *)
      assert_authority_eq
        ~expected:Ops.Dominates
        ~actual:
          (authority ~actor:(admin [ "t1" ]) ~target:(users_manage [ "t1" ]) ~tenants:[ "t1" ]);
      assert_authority_eq
        ~expected:Ops.Peer_or_greater
        ~actual:
          (authority ~actor:(users_manage [ "t1" ]) ~target:(admin [ "t1" ]) ~tenants:[ "t1" ]);
      (* Equals do not outrank each other. *)
      assert_authority_eq
        ~expected:Ops.Peer_or_greater
        ~actual:(authority ~actor:(admin [ "t1" ]) ~target:(admin [ "t1" ]) ~tenants:[ "t1" ]);
      (* Holding more is not enough: the actor must reach every tenant the target belongs to. *)
      assert_authority_eq
        ~expected:(Ops.Tenant_out_of_scope "t2")
        ~actual:
          (authority
             ~actor:(admin [ "t1" ])
             ~target:(users_manage [ "t1" ])
             ~tenants:[ "t1"; "t2" ]);
      (* A target in no tenant leaves no tenant unreached. *)
      assert_authority_eq
        ~expected:Ops.Dominates
        ~actual:(authority ~actor:(admin [ "t1" ]) ~target:C.empty ~tenants:[]);
      ())

let unreached_tenant_examples =
  let assert_unreached_eq = Oth.Assert.Eq.string_option in
  Oth.test ~name:"unreached_tenant_examples" (fun _ ->
      (* Either grant reaches a user: administering a tenant reaches its users, and so does managing
         them. *)
      assert_unreached_eq
        ~expected:None
        ~actual:(Ops.unreached_tenant ~actor:(admin [ "t1" ]) ~target_tenants:[ "t1" ]);
      assert_unreached_eq
        ~expected:None
        ~actual:(Ops.unreached_tenant ~actor:(users_manage [ "t1" ]) ~target_tenants:[ "t1" ]);
      assert_unreached_eq
        ~expected:(Some "t2")
        ~actual:
          (Ops.unreached_tenant
             ~actor:{ (admin [ "t1" ]) with C.users_manage = scope [ "t3" ] }
             ~target_tenants:[ "t1"; "t2"; "t3" ]);
      ())

(* {1 What a tenant's administrator may grant} *)

let scoped_to_tenant_examples =
  Oth.test ~name:"scoped_to_tenant_examples" (fun _ ->
      let refused caps expected =
        Oth.Assert.eq
          ~eq:Ops.equal_tenant_scope_err
          ~pp:Ops.pp_tenant_scope_err
          expected
          (Oth.Assert.error (Ops.scoped_to_tenant ~tenant:"t1" caps))
      in
      let states caps = Oth.Assert.ok (Ops.scoped_to_tenant ~tenant:"t1" caps) in
      (* Bounded by the tenant it names: nothing for the caller to confirm. *)
      Oth.Assert.Eq.string_list ~expected:[] ~actual:(states (admin [ "t1" ]));
      Oth.Assert.Eq.string_list
        ~expected:[]
        ~actual:(states (previewing (reach ~tenants:[ "t1" ] ~states:[ "*" ] ~addresses:[ "*" ])));
      (* Naming no tenant but naming states: the caller confirms those states are this tenant's. *)
      Oth.Assert.Eq.string_list
        ~expected:[ "s1"; "s1" ]
        ~actual:(states (previewing (reach ~tenants:[ "*" ] ~states:[ "s1" ] ~addresses:[ "*" ])));
      (* Reaching past the tenant: admin over another one, or over every one. *)
      refused (admin [ "t2" ]) (Ops.Grants_beyond_tenant "admin");
      refused (admin [ "*" ]) (Ops.Grants_beyond_tenant "admin");
      refused (users_manage [ "*" ]) (Ops.Grants_beyond_tenant "users-manage");
      (* Capabilities that are not about tenants cannot be granted this way at all. *)
      refused
        { C.empty with C.access_token_create = true }
        (Ops.Instance_capability "access-token-create");
      refused { C.empty with C.sudo = scope [ "u1" ] } (Ops.Instance_capability "sudo");
      (* An action grant reaching every tenant is refused whatever else it says. *)
      refused
        (previewing (reach ~tenants:[ "*" ] ~states:[ "*" ] ~addresses:[ "*" ]))
        (Ops.Grants_beyond_tenant "preview");
      ())

(* A grant that names a state of its own tenant AND answers for the states it does not name reaches
   states of every other tenant, which no caller can confirm. It used to be accepted on the strength
   of the named state alone, which let a tenant's administrator write a rule reaching every tenant. *)
let scoped_to_tenant_named_state_does_not_excuse_the_rest =
  Oth.test ~name:"scoped_to_tenant_named_state_does_not_excuse_the_rest" (fun _ ->
      let overreaching =
        previewing
          (Sg_caps_reach.union
             (reach ~tenants:[ "*" ] ~states:[ "s1" ] ~addresses:[ "*" ])
             (reach ~tenants:[ "*" ] ~states:[ "*" ] ~addresses:[ "*"; "!zzz" ]))
      in
      (* The value does reach another tenant, which is what makes accepting it a mistake. *)
      Oth.Assert.true_
        (C.authorizes
           overreaching
           (C.Act
              {
                action = `Preview;
                axis = `Modified;
                tenant = "t2";
                state = "s9";
                address = "aws_instance.prod";
              }));
      Oth.Assert.eq
        ~eq:Ops.equal_tenant_scope_err
        ~pp:Ops.pp_tenant_scope_err
        (Ops.Grants_beyond_tenant "preview")
        (Oth.Assert.error (Ops.scoped_to_tenant ~tenant:"t1" overreaching));
      ())

(* {1 How much of a tenant a reach covers} *)

let reaches_every_address_examples =
  Oth.test ~name:"reaches_every_address_examples" (fun _ ->
      let whole_tenant = reach ~tenants:[ "t1" ] ~states:[ "*" ] ~addresses:[ "*" ] in
      Oth.Assert.true_ (Ops.reaches_every_address whole_tenant ~tenant:"t1");
      (* Reaching nothing of a tenant is not reaching all of it: the answer for the states no rule
         names is what separates the two, and a reach that grants nothing still carries it. *)
      Oth.Assert.not_true (Ops.reaches_every_address Sg_caps_reach.empty ~tenant:"t1");
      Oth.Assert.not_true (Ops.reaches_every_address whole_tenant ~tenant:"t2");
      Oth.Assert.not_true
        (Ops.reaches_every_address
           (reach ~tenants:[ "t1" ] ~states:[ "*" ] ~addresses:[ "aws_instance.*" ])
           ~tenant:"t1");
      Oth.Assert.not_true
        (Ops.reaches_every_address
           (reach ~tenants:[ "t1" ] ~states:[ "s1" ] ~addresses:[ "*" ])
           ~tenant:"t1");
      Oth.Assert.true_ (Ops.reaches_tenant whole_tenant ~tenant:"t1");
      Oth.Assert.not_true (Ops.reaches_tenant Sg_caps_reach.empty ~tenant:"t1");
      ())

let prop_reaches_every_address =
  Oth.test ~name:"prop_reaches_every_address" (fun _ ->
      check
        ~name:"reaches_every_address answers what the reach says about every triple of the tenant"
        ~print:(Q.Print.pair print_reach Q.Print.string)
        (Q.Gen.pair Gen.reach Gen.text)
        (fun (r, tenant) ->
          let whole_tenant =
            Sg_caps_reach.make ~tenants:(scope [ tenant ]) ~states:Scope.full ~addresses:Scope.full
          in
          CCBool.equal (Ops.reaches_every_address r ~tenant) (Sg_caps_reach.entails r whole_tenant)
          && CCBool.equal
               (Ops.reaches_tenant r ~tenant)
               (not (Sg_caps_reach.is_empty (Sg_caps_reach.inter r whole_tenant))));
      ())

let test =
  Oth.parallel
    [
      coverage_examples;
      instance_admin_examples;
      authority_examples;
      unreached_tenant_examples;
      scoped_to_tenant_examples;
      scoped_to_tenant_named_state_does_not_excuse_the_rest;
      reaches_every_address_examples;
      prop_reaches_every_address;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
