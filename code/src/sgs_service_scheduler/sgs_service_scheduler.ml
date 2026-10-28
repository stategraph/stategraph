let src = Logs.Src.create "scheduler"

module Logs = (val Logs.src_log src : Logs.LOG)
module Service = Abbs_service_local

type register_kind_err = [ `Chan_closed ] [@@deriving show]
type register_task_err = [ `Chan_closed ] [@@deriving show]

(* The id of a scheduled task: its [kind] in the [schedules] table. *)
module Id = struct
  type t = string

  let of_string s = s
  let to_string t = t
end

module Schedule = struct
  type t =
    | Minutely
    | Hourly
    | Daily
    | Weekly
    | Monthly

  (* The converter of {!t} for the typed SQL layer: [None] is a row value the type does not
     represent, which [Ret.u] reports as [`Bad_result]. Every value the [schedules] check
     constraint allows maps to a constructor. *)
  let of_string = function
    | "minutely" -> Some Minutely
    | "hourly" -> Some Hourly
    | "daily" -> Some Daily
    | "weekly" -> Some Weekly
    | "monthly" -> Some Monthly
    | _ -> None

  let to_string = function
    | Minutely -> "minutely"
    | Hourly -> "hourly"
    | Daily -> "daily"
    | Weekly -> "weekly"
    | Monthly -> "monthly"
end

(* What a registered kind runs: the dispatch function a service hands to {!register_kind}. *)
type task_run = Sgs_config.t -> Sgs_storage.t -> Pgsql_io.t -> Yojson.Safe.t -> unit Abb.Future.t

module Reg_req = struct
  type 'resp t =
    | Register_kind : Id.t * task_run -> unit t
    | Register_task : Id.t * Schedule.t * Yojson.Safe.t -> unit t
    | Lookup : Id.t -> task_run option t
    | Stop : unit t
end

module Reg = Service.Make_typed (Reg_req)

(* The Postgres-backed implementation of the generic distributed scheduler. [Store.tx] borrows a
   connection from the shared pool and opens a transaction around the [Dist_scheduler] callback;
   [fetch_next] claims the next due row with `for update skip locked` inside that transaction, so
   the row stays locked through [run] (dispatch + advance) and concurrent instances skip it.

   Query-level errors are caught by [fetch_next] (reported as a fetch error, which ends the
   iteration cleanly) and by [run] (logged and swallowed). A connection-level failure (pool closed
   / unreachable) is reported by [Store.tx] as an error of kind [Tx], which [Dist_scheduler] handles
   by ending the iteration / failing the pending operation -- the service loop keeps running. *)
module Sched_s = struct
  module Task = struct
    (* A schedule row. [v] carries the per-state payload following the [minted]/[stored] convention
       used across the codebase (see {!Sgs_tf_state}): a [minted] schedule has no id yet (the
       database assigns it), a [stored] schedule does. *)
    type 'a t = {
      schedule : Schedule.t;
      kind : string;
      data : Yojson.Safe.t;
      v : 'a;
    }
  end

  module Sql = struct
    let claim_due_sql = Mql_sql.read [%blob "./sql/claim_due.sql"]

    let claim_due () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* schedule *)
        Ret.u Ret.text Schedule.of_string
        //
        (* kind *)
        Ret.text
        //
        (* data *)
        Ret.jsonb
        /^ claim_due_sql)

    let advance_last_run_at_sql = Mql_sql.read [%blob "./sql/advance_last_run_at.sql"]

    let advance_last_run_at () =
      Pgsql_io.Typed_sql.(sql /^ advance_last_run_at_sql /% Var.uuid "id")

    let insert_schedule_sql = Mql_sql.read [%blob "./sql/insert_schedule.sql"]

    let insert_schedule () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        /^ insert_schedule_sql
        /% Var.ud (Var.text "schedule") Schedule.to_string
        /% Var.text "kind"
        /% Var.json "data")

    let update_schedule_sql = Mql_sql.read [%blob "./sql/update_schedule.sql"]

    let update_schedule () =
      Pgsql_io.Typed_sql.(
        sql
        /^ update_schedule_sql
        /% Var.ud (Var.text "schedule") Schedule.to_string
        /% Var.text "kind"
        /% Var.json "data"
        /% Var.uuid "id")

    let delete_schedule_sql = Mql_sql.read [%blob "./sql/delete_schedule.sql"]
    let delete_schedule () = Pgsql_io.Typed_sql.(sql /^ delete_schedule_sql /% Var.uuid "id")
    let select_schedule_by_id_sql = Mql_sql.read [%blob "./sql/select_schedule_by_id.sql"]

    let select_schedule_by_id () =
      Pgsql_io.Typed_sql.(
        sql
        //
        (* id *)
        Ret.uuid
        //
        (* schedule *)
        Ret.u Ret.text Schedule.of_string
        //
        (* kind *)
        Ret.text
        //
        (* data *)
        Ret.jsonb
        /^ select_schedule_by_id_sql
        /% Var.uuid "id")

    let upsert_task_sql = Mql_sql.read [%blob "./sql/upsert_task.sql"]

    let upsert_task () =
      Pgsql_io.Typed_sql.(
        sql
        /^ upsert_task_sql
        /% Var.text "kind"
        /% Var.ud (Var.text "schedule") Schedule.to_string
        /% Var.json "data")

    let miss_task_sql = Mql_sql.read [%blob "./sql/miss_task.sql"]
    let miss_task () = Pgsql_io.Typed_sql.(sql // Ret.integer /^ miss_task_sql /% Var.uuid "id")
  end

  module Store = struct
    type opts = {
      config : Sgs_config.t;
      storage : Sgs_storage.t;
      registry : Reg.svc;
    }

    type t = opts
    type tx = Pgsql_io.t * t
    type minted = unit
    type stored = { id : Uuidm.t }
    type id = Uuidm.t

    let stored_id row = row.Task.v.id
    let row_of_columns id schedule kind data = { Task.schedule; kind; data; v = { id } }
    let create opts = Abb.Future.return (Ok opts)

    (* The pool is owned by the caller (the server); never tear it down here. *)
    let destroy _ = Abb.Future.return ()

    let tx ({ storage; _ } as opts) f =
      let open Abb.Future.Infix_monad in
      Pgsql_pool.with_conn storage ~f:(fun db ->
          Pgsql_io.tx db ~f:(fun () -> f (db, opts) >>= fun v -> Abb.Future.return (Ok v)))
      >>= function
      | Ok v -> Abb.Future.return (Ok v)
      | Error err ->
          let msg =
            match err with
            | #Pgsql_io.err as err -> Pgsql_io.show_err err
            | _ -> "could not acquire a connection"
          in
          Logs.err (fun m -> m "TX : %s" msg);
          Abb.Future.return
            (Error (`Dist_sched_err { Dist_scheduler.kind = Dist_scheduler.Tx; msg }))

    let fetch_next (db, _) =
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.fetch db (Sql.claim_due ()) ~f:row_of_columns
      >>= function
      | Ok (row :: _) ->
          Logs.info (fun m ->
              m
                "CLAIM : id=%a : kind=%s : schedule=%s"
                Uuidm.pp
                (stored_id row)
                row.Task.kind
                (Schedule.to_string row.Task.schedule));
          Abb.Future.return (Ok (Some row))
      | Ok [] -> Abb.Future.return (Ok None)
      | Error (#Pgsql_io.err as err) ->
          Logs.err (fun m -> m "FETCH_NEXT : %a" Pgsql_io.pp_err err);
          Abb.Future.return
            (Error
               (`Dist_sched_err
                  { Dist_scheduler.kind = Dist_scheduler.Fetch; msg = Pgsql_io.show_err err }))

    module Task = struct
      let store (db, _) row =
        let open Abb.Future.Infix_monad in
        Pgsql_io.Prepared_stmt.fetch
          db
          (Sql.insert_schedule ())
          ~f:CCFun.id
          row.Task.schedule
          row.Task.kind
          row.Task.data
        >>= function
        | Ok (id :: _) -> Abb.Future.return (Ok { row with Task.v = { id } })
        | Ok [] ->
            Abb.Future.return
              (Error
                 (`Dist_sched_err
                    { Dist_scheduler.kind = Dist_scheduler.Store; msg = "insert returned no id" }))
        | Error (#Pgsql_io.err as err) ->
            Abb.Future.return
              (Error
                 (`Dist_sched_err
                    { Dist_scheduler.kind = Dist_scheduler.Store; msg = Pgsql_io.show_err err }))

      let update (db, _) row =
        let open Abb.Future.Infix_monad in
        Pgsql_io.Prepared_stmt.execute
          db
          (Sql.update_schedule ())
          row.Task.schedule
          row.Task.kind
          row.Task.data
          (stored_id row)
        >>= function
        | Ok () -> Abb.Future.return (Ok ())
        | Error (#Pgsql_io.err as err) ->
            Abb.Future.return
              (Error
                 (`Dist_sched_err
                    { Dist_scheduler.kind = Dist_scheduler.Update; msg = Pgsql_io.show_err err }))

      let delete (db, _) row =
        let open Abb.Future.Infix_monad in
        Pgsql_io.Prepared_stmt.execute db (Sql.delete_schedule ()) (stored_id row)
        >>= function
        | Ok () -> Abb.Future.return (Ok ())
        | Error (#Pgsql_io.err as err) ->
            Abb.Future.return
              (Error
                 (`Dist_sched_err
                    { Dist_scheduler.kind = Dist_scheduler.Delete; msg = Pgsql_io.show_err err }))

      let fetch (db, _) id =
        let open Abb.Future.Infix_monad in
        Pgsql_io.Prepared_stmt.fetch db (Sql.select_schedule_by_id ()) ~f:row_of_columns id
        >>= function
        | Ok (row :: _) -> Abb.Future.return (Ok (Some row))
        | Ok [] -> Abb.Future.return (Ok None)
        | Error (#Pgsql_io.err as err) ->
            Abb.Future.return
              (Error
                 (`Dist_sched_err
                    { Dist_scheduler.kind = Dist_scheduler.Fetch; msg = Pgsql_io.show_err err }))
    end
  end

  (* A claim whose kind has no registered handler: advance the next run so the task re-runs on its
     own schedule and count the miss. The third miss deletes the row. *)
  let miss db id =
    let open Abb.Future.Infix_monad in
    Pgsql_io.Prepared_stmt.fetch db (Sql.miss_task ()) ~f:(fun misses -> misses) id
    >>= function
    | Ok (misses :: _) when misses >= 3l -> (
        Logs.warn (fun m -> m "DELETE : id=%a : misses=%ld" Uuidm.pp id misses);
        Pgsql_io.Prepared_stmt.execute db (Sql.delete_schedule ()) id
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "DELETE : id=%a : %a" Uuidm.pp id Pgsql_io.pp_err err);
            Abb.Future.return ())
    | Ok _ -> Abb.Future.return ()
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "MISS : id=%a : %a" Uuidm.pp id Pgsql_io.pp_err err);
        Abb.Future.return ()

  (* Dispatch a claimed schedule and advance its [last_run_at]. Never raises and never returns an
     error: a failed dispatch is logged and the schedule still advances (at-most-once), which also
     prevents [drain] from re-fetching the same row within one iteration. A claim whose kind has
     nobody registered records a miss instead. *)
  let run (db, { Store.config; storage; registry }) row =
    let open Abb.Future.Infix_monad in
    let id = Store.stored_id row in
    Reg.call registry (Reg_req.Lookup (Id.of_string row.Task.kind))
    >>= function
    | Error `Chan_closed -> miss db id
    | Ok None ->
        Logs.warn (fun m -> m "NOT_REGISTERED : id=%a : kind=%s" Uuidm.pp id row.Task.kind);
        miss db id
    | Ok (Some task) -> (
        task config storage db row.Task.data
        >>= fun () ->
        Pgsql_io.Prepared_stmt.execute db (Sql.advance_last_run_at ()) id
        >>= function
        | Ok () ->
            Logs.debug (fun m -> m "ADVANCE : id=%a" Uuidm.pp id);
            Abb.Future.return ()
        | Error (#Pgsql_io.err as err) ->
            Logs.err (fun m -> m "ADVANCE : id=%a : %a" Uuidm.pp id Pgsql_io.pp_err err);
            Abb.Future.return ())
end

module Dist = Dist_scheduler.Make (Sched_s)

(* The registry loop owns the registered kinds and the schedule upserts. Its state is an immutable
   map threaded through the loop, so no mutable table is shared across tasks and every iteration
   sees the state the previous one returned. *)
let registry_loop storage svc =
  let open Abb.Future.Infix_monad in
  let module Task_map = Map.Make (String) in
  let upsert_task kind schedule data =
    Pgsql_pool.with_conn storage ~f:(fun db ->
        Pgsql_io.Prepared_stmt.execute
          db
          (Sched_s.Sql.upsert_task ())
          (Id.to_string kind)
          schedule
          data)
    >>= function
    | Ok () -> Abb.Future.return ()
    | Error err ->
        let msg =
          match err with
          | #Pgsql_io.err as err -> Pgsql_io.show_err err
          | _ -> "could not acquire a connection"
        in
        Logs.err (fun m -> m "REGISTER_TASK : kind=%s : %s" (Id.to_string kind) msg);
        Abb.Future.return ()
  in
  let rec loop tasks =
    Abb.Chan.recv svc
    >>= function
    | Ok (Reg.Msg req) -> (
        match Service.Request.payload req with
        | Reg_req.Register_kind (kind, run) ->
            Service.respond req (fun () -> Abb.Future.return ())
            >>= fun () -> loop (Task_map.add (Id.to_string kind) run tasks)
        | Reg_req.Register_task (kind, schedule, data) ->
            upsert_task kind schedule data
            >>= fun () ->
            Service.respond req (fun () -> Abb.Future.return ()) >>= fun () -> loop tasks
        | Reg_req.Lookup kind ->
            let found = Task_map.find_opt (Id.to_string kind) tasks in
            Service.respond req (fun () -> Abb.Future.return found) >>= fun () -> loop tasks
        | Reg_req.Stop ->
            Service.respond req (fun () -> Abb.Future.return ()) >>= fun () -> Abb.Future.return ())
    | Error `Chan_closed -> Abb.Future.return ()
  in
  loop Task_map.empty

type t = {
  dist : Dist.t;
  registry : Reg.svc;
}

type 'a Sgs_service.ty += Ty : t Sgs_service.ty

let ty = Ty

let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
  match q with
  | Ty -> Some Sgs_service.Refl
  | _ -> None

let name = "scheduler"
let default_wait () = Abb.Sys.sleep (Duration.to_f (Duration.of_min 10))

(* [start] below is this with the default cadence; [wait] stays a label so a test can drive a
   single deterministic iteration. *)
let start_with_wait ~wait config storage =
  let open Abb.Future.Infix_monad in
  Service.create ~name:"sgs-scheduler-registry" (registry_loop storage)
  >>= fun registry ->
  Dist.start ~name:"sgs-scheduler" ~wait { Sched_s.Store.config; storage; registry }
  >>| fun dist -> { dist; registry }

type opt = Sgs_svc_mngr.t

let start mgr =
  let open Abbs_fc.Infix_result_monad in
  Abbs_fc.Result.all2
    (Sgs_svc_mngr.load ~name:Sgs_service_config.name Sgs_service_config.Ty mgr)
    (Sgs_svc_mngr.load ~name:Sgs_service_storage.name Sgs_service_storage.Ty mgr)
  >>= fun (config, storage) ->
  start_with_wait ~wait:default_wait config storage |> Abb.Future.map (fun v -> Ok v)

let register_kind t ~kind run =
  let open Abb.Future.Infix_monad in
  Reg.call t.registry (Reg_req.Register_kind (kind, run))
  >>= function
  | Ok () -> Abbs_fc.return_ok ()
  | Error `Chan_closed -> Abbs_fc.return_err `Chan_closed

let register_task t ~kind schedule data =
  let open Abb.Future.Infix_monad in
  Reg.call t.registry (Reg_req.Register_task (kind, schedule, data))
  >>= function
  | Ok () -> Abbs_fc.return_ok ()
  | Error `Chan_closed -> Abbs_fc.return_err `Chan_closed

let register_scheduled_kind t ~kind schedule run =
  let open Abb.Future.Infix_monad in
  let register () =
    let open Abbs_fc.Infix_result_monad in
    register_kind t ~kind run >>= fun () -> register_task t ~kind schedule (`Assoc [])
  in
  register ()
  >>| function
  | Ok () -> ()
  | Error `Chan_closed ->
      Logs.warn (fun m ->
          m "REGISTER_SCHEDULED_KIND : kind=%s : REGISTRY_CLOSED" (Id.to_string kind))

(* The scheduler appends no routes of its own. *)
let routes _ = []
let wrap _ = CCFun.id

let stop t =
  let open Abb.Future.Infix_monad in
  Dist.stop t.dist >>= fun () -> Reg.call t.registry Reg_req.Stop >>= fun _ -> Abb.Future.return ()
