(** A total function from strings to ['a], written as longest-prefix rules.

    Each node sits at a prefix [p] and holds two answers: [here], for the string [p] itself, and
    [below], for every longer string that no child covers. A string gets the answer of the deepest
    node whose prefix starts it. The rules [Prefix "a." -> true] and [Literal "a.b" -> false], with
    [false] by default, give:

    {v
      ""          here false  below false
      └── "a."    here true   below true
          └── "b" here false  below true      (the node of prefix "a.b")

      find "a"   = false     find "a.b"   = false
      find "a."  = true      find "a.b.c" = true
    v}

    The representation is canonical: two tries that give the same answer for every string are
    structurally equal, when their answers are compared with an exact equality. A pattern holds no
    character below 32 while a string holds any byte, so no set of children covers every
    continuation of a prefix and [below] always decides some strings. A node therefore exists
    exactly where it changes an answer of its parent, or where several children branch. *)

(** The strings a rule applies to.

    {v
      "a.b"   Literal "a.b"   the string a.b, and no other string
      "a.*"   Prefix "a."     every string that starts with a., including a.
      "*"     Prefix ""       every string
      ""      Literal ""      the empty string
    v} *)
module Pattern : sig
  type t = private
    | Literal of string
    | Prefix of string
  [@@deriving show, eq]

  (** [of_string s] reads a pattern. The text holds no character below 32, and a ['*'] only as its
      last character. Whether a rule allows or refuses is not part of its pattern.

      {v
        of_string "a.*"    = Ok (Prefix "a.")
        of_string "a"      = Ok (Literal "a")
        of_string "caf\233" = Ok (Literal "caf\233")
        of_string "a*b"    = Error (`Invalid_pattern_err "a*b")
        of_string "a**"    = Error (`Invalid_pattern_err "a**")
        of_string "a\t"    = Error (`Invalid_pattern_err "a\t")
      v} *)
  val of_string : string -> (t, [> `Invalid_pattern_err of string ]) result

  (** [to_string p] is the text that [of_string] reads back as [p]. *)
  val to_string : t -> string

  (** The maximum length of the text of a pattern. *)
  val max_length : int
end

type 'a t [@@deriving show, eq]

(** [const v] answers [v] for every string. *)
val const : 'a -> 'a t

(** [find t s] is the answer that [t] gives for [s]: the answer of the most specific pattern that
    matches [s].

    {v
      t = of_rules ~default:false [ (Prefix "a.", true); (Literal "a.b", false) ]

        find t "a.b"     = false     Literal "a.b"
        find t "a.bc"    = true      Prefix "a."
        find t "a.\t"    = true      Prefix "a."   a tab can be in a query, even if not in a pattern (because of Pattern.in_range)
        find t "b"       = false     no pattern matches: the default
    v} *)
val find : 'a t -> string -> 'a

(** [override ~equal ~answer ~on ~base] answers [answer] for the strings that [on] matches, and what
    [base] answers for the other strings. *)
val override : equal:('a -> 'a -> bool) -> answer:'a -> on:Pattern.t -> base:'a t -> 'a t

(** [of_rules ~equal ~default rules] answers [default], then applies [rules] from the most general
    pattern to the most specific one: the most specific pattern that matches a string decides its
    answer. A literal is more specific than a prefix of the same text. When the same pattern occurs
    more than once, the last occurrence wins.

    {v
      "a.*"   is  (Prefix "a.", true)
      "!a.b"  is  (Literal "a.b", false)

      of_rules ~default:false [ (Prefix "a.", true); (Literal "a.b", false) ]

        find "a.x" = true     find "a.b" = false     find "b" = false
    v} *)
val of_rules : equal:('a -> 'a -> bool) -> default:'a -> (Pattern.t * 'a) list -> 'a t

(** [to_rules ~equal t] gives one or two rules for each node of [t], in prefix order, starting with
    [Prefix ""]. [of_rules ~equal ~default (to_rules ~equal t)] is [t], whatever [default] is.

    {v
      to_rules (of_rules ~default:false [ (Prefix "a.", true); (Literal "a.b", false); (Literal "a.b.c", true) ])
        = [ (Prefix "", false); (Prefix "a.", true); (Literal "a.b", false) ]
    v} *)
val to_rules : equal:('a -> 'a -> bool) -> 'a t -> (Pattern.t * 'a) list

(** [map ~equal f t] answers [f (find t s)] for every string [s]. *)
val map : equal:('b -> 'b -> bool) -> ('a -> 'b) -> 'a t -> 'b t

(** [merge ~equal f a b] answers [f (find a s) (find b s)] for every string [s]. *)
val merge : equal:('c -> 'c -> bool) -> ('a -> 'b -> 'c) -> 'a t -> 'b t -> 'c t

(** [for_all p t] is true when [p] holds for every answer [t] gives. *)
val for_all : ('a -> bool) -> 'a t -> bool
