let test_bool =
  Oth.test ~name:"Test Bool" (fun _ ->
      let base = `Bool true in
      let override = `Bool false in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok (`Bool false)"
        (Jsonu.merge ~base override = Ok (`Bool false));
      let base = `Bool false in
      let override = `Bool true in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok (`Bool true)"
        (Jsonu.merge ~base override = Ok (`Bool true));
      let base = `Null in
      let override = `Bool true in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok (`Bool true)"
        (Jsonu.merge ~base override = Ok (`Bool true));
      let base = `Bool true in
      let override = `Null in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok `Null"
        (Jsonu.merge ~base override = Ok `Null))

let test_int =
  Oth.test ~name:"Test Integer" (fun _ ->
      let base = `Int 1 in
      let override = `Int 2 in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok (`Int 2)"
        (Jsonu.merge ~base override = Ok (`Int 2));
      let base = `Null in
      let override = `Int 1 in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok (`Int 1)"
        (Jsonu.merge ~base override = Ok (`Int 1));
      let base = `Int 1 in
      let override = `Null in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok `Null"
        (Jsonu.merge ~base override = Ok `Null);
      let base = `Intlit "1" in
      let override = `Int 1 in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok (`Int 1)"
        (Jsonu.merge ~base override = Ok (`Int 1));
      let base = `Int 1 in
      let override = `Intlit "1" in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok (`Intlit \"1\")"
        (Jsonu.merge ~base override = Ok (`Intlit "1")))

let test_list =
  Oth.test ~name:"Test List" (fun _ ->
      let base = `List [ `Int 1; `Int 2 ] in
      let override = `List [ `Int 3; `Int 4 ] in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok (`List [ `Int 3; `Int 4; `Int 1; `Int 2 ])"
        (Jsonu.merge ~base override = Ok (`List [ `Int 3; `Int 4; `Int 1; `Int 2 ])))

let test_assoc =
  Oth.test ~name:"Test Assoc" (fun _ ->
      let base = `Assoc [ ("foo", `Int 1); ("bar", `String "foo") ] in
      let override = `Assoc [ ("foo", `Int 2); ("bar", `String "baz") ] in
      let res = CCResult.get_exn (Jsonu.merge ~base override) in
      Oth.Assert.true_
        "Yojson.Safe.Util.member \"foo\" res = `Int 2"
        (Yojson.Safe.Util.member "foo" res = `Int 2);
      Oth.Assert.true_
        "Yojson.Safe.Util.member \"bar\" res = `String \"baz\""
        (Yojson.Safe.Util.member "bar" res = `String "baz"))

let test_assoc_extra_keys_in_base =
  Oth.test ~name:"Test Assoc extra keys in base" (fun _ ->
      let base = `Assoc [ ("foo", `Int 1); ("bar", `String "foo") ] in
      let override = `Assoc [ ("foo", `Int 2) ] in
      let res = CCResult.get_exn (Jsonu.merge ~base override) in
      Oth.Assert.true_
        "Yojson.Safe.Util.member \"foo\" res = `Int 2"
        (Yojson.Safe.Util.member "foo" res = `Int 2);
      Oth.Assert.true_
        "Yojson.Safe.Util.member \"bar\" res = `String \"foo\""
        (Yojson.Safe.Util.member "bar" res = `String "foo"))

let test_type_mismatch_err =
  Oth.test ~name:"Test type mismatch err" (fun _ ->
      let base = `Int 1 in
      let override = `String "foo" in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Error (`Type_mismatch_err (None, `Int 1, `String \"foo\"))"
        (Jsonu.merge ~base override = Error (`Type_mismatch_err (None, `Int 1, `String "foo")));
      let base = `Assoc [ ("k", `Int 1) ] in
      let override = `Assoc [ ("k", `String "foo") ] in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Error (`Type_mismatch_err (Some \"k\", `Int 1, `String \
         \"foo\"))"
        (Jsonu.merge ~base override = Error (`Type_mismatch_err (Some "k", `Int 1, `String "foo")));
      let base = `Assoc [ ("j", `Assoc [ ("k", `Int 1) ]) ] in
      let override = `Assoc [ ("j", `Assoc [ ("k", `String "foo") ]) ] in
      Oth.Assert.true_
        "Jsonu.merge ~base override = Error (`Type_mismatch_err (Some \"j.k\", `Int 1, `String \
         \"foo\"))"
        (Jsonu.merge ~base override = Error (`Type_mismatch_err (Some "j.k", `Int 1, `String "foo"))))

let test_null_is_identity =
  Oth.test ~name:"Test null_is_identity" (fun _ ->
      (* null override preserves base when null_is_identity is true *)
      Oth.Assert.true_
        "Jsonu.merge ~null_is_identity:true ~base:(`Bool true) `Null = Ok (`Bool true)"
        (Jsonu.merge ~null_is_identity:true ~base:(`Bool true) `Null = Ok (`Bool true));
      Oth.Assert.true_
        "Jsonu.merge ~null_is_identity:true ~base:(`Int 1) `Null = Ok (`Int 1)"
        (Jsonu.merge ~null_is_identity:true ~base:(`Int 1) `Null = Ok (`Int 1));
      Oth.Assert.true_
        "Jsonu.merge ~null_is_identity:true ~base:(`String \"s\") `Null = Ok (`String \"s\")"
        (Jsonu.merge ~null_is_identity:true ~base:(`String "s") `Null = Ok (`String "s"));
      (* null base is still replaced by override *)
      Oth.Assert.true_
        "Jsonu.merge ~null_is_identity:true ~base:`Null (`Int 1) = Ok (`Int 1)"
        (Jsonu.merge ~null_is_identity:true ~base:`Null (`Int 1) = Ok (`Int 1));
      (* null base with null override stays null *)
      Oth.Assert.true_
        "Jsonu.merge ~null_is_identity:true ~base:`Null `Null = Ok `Null"
        (Jsonu.merge ~null_is_identity:true ~base:`Null `Null = Ok `Null);
      (* nested: null override in assoc preserves base value *)
      let base = `Assoc [ ("foo", `Int 1); ("bar", `String "hello") ] in
      let override = `Assoc [ ("foo", `Null) ] in
      let res = CCResult.get_exn (Jsonu.merge ~null_is_identity:true ~base override) in
      Oth.Assert.true_
        "Yojson.Safe.Util.member \"foo\" res = `Int 1"
        (Yojson.Safe.Util.member "foo" res = `Int 1);
      Oth.Assert.true_
        "Yojson.Safe.Util.member \"bar\" res = `String \"hello\""
        (Yojson.Safe.Util.member "bar" res = `String "hello");
      (* default behavior unchanged: null override replaces base *)
      Oth.Assert.true_
        "Jsonu.merge ~base:(`Bool true) `Null = Ok `Null"
        (Jsonu.merge ~base:(`Bool true) `Null = Ok `Null);
      Oth.Assert.true_
        "Jsonu.merge ~base:(`Int 1) `Null = Ok `Null"
        (Jsonu.merge ~base:(`Int 1) `Null = Ok `Null);
      ())

let test_list_append_mode =
  Oth.test ~name:"Test list `Append" (fun _ ->
      let base = `List [ `Int 1; `Int 2 ] in
      let override = `List [ `Int 3; `Int 4 ] in
      (* `Append: override appended to base *)
      Oth.Assert.true_
        "Jsonu.merge ~list:`Append ~base override = Ok (`List [ `Int 1; `Int 2; `Int 3; `Int 4 ])"
        (Jsonu.merge ~list:`Append ~base override = Ok (`List [ `Int 1; `Int 2; `Int 3; `Int 4 ]));
      (* default: override prepended to base *)
      Oth.Assert.true_
        "Jsonu.merge ~base override = Ok (`List [ `Int 3; `Int 4; `Int 1; `Int 2 ])"
        (Jsonu.merge ~base override = Ok (`List [ `Int 3; `Int 4; `Int 1; `Int 2 ]));
      ())

let test_both_params =
  Oth.test ~name:"Test null_is_identity and list `Append combined" (fun _ ->
      let base =
        `Assoc [ ("items", `List [ `Int 1 ]); ("name", `String "base"); ("extra", `Int 42) ]
      in
      let override = `Assoc [ ("items", `List [ `Int 2 ]); ("name", `Null) ] in
      let res =
        CCResult.get_exn (Jsonu.merge ~null_is_identity:true ~list:`Append ~base override)
      in
      (* list appended *)
      Oth.Assert.true_
        "Yojson.Safe.Util.member \"items\" res = `List [ `Int 1; `Int 2 ]"
        (Yojson.Safe.Util.member "items" res = `List [ `Int 1; `Int 2 ]);
      (* null override preserves base *)
      Oth.Assert.true_
        "Yojson.Safe.Util.member \"name\" res = `String \"base\""
        (Yojson.Safe.Util.member "name" res = `String "base");
      (* keys only in base are kept *)
      Oth.Assert.true_
        "Yojson.Safe.Util.member \"extra\" res = `Int 42"
        (Yojson.Safe.Util.member "extra" res = `Int 42);
      ())

(* Documents the duplication behind duplicate drift issues (#1789): the config
   builder receives the existing configuration and outputs a full config, and
   the engine then merges the repo config back on top of the builder's output.
   Scalars and objects converge (same value wins by key), but lists concatenate
   without deduplication, so a hook present in both layers runs twice. This
   test pins the current (surprising) behavior; a convergence strategy is the
   follow-up discussed on the issue. *)
let test_layer_echo_duplicates =
  Oth.test ~name:"Test identical layers duplicate lists" (fun _ ->
      let config =
        `Assoc
          [
            ("when_modified", `Assoc [ ("autoplan", `Bool true) ]);
            ( "hooks",
              `Assoc
                [
                  ( "plan",
                    `Assoc [ ("post", `List [ `Assoc [ ("type", `String "drift_create_issue") ] ]) ]
                  );
                ] );
          ]
      in
      let merged = CCResult.get_exn (Jsonu.merge ~base:config config) in
      let post = Yojson.Safe.Util.(member "post" (member "plan" (member "hooks" merged))) in
      (* Scalar converged... *)
      Oth.Assert.true_
        "autoplan stays a single bool"
        (Yojson.Safe.Util.(member "autoplan" (member "when_modified" merged)) = `Bool true);
      (* ...but the hook list doubled. *)
      Oth.Assert.true_
        "post hook list has doubled"
        (post
        = `List
            [
              `Assoc [ ("type", `String "drift_create_issue") ];
              `Assoc [ ("type", `String "drift_create_issue") ];
            ]))

let test =
  Oth.parallel
    [
      test_bool;
      test_int;
      test_list;
      test_assoc;
      test_assoc_extra_keys_in_base;
      test_type_mismatch_err;
      test_null_is_identity;
      test_list_append_mode;
      test_both_params;
      test_layer_echo_duplicates;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
