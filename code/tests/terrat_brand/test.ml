let test_of_string =
  Oth.test ~tags:[ "brand" ] ~name:"of_string accepts both brands" (fun _ ->
      (match Terrat_brand.of_string "stategraph" with
      | Some Terrat_brand.Stategraph -> ()
      | _ -> failwith "stategraph did not parse");
      (match Terrat_brand.of_string "terrateam" with
      | Some Terrat_brand.Terrateam -> ()
      | _ -> failwith "terrateam did not parse");
      match Terrat_brand.of_string "acme" with
      | None -> ()
      | Some _ -> failwith "an unknown brand parsed")

let test_to_terrateam =
  Oth.test ~tags:[ "brand" ] ~name:"to_terrateam rewrites every brand form" (fun _ ->
      CCList.iter
        (fun (before, after) ->
          let got = Terrat_brand.to_terrateam before in
          if not (CCString.equal got after) then
            failwith (Printf.sprintf "%S became %S, expected %S" before got after))
        [
          ("Stategraph", "Terrateam");
          ("Stategraph's Console", "Terrateam's Console");
          ("stategraph apply", "terrateam apply");
          ("`stategraph plan`", "`terrateam plan`");
          ("support@stategraph.com", "support@terrateam.io");
          ("support@@stategraph.com", "support@@terrateam.io");
          ("https://stategraph.com/slack", "https://terrateam.io/slack");
          ("https://stategraph.com/pricing", "https://terrateam.io/pricing");
          ("`.stategraph/config.yml`", "`.terrateam/config.yml`");
        ])

let test_terrateam_text_unchanged =
  Oth.test ~tags:[ "brand" ] ~name:"to_terrateam leaves Terrateam text alone" (fun _ ->
      CCList.iter
        (fun s ->
          if not (CCString.equal (Terrat_brand.to_terrateam s) s) then
            failwith (Printf.sprintf "%S was rewritten" s))
        [
          "terrateam apply";
          "Terrateam Console";
          "https://terrateam.io/docs/configuration";
          "https://docs.terrateam.io/getting-started";
          "support@terrateam.io";
        ])

let test_idempotent =
  Oth.test ~tags:[ "brand" ] ~name:"to_terrateam is idempotent" (fun _ ->
      let s = "Stategraph says `stategraph apply`, see https://stategraph.com/pricing" in
      let once = Terrat_brand.to_terrateam s in
      if not (CCString.equal (Terrat_brand.to_terrateam once) once) then
        failwith "a second rewrite changed the text")

let test_directory =
  Oth.test ~tags:[ "brand" ] ~name:"directory names the configuration directory" (fun _ ->
      Oth.Assert.Eq.string_list
        ~expected:[ ".stategraph"; ".terrateam" ]
        ~actual:(CCList.map Terrat_brand.directory Terrat_brand.all);
      ())

let test_of_repo_name =
  Oth.test ~tags:[ "brand" ] ~name:"of_repo_name accepts any case" (fun _ ->
      let check ~expected name =
        Oth.Assert.Eq.option
          ~eq:Terrat_brand.equal
          ~pp:Terrat_brand.pp
          ~expected
          ~actual:(Terrat_brand.of_repo_name name)
      in
      check ~expected:(Some Terrat_brand.Stategraph) "stategraph";
      check ~expected:(Some Terrat_brand.Stategraph) "Stategraph";
      check ~expected:(Some Terrat_brand.Terrateam) "Terrateam";
      check ~expected:None "terraform";
      ())

let test_of_env =
  Oth.test ~tags:[ "brand" ] ~name:"of_env reads TERRAT_BRAND" (fun _ ->
      let check value ~expected =
        Unix.putenv "TERRAT_BRAND" value;
        match (Terrat_brand.of_env (), expected) with
        | Ok actual, Ok expected ->
            Oth.Assert.Eq.option ~eq:Terrat_brand.equal ~pp:Terrat_brand.pp ~expected ~actual
        | Error _, Error () -> ()
        | Ok _, Error () -> failwith (Printf.sprintf "%S parsed" value)
        | Error msg, Ok _ -> failwith (Printf.sprintf "%S did not parse: %s" value msg)
      in
      check "terrateam" ~expected:(Ok (Some Terrat_brand.Terrateam));
      check " Stategraph\n" ~expected:(Ok (Some Terrat_brand.Stategraph));
      check "acme" ~expected:(Error ());
      check "" ~expected:(Error ());
      ())

(* One case for each step of the brand selection, and one for each pair of steps that apply at
   the same time: the earlier step wins. *)
let test_resolve =
  Oth.test ~tags:[ "brand" ] ~name:"resolve takes the first step that applies" (fun _ ->
      let open Terrat_brand in
      let check ~name ?forced_config ?repo_config ?centralized ~fallback expected =
        let actual = resolve ~forced_config ~repo_config ~centralized ~fallback in
        if not (equal expected actual) then
          failwith (Printf.sprintf "%s: expected %s, got %s" name (show expected) (show actual))
      in
      check ~name:"fallback only" ~fallback:Terrateam Terrateam;
      check ~name:"forced config" ~forced_config:Terrateam ~fallback:Stategraph Terrateam;
      check ~name:"repo config" ~repo_config:Terrateam ~fallback:Stategraph Terrateam;
      check ~name:"centralized" ~centralized:Terrateam ~fallback:Stategraph Terrateam;
      check
        ~name:"forced config over repo config"
        ~forced_config:Stategraph
        ~repo_config:Terrateam
        ~centralized:Stategraph
        ~fallback:Terrateam
        Stategraph;
      check
        ~name:"forced config over centralized"
        ~forced_config:Terrateam
        ~centralized:Terrateam
        ~fallback:Stategraph
        Terrateam;
      check
        ~name:"repo config over centralized"
        ~repo_config:Terrateam
        ~centralized:Stategraph
        ~fallback:Stategraph
        Terrateam;
      check ~name:"repo config over fallback" ~repo_config:Stategraph ~fallback:Terrateam Stategraph;
      check ~name:"centralized over fallback" ~centralized:Stategraph ~fallback:Terrateam Stategraph;
      ())

(* [branded] prepares its answer for each brand one time, and the count proves
   that it is not prepared again for each call. *)
let test_branded =
  Oth.test ~tags:[ "brand" ] ~name:"branded prepares each brand one time" (fun _ ->
      let calls = ref 0 in
      let prepared =
        Terrat_brand.branded
          (fun s ->
            incr calls;
            CCString.uppercase_ascii s)
          "Run `stategraph plan`, see https://stategraph.com/pricing"
      in
      Oth.Assert.Eq.int ~expected:2 ~actual:!calls;
      Oth.Assert.Eq.string
        ~expected:"RUN `STATEGRAPH PLAN`, SEE HTTPS://STATEGRAPH.COM/PRICING"
        ~actual:(prepared Terrat_brand.Stategraph);
      Oth.Assert.Eq.string
        ~expected:"RUN `TERRATEAM PLAN`, SEE HTTPS://TERRATEAM.IO/PRICING"
        ~actual:(prepared Terrat_brand.Terrateam);
      Oth.Assert.Eq.int ~expected:2 ~actual:!calls;
      ())

let test =
  Oth.parallel
    [
      test_of_string;
      test_to_terrateam;
      test_terrateam_text_unchanged;
      test_idempotent;
      test_directory;
      test_of_repo_name;
      test_of_env;
      test_resolve;
      test_branded;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
