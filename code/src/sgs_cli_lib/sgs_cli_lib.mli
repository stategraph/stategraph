(** The server command line: [server], [migrate], [version] and [test]. A build of the server is a
    list of {!Sgs_service.S}; the core starts them, serves their routes next to its own, and stops
    them. *)

(** The command line of an edition, given its Cloud abstraction. *)
module Make (_ : Sgs_cloud.S) : sig
  (** Parse [Sys.argv], run the selected subcommand, and exit the process. [services] start in list
      order and stop in the reverse order. *)
  val main : services:(module Sgs_service.S) list -> unit
end
