(** The Terrateam configuration of a Stategraph process. Stategraph and Terrateam both read [DB_*],
    for different databases, and some Terrateam values derive from Stategraph ones. This module
    gives {!Terrat_config} its own view of the environment:

    {v
      variable            value
      DB_NAME             TERRAT_DB_NAME, else "terrateam" (never DB_NAME)
      DB_HOST             TERRAT_DB_HOST, else DB_HOST
      DB_PORT             TERRAT_DB_PORT, else DB_PORT
      DB_USER             TERRAT_DB_USER, else DB_USER
      DB_PASS             TERRAT_DB_PASS, else DB_PASS
      TERRAT_API_BASE     TERRAT_API_BASE, else STATEGRAPH_UI_BASE ^ "/api"
      TERRAT_UI_BASE      TERRAT_UI_BASE, else STATEGRAPH_UI_BASE
      TERRAT_PYTHON_EXEC  TERRAT_PYTHON_EXEC, else "/usr/bin/python3"
      GITHUB_APP_PEM      GITHUB_APP_PEM, each "\n" escape replaced by a newline
      any other           the variable itself
    v}

    An empty TERRAT_DB_NAME, TERRAT_API_BASE or TERRAT_UI_BASE is unset. STATEGRAPH_UI_BASE loses
    its trailing slashes. *)

(** The configuration from the process environment. *)
val create : unit -> (Terrat_config.t, [> Terrat_config.err ]) result

(** The configuration from the environment that [getenv] reads. *)
val of_env : (string -> string option) -> (Terrat_config.t, [> Terrat_config.err ]) result
