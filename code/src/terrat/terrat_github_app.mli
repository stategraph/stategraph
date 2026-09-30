(** The GitHub App stored in the orchestration database: one row, written by the console through the
    admin FDW channel. The environment wins over it, see [Terrat_cli]. *)

type err =
  [ Pgsql_pool.err
  | Pgsql_io.err
  | `Key_error of string
  | `Bad_pem of string
  ]
[@@deriving show]

(** The stored App, or [None] when no row exists. *)
val load : Terrat_storage.t -> (Terrat_config.Github.t option, [> err ]) result Abb.Future.t

(** Records that a server process has started with the stored App, which the console reports as
    ready. *)
val mark_loaded : Terrat_storage.t -> (unit, [> err ]) result Abb.Future.t

(** Polls for a row and exits the process with status 0 when one appears, so the supervisor starts
    it again and the new process loads the App. Polls every few seconds while the console may be
    waiting, then once a minute. Never returns. *)
val exit_when_created : ?waited:float -> Terrat_storage.t -> unit Abb.Future.t
