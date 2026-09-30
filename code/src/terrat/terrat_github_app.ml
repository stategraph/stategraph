let src = Logs.Src.create "github_app"

module Logs = (val Logs.src_log src : Logs.LOG)

(* The console polls for readiness right after it stores the App, so the first
   minutes are checked often. After that nobody is watching and the wait can
   last days, so the interval grows. *)
let poll_interval = 5.0
let poll_interval_idle = 60.0
let poll_attention_span = 120.0

module Sql = struct
  let select_app () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.bigint
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
      /^ "select id, pem, client_id, client_secret, webhook_secret, html_url from github_app")

  let count_app () = Pgsql_io.Typed_sql.(sql // Ret.bigint /^ "select count(*) from github_app")
  let mark_loaded () = Pgsql_io.Typed_sql.(sql /^ "update github_app set loaded_at = now()")
end

type err =
  [ Pgsql_pool.err
  | Pgsql_io.err
  | `Key_error of string
  | `Bad_pem of string
  ]
[@@deriving show]

let load storage =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.fetch
        db
        (Sql.select_app ())
        ~f:(fun id pem client_id client_secret webhook_secret html_url ->
          (id, pem, client_id, client_secret, webhook_secret, html_url)))
  >>| function
  | Ok [] -> Ok None
  | Ok ((id, pem, client_id, client_secret, webhook_secret, html_url) :: _) -> (
      match
        Terrat_config.github_of_stored
          ~app_id:(Int64.to_string id)
          ~pem
          ~client_id
          ~client_secret
          ~webhook_secret
          ~app_url:html_url
      with
      | Ok github -> Ok (Some github)
      | Error (#Terrat_config.err as err) -> Error err)
  | Error (#err as err) -> Error err

let mark_loaded storage =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db -> Pgsql_io.Prepared_stmt.execute db (Sql.mark_loaded ()))
  >>| function
  | Ok () -> Ok ()
  | Error (#err as err) -> Error err

let rec exit_when_created ?(waited = 0.0) storage =
  let open Abb.Future.Infix_monad in
  let interval = if waited < poll_attention_span then poll_interval else poll_interval_idle in
  Abb.Sys.sleep interval
  >>= fun () ->
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.fetch db (Sql.count_app ()) ~f:CCFun.id)
  >>= function
  | Ok (n :: _) when n > 0L ->
      Logs.info (fun m -> m "GITHUB_APP : CREATED : RESTART");
      exit 0
  | Ok _ -> exit_when_created ~waited:(waited +. interval) storage
  | Error (#err as err) ->
      Logs.err (fun m -> m "GITHUB_APP : POLL : %a" pp_err err);
      exit_when_created ~waited:(waited +. interval) storage
