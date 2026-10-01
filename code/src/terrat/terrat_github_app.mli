(** The GitHub App stored in the orchestration database: one row, written by the console through the
    admin FDW channel. The environment wins over it, see [Terrat_cli]. *)

type err =
  [ Pgsql_pool.err
  | Pgsql_io.err
  | `Key_error of string
  | `Bad_pem of string
  ]
[@@deriving show]

(** What a process compares the stored row against to decide it is running a stale App. It covers
    every credential column, so replacing the App and rotating its key both change it, and it
    excludes [loaded_at], so a process marking itself loaded cannot make itself stale. *)
type token [@@deriving eq]

(** What the database holds for this process. [Unusable] is a row the process cannot run, such as a
    key that does not decode: it carries the row's token so the process can wait for a correction
    rather than treat the row as newly created and restart on every poll. *)
type loaded =
  | No_app
  | App of Terrat_config.Github.t * token
  | Unusable of token * err

(** The stored App with the token of the row it came from. The token is taken from that same read,
    so a write that lands between the read and {!exit_when_changed} is not missed. *)
val load : Terrat_storage.t -> (loaded, [> err ]) result Abb.Future.t

(** Records that a server process has started with the App [token] names, which the console reports
    as ready. Bound to that App, so a replacement landing in between is not marked loaded by a
    process that does not run it. *)
val mark_loaded : token:token -> Terrat_storage.t -> (unit, [> err ]) result Abb.Future.t

(** [stale ~loaded stored] is why the process should restart, or [None] when the stored App is the
    one it runs. Exposed for tests. *)
val stale :
  loaded:token option -> token option -> [ `Created | `Removed | `Replaced | `Rotated ] option

(** Exposed for tests: a token from an App id and a credential digest, so the rule can be exercised
    without a database. *)
module Tests : sig
  val token : app_id:int64 -> string -> token
end

(** Polls for a stored App that is not [loaded] and exits the process with status 0 when it finds
    one, so the supervisor starts it again and the new process loads it. This covers a first App, a
    replacement, a rotated key and a deletion. Polls every few seconds while the console may be
    waiting, then once a minute, with jitter so replicas do not all exit together. Never returns. *)
val exit_when_changed :
  ?waited:float -> loaded:token option -> Terrat_storage.t -> unit Abb.Future.t
