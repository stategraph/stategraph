type brand =
  | Terrateam
  | Stategraph

let canonical_prefix = "terrateam "
let stategraph_prefix = "stategraph "

let active =
  match Sys.getenv_opt "TERRAT_CHECK_TITLE_BRAND" with
  | Some "stategraph" -> Stategraph
  | Some _ | None -> Terrateam

let branded_with ~brand title =
  match brand with
  | Terrateam -> title
  | Stategraph -> (
      match CCString.chop_prefix ~pre:canonical_prefix title with
      | Some rest -> stategraph_prefix ^ rest
      | None -> title)

let branded title = branded_with ~brand:active title

let canonical title =
  match CCString.chop_prefix ~pre:stategraph_prefix title with
  | Some rest -> canonical_prefix ^ rest
  | None -> title
