type of_yaml_string_err = [ `Yaml_decode_err of string ] [@@deriving show]

type merge_err = [ `Type_mismatch_err of string option * Yojson.Safe.t * Yojson.Safe.t ]
[@@deriving show]

let to_yaml_string json =
  match Yaml_of_json.yaml_of_json @@ Yojson.Safe.to_string json with
  | Ok yaml -> yaml
  | Error _ -> assert false

let of_yaml_string yaml_str =
  match Json_of_yaml.json_of_yaml yaml_str with
  | Ok json_str -> Ok (Yojson.Safe.from_string json_str)
  | Error err -> Error (`Yaml_decode_err err)

let rec merge' ~null_is_identity ~list ~base override =
  match (base, override) with
  | `Bool _, (`Bool _ as v)
  | `Intlit _, (`Intlit _ as v)
  | `Int _, (`Int _ as v)
  | `Intlit _, (`Int _ as v)
  | `Int _, (`Intlit _ as v)
  | `Float _, (`Float _ as v)
  | `String _, (`String _ as v) -> Ok v
  | `List b, `List o -> (
      match list with
      | `Prepend -> Ok (`List (CCList.append o b))
      | `Append -> Ok (`List (CCList.append b o)))
  | (`Assoc b as base), `Assoc o ->
      let open CCResult.Infix in
      CCResult.fold_l
        (fun acc (k, v) ->
          match Yojson.Safe.Util.member k base with
          | `Null -> Ok ((k, v) :: acc)
          | v' -> (
              match merge' ~null_is_identity ~list ~base:v' v with
              | Ok v -> Ok ((k, v) :: acc)
              | Error (`Type_mismatch_err (None, b, o)) -> Error (`Type_mismatch_err (Some k, b, o))
              | Error (`Type_mismatch_err (Some p, b, o)) ->
                  Error (`Type_mismatch_err (Some (k ^ "." ^ p), b, o))))
        []
        o
      >>= fun override ->
      (* Add back any keys in base not in override *)
      let override =
        CCList.fold_left
          (fun acc (k, v) ->
            if not (CCList.Assoc.mem ~eq:CCString.equal k override) then (k, v) :: acc else acc)
          override
          b
      in
      Ok (`Assoc override)
  | v, `Null when null_is_identity -> Ok v
  | _, `Null -> Ok `Null
  | `Null, v -> Ok v
  | `Tuple _, _ | _, `Tuple _ -> assert false
  | `Variant _, _ | _, `Variant _ -> assert false
  | b, o -> Error (`Type_mismatch_err (None, b, o))

let merge ?(null_is_identity = false) ?(list = `Prepend) ~base override =
  (merge' ~null_is_identity ~list ~base override
    : (Yojson.Safe.t, merge_err) result
    :> (Yojson.Safe.t, [> merge_err ]) result)
