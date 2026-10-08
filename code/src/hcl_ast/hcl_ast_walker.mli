(** Generic recursive walkers over the HCL expression and body AST. *)

(** [map_in_expr f expr] applies [f] to [expr]. If [f] returns [Some replacement], that value is
    returned {b without} further recursion — the replacement is considered final. If [f] returns
    [None], [expr]'s immediate children are walked recursively with the same [f]. *)
val map_in_expr :
  (Hcl_parser_value.Expr.t -> Hcl_parser_value.Expr.t option) ->
  Hcl_parser_value.Expr.t ->
  Hcl_parser_value.Expr.t

(** [map_accum_in_expr f acc expr] is {!map_in_expr} with an accumulator that flows through the walk
    in evaluation order, left to right. [f] sees the accumulator of the walk so far. When it returns
    [Some (acc, replacement)], the walk uses both and does not recurse into the replacement. When it
    returns [None], the walk recurses into the children of [expr]. A caller uses it to carry a
    state, for example a budget, down a rewrite and back, without a mutable value. *)
val map_accum_in_expr :
  ('a -> Hcl_parser_value.Expr.t -> ('a * Hcl_parser_value.Expr.t) option) ->
  'a ->
  Hcl_parser_value.Expr.t ->
  'a * Hcl_parser_value.Expr.t

(** [map_in_template_part f part] walks the expressions embedded in [part] (and recursively into
    nested template parts for [If_directive] / [For_directive] bodies), applying [f] via
    [map_in_expr]. Strip-marker and vars metadata is preserved as-is. *)
val map_in_template_part :
  (Hcl_parser_value.Expr.t -> Hcl_parser_value.Expr.t option) ->
  Hcl_parser_value.Template_part.t ->
  Hcl_parser_value.Template_part.t

(** [map_in_body f ast] walks every expression in [ast] (inside attributes and nested block bodies)
    with [map_in_expr f]. Block structure and block labels are preserved as-is — labels carry no
    expressions. *)
val map_in_body :
  (Hcl_parser_value.Expr.t -> Hcl_parser_value.Expr.t option) ->
  Hcl_parser_value.t list ->
  Hcl_parser_value.t list

(** [fold_in_expr f init expr] is a left-to-right depth-first fold over an HCL expression. The
    callback is invoked on the expression itself before its children. Returning [`Continue acc]
    recurses into children with the new accumulator; returning [`Stop acc] halts traversal of the
    current branch. *)
val fold_in_expr :
  ('a -> Hcl_parser_value.Expr.t -> [ `Continue of 'a | `Stop of 'a ]) ->
  'a ->
  Hcl_parser_value.Expr.t ->
  'a
