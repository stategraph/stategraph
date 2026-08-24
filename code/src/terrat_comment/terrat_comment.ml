let trigger_words = [ "terrateam"; "stategraph"; "terraform"; "tofu" ]

type t =
  | Apply of { tag_query : Terrat_tag_query.t }
  | Apply_autoapprove of { tag_query : Terrat_tag_query.t }
  | Apply_force of { tag_query : Terrat_tag_query.t }
  | Feedback of string
  | Gate_approval of { tokens : string list }
  | Help
  | Index
  | Plan of { tag_query : Terrat_tag_query.t }
  | Repo_config
  | Unlock of string list

type err =
  [ `Not_terrateam
  | `Unknown_action of string
  | Terrat_tag_query_ast.err
  ]
[@@deriving show]

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
  let split_s =
    match CCString.Split.left ~by:" " s with
    | Some (trigger_word, action_rest)
      when CCList.mem ~eq:CCString.equal (CCString.lowercase_ascii trigger_word) trigger_words -> (
        match CCString.Split.left ~by:" " (CCString.trim action_rest) with
        | Some (action, rest) -> Some (action, rest)
        | None -> Some (action_rest, ""))
    | _ -> None
  in
  let open CCResult.Infix in
  match split_s with
  | Some ("unlock", rest) ->
      Ok
        (Unlock
           (rest
           |> CCString.split_on_char ' '
           |> CCList.map CCString.trim
           |> CCList.filter CCFun.(CCString.is_empty %> not)))
  | Some ("plan", rest) ->
      Terrat_tag_query.of_string rest >>= fun tag_query -> Ok (Plan { tag_query })
  | Some ("apply", rest) ->
      Terrat_tag_query.of_string rest >>= fun tag_query -> Ok (Apply { tag_query })
  | Some ("apply-autoapprove", rest) ->
      Terrat_tag_query.of_string rest >>= fun tag_query -> Ok (Apply_autoapprove { tag_query })
  | Some ("apply-force", rest) ->
      Terrat_tag_query.of_string rest >>= fun tag_query -> Ok (Apply_force { tag_query })
  | Some ("help", _) -> Ok Help
  | Some ("feedback", rest) -> Ok (Feedback rest)
  | Some ("repo-config", _) -> Ok Repo_config
  | Some ("index", _) -> Ok Index
  | Some ("gate", rest) -> (
      match CCString.Split.left ~by:" " (CCString.trim rest) with
      | Some ("approve", tokens) ->
          Ok
            (Gate_approval
               { tokens = CCList.map CCString.trim @@ CCString.split_on_char ' ' tokens })
      | Some (action, _) -> Error (`Unknown_action action)
      | None -> Error (`Unknown_action s))
  | Some (action, _rest) -> Error (`Unknown_action action)
  | None -> Error `Not_terrateam

let to_string = function
  | Apply { tag_query } -> "terrateam apply " ^ Terrat_tag_query.to_string tag_query
  | Apply_autoapprove { tag_query } ->
      "terrateam apply-autoapprove " ^ Terrat_tag_query.to_string tag_query
  | Apply_force { tag_query } -> "terrateam apply-force " ^ Terrat_tag_query.to_string tag_query
  | Feedback feedback -> "terrateam feedback " ^ feedback
  | Gate_approval { tokens } -> "terrateam gate approval " ^ CCString.concat " " tokens
  | Help -> "terrateam help"
  | Index -> "terrateam index"
  | Plan { tag_query } -> "terrateam plan " ^ Terrat_tag_query.to_string tag_query
  | Repo_config -> "terrateam repo-config"
  | Unlock ids -> "terrateam unlock " ^ CCString.concat " " ids

let self_marker = "<!-- stategraph -->"
let add_self_marker body = body ^ "\n\n" ^ self_marker

(* The marker must CLOSE the body, not merely appear in it.  A quote-reply
   carries the raw markdown of the quoted comment, marker included, and the
   person's own command follows it. *)
let is_from_self body = CCString.suffix ~suf:self_marker (CCString.trim body)
