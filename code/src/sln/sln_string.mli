(** [is_whitespace c] is [true] iff [c] is one of [' '], ['\t'], ['\n'], ['\r']. This is the
    ASCII-whitespace predicate used by {!words} and {!take_words}. *)
val is_whitespace : char -> bool

(** [not (CCString.is_empty s)]: [is_non_empty "a" = true] and [is_non_empty "" = false]. *)
val is_non_empty : string -> bool

(** Split [s] on runs of ASCII whitespace ([' '], ['\t'], ['\n'], ['\r']) and return the resulting
    non-empty words in order. Leading, trailing, and consecutive whitespace produce no empty
    elements.

    Equivalent to Haskell's
    {{:https://hackage.haskell.org/package/base/docs/Prelude.html#v:words} [Prelude.words]}.

    Examples:
    - [words "  WITH foo bar  "] = [["WITH"; "foo"; "bar"]]
    - [words "WITH\nclear_old AS"] = [["WITH"; "clear_old"; "AS"]]
    - [words ""] = [[]]
    - [words "   "] = [[]] *)
val words : string -> string list

(** [take_words ~max_nb_words s] is the same as {!words} except scanning stops as soon as
    [max_nb_words] words have been collected. This bounds the work to roughly
    [O(input prefix consumed)] regardless of the total length of [s], which is useful when only the
    leading few words are needed (e.g. classifying a SQL statement by operation and target table).

    [max_nb_words <= 0] returns the empty list. If the input has fewer non-whitespace tokens than
    [max_nb_words], the result has length less than [max_nb_words].

    Examples:
    - [take_words ~max_nb_words:2 "WITH foo bar baz"] = [["WITH"; "foo"]]
    - [take_words ~max_nb_words:5 "a b"] = [["a"; "b"]]
    - [take_words ~max_nb_words:0 "anything"] = [[]] *)
val take_words : max_nb_words:int -> string -> string list
