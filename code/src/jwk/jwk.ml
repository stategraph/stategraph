module Key = struct
  type t = string Sln_map.String.t

  let get = Sln_map.String.get
end

type t = {
  by_kid : Key.t Sln_map.String.t;
  keys : Key.t list;
}

let get_kid kid t = Sln_map.String.get kid t.by_kid
let keys t = t.keys

let of_string =
  CCOption.wrap (fun s ->
      let json = Yojson.Basic.from_string s in
      let keys =
        CCList.map
          (fun k ->
            Sln_map.String.of_list
              (CCList.filter_map
                 (fun (k, v) ->
                   match v with
                   | `String v -> Some (k, v)
                   | `Assoc _ | `Bool _ | `Float _ | `Int _ | `List _ | `Null -> None)
                 (Yojson.Basic.Util.to_assoc k)))
          Yojson.Basic.Util.(to_list (member "keys" json))
      in
      {
        by_kid =
          CCList.fold_left
            (fun acc key ->
              CCOption.map_or
                ~default:acc
                (fun kid -> Sln_map.String.add kid key acc)
                (Key.get "kid" key))
            Sln_map.String.empty
            keys;
        keys;
      })
