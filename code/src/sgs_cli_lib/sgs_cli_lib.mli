(** The server command line: [server], [migrate], [version] and [test]. A build of the server is a
    list of {!Sgs_service.S}; the core starts them, serves their routes next to its own, and stops
    them. *)

(** Parse [Sys.argv], run the selected subcommand, and exit the process. [services] start in list
    order and stop in the reverse order. They include a config service ({!Sgs_service_config.Make}):
    the server reads its configuration from it. *)
val main : services:(module Sgs_service.S with type opt = Sgs_svc_mngr.t) list -> unit
