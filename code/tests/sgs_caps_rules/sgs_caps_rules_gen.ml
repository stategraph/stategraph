module R = Sgs_caps_rules
module Q = QCheck2

(* [group_str_gen] draws a short pattern over a small alphabet with an optional trailing [*], so both
   plain and glob group names are exercised.  [cond_gen] builds a bounded-depth tree, biased toward
   [Group] leaves (weight 2 vs 1) so the [Any]/[All] nesting terminates. *)
let group_str_gen =
  let open Q.Gen in
  map2
    (fun body star -> if star then body ^ "*" else body)
    (string_size ~gen:(oneof_list [ 'a'; 'e'; 'n'; 'g'; '-'; 's'; 'r' ]) (int_range 1 5))
    bool

let cond_gen =
  Q.Gen.fix
    (fun self depth ->
      let open Q.Gen in
      let leaf = map (fun s -> R.Group s) group_str_gen in
      if depth <= 0 then leaf
      else
        oneof_weighted
          [
            (2, leaf);
            (1, map (fun cs -> R.Any cs) (list_size (int_bound 3) (self (depth - 1))));
            (1, map (fun cs -> R.All cs) (list_size (int_bound 3) (self (depth - 1))));
          ])
    3
