let canonical_prefix = "terrateam "
let stategraph_prefix = "stategraph "

let branded_with ~brand title =
  match brand with
  | Terrat_brand.Terrateam -> title
  | Terrat_brand.Stategraph -> (
      match CCString.chop_prefix ~pre:canonical_prefix title with
      | Some rest -> stategraph_prefix ^ rest
      | None -> title)

let canonical title =
  match CCString.chop_prefix ~pre:stategraph_prefix title with
  | Some rest -> canonical_prefix ^ rest
  | None -> title
