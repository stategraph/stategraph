module Attached_files_entry : sig
  type t = {
    address_glob : string;
    globs : string list;
    dest : string option;
    recursive : bool;
        (** [globs] are plain paths rather than globs. Absent in plan files written before
            [--recursive] existed, where it defaults to [false]. *)
    expr : string option;
        (** The exact HCL expression this attachment is for, as source text. Absent in plan files
            written before [--expr] existed, where it defaults to [None]. *)
  }
  [@@deriving yojson]
end

module Dir_entry : sig
  type t = {
    workspace : string;
    tfvars : string Sln_map.String.t;  (** Tfvars that count toward the plan's revision hash. *)
    ephemeral_tfvars : string Sln_map.String.t;
        (** Ephemeral tfvars (RFD 1377): collected and recorded so apply can evaluate the
            configuration exactly as plan did, but deliberately kept apart from {!tfvars} because
            they contribute no revision node. Apply must union both into its evaluation variables
            and take its revision nodes from {!tfvars} alone. Absent in plan files written before
            this existed, where it defaults to empty. *)
    attached_files : Attached_files_entry.t list;
  }
  [@@deriving yojson]

  val make :
    workspace:string ->
    ?attached_files:Attached_files_entry.t list ->
    ?tfvars:string Sln_map.String.t ->
    ?ephemeral_tfvars:string Sln_map.String.t ->
    unit ->
    t

  val workspace : t -> string
  val tfvars : t -> string Sln_map.String.t
  val ephemeral_tfvars : t -> string Sln_map.String.t
  val attached_files : t -> Attached_files_entry.t list
end

type of_yojson_err = [ `Sg_plan_file_of_yojson_err of string ] [@@deriving show]
type t

val make :
  tx_id:Uuidm.t ->
  task_id:Uuidm.t ->
  revision_hash:string ->
  dirs:(string * Dir_entry.t) list ->
  unit ->
  t

(** The plan of a run that opened no transaction: the configuration had not moved and there was
    nothing to refresh, so no preview ran and there is nothing on the server to commit. {!tx_id} and
    {!task_id} are [None], which is what tells apply to report a successful noop without a round
    trip. [revision_hash] and [dirs] are recorded as they are for any other plan, so apply still
    refuses the file once the configuration has moved on. *)
val make_noop : revision_hash:string -> dirs:(string * Dir_entry.t) list -> unit -> t

(** [None] for a plan built by {!make_noop}; see there. *)
val tx_id : t -> Uuidm.t option

(** [None] for a plan built by {!make_noop}; see there. *)
val task_id : t -> Uuidm.t option

val revision_hash : t -> string option
val dirs : t -> (string * Dir_entry.t) list
val to_yojson : t -> Yojson.Safe.t
val of_yojson : Yojson.Safe.t -> (t, [> of_yojson_err ]) result
