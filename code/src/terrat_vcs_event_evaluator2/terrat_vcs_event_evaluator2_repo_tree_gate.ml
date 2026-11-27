type t =
  | Use
  | Fetch
  | Give_up
[@@deriving eq, show]

let decide ~missing_tree ~tree_builder ~built =
  match built with
  | true -> Use
  | false -> (
      match missing_tree with
      | `Unknown -> Give_up
      | `Fetch when tree_builder -> Give_up
      | `Fetch -> Fetch)
