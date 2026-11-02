(** The parts of an HTTP request the sign-in flow reads. *)

type t

(** Read a request out of a {!Brtl_ctx}. The body must already have been read. *)
val of_ctx : (string, 'b) Brtl_ctx.t -> t

(** The first value of a parameter in the query or an [application/x-www-form-urlencoded] body, [""]
    when absent. *)
val form_value : string -> t -> string

val cookies : t -> (string * string) list
