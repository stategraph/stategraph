let concat_many root segments = CCList.fold_left Filename.concat root segments

let normalize_path path =
  let is_abs = CCString.prefix ~pre:"/" path in
  let parts = CCString.split_on_char '/' path in
  let rec process_parts acc = function
    | [] -> CCList.rev acc
    | "." :: rest | "" :: rest -> process_parts acc rest
    | ".." :: rest -> (
        match acc with
        | ".." :: _ -> process_parts (".." :: acc) rest
        | _ :: prev_acc -> process_parts prev_acc rest
        | [] -> if is_abs then process_parts [] rest else process_parts (".." :: acc) rest)
    | part :: rest -> process_parts (part :: acc) rest
  in
  let processed = process_parts [] parts in
  let res = CCString.concat "/" processed in
  if is_abs then "/" ^ res else if res = "" then "." else res

let has_no_parent_escape path =
  let n = normalize_path path in
  Filename.is_relative n && n <> ".." && not (CCString.prefix ~pre:"../" n)

(* Split a normalized non-absolute path into segments. [.] becomes the empty list so both
   [relpath ~from:"." ~to_:"a/b"] and [relpath ~from:"a/b" ~to_:"a/b"] work without special cases. *)
let segments_of_normalized n = if n = "." then [] else CCString.split_on_char '/' n

let relpath ~from ~to_ =
  let nfrom = normalize_path from in
  let nto = normalize_path to_ in
  assert (Filename.is_relative nfrom && Filename.is_relative nto);
  let from_segs = segments_of_normalized nfrom in
  let to_segs = segments_of_normalized nto in
  let rec drop_common a b =
    match (a, b) with
    | ah :: at, bh :: bt when ah = bh -> drop_common at bt
    | _ -> (a, b)
  in
  let from_rem, to_rem = drop_common from_segs to_segs in
  let ups = CCList.map (fun _ -> "..") from_rem in
  let segments = ups @ to_rem in
  match segments with
  | [] -> "."
  | _ -> CCString.concat "/" segments

let classify_path ~scope filepath =
  let normalized = normalize_path filepath in
  let scope_rel =
    CCOption.flat_map
      (fun src ->
        let src_norm = normalize_path src in
        if src_norm = "." then
          if Filename.is_relative normalized && has_no_parent_escape normalized then Some normalized
          else None
        else if normalized = src_norm then Some ""
        else if
          CCString.prefix ~pre:(src_norm ^ "/") normalized
          && CCString.length normalized > CCString.length src_norm + 1
        then Some (CCString.drop (CCString.length src_norm + 1) normalized)
        else None)
      scope
  in
  match scope_rel with
  | Some rel -> `In_scope rel
  | None ->
      if has_no_parent_escape filepath then `In_tree (if normalized = "." then "" else normalized)
      else `Outside

let rec mkdir_p path =
  if CCString.equal path "/" || CCString.equal path "." || CCString.equal path "" then ()
  else if Sys.file_exists path then ()
  else (
    mkdir_p (Filename.dirname path);
    (* An already-created directory is not an error: concurrent callers building overlapping trees
       would otherwise race between the [file_exists] test above and this [mkdir]. *)
    try Sys.mkdir path 0o755 with Sys_error _ -> ())

let write_file ~dir ~filepath content =
  let full = Filename.concat dir filepath in
  mkdir_p (Filename.dirname full);
  CCIO.with_out full (fun oc -> output_string oc content)

(* Permission bits only.  The set-user-ID, set-group-ID and sticky bits are deliberately dropped:
   they are recorded nowhere that reads this and restaging one would grant a privilege the source
   tree's owner never asked us to reproduce. *)
let perm_mask = 0o777

let mode_of_path ~default path =
  try (Unix.stat path).Unix.st_perm land perm_mask with Unix.Unix_error _ -> default

type chmod_err = [ `Chmod_err of string * string ] [@@deriving show]

let chmod path mode =
  try Ok (Unix.chmod path (mode land perm_mask))
  with Unix.Unix_error (err, _, _) -> Error (`Chmod_err (path, Unix.error_message err))
