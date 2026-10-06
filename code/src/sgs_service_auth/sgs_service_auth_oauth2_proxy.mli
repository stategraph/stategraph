(** OAuth2 Proxy Process Management

    This module handles spawning and managing the oauth2-proxy process for OAuth authentication.
    Process management uses Abb.Process for proper async integration with the scheduler. *)

(** The handle to a running oauth2-proxy process *)
type t

(** Errors that can occur when spawning oauth2-proxy *)
type spawn_err =
  [ `Spawn_failed of string
  | `No_oauth_config
  | Abb_intf.Errors.spawn
  ]

val pp_spawn_err : Format.formatter -> spawn_err -> unit
val show_spawn_err : spawn_err -> string

(** Spawn oauth2-proxy based on the configuration. Must be called within the Abb scheduler context.
    Returns [Error `No_oauth_config] if OAuth is not configured. Returns [Error (`Spawn_failed msg)]
    if the process fails to start. *)
val spawn : Sgs_config.t -> (t, spawn_err) result Abb.Future.t

(** Stop oauth2-proxy gracefully. Sends SIGTERM, waits briefly, then SIGKILL if still running.
    Returns a future that completes when the process has exited. *)
val stop : t -> unit Abb.Future.t

(** Get the port oauth2-proxy is listening on *)
val port : t -> int

(** Test-only: steps of {!spawn} that the unit tests exercise directly. *)
module Tests : sig
  (** Mask the value of a secret-bearing oauth2-proxy flag (["--client-secret=x"] becomes
      ["--client-secret=<redacted>"]), leaving every other argument untouched. The full argv is
      logged at debug to make misconfiguration diagnosable, which must not print credentials into
      the operator's logs. *)
  val redact_arg : string -> string

  (** Resolve a [STATEGRAPH_OAUTH_GOOGLE_SERVICE_ACCOUNT_JSON] value into a path for oauth2-proxy's
      [--google-service-account-json], which accepts only a path. A value whose first non-whitespace
      character is ['{'] is inline JSON: it is written to a [0600] file and reported [`Owned], so
      [stop] removes it. Anything else is already a path and is passed through as
      [`Operator_supplied], never removed. *)
  val materialize_service_account_json :
    string -> (string * [ `Owned | `Operator_supplied ], [> `Spawn_failed of string ]) result
end
