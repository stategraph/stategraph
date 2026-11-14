(** The parameters of a run command, as the comment wrote them: name and value pairs in written
    order. *)
type parameters = (string * string) list

(** A run command. The parameters ride between the trigger word and the verb, so
    [mode=DEBUG plan dir:staging] carries one parameter and the tag query [dir:staging]. *)
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

(** [parse s] reads one command of the shape [TRIGGER [name=value ...] VERB [arguments]].

    The parameters ride between the trigger word and the verb, and only the four run verbs [Plan],
    [Apply], [Apply_force] and [Apply_autoapprove] accept them: on any other verb the parameter
    tokens stay part of the text, so [mode=DEBUG help] names no verb at all. A first word that is no
    built-in verb parses as an {!Alias}, and an alias takes no parameters of its own, so
    [debug mode=DEBUG] is a tag query error. *)
val parse : string -> (t, [> err ]) result

(** [to_string c] writes [c] back as one command. A run command re-emits its parameters before the
    verb, in written order, so [parse (to_string c)] reads a parameterized run command back as [c]
    again. *)
val to_string : t -> string

(** Closes [body] with a hidden marker. Neither GitHub nor GitLab render the marker, so it is how a
    comment published by this system is recognized when it comes back as an event. Every comment
    published on a pull request goes through here. *)
val add_self_marker : string -> string

(** [true] when [body] was published by this system, that is, when {!add_self_marker} closed it. A
    quoted copy of such a comment is not a match, because the quote does not close the body.
    Comments published before the marker existed are not matched either. *)
val is_from_self : string -> bool
