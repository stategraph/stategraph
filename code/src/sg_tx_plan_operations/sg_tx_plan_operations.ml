type operation =
  | Create
  | Update
  | Replace
  | Destroy

let operation_to_string = function
  | Create -> "create"
  | Update -> "update"
  | Replace -> "replace"
  | Destroy -> "destroy"

(* Inverse of [operation_to_string]; every reader of the persisted strings goes
   through here. The CHECK constraint in migrations/2026-08-10-add-tx-detail.sql
   admits the same four strings, so [None] means the SQL is wrong, not the
   data. *)
let operation_of_string = function
  | "create" -> Some Create
  | "update" -> Some Update
  | "replace" -> Some Replace
  | "destroy" -> Some Destroy
  | _ -> None

(* Terraform's action arrays: ["create"], ["update"], ["delete"],
   ["create";"delete"] (or reversed) for replace. ["no-op"], ["read"] and
   anything unrecognized (a non-string element included) are excluded, matching
   terraform's own tally. *)
let operation_of_actions actions =
  let action_string = function
    | `String s -> Some s
    | `Assoc _ | `Bool _ | `Float _ | `Int _ | `Intlit _ | `List _ | `Null | `Tuple _ | `Variant _
      -> None
  in
  match CCOption.sequence_l (CCList.map action_string actions) with
  | Some [ "create" ] -> Some Create
  | Some [ "update" ] -> Some Update
  | Some [ "delete" ] -> Some Destroy
  | Some [ "create"; "delete" ] | Some [ "delete"; "create" ] -> Some Replace
  | Some _ | None -> None

let of_plan_json plan_json =
  let assoc k = function
    | `Assoc fields -> CCList.assoc_opt ~eq:CCString.equal k fields
    | _ -> None
  in
  match assoc "resource_changes" plan_json with
  | Some (`List entries) ->
      CCList.filter_map
        (fun entry ->
          match (assoc "mode" entry, assoc "address" entry, assoc "change" entry) with
          | Some (`String "managed"), Some (`String address), Some change -> (
              match assoc "actions" change with
              | Some (`List actions) ->
                  CCOption.map (fun op -> (address, op)) (operation_of_actions actions)
              | Some _ | None -> None)
          | _ -> None)
        entries
  | Some _ | None -> []
