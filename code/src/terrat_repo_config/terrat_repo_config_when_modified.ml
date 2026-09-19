module File_patterns = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Prechecks = struct
  type t = Terrat_repo_config_precheck.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  autoapply : bool; [@default false]
  autoplan : bool; [@default true]
  autoplan_draft_pr : bool; [@default true]
  depends_on : Terrat_repo_config_depends_on.t option; [@default None]
  file_patterns : File_patterns.t; [@default [ "**/*.tf"; "**/*.tfvars" ]]
  prechecks : Prechecks.t; [@default []]
}
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
