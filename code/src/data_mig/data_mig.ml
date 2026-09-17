module Error = struct
  module Consistency = struct
    type t = {
      idx : int;
      last_common : string option;
      applied : string option;
      expected : string option;
    }
    [@@deriving show]

    let to_string { idx; last_common; applied; expected } =
      let name = CCOption.get_or ~default:"<none>" in
      Printf.sprintf
        "diverged after %d migration(s) (last in common: %s): database has %s, expected %s"
        idx
        (name last_common)
        (name applied)
        (name expected)
  end

  type 'a t =
    [ `Migration_err of 'a
    | `Consistency_err of Consistency.t
    ]
end

module type S = sig
  type tx
  type 'a t
  type err

  val tx :
    'a t -> (tx t -> ('r, err Error.t) result Abb.Future.t) -> ('r, err Error.t) result Abb.Future.t

  val start_migration : tx t -> string -> unit Abb.Future.t
  val complete_migration : 'a t -> string -> unit Abb.Future.t
  val list_migrations : 'a t -> string list -> unit Abb.Future.t
  val get_migrations : tx t -> (string list, err) result Abb.Future.t
  val add_migration : tx t -> string -> (unit, err) result Abb.Future.t
end

module Make (M : S) = struct
  type err = M.err Error.t

  module Migration = struct
    type 'a t =
      M.tx M.t ->
      ([ `Sync | `Async of 'a M.t -> (unit, M.err) result Abb.Future.t ], M.err) result Abb.Future.t
  end

  let run_migration m mt =
    let open Abb.Future.Infix_monad in
    m mt
    >>| function
    | Ok r -> Ok r
    | Error err -> Error (`Migration_err err)

  let get_migrations mt =
    let open Abb.Future.Infix_monad in
    M.get_migrations mt
    >>| function
    | Ok ms -> Ok ms
    | Error err -> Error (`Migration_err err)

  let add_migration mt name =
    let open Abb.Future.Infix_monad in
    M.add_migration mt name
    >>| function
    | Ok () -> Ok ()
    | Error err -> Error (`Migration_err err)

  let start_migration mt name =
    let open Abb.Future.Infix_monad in
    M.start_migration mt name >>= fun () -> Abbs_future_combinators.return_ok ()

  let complete_migration mt name =
    let open Abb.Future.Infix_monad in
    M.complete_migration mt name >>= fun () -> Abbs_future_combinators.return_ok ()

  let exec mt (name, m) =
    let open Abbs_future_combinators.Infix_result_monad in
    start_migration mt name
    >>= fun () ->
    run_migration m mt
    >>= fun r -> add_migration mt name >>= fun () -> complete_migration mt name >>| fun () -> r

  (* The migrations recorded in the database must be a prefix of the migration
     list.  On a mismatch, report where the two diverge so the operator can see
     which migration the database stopped agreeing at. *)
  let rec verify_consistency ~idx ~last_common migrations ms =
    match (migrations, ms) with
    | [], ms -> Ok ms
    | mig :: migs, (m, _) :: ms when m = mig ->
        verify_consistency ~idx:(idx + 1) ~last_common:(Some mig) migs ms
    | mig :: _, ms ->
        Error
          {
            Error.Consistency.idx;
            last_common;
            applied = Some mig;
            expected = CCOption.map fst (CCList.head_opt ms);
          }

  (* Do each migration one at a time inside a transaction, committing the
     transaction between steps.  This is so that, in the case of a database, we
     don't build up a massive transaction.  It also means, in the case of a
     database which has concurrent processes performing migrations, each
     migration step will be serialized but it might bounce around between
     processes.  That's OK. *)
  let rec run' mt ms =
    let open Abbs_future_combinators.Infix_result_monad in
    M.tx mt (fun tx ->
        get_migrations tx
        >>= function
        | migrations -> (
            match verify_consistency ~idx:0 ~last_common:None migrations ms with
            | Ok [] -> Abbs_future_combinators.return_ok `Done
            | Ok (migration :: _) ->
                let open Abb.Future.Infix_monad in
                M.list_migrations tx [ fst migration ]
                >>= fun () ->
                let open Abbs_future_combinators.Infix_result_monad in
                exec tx migration >>| fun r -> `Cont r
            | Error consistency -> Abbs_future_combinators.return_err (`Consistency_err consistency)
            ))
    >>= function
    | `Done -> Abbs_future_combinators.return_ok ()
    | `Cont `Sync -> run' mt ms
    | `Cont (`Async mig) -> run_migration mig mt >>= fun () -> run' mt ms

  let run mt ms =
    (run' mt ms : (unit, err) result Abb.Future.t :> (unit, [> err ]) result Abb.Future.t)
end
