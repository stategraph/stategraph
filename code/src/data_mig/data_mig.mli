module Error : sig
  (** Where the migrations recorded in the database stop matching the migration list they are
      checked against. *)
  module Consistency : sig
    type t = {
      idx : int;  (** How many migrations the database and the migration list agree on. *)
      last_common : string option;  (** Last migration both sides agree on, if any. *)
      applied : string option;  (** What the database has at [idx]. *)
      expected : string option;  (** What the migration list has at [idx]. *)
    }
    [@@deriving show]

    (** Render the divergence as a human-readable message. *)
    val to_string : t -> string
  end

  type 'a t =
    [ `Migration_err of 'a
    | `Consistency_err of Consistency.t
    ]
end

module type S = sig
  type tx
  type 'a t
  type err

  val tx :
    'a t -> (tx t -> ('r, err Error.t) result Abb.Future.t) -> ('r, err Error.t) result Abb.Future.t

  val start_migration : tx t -> string -> unit Abb.Future.t
  val complete_migration : 'a t -> string -> unit Abb.Future.t
  val list_migrations : 'a t -> string list -> unit Abb.Future.t
  val get_migrations : tx t -> (string list, err) result Abb.Future.t
  val add_migration : tx t -> string -> (unit, err) result Abb.Future.t
end

module Make (M : S) : sig
  type err = M.err Error.t

  module Migration : sig
    (** [`Async] means to run the returned migration outside of the transaction block. *)
    type 'a t =
      M.tx M.t ->
      ([ `Sync | `Async of 'a M.t -> (unit, M.err) result Abb.Future.t ], M.err) result Abb.Future.t
  end

  val run : 'a M.t -> (string * 'a Migration.t) list -> (unit, [> err ]) result Abb.Future.t
end
