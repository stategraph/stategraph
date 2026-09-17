type t =
  | Stategraph
  | Terrateam
[@@deriving eq, show]

(** Every brand, in the order the server examines them. *)
val all : t list

val of_string : string -> t option
val to_string : t -> string

(** The brand of a repository name, whatever its case. *)
val of_repo_name : string -> t option

(** The repository configuration directory of a brand: [".stategraph"] or [".terrateam"]. *)
val directory : t -> string

(** The value of TERRAT_BRAND. [Error] names a value that is not a brand. *)
val of_env : unit -> (t option, string) result

(** TERRAT_BRAND, or [Stategraph] when it is unset. Raises [Failure] on a value that is not a brand,
    which [Terrat_config.create] rejects at boot. *)
val fallback : unit -> t

(** The brand of a repository, from the first argument that is [Some]:
    - [forced_config]: the name of the centralized repository that holds a forced config for the
      repository.
    - [repo_config]: the directory of the configuration file on the default branch.
    - [centralized]: the name of the selected centralized repository. *)
val resolve :
  forced_config:t option -> repo_config:t option -> centralized:t option -> fallback:t -> t

val to_terrateam : string -> string

(** [branded f s] prepares [f s] for every brand when it is called, and answers the prepared value
    of the brand it is given. *)
val branded : (string -> 'a) -> string -> t -> 'a
