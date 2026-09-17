(** Reads a repository configuration file named [<basename>.yml] or [<basename>.yaml].

    Both the repository itself and the centralized configuration repository read files of that
    shape, so both go through this module. *)

(** Read [<basename>.yml], or [<basename>.yaml] when the [.yml] name is absent. A file that holds
    nothing but whitespace reads as no configuration, and does not fall back to the other extension.
    The answer carries the name [<repo>:<ref>:<path>], which is what a YAML error reports. *)
val fetch_config :
  request_id:string ->
  Terrat_vcs_api_gitlab.Client.t ->
  Terrat_vcs_api_gitlab.Repo.t ->
  Terrat_vcs_api_gitlab.Ref.t ->
  string ->
  ( (string * Yojson.Safe.t) option,
    [> Terrat_vcs_api.call_err | `Yaml_decode_err of string * string ] )
  result
  Abb.Future.t

(** The path of the file that {!fetch_config} reads, without reading its YAML. *)
val fetch_config_path :
  request_id:string ->
  Terrat_vcs_api_gitlab.Client.t ->
  Terrat_vcs_api_gitlab.Repo.t ->
  Terrat_vcs_api_gitlab.Ref.t ->
  string ->
  (string option, [> Terrat_vcs_api.call_err ]) result Abb.Future.t

(** Read the configuration of a repository. Config parity (#1442): [.stategraph/config] wins when
    both exist; [.terrateam/config] keeps working so existing repos need no rename. *)
val fetch :
  request_id:string ->
  Terrat_vcs_api_gitlab.Client.t ->
  Terrat_vcs_api_gitlab.Repo.t ->
  Terrat_vcs_api_gitlab.Ref.t ->
  ( (string * Yojson.Safe.t) option,
    [> Terrat_vcs_api.call_err | `Yaml_decode_err of string * string ] )
  result
  Abb.Future.t

(** The brand of the directory that holds the configuration file {!fetch} reads, without reading its
    YAML. *)
val fetch_config_brand :
  request_id:string ->
  Terrat_vcs_api_gitlab.Client.t ->
  Terrat_vcs_api_gitlab.Repo.t ->
  Terrat_vcs_api_gitlab.Ref.t ->
  (Terrat_brand.t option, [> Terrat_vcs_api.call_err ]) result Abb.Future.t
