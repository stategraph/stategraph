module Cap = Terrat_job_context.Compute_node.Capabilities

(* The capabilities of a compute node live in a jsonb column, and RFD 2094 adds a
   field to them in more than one phase.  No phase writes a migration for that
   column.  A row that an earlier version of the server wrote must therefore
   still decode, with each field it has no value for at its default.

   This matters more than it looks.  [to_capabilities] in each provider turns a
   decode error into no node at all, and [Ret.u] turns that into [`Bad_result],
   which fails the whole query.  Every read of that node then fails, and the work
   manifest of the node waits for ever. *)
let decode name json expected =
  Oth.test ~name (fun _ ->
      match Cap.of_yojson (Yojson.Safe.from_string json) with
      | Ok capabilities -> Oth.Assert.eq ~eq:Cap.equal ~pp:Cap.pp expected capabilities
      | Error err -> raise (Failure ("decode failed: " ^ err)))

(* The shape before RFD 2094: the flags and the sha, and nothing else.  The
   encoder leaves out each field that holds its default, and the flags of a node
   are the default, so a real row of that time holds the sha alone. *)
let test_a_row_from_before_the_rfd =
  decode
    "a capabilities row from before RFD 2094 decodes"
    {|{"sha": "abc123"}|}
    {
      Cap.flags = [ Cap.Flags.One_shot ];
      sha = "abc123";
      environment = None;
      runs_on = None;
      used_work_manifests = 0;
      merge_phase = None;
    }

(* Flags that are not the default are written out, one array for each flag. *)
let test_a_row_with_flags =
  decode
    "a capabilities row with flags written out decodes"
    {|{"flags": [["One_shot"]], "sha": "abc123"}|}
    {
      Cap.flags = [ Cap.Flags.One_shot ];
      sha = "abc123";
      environment = None;
      runs_on = None;
      used_work_manifests = 0;
      merge_phase = None;
    }

(* The shape that the phase before this one wrote: it has no
   [used_work_manifests]. *)
let test_a_row_without_the_work_manifest_count =
  decode
    "a capabilities row without used_work_manifests decodes"
    {|{"flags": [], "sha": "abc123", "environment": "production",
       "runs_on": {"labels": ["self-hosted"]}, "max_workspaces": 3,
       "used_workspaces": 2}|}
    {
      Cap.flags = [];
      sha = "abc123";
      environment = Some "production";
      runs_on = Some (`Assoc [ ("labels", `List [ `String "self-hosted" ]) ]);
      used_work_manifests = 0;
      merge_phase = None;
    }

(* The shape that the phase before this one wrote: it has every field but
   [merge_phase].  A node of that shape has no phase, and [by_phase] gives it no
   more work. *)
let test_a_row_without_the_merge_phase =
  decode
    "a capabilities row without merge_phase decodes"
    {|{"flags": [], "sha": "abc123", "environment": "production",
       "runs_on": {"labels": ["self-hosted"]}, "max_workspaces": 3,
       "used_workspaces": 2, "used_work_manifests": 2}|}
    {
      Cap.flags = [];
      sha = "abc123";
      environment = Some "production";
      runs_on = Some (`Assoc [ ("labels", `List [ `String "self-hosted" ]) ]);
      used_work_manifests = 2;
      merge_phase = None;
    }

(* The two fields this version removed must not stop an old row from decoding.
   The deriving is lenient for exactly this reason, and the two tests above carry
   the removed keys for the same reason.  This one asks the question alone. *)
let test_a_row_with_only_the_removed_fields =
  decode
    "a capabilities row that carries only the removed workspace fields decodes"
    {|{"sha": "abc123", "max_workspaces": 3, "used_workspaces": 2}|}
    {
      Cap.flags = [ Cap.Flags.One_shot ];
      sha = "abc123";
      environment = None;
      runs_on = None;
      used_work_manifests = 0;
      merge_phase = None;
    }

(* Both phases must decode, because the wall of [by_phase] is the pair and not one
   of them. *)
let test_a_row_of_the_setup_phase =
  decode
    "a capabilities row of the setup phase decodes"
    {|{"flags": [], "sha": "abc123", "merge_phase": ["Setup"]}|}
    {
      Cap.flags = [];
      sha = "abc123";
      environment = None;
      runs_on = None;
      used_work_manifests = 0;
      merge_phase = Some Cap.Merge_phase.Setup;
    }

(* A row this version writes must survive a round trip, or a node would lose what
   it has already done every time the server reads it back. *)
let test_a_row_of_this_version_round_trips =
  Oth.test ~name:"a capabilities row of this version round trips" (fun _ ->
      let capabilities =
        {
          Cap.flags = [ Cap.Flags.One_shot ];
          sha = "deadbeef";
          environment = Some "development";
          runs_on = Some (`Assoc [ ("labels", `List [ `String "ubuntu-latest" ]) ]);
          used_work_manifests = 2;
          merge_phase = Some Cap.Merge_phase.Layer;
        }
      in
      match Cap.of_yojson (Cap.to_yojson capabilities) with
      | Ok decoded -> Oth.Assert.eq ~eq:Cap.equal ~pp:Cap.pp capabilities decoded
      | Error err -> raise (Failure ("decode failed: " ^ err)))

(* The carrier on the job type: a parameter map with the name unchanged. *)
module T = Terrat_job_context.Job.Type_

let expected_parameters = Sln_map.String.add "mode" "DEBUG" Sln_map.String.empty

(* The stored row of a job, decoded the way the provider decodes it before it
   builds the job type. *)
let decode_job_type json =
  match Terrat_job_type_type.of_yojson (Yojson.Safe.from_string json) with
  | Ok type_ -> type_
  | Error err -> raise (Failure ("decode failed: " ^ err))

(* A parameter map must survive its own yojson form: this is the shape that
   crosses into the stored row. *)
let test_parameters_map_round_trips =
  Oth.test ~name:"a parameter map round trips through yojson" (fun _ ->
      Oth.Assert.eq
        ~eq:T.Params.equal
        ~pp:T.Params.pp
        expected_parameters
        (Oth.Assert.ok_pp
           ~pp:Format.pp_print_string
           (T.Params.of_yojson (T.Params.to_yojson expected_parameters))))

(* The composition the provider runs: the map on the job type crosses into the
   generated job schema and comes back with the same bindings. *)
let test_parameters_compose_with_the_job_schema =
  Oth.test ~name:"a parameter map survives the job schema composition" (fun _ ->
      let generated =
        Oth.Assert.ok_pp
          ~pp:Format.pp_print_string
          (Terrat_job_type_run_params.of_yojson (T.Params.to_yojson expected_parameters))
      in
      Oth.Assert.eq
        ~eq:T.Params.equal
        ~pp:T.Params.pp
        expected_parameters
        (Oth.Assert.ok_pp
           ~pp:Format.pp_print_string
           (T.Params.of_yojson (Terrat_job_type_run_params.to_yojson generated))))

(* A stored plan row of a run with no run_params: the field is absent, and it
   must decode to [None].  A row written before this field existed is this
   row. *)
let test_a_stored_plan_row_without_parameters =
  Oth.test ~name:"a stored plan row without run_params decodes" (fun _ ->
      Oth.Assert.eq
        ~eq:Terrat_job_type_type.equal
        ~pp:Terrat_job_type_type.pp
        (Terrat_job_type_type.Plan
           {
             Terrat_job_type_plan.type_ = `Plan;
             tag_query = Some "directory:foo";
             kind = None;
             force_fail = None;
             run_params = None;
           })
        (decode_job_type {|{"type": "plan", "tag_query": "directory:foo"}|}))

(* A stored plan row of a run with run_params: the field carries the map. *)
let test_a_stored_plan_row_with_parameters =
  Oth.test ~name:"a stored plan row with run_params decodes" (fun _ ->
      match
        decode_job_type
          {|{"type": "plan", "tag_query": "directory:foo", "run_params": {"mode": "DEBUG"}}|}
      with
      | Terrat_job_type_type.Plan plan -> (
          match plan.Terrat_job_type_plan.run_params with
          | Some run_params ->
              Oth.Assert.eq
                ~eq:T.Params.equal
                ~pp:T.Params.pp
                expected_parameters
                (Oth.Assert.ok_pp
                   ~pp:Format.pp_print_string
                   (T.Params.of_yojson (Terrat_job_type_run_params.to_yojson run_params)))
          | None -> Oth.Assert.false_ "expected the row to carry run_params")
      | _ -> Oth.Assert.false_ "expected a plan row")

(* A stored apply row of a run with no parameters: the field is absent, and it
   must decode to [None]. *)
let test_a_stored_apply_row_without_parameters =
  Oth.test ~name:"a stored apply row without run_params decodes" (fun _ ->
      Oth.Assert.eq
        ~eq:Terrat_job_type_type.equal
        ~pp:Terrat_job_type_type.pp
        (Terrat_job_type_type.Apply
           {
             Terrat_job_type_apply.type_ = `Apply;
             tag_query = Some "directory:foo";
             kind = None;
             force = false;
             force_fail = None;
             run_params = None;
           })
        (decode_job_type {|{"type": "apply", "tag_query": "directory:foo"}|}))

(* A stored apply row of a run with run_params: the field carries the map. *)
let test_a_stored_apply_row_with_parameters =
  Oth.test ~name:"a stored apply row with run_params decodes" (fun _ ->
      match
        decode_job_type
          {|{"type": "apply", "tag_query": "directory:foo", "force": true, "run_params": {"mode": "DEBUG"}}|}
      with
      | Terrat_job_type_type.Apply apply -> (
          match apply.Terrat_job_type_apply.run_params with
          | Some run_params ->
              Oth.Assert.eq
                ~eq:T.Params.equal
                ~pp:T.Params.pp
                expected_parameters
                (Oth.Assert.ok_pp
                   ~pp:Format.pp_print_string
                   (T.Params.of_yojson (Terrat_job_type_run_params.to_yojson run_params)))
          | None -> Oth.Assert.false_ "expected the row to carry run_params")
      | _ -> Oth.Assert.false_ "expected an apply row")

(* A row whose parameter value is not a string breaks the schema and must be
   rejected, not read as a run with no parameters. *)
let test_a_stored_row_with_a_non_string_parameter_is_rejected =
  Oth.test ~name:"a stored row with a non-string parameter is rejected" (fun _ ->
      match
        Terrat_job_type_type.of_yojson
          (Yojson.Safe.from_string
             {|{"type": "plan", "tag_query": "directory:foo", "run_params": {"mode": 42}}|})
      with
      | Error _ -> ()
      | Ok _ -> Oth.Assert.false_ "expected the row to be rejected")

(* The sub-key is [run_params].  A row that still spells it [parameters] is a row
   of a build that no deployment carries, and the schema is strict: it must be
   rejected, not read as a run with no parameters. *)
let test_a_stored_row_with_the_old_parameters_key_is_rejected =
  Oth.test ~name:"a stored row with the old parameters key is rejected" (fun _ ->
      match
        Terrat_job_type_type.of_yojson
          (Yojson.Safe.from_string
             {|{"type": "plan", "tag_query": "directory:foo", "parameters": {"mode": "DEBUG"}}|})
      with
      | Error _ -> ()
      | Ok _ -> Oth.Assert.false_ "expected the row to be rejected")

let test =
  Oth.parallel
    [
      test_a_row_from_before_the_rfd;
      test_a_row_with_flags;
      test_a_row_without_the_work_manifest_count;
      test_a_row_without_the_merge_phase;
      test_a_row_with_only_the_removed_fields;
      test_a_row_of_the_setup_phase;
      test_a_row_of_this_version_round_trips;
      test_parameters_map_round_trips;
      test_parameters_compose_with_the_job_schema;
      test_a_stored_plan_row_without_parameters;
      test_a_stored_plan_row_with_parameters;
      test_a_stored_apply_row_without_parameters;
      test_a_stored_apply_row_with_parameters;
      test_a_stored_row_with_a_non_string_parameter_is_rejected;
      test_a_stored_row_with_the_old_parameters_key_is_rejected;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
