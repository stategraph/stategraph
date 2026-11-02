let member name = function
  | `Assoc kvs -> CCOption.get_or ~default:`Null (Sln_list.String.assoc_opt name kvs)
  | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null | `String _ -> `Null

let is_null = function
  | `Null -> true
  | `Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `String _ -> false

let must_string = function
  | `String s -> s
  | `Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null -> ""

let string_list = function
  | `String s -> [ s ]
  | `List vs ->
      CCList.filter_map
        (function
          | `String s -> Some s
          | `Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null -> None)
        vs
  | `Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `Null -> []

let must_bool = function
  | `Bool b -> b
  | `Assoc _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null | `String _ -> false

let must_number = function
  | `Int i -> CCFloat.of_int i
  | `Float f -> f
  | `Assoc _ | `Bool _ | `Intlit _ | `List _ | `Null | `String _ -> 0.
