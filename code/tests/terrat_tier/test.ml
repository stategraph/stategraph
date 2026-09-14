let parse s =
  match Terrat_tier.of_yojson (Yojson.Safe.from_string s) with
  | Ok t -> t
  | Error err -> raise (Failure err)

let test_empty_features =
  Oth.test ~name:"Empty features" (fun _ ->
      let t = parse "{}" in
      Oth.Assert.true_
        "t.Terrat_tier.num_users_per_month = CCInt.max_int"
        (t.Terrat_tier.num_users_per_month = CCInt.max_int);
      Oth.Assert.true_
        "t.Terrat_tier.runs_per_month = CCInt.max_int"
        (t.Terrat_tier.runs_per_month = CCInt.max_int);
      Oth.Assert.true_
        "t.Terrat_tier.private_runners = CCInt.max_int"
        (t.Terrat_tier.private_runners = CCInt.max_int))

let test_free_tier_features =
  Oth.test ~name:"Free tier features" (fun _ ->
      let t = parse "{\"runs_per_month\":50,\"num_users_per_month\":3,\"private_runners\":1}" in
      Oth.Assert.Eq.int ~expected:3 ~actual:t.Terrat_tier.num_users_per_month;
      Oth.Assert.Eq.int ~expected:50 ~actual:t.Terrat_tier.runs_per_month;
      Oth.Assert.Eq.int ~expected:1 ~actual:t.Terrat_tier.private_runners)

let test_unknown_fields =
  Oth.test ~name:"Unknown fields are ignored" (fun _ ->
      let t = parse "{\"num_users_per_month\":3,\"some_future_feature\":true}" in
      Oth.Assert.Eq.int ~expected:3 ~actual:t.Terrat_tier.num_users_per_month)

let test_clamp_caps_win =
  Oth.test ~name:"Clamp: caps win over unlimited" (fun _ ->
      let t = Terrat_tier.clamp ~caps:Terrat_tier.oss (parse "{}") in
      Oth.Assert.Eq.int ~expected:3 ~actual:t.Terrat_tier.num_users_per_month;
      Oth.Assert.true_
        "t.Terrat_tier.runs_per_month = CCInt.max_int"
        (t.Terrat_tier.runs_per_month = CCInt.max_int);
      Oth.Assert.true_
        "t.Terrat_tier.private_runners = CCInt.max_int"
        (t.Terrat_tier.private_runners = CCInt.max_int))

let test_clamp_lower_tier_stays =
  Oth.test ~name:"Clamp: an already-lower tier keeps its own limits" (fun _ ->
      let t =
        Terrat_tier.clamp
          ~caps:Terrat_tier.oss
          (parse "{\"runs_per_month\":10,\"num_users_per_month\":1}")
      in
      Oth.Assert.Eq.int ~expected:1 ~actual:t.Terrat_tier.num_users_per_month;
      Oth.Assert.Eq.int ~expected:10 ~actual:t.Terrat_tier.runs_per_month)

let test_clamp_max_int_identity =
  Oth.test ~name:"Clamp: max_int caps are the identity" (fun _ ->
      let tier = parse "{\"runs_per_month\":50,\"num_users_per_month\":3}" in
      let t = Terrat_tier.clamp ~caps:(parse "{}") tier in
      Oth.Assert.true_ "clamp with empty caps is identity" (Terrat_tier.equal t tier))

let test =
  Oth.parallel
    [
      test_empty_features;
      test_free_tier_features;
      test_unknown_fields;
      test_clamp_caps_win;
      test_clamp_lower_tier_stays;
      test_clamp_max_int_identity;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
