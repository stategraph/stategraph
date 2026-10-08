module File_read_hint = Sgs_tx_log_hints_file_read_hint
module For_each_body_ref_hint = Sgs_tx_log_hints_for_each_body_ref_hint
module For_each_file_calls = Sgs_tx_log_hints_for_each_file_calls
module For_each_ref_hint = Sgs_tx_log_hints_for_each_ref_hint
module Hints = Sgs_tx_log_hints_hints
module Module_index_read_hint = Sgs_tx_log_hints_module_index_read_hint
module Object_attr_ref_hint = Sgs_tx_log_hints_object_attr_ref_hint
module Path_attr_hint = Sgs_tx_log_hints_path_attr_hint
module Realized_object_input = Sgs_tx_log_hints_realized_object_input
module Stored_for_each_body_ref = Sgs_tx_log_hints_stored_for_each_body_ref
module Stored_for_each_hint = Sgs_tx_log_hints_stored_for_each_hint
module Stored_for_each_ref = Sgs_tx_log_hints_stored_for_each_ref
module Stored_hints = Sgs_tx_log_hints_stored_hints
module Stored_object_attr_ref = Sgs_tx_log_hints_stored_object_attr_ref
module Stored_realized_object_hint = Sgs_tx_log_hints_stored_realized_object_hint

module Event = struct
  type t = Hints of Sgs_tx_log_hints_hints.t [@@deriving show, eq]

  let of_yojson =
    Json_schema.one_of
      (let open CCResult in
       [ (fun v -> map (fun v -> Hints v) (Sgs_tx_log_hints_hints.of_yojson v)) ])

  let to_yojson = function
    | Hints v -> Sgs_tx_log_hints_hints.to_yojson v
end
