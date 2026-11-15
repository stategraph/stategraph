type start_err = [ `Error ] [@@deriving show]
type get_user_err = [ `Error ] [@@deriving show]

let src = Logs.Src.create "vcs_service"

module Logs = (val Logs.src_log src : Logs.LOG)

(* The maintenance loops -- the drift, cleanup, and retention tasks -- are forked by [start] and
   never awaited, so an exception that settles one loop dead would go unseen and the task would
   never run again for the life of the process.  [start_loop name loop] runs [loop ()] and starts
   it again after an exception, with the log line a dead fork would never print; one second
   between restarts, so a task that raises on every run does not spin.  A loop that finishes or
   is aborted is not a failure: finishing never happens, and an abort is [Service.stop]'s handle,
   which ends the loop for good. *)
let rec start_loop name loop =
  let open Abb.Future.Infix_monad in
  Abb.Future.await_bind
    (function
      | `Det () | `Aborted -> Abb.Future.return ()
      | `Exn (exn, bt_opt) ->
          Logs.err (fun m -> m "%s : ERROR : %s" name (Printexc.to_string exn));
          CCOption.iter
            (fun bt ->
              Logs.err (fun m -> m "%s : BACKTRACE : %s" name (Printexc.raw_backtrace_to_string bt)))
            bt_opt;
          Abb.Sys.sleep 1.0 >>= fun () -> start_loop name loop)
    (loop ())

module type S = sig
  module Service : sig
    type t
    type vcs_config

    val name : t -> string

    val start :
      Terrat_config.t ->
      vcs_config ->
      Terrat_storage.t ->
      Terrat_vcs_event_evaluator2.Exec.t ->
      (t, [> start_err ]) result Abb.Future.t

    val stop : t -> unit Abb.Future.t
    val routes : t -> (Brtl_rtng.Method.t * Brtl_rtng.Handler.t Brtl_rtng.Route.Route.t) list
    val get_user : t -> Uuidm.t -> (Terrat_user.t option, [> get_user_err ]) result Abb.Future.t
  end
end

type service = Service : (module S with type Service.t = 'a) * 'a -> service
