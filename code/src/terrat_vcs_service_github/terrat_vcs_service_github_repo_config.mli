(** Reads a repository configuration file out of a directory that holds [<basename>.yml] or
    [<basename>.yaml].

    Both the repository itself and the centralized configuration repository read files of that
    shape, so both go through this module: the empty file rule, the [.yml] before [.yaml] rule and
    the name that a YAML error carries live here one time. *)

(** The file that a listed directory offers: where it is, and how big it is. A size of zero means
    the file holds no configuration, which the read can then skip. *)
module Candidate : sig
  type t = {
    path : string;
    size : int;
  }
  [@@deriving show, eq]
end

(** What one configuration load learned about the directories it reads. *)
type listings

(** List each directory one time, all of them together. A directory that does not exist holds no
    candidates. A directory that the contents endpoint refuses to list is remembered as such, and
    {!fetch_config} reads its names directly instead. *)
val list_directories :
  request_id:string ->
  Terrat_vcs_api_github.Client.t ->
  Terrat_vcs_api_github.Repo.t ->
  Terrat_vcs_api_github.Ref.t ->
  string list ->
  (listings, [> Terrat_vcs_api.call_err ]) result Abb.Future.t

(** Read [<directory>/<basename>.yml], or [<directory>/<basename>.yaml] when the [.yml] name is
    absent. A file that holds nothing but whitespace reads as no configuration, and does not fall
    back to the other extension. The answer carries the name [<repo>:<ref>:<path>], which is what a
    YAML error reports.

    A [directory] that {!list_directories} did not read is read directly. *)
val fetch_config :
  request_id:string ->
  Terrat_vcs_api_github.Client.t ->
  Terrat_vcs_api_github.Repo.t ->
  Terrat_vcs_api_github.Ref.t ->
  listings ->
  directory:string ->
  basename:string ->
  ( (string * Yojson.Safe.t) option,
    [> Terrat_vcs_api.call_err | `Yaml_decode_err of string * string ] )
  result
  Abb.Future.t

(** The path of the file that {!fetch_config} reads, without reading its YAML. *)
val fetch_config_path :
  request_id:string ->
  Terrat_vcs_api_github.Client.t ->
  Terrat_vcs_api_github.Repo.t ->
  Terrat_vcs_api_github.Ref.t ->
  listings ->
  directory:string ->
  basename:string ->
  (string option, [> Terrat_vcs_api.call_err ]) result Abb.Future.t

(** Read the configuration of a repository. Config parity (#1442): [.stategraph/config] wins when
    both exist; [.terrateam/config] keeps working so existing repos need no rename. *)
val fetch :
  request_id:string ->
  Terrat_vcs_api_github.Client.t ->
  Terrat_vcs_api_github.Repo.t ->
  Terrat_vcs_api_github.Ref.t ->
  ( (string * Yojson.Safe.t) option,
    [> Terrat_vcs_api.call_err | `Yaml_decode_err of string * string ] )
  result
  Abb.Future.t

(** The brand of the directory that holds the configuration file {!fetch} reads, without reading its
    YAML. *)
val fetch_config_brand :
  request_id:string ->
  Terrat_vcs_api_github.Client.t ->
  Terrat_vcs_api_github.Repo.t ->
  Terrat_vcs_api_github.Ref.t ->
  (Terrat_brand.t option, [> Terrat_vcs_api.call_err ]) result Abb.Future.t

module Tests : sig
  (** Choose [<basename>.yml] before [<basename>.yaml] among the entries of one listed directory.
      Only a file counts: a directory, a symlink or a submodule of that name is not a candidate. *)
  val find_candidate :
    Terrat_vcs_api_github.Directory_entry.t list ->
    directory:string ->
    basename:string ->
    Candidate.t option
end
