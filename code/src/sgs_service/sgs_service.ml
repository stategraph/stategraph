type route = Brtl_rtng.Method.t * Brtl_rtng.Handler.t Brtl_rtng.Route.Route.t

type start_err =
  [ `Start_err of string
  | `Start_missing_deps_err of string list
  ]
[@@deriving show]

type 'a ty = ..
type (_, _) eq = Refl : ('a, 'a) eq

module type S = sig
  type t
  type opt

  val name : string
  val ty : t ty
  val matches : 'a ty -> (t, 'a) eq option
  val start : opt -> (t, [> start_err ]) result Abb.Future.t
  val routes : t -> route list
  val stop : t -> unit Abb.Future.t
end

type started = Started : (module S with type t = 'a) * 'a -> started

let src = Logs.Src.create "service"

module Logs = (val Logs.src_log src : Logs.LOG)

let start (type opt) (m : (module S with type opt = opt)) (o : opt) =
  let module M = (val m) in
  let open Abb.Future.Infix_monad in
  Logs.info (fun m -> m "Starting service %s" M.name);
  M.start o >>| CCResult.map (fun t -> Started ((module M), t))

let routes (Started ((module M), t)) = M.routes t

let stop (Started ((module M), t)) =
  Logs.info (fun m -> m "Stopping service %s" M.name);
  M.stop t
