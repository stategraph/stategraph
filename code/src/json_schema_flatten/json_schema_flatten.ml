(* All the state accumulated while flattening, threaded immutably through the recursion (no mutable
   structures).  [visited] is a [file -> fragment -> canonical name] nesting, since [Sln_map] is
   string-keyed. *)
type state = {
  defs : Yojson.Safe.t Sln_map.String.t;
      (* newly-inlined foreign definitions, keyed by canonical name *)
  visited : string Sln_map.String.t Sln_map.String.t;
      (* (file, fragment) -> canonical name, for dedup and cycle breaking *)
  used_canon : Sln_set.String.t; (* canonical names already in use, to avoid collisions *)
  file_cache : Yojson.Safe.t Sln_map.String.t; (* parsed foreign files, keyed by resolved path *)
}

(* [visited] lookup/insert for a [(file, fragment)] pair over the nested map. *)
let visited_get ~file ~frag visited =
  CCOption.flat_map (Sln_map.String.get frag) (Sln_map.String.get file visited)

let visited_add ~file ~frag canon visited =
  let inner = CCOption.get_or ~default:Sln_map.String.empty (Sln_map.String.get file visited) in
  Sln_map.String.add file (Sln_map.String.add frag canon inner) visited

let flatten_document ~search_path ~file_link ~root_file json =
  let file_link_by_base =
    CCList.map (fun (file, module_base) -> (Filename.basename file, module_base)) file_link
  in
  let file_link_of path =
    match Sln_list.String.assoc_opt path file_link with
    | Some _ as module_base -> module_base
    | None -> Sln_list.String.assoc_opt (Filename.basename path) file_link_by_base
  in
  let root_dir = Filename.dirname root_file in
  let load_json state file =
    match Sln_map.String.get file state.file_cache with
    | Some j -> (j, state)
    | None ->
        let j = Yojson.Safe.from_file file in
        (j, { state with file_cache = Sln_map.String.add file j state.file_cache })
  in
  let resolve_file ~base_dir path =
    if Filename.is_relative path then
      let candidates =
        Filename.concat base_dir path :: CCList.map (fun d -> Filename.concat d path) search_path
      in
      match CCList.find_opt Sys.file_exists candidates with
      | Some f -> f
      | None ->
          failwith
            (Printf.sprintf
               "Could not find foreign schema file %S; searched: %s"
               path
               (CCString.concat ", " candidates))
    else if Sys.file_exists path then path
    else failwith (Printf.sprintf "Could not find foreign schema file %S" path)
  in
  let sanitize s =
    CCString.map
      (fun c -> if CCChar.is_letter_ascii c || CCChar.is_digit_ascii c || c = '_' then c else '_')
      (CCString.lowercase_ascii s)
  in
  (* Collision-free [definitions] key for a foreign definition, namespaced by file stem. *)
  let fresh_canonical state file name =
    let stem = sanitize (Filename.remove_extension (Filename.basename file)) in
    let base = stem ^ "_" ^ sanitize name in
    let rec uniq i =
      let cand = if i = 0 then base else Printf.sprintf "%s_%d" base i in
      if Sln_set.String.mem cand state.used_canon then uniq (i + 1) else cand
    in
    let c = uniq 0 in
    (c, { state with used_canon = Sln_set.String.add c state.used_canon })
  in
  (* Split "<path>#<fragment>" into (path, "#<fragment>").  Internal refs have an empty path. *)
  let split_ref ref_ =
    match CCString.Split.left ~by:"#" ref_ with
    | Some (path, frag) -> (path, "#" ^ frag)
    | None -> (ref_, "")
  in
  (* The keys from the root of a document to a definition, for the pointers that refs may use. *)
  let keys_of_fragment frag ref_ =
    match CCString.split_on_char '/' frag with
    | [ "#"; "definitions"; n ] -> ([ "definitions"; n ], n)
    | [ "#"; "components"; "schemas"; n ] -> ([ "components"; "schemas"; n ], n)
    | _ ->
        failwith
          (Printf.sprintf
             "Unsupported foreign ref %S: only #/definitions/<Name> and \
              #/components/schemas/<Name> are supported"
             ref_)
  in
  let rec lookup json = function
    | [] -> Some json
    | k :: ks -> (
        match json with
        | `Assoc kvs -> CCOption.flat_map (fun j -> lookup j ks) (Sln_list.String.assoc_opt k kvs)
        | _ -> None)
  in
  (* [current_file] is the foreign file that holds the ref, or [None] in the root document. *)
  let rec rewrite_ref_string state ~current_file ref_ =
    let path, frag = split_ref ref_ in
    match (path, current_file) with
    | "", None -> (ref_, state) (* internal ref of the root document, unchanged *)
    | "", Some file -> inline_ref state ~file ~frag ref_
    | path, _ -> (
        match file_link_of path with
        | Some module_base ->
            let _, name = keys_of_fragment frag ref_ in
            (Printf.sprintf "#/file-link/%s/%s" module_base name, state)
        | None ->
            let base_dir = CCOption.map_or ~default:root_dir Filename.dirname current_file in
            inline_ref state ~file:(resolve_file ~base_dir path) ~frag ref_)
  and inline_ref state ~file ~frag ref_ =
    let keys, name = keys_of_fragment frag ref_ in
    let canon, state =
      match visited_get ~file ~frag state.visited with
      | Some c -> (c, state)
      | None ->
          let c, state = fresh_canonical state file name in
          (* Reserve before recursing so cyclic refs terminate. *)
          let state = { state with visited = visited_add ~file ~frag c state.visited } in
          let json, state = load_json state file in
          let def_json =
            match lookup json keys with
            | Some d -> d
            | None -> failwith (Printf.sprintf "Definition %s not found in %s" frag file)
          in
          let def_json, state = rewrite state ~current_file:(Some file) def_json in
          (c, { state with defs = Sln_map.String.add c def_json state.defs })
    in
    ("#/definitions/" ^ canon, state)
  and rewrite state ~current_file json =
    match json with
    | `Assoc [ ("$ref", `String ref_) ] ->
        let ref_, state = rewrite_ref_string state ~current_file ref_ in
        (`Assoc [ ("$ref", `String ref_) ], state)
    | `Assoc kvs ->
        let state, kvs =
          CCList.fold_map
            (fun state (k, v) ->
              let v, state = rewrite state ~current_file v in
              (state, (k, v)))
            state
            kvs
        in
        (`Assoc kvs, state)
    | `List xs ->
        let state, xs =
          CCList.fold_map
            (fun state x ->
              let x, state = rewrite state ~current_file x in
              (state, x))
            state
            xs
        in
        (`List xs, state)
    | x -> (x, state)
  in
  (* Seed the in-use canonical names with the root document's existing definition names. *)
  let used_canon =
    match Yojson.Safe.Util.member "definitions" json with
    | `Assoc kvs ->
        CCList.fold_left (fun acc (k, _) -> Sln_set.String.add k acc) Sln_set.String.empty kvs
    | _ -> Sln_set.String.empty
  in
  let state =
    {
      defs = Sln_map.String.empty;
      visited = Sln_map.String.empty;
      used_canon;
      file_cache = Sln_map.String.empty;
    }
  in
  let rewritten, state = rewrite state ~current_file:None json in
  (* Handle a document-level "$ref" entrypoint (a sibling of "definitions"), which is a plain string
     field rather than a sole-key {"$ref": ...} object. *)
  let rewritten, state =
    match rewritten with
    | `Assoc kvs ->
        let state, kvs =
          CCList.fold_map
            (fun state (k, v) ->
              match (k, v) with
              | "$ref", `String ref_ ->
                  let ref_, state = rewrite_ref_string state ~current_file:None ref_ in
                  (state, (k, `String ref_))
              | _ -> (state, (k, v)))
            state
            kvs
        in
        (`Assoc kvs, state)
    | x -> (x, state)
  in
  (* Merge the inlined foreign definitions into the document's [definitions]. *)
  match rewritten with
  | `Assoc kvs ->
      let existing_defs =
        match Sln_list.String.assoc_opt "definitions" kvs with
        | Some (`Assoc d) -> d
        | _ -> []
      in
      let new_defs = Sln_map.String.fold (fun k v acc -> (k, v) :: acc) state.defs [] in
      `Assoc
        (("definitions", `Assoc (existing_defs @ new_defs))
        :: CCList.remove_assoc ~eq:CCString.equal "definitions" kvs)
  | x -> x
