let src = Logs.Src.create "svc_mngr"

module Logs = (val Logs.src_log src : Logs.LOG)
module Service = Abbs_service_local

type start_err = [ `Start_err ] [@@deriving show]
type register_err = [ `Register_err ] [@@deriving show]

type get_err =
  [ `Service_not_found_err
  | `Chan_closed
  ]
[@@deriving show]

type routes_err = [ `Routes_err ] [@@deriving show]

(* What the loop needs to start a service on a task of its own. The [run] closure captures the
   service module and the manager; both are safe to read from that task. *)
type starter = {
  name : string;
  run : unit -> (Sgs_service.started, Sgs_service.start_err) result Abb.Future.t;
}

type state =
  | Waiting
  | All_started
  | Fatal of string

module Req = struct
  type 'resp t =
    | Register : starter -> unit t
    | Registered : int * Sgs_service.started -> unit t
    | Failed : string -> unit t
    | Add : Sgs_service.started -> unit t
    | Get : 'a Sgs_service.ty -> 'a option t
    | State : state t
    | Routes : (Sgs_service.started -> Sgs_service.route list) -> Sgs_service.route list t
    | Stop : unit t
end

module Typed = Service.Make_typed (Req)

module Svc = struct
  (* Starts run on tasks of their own and so finish in no fixed order; [next_id] numbers the
     services in registration order, so routes can be collected in that order. [pending] counts
     the services that registered but have not reported a start yet. [fatal] is the first fatal
     refusal. *)
  type t = {
    next_id : int;
    pending : int;
    services : (int * Sgs_service.started) list;
    fatal : string option;
  }

  (* A fatal refusal is not retried: the manager reports it to the waiters of [started]. *)
  let fail svc starter msg =
    let open Abb.Future.Infix_monad in
    let msg = Printf.sprintf "Service %s cannot start : %s" starter.name msg in
    Logs.err (fun m -> m "%s" msg);
    Typed.call svc (Req.Failed msg) >>= fun _ -> Abb.Future.return ()

  (* One attempt, then one second between tries, until the service starts, refuses for good, or
     the manager is gone. A start that raises refuses for good: a retry would raise again, and an
     exception that ended the task unseen would leave [started] waiting forever. *)
  let rec start_service svc id (starter : starter) =
    let open Abb.Future.Infix_monad in
    Abb.Future.await (Abb.Future.return () >>= starter.run)
    >>= function
    | `Det (Ok started) ->
        Typed.call svc (Req.Registered (id, started))
        >>= Abbs_fc.when_err (fun `Chan_closed ->
            (* The manager is gone, so the service must not outlive it. *)
            Sgs_service.stop started)
    | `Det (Error (`Start_fatal_err msg)) -> fail svc starter msg
    | `Exn (exn, bt) ->
        CCOption.iter
          (fun bt ->
            Logs.err (fun m ->
                m "Service %s raised : %s" starter.name (Printexc.raw_backtrace_to_string bt)))
          bt;
        fail svc starter ("raised " ^ Printexc.to_string exn)
    | `Aborted -> Abb.Future.return ()
    | `Det (Error ((`Start_err _ | `Start_missing_deps_err _) as err)) -> (
        (* Any other refusal, missing dependencies included, is logged and retried: the next attempt
           runs one second later. *)
        Logs.err (fun m ->
            m "Service %s failed to start : %a" starter.name Sgs_service.pp_start_err err);
        Abb.Sys.sleep 1.0
        >>= fun () ->
        Typed.call svc Req.State
        >>= function
        | Ok (Waiting | All_started | Fatal _) -> start_service svc id starter
        | Error `Chan_closed -> Abb.Future.return ())

  (* The registered service the query names, if any. [matches] proves the stored value has the
     query's type when the witnesses match. *)
  let rec find_service : type a. a Sgs_service.ty -> (int * Sgs_service.started) list -> a option =
   fun q services ->
    match services with
    | [] -> None
    | (_, Sgs_service.Started (m, v)) :: services -> (
        let module M = (val m) in
        match M.matches q with
        | Some Sgs_service.Refl -> Some v
        | None -> find_service q services)

  let handle svc t (Typed.Msg req) =
    let open Abb.Future.Infix_monad in
    match Service.Request.payload req with
    | Req.Register starter ->
        let id = t.next_id in
        Service.respond req (fun () -> Abb.Future.return ())
        >>= fun () ->
        (* The start runs on a task, so the loop keeps serving while it waits and retries. *)
        Abb.Task.run ~pinned:false ~name:("sgs-svc-mngr-start-" ^ starter.name) (fun () ->
            start_service svc id starter)
        >>= fun _ ->
        Abb.Future.return (`Continue { t with next_id = id + 1; pending = t.pending + 1 })
    | Req.Registered (id, started) ->
        Service.respond req (fun () -> Abb.Future.return ())
        >>= fun () ->
        Abb.Future.return
          (`Continue { t with pending = t.pending - 1; services = (id, started) :: t.services })
    | Req.Failed msg ->
        Service.respond req (fun () -> Abb.Future.return ())
        >>= fun () ->
        Abb.Future.return
          (`Continue
             { t with pending = t.pending - 1; fatal = CCOption.or_ ~else_:(Some msg) t.fatal })
    | Req.Add started ->
        let id = t.next_id in
        Service.respond req (fun () -> Abb.Future.return ())
        >>= fun () ->
        Abb.Future.return
          (`Continue { t with next_id = id + 1; services = (id, started) :: t.services })
    | Req.Get q ->
        let found = find_service q t.services in
        Service.respond req (fun () -> Abb.Future.return found)
        >>= fun () -> Abb.Future.return (`Continue t)
    | Req.State ->
        let state =
          match (t.fatal, t.pending) with
          | Some msg, _ -> Fatal msg
          | None, 0 -> All_started
          | None, _ -> Waiting
        in
        Service.respond req (fun () -> Abb.Future.return state)
        >>= fun () -> Abb.Future.return (`Continue t)
    | Req.Routes collect ->
        (* Routes come in registration order: the router matches in order, and start completion
           order is racy. The caller says how a started service turns into routes. *)
        let routes =
          CCList.sort (fun (i, _) (j, _) -> CCInt.compare i j) t.services
          |> CCList.flat_map (fun (_, s) -> collect s)
        in
        Service.respond req (fun () -> Abb.Future.return routes)
        >>= fun () -> Abb.Future.return (`Continue t)
    | Req.Stop ->
        (* The manager owns its services: it stops every one it started, newest first, which is
           the reverse of the order they started. A service still being retried stops itself when
           the channel closes. *)
        Abbs_fc.List.iter ~f:(fun (_, s) -> Sgs_service.stop s) t.services
        >>= fun () ->
        Service.respond req (fun () -> Abb.Future.return ()) >>= fun () -> Abb.Future.return `Stop

  let rec loop t svc =
    let open Abb.Future.Infix_monad in
    Abb.Chan.recv svc
    >>= function
    | Ok msg -> (
        handle svc t msg
        >>= function
        | `Continue t -> loop t svc
        | `Stop -> Abb.Future.return ())
    | Error `Chan_closed -> Abb.Future.return ()

  let run svc = loop { next_id = 0; pending = 0; services = []; fatal = None } svc
end

type t = Typed.svc

let start () = Abbs_fc.to_result @@ Typed.create ~name:"sgs_svc_mngr" ~pinned:false Svc.run

let stop t =
  let open Abb.Future.Infix_monad in
  Typed.call t Req.Stop >>= fun _ -> Abb.Future.return ()

let register t (service : (module Sgs_service.S with type opt = t)) =
  let module M = (val service) in
  let open Abb.Future.Infix_monad in
  Typed.call t (Req.Register { name = M.name; run = (fun () -> Sgs_service.start service t) })
  >>= function
  | Ok () -> Abbs_fc.return_ok ()
  | Error `Chan_closed -> Abbs_fc.return_err `Register_err

let add t started =
  let open Abb.Future.Infix_monad in
  Typed.call t (Req.Add started)
  >>= function
  | Ok () -> Abbs_fc.return_ok ()
  | Error `Chan_closed -> Abbs_fc.return_err `Register_err

let routes t collect =
  let open Abb.Future.Infix_monad in
  Typed.call t (Req.Routes collect)
  >>= function
  | Ok routes -> Abbs_fc.return_ok routes
  | Error `Chan_closed -> Abbs_fc.return_err `Routes_err

let get t ty =
  let open Abb.Future.Infix_monad in
  Typed.call t (Req.Get ty)
  >>= function
  | Ok (Some v) -> Abbs_fc.return_ok v
  | Ok None -> Abbs_fc.return_err `Service_not_found_err
  | Error `Chan_closed -> Abbs_fc.return_err `Chan_closed

(* A missing dependency refuses the start with the dependency's name, so the retry log names the
   service the caller waits for; a closed manager is a plain start error. *)
let load ~name ty mgr =
  let open Abb.Future.Infix_monad in
  get mgr ty
  >>= function
  | Ok v -> Abbs_fc.return_ok v
  | Error `Service_not_found_err -> Abbs_fc.return_err (`Start_missing_deps_err [ name ])
  | Error `Chan_closed ->
      Abbs_fc.return_err (`Start_err (Printf.sprintf "SERVICE_MANAGER : could not get %s" name))

let register' t services = Abbs_fc.List_result.iter ~f:(fun service -> register t service) services

(* Every caller runs its own poll of the manager's state, so any number of callers can wait at the
   same time and each gets its own future. A register whose start has not finished yet keeps the
   manager waiting; a service whose start never succeeds keeps the future undetermined. A closed
   manager has nothing left to wait for. *)
let rec started t =
  let open Abb.Future.Infix_monad in
  Typed.call t Req.State
  >>= function
  | Ok All_started -> Abbs_fc.return_ok ()
  | Ok (Fatal msg) -> Abbs_fc.return_err (`Start_fatal_err msg)
  | Ok Waiting -> Abb.Sys.sleep 0.1 >>= fun () -> started t
  | Error `Chan_closed -> Abbs_fc.return_ok ()
