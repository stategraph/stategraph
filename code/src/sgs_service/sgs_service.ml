type route = Brtl_rtng.Method.t * Brtl_rtng.Handler.t Brtl_rtng.Route.Route.t
type start_err = [ `Start_err of string ]
type 'a ty = ..

module type S = sig
  type t

  val name : string
  val ty : t ty
  val start : Sgs_config.t -> Sgs_storage.t -> (t, start_err) result Abb.Future.t
  val routes : t -> Sgs_config.t -> Sgs_storage.t -> route list
  val stop : t -> unit Abb.Future.t
end

type started = Started : (module S with type t = 'a) * 'a -> started

let src = Logs.Src.create "service"

module Logs = (val Logs.src_log src : Logs.LOG)

let start (module M : S) config storage =
  let open Abb.Future.Infix_monad in
  Logs.info (fun m -> m "Starting service %s" M.name);
  M.start config storage >>| CCResult.map (fun t -> Started ((module M), t))

let routes (Started ((module M), t)) config storage = M.routes t config storage

let stop (Started ((module M), t)) =
  Logs.info (fun m -> m "Stopping service %s" M.name);
  M.stop t
