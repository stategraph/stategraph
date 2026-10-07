module Ctx = struct
  type t = {
    dirspace : Terrat_dirspace.t;
    working_dirspace : Terrat_dirspace.t option;
    outputs : Terrat_output_diff.t option;
  }

  let make ?working_dirspace ?outputs ~dirspace () = { dirspace; working_dirspace; outputs }
end

module Q = struct
  type t =
    | Or of (t * t)
    | And of (t * t)
    | Tag of string
    | Dir_glob of (string * ((string -> bool)[@opaque]))
    | Not of t
    | Outputs of {
        target : outputs_target;
        path : string list option;
      }
    | Any

  and outputs_target =
    | Dir of string
    | Relative_dir of string
  [@@deriving show]
end

type warning = Implicit_and of { suggestion : string option } [@@deriving show]

type t = {
  s : string;
  q : Q.t;
  warning : warning option;
}
[@@deriving show]

let equal { s = s1; _ } { s = s2; _ } = CCString.equal s1 s2
let dir_in_prefix = "dir~"
let dir_in_prefix_len = CCString.length dir_in_prefix
let dir_prefix = "dir:"
let workspace_prefix = "workspace:"

let escape_glob s =
  let b = Buffer.create (CCString.length s) in
  CCString.iter
    (function
      | ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-' | '.' | ' ' | '/') as c ->
          Buffer.add_char b c
      | c ->
          Buffer.add_char b '\\';
          Buffer.add_char b c)
    s;
  Buffer.contents b

let rec process_dot_dot fname =
  match CCString.Split.left ~by:"/../" fname with
  | Some (l, r) -> (
      match CCString.Split.right ~by:"/" l with
      | Some (l', _) -> process_dot_dot (l' ^ "/" ^ r)
      | None -> process_dot_dot r)
  | None -> fname

let test_relative_dir ctx relative_dir =
  match ctx.Ctx.working_dirspace with
  | Some working_dirspace ->
      CCString.equal
        ctx.Ctx.dirspace.Terrat_dirspace.dir
        (process_dot_dot (Filename.concat working_dirspace.Terrat_dirspace.dir relative_dir))
  | None -> false

let rec match' ~ctx ~tag_set = function
  | Q.Any -> true
  | Q.Not t -> not (match' ~ctx ~tag_set t)
  | Q.Tag tag -> (
      match CCString.Split.left ~by:":" tag with
      | Some ("relative_dir", relative_dir) -> test_relative_dir ctx relative_dir
      | _ -> Terrat_tag_set.mem tag tag_set)
  | Q.Dir_glob (_, eq) -> eq ctx.Ctx.dirspace.Terrat_dirspace.dir
  | Q.Outputs { target; path } ->
      (* The target is tested the same way as a [dir:] tag or a [relative_dir:] tag. *)
      let names_dirspace =
        match target with
        | Q.Dir dir -> Terrat_tag_set.mem (dir_prefix ^ dir) tag_set
        | Q.Relative_dir relative_dir -> test_relative_dir ctx relative_dir
      in
      names_dirspace
      && CCOption.map_or
           ~default:true
           (fun outputs -> Terrat_output_diff.changed outputs ~path)
           ctx.Ctx.outputs
  | Q.And (l, r) -> match' ~ctx ~tag_set l && match' ~ctx ~tag_set r
  | Q.Or (l, r) -> match' ~ctx ~tag_set l || match' ~ctx ~tag_set r

let match_ ~ctx ~tag_set t = match' ~ctx ~tag_set t.q

let outputs_target = function
  | Terrat_tag_query_parser_value.Outputs dir -> Q.Dir dir
  | Terrat_tag_query_parser_value.Relative_outputs relative_dir -> Q.Relative_dir relative_dir

let rec of_ast =
  let module T = Terrat_tag_query_parser_value in
  function
  | T.In_dir glob_str ->
      let glob = Path_glob.Glob.parse (Printf.sprintf "<**/%s/**>" (escape_glob glob_str)) in
      Q.Dir_glob (glob_str, Path_glob.Glob.eval glob)
  | T.Tag q when CCString.starts_with ~prefix:dir_in_prefix q ->
      let glob_str = CCString.drop dir_in_prefix_len q in
      let glob = Path_glob.Glob.parse (Printf.sprintf "<**/%s/**>" (escape_glob glob_str)) in
      Q.Dir_glob (glob_str, Path_glob.Glob.eval glob)
  | T.In_outputs { path; target } ->
      Q.Outputs { target = outputs_target target; path = Some (CCString.split_on_char '.' path) }
  | T.Tag tag -> (
      match T.outputs_target_of_string tag with
      | Some target -> Q.Outputs { target = outputs_target target; path = None }
      | None -> Q.Tag tag)
  | T.And (l, r) | T.Implicit_and (l, r) -> Q.And (of_ast l, of_ast r)
  | T.Or (l, r) -> Q.Or (of_ast l, of_ast r)
  | T.Not e -> Q.Not (of_ast e)

let rec has_implicit_and =
  let module T = Terrat_tag_query_parser_value in
  function
  | T.Implicit_and _ -> true
  | T.And (l, r) | T.Or (l, r) -> has_implicit_and l || has_implicit_and r
  | T.Not e -> has_implicit_and e
  | T.Tag _ | T.In_dir _ | T.In_outputs _ -> false

(* Collect the operands of a query that is nothing but directory selectors joined
   by [or]s and implicit [and]s, in the order they were written.  A dirspace is in
   exactly one directory, so every implicit [and] in such a query is a dead
   conjunct and the user certainly meant [or] throughout.  Any other shape,
   [dir:foo workspace:prod] for instance, is a sensible [and] and must not be
   rewritten, so it yields [None]. *)
let rec dir_selectors =
  let module T = Terrat_tag_query_parser_value in
  function
  | T.Implicit_and (l, r) | T.Or (l, r) -> (
      match (dir_selectors l, dir_selectors r) with
      | Some l, Some r -> Some (l @ r)
      | Some _, None | None, Some _ | None, None -> None)
  | T.Tag tag
    when CCString.starts_with ~prefix:dir_prefix tag
         || CCString.starts_with ~prefix:dir_in_prefix tag -> Some [ tag ]
  | T.In_dir glob_str -> Some [ glob_str ^ " in dir" ]
  | T.Tag _ | T.And _ | T.Not _ | T.In_outputs _ -> None

(* The order the selectors were written in is the order to offer them back in, so
   this keeps the first of any repeat rather than sorting. *)
let uniq_in_order =
  CCFun.(
    CCList.fold_left (fun acc s -> if CCList.mem ~eq:CCString.equal s acc then acc else s :: acc) []
    %> CCList.rev)

let warning_of_ast ast =
  match has_implicit_and ast with
  | false -> None
  | true ->
      let suggestion =
        match CCOption.map uniq_in_order (dir_selectors ast) with
        | Some (_ :: _ :: _ as selectors) -> Some (CCString.concat " or " selectors)
        | Some ([] | [ _ ]) | None -> None
      in
      Some (Implicit_and { suggestion })

(* [Q.Tag] keeps the text the user wrote, thus the prefix is still there to test.  [Q.Dir_glob]
   does not: both [in dir <glob>] and [dir~<glob>] become that node, and neither one is a [dir:]
   tag.  A [Q.Not] answers false wherever it sits, thus one negation takes the whole query out. *)
let rec selects_dirspaces_only' = function
  | Q.Tag tag ->
      CCString.starts_with ~prefix:dir_prefix tag
      || CCString.starts_with ~prefix:workspace_prefix tag
  | Q.And (l, r) | Q.Or (l, r) -> selects_dirspaces_only' l && selects_dirspaces_only' r
  | Q.Dir_glob _ | Q.Not _ | Q.Outputs _ | Q.Any -> false

let selects_dirspaces_only t = selects_dirspaces_only' t.q

(* [Q.Any] is what an input of no tokens parses to, and no other input produces it, thus it is the
   test for the empty query. *)
let is_empty t =
  match t.q with
  | Q.Any -> true
  | Q.Tag _ | Q.Dir_glob _ | Q.Not _ | Q.Outputs _ | Q.And _ | Q.Or _ -> false

let rec uses_outputs' = function
  | Q.Outputs _ -> true
  | Q.And (l, r) | Q.Or (l, r) -> uses_outputs' l || uses_outputs' r
  | Q.Not t -> uses_outputs' t
  | Q.Tag _ | Q.Dir_glob _ | Q.Any -> false

let uses_outputs t = uses_outputs' t.q

let of_string s =
  match Terrat_tag_query_ast.of_string s with
  | Ok (Some ast) -> Ok { q = of_ast ast; s; warning = warning_of_ast ast }
  | Ok None -> Ok { q = Q.Any; s; warning = None }
  | Error _ as err -> err

let to_string t = t.s
let warning t = t.warning
let any = { q = Q.Any; s = ""; warning = None }
