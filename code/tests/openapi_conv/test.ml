let read_file = CCIO.with_in

let remove_dir dir =
  try
    Array.iter (fun name -> Sys.remove (Filename.concat dir name)) (Sys.readdir dir);
    Unix.rmdir dir
  with Sys_error _ -> ()

let with_output_dir f =
  let dir = Filename.temp_file "openapi-conv-enum-" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o700;
  Fun.protect ~finally:(fun () -> remove_dir dir) (fun () -> f dir)

let convert ~input_file ~output_name ~output_dir =
  Openapi_conv.convert
    ~strict_records:false
    ~search_path:[]
    ~file_link:[]
    ~input_file
    ~output_name
    ~output_dir

let test_integer_query_enums =
  Oth.test ~name:"Integer query enums are constrained" (fun _ ->
      with_output_dir (fun dir ->
          convert ~input_file:"integer_enum.json" ~output_name:"enum_api" ~output_dir:dir;
          let generated = read_file (Filename.concat dir "enum_api_enum.ml") CCIO.read_all in
          Oth.Assert.str_contains_all
            ~haystack:generated
            ~needles:
              [
                "CCInt.of_string value";
                "Some 1 -> Some 1";
                "Some 4 -> Some 4";
                "CCInt64.of_string value";
                "Some 10000000000L";
                "Some 20000000000L";
                "let open Brtl_rtng.Route.Query in";
              ];
          Oth.Assert.str_doesnt_contain ~haystack:generated ~needle:"Brtl_rtng.Route.Query."))

let test_unsupported_default_fails_generation =
  Oth.test ~name:"Unsupported query defaults fail generation" (fun _ ->
      with_output_dir (fun dir ->
          let failure =
            try
              convert
                ~input_file:"unsupported_array_default.json"
                ~output_name:"enum_api"
                ~output_dir:dir;
              None
            with Failure message -> Some message
          in
          Oth.Assert.str_contains
            ~haystack:(Oth.Assert.some failure)
            ~needle:"Unsupported query parameter default for \"codes\""))

let test_required_param_default_is_not_generated =
  Oth.test ~name:"The default of a required query parameter is not generated" (fun _ ->
      with_output_dir (fun dir ->
          convert ~input_file:"required_array_default.json" ~output_name:"enum_api" ~output_dir:dir;
          let generated = read_file (Filename.concat dir "enum_api_array.ml") CCIO.read_all in
          Oth.Assert.str_contains
            ~haystack:generated
            ~needle:"(rel / \"array\") /? (array (int \"codes\"))"))

(* The failure message of the generation of [input_file], which must fail. *)
let generation_failure input_file =
  with_output_dir (fun dir ->
      try
        convert ~input_file ~output_name:"enum_api" ~output_dir:dir;
        Oth.Assert.false_ ("The generation of " ^ input_file ^ " succeeded")
      with Failure message -> message)

let test_undeclared_template_param_fails_generation =
  Oth.test ~name:"A path template parameter that is not declared fails generation" (fun _ ->
      Oth.Assert.str_contains
        ~haystack:(generation_failure "undeclared_template_param.json")
        ~needle:"Path template /things/{id} of things/get: {id} is not a declared path parameter")

let test_path_param_not_in_template_fails_generation =
  Oth.test
    ~name:"A declared path parameter that is not in the path template fails generation"
    (fun _ ->
      Oth.Assert.str_contains
        ~haystack:(generation_failure "path_param_not_in_template.json")
        ~needle:"Path parameter \"thing_id\" of things/get is not in its path template /things/{id}")

(* What the handler of [route] returns for a GET of [uri], or [None] if [route] does not match. *)
let match_route route uri =
  Brtl_rtng.Route.match_ctx
    ~default:(fun _ -> None)
    [ route ]
    (Brtl_ctx.set_body "" (Brtl_ctx.create "127.0.0.1" (Brtl_ctx.Request.make (Uri.of_string uri))))

module Alerts = Routes_api_alerts.List
module Has = Alerts.Parameters.Has
module Cwes = Alerts.Parameters.Cwes

(* The query parameters of the [/alerts] route, or [None] if the route does not match a GET of
   [uri]. *)
let match_alerts =
  match_route
    Brtl_rtng.Route.(Alerts.route () --> fun has cwes environment -> Some (has, cwes, environment))

let test_one_of_query_params =
  Oth.test ~name:"oneOf query parameters choose the alternative from the values" (fun _ ->
      let assert_has ~expected uri =
        let has, _, _ = Oth.Assert.some (match_alerts uri) in
        Oth.Assert.Eq.option ~eq:Has.equal ~pp:Has.pp ~expected ~actual:has
      in
      let assert_cwes ~expected uri =
        let _, cwes, _ = Oth.Assert.some (match_alerts uri) in
        Oth.Assert.Eq.option ~eq:Cwes.equal ~pp:Cwes.pp ~expected ~actual:cwes
      in
      assert_has ~expected:None "/alerts";
      assert_has ~expected:(Some (Has.V0 "patch")) "/alerts?has=patch";
      assert_has ~expected:(Some (Has.V0 "other")) "/alerts?has=other";
      assert_has ~expected:(Some (Has.V1 [ `Patch; `Patch ])) "/alerts?has=patch,patch";
      assert_has ~expected:(Some (Has.V1 [ `Patch; `Patch ])) "/alerts?has=patch&has=patch";
      assert_cwes ~expected:(Some (Cwes.V0 "79")) "/alerts?cwes=79";
      assert_cwes ~expected:(Some (Cwes.V1 [ "79"; "80" ])) "/alerts?cwes=79,80";
      Oth.Assert.none (match_alerts "/alerts?has=patch,other"))

let test_nullable_query_param_default =
  Oth.test ~name:"A nullable query parameter takes its default when it is absent" (fun _ ->
      let environment uri =
        let _, _, environment = Oth.Assert.some (match_alerts uri) in
        environment
      in
      Oth.Assert.Eq.string_option ~expected:(Some "none") ~actual:(environment "/alerts");
      Oth.Assert.Eq.string_option
        ~expected:(Some "prod")
        ~actual:(environment "/alerts?environment=prod"))

module Items = Routes_api_items.Get
module Colors = Routes_api_colors.Get
module Packages = Routes_api_packages.Get

let tenant_id = "c0708dee-4e89-470a-a4b8-83cbc4051327"

(* The route of [items/get] in routes.json:

     /tenants/{tenant_id: uuid}/items/{name: string}/{count: int}/{big: int64}
       ?limit=<int, default 5>

   Its handler takes the path parameters in the order of the template, then [limit], although
   routes.json declares [limit] first. *)
let match_items =
  match_route
    Brtl_rtng.Route.(
      Items.route ()
      --> fun tenant_id name count big limit -> Some (tenant_id, name, count, big, limit))

let test_path_params =
  Oth.test
    ~name:"Path parameters are extracted in the order of the template, before the query"
    (fun _ ->
      let tenant, name, count, big, limit =
        Oth.Assert.some
          (match_items ("/tenants/" ^ tenant_id ^ "/items/a%20b/3/10000000000?limit=7"))
      in
      Oth.Assert.eq
        ~eq:Uuidm.equal
        ~pp:Uuidm.pp
        (Oth.Assert.some (Uuidm.of_string tenant_id))
        tenant;
      Oth.Assert.Eq.string ~expected:"a b" ~actual:name;
      Oth.Assert.Eq.int ~expected:3 ~actual:count;
      Oth.Assert.eq ~eq:Int64.equal ~pp:CCInt64.pp 10000000000L big;
      Oth.Assert.Eq.int ~expected:7 ~actual:limit)

let test_path_params_mismatch =
  Oth.test ~name:"A path parameter that does not parse does not match the route" (fun _ ->
      Oth.Assert.none (match_items "/tenants/not-a-uuid_wrong/items/a/3/1");
      Oth.Assert.none (match_items ("/tenants/" ^ tenant_id ^ "/items/a/three_wrong/1"));
      Oth.Assert.none (match_items ("/tenants/" ^ tenant_id ^ "/items/a/3/big_wrong"));
      (* No [big] segment. *)
      Oth.Assert.none (match_items ("/tenants/" ^ tenant_id ^ "/items/a/3"));
      Oth.Assert.none (match_items ("/tenants/" ^ tenant_id ^ "/other_wrong/a/3/1")))

(* The route of [colors/get] in routes.json:

     /colors/{color: red | green}/{workflow: oneOf int | string}

   A [workflow] that parses as an integer is the first alternative, [V0]; any other is [V1]. *)
let match_colors =
  match_route Brtl_rtng.Route.(Colors.route () --> fun color workflow -> Some (color, workflow))

let test_enum_and_one_of_path_params =
  Oth.test ~name:"Enum and oneOf path parameters parse into the client types" (fun _ ->
      let assert_colors ~expected uri =
        Oth.Assert.eq
          ~eq:(CCEqual.pair Colors.Parameters.Color.equal Colors.Parameters.Workflow.equal)
          ~pp:(CCFormat.pair Colors.Parameters.Color.pp Colors.Parameters.Workflow.pp)
          expected
          (Oth.Assert.some (match_colors uri))
      in
      assert_colors ~expected:(`Red, Colors.Parameters.Workflow.V0 12) "/colors/red/12";
      assert_colors
        ~expected:(`Green, Colors.Parameters.Workflow.V1 "ci.yml")
        "/colors/green/ci.yml";
      Oth.Assert.none (match_colors "/colors/blue/12"))

(* The route of [packages/get] in routes.json:

     /packages/binary-{arch: string}/{version: string}.info *)
let match_packages =
  match_route Brtl_rtng.Route.(Packages.route () --> fun arch version -> Some (arch, version))

let test_partial_segment_path_params =
  Oth.test
    ~name:"A path parameter in part of a segment is extracted without the literal text"
    (fun _ ->
      let arch, version = Oth.Assert.some (match_packages "/packages/binary-amd64/1.2.3.info") in
      Oth.Assert.Eq.string ~expected:"amd64" ~actual:arch;
      Oth.Assert.Eq.string ~expected:"1.2.3" ~actual:version;
      Oth.Assert.none (match_packages "/packages/amd64/1.2.3.info");
      Oth.Assert.none (match_packages "/packages/binary-amd64/1.2.3"))

(* The test runs in _build/default/code/tests/openapi_conv, five directories below the root of the
   repository, so [file] is reached in the source tree. *)
let source_file file =
  CCList.fold_left
    Filename.concat
    (Filename.dirname Sys.executable_name)
    [ ".."; ".."; ".."; ".."; ".."; "code"; "tests"; "openapi_conv"; file ]

(* The converter generates, from [input_file], exactly the committed fixture API [files]. Regenerate
   them after an intended change to the converter with:

     OTH_CREATE_EXPECTED_FILES=1 dune test code/tests/openapi_conv *)
let test_fixture_api_golden ~name ~input_file ~output_name ~files =
  Oth.test ~name (fun _ ->
      with_output_dir (fun dir ->
          convert ~input_file ~output_name ~output_dir:dir;
          Oth.Assert.Eq.string_list
            ~expected:files
            ~actual:(CCList.sort CCString.compare (CCArray.to_list (Sys.readdir dir)));
          CCList.iter
            (fun file ->
              Oth.Diff.check
                ~tmp_dir_name:"openapi_conv"
                ~expected_file_path:(source_file file)
                ~actual_content:(read_file (Filename.concat dir file) CCIO.read_all))
            files))

let test_routes_golden =
  test_fixture_api_golden
    ~name:"The generated code of the routes is unchanged"
    ~input_file:"routes.json"
    ~output_name:"routes_api"
    ~files:
      [
        "routes_api_alerts.ml";
        "routes_api_colors.ml";
        "routes_api_components.ml";
        "routes_api_items.ml";
        "routes_api_packages.ml";
      ]

let test_query_params_golden =
  test_fixture_api_golden
    ~name:"The generated code of each query parameter shape is unchanged"
    ~input_file:"query_params.json"
    ~output_name:"query_params_api"
    ~files:
      [
        "query_params_api_components.ml";
        "query_params_api_components_shade.ml";
        "query_params_api_params.ml";
      ]

let () =
  Oth.run
    ~file:__FILE__
    ~setup:(fun () -> Ok ())
    ~teardown:(fun _ -> ())
    (fun _ ->
      Oth.parallel
        [
          test_integer_query_enums;
          test_unsupported_default_fails_generation;
          test_required_param_default_is_not_generated;
          test_undeclared_template_param_fails_generation;
          test_path_param_not_in_template_fails_generation;
          test_one_of_query_params;
          test_nullable_query_param_default;
          test_path_params;
          test_path_params_mismatch;
          test_enum_and_one_of_path_params;
          test_partial_segment_path_params;
          test_routes_golden;
          test_query_params_golden;
        ])
