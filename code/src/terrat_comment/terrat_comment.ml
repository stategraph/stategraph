let trigger_words = [ "terrateam"; "stategraph"; "terraform"; "tofu" ]

type parameters = (string * string) list

type run = {
  parameters : parameters;
  tag_query : Terrat_tag_query.t;
}

type t =
  | Apply of run
  | Apply_autoapprove of run
  | Apply_force of run
  | Alias of {
      name : string;
      tag_query : Terrat_tag_query.t;
    }
  | Feedback of string
  | Gate_approval of { tokens : string list }
  | Help
  | Index
  | Plan of run
  | Repo_config
  | Unlock of string list

type err =
  [ `Not_terrateam
  | `Unknown_action of string
  | Terrat_tag_query_ast.err
  ]
[@@deriving show]

(* [split_trigger s] cuts the trigger word off [s] and answers the text after it, or [None] when
   [s] does not start with a trigger word. The trigger word matches case insensitively and the
   text after it is trimmed. *)
let split_trigger s =
  match CCString.Split.left ~by:" " s with
  | Some (trigger_word, rest)
    when CCList.mem ~eq:CCString.equal (CCString.lowercase_ascii trigger_word) trigger_words ->
      Some (CCString.trim rest)
  | _ -> None

(* [tokenize s] splits on single spaces and drops the empty tokens, so the scans below never see
   a run of spaces. *)
let tokenize s =
  s |> CCString.split_on_char ' ' |> CCList.filter (fun token -> not (CCString.is_empty token))

(* A token that holds [=] is a parameter written as [name=value]. *)
let holds_equals token = CCString.contains token '='

(* [parameter_of_token token] cuts [name=value] on the first [=]. [split_parameters] only hands
   over tokens that hold [=], so the fallback never answers. *)
let parameter_of_token token =
  match CCString.Split.left ~by:"=" token with
  | Some (name, value) -> (name, value)
  | None -> (token, "")

(* [split_parameters tokens] consumes the leading tokens that hold [=] and leaves the rest. The
   consumed tokens keep the order they were written in. *)
let split_parameters tokens =
  let rec go parameters = function
    | token :: rest when holds_equals token -> go (token :: parameters) rest
    | rest -> (CCList.rev parameters, rest)
  in
  go [] tokens

(* [run make parameters arguments] reads the tag query from [arguments] and builds the run
   command [make] builds from it. *)
let run make parameters arguments =
  let open CCResult.Infix in
  Terrat_tag_query.of_string (CCString.concat " " arguments)
  >>= fun tag_query -> Ok (make { parameters; tag_query })

(* [parse_dispatch command rest] reads the text [rest] that follows a trigger word. [command] is
   the whole trimmed command, which the [gate] arm answers back when it names no subcommand.
   Parameters attach only on the four run verbs; every other first word keeps them in its own
   text, and a first word that is no built-in verb reads as an alias name. *)
let parse_dispatch command rest =
  let open CCResult.Infix in
  let tokens = tokenize rest in
  let parameters, after_parameters = split_parameters tokens in
  let parameters = CCList.map parameter_of_token parameters in
  let alias name arguments =
    if CCList.exists holds_equals arguments then
      Error
        (`Tag_query_error
           ( CCString.concat " " arguments,
             "An alias takes no parameters of its own. Set the parameters of an alias in its \
              `params` configuration." ))
    else
      Terrat_tag_query.of_string (CCString.concat " " arguments)
      >>= fun tag_query -> Ok (Alias { name; tag_query })
  in
  match after_parameters with
  | "plan" :: arguments -> run (fun r -> Plan r) parameters arguments
  | "apply" :: arguments -> run (fun r -> Apply r) parameters arguments
  | "apply-autoapprove" :: arguments -> run (fun r -> Apply_autoapprove r) parameters arguments
  | "apply-force" :: arguments -> run (fun r -> Apply_force r) parameters arguments
  | _ -> (
      match tokens with
      | [] -> Error (`Unknown_action "")
      | token :: _ when holds_equals token -> Error (`Unknown_action token)
      | "unlock" :: ids -> Ok (Unlock ids)
      | "help" :: _ -> Ok Help
      | "feedback" :: _ -> (
          (* The feedback text keeps the raw remainder, spaces included. *)
          match CCString.Split.left ~by:" " rest with
          | Some (_, feedback) -> Ok (Feedback feedback)
          | None -> Ok (Feedback ""))
      | "repo-config" :: _ -> Ok Repo_config
      | "index" :: _ -> Ok Index
      | "gate" :: "approve" :: gate_tokens -> Ok (Gate_approval { tokens = gate_tokens })
      | "gate" :: action :: _ -> Error (`Unknown_action action)
      | "gate" :: [] -> Error (`Unknown_action command)
      | alias_name :: alias_arguments -> alias alias_name alias_arguments)

let parse s =
  let s =
    (* In GitLab, the automatic copy of a triple backtick text adds the single
       backticks, so we trim those off and any white space.  This makes it so
       people can drop comments like `terrateam plan` and it will still work.
       We trim twice, once for outside the single backticks and once for
       inside. *)
    s
    |> CCString.trim
    |> CCString.drop_while (( = ) '`')
    |> CCString.rdrop_while (( = ) '`')
    |> CCString.trim
  in
  match split_trigger s with
  | None -> Error `Not_terrateam
  | Some rest -> parse_dispatch s rest

(* [parameters_text parameters] writes each parameter back as [name=value], in written order. *)
let parameters_text parameters =
  parameters |> CCList.map (fun (name, value) -> name ^ "=" ^ value) |> CCString.concat " "

(* [run_text verb run] writes a run command. The parameters go back before the verb, in written
   order, so reading the text back gives the same command. *)
let run_text verb run =
  match run.parameters with
  | [] -> "terrateam " ^ verb ^ " " ^ Terrat_tag_query.to_string run.tag_query
  | parameters ->
      "terrateam "
      ^ parameters_text parameters
      ^ " "
      ^ verb
      ^ " "
      ^ Terrat_tag_query.to_string run.tag_query

let to_string = function
  | Apply run -> run_text "apply" run
  | Apply_autoapprove run -> run_text "apply-autoapprove" run
  | Apply_force run -> run_text "apply-force" run
  | Alias { name; tag_query } -> "terrateam " ^ name ^ " " ^ Terrat_tag_query.to_string tag_query
  | Feedback feedback -> "terrateam feedback " ^ feedback
  | Gate_approval { tokens } -> "terrateam gate approval " ^ CCString.concat " " tokens
  | Help -> "terrateam help"
  | Index -> "terrateam index"
  | Plan run -> run_text "plan" run
  | Repo_config -> "terrateam repo-config"
  | Unlock ids -> "terrateam unlock " ^ CCString.concat " " ids

let self_marker = "<!-- stategraph -->"
let add_self_marker body = body ^ "\n\n" ^ self_marker

(* The marker must CLOSE the body, not merely appear in it.  A quote-reply
   carries the raw markdown of the quoted comment, marker included, and the
   person's own command follows it. *)
let is_from_self body = CCString.suffix ~suf:self_marker (CCString.trim body)
