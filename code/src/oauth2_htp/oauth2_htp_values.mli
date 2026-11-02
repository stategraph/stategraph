(** Multi-map of query and form parameters.

    [Uri.query] already has this shape, so this is only the operations on top of it. The one that
    cannot be borrowed is {!encode}: [Uri]'s encoder follows RFC 3986, whereas an IdP is handed HTML
    form encoding — a space becomes ['+'] — which is what {!Form_urlencode} produces. *)

type t = (string * string list) list

(** The first value bound to [k], [""] when absent. *)
val get : string -> t -> string

(** Append a value to [k]'s bindings, or create it. *)
val add : string -> string -> t -> t

(** Encode as a query string with the keys sorted. *)
val encode : t -> string

(** [of_query_string "a=1&b=2"] parses a query or an [application/x-www-form-urlencoded] body. *)
val of_query_string : string -> t
