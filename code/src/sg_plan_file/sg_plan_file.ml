(* A [None] is written as a JSON null rather than by omitting the key, thus a plan file always
   states which of the two kinds it is. See {!make_noop} for the kind that has none. *)
let uuidm_opt_to_yojson = function
  | Some u -> `String (Uuidm.to_string u)
  | None -> `Null

let uuidm_opt_of_yojson = function
  | `String s -> (
      match Uuidm.of_string s with
      | Some u -> Ok (Some u)
      | None -> Error "Invalid UUID")
  | `Null -> Ok None
  | _ -> Error "Expected string or null"

module Attached_files_entry = struct
  type t = {
    address_glob : string;
    globs : string list;
    dest : string option; [@default None]
    recursive : bool; [@default false]
    expr : string option; [@default None]
        (* Carried so [apply] reads a plan's attachments exactly as [plan] wrote them. Defaulted so
           plan files written before [--recursive] / [--expr] existed still parse. *)
  }
  [@@deriving yojson]
end

module Dir_entry = struct
  type t = {
    workspace : string;
    tfvars : string Sln_map.String.t; [@default Sln_map.String.empty]
    ephemeral_tfvars : string Sln_map.String.t; [@default Sln_map.String.empty]
        (* Ephemeral tfvars (RFD 1377), kept in a compartment of their own rather than flagged
           inside [tfvars]. The split IS the invariant: everything in [tfvars] counts toward the
           revision hash, everything here does not. Apply needs both -- the values, so it evaluates
           the configuration exactly as plan did, and the separation, so it leaves these out of the
           hash it compares. Defaulted so plan files written before this existed still parse. *)
    attached_files : Attached_files_entry.t list; [@default []]
  }
  [@@deriving yojson]

  let make
      ~workspace
      ?(attached_files = [])
      ?(tfvars = Sln_map.String.empty)
      ?(ephemeral_tfvars = Sln_map.String.empty)
      () =
    { workspace; tfvars; ephemeral_tfvars; attached_files }

  let workspace t = t.workspace
  let tfvars t = t.tfvars
  let ephemeral_tfvars t = t.ephemeral_tfvars
  let attached_files t = t.attached_files
end

module Dir_binding = struct
  type t = {
    dir : string;
    entry : Dir_entry.t;
  }
  [@@deriving yojson]
end

type t = {
  tx_id : Uuidm.t option;
      [@default None] [@to_yojson uuidm_opt_to_yojson] [@of_yojson uuidm_opt_of_yojson]
  task_id : Uuidm.t option;
      [@default None] [@to_yojson uuidm_opt_to_yojson] [@of_yojson uuidm_opt_of_yojson]
  revision_hash : string option; [@default None]
  dirs : Dir_binding.t list; [@default []]
}
[@@deriving yojson]

let dir_bindings dirs = CCList.map (fun (dir, entry) -> { Dir_binding.dir; entry }) dirs

let make ~tx_id ~task_id ~revision_hash ~dirs () =
  {
    tx_id = Some tx_id;
    task_id = Some task_id;
    revision_hash = Some revision_hash;
    dirs = dir_bindings dirs;
  }

let make_noop ~revision_hash ~dirs () =
  { tx_id = None; task_id = None; revision_hash = Some revision_hash; dirs = dir_bindings dirs }

let tx_id t = t.tx_id
let task_id t = t.task_id
let revision_hash t = t.revision_hash
let dirs t = CCList.map (fun { Dir_binding.dir; entry } -> (dir, entry)) t.dirs

type of_yojson_err = [ `Sg_plan_file_of_yojson_err of string ] [@@deriving show]

let of_yojson json =
  match of_yojson json with
  | Ok _ as ok -> ok
  | Error msg -> Error (`Sg_plan_file_of_yojson_err msg)
