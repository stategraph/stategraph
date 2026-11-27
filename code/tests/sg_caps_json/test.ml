(* Tests of [Sg_caps_json]: the JSON a capability set is written as, and the capability set some
   JSON is read as. Equality of capability sets is [equivalent], so what is pinned is the atoms
   they allow, not the shape they are held in. *)

module C = Sg_caps
module R = Sg_caps_reach
module Scope = Sg_caps_trie_scope
module P = Sg_caps_trie.Pattern
module W = Sg_caps_wire_capabilities
module Q = QCheck2

let scope texts = Oth.Assert.ok (Scope.of_strings texts)

let reach ~tenants ~states ~addresses =
  R.make ~tenants:(scope tenants) ~states:(scope states) ~addresses:(scope addresses)

let read_wire wire = Oth.Assert.ok (Sg_caps_json.of_wire wire)
let wire_to_json caps = Yojson.Safe.to_string (W.to_yojson (Sg_caps_json.to_wire caps))

(* The same text laid out for reading, the form an example is pinned in. *)
let wire_to_pretty_json caps =
  Yojson.Safe.pretty_to_string (W.to_yojson (Sg_caps_json.to_wire caps))

let parsed text =
  Oth.Assert.ok
    ~fail_msg:("not a capabilities object: " ^ text)
    (W.of_yojson (Yojson.Safe.from_string text))

let check_equivalent left right =
  Oth.Assert.true_
    ~fail_msg:(Format.asprintf "@[<v>left:  %a@,right: %a@]" C.pp left C.pp right)
    (C.equivalent left right)

(* {1 Examples} *)

(* The example of {!Sg_caps_reach.to_rules}. *)
let doc_reach = R.make ~tenants:(scope [ "t1" ]) ~states:Scope.full ~addresses:(scope [ "a.*" ])

(* A preview over one state of one tenant, with a refusal inside what it allows, that pulls in
   everything: what [reads_examples] writes by hand. *)
let one_state =
  {
    C.empty with
    C.preview =
      {
        C.modified = reach ~tenants:[ "t1" ] ~states:[ "s1" ] ~addresses:[ "a.*"; "!a.b" ];
        pulled_in = R.everything;
      };
  }

(* Scopes only, one with a refusal inside a prefix, and a flag. *)
let scopes_only =
  {
    C.empty with
    C.access_token_create = true;
    admin = scope [ "prod-*"; "!prod-secret" ];
    users_manage = scope [ "t1" ];
    sudo = scope [ "svc-*" ];
  }

(* The union of two commit grants: one over a state of a tenant, one over every tenant of a prefix
   but one. The refused tenant is a rule of its own, inside the prefix that allows. *)
let two_grants =
  {
    C.empty with
    C.commit =
      {
        C.modified =
          R.union
            (reach ~tenants:[ "t1" ] ~states:[ "s1" ] ~addresses:[ "a.*" ])
            (reach ~tenants:[ "prod-*"; "!prod-secret" ] ~states:[ "*" ] ~addresses:[ "*" ]);
        pulled_in = R.everything;
      };
  }

(* {1 What is written, and what is read} *)

let writes_examples =
  Oth.test ~name:"writes_examples" (fun _ ->
      (* A capability set that allows nothing writes every key, each an empty list. *)
      Oth.Assert.Eq.string
        ~expected:
          {|{
  "access-token-create": false,
  "access-token-refresh": false,
  "admin": [],
  "commit": { "modified": [], "pulled-in": [] },
  "preview": { "modified": [], "pulled-in": [] },
  "sudo": [],
  "users-manage": []
}|}
        ~actual:(wire_to_pretty_json C.empty);
      (* The example of {!Sg_caps_reach.to_rules}, on the wire: a tenant rule answers the state
         rules reached there, and a state rule the addresses. *)
      let written_reach =
        Sg_caps_json.to_wire
          { C.empty with C.preview = { C.modified = doc_reach; pulled_in = R.empty } }
      in
      Oth.Assert.Eq.string
        ~expected:
          {|[
  { "states": [ { "addresses": [ "a.*" ], "state": "*" } ], "tenant": "t1" }
]|}
        ~actual:
          (Yojson.Safe.pretty_to_string
             (Sg_caps_wire_reach.to_yojson
                written_reach.Sg_caps_wire_capabilities.preview.Sg_caps_wire_actions.modified));
      (* [one_state]: the commit reaches, which reach nothing, are empty lists. *)
      Oth.Assert.Eq.string
        ~expected:
          {|{
  "access-token-create": false,
  "access-token-refresh": false,
  "admin": [],
  "commit": { "modified": [], "pulled-in": [] },
  "preview": {
    "modified": [
      {
        "states": [ { "addresses": [ "a.*", "!a.b" ], "state": "s1" } ],
        "tenant": "t1"
      }
    ],
    "pulled-in": [
      { "states": [ { "addresses": [ "*" ], "state": "*" } ], "tenant": "*" }
    ]
  },
  "sudo": [],
  "users-manage": []
}|}
        ~actual:(wire_to_pretty_json one_state);
      (* [scopes_only]: every reach is an empty list, and a scope is its rules alone, with no [!*]. *)
      Oth.Assert.Eq.string
        ~expected:
          {|{
  "access-token-create": true,
  "access-token-refresh": false,
  "admin": [ "prod-*", "!prod-secret" ],
  "commit": { "modified": [], "pulled-in": [] },
  "preview": { "modified": [], "pulled-in": [] },
  "sudo": [ "svc-*" ],
  "users-manage": [ "t1" ]
}|}
        ~actual:(wire_to_pretty_json scopes_only);
      (* [two_grants]: the refused tenant is written with no state rule, inside the prefix that
         allows. *)
      Oth.Assert.Eq.string
        ~expected:
          {|{
  "access-token-create": false,
  "access-token-refresh": false,
  "admin": [],
  "commit": {
    "modified": [
      {
        "states": [ { "addresses": [ "*" ], "state": "*" } ],
        "tenant": "prod-*"
      },
      { "states": [], "tenant": "prod-secret" },
      {
        "states": [ { "addresses": [ "a.*" ], "state": "s1" } ],
        "tenant": "t1"
      }
    ],
    "pulled-in": [
      { "states": [ { "addresses": [ "*" ], "state": "*" } ], "tenant": "*" }
    ]
  },
  "preview": { "modified": [], "pulled-in": [] },
  "sudo": [],
  "users-manage": []
}|}
        ~actual:(wire_to_pretty_json two_grants);
      ())

(* One line per tenant rule: the state rules reached there, each with the addresses reached. *)
let reach_rules reach =
  let state_rule (state, addresses) =
    Printf.sprintf
      "%s -> %s"
      (P.to_string state)
      (CCString.concat ", " (Scope.to_strings addresses))
  in
  CCList.map
    (fun (tenant, states) ->
      Printf.sprintf
        "%s -> [%s]"
        (P.to_string tenant)
        (CCString.concat "; " (CCList.map state_rule states)))
    (R.to_rules reach)

let scope_rules scope =
  CCList.map
    (fun (p, allowed) -> (if allowed then "" else "!") ^ P.to_string p)
    (Scope.to_rules scope)

(* The rules the examples of [writes_examples] are written from. The [*] rule of a level is left out
   when it answers nothing: a reach that reaches nothing has no rule, a tenant that reaches nothing,
   such as a refused one inside a prefix that allows, has no state rule, and no scope has a [!*]
   rule. *)
let to_rules_examples =
  Oth.test ~name:"to_rules_examples" (fun _ ->
      (* Every reach of [C.empty], and of [scopes_only]. *)
      Oth.Assert.String_list.eq ~expected:[] ~actual:(reach_rules C.empty.C.commit.C.modified);
      Oth.Assert.String_list.eq ~expected:[ "t1 -> [* -> a.*]" ] ~actual:(reach_rules doc_reach);
      Oth.Assert.String_list.eq
        ~expected:[ "t1 -> [s1 -> a.*, !a.b]" ]
        ~actual:(reach_rules one_state.C.preview.C.modified);
      Oth.Assert.String_list.eq
        ~expected:[ "* -> [* -> *]" ]
        ~actual:(reach_rules one_state.C.preview.C.pulled_in);
      Oth.Assert.String_list.eq
        ~expected:[ "prod-*"; "!prod-secret" ]
        ~actual:(scope_rules scopes_only.C.admin);
      Oth.Assert.String_list.eq ~expected:[ "t1" ] ~actual:(scope_rules scopes_only.C.users_manage);
      Oth.Assert.String_list.eq ~expected:[ "svc-*" ] ~actual:(scope_rules scopes_only.C.sudo);
      Oth.Assert.String_list.eq
        ~expected:[ "prod-* -> [* -> *]"; "prod-secret -> []"; "t1 -> [s1 -> a.*]" ]
        ~actual:(reach_rules two_grants.C.commit.C.modified);
      Oth.Assert.String_list.eq
        ~expected:[ "* -> [* -> *]" ]
        ~actual:(reach_rules two_grants.C.commit.C.pulled_in);
      ())

let reads_examples =
  Oth.test ~name:"reads_examples" (fun _ ->
      (* A preview over one state of one tenant, with a refusal inside what it allows. *)
      let written_by_hand =
        {|{"access-token-create": false, "access-token-refresh": false,
           "admin": [], "users-manage": [], "sudo": [],
           "commit": {"modified": [], "pulled-in": []},
           "preview": {"modified": [{"tenant": "t1",
                                     "states": [{"state": "s1",
                                                 "addresses": ["a.*", "!a.b"]}]}],
                       "pulled-in": [{"tenant": "*",
                                      "states": [{"state": "*", "addresses": ["*"]}]}]}}|}
      in
      check_equivalent
        (read_wire (parsed written_by_hand))
        {
          C.empty with
          C.preview =
            {
              C.modified = reach ~tenants:[ "t1" ] ~states:[ "s1" ] ~addresses:[ "a.*"; "!a.b" ];
              pulled_in = R.everything;
            };
        };
      ())

let unreadable_examples =
  Oth.test ~name:"unreadable_examples" (fun _ ->
      let refused text_of_caps text =
        match Oth.Assert.error (Sg_caps_json.of_wire (parsed text_of_caps)) with
        | `Invalid_pattern_err rejected -> Oth.Assert.Eq.string ~expected:text ~actual:rejected
        | `Too_many_rules_err _ -> Oth.Assert.false_ "expected a bad pattern, got too many rules"
      in
      let around scope =
        Printf.sprintf
          {|{"access-token-create": false, "access-token-refresh": false, "admin": %s,
             "users-manage": [], "sudo": [],
             "commit": {"modified": [], "pulled-in": []},
             "preview": {"modified": [], "pulled-in": []}}|}
          scope
      in
      (* A ['*'] that is not the last character, in a scope and in a tenant rule. *)
      refused (around {|["a*b"]|}) "a*b";
      refused
        {|{"access-token-create": false, "access-token-refresh": false, "admin": [],
           "users-manage": [], "sudo": [],
           "commit": {"modified": [{"tenant": "a*b", "states": []}], "pulled-in": []},
           "preview": {"modified": [], "pulled-in": []}}|}
        "a*b";
      ())

(* {1 What is written is read back} *)

let round_trip_examples =
  Oth.test ~name:"round_trip_examples" (fun _ ->
      let round_trips caps = check_equivalent (read_wire (Sg_caps_json.to_wire caps)) caps in
      round_trips C.empty;
      round_trips C.everything;
      round_trips
        {
          C.empty with
          C.admin = scope [ "t1"; "prod-*"; "!prod-secret" ];
          sudo = scope [ "svc-*" ];
          commit =
            {
              C.modified =
                R.union
                  (reach ~tenants:[ "t1" ] ~states:[ "s1" ] ~addresses:[ "a.*" ])
                  (reach ~tenants:[ "t2" ] ~states:[ "*" ] ~addresses:[ "*"; "!b" ]);
              pulled_in = R.everything;
            };
        };
      ())

let prop_round_trip =
  Oth.test ~name:"prop_round_trip" (fun _ ->
      Q.Test.check_exn
        ~rand:(Random.State.make_self_init ())
        (Q.Test.make
           ~count:10_000 (* A large count, it's very important that this holds *)
           ~name:"of_wire (to_wire caps) allows what caps allows"
           ~print:(fun caps -> Format.asprintf "%a" C.pp caps)
           Sg_caps_gen.caps
           (fun caps ->
             match Sg_caps_json.of_wire (Sg_caps_json.to_wire caps) with
             | Ok read -> C.equivalent read caps
             | Error (`Invalid_pattern_err _ | `Too_many_rules_err _) -> false)))

let prop_written_once =
  Oth.test ~name:"prop_written_once" (fun _ ->
      Q.Test.check_exn
        ~rand:(Random.State.make_self_init ())
        (Q.Test.make
           ~count:1000
           ~name:"reading what was written and writing it again gives the same text"
           ~print:(fun caps -> Format.asprintf "%a" C.pp caps)
           Sg_caps_gen.caps
           (fun caps ->
             let text = wire_to_json caps in
             CCString.equal text (wire_to_json (read_wire (parsed text)))
             (* Joining a capability set with itself changes nothing it is written with. *)
             && CCString.equal text (wire_to_json (C.union caps caps)))))

let too_many_rules_examples =
  Oth.test ~name:"too_many_rules_examples" (fun _ ->
      let rules n = CCList.init n (fun i -> Printf.sprintf "t%d" i) in
      let with_admin rules =
        { (Sg_caps_json.to_wire C.empty) with Sg_caps_wire_capabilities.admin = rules }
      in
      Oth.Assert.ok (Sg_caps_json.of_wire (with_admin (rules 64))) |> ignore;
      Oth.Assert.error (Sg_caps_json.of_wire (with_admin (rules 65))) |> ignore;
      (* And per level of a reach, not only per scope. *)
      let states n =
        CCList.init n (fun i ->
            { Sg_caps_wire_state_reach.state = Printf.sprintf "s%d" i; addresses = [ "*" ] })
      in
      let with_states states =
        let reach = [ { Sg_caps_wire_tenant_reach.tenant = "*"; states } ] in
        {
          (Sg_caps_json.to_wire C.empty) with
          Sg_caps_wire_capabilities.preview =
            { Sg_caps_wire_actions.modified = reach; pulled_in = reach };
        }
      in
      Oth.Assert.ok (Sg_caps_json.of_wire (with_states (states 64))) |> ignore;
      Oth.Assert.error (Sg_caps_json.of_wire (with_states (states 65))) |> ignore;
      ())

let test =
  Oth.parallel
    [
      too_many_rules_examples;
      writes_examples;
      to_rules_examples;
      reads_examples;
      unreadable_examples;
      round_trip_examples;
      prop_round_trip;
      prop_written_once;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
