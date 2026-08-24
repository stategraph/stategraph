let marked_comment_is_from_self =
  Oth.test ~name:"marked comment is from self" (fun _ ->
      let body = Terrat_comment.add_self_marker "## Plan Output" in
      Oth.Assert.true_ "marked body is from self" (Terrat_comment.is_from_self body);
      ())

let plain_comment_is_not_from_self =
  Oth.test ~name:"plain comment is not from self" (fun _ ->
      Oth.Assert.not_true
        "a command is not from self"
        (Terrat_comment.is_from_self "terrateam plan");
      Oth.Assert.not_true "an empty body is not from self" (Terrat_comment.is_from_self "");
      ())

(* The marker closes the body, so the command parser still reads the first word
   of what was published. *)
let marker_keeps_the_body_first =
  Oth.test ~name:"marker keeps the body first" (fun _ ->
      let body = Terrat_comment.add_self_marker "terrateam plan" in
      Oth.Assert.Eq.string
        ~expected:"terrateam plan"
        ~actual:(CCString.take (CCString.length "terrateam plan") body);
      Oth.Assert.true_ "the marked body is from self" (Terrat_comment.is_from_self body);
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
      Oth.Assert.not_true "a quote-reply is not from self" (Terrat_comment.is_from_self body);
      ())

(* Trailing white space around the marker must not hide it. *)
let trailing_whitespace_keeps_the_marker =
  Oth.test ~name:"trailing whitespace keeps the marker" (fun _ ->
      let body = Terrat_comment.add_self_marker "## Plan Output" ^ "\n" in
      Oth.Assert.true_ "a trailing newline is ignored" (Terrat_comment.is_from_self body);
      ())

(* The [stategraph] trigger word (#1442 Phase 3): additive next to
   [terrateam], so existing repos keep working while migrated ones use the new
   brand. Commands must parse identically under both. *)

let parses_as_plan s =
  match Terrat_comment.parse s with
  | Ok (Terrat_comment.Plan _) -> true
  | _ -> false

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
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
