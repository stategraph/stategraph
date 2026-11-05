module Api = Terrat_vcs_api_github
module Tmpl = Terrat_vcs_github_comment_templates.Tmpl
module Ui = Terrat_vcs_github_comment_ui.Ui
module Unified = Terrat_vcs_comment_unified

let src = Logs.Src.create "vcs_github_comment_unified"

module Logs = (val Logs.src_log src : Logs.LOG)

module Sql = struct
  let upsert_unified_comment_dirty_sql = Mql_sql.read [%blob "sql/upsert_unified_comment_dirty.sql"]

  let upsert_unified_comment_dirty =
    Pgsql_io.Typed_sql.(
      sql
      /^ upsert_unified_comment_dirty_sql
      /% Var.uuid "work_manifest"
      /% Var.boolean "output_details")

  let select_unified_comment_latest_work_manifest_sql =
    Mql_sql.read [%blob "sql/select_unified_comment_latest_work_manifest.sql"]

  let select_unified_comment_latest_work_manifest =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ select_unified_comment_latest_work_manifest_sql
      /% Var.bigint "repository"
      /% Var.bigint "pull_number")

  let mark_unified_comment_dirty_sql = Mql_sql.read [%blob "sql/mark_unified_comment_dirty.sql"]

  let mark_unified_comment_dirty =
    Pgsql_io.Typed_sql.(sql /^ mark_unified_comment_dirty_sql /% Var.uuid "work_manifest")

  let select_unified_comment_state_sql = Mql_sql.read [%blob "sql/select_unified_comment_state.sql"]

  let select_unified_comment_state =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* repository *)
      Ret.bigint
      //
      (* pull_number *)
      Ret.bigint
      //
      (* installation_id *)
      Ret.bigint
      //
      (* repo_owner *)
      Ret.text
      //
      (* repo_name *)
      Ret.text
      //
      (* comment_id *)
      Ret.(option bigint)
      //
      (* dirty *)
      Ret.bigint
      //
      (* output_details *)
      Ret.boolean
      /^ select_unified_comment_state_sql
      /% Var.uuid "work_manifest")

  let select_unified_comment_elements_sql =
    Mql_sql.read [%blob "sql/select_unified_comment_elements.sql"]

  let select_unified_comment_elements () =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* path *)
      Ret.text
      //
      (* workspace *)
      Ret.text
      //
      (* plan_success *)
      Ret.(option boolean)
      //
      (* plan_has_changes *)
      Ret.(option boolean)
      //
      (* plan_work_manifest *)
      Ret.(option uuid)
      //
      (* created *)
      Ret.(option bigint)
      //
      (* updated *)
      Ret.(option bigint)
      //
      (* deleted *)
      Ret.(option bigint)
      //
      (* replaced *)
      Ret.(option bigint)
      //
      (* imported *)
      Ret.(option bigint)
      //
      (* plan_output *)
      Ret.(option text)
      //
      (* apply_success *)
      Ret.(option boolean)
      //
      (* apply_work_manifest *)
      Ret.(option uuid)
      //
      (* latest_work_manifest *)
      Ret.(option uuid)
      //
      (* active *)
      Ret.boolean
      //
      (* active_apply *)
      Ret.boolean
      //
      (* aborted *)
      Ret.boolean
      //
      (* summary_state *)
      Ret.(option text)
      /^ select_unified_comment_elements_sql
      /% Var.uuid "work_manifest")

  let update_unified_comment_id_sql = Mql_sql.read [%blob "sql/update_unified_comment_id.sql"]

  let update_unified_comment_id =
    Pgsql_io.Typed_sql.(
      sql
      /^ update_unified_comment_id_sql
      /% Var.bigint "comment_id"
      /% Var.bigint "repository"
      /% Var.bigint "pull_number")

  let clear_unified_comment_dirty_sql = Mql_sql.read [%blob "sql/clear_unified_comment_dirty.sql"]

  let clear_unified_comment_dirty =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* repository *)
      Ret.bigint
      /^ clear_unified_comment_dirty_sql
      /% Var.bigint "repository"
      /% Var.bigint "pull_number"
      /% Var.bigint "dirty")

  let try_advisory_lock_sql =
    Mql_sql.read
      "select pg_try_advisory_xact_lock(hashtext('github_unified_comments'), hashtext($key))"

  let try_advisory_lock =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* locked *)
      Ret.boolean
      /^ try_advisory_lock_sql
      /% Var.text "key")

  let advisory_lock_sql =
    Mql_sql.read
      "select pg_advisory_xact_lock(hashtext('github_unified_comments'), hashtext($key)) is not \
       null"

  let advisory_lock =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* locked *)
      Ret.boolean
      (* [pg_advisory_xact_lock] returns a void datum, which is NOT null, so
         [is not null] is true once the call returns: the lock was acquired,
         after blocking until any concurrent holder released it.  ([is null]
         here would be always false -- void is not null -- and made every
         run-start publish take the [Skip] path.) *)
      /^ advisory_lock_sql
      /% Var.text "key")

  let select_unified_comment_pr_sql = Mql_sql.read [%blob "sql/select_unified_comment_pr.sql"]

  let select_unified_comment_pr =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* repository *)
      Ret.bigint
      //
      (* pull_number *)
      Ret.bigint
      /^ select_unified_comment_pr_sql
      /% Var.uuid "work_manifest")
end

(* The machine-readable payload of the [stategraph:unified:v1] trailer: every dirspace of the
   pull request, in render order.  It is a published format -- the system tests read it back --
   so it is a type of its own rather than a hand-built JSON document. *)
module Machine = struct
  module Dirspace = struct
    type t = {
      dir : string;
      workspace : string;
      status : string;
      has_changes : bool;
      created : int64 option;
      updated : int64 option;
      deleted : int64 option;
      replaced : int64 option;
      imported : int64 option;
      run_url : string option;
    }
    [@@deriving to_yojson]
  end

  type t = { dirspaces : Dirspace.t list } [@@deriving to_yojson]
end

module S = struct
  type t = {
    account : Api.Account.t;
    brand : Terrat_brand.t;
    client : Githubc2_abb.t;
    comment_id : Api.Comment.Id.t option;
    config : Api.Config.t;
    db : Pgsql_io.t;
    output_details : bool;
    pull_number : int64;
    repo_name : string;
    repo_owner : string;
    repository : int64;
    request_id : string;
    work_manifest_id : Uuidm.t;
  }

  type el = {
    created : int64 option;
    deleted : int64 option;
    dirspace : Terrat_dirspace.t;
    has_changes : bool;
    imported : int64 option;
    output : string option;
    replaced : int64 option;
    status : Unified.Status.t;
    updated : int64 option;
    work_manifest_id : Uuidm.t option;
  }
  [@@deriving ord, show]

  type comment_id = Api.Comment.Id.t [@@deriving ord, show]

  (* The database stores the state as text.  A name that this code does not know falls back to the
     runs on the head. *)
  let summary_status_of_string state =
    let module Ds = Terrat_vcs_provider2.Dirspace_summary in
    let module St = Unified.Status in
    CCOption.map
      (function
        | Ds.Applied -> St.Applied
        | Ds.Planned -> St.Planned
        | Ds.Failed -> St.Failed
        | Ds.Stale -> St.Stale)
      (Ds.of_string state)

  let status_of_row ~plan_success ~apply_success ~active ~active_apply ~aborted ~summary_state =
    let module St = Unified.Status in
    (* What a run in flight is called: the apply of a dirspace is named for what it does, because
       the plan it applies is already in the comment and the reader is waiting on the change, not
       on the plan. *)
    let in_flight = if active_apply then St.Apply_running else St.Plan_running in
    match (active, CCOption.flat_map summary_status_of_string summary_state) with
    | false, Some status -> status
    | true, _ | false, None -> (
        match (apply_success, active, plan_success) with
        | Some true, _, _ -> St.Applied
        | Some false, _, _ -> St.Failed
        | None, true, _ -> in_flight
        (* Nothing in flight and no plan either: the dirspace belongs to the pull request and nothing
       has run for it -- the state a run-start publish leaves every dirspace the run does not
       cover in. *)
        | None, false, Some false -> St.Failed
        | None, false, Some true -> St.Planned
        | None, false, None -> if aborted then St.Failed else St.Pending)

  let query_comment_id t = Abbs_fc.return_ok t.comment_id

  let query_els t =
    let open Abb.Future.Infix_monad in
    Pgsql_io.Prepared_stmt.fetch
      t.db
      (Sql.select_unified_comment_elements ())
      ~f:(fun
          path
          workspace
          plan_success
          plan_has_changes
          plan_work_manifest
          created
          updated
          deleted
          replaced
          imported
          plan_output
          apply_success
          apply_work_manifest
          latest_work_manifest
          active
          active_apply
          aborted
          summary_state
        ->
        {
          created;
          deleted;
          dirspace = { Terrat_dirspace.dir = path; workspace };
          has_changes = CCOption.get_or ~default:false plan_has_changes;
          imported;
          output = plan_output;
          replaced;
          status =
            status_of_row ~plan_success ~apply_success ~active ~active_apply ~aborted ~summary_state;
          updated;
          (* A dirspace with no run that counts for the head links to its newest run. *)
          work_manifest_id =
            CCOption.(
              apply_work_manifest
              |> or_ ~else_:plan_work_manifest
              |> or_ ~else_:latest_work_manifest);
        })
      t.work_manifest_id
    >>= function
    | Ok _ as r -> Abb.Future.return r
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : ERROR : %a" t.request_id Pgsql_io.pp_err err);
        Abbs_fc.return_err `Error

  let status_kv status =
    let module St = Unified.Status in
    match status with
    | St.Failed -> ":x: **Failed**"
    | St.Planned -> ":pencil2: Planned"
    | St.Plan_running -> ":construction: Plan Running"
    | St.Apply_running -> ":construction: Apply Running"
    | St.Stale -> ":warning: Stale"
    | St.Pending -> ":hourglass_flowing_sand: Pending"
    | St.Applied -> ":white_check_mark: Applied"

  let status_machine status =
    let module St = Unified.Status in
    match status with
    | St.Failed -> "failed"
    | St.Planned -> "planned"
    | St.Plan_running -> "plan_running"
    | St.Apply_running -> "apply_running"
    | St.Stale -> "stale"
    | St.Pending -> "pending"
    | St.Applied -> "applied"

  let shown_count el count =
    if Unified.Status.shows_counts el.status && el.has_changes then count else None

  let count_kv el count = CCOption.map_or ~default:"-" Int64.to_string (shown_count el count)

  let run_url t el =
    CCOption.map
      (fun work_manifest_id ->
        Uri.to_string
        @@ CCOption.get_exn_or "run_url"
        @@ Ui.dirspace_run_url ~brand:t.brand t.config t.account work_manifest_id el.dirspace)
      el.work_manifest_id

  let console_url t =
    Printf.sprintf
      "%s/runs/pr/%s/%Ld"
      (Ui.base_url ~brand:t.brand t.config t.account)
      (Uri.pct_encode ~component:`Path t.repo_name)
      t.pull_number

  let sum f els =
    CCList.fold_left (fun acc el -> Int64.add acc (CCOption.get_or ~default:0L (f el))) 0L els

  let machine_kv t els =
    let dirspaces =
      CCList.map
        (fun el ->
          let { Terrat_dirspace.dir; workspace } = el.dirspace in
          {
            Machine.Dirspace.dir;
            workspace;
            status = status_machine el.status;
            has_changes = el.has_changes;
            created = el.created;
            updated = el.updated;
            deleted = el.deleted;
            replaced = el.replaced;
            imported = el.imported;
            run_url = run_url t el;
          })
        els
    in
    let json = Machine.to_yojson { Machine.dirspaces } in
    (* "--" may not appear inside an HTML comment; encode it away using JSON
       unicode escapes so the payload stays valid JSON. *)
    CCString.replace ~sub:"--" ~by:"\\u002d\\u002d" (Yojson.Safe.to_string json)

  let render t tier els =
    let module T = Unified.Tier in
    let num_els = CCList.length els in
    let shown =
      match tier with
      | T.Details _ | T.Table -> els
      | T.Truncated n -> CCList.take n els
    in
    let details =
      match tier with
      | T.Details n -> CCList.filter (fun el -> CCOption.is_some el.output) (CCList.take n els)
      | T.Table | T.Truncated _ -> []
    in
    let count_status status =
      CCList.length (CCList.filter (fun el -> Unified.Status.compare el.status status = 0) els)
    in
    let kv =
      `Assoc
        [
          ("num_dirspaces", `Int num_els);
          ("num_failed", `Int (count_status Unified.Status.Failed));
          ("num_stale", `Int (count_status Unified.Status.Stale));
          ("num_planned", `Int (count_status Unified.Status.Planned));
          ("num_plan_running", `Int (count_status Unified.Status.Plan_running));
          ("num_apply_running", `Int (count_status Unified.Status.Apply_running));
          ("num_pending", `Int (count_status Unified.Status.Pending));
          ("num_applied", `Int (count_status Unified.Status.Applied));
          ( "dirspaces",
            `List
              (CCList.map
                 (fun el ->
                   let { Terrat_dirspace.dir; workspace } = el.dirspace in
                   `Assoc
                     [
                       ("dir", `String dir);
                       ("workspace", `String workspace);
                       ("status", `String (status_kv el.status));
                       ("imported", `String (count_kv el el.imported));
                       ("created", `String (count_kv el el.created));
                       ("updated", `String (count_kv el el.updated));
                       ("replaced", `String (count_kv el el.replaced));
                       ("deleted", `String (count_kv el el.deleted));
                       ( "run_url",
                         CCOption.map_or ~default:`Null (fun url -> `String url) @@ run_url t el );
                     ])
                 shown) );
          ( "totals",
            `Assoc
              [
                ( "imported",
                  `String (Int64.to_string (sum (fun el -> shown_count el el.imported) els)) );
                ( "created",
                  `String (Int64.to_string (sum (fun el -> shown_count el el.created) els)) );
                ( "updated",
                  `String (Int64.to_string (sum (fun el -> shown_count el el.updated) els)) );
                ( "replaced",
                  `String (Int64.to_string (sum (fun el -> shown_count el el.replaced) els)) );
                ( "deleted",
                  `String (Int64.to_string (sum (fun el -> shown_count el el.deleted) els)) );
              ] );
          ("truncated", `Int (num_els - CCList.length shown));
          ("console_url", `String (console_url t));
          ( "details",
            `List
              (CCList.map
                 (fun el ->
                   let { Terrat_dirspace.dir; workspace } = el.dirspace in
                   `Assoc
                     [
                       ("dir", `String dir);
                       ("workspace", `String workspace);
                       ("output", `String (CCOption.get_or ~default:"" el.output));
                     ])
                 details) );
          ( "show_apply_hint",
            `Bool
              (CCList.exists
                 (fun el ->
                   Unified.Status.compare el.status Unified.Status.Planned = 0 && el.has_changes)
                 els) );
          ( "machine",
            match tier with
            | T.Details _ | T.Table -> `String (machine_kv t els)
            | T.Truncated _ -> `Null );
        ]
    in
    match Minijinja.render_template (Tmpl.unified_comment t.brand) kv with
    | Ok body -> body
    | Error err ->
        Logs.err (fun m -> m "%s : ERROR : %s" t.request_id err);
        assert false

  let update_comment t comment_id body =
    let open Abb.Future.Infix_monad in
    Terrat_github.update_comment
      ~owner:t.repo_owner
      ~repo:t.repo_name
      ~comment_id:
        (Api.Comment.Id.to_string comment_id |> CCInt.of_string |> CCOption.get_exn_or "comment_id")
      ~body:(Terrat_comment.add_self_marker body)
      t.client
    >>= function
    | Ok () -> Abbs_fc.return_ok ()
    | Error `Not_found -> Abbs_fc.return_err `Not_found
    | Error (#Terrat_github.update_comment_err as err) ->
        Logs.err (fun m -> m "%s : ERROR : %a" t.request_id Terrat_github.pp_update_comment_err err);
        Abbs_fc.return_err `Error

  let post_comment t body =
    let open Abb.Future.Infix_monad in
    Terrat_github.publish_comment
      ~owner:t.repo_owner
      ~repo:t.repo_name
      ~pull_number:(CCInt64.to_int t.pull_number)
      ~body:(Terrat_comment.add_self_marker body)
      t.client
    >>= function
    | Ok comment_id -> (
        match Api.Comment.Id.of_string (CCInt.to_string comment_id) with
        | Some comment_id -> Abbs_fc.return_ok comment_id
        | None -> Abbs_fc.return_err `Error)
    | Error (#Terrat_github.publish_comment_err as err) ->
        Logs.err (fun m ->
            m "%s : ERROR : %a" t.request_id Terrat_github.pp_publish_comment_err err);
        Abbs_fc.return_err `Error

  let upsert_comment_id t comment_id =
    let open Abb.Future.Infix_monad in
    Pgsql_io.Prepared_stmt.execute
      t.db
      Sql.update_unified_comment_id
      (Int64.of_int
         (Api.Comment.Id.to_string comment_id |> CCInt.of_string |> CCOption.get_exn_or "comment_id"))
      t.repository
      t.pull_number
    >>= function
    | Ok () -> Abbs_fc.return_ok ()
    | Error (#Pgsql_io.err as err) ->
        Logs.err (fun m -> m "%s : ERROR : %a" t.request_id Pgsql_io.pp_err err);
        Abbs_fc.return_err `Error

  let dirspace el = el.dirspace
  let status el = el.status
  let has_changes el = el.has_changes
  let output_details t = t.output_details

  (* GitHub limits a comment to 65536 characters, and it counts the JSON-escaped body: every
     newline and every quote costs two.  The functor measures the RAW string
     (see [Terrat_vcs_comment_unified.max_comment_length]), so this bound has to absorb the
     escaping itself.  Plan output is dense in both, so a raw body can very nearly double once
     escaped -- half the limit is the bound the non-unified adapter uses for exactly this reason
     (terrat_vcs_github_comment.ml). *)
  let max_comment_length = 65536 / 2
end

module Publisher = Unified.Make (S)

let status_of_row = S.status_of_row

let mark_dirty ~request_id ~output_details db work_manifest_id =
  let open Abb.Future.Infix_monad in
  Pgsql_io.Prepared_stmt.execute db Sql.upsert_unified_comment_dirty work_manifest_id output_details
  >>= function
  | Ok () -> Abbs_fc.return_ok ()
  | Error (#Pgsql_io.err as err) ->
      Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
      Abbs_fc.return_err `Error

let mark_dirty_if_tracked ~request_id db work_manifest_id =
  let open Abb.Future.Infix_monad in
  Pgsql_io.Prepared_stmt.execute db Sql.mark_unified_comment_dirty work_manifest_id
  >>= function
  | Ok () -> Abbs_fc.return_ok ()
  | Error (#Pgsql_io.err as err) ->
      Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
      Abbs_fc.return_err `Error

(* One publish attempt against an open transaction on [db].  [lock] is the
   advisory-lock statement serializing publishers of one pull request: the
   non-blocking try-lock is used by result drains, where a concurrent
   publisher (or the next result) covers our dirty mark, and the blocking
   lock by run-start publishes, which must not skip -- they are what creates
   the comment before any result comment posts.  Returns [`Skip] when
   [lock] did not wait and another publisher holds the lock, [`Done] when the
   comment was published (or there was nothing to do), and [`Race] when the
   observed dirty counter moved while publishing. *)
let publish_core ~request_id ~fetch_brand ~lock config db work_manifest_id =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    Sql.select_unified_comment_state
    ~f:(fun
        repository
        pull_number
        installation_id
        repo_owner
        repo_name
        comment_id
        dirty
        output_details
      ->
      ( repository,
        pull_number,
        installation_id,
        repo_owner,
        repo_name,
        comment_id,
        dirty,
        output_details ))
    work_manifest_id
  >>= function
  | [] | (_, _, _, _, _, _, 0L, _) :: _ -> Abbs_fc.return_ok `Done
  | ( repository,
      pull_number,
      installation_id,
      repo_owner,
      repo_name,
      comment_id,
      dirty,
      output_details )
    :: _ -> (
      let key = Printf.sprintf "%Ld:%Ld" repository pull_number in
      Pgsql_io.Prepared_stmt.fetch db lock ~f:CCFun.id key
      >>= function
      | [ false ] ->
          (* Another drain is publishing; it will pick up our dirty
             mark or the next result will. *)
          Abbs_fc.return_ok `Skip
      | _ -> (
          let account = Api.Account.make (CCInt64.to_int installation_id) in
          Api.create_client ~request_id config account db
          >>= fun client ->
          Abbs_fc.Result.map_err
            ~f:(fun (#Terrat_vcs_api.call_err as err) -> err)
            (fetch_brand
               client
               (Api.Repo.make ~id:(CCInt64.to_int repository) ~name:repo_name ~owner:repo_owner ()))
          >>= fun brand ->
          let t =
            {
              S.account;
              brand;
              client = Api.Client.to_native client;
              comment_id =
                CCOption.flat_map CCFun.(Int64.to_string %> Api.Comment.Id.of_string) comment_id;
              config;
              db;
              output_details;
              pull_number;
              repo_name;
              repo_owner;
              repository;
              request_id;
              work_manifest_id;
            }
          in
          Publisher.run t
          >>= fun () ->
          Pgsql_io.Prepared_stmt.fetch
            db
            Sql.clear_unified_comment_dirty
            ~f:CCFun.id
            repository
            pull_number
            dirty
          >>= function
          | [] -> Abbs_fc.return_ok `Race
          | _ :: _ -> Abbs_fc.return_ok `Done))

(* One refresh attempt.  Runs in its own transaction on its own connection so
   the advisory lock and the GitHub API calls never extend a result
   transaction.  Returns [`Race] when new results marked the comment dirty
   while we were publishing, in which case the caller retries. *)
let refresh ~request_id ~fetch_brand config storage work_manifest_id =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.tx db ~f:(fun () ->
          publish_core
            ~request_id
            ~fetch_brand
            ~lock:Sql.try_advisory_lock
            config
            db
            work_manifest_id))
  >>= function
  | Ok (`Done | `Skip) -> Abbs_fc.return_ok `Done
  | Ok `Race -> Abbs_fc.return_ok `Race
  | Error (#Pgsql_io.err as e) as err ->
      Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err e);
      Abb.Future.return err
  | Error (#Terrat_vcs_api.call_err as e) as err ->
      Logs.err (fun m -> m "%s : ERROR : %a" request_id Terrat_vcs_api.pp_call_err e);
      Abb.Future.return err
  | Error (#Pgsql_pool.err as e) as err ->
      Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_pool.pp_err e);
      Abb.Future.return err

(* Publish the unified summary comment as a run starts, before any result
   comment posts.  Runs in the caller's open transaction so the comment's
   creation commits atomically with the run's own bookkeeping; the blocking
   advisory lock serializes concurrent starts of the same pull request, and
   each publish recomputes every dirspace, so the last writer leaves complete
   state.  Best effort: the caller logs failures and carries on -- the result
   drain still creates or refreshes the comment. *)
let publish_at_start ~request_id ~fetch_brand ~config ~output_details db work_manifest_id =
  let go () =
    let open Abbs_fc.Infix_result_monad in
    Pgsql_io.Prepared_stmt.fetch
      db
      Sql.select_unified_comment_pr
      ~f:(fun repository pull_number -> (repository, pull_number))
      work_manifest_id
    >>= function
    | [] ->
        (* Drift work manifests have no pull request; there is nothing to
           summarize. *)
        Abbs_fc.return_ok ()
    | [ (repository, pull_number) ] ->
        let key = Printf.sprintf "%Ld:%Ld" repository pull_number in
        let rec attempt n =
          if n <= 0 then Abbs_fc.return_ok ()
          else
            Pgsql_io.Prepared_stmt.fetch db Sql.advisory_lock ~f:CCFun.id key
            >>= fun _locked ->
            mark_dirty ~request_id ~output_details db work_manifest_id
            >>= fun () ->
            publish_core ~request_id ~fetch_brand ~lock:Sql.advisory_lock config db work_manifest_id
            >>= function
            | `Done | `Skip -> Abbs_fc.return_ok ()
            | `Race -> attempt (n - 1)
        in
        attempt 3
    | _ -> assert false
  in
  let open Abb.Future.Infix_monad in
  go ()
  >>= function
  | Ok () -> Abbs_fc.return_ok ()
  | Error (#Pgsql_io.err as err) ->
      Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_io.pp_err err);
      Abbs_fc.return_err `Error
  | Error (#Terrat_vcs_api.call_err as err) ->
      Logs.err (fun m -> m "%s : ERROR : %a" request_id Terrat_vcs_api.pp_call_err err);
      Abbs_fc.return_err `Error
  | Error (#Pgsql_pool.err as err) ->
      Logs.err (fun m -> m "%s : ERROR : %a" request_id Pgsql_pool.pp_err err);
      Abbs_fc.return_err `Error

let drain ~request_id ~fetch_brand config storage work_manifest_id =
  let open Abb.Future.Infix_monad in
  let rec attempt n =
    if n <= 0 then (
      (* The dirty counter is still set; the next drain of this pull request
         picks it up. *)
      Logs.warn (fun m ->
          m
            "%s : DRAIN_UNIFIED_COMMENT : RETRIES_EXHAUSTED : %a"
            request_id
            Uuidm.pp
            work_manifest_id);
      Abbs_fc.return_ok `Done)
    else
      refresh ~request_id ~fetch_brand config storage work_manifest_id
      >>= function
      | Ok `Done -> Abbs_fc.return_ok `Done
      | Ok `Race -> attempt (n - 1)
      | Error _ as err -> Abb.Future.return err
  in
  attempt 3
  >>= function
  | Ok `Done -> Abb.Future.return ()
  | Error `Error ->
      Logs.err (fun m -> m "%s : DRAIN_UNIFIED_COMMENT : ERROR" request_id);
      Abb.Future.return ()
  | Error (`Vcs_api_timeout_err operation) ->
      Logs.err (fun m -> m "%s : DRAIN_UNIFIED_COMMENT : VCS_API_TIMEOUT : %s" request_id operation);
      Abb.Future.return ()
  | Error (`Vcs_api_rate_limit_err operation) ->
      Logs.err (fun m ->
          m "%s : DRAIN_UNIFIED_COMMENT : VCS_API_RATE_LIMIT : %s" request_id operation);
      Abb.Future.return ()
  | Error (#Pgsql_pool.err as err) ->
      Logs.err (fun m -> m "%s : DRAIN_UNIFIED_COMMENT : %a" request_id Pgsql_pool.pp_err err);
      Abb.Future.return ()
  | Error (#Pgsql_io.err as err) ->
      Logs.err (fun m -> m "%s : DRAIN_UNIFIED_COMMENT : %a" request_id Pgsql_io.pp_err err);
      Abb.Future.return ()

let drain_pull_request ~request_id ~fetch_brand config storage ~repository ~pull_number =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.fetch
        db
        Sql.select_unified_comment_latest_work_manifest
        ~f:CCFun.id
        (CCInt64.of_int repository)
        (CCInt64.of_int pull_number))
  >>= function
  | Ok [] -> Abb.Future.return ()
  | Ok (work_manifest_id :: _) -> drain ~request_id ~fetch_brand config storage work_manifest_id
  | Error (#Pgsql_pool.err as err) ->
      Logs.err (fun m -> m "%s : DRAIN_UNIFIED_COMMENT : %a" request_id Pgsql_pool.pp_err err);
      Abb.Future.return ()
  | Error (#Pgsql_io.err as err) ->
      Logs.err (fun m -> m "%s : DRAIN_UNIFIED_COMMENT : %a" request_id Pgsql_io.pp_err err);
      Abb.Future.return ()
