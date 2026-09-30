let src = Logs.Src.create "github_app"

module Logs = (val Logs.src_log src : Logs.LOG)

(* The console polls for readiness right after it writes the App, so the first
   minutes are checked often. After that nobody is watching and the wait can
   last days, so the interval grows. Each sleep is jittered: replicas boot
   together, and an unjittered poll has them all exit in the same second, which
   turns a rolling restart into an outage. *)
let poll_interval = 5.0
let poll_interval_idle = 60.0
let poll_attention_span = 120.0

module Sql = struct
  let columns =
    "select id, slug, pem, client_id, client_secret, webhook_secret, html_url from github_app"

  (* The token, computed remotely: the poll runs for the life of the process and
     has no business copying the private key out of the database to hash it. The
     columns are the credentials, so a replaced App and a rotated key both move
     it; loaded_at is not among them, so a process marking itself loaded cannot
     make itself stale. *)
  let select_token () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.bigint
      //
      (* digest *)
      Ret.text
      /^ "select id, md5(slug || pem || client_id || client_secret || webhook_secret || html_url) \
          from github_app")

  let select_app () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.bigint
      //
      (* slug *)
      Ret.text
      //
      (* pem *)
      Ret.text
      //
      (* client_id *)
      Ret.text
      //
      (* client_secret *)
      Ret.text
      //
      (* webhook_secret *)
      Ret.text
      //
      (* html_url *)
      Ret.text
      /^ columns)

  (* Bound to the App this process runs: a replace landing between the read and
     this write must not have the console told the engine holds it. *)
  let mark_loaded () =
    Pgsql_io.Typed_sql.(
      sql /^ "update github_app set loaded_at = now() where id = $id" /% Var.bigint "id")
end

type err =
  [ Pgsql_pool.err
  | Pgsql_io.err
  | `Key_error of string
  | `Bad_pem of string
  ]
[@@deriving show]

(* What the process compares the stored row against to decide it is running a
   stale App. Every credential column is in it, so replacing the App and
   rotating its key both change it, and [loaded_at] is not, so the process
   marking itself loaded cannot make itself stale. *)
type token = {
  app_id : int64;
  digest : string;
}
[@@deriving eq]

(* The same digest [Sql.select_token] computes remotely, so a token from [load]
   and a token from a poll compare. Every column here is not null, so the
   concatenation on either side is total. This identifies a version of a row,
   nothing more, which is all MD5 is asked for. *)
let token_of ~id ~slug ~pem ~client_id ~client_secret ~webhook_secret ~html_url =
  {
    app_id = id;
    digest =
      Digest.to_hex
        (Digest.string
           (String.concat "" [ slug; pem; client_id; client_secret; webhook_secret; html_url ]));
  }

type loaded =
  | No_app  (** no row *)
  | App of Terrat_config.Github.t * token  (** the row, usable *)
  | Unusable of token * err  (** the row is there and the process cannot run it *)

let select db =
  let open Abb.Future.Infix_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.select_app ())
    ~f:(fun id slug pem client_id client_secret webhook_secret html_url ->
      (id, slug, pem, client_id, client_secret, webhook_secret, html_url))
  >>| function
  | Ok [] -> Ok None
  | Ok (row :: _) -> Ok (Some row)
  | Error (#Pgsql_io.err as err) -> Error err

(* The token comes from the row this read returned, never from a second read: a
   write landing in between would otherwise be invisible for the life of the
   process. A row that will not decode still yields its token, so the process
   watches for the correction instead of treating the row as newly created and
   restarting on every poll. *)
let load storage =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:select
  >>| function
  | Ok None -> Ok No_app
  | Ok (Some (id, slug, pem, client_id, client_secret, webhook_secret, html_url)) -> (
      let token = token_of ~id ~slug ~pem ~client_id ~client_secret ~webhook_secret ~html_url in
      match
        Terrat_config.github_of_stored
          ~app_id:(Int64.to_string id)
          ~pem
          ~client_id
          ~client_secret
          ~webhook_secret
          ~app_url:html_url
      with
      | Ok github -> Ok (App (github, token))
      | Error (#Terrat_config.err as err) -> Ok (Unusable (token, err)))
  | Error (#err as err) -> Error err

let mark_loaded ~token storage =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.execute db (Sql.mark_loaded ()) token.app_id)
  >>| function
  | Ok () -> Ok ()
  | Error (#err as err) -> Error err

let stale ~loaded stored =
  match (loaded, stored) with
  | None, None -> None
  | None, Some _ -> Some `Created
  | Some _, None -> Some `Removed
  | Some loaded, Some stored when equal_token loaded stored -> None
  (* Same App, other credentials: the operator rotated its key. A different app
     id is a different App. Worth telling apart in the log of a restart nobody
     asked for. *)
  | Some loaded, Some stored when Int64.equal loaded.app_id stored.app_id -> Some `Rotated
  | Some _, Some _ -> Some `Replaced

let show_stale = function
  | `Created -> "CREATED"
  | `Removed -> "REMOVED"
  | `Replaced -> "REPLACED"
  | `Rotated -> "ROTATED"

let rec exit_when_changed ?(waited = 0.0) ~loaded storage =
  let open Abb.Future.Infix_monad in
  let interval = if waited < poll_attention_span then poll_interval else poll_interval_idle in
  let slept = interval *. (0.75 +. Random.float 0.5) in
  Abb.Sys.sleep slept
  >>= fun () ->
  Pgsql_pool.with_conn storage ~f:(fun db ->
      let open Abb.Future.Infix_monad in
      Pgsql_io.Prepared_stmt.fetch db (Sql.select_token ()) ~f:(fun app_id digest ->
          { app_id; digest })
      >>| function
      | Ok [] -> Ok None
      | Ok (token :: _) -> Ok (Some token)
      | Error (#Pgsql_io.err as err) -> Error err)
  >>= function
  | Ok stored -> (
      match stale ~loaded stored with
      | Some change ->
          Logs.info (fun m -> m "GITHUB_APP : %s : RESTART" (show_stale change));
          exit 0
      | None -> exit_when_changed ~waited:(waited +. slept) ~loaded storage)
  | Error (#err as err) ->
      Logs.err (fun m -> m "GITHUB_APP : POLL : %a" pp_err err);
      exit_when_changed ~waited:(waited +. slept) ~loaded storage

module Tests = struct
  let token ~app_id digest = { app_id; digest }
end
