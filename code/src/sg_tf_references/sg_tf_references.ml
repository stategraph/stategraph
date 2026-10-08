module Reference_set = CCSet.Make (struct
  type t = string list [@@deriving eq, ord]
end)

module String_set = CCSet.Make (CCString)

let meta_roots = String_set.of_list [ "each"; "count"; "path" ]

(* Extract a qualified name from an expression, if it forms one *)
let rec extract_qualified_name bound_vars expr =
  let module Expr = Hcl_parser_value.Expr in
  match expr with
  | Expr.Id id -> if String_set.mem id bound_vars then None else Some [ id ]
  | Expr.Attr (e, Hcl_parser_value.Attr.A_string key) ->
      extract_qualified_name bound_vars e |> CCOption.map (fun prefix -> prefix @ [ key ])
  | Expr.Attr (_, (Hcl_parser_value.Attr.A_int _ | Hcl_parser_value.Attr.A_splat))
  | Expr.String _
  | Expr.Template _
  | Expr.Int _
  | Expr.Float _
  | Expr.Bool _
  | Expr.Null
  | Expr.Tuple _
  | Expr.Object _
  | Expr.Fun_call _
  | Expr.For_tuple _
  | Expr.For_object _
  | Expr.Cond _
  | Expr.Idx _
  | Expr.Splat
  | Expr.Not _
  | Expr.Minus _
  | Expr.Add _
  | Expr.Subtract _
  | Expr.Mult _
  | Expr.Div _
  | Expr.Log_and _
  | Expr.Log_or _
  | Expr.Equal _
  | Expr.Not_equal _
  | Expr.Gt _
  | Expr.Lt _
  | Expr.Gte _
  | Expr.Lte _
  | Expr.Mod _
  | Expr.Heredoc _
  | Expr.Heredoc' _
  | Expr.Template_heredoc _
  | Expr.Ellipsis _ -> None

module Selector = struct
  type t =
    | Key of string
    | Index of int
  [@@deriving show, eq]
end

let selector_of_expr expr =
  let module Expr = Hcl_parser_value.Expr in
  match expr with
  | Expr.String s -> Some (Selector.Key s)
  | Expr.Int n -> Some (Selector.Index n)
  | Expr.Id _
  | Expr.Attr _
  | Expr.Template _
  | Expr.Float _
  | Expr.Bool _
  | Expr.Null
  | Expr.Tuple _
  | Expr.Object _
  | Expr.Fun_call _
  | Expr.For_tuple _
  | Expr.For_object _
  | Expr.Cond _
  | Expr.Idx _
  | Expr.Splat
  | Expr.Not _
  | Expr.Minus _
  | Expr.Add _
  | Expr.Subtract _
  | Expr.Mult _
  | Expr.Div _
  | Expr.Log_and _
  | Expr.Log_or _
  | Expr.Equal _
  | Expr.Not_equal _
  | Expr.Gt _
  | Expr.Lt _
  | Expr.Gte _
  | Expr.Lte _
  | Expr.Mod _
  | Expr.Heredoc _
  | Expr.Heredoc' _
  | Expr.Template_heredoc _
  | Expr.Ellipsis _ -> None

(* The accumulator of the reference walk. The selectors travel with the references, and not in a
   second walk. Thus a new arm of the walker cannot forget one of the two. *)
module Acc = struct
  type t = {
    refs : Reference_set.t;
    selectors : (string list * Selector.t) list;
  }

  let empty = { refs = Reference_set.empty; selectors = [] }
  let add_ref r t = { t with refs = Reference_set.add r t.refs }

  let add_selector_opt r s t =
    match s with
    | Some s -> { t with selectors = (r, s) :: t.selectors }
    | None -> t
end

let rec from_expr bound_vars acc expr =
  let module Expr = Hcl_parser_value.Expr in
  match expr with
  | Expr.Splat -> acc
  (* Attribute-only splat [e.*] is transparent for reference extraction, like
     [.0] indexing below: recurse into the base so its references are collected
     (e.g. [local.xs.*.name] structurally depends on [local.xs]). Without this
     the base is dropped and the referenced node is never pulled into the plan
     subgraph *)
  | Expr.Attr (e, Hcl_parser_value.Attr.A_splat) -> from_expr bound_vars acc e
  | Expr.Attr (Expr.Id v, Hcl_parser_value.Attr.A_string _) when String_set.mem v bound_vars -> acc
  | Expr.Attr (e, Hcl_parser_value.Attr.A_int _) -> from_expr bound_vars acc e
  | Expr.Attr (Expr.Idx (inner, idx_expr), Hcl_parser_value.Attr.A_string key) ->
      (* Indexing is transparent for reference extraction: module.child[*].bar or
         module.child[0].bar extracts the same reference as module.child.bar.
         We also collect any references inside the index expression itself. *)
      let acc = from_expr bound_vars acc idx_expr in
      let inner_name = extract_qualified_name bound_vars inner in
      CCOption.map_or
        ~default:(from_expr bound_vars acc inner)
        (fun prefix ->
          let ref_ = prefix @ [ key ] in
          Acc.add_ref ref_ (Acc.add_selector_opt ref_ (selector_of_expr idx_expr) acc))
        inner_name
  | Expr.Attr (e, Hcl_parser_value.Attr.A_string _) -> (
      match extract_qualified_name bound_vars expr with
      | Some qualified_name -> Acc.add_ref qualified_name acc
      | None -> from_expr bound_vars acc e)
  | Expr.Id s -> if String_set.mem s bound_vars then acc else Acc.add_ref [ s ] acc
  | Expr.Add (e1, e2)
  | Expr.Subtract (e1, e2)
  | Expr.Mult (e1, e2)
  | Expr.Div (e1, e2)
  | Expr.Log_and (e1, e2)
  | Expr.Log_or (e1, e2)
  | Expr.Equal (e1, e2)
  | Expr.Not_equal (e1, e2)
  | Expr.Gt (e1, e2)
  | Expr.Lt (e1, e2)
  | Expr.Gte (e1, e2)
  | Expr.Lte (e1, e2)
  | Expr.Mod (e1, e2) -> from_expr bound_vars (from_expr bound_vars acc e1) e2
  | Expr.Tuple l -> CCList.fold_left (from_expr bound_vars) acc l
  | Expr.Object l ->
      let module K = Hcl_parser_value.Obj_key in
      CCList.fold_left
        (fun current_acc (k, v_expr) ->
          let key_acc =
            match k with
            (* [Bare] / [Quoted] keys are literal names, never variable refs. *)
            | K.Bare _ | K.Quoted _ -> current_acc
            | K.Template parts -> from_template_parts bound_vars current_acc parts
            | K.Computed e | K.Expr e -> from_expr bound_vars current_acc e
          in
          from_expr bound_vars key_acc v_expr)
        acc
        l
  | Expr.Fun_call (fn, args) -> (
      let acc = CCList.fold_left (from_expr bound_vars) acc args in
      (* [lookup(m, "K", d)] is [m["K"]] written as a call, and tofu evaluates the two in the same
         way. The arms above see only the arguments, thus they would lose the key. *)
      match (fn, args) with
      | "lookup", m :: key_expr :: _ ->
          CCOption.map_or
            ~default:acc
            (fun prefix -> Acc.add_selector_opt prefix (selector_of_expr key_expr) acc)
            (extract_qualified_name bound_vars m)
      | _ -> acc)
  | Expr.For_tuple { identifiers = first_id, other_ids; input; output; cond } ->
      let acc' = from_expr bound_vars acc input in
      let all_ids = String_set.of_list (first_id :: other_ids) in
      let bound_vars = String_set.union all_ids bound_vars in
      let acc'' = CCOption.fold (from_expr bound_vars) acc' cond in
      from_expr bound_vars acc'' output
  | Expr.For_object { identifiers = first_id, other_ids; input; key_output; value_output; cond } ->
      let acc' = from_expr bound_vars acc input in
      let all_ids = String_set.of_list (first_id :: other_ids) in
      let bound_vars = String_set.union all_ids bound_vars in
      let acc'' = CCOption.fold (from_expr bound_vars) acc' cond in
      let acc''' = from_expr bound_vars acc'' key_output in
      from_expr bound_vars acc''' value_output
  | Expr.Cond { if_; then_; else_ } ->
      let acc' = from_expr bound_vars acc if_ in
      let acc'' = from_expr bound_vars acc' then_ in
      from_expr bound_vars acc'' else_
  | Expr.Idx (e, idx_expr) ->
      (* Dynamic/indexed module-output access (e.g. [module.X[local.k]]) is
         resolved by the client-side ref-hint path in [Sg_tx_builder] — see
         [record_idx_hint] there.  For remote-source modules (where
         [root_module] doesn't have the child's files on disk), resolution
         falls to the [is_remote_module_body] path in [Sgs_tx_log], which
         leaves [module_input_refs] empty so cone follows the module
         block's own refs and pulls in every feeder.  Either way, no
         wildcard sentinel is needed here; just recurse into both sides
         to collect any nested refs. *)
      let acc = from_expr bound_vars acc e in
      let acc = from_expr bound_vars acc idx_expr in
      CCOption.map_or
        ~default:acc
        (fun prefix -> Acc.add_selector_opt prefix (selector_of_expr idx_expr) acc)
        (extract_qualified_name bound_vars e)
  | Expr.Not e | Expr.Minus e | Expr.Ellipsis e -> from_expr bound_vars acc e
  | Expr.Template parts -> from_template_parts bound_vars acc parts
  | Expr.String _ | Expr.Int _ | Expr.Float _ | Expr.Bool _ | Expr.Null -> acc
  (* A heredoc that carries [${...}] interpolations is promoted at load time to
     [Template_heredoc] (see [Hcl_ast_template]); recurse into its parts like
     the [Template] arm above.  A plain literal heredoc stays [Heredoc] and has
     no references. *)
  | Expr.Template_heredoc (_, parts) -> from_template_parts bound_vars acc parts
  | Expr.Heredoc _ | Expr.Heredoc' _ -> acc

and from_template_parts bound_vars acc parts =
  CCList.fold_left (from_template_part bound_vars) acc parts

and from_template_part bound_vars acc part =
  let module Tp = Hcl_parser_value.Template_part in
  match part with
  | Tp.Literal _ -> acc
  | Tp.Interpolation { expr; _ } -> from_expr bound_vars acc expr
  | Tp.If_directive { cond; then_; else_; _ } ->
      let acc' = from_expr bound_vars acc cond in
      let acc'' = from_template_parts bound_vars acc' then_ in
      CCOption.fold (from_template_parts bound_vars) acc'' else_
  | Tp.For_directive { vars = v, key_opt; input; body; _ } ->
      let acc' = from_expr bound_vars acc input in
      let new_bound = String_set.add v bound_vars in
      let new_bound =
        match key_opt with
        | Some k -> String_set.add k new_bound
        | None -> new_bound
      in
      from_template_parts new_bound acc' body

module Var_reads = struct
  type t = {
    attrs : string list;
    whole : bool;
  }

  let empty = { attrs = []; whole = false }
  let add_attr a t = { t with attrs = a :: t.attrs }
  let mark_whole t = { t with whole = true }
end

(* How a comprehension's loop variable is consumed inside the comprehension body.
   [Attr (Id v, A_string k)] contributes the attribute name [k]; anything else that reaches the
   variable -- a bare read, a splat, an index, an integer attribute -- contributes [whole], because
   the value is used in a way that does not name one member of it.

   A nested comprehension rebinding the same name shadows it, and reads under that binding belong to
   the inner variable.  The [input] of such a comprehension is evaluated in the OUTER scope, so it is
   walked before the shadow takes effect. *)
let reads_of_var ~var expr =
  let module E = Hcl_parser_value.Expr in
  let module A = Hcl_parser_value.Attr in
  let module Tp = Hcl_parser_value.Template_part in
  let module K = Hcl_parser_value.Obj_key in
  let is_var shadowed id = (not shadowed) && CCString.equal id var in
  let binds (first, rest) = CCList.exists (CCString.equal var) (first :: rest) in
  let rec go shadowed acc expr =
    match expr with
    | E.Attr (E.Id id, A.A_string key) when is_var shadowed id -> Var_reads.add_attr key acc
    | E.Attr (E.Id id, (A.A_int _ | A.A_splat)) when is_var shadowed id -> Var_reads.mark_whole acc
    | E.Idx (E.Id id, idx_expr) when is_var shadowed id ->
        go shadowed (Var_reads.mark_whole acc) idx_expr
    | E.Id id -> if is_var shadowed id then Var_reads.mark_whole acc else acc
    | E.Attr (e, (A.A_string _ | A.A_int _ | A.A_splat)) -> go shadowed acc e
    | E.Idx (e, idx_expr) -> go shadowed (go shadowed acc e) idx_expr
    | E.Tuple l -> CCList.fold_left (go shadowed) acc l
    | E.Object l ->
        CCList.fold_left
          (fun acc (k, v_expr) ->
            let acc =
              match k with
              | K.Bare _ | K.Quoted _ -> acc
              | K.Template parts -> go_parts shadowed acc parts
              | K.Computed e | K.Expr e -> go shadowed acc e
            in
            go shadowed acc v_expr)
          acc
          l
    | E.Fun_call (_, args) -> CCList.fold_left (go shadowed) acc args
    | E.For_tuple { identifiers; input; output; cond } ->
        let acc = go shadowed acc input in
        let shadowed = shadowed || binds identifiers in
        let acc = CCOption.fold (go shadowed) acc cond in
        go shadowed acc output
    | E.For_object { identifiers; input; key_output; value_output; cond } ->
        let acc = go shadowed acc input in
        let shadowed = shadowed || binds identifiers in
        let acc = CCOption.fold (go shadowed) acc cond in
        let acc = go shadowed acc key_output in
        go shadowed acc value_output
    | E.Cond { if_; then_; else_ } -> go shadowed (go shadowed (go shadowed acc if_) then_) else_
    | E.Add (e1, e2)
    | E.Subtract (e1, e2)
    | E.Mult (e1, e2)
    | E.Div (e1, e2)
    | E.Log_and (e1, e2)
    | E.Log_or (e1, e2)
    | E.Equal (e1, e2)
    | E.Not_equal (e1, e2)
    | E.Gt (e1, e2)
    | E.Lt (e1, e2)
    | E.Gte (e1, e2)
    | E.Lte (e1, e2)
    | E.Mod (e1, e2) -> go shadowed (go shadowed acc e1) e2
    | E.Not e | E.Minus e | E.Ellipsis e -> go shadowed acc e
    | E.Template parts | E.Template_heredoc (_, parts) -> go_parts shadowed acc parts
    | E.String _ | E.Int _ | E.Float _ | E.Bool _ | E.Null | E.Splat | E.Heredoc _ | E.Heredoc' _ ->
        acc
  and go_parts shadowed acc parts = CCList.fold_left (go_part shadowed) acc parts
  and go_part shadowed acc part =
    match part with
    | Tp.Literal _ -> acc
    | Tp.Interpolation { expr; _ } -> go shadowed acc expr
    | Tp.If_directive { cond; then_; else_; _ } ->
        let acc = go shadowed acc cond in
        let acc = go_parts shadowed acc then_ in
        CCOption.fold (go_parts shadowed) acc else_
    | Tp.For_directive { vars = value, key_opt; input; body; _ } ->
        (* [Template_part.For_directive.vars] is (value, optional key) -- the opposite order from an
           expression comprehension's [identifiers]. *)
        let acc = go shadowed acc input in
        let shadowed =
          shadowed
          || CCString.equal value var
          || CCOption.map_or ~default:false (CCString.equal var) key_opt
        in
        go_parts shadowed acc body
  in
  let reads = go false Var_reads.empty expr in
  { reads with Var_reads.attrs = Sln_list.String.sort_uniq reads.Var_reads.attrs }

module Comprehension = struct
  type t = {
    var : string;
    input : Hcl_parser_value.Expr.t;
    reads : Var_reads.t;
  }
end

(* The VALUE identifier: HCL binds [for k, v in coll] as (key, value) and [for v in coll] as
   (value), so the one that ranges over the collection's elements is the LAST.  Reads off the key
   name nothing -- a key is a string or an index. *)
let value_identifier (first, rest) = CCList.fold_left (fun _ id -> id) first rest

let combine_reads a b =
  {
    Var_reads.attrs = Sln_list.String.sort_uniq (a.Var_reads.attrs @ b.Var_reads.attrs);
    whole = a.Var_reads.whole || b.Var_reads.whole;
  }

let reads_of_body ~var body =
  CCList.fold_left (fun acc e -> combine_reads acc (reads_of_var ~var e)) Var_reads.empty body

let comprehension_of_expr expr =
  let module E = Hcl_parser_value.Expr in
  match expr with
  | E.For_tuple { identifiers; input; output; cond } ->
      let var = value_identifier identifiers in
      let reads = reads_of_body ~var (output :: CCOption.to_list cond) in
      Some { Comprehension.var; input; reads }
  | E.For_object { identifiers; input; key_output; value_output; cond } ->
      let var = value_identifier identifiers in
      let reads = reads_of_body ~var (key_output :: value_output :: CCOption.to_list cond) in
      Some { Comprehension.var; input; reads }
  | E.Id _
  | E.String _
  | E.Template _
  | E.Int _
  | E.Float _
  | E.Bool _
  | E.Null
  | E.Tuple _
  | E.Object _
  | E.Fun_call _
  | E.Cond _
  | E.Idx _
  | E.Attr _
  | E.Splat
  | E.Not _
  | E.Minus _
  | E.Add _
  | E.Subtract _
  | E.Mult _
  | E.Div _
  | E.Log_and _
  | E.Log_or _
  | E.Equal _
  | E.Not_equal _
  | E.Gt _
  | E.Lt _
  | E.Gte _
  | E.Lte _
  | E.Mod _
  | E.Heredoc _
  | E.Heredoc' _
  | E.Template_heredoc _
  | E.Ellipsis _ -> None

(* Meta-argument slots that are keyword / bare-attribute-name traversals, not
   structural references: [lifecycle.ignore_changes] lists attribute names of the
   resource itself, and a provisioner/connection's [when]/[on_failure] are
   keywords.  Extracting refs from them would invent bogus dependency edges (e.g.
   to a resource named after an ignored attribute).  [replace_triggered_by] is a
   real reference list and is intentionally not included.

   A [variable] block's [type] is a type constraint (e.g. [string],
   [object({...})]) — a syntactic type expression, not an evaluatable value — so
   it carries no references either. *)
let meta_keyword_attr ~block_type name =
  match (block_type, name) with
  | "lifecycle", "ignore_changes" -> true
  | ("provisioner" | "connection"), ("when" | "on_failure") -> true
  | "variable", "type" -> true
  | _ -> false

let rec from_value ?(block_type = "") acc item =
  match item with
  | Hcl_parser_value.Attribute ("depends_on", _) ->
      (* [depends_on] expresses Terraform data-flow ordering, not a structural
         reference.  Its targets must not contribute to subgraph traversal — see
         [Sg_tx_builder] header note.  Skip the attribute entirely here; the
         depends_on address list is captured separately by [Sgs_tx_log] for the
         reifier to use when rewriting the attribute at reify time. *)
      acc
  | Hcl_parser_value.Attribute (name, _) when meta_keyword_attr ~block_type name -> acc
  | Hcl_parser_value.Attribute (_, expr) -> from_expr String_set.empty acc expr
  | Hcl_parser_value.Block { type_; body; _ } ->
      CCList.fold_left (fun acc item -> from_value ~block_type:type_ acc item) acc body

let expr_references expr = (from_expr String_set.empty Acc.empty expr).Acc.refs
let references' v = (from_value Acc.empty v).Acc.refs
let selectors v = (from_value Acc.empty v).Acc.selectors
let expr_selectors expr = (from_expr String_set.empty Acc.empty expr).Acc.selectors

(* Collect references from [depends_on] attributes only.  [from_value] above
   skips them so they do not contribute to subgraph traversal; this walker is
   the dual — it only collects them, recursing into nested blocks so module
   bodies are covered. *)
let rec depends_on_from_value acc item =
  match item with
  | Hcl_parser_value.Attribute ("depends_on", expr) -> from_expr String_set.empty acc expr
  | Hcl_parser_value.Attribute (_, _) -> acc
  | Hcl_parser_value.Block { body; _ } -> CCList.fold_left depends_on_from_value acc body

let depends_on_references v = (depends_on_from_value Acc.empty v).Acc.refs

(* Block kinds whose body Terraform requires to reference at least one
   other configuration object: lifecycle [precondition] / [postcondition],
   variable [validation], and check [assert] blocks.  Refs collected from
   inside these blocks must not drive boundary-substitution decisions —
   if substitution dropped the boundary, the check's [condition] would
   either dangle (target gone) or collapse to pure literals (which
   Terraform rejects at init).  This walker is the dual of [references]
   used by [Sgs_tx_log] to flag such refs at edge-emission time. *)
let is_check_block_kind = function
  | "precondition" | "postcondition" | "validation" | "assert" -> true
  | _ -> false

let rec check_block_from_value ~inside_check acc item =
  match item with
  | Hcl_parser_value.Attribute ("depends_on", _) -> acc
  | Hcl_parser_value.Attribute (_, expr) ->
      if inside_check then from_expr String_set.empty acc expr else acc
  | Hcl_parser_value.Block { type_; body; _ } ->
      let inside_check = inside_check || is_check_block_kind type_ in
      CCList.fold_left (check_block_from_value ~inside_check) acc body

let check_block_references v =
  let all = (check_block_from_value ~inside_check:false Acc.empty v).Acc.refs in
  Reference_set.filter
    (fun ref_ ->
      match ref_ with
      | root :: _ -> not (String_set.mem root meta_roots)
      | [] -> true)
    all

let references v =
  let all = references' v in
  Reference_set.filter
    (fun ref_ ->
      match ref_ with
      | root :: _ -> not (String_set.mem root meta_roots)
      | [] -> true)
    all

module Address_set = String_set

(* Sentinel fq_address used in [remote_tf_state_refs] to mean "every
   output the producing state declares". Cross-state references that
   grab the whole [.outputs] object or the bare data block have no
   specific output name to seed, so we record this marker and the cone
   walk SQL fans it out to every [output.*] node in the target state.
   The literal [<*all-outputs*>] cannot collide with any real
   fq_address (terraform identifiers cannot contain [*] or [<]). *)
let remote_tf_state_all_outputs_sentinel_addr = "<*all-outputs*>"

(* Why the bare edge to the call block is not sufficient: the replaced walk refused a module
   block as the origin of a reference edge. Containment admits a block if it admits anything
   inside that block, thus such an origin would bring in each consumer of each output.

   Why the mark is on [attr_path], and not a new address: the edge continues to point at a real
   node, thus it still gives the module block demand and SQL builds no string. The empty-module
   prune of the replaced walk read the same edge as its "never drop a module that something points
   at" guard. *)
let module_all_outputs_attr = "<*all-outputs*>"

(* The address a reference resolves to, as tokens.  One match, so that a caller which needs to
   inspect what the address consumed does not have to take the joined string apart again -- which is
   the thing RFD 1008 forbids of SQL and which is no better done here.

   [address_of_reference] is the join of this, and [attr_path_of_reference] beside it consumes the
   same token counts; the file header already says those two must agree. *)
let address_tokens_of_reference ref_ =
  match ref_ with
  | [ s ] when s = remote_tf_state_all_outputs_sentinel_addr -> Some [ s ]
  | "data" :: type_ :: name :: _ -> Some [ "data"; type_; name ]
  (* Ephemeral resources are 3-token (ephemeral.<type>.<name>), like data sources;
     keep the instance name so the edge matches the block node. *)
  | "ephemeral" :: type_ :: name :: _ -> Some [ "ephemeral"; type_; name ]
  | "outputs" :: name :: _ -> Some [ "output"; name ]
  (* [module.X.attr] reads a child module's output [attr].  The graph stores
     that output as a distinct node at [module.X.output.<attr>], so the
     reference must resolve to that full address — not to the module block
     [module.X].  Bare [module.X] (no attr, e.g. inside [keys(module.X)] or
     a whole-module object expression) resolves to the module block. *)
  | "module" :: name :: attr :: _ -> Some [ "module"; name; "output"; attr ]
  | [ "module"; name ] -> Some [ "module"; name ]
  | ("var" | "local" | "output" | "terraform") :: name :: _ -> Some [ List.hd ref_; name ]
  | _type :: name :: _ -> Some [ List.hd ref_; name ]
  | _ -> None

let address_of_reference ref_ = CCOption.map (String.concat ".") (address_tokens_of_reference ref_)

(* Does the address this reference resolves to name a node?

   It does not when the last token the address consumed is the splat [*]:
   [module.X.*] gives the address [module.X.output.*], and no node has that address.  The reference
   is real -- it reads every output of the module -- but the address is not a name, and an edge
   carrying it points at nothing.

   Not [is_wildcard], which asks whether [*] appears anywhere.  For
   [aws_instance.web.*.id] the address is [aws_instance.web], which names a node perfectly well and
   which the apply keeps today; testing for a [*] anywhere would drop that edge and reify too
   little. *)
let names_a_node ref_ =
  match CCOption.map CCList.rev (address_tokens_of_reference ref_) with
  | Some (last :: _) -> not (CCString.equal last "*")
  | Some [] | None -> true

(* The companion of {!address_of_reference}: the reference tail beyond the tokens
   that the address consumed — i.e. the attribute path a consumer read within the
   node the address names.  [local.config.x.z] resolves to address [local.config]
   with attr_path [["x"; "z"]].

   ALWAYS derive an attr_path with this function.  Do NOT recover it by joining the
   reference with "." and stripping the address off the resulting string: that is a
   prefix match on text rather than on structure, and it goes wrong in two ways.

   The one that is reachable in current behaviour (and has been since #685): a token
   can reproduce the ".output." separator that [address_of_reference] synthesises for
   a module output.  A child module whose
   output is named [output] makes [module.m.output.output] a spurious string prefix
   of [module.m.output.output.x], so the textual form attributes a tail of ["x"] to
   the base edge — not even the correct tail, which is ["output"; "x"].  Deriving
   structurally yields [] instead, which over-approximates (an empty path selects
   the whole attributes object) rather than pointing at the wrong field.  See
   [module_output_named_output] in code/tests/sgs_tx_log/test.ml.

   The one that will bite ONCE static map-key folding lands: folding puts the RAW
   key into the reference path, and a key may itself contain a "." (["main.tf"],
   ["example.com"], ["1.2.3"]).  Re-splitting would shatter such a key into several
   segments, and the resulting attr_path would then never match the single-segment
   path recorded elsewhere for that key — silently dropping a consumer instead of
   merely over-approximating it.  Reference segments cannot contain a "." yet (the
   lexer admits none in an identifier), so that failure is latent, not live.

   Keeping this next to [address_of_reference] is deliberate: the two must agree on
   how many leading tokens an address consumes, and they cannot drift while they sit
   in one place.

   [outputs.X] (renamed to [output.X]) and [module.X.attr] (rewritten to
   [module.X.output.attr]) are addresses that are NOT a verbatim prefix of their
   reference, so no tail can be attributed to them and the result is []. *)
let attr_path_of_reference ref_ =
  match ref_ with
  | "outputs" :: _ | "module" :: _ -> []
  | "data" :: _ :: _ :: tail | "ephemeral" :: _ :: _ :: tail -> tail
  | _ :: _ :: tail -> tail
  | [ _ ] | [] -> []

let addresses refs =
  Reference_set.fold
    (fun ref_ acc ->
      let acc =
        match address_of_reference ref_ with
        | Some addr -> Address_set.add addr acc
        | None -> acc
      in
      (* For a [module.X.attr] read, also include the module block address
         [module.X].  For local modules, the output-to-block implicit edge
         in [Sgs_tx_log.process_hcl_value] makes this redundant — but for
         remote-source modules, stategraph has no child-output nodes in the
         graph (the module's body is opaque), so the output address
         [module.X.output.attr] matches nothing.  Including the block
         address as a fallback ensures cone always reaches the module call
         block. *)
      match ref_ with
      | "module" :: name :: _ :: _ -> Address_set.add (String.concat "." [ "module"; name ]) acc
      | _ -> acc)
    refs
    Address_set.empty

module Data_reference_map = Sln_map.String

let split_remote_tf_state_references refs =
  Reference_set.fold
    (fun ref_ acc ->
      match ref_ with
      | "data" :: "terraform_remote_state" :: name :: rest ->
          let addr = String.concat "." [ "data"; "terraform_remote_state"; name ] in
          let existing =
            match Data_reference_map.find_opt addr acc with
            | Some s -> s
            | None -> Reference_set.empty
          in
          let ref_to_add =
            match rest with
            (* [.outputs.X[.Y...]] - specific named output, existing path *)
            | "outputs" :: _ :: _ -> rest
            (* [.outputs] alone (whole object) or bare data ref ([]) -
               fan out to every upstream output via the sentinel. *)
            | "outputs" :: [] | [] -> [ remote_tf_state_all_outputs_sentinel_addr ]
            (* Other shapes (e.g. [.config]) - retain prior behaviour. *)
            | _ -> rest
          in
          Data_reference_map.add addr (Reference_set.add ref_to_add existing) acc
      | _ -> acc)
    refs
    Data_reference_map.empty

(** Static parse of a leaf reference expression (a chain of [Attr]/[Idx] nodes bottoming in
    [Id "<type>"]) into the four pieces the boundary-substitution machinery needs. Used both to
    decide whether a cone-side resource can be inlined as a state literal and to drive the actual
    rewrite. Returns [None] for shapes that cannot be safely substituted against state — dynamic
    indexes, splats, function-call heads, anything that isn't a concrete chain rooted at an [Id]. *)
module Address = struct
  module Index = struct
    type t =
      | None
      | Int of int
      | String of string
    [@@deriving show, eq]
  end

  type t = {
    type_ : string;
    name : string;
    index : Index.t;
    attr_path : string list;
  }
  [@@deriving show, eq]

  let of_expr expr =
    let module E = Hcl_parser_value.Expr in
    let module A = Hcl_parser_value.Attr in
    let module Step = struct
      type t =
        | Attr of string
        | Idx_int of int
        | Idx_string of string
    end in
    let rec walk steps e =
      match e with
      | E.Attr (inner, A.A_string s) -> walk (Step.Attr s :: steps) inner
      | E.Attr (_, A.A_int _) | E.Attr (_, A.A_splat) -> None
      | E.Idx (inner, idx_expr) -> (
          match idx_expr with
          | E.Int n -> walk (Step.Idx_int n :: steps) inner
          | E.String s -> walk (Step.Idx_string s :: steps) inner
          | E.Id _
          | E.Template _
          | E.Float _
          | E.Bool _
          | E.Null
          | E.Tuple _
          | E.Object _
          | E.Fun_call _
          | E.For_tuple _
          | E.For_object _
          | E.Cond _
          | E.Idx _
          | E.Attr _
          | E.Splat
          | E.Not _
          | E.Minus _
          | E.Add _
          | E.Subtract _
          | E.Mult _
          | E.Div _
          | E.Log_and _
          | E.Log_or _
          | E.Equal _
          | E.Not_equal _
          | E.Gt _
          | E.Lt _
          | E.Gte _
          | E.Lte _
          | E.Mod _
          | E.Heredoc _
          | E.Heredoc' _
          | E.Template_heredoc _
          | E.Ellipsis _ -> None)
      | E.Id type_ -> Some (type_, steps)
      | E.String _
      | E.Template _
      | E.Int _
      | E.Float _
      | E.Bool _
      | E.Null
      | E.Tuple _
      | E.Object _
      | E.Fun_call _
      | E.For_tuple _
      | E.For_object _
      | E.Cond _
      | E.Splat
      | E.Not _
      | E.Minus _
      | E.Add _
      | E.Subtract _
      | E.Mult _
      | E.Div _
      | E.Log_and _
      | E.Log_or _
      | E.Equal _
      | E.Not_equal _
      | E.Gt _
      | E.Lt _
      | E.Gte _
      | E.Lte _
      | E.Mod _
      | E.Heredoc _
      | E.Heredoc' _
      | E.Template_heredoc _
      | E.Ellipsis _ -> None
    in
    let only_attrs steps =
      let rec aux acc = function
        | [] -> Some (CCList.rev acc)
        | Step.Attr s :: rest -> aux (s :: acc) rest
        | Step.Idx_int _ :: _ | Step.Idx_string _ :: _ -> None
      in
      aux [] steps
    in
    match walk [] expr with
    | None -> None
    | Some (type_, Step.Attr name :: rest) ->
        let index, after_index =
          match rest with
          | Step.Idx_int n :: r -> (Index.Int n, r)
          | Step.Idx_string s :: r -> (Index.String s, r)
          | Step.Attr _ :: _ | [] -> (Index.None, rest)
        in
        CCOption.map (fun attr_path -> { type_; name; index; attr_path }) (only_attrs after_index)
    | Some (_, (Step.Idx_int _ :: _ | Step.Idx_string _ :: _ | [])) -> None
end

module Tests = struct
  let reads_of_var = reads_of_var
end
