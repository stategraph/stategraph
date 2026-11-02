(** Accessors over {!Yojson.Safe} that never fail to navigate: a missing key yields [`Null]. *)

val member : string -> Yojson.Safe.t -> Yojson.Safe.t
val is_null : Yojson.Safe.t -> bool

(** The string, [""] for anything that is not a JSON string. *)
val must_string : Yojson.Safe.t -> string

(** A JSON string as a one element list, the strings of a JSON array, [[]] for anything else. *)
val string_list : Yojson.Safe.t -> string list

val must_bool : Yojson.Safe.t -> bool

(** A JSON number, [0.] for anything else. *)
val must_number : Yojson.Safe.t -> float
