type t = {
  config : Terrat_config.t;
  storage : Terrat_storage.t;
  watcher : unit Abb.Future.t option;
}

type opt = Sgs_svc_mngr.t
type 'a Sgs_service.ty += Ty : t Sgs_service.ty

let ty = Ty

let matches (type a) (q : a Sgs_service.ty) : (t, a) Sgs_service.eq option =
  match q with
  | Ty -> Some Sgs_service.Refl
  | _ -> None

let name = "terrat_config"

(* An empty secret HMACs with an empty key and rejects every webhook, and no secret skips the
   verification of webhooks, which are publicly routed. *)
let check_webhook_secret config =
  match CCOption.map Terrat_config.Github.webhook_secret (Terrat_config.github config) with
  | None -> Ok ()
  | Some (Some secret) when not (CCString.is_empty secret) -> Ok ()
  | Some (Some _ | None) ->
      Error
        (`Start_fatal_err
           "GITHUB_WEBHOOK_SECRET must be set, and not empty, when GITHUB_APP_ID is set. Set it to \
            the value configured under the GitHub App's Webhook -> Secret")

(* The watcher runs until the service stops: it ends the process when the stored App changes. It is
   forked last, once nothing can fail any more, so a refused start leaves no watcher behind. *)
let fork_watcher = function
  | Some watch -> Abb.Future.fork (watch ()) |> Abb.Future.map CCOption.return
  | None -> Abb.Future.return None

let show_storage_err = function
  | #Pgsql_io.err as err -> Pgsql_io.show_err err
  | #Pgsql_pool.err as err -> Pgsql_pool.show_err err

(* The pool is destroyed when the App cannot be settled, so a refused start leaves no pool behind. *)
let resolve config storage =
  let open Abb.Future.Infix_monad in
  Terrat_github_app.resolve config storage
  >>= function
  | Ok _ as resolved -> Abb.Future.return resolved
  | Error err ->
      Pgsql_pool.destroy storage
      >>| fun () -> Error (`Start_fatal_err (Terrat_github_app.show_err err))

let start _ =
  let open Abbs_fc.Infix_result_monad in
  Abb.Future.return
    (CCResult.map_err
       (fun err -> `Start_fatal_err (Terrat_config.show_err err))
       (Sgs_terrat_config.create ()))
  >>= fun config ->
  Abb.Future.return (check_webhook_secret config)
  >>= fun () ->
  Abbs_fc.Result.map_err
    ~f:(fun err -> `Start_fatal_err (show_storage_err err))
    (Terrat_storage.try_create config)
  >>= fun storage ->
  resolve config storage
  >>= fun (config, watch) ->
  let open Abb.Future.Infix_monad in
  fork_watcher watch >>= fun watcher -> Abbs_fc.return_ok { config; storage; watcher }

let config { config; storage = _; watcher = _ } = config
let storage { config = _; storage; watcher = _ } = storage
let routes _ = []
let wrap _ = CCFun.id

let stop { config = _; storage = _; watcher } =
  CCOption.map_or ~default:(Abb.Future.return ()) Abb.Future.abort watcher
