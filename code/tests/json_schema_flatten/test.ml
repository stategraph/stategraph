module U = Yojson.Safe.Util

let flatten = Json_schema_flatten.flatten_document
let load = Yojson.Safe.from_file
let def name j = U.member name (U.member "definitions" j)
let prop p obj = U.member p (U.member "properties" obj)
let ref_of node = U.to_string (U.member "$ref" node)
let present node = node <> `Null

(* Default mode: a foreign ref is inlined under a stem-namespaced canonical name and its ref is
   rewritten to an internal one.  Local and transitive refs behave as expected. *)
let test_inline =
  Oth.test ~name:"Inline foreign ref (default)" (fun _ ->
      let flat = flatten ~search_path:[] ~file_link:[] ~root_file:"main.json" (load "main.json") in
      let person = def "Person" flat in
      (* foreign ref rewritten to internal canonical *)
      Oth.Assert.Eq.string
        ~expected:"#/definitions/common_address"
        ~actual:(ref_of (prop "address" person));
      (* local ref untouched *)
      Oth.Assert.Eq.string ~expected:"#/definitions/Place" ~actual:(ref_of (prop "home" person));
      (* foreign definition pulled in *)
      Oth.Assert.true_ (present (def "common_address" flat));
      (* transitive foreign ref pulled in and rewritten *)
      Oth.Assert.Eq.string
        ~expected:"#/definitions/deep_zip"
        ~actual:(ref_of (prop "zip" (def "common_address" flat)));
      Oth.Assert.true_ (present (def "deep_zip" flat)))

(* --file-link mode: the ref points at an existing module and the file is neither loaded nor
   inlined (so its transitive deps are not pulled in either). *)
let test_file_link =
  Oth.test ~name:"File-link foreign ref" (fun _ ->
      let flat =
        flatten
          ~search_path:[]
          ~file_link:[ ("common.json", "Common") ]
          ~root_file:"main.json"
          (load "main.json")
      in
      let person = def "Person" flat in
      Oth.Assert.Eq.string
        ~expected:"#/file-link/Common/Address"
        ~actual:(ref_of (prop "address" person));
      (* not inlined *)
      Oth.Assert.not_true (present (def "common_address" flat));
      (* common.json was never loaded, so its transitive dep is absent too *)
      Oth.Assert.not_true (present (def "deep_zip" flat)))

(* The search path is consulted when the ref cannot be found next to the referencing file. *)
let test_search_path =
  Oth.test ~name:"Foreign ref resolved via search path" (fun _ ->
      let flat =
        flatten ~search_path:[ "sub" ] ~file_link:[] ~root_file:"main2.json" (load "main2.json")
      in
      Oth.Assert.Eq.string
        ~expected:"#/definitions/lib_x"
        ~actual:(ref_of (prop "x" (def "Root" flat)));
      Oth.Assert.true_ (present (def "lib_x" flat)))

(* Mutually-recursive foreign files terminate and both definitions are inlined. *)
let test_cycle =
  Oth.test ~name:"Cyclic foreign refs terminate" (fun _ ->
      let flat = flatten ~search_path:[] ~file_link:[] ~root_file:"a.json" (load "a.json") in
      Oth.Assert.Eq.string ~expected:"#/definitions/b_b" ~actual:(ref_of (prop "b" (def "A" flat)));
      Oth.Assert.Eq.string
        ~expected:"#/definitions/a_a"
        ~actual:(ref_of (prop "a" (def "b_b" flat)));
      Oth.Assert.true_ (present (def "a_a" flat)))

(* An internal ref inside an inlined foreign definition points into its own file: the target is
   inlined too and the ref rewritten to it. *)
let test_foreign_internal_ref =
  Oth.test ~name:"Internal ref of a foreign definition" (fun _ ->
      let flat = flatten ~search_path:[] ~file_link:[] ~root_file:"main.json" (load "main.json") in
      Oth.Assert.Eq.string
        ~expected:"#/definitions/common_city"
        ~actual:(ref_of (prop "city" (def "common_address" flat)));
      Oth.Assert.true_ (present (def "common_city" flat));
      ())

(* A ref into the components of an OpenAPI document is inlined like a ref into [definitions], with
   the internal refs of the component. *)
let test_components_inline =
  Oth.test ~name:"Inline OpenAPI component ref" (fun _ ->
      let flat =
        flatten
          ~search_path:[]
          ~file_link:[]
          ~root_file:"openapi_main.json"
          (load "openapi_main.json")
      in
      Oth.Assert.Eq.string
        ~expected:"#/definitions/openapi_tx_detail"
        ~actual:(ref_of (prop "transaction" (def "Output" flat)));
      Oth.Assert.Eq.string
        ~expected:"#/definitions/openapi_tx"
        ~actual:(ref_of (prop "tx" (def "openapi_tx_detail" flat)));
      Oth.Assert.true_ (present (def "openapi_tx" flat));
      ())

(* A ref into the components of a file-linked OpenAPI document points at the existing module. *)
let test_components_file_link =
  Oth.test ~name:"File-link OpenAPI component ref" (fun _ ->
      let flat =
        flatten
          ~search_path:[]
          ~file_link:[ ("openapi.json", "Api") ]
          ~root_file:"openapi_main.json"
          (load "openapi_main.json")
      in
      Oth.Assert.Eq.string
        ~expected:"#/file-link/Api/tx-detail"
        ~actual:(ref_of (prop "transaction" (def "Output" flat)));
      Oth.Assert.not_true (present (def "openapi_tx_detail" flat));
      ())

(* A file-link whose path equals the ref's path wins over one that matches only its basename. *)
let test_file_link_same_basename =
  Oth.test ~name:"File-link of two files with the same basename" (fun _ ->
      let flat =
        flatten
          ~search_path:[]
          ~file_link:[ ("common.json", "Common"); ("sub/common.json", "Sub_common") ]
          ~root_file:"same_basename.json"
          (load "same_basename.json")
      in
      let root = def "Root" flat in
      Oth.Assert.Eq.string ~expected:"#/file-link/Common/Address" ~actual:(ref_of (prop "a" root));
      Oth.Assert.Eq.string
        ~expected:"#/file-link/Sub_common/Address"
        ~actual:(ref_of (prop "b" root)))

(* An unresolvable foreign file is a hard error. *)
let test_missing_file =
  Oth.test ~name:"Missing foreign file raises" (fun _ ->
      let raised =
        try
          ignore (flatten ~search_path:[] ~file_link:[] ~root_file:"main2.json" (load "main2.json"));
          false
        with Failure _ -> true
      in
      Oth.Assert.true_ raised)

let test =
  Oth.parallel
    [
      test_inline;
      test_file_link;
      test_search_path;
      test_cycle;
      test_foreign_internal_ref;
      test_components_inline;
      test_components_file_link;
      test_file_link_same_basename;
      test_missing_file;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
