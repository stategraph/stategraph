let marked_comment_is_from_self =
  Oth.test ~name:"marked comment is from self" (fun _ ->
      let body = Terrat_comment.add_self_marker "## Plan Output" in
      Oth.Assert.true_ (Terrat_comment.is_from_self body);
      ())

let plain_comment_is_not_from_self =
  Oth.test ~name:"plain comment is not from self" (fun _ ->
      Oth.Assert.not_true
        ~fail_msg:"a command is not from self"
        (Terrat_comment.is_from_self "terrateam plan");
      Oth.Assert.not_true
        ~fail_msg:"an empty body is not from self"
        (Terrat_comment.is_from_self "");
      ())

(* The marker closes the body, so the command parser still reads the first word
   of what was published. *)
let marker_keeps_the_body_first =
  Oth.test ~name:"marker keeps the body first" (fun _ ->
      let body = Terrat_comment.add_self_marker "terrateam plan" in
      Oth.Assert.Eq.string
        ~expected:"terrateam plan"
        ~actual:(CCString.take (CCString.length "terrateam plan") body);
      Oth.Assert.true_ (Terrat_comment.is_from_self body);
      ())

(* A quote-reply copies the raw markdown of the quoted comment, marker
   included, and the person's command follows it.  Such a body carries the
   marker but is NOT from self: the command must still run. *)
let quoted_marked_comment_is_not_from_self =
  Oth.test ~name:"quoted marked comment is not from self" (fun _ ->
      let quoted =
        Terrat_comment.add_self_marker "## Plan Output"
        |> CCString.split_on_char '\n'
        |> CCList.map (fun line -> "> " ^ line)
        |> CCString.concat "\n"
      in
      let body = quoted ^ "\n\nterrateam apply" in
      Oth.Assert.not_true
        ~fail_msg:"a quote-reply is not from self"
        (Terrat_comment.is_from_self body);
      ())

(* Trailing white space around the marker must not hide it. *)
let trailing_whitespace_keeps_the_marker =
  Oth.test ~name:"trailing whitespace keeps the marker" (fun _ ->
      let body = Terrat_comment.add_self_marker "## Plan Output" ^ "\n" in
      Oth.Assert.true_ (Terrat_comment.is_from_self body);
      ())

(* The [stategraph] trigger word (#1442 Phase 3): additive next to
   [terrateam], so existing repos keep working while migrated ones use the new
   brand. Commands must parse identically under both. *)

let parses_as_plan s =
  match Terrat_comment.parse s with
  | Ok (Terrat_comment.Plan _) -> true
  | _ -> false

(* The parameter and the run record the tests below read. *)
let pp_parameter ppf (name, value) = Format.fprintf ppf "@[%s=%s@]" name value
let eq_parameters (a, b) (c, d) = CCString.equal a c && CCString.equal b d

(* Reads the parameters and the tag query of the run comment that [verb] builds. *)
let run_of_comment verb comment =
  match (verb, comment) with
  | "plan", Terrat_comment.Plan { Terrat_comment.parameters; Terrat_comment.tag_query } ->
      (parameters, tag_query)
  | "apply", Terrat_comment.Apply { Terrat_comment.parameters; Terrat_comment.tag_query } ->
      (parameters, tag_query)
  | ( "apply-force",
      Terrat_comment.Apply_force { Terrat_comment.parameters; Terrat_comment.tag_query } ) ->
      (parameters, tag_query)
  | ( "apply-autoapprove",
      Terrat_comment.Apply_autoapprove { Terrat_comment.parameters; Terrat_comment.tag_query } ) ->
      (parameters, tag_query)
  | _ -> failwith ("expected a " ^ verb ^ " comment")

(* Parameters ride between the trigger word and the verb, on every run verb. *)
let parameters_on_every_run_verb =
  Oth.test ~name:"parameters parse on every run verb" (fun _ ->
      CCList.iter
        (fun verb ->
          let comment =
            Oth.Assert.ok (Terrat_comment.parse ("terrateam mode=DEBUG " ^ verb ^ " dir:staging"))
          in
          let parameters, tag_query = run_of_comment verb comment in
          Oth.Assert.Eq.list
            ~eq:eq_parameters
            ~pp:pp_parameter
            ~expected:[ ("mode", "DEBUG") ]
            ~actual:parameters;
          Oth.Assert.Eq.string
            ~expected:"dir:staging"
            ~actual:(Terrat_tag_query.to_string tag_query))
        [ "plan"; "apply"; "apply-force"; "apply-autoapprove" ])

(* A run verb with no parameter carries none. *)
let no_parameter_gives_no_parameters =
  Oth.test ~name:"no parameter gives no parameters" (fun _ ->
      let parameters, tag_query =
        run_of_comment "plan" (Oth.Assert.ok (Terrat_comment.parse "terrateam plan"))
      in
      Oth.Assert.List.empty parameters;
      Oth.Assert.Eq.string ~expected:"" ~actual:(Terrat_tag_query.to_string tag_query))

(* [to_string] puts the parameters back before the verb, in written order, so the rendered
   command reads back as the same command under both trigger words. *)
let to_string_repeats_the_written_order =
  Oth.test ~name:"to_string repeats the written order" (fun _ ->
      CCList.iter
        (fun trigger ->
          let comment =
            Oth.Assert.ok
              (Terrat_comment.parse (trigger ^ " mode=DEBUG region=us-east-1 plan dir:staging"))
          in
          Oth.Assert.Eq.string
            ~expected:"terrateam mode=DEBUG region=us-east-1 plan dir:staging"
            ~actual:(Terrat_comment.to_string comment))
        [ "terrateam"; "stategraph" ])

(* A first word that is no built-in verb reads as an alias name, with the arguments as its tag
   query. *)
let unknown_verb_parses_as_alias =
  Oth.test ~name:"unknown verbs parse as an alias" (fun _ ->
      CCList.iter
        (fun (command, expected_name, expected_query) ->
          match Terrat_comment.parse command with
          | Ok (Terrat_comment.Alias { name; tag_query }) ->
              Oth.Assert.Eq.string ~expected:expected_name ~actual:name;
              Oth.Assert.Eq.string
                ~expected:expected_query
                ~actual:(Terrat_tag_query.to_string tag_query)
          | _ -> failwith (command ^ " did not parse as an alias"))
        [
          ("terrateam debug", "debug", "");
          ("terrateam debug dev", "debug", "dev");
          ("stategraph plna", "plna", "");
        ])

(* An alias takes no parameters of its own, so a [=] token after its name is an error, and the
   message names the token. *)
let alias_takes_no_parameters =
  Oth.test ~name:"an alias takes no parameters" (fun _ ->
      match Terrat_comment.parse "terrateam debug mode=DEBUG" with
      | Error (`Tag_query_error (text, message)) ->
          Oth.Assert.Eq.string ~expected:"mode=DEBUG" ~actual:text;
          Oth.Assert.Eq.string
            ~expected:
              "An alias takes no parameters of its own. Set the parameters of an alias in its \
               `params` configuration."
            ~actual:message
      | _ -> failwith "expected a tag query error")

(* Parameters attach only on the run verbs, so a parameter token before any other verb stays the
   unknown action. *)
let parameters_on_other_verbs_stay_unknown =
  Oth.test ~name:"parameters on other verbs stay unknown" (fun _ ->
      CCList.iter
        (fun command ->
          match Terrat_comment.parse command with
          | Error (`Unknown_action "mode=DEBUG") -> ()
          | _ -> failwith (command ^ " did not stay the unknown action"))
        [ "terrateam mode=DEBUG help"; "terrateam mode=DEBUG" ])

let test =
  Oth.parallel
    [
      marked_comment_is_from_self;
      plain_comment_is_not_from_self;
      marker_keeps_the_body_first;
      quoted_marked_comment_is_not_from_self;
      trailing_whitespace_keeps_the_marker;
      Oth.test ~name:"stategraph trigger word parses" (fun _ ->
          if not (parses_as_plan "stategraph plan") then failwith "stategraph plan did not parse";
          ());
      Oth.test ~name:"terrateam trigger word still parses" (fun _ ->
          if not (parses_as_plan "terrateam plan") then failwith "terrateam plan did not parse";
          ());
      Oth.test ~name:"commands parse identically under both trigger words" (fun _ ->
          CCList.iter
            (fun cmd ->
              match
                ( Terrat_comment.parse ("terrateam " ^ cmd),
                  Terrat_comment.parse ("stategraph " ^ cmd) )
              with
              | Ok a, Ok b when Terrat_comment.to_string a = Terrat_comment.to_string b -> ()
              | Ok _, Ok _ -> failwith (cmd ^ ": parses differ between trigger words")
              | Error _, _ -> failwith (cmd ^ ": terrateam form did not parse")
              | _, Error _ -> failwith (cmd ^ ": stategraph form did not parse"))
            [ "plan"; "apply"; "apply-force"; "apply-autoapprove"; "unlock"; "help"; "repo-config" ];
          ());
      Oth.test ~name:"non-trigger word still rejected" (fun _ ->
          (match Terrat_comment.parse "atlantis plan" with
          | Error `Not_terrateam -> ()
          | _ -> failwith "non-trigger word was accepted");
          ());
      parameters_on_every_run_verb;
      no_parameter_gives_no_parameters;
      to_string_repeats_the_written_order;
      unknown_verb_parses_as_alias;
      alias_takes_no_parameters;
      parameters_on_other_verbs_stay_unknown;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
