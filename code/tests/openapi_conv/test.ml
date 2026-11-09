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

let convert ~input_file ~output_dir =
  Openapi_conv.convert
    ~strict_records:false
    ~search_path:[]
    ~file_link:[]
    ~input_file
    ~output_name:"enum_api"
    ~output_dir

let test_integer_query_enums =
  Oth.test ~name:"Integer query enums are constrained" (fun _ ->
      with_output_dir (fun dir ->
          convert ~input_file:"integer_enum.json" ~output_dir:dir;
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
              convert ~input_file:"unsupported_array_default.json" ~output_dir:dir;
              None
            with Failure message -> Some message
          in
          Oth.Assert.str_contains
            ~haystack:(Oth.Assert.some failure)
            ~needle:"Unsupported query parameter default for \"codes\""))

let test_required_param_default_is_not_generated =
  Oth.test ~name:"The default of a required query parameter is not generated" (fun _ ->
      with_output_dir (fun dir ->
          convert ~input_file:"required_array_default.json" ~output_dir:dir;
          let generated = read_file (Filename.concat dir "enum_api_array.ml") CCIO.read_all in
          Oth.Assert.str_contains
            ~haystack:generated
            ~needle:"base_route /? (array (int \"codes\"))"))

module Alerts = Routes_api_alerts.List
module Has = Alerts.Parameters.Has
module Cwes = Alerts.Parameters.Cwes

(* The query parameters of the [/alerts] route, or [None] if the route does not match a GET of
   [uri]. *)
let match_alerts uri =
  Brtl_rtng.Route.match_ctx
    ~default:(fun _ -> None)
    [
      Brtl_rtng.Route.(
        Alerts.route (rel / "alerts") --> fun has cwes environment -> Some (has, cwes, environment));
    ]
    (Brtl_ctx.set_body "" (Brtl_ctx.create "127.0.0.1" (Brtl_ctx.Request.make (Uri.of_string uri))))

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

(* The test runs in _build/default/code/tests/openapi_conv, five directories below the root of the
   repository, so [query_params.expected] is reached in the source tree. Regenerate it after an
   intended change to the generator with:

     OTH_CREATE_EXPECTED_FILES=1 dune test code/tests/openapi_conv *)
let expected_query_params =
  CCList.fold_left
    Filename.concat
    (Filename.dirname Sys.executable_name)
    [ ".."; ".."; ".."; ".."; ".."; "code"; "tests"; "openapi_conv"; "query_params.expected" ]

let test_query_params_golden =
  Oth.test ~name:"The generated code of each query parameter shape is unchanged" (fun _ ->
      Oth.Diff.check
        ~tmp_dir_name:"openapi_conv"
        ~expected_file_path:expected_query_params
        ~actual_content:(read_file "query_params_api_params.ml" CCIO.read_all))

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
          test_one_of_query_params;
          test_nullable_query_param_default;
          test_query_params_golden;
        ])
