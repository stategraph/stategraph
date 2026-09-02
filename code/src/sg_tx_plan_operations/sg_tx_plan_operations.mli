(** Per-resource plan operations extracted from a (demangled) Terraform/OpenTofu plan JSON
    ([terraform show -json] shape). Instance-level: [resource_changes] entries arrive with count /
    for_each already expanded, carrying terraform's own action set, so the derived operations — and
    any counts aggregated from them — match what the user saw on [plan]. Data sources (mode =
    "data") and no-op/read entries are excluded, matching terraform's own plan tally. *)

type operation =
  | Create
  | Update
  | Replace
  | Destroy

val operation_to_string : operation -> string

(** Inverse of {!operation_to_string}, for readers of the persisted strings. The
    [transaction_plan_operations] CHECK constraint admits the same four strings, so [None] on a
    persisted value is a defect in the SQL, not data. *)
val operation_of_string : string -> operation option

(** [(address, operation)] per changed resource instance. A plan JSON whose shape defeats the walk
    yields [[]] — callers treat persistence as best-effort. *)
val of_plan_json : Yojson.Safe.t -> (string * operation) list
