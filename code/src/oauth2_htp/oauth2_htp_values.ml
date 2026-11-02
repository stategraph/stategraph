type t = (string * string list) list

let get k t =
  CCOption.get_or
    ~default:""
    (CCList.find_map (fun (k', vs) -> if CCString.equal k k' then CCList.head_opt vs else None) t)

let add k v t =
  match Sln_list.String.mem_assoc k t with
  | true ->
      CCList.map (fun (k', vs) -> if CCString.equal k k' then (k', vs @ [ v ]) else (k', vs)) t
  | false -> t @ [ (k, [ v ]) ]

let encode t =
  t
  |> Sln_list.String.sort_assoc
  |> CCList.flat_map (fun (k, vs) ->
      CCList.map
        (fun v -> Printf.sprintf "%s=%s" (Form_urlencode.encode k) (Form_urlencode.encode v))
        vs)
  |> CCString.concat "&"

let of_query_string s = Uri.query (Uri.of_string ("?" ^ s))
