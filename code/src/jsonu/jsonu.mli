type of_yaml_string_err = [ `Yaml_decode_err of string ] [@@deriving show]

type merge_err = [ `Type_mismatch_err of string option * Yojson.Safe.t * Yojson.Safe.t ]
[@@deriving show]

val to_yaml_string : Yojson.Safe.t -> string
val of_yaml_string : string -> (Yojson.Safe.t, [> of_yaml_string_err ]) result

(** [merge] takes a starting json, [base], and merges another json, [override] on top of it. The
    following rules are applied for merging:

    - If a key is in [base] and [override] and has a scalar type, the value from [override] is
      taken.

    - If a key is in [base] and [override] and it is a list, the two lists are concatenated as
      directed by [~list]: [`Prepend] (the default) puts the items from [override] before the items
      in [base]; [`Append] puts them after. Concatenation never deduplicates, so the same entry
      arriving from two merged layers appears twice in the result.

    - If a key is in [base] and [override] and it is a dictionary, [merge] is recursively applied.

    - If a key is in [base] and [override] and either has a value of [null], then the value from
      [override] is taken. If [~null_is_identity:true] is passed, a [null] value in [override] does
      not replace the value from [base].

    - If a key is in [base] and [override] and no other rule applies, then a
      [`Type_mismatch_err key] is returned.

    - All keys from [override] are added to the result.

    Note that no deep merging of lists is performed. *)
val merge :
  ?null_is_identity:bool ->
  ?list:[ `Prepend | `Append ] ->
  base:Yojson.Safe.t ->
  Yojson.Safe.t ->
  (Yojson.Safe.t, [> merge_err ]) result
