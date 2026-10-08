let src = Logs.Src.create "svc_mngr"

module Logs = (val Logs.src_log src : Logs.LOG)
module Service = Abbs_service_local

type start_err = [ `Start_err ] [@@deriving show]
type register_err = [ `Register_err ] [@@deriving show]
type config_err = [ `Config_err ] [@@deriving show]
type storage_err = [ `Storage_err ] [@@deriving show]

type get_err =
  [ `Service_not_found_err
  | `Chan_closed
  ]
[@@deriving show]

(* What the loop needs to start a service on a task of its own. The [run] closure captures the
   service module and the manager; both are safe to read from that task. *)
type starter = {
  name : string;
  run : unit -> (Sgs_service.started, Sgs_service.start_err) result Abb.Future.t;
}

module Req = struct
  type 'resp t =
    | Register : starter -> unit t
    | Registered : Sgs_service.started -> unit t
    | Get : 'a Sgs_service.ty -> 'a option t
    | Config : Sgs_config.t t
    | Storage : Sgs_storage.t t
    | Stop : unit t
end

module Typed = Service.Make_typed (Req)

module Svc = struct
  type t = {
    config : Sgs_config.t;
    storage : Sgs_storage.t;
    services : Sgs_service.started list;
  }

  (* One attempt, then one second between tries, until the service starts or the manager is
     gone. *)
  let rec start_service svc (starter : starter) =
    let open Abb.Future.Infix_monad in
    starter.run ()
    >>= function
    | Ok started ->
        Typed.call svc (Req.Registered started)
        >>= Abbs_fc.when_err (fun `Chan_closed ->
            (* The manager is gone, so the service must not outlive it. *)
            Sgs_service.stop started)
    | Error (#Sgs_service.start_err as err) ->
        (* Any refusal, missing dependencies included, is logged and retried: the next attempt runs
           one second later. *)
        Logs.err (fun m ->
            m "Service %s failed to start : %a" starter.name Sgs_service.pp_start_err err);
        Abb.Sys.sleep 1.0 >>= fun () -> start_service svc starter

  (* The registered service the query names, if any. [matches] proves the stored value has the
     query's type when the witnesses match. *)
  let rec find_service : type a. a Sgs_service.ty -> Sgs_service.started list -> a option =
   fun q services ->
    match services with
    | [] -> None
    | Sgs_service.Started (m, v) :: services -> (
        let module M = (val m) in
        match M.matches q with
        | Some Sgs_service.Refl -> Some v
        | None -> find_service q services)

  let handle svc t (Typed.Msg req) =
    let open Abb.Future.Infix_monad in
    match Service.Request.payload req with
    | Req.Register starter ->
        Service.respond req (fun () -> Abb.Future.return ())
        >>= fun () ->
        (* The start runs on a task, so the loop keeps serving while it waits and retries. *)
        Abb.Task.run ~pinned:false ~name:("sgs-svc-mngr-start-" ^ starter.name) (fun () ->
            start_service svc starter)
        >>= fun _ -> Abb.Future.return (`Continue t)
    | Req.Registered started ->
        Service.respond req (fun () -> Abb.Future.return ())
        >>= fun () -> Abb.Future.return (`Continue { t with services = started :: t.services })
    | Req.Get q ->
        let found = find_service q t.services in
        Service.respond req (fun () -> Abb.Future.return found)
        >>= fun () -> Abb.Future.return (`Continue t)
    | Req.Config ->
        Service.respond req (fun () -> Abb.Future.return t.config)
        >>= fun () -> Abb.Future.return (`Continue t)
    | Req.Storage ->
        Service.respond req (fun () -> Abb.Future.return t.storage)
        >>= fun () -> Abb.Future.return (`Continue t)
    | Req.Stop ->
        (* The manager owns its services: it stops every one it started, newest first, which is
           the reverse of the order they started. A service still being retried stops itself when
           the channel closes. *)
        Abbs_fc.List.iter ~f:Sgs_service.stop t.services
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

  let run config storage svc = loop { config; storage; services = [] } svc
end

type t = Typed.svc

let start config storage =
  Abbs_fc.to_result @@ Typed.create ~name:"sgs_svc_mngr" ~pinned:false (Svc.run config storage)

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
  Typed.call t (Req.Registered started)
  >>= function
  | Ok () -> Abbs_fc.return_ok ()
  | Error `Chan_closed -> Abbs_fc.return_err `Register_err

let config t =
  let open Abb.Future.Infix_monad in
  Typed.call t Req.Config
  >>= function
  | Ok cfg -> Abbs_fc.return_ok cfg
  | Error `Chan_closed -> Abbs_fc.return_err `Config_err

let storage t =
  let open Abb.Future.Infix_monad in
  Typed.call t Req.Storage
  >>= function
  | Ok stg -> Abbs_fc.return_ok stg
  | Error `Chan_closed -> Abbs_fc.return_err `Storage_err

let get t ty =
  let open Abb.Future.Infix_monad in
  Typed.call t (Req.Get ty)
  >>= function
  | Ok (Some v) -> Abbs_fc.return_ok v
  | Ok None -> Abbs_fc.return_err `Service_not_found_err
  | Error `Chan_closed -> Abbs_fc.return_err `Chan_closed

(* Registration returns once the message is sent, so the boot waits here until the manager has
   started every service. The manager retries a failed start one second later, so a service whose
   dependency is not up yet neither holds up the other services nor fails the call. *)
let start_services t services =
  let open Abb.Future.Infix_monad in
  let started_of (service : (module Sgs_service.S with type opt = t)) =
    let module M = (val service) in
    get t M.ty
    >>| function
    | Ok v -> Some (Sgs_service.Started ((module M), v))
    | Error (`Service_not_found_err | `Chan_closed) -> None
  in
  let rec wait () =
    Abbs_fc.List.map ~f:started_of services
    >>= fun started ->
    let up = List.filter_map Fun.id started in
    if List.length up = List.length services then Abbs_fc.return_ok up
    else Abb.Sys.sleep 1.0 >>= fun () -> wait ()
  in
  Abbs_fc.List_result.iter ~f:(fun service -> register t service) services
  >>= function
  | Ok () -> wait ()
  | Error `Register_err ->
      Abbs_fc.return_err (`Start_err "SERVICE_MANAGER : could not register the service")
