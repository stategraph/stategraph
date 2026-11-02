module Key : sig
  type t

  val get : string -> t -> string option
end

type t

val get_kid : string -> t -> Key.t option

(** Every key of the set, in order, including those without a [kid]. *)
val keys : t -> Key.t list

val of_string : string -> t option
