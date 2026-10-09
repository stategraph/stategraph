type t = {
  checks : Terrat_repo_config_apply_requirements_checks.t option; [@default None]
  create_completed_apply_check_on_noop : bool; [@default true]
  create_pending_apply_check : bool; [@default true]
}
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
