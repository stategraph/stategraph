(** The orchestration's reader of Stategraph as a service in the manager.

    The service is a functor over the reader, because the reader that queries the Stategraph
    database is private to the enterprise server, while this service and the servers it is
    registered in are public. The enterprise server gives it that reader; the open source server
    gives it {!Standalone}, so its orchestration asks nothing and leaves the overlaps to
    Stategraph's commit, as the orchestration on its own does. *)

(** What the service builds the reader from: the pool of the process. *)
module type READER = sig
  val make : Pgsql_pool.t -> Terrat_stategraph.t
end

module type S = sig
  include Sgs_service.S with type t = Terrat_stategraph.t and type opt = Sgs_svc_mngr.t

  (** Names this service in a match on {!Sgs_service.ty}. *)
  type 'a Sgs_service.ty += Ty : t Sgs_service.ty
end

(** The name every instance registers under: one Stategraph reader runs in a server. *)
val name : string

(** No reader: {!Terrat_stategraph.Standalone}. *)
module Standalone : READER

(** How to make a stategraph-backed reader *)
module Make (_ : READER) : S
