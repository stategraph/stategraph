(** A set of strings, such as the tenants, users or resource addresses a capability reaches.

    {v
      of_rules [ (Prefix "a.", true); (Literal "a.b", false) ]

        mem "a.x" = true     mem "a.b" = false     mem "b" = false
    v} *)

(** A scope is a trie that answers [true] for the strings it contains. A scope can be used where a
    [bool Sg_caps_trie.t] is expected, with [(scope :> bool Sg_caps_trie.t)]. A trie cannot be used
    where a scope is expected. *)
type t = private bool Sg_caps_trie.t

(** The scope that contains no string, [Sg_caps_trie.const false]. It is the start value to fold
    [union] over several scopes, and the scope of a grant that reaches nothing:

    {v
      union empty t = t
      inter empty t = empty
    v} *)
val empty : t

(** The scope that contains every string, [Sg_caps_trie.const true]. It is the start value to fold
    [inter] over several scopes, and the scope of an unrestricted grant, such as an admin grant over
    every tenant:

    {v
      inter full t = t
      union full t = full
    v} *)
val full : t

(** [of_rules rules] contains a string when the most specific pattern that matches it allows it, and
    no string that no pattern matches. When the same pattern is both allowed and refused, it is
    refused. *)
val of_rules : (Sg_caps_trie.Pattern.t * bool) list -> t

(** [to_rules t] gives the rules that [of_rules] turns back into [t], starting with [Prefix ""]. *)
val to_rules : t -> (Sg_caps_trie.Pattern.t * bool) list

(** [mem t s] is true when [t] contains [s]. [s] can contain any byte. *)
val mem : t -> string -> bool

(** [union a b] contains the strings that [a] contains or [b] contains. A string that one scope
    allows inside a prefix that the other scope refuses stays allowed, and only that string:

    {v
      union (of_rules [ (Prefix "a.", true); (Prefix "a.x.", false) ])
            (of_rules [ (Literal "a.x.foo", true) ])

        mem "a.x.foo" = true     mem "a.x.bar" = false     mem "a.y" = true
    v} *)
val union : t -> t -> t

(** [inter a b] contains the strings that both [a] and [b] contain. *)
val inter : t -> t -> t

(** [diff a b] contains the strings that [a] contains and [b] does not contain. *)
val diff : t -> t -> t

(** [compl t] contains the strings that [t] does not contain. *)
val compl : t -> t

(** [subset a b] is true when [b] contains every string that [a] contains.

    {v
      subset (of_rules [ (Literal "t1", true) ]) (of_rules [ (Prefix "t", true) ])  = true
      subset (of_rules [ (Prefix "t", true) ])  (of_rules [ (Literal "t1", true) ]) = false
    v} *)
val subset : t -> t -> bool

(** [is_empty t] is true when [t] contains no string. *)
val is_empty : t -> bool

(** [is_full t] is true when [t] contains every string. *)
val is_full : t -> bool

(** [literals t] is the strings of [t], or [`Infinite] when [t] contains infinitely many strings.

    {v
      literals (of_rules [ (Literal "t1", true); (Literal "t2", true) ])  = `Literals [ "t1"; "t2" ]
      literals (of_rules [ (Prefix "t", true) ])                         = `Infinite
    v} *)
val literals : t -> [ `Literals of string list | `Infinite ]

(** [equal a b] is true when [a] and [b] contain the same strings. *)
val equal : t -> t -> bool

(** [pp] prints the trie of a scope, for debugging and test failures. *)
val pp : Format.formatter -> t -> unit
