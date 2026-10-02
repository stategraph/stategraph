(* Unit tests for the pure part of the group-rules engine: condition matching, the single-key JSON
   (de)serialization of [cond], grant evaluation (union of matching rules), and validation.  The
   storage functions ([list_alive]/[add]/[soft_delete]) need a database and are exercised by the
   integration suite, not here. *)

module R = Sgs_caps_rules
module C = Sg_caps
module Q = QCheck2

(* File-local extension of [Oth]: [include] the real runner/assertions, then add domain shorthands
   for the [R.matches] boolean so the rest of the file reads better. *)
module Oth = struct
  include Oth

  let matches cond ~groups = Assert.true_ (R.matches cond ~groups)
  let doesnt_match cond ~groups = Assert.not_true (R.matches cond ~groups)
end

let uid = CCOption.get_exn_or "bad uuid" (Uuidm.of_string "00000000-0000-0000-0000-000000000000")

let rule condition grant =
  let tenant_id = uid in
  let created_at = "" in
  { R.id = uid; tenant_id; created_at; created_by = uid; description = None; condition; grant }

let admin_grant = { C.empty with C.admin = Sg_caps_trie_scope.full }

let preview_grant =
  {
    C.empty with
    C.preview = { C.modified = Sg_caps_reach.everything; pulled_in = Sg_caps_reach.everything };
  }

let cond_matches =
  Oth.test ~name:"cond_matches" (fun _ ->
      Oth.matches (R.Group "eng-*") ~groups:[ "eng-web"; "x" ];
      Oth.doesnt_match (R.Group "sre") ~groups:[ "eng-web" ];
      Oth.matches (R.Group "sre") ~groups:[ "sre" ];
      Oth.matches (R.Any [ R.Group "sre"; R.Group "eng-*" ]) ~groups:[ "eng-web" ];
      Oth.doesnt_match (R.Any [ R.Group "sre"; R.Group "ops" ]) ~groups:[ "eng-web" ];
      Oth.matches
        (R.All [ R.Group "eng-*"; R.Group "contractor" ])
        ~groups:[ "eng-web"; "contractor" ];
      Oth.doesnt_match (R.All [ R.Group "eng-*"; R.Group "contractor" ]) ~groups:[ "eng-web" ];
      Oth.doesnt_match (R.Any []) ~groups:[ "eng-web" ];
      Oth.matches (R.All []) ~groups:[ "eng-web" ];
      ())

(* Property: for any generated [cond], decoding its encoding reproduces it exactly.  This pins the
   two hand-written serializers as mutual inverses over arbitrary trees (the guarantee we forgo by
   not using [@@deriving yojson] (see the module's design note)). *)
let prop_json_roundtrip =
  Oth.test ~name:"prop_json_roundtrip" (fun _ ->
      Q.Test.check_exn
        (Q.Test.make
           ~count:1000
           ~name:"cond json roundtrip: of_yojson (to_yojson c) = Ok c"
           ~print:R.show_cond
           Sgs_caps_rules_gen.cond_gen
           (fun c -> R.cond_of_yojson (R.cond_to_yojson c) = Ok c)))

(* Negative decode cases the round-trip property cannot reach: a wrong operator key and a non-object
   must both be rejected rather than silently accepted. *)
let json_decode_rejects =
  Oth.test ~name:"json_decode_rejects" (fun _ ->
      Oth.Assert.error_pp ~pp:R.pp_cond (R.cond_of_yojson (`Assoc [ ("bogus", `String "x") ]))
      |> ignore;
      Oth.Assert.error_pp ~pp:R.pp_cond (R.cond_of_yojson (`String "nope")) |> ignore)

let eval_union =
  Oth.test ~name:"eval_union" (fun _ ->
      let rules = [ rule (R.Group "platform") admin_grant; rule (R.Group "eng-*") preview_grant ] in
      let reaches_something actions =
        not (Sg_caps_reach.is_empty actions.C.modified && Sg_caps_reach.is_empty actions.C.pulled_in)
      in
      let e_eng = R.eval rules ~groups:[ "eng-web" ] in
      Oth.Assert.true_ (reaches_something e_eng.C.preview);
      Oth.Assert.true_ (Sg_caps_trie_scope.is_empty e_eng.C.admin);
      let e_plat = R.eval rules ~groups:[ "platform" ] in
      Oth.Assert.true_ (Sg_caps_trie_scope.is_full e_plat.C.admin);
      Oth.Assert.not_true (reaches_something e_plat.C.preview);
      let e_none = R.eval rules ~groups:[ "random" ] in
      Oth.Assert.true_ (Sg_caps_trie_scope.is_empty e_none.C.admin);
      Oth.Assert.not_true (reaches_something e_none.C.preview);
      (* The join does not depend on the order the rules come in, whatever the grants are. *)
      let both = [ "eng-web"; "platform" ] in
      let fwd = R.eval rules ~groups:both in
      let rev = R.eval (CCList.rev rules) ~groups:both in
      Oth.Assert.true_ (Sg_caps_trie_scope.is_full fwd.C.admin && reaches_something fwd.C.preview);
      Oth.Assert.true_ (C.equivalent fwd rev);
      ())

let validate =
  Oth.test ~name:"validate" (fun _ ->
      Oth.Assert.error_pp
        ~pp:(fun fmt () -> Format.pp_print_string fmt "ok")
        (R.validate_cond (R.All [ R.Group "ok"; R.Group "a**" ]))
      |> ignore;
      Oth.Assert.ok_pp
        ~pp:Format.pp_print_string
        (R.validate_cond (R.Any [ R.Group "eng-*"; R.Group "sre" ]));
      ())

let test =
  Oth.parallel [ cond_matches; prop_json_roundtrip; json_decode_rejects; eval_union; validate ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
