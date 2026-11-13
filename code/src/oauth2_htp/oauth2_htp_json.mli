(** Accessors that read a value of one shape, and are [None] for any other:

    {[
    member "a" (`Assoc [ ("a", `Int 1) ]) = Some (`Int 1)
    member "a" (`Assoc []) = None
    member "a" (`List []) = None
    string (`String "x") = Some "x"
    string (`Int 1) = None
    ]} *)

(** The value of the key, when the JSON is an object that has the key. *)
val member : string -> Yojson.Safe.t -> Yojson.Safe.t option

val string : Yojson.Safe.t -> string option
val bool : Yojson.Safe.t -> bool option
val list : Yojson.Safe.t -> Yojson.Safe.t list option

(** An integer or a float, as a float. *)
val number : Yojson.Safe.t -> float option
