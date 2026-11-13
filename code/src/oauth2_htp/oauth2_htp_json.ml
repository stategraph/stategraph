let member name = function
  | `Assoc kvs -> Sln_list.String.assoc_opt name kvs
  | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null | `String _ -> None

let string = function
  | `String s -> Some s
  | `Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null -> None

let bool = function
  | `Bool b -> Some b
  | `Assoc _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null | `String _ -> None

let list = function
  | `List vs -> Some vs
  | `Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `Null | `String _ -> None

let number = function
  | `Int i -> Some (CCFloat.of_int i)
  | `Float f -> Some f
  | `Assoc _ | `Bool _ | `Intlit _ | `List _ | `Null | `String _ -> None
