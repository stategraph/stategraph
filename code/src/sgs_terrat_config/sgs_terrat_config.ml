let default_db_name = "terrateam"
let default_python_exec = "/usr/bin/python3"

let ui_base getenv =
  match CCOption.map (CCString.rdrop_while (Char.equal '/')) (getenv "STATEGRAPH_UI_BASE") with
  | None | Some "" -> None
  | Some _ as base -> base

(* The value of [key], else [STATEGRAPH_UI_BASE] followed by [suffix]. *)
let derive_from_ui_base ~suffix getenv key =
  match getenv key with
  | Some value when not (CCString.is_empty value) -> Some value
  | value -> CCOption.map_or ~default:value (fun base -> Some (base ^ suffix)) (ui_base getenv)

(* An empty database name is no database, otherwise Postgres would connect to the database named after the
   user, which can be the Stategraph one. *)
let db_name getenv =
  match getenv "TERRAT_DB_NAME" with
  | Some name when not (CCString.is_empty name) -> name
  | Some _ | None -> default_db_name

let terrat_getenv getenv = function
  | "DB_NAME" -> Some (db_name getenv)
  | ("DB_HOST" | "DB_PORT" | "DB_USER" | "DB_PASS") as key ->
      CCOption.or_lazy ~else_:(fun () -> getenv key) (getenv ("TERRAT_" ^ key))
  | "TERRAT_API_BASE" as key -> derive_from_ui_base ~suffix:"/api" getenv key
  | "TERRAT_UI_BASE" as key -> derive_from_ui_base ~suffix:"" getenv key
  | "TERRAT_PYTHON_EXEC" as key -> Some (CCOption.get_or ~default:default_python_exec (getenv key))
  | "GITHUB_APP_PEM" as key ->
      CCOption.map (CCString.replace ~which:`All ~sub:"\\n" ~by:"\n") (getenv key)
  | key -> getenv key

let of_env getenv = Terrat_config.of_env (terrat_getenv getenv)
let create () = of_env Sys.getenv_opt
