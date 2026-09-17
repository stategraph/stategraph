type t =
  | Stategraph
  | Terrateam
[@@deriving eq, show]

let env_var = "TERRAT_BRAND"
let all = [ Stategraph; Terrateam ]

let of_string = function
  | "stategraph" -> Some Stategraph
  | "terrateam" -> Some Terrateam
  | _ -> None

let to_string = function
  | Stategraph -> "stategraph"
  | Terrateam -> "terrateam"

let of_repo_name name = of_string (CCString.lowercase_ascii name)
let directory brand = "." ^ to_string brand

let of_env () =
  match Sys.getenv_opt env_var with
  | None -> Ok None
  | Some s -> (
      match of_string (CCString.lowercase_ascii (CCString.trim s)) with
      | Some brand -> Ok (Some brand)
      | None ->
          Error
            (Printf.sprintf
               "%s: unknown value %S, expected \"stategraph\" or \"terrateam\""
               env_var
               s))

let fallback =
  lazy
    (match of_env () with
    | Ok (Some brand) -> brand
    | Ok None -> Stategraph
    | Error msg -> failwith msg)

let fallback () = Lazy.force fallback

let resolve ~forced_config ~repo_config ~centralized ~fallback =
  CCOption.get_or ~default:fallback (CCOption.choice [ forced_config; repo_config; centralized ])

let to_terrateam s =
  s
  |> CCString.replace ~sub:"stategraph.com" ~by:"terrateam.io"
  |> CCString.replace ~sub:"stategraph" ~by:"terrateam"
  |> CCString.replace ~sub:"Stategraph" ~by:"Terrateam"

let branded f s =
  let stategraph = f s in
  let terrateam = f (to_terrateam s) in
  function
  | Stategraph -> stategraph
  | Terrateam -> terrateam
