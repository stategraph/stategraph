module String : sig
  (** [CCList.mem ~eq:CCString.equal] *)
  val mem : string -> string list -> bool

  (** [CCList.sort CCString.compare] *)
  val sort : string list -> string list

  (** [CCList.sort_uniq ~cmp:CCString.compare] *)
  val sort_uniq : string list -> string list

  (** [CCList.equal CCString.equal] *)
  val equal : string list -> string list -> bool

  (** [CCList.uniq ~eq:CCString.equal] *)
  val uniq : string list -> string list

  (** [CCList.remove ~eq:CCString.equal ~key]: drops {i every} occurrence of the value, not just the
      first. *)
  val remove : string -> string list -> string list

  (** [CCList.assoc_opt ~eq:CCString.equal] *)
  val assoc_opt : string -> (string * 'a) list -> 'a option

  (** [CCList.mem_assoc ~eq:CCString.equal] *)
  val mem_assoc : string -> (string * _) list -> bool

  (** [CCList.sort (fun (a, _) (b, _) -> CCString.compare a b)] *)
  val sort_assoc : (string * 'a) list -> (string * 'a) list
end

module Uuidm : sig
  (** [CCList.mem ~eq:Uuidm.equal] *)
  val mem : Uuidm.t -> Uuidm.t list -> bool
end

(** A list with at least one element. Its constructor is [( :: )], so a value is written as a list
    literal with the module in scope, and [[]] does not type-check:

    {[
    let orgs = Sln_list.Non_empty.[ "acme"; "acme-labs" ]
    ]} *)
module Non_empty : sig
  type 'a t = ( :: ) of 'a * 'a list [@@deriving show]

  (** [None] for [[]]. *)
  val of_list : 'a list -> 'a t option

  val to_list : 'a t -> 'a list

  (** The first element: [hd Sln_list.Non_empty.[ "a"; "b" ] = "a"]. *)
  val hd : 'a t -> 'a

  (** The elements after the first, possibly none: [tl Sln_list.Non_empty.[ "a"; "b" ] = [ "b" ]]
      and [tl Sln_list.Non_empty.[ "a" ] = []]. *)
  val tl : 'a t -> 'a list

  (** The elements after the first, [None] when there are none:
      [tail_opt Sln_list.Non_empty.[ "a"; "b" ] = Some Sln_list.Non_empty.[ "b" ]] and
      [tail_opt Sln_list.Non_empty.[ "a" ] = None]. *)
  val tail_opt : 'a t -> 'a t option
end
