module Pattern = struct
  type t =
    | Literal of string
    | Prefix of string
  [@@deriving show, eq]

  let max_length = 256

  (* Excluding the control characters is what keeps [below] observable: no set of children can
     cover every continuation of a prefix, so a node always decides some strings of its own. *)
  let in_range c = 32 <= Char.code c

  let of_string s =
    match CCString.index_opt s '*' with
    | _ when CCString.length s > max_length || not (CCString.for_all in_range s) ->
        Error (`Invalid_pattern_err s)
    | None -> Ok (Literal s)
    | Some i when i = CCString.length s - 1 -> Ok (Prefix (CCString.sub s 0 i))
    | Some _ -> Error (`Invalid_pattern_err s)

  let to_string = function
    | Literal s -> s
    | Prefix s -> s ^ "*"

  (* Patterns that match a common string are nested, so ordering them by length, then a prefix
     before a literal of the same text, puts every pattern after the patterns that contain it. *)
  let compare_specificity a b =
    let rank = function
      | Prefix s -> (CCString.length s, 0)
      | Literal s -> (CCString.length s, 1)
    in
    let length_a, kind_a = rank a in
    let length_b, kind_b = rank b in
    match CCInt.compare length_a length_b with
    | 0 -> CCInt.compare kind_a kind_b
    | c -> c
end

module Char_map = CCMap.Make (CCChar)

(* The children of a node are keyed by the first character of their edge label. Labels are not
   empty, so the siblings of a node start with distinct characters. *)
type 'a t = {
  here : 'a;
  below : 'a;
  children : 'a edge Char_map.t;
}

and 'a edge = {
  label : string;
  target : 'a t;
}

let const v = { here = v; below = v; children = Char_map.empty }

let label_at label s i =
  let length = CCString.length label in
  CCString.length s - i >= length && CCString.is_sub ~sub:label 0 s i ~sub_len:length

let rec find_from t s i =
  if i = CCString.length s then t.here
  else
    match Char_map.find_opt s.[i] t.children with
    | Some { label; target } when label_at label s i ->
        find_from target s (i + CCString.length label)
    | Some _ | None -> t.below

let find t s = find_from t s 0

(* The edge from a parent to [node], in canonical form. A node that gives the parent's [below] for
   its own string and for the strings under it is removed when it has no child, and merged into
   the edge when it has one child. *)
let edge ~equal ~parent_below label node =
  let inherits = equal node.here parent_below && equal node.below parent_below in
  match Char_map.to_list node.children with
  | [] when inherits -> None
  | [ (_, { label = rest; target }) ] when inherits -> Some { label = label ^ rest; target }
  | [] | [ _ ] | _ :: _ :: _ -> Some { label; target = node }

let rec map ~equal f t =
  let below = f t.below in
  {
    here = f t.here;
    below;
    children =
      Char_map.filter_map
        (fun _ { label; target } -> edge ~equal ~parent_below:below label (map ~equal f target))
        t.children;
  }

(* The node that sits [depth] characters down edge [e], inside its label. No node of the trie is
   there: its strings answer the parent's [below], except the strings that continue along [e]. *)
let inside ~parent_below e depth =
  let rest = CCString.sub e.label depth (CCString.length e.label - depth) in
  {
    here = parent_below;
    below = parent_below;
    children = Char_map.singleton rest.[0] { label = rest; target = e.target };
  }

let common_prefix_length a b =
  let n = min (CCString.length a) (CCString.length b) in
  let rec go i = if i < n && Char.equal a.[i] b.[i] then go (i + 1) else i in
  go 0

let rec merge ~equal f a b =
  let below = f a.below b.below in
  let child _ ea eb =
    match (ea, eb) with
    | Some { label; target }, None ->
        edge ~equal ~parent_below:below label (map ~equal (fun x -> f x b.below) target)
    | None, Some { label; target } ->
        edge ~equal ~parent_below:below label (map ~equal (fun y -> f a.below y) target)
    | Some ea, Some eb ->
        (* Both edges start with the same character. Both sides are compared at the end of their
           common part, where at least one of them has a real node. *)
        let depth = common_prefix_length ea.label eb.label in
        let at_depth ~parent_below e =
          if CCString.length e.label = depth then e.target else inside ~parent_below e depth
        in
        edge
          ~equal
          ~parent_below:below
          (CCString.sub ea.label 0 depth)
          (merge ~equal f (at_depth ~parent_below:a.below ea) (at_depth ~parent_below:b.below eb))
    | None, None -> None
  in
  { here = f a.here b.here; below; children = Char_map.merge child a.children b.children }

(* The trie that answers [Some v] for the strings [pattern] matches, and [None] for the others. *)
let only pattern v =
  let at prefix node =
    match prefix with
    | "" -> node
    | _ ->
        {
          (const None) with
          children = Char_map.singleton prefix.[0] { label = prefix; target = node };
        }
  in
  match pattern with
  | Pattern.Prefix prefix -> at prefix { here = Some v; below = Some v; children = Char_map.empty }
  | Pattern.Literal prefix -> at prefix { here = Some v; below = None; children = Char_map.empty }

let override ~equal ~answer ~on ~base =
  merge ~equal (fun matched x -> CCOption.get_or ~default:x matched) (only on answer) base

let of_rules ~equal ~default rules =
  CCList.stable_sort (fun (a, _) (b, _) -> Pattern.compare_specificity a b) rules
  |> CCList.fold_left (fun base (on, answer) -> override ~equal ~answer ~on ~base) (const default)

let to_rules ~equal t =
  let literal ~prefix node =
    if equal node.here node.below then [] else [ (Pattern.Literal prefix, node.here) ]
  in
  let rec node_rules ~prefix ~parent_below node =
    (if equal node.below parent_below then [] else [ (Pattern.Prefix prefix, node.below) ])
    @ literal ~prefix node
    @ children_rules ~prefix node
  and children_rules ~prefix node =
    CCList.flat_map
      (fun (_, { label; target }) ->
        node_rules ~prefix:(prefix ^ label) ~parent_below:node.below target)
      (Char_map.to_list node.children)
  in
  ((Pattern.Prefix "", t.below) :: literal ~prefix:"" t) @ children_rules ~prefix:"" t

let rec for_all p t =
  p t.here
  && p t.below
  && Char_map.for_all (fun _ { label = _; target } -> for_all p target) t.children

let rec equal eq a b =
  eq a.here b.here
  && eq a.below b.below
  && Char_map.equal
       (fun ea eb -> CCString.equal ea.label eb.label && equal eq ea.target eb.target)
       a.children
       b.children

let pp pp_value fmt t =
  let rec pp_node fmt { here; below; children } =
    Format.fprintf
      fmt
      "@[<hv 2>{ here = %a;@ below = %a;@ children = [@[<hv>%a@]] }@]"
      pp_value
      here
      pp_value
      below
      (Format.pp_print_list
         ~pp_sep:(fun fmt () -> Format.fprintf fmt ";@ ")
         (fun fmt (_, { label; target }) -> Format.fprintf fmt "%S -> %a" label pp_node target))
      (Char_map.to_list children)
  in
  pp_node fmt t

let show pp_value t = Format.asprintf "%a" (pp pp_value) t
