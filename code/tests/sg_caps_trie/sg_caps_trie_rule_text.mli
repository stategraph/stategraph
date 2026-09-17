(** The text form of capability rules.

    A pattern carries no refusal of its own, so the text form puts it in front: ["a.*"] allows the
    strings under ["a."], ["!a.b"] refuses ["a.b"], and ["!a.b"] read as a pattern alone is the
    literal string ["!a.b"]. *)

(** [pattern text] reads a pattern, and fails the test when [text] is not one. *)
val pattern : string -> Sg_caps_trie.Pattern.t

(** [rule "a.*"] is [(Prefix "a.", true)] and [rule "!a.b"] is [(Literal "a.b", false)]. *)
val rule : string -> Sg_caps_trie.Pattern.t * bool

(** [render_rule] is the text [rule] reads back. *)
val render_rule : Sg_caps_trie.Pattern.t * bool -> string

(** [scope texts] is the scope the rules [texts] describe.

    {v   scope [ "a.*"; "!a.b" ]     contains "a.x", and not "a.b" v} *)
val scope : string list -> Sg_caps_trie_scope.t
