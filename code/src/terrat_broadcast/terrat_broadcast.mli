(** Operator notices shown in plan and apply comments while [now () < ends_at]. *)

module Level : sig
  type t =
    | Info
    | Warning
    | Critical
  [@@deriving eq, show]

  val of_string : string -> t option

  (** The GitHub and GitLab alert type: [NOTE], [WARNING] or [CAUTION]. *)
  val alert : t -> string
end

type t = {
  level : Level.t;
  message : string;  (** Markdown. *)
}
[@@deriving eq, show]

(** Template input: a list of [{ "alert": <alert type>, "lines": [<message line>, ...] }]. *)
val to_kv : t list -> Yojson.Safe.t

(** Active broadcasts for [vcs] and for every VCS, oldest first. A row with an unknown level is
    dropped. *)
val active :
  request_id:string ->
  vcs:[ `Github | `Gitlab ] ->
  Pgsql_io.t ->
  (t list, [> `Error ]) result Abb.Future.t
