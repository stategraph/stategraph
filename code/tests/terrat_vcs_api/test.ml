module Oth_abb = Oth_abb.Make (Abb)
module Cr = Terrat_vcs_api.Centralized_repo

let test_is_config_path =
  Oth_abb.test ~tags:[ "centralized_repo" ] ~name:"is_config_path" (fun () ->
      CCList.iter
        (fun (path, expected) ->
          if not (Bool.equal (Cr.is_config_path path) expected) then
            failwith (Printf.sprintf "%S: expected %b" path expected))
        [
          ("config/defaults.yml", true);
          ("config/defaults.yaml", true);
          ("config/overrides.yml", true);
          ("config/overrides.yaml", true);
          ("config/repo/defaults.yml", true);
          ("config/repo/overrides.yaml", true);
          ("config/repo/config.yml", true);
          ("config/repo/config.yaml", true);
          ("config/config.yml", false);
          ("config/notes.md", false);
          ("config/base_image_config.sh", false);
          ("config/repo/notes.yml", false);
          ("config//config.yml", false);
          ("config/a/b/defaults.yml", false);
          ("defaults.yml", false);
          (".terrateam/config.yml", false);
          ("other/defaults.yml", false);
        ];
      Abb.Future.return ())

(* [holds_config] names the repositories that exist and hold a configuration file. *)
let select ~holds_config =
  Cr.select (fun name ->
      Abb.Future.return
        (Ok (if CCList.mem ~eq:CCString.equal name holds_config then Some name else None)))

let check_select ~name ~holds_config expected =
  Oth_abb.test ~tags:[ "centralized_repo" ] ~name (fun () ->
      let open Abb.Future.Infix_monad in
      select ~holds_config
      >>= function
      | Ok actual ->
          Oth_abb.Assert.Eq.string_option ~expected ~actual;
          Abb.Future.return ()
      | Error () -> failwith "select failed")

let test_select_error =
  Oth_abb.test ~tags:[ "centralized_repo" ] ~name:"select stops at an error" (fun () ->
      let open Abb.Future.Infix_monad in
      let asked = ref [] in
      Cr.select (fun name ->
          asked := name :: !asked;
          Abb.Future.return (Error name))
      >>= function
      | Error "stategraph" ->
          Oth_abb.Assert.Eq.string_list ~expected:[ "stategraph" ] ~actual:!asked;
          Abb.Future.return ()
      | Error name -> failwith (Printf.sprintf "error from %s" name)
      | Ok _ -> failwith "select did not fail")

let test =
  Oth_abb.parallel
    [
      test_is_config_path;
      check_select
        ~name:"only stategraph holds configuration"
        ~holds_config:[ "stategraph" ]
        (Some "stategraph");
      check_select
        ~name:"only terrateam holds configuration"
        ~holds_config:[ "terrateam" ]
        (Some "terrateam");
      check_select
        ~name:"both hold configuration"
        ~holds_config:[ "stategraph"; "terrateam" ]
        (Some "stategraph");
      check_select ~name:"neither holds configuration" ~holds_config:[] None;
      test_select_error;
    ]

let () =
  Random.self_init ();
  Oth_abb.run
    ~file:__FILE__
    ~setup:(fun () -> Abbs_future_combinators.return_ok ())
    ~teardown:(fun () -> Abb.Future.return ())
    (fun () -> test)
