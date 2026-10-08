(* One walk serves both maps: [map_in_expr] is [map_accum_in_expr] with a unit accumulator. *)
let rec map_accum_in_expr f acc expr =
  match f acc expr with
  | Some replaced -> replaced
  | None -> recurse_map_accum_in_expr f acc expr

and recurse_map_accum_in_expr f acc expr =
  let module E = Hcl_parser_value.Expr in
  let go = map_accum_in_expr f in
  let go_list acc es = CCList.fold_map go acc es in
  let go_opt acc = function
    | None -> (acc, None)
    | Some e ->
        let acc, e = go acc e in
        (acc, Some e)
  in
  let go2 acc a b k =
    let acc, a = go acc a in
    let acc, b = go acc b in
    (acc, k a b)
  in
  match expr with
  | E.Id _ | E.String _ | E.Int _ | E.Float _ | E.Bool _ | E.Null | E.Splat
  | E.Heredoc (_, _)
  | E.Heredoc' (_, _) -> (acc, expr)
  | E.Template parts ->
      let acc, parts = CCList.fold_map (map_accum_in_template_part f) acc parts in
      (acc, E.Template parts)
  | E.Template_heredoc (marker, parts) ->
      let acc, parts = CCList.fold_map (map_accum_in_template_part f) acc parts in
      (acc, E.Template_heredoc (marker, parts))
  | E.Tuple items ->
      let acc, items = go_list acc items in
      (acc, E.Tuple items)
  | E.Object pairs ->
      let acc, pairs =
        CCList.fold_map
          (fun acc (k, v) ->
            let acc, k = map_accum_in_obj_key f acc k in
            let acc, v = go acc v in
            (acc, (k, v)))
          acc
          pairs
      in
      (acc, E.Object pairs)
  | E.Fun_call (name, args) ->
      let acc, args = go_list acc args in
      (acc, E.Fun_call (name, args))
  | E.For_tuple { identifiers; input; output; cond } ->
      let acc, input = go acc input in
      let acc, output = go acc output in
      let acc, cond = go_opt acc cond in
      (acc, E.For_tuple { identifiers; input; output; cond })
  | E.For_object { identifiers; input; key_output; value_output; cond } ->
      let acc, input = go acc input in
      let acc, key_output = go acc key_output in
      let acc, value_output = go acc value_output in
      let acc, cond = go_opt acc cond in
      (acc, E.For_object { identifiers; input; key_output; value_output; cond })
  | E.Cond { if_; then_; else_ } ->
      let acc, if_ = go acc if_ in
      let acc, then_ = go acc then_ in
      let acc, else_ = go acc else_ in
      (acc, E.Cond { if_; then_; else_ })
  | E.Idx (e, idx) -> go2 acc e idx (fun e idx -> E.Idx (e, idx))
  | E.Attr (e, attr) ->
      let acc, e = go acc e in
      (acc, E.Attr (e, attr))
  | E.Not e ->
      let acc, e = go acc e in
      (acc, E.Not e)
  | E.Minus e ->
      let acc, e = go acc e in
      (acc, E.Minus e)
  | E.Add (a, b) -> go2 acc a b (fun a b -> E.Add (a, b))
  | E.Subtract (a, b) -> go2 acc a b (fun a b -> E.Subtract (a, b))
  | E.Mult (a, b) -> go2 acc a b (fun a b -> E.Mult (a, b))
  | E.Div (a, b) -> go2 acc a b (fun a b -> E.Div (a, b))
  | E.Log_and (a, b) -> go2 acc a b (fun a b -> E.Log_and (a, b))
  | E.Log_or (a, b) -> go2 acc a b (fun a b -> E.Log_or (a, b))
  | E.Equal (a, b) -> go2 acc a b (fun a b -> E.Equal (a, b))
  | E.Not_equal (a, b) -> go2 acc a b (fun a b -> E.Not_equal (a, b))
  | E.Gt (a, b) -> go2 acc a b (fun a b -> E.Gt (a, b))
  | E.Lt (a, b) -> go2 acc a b (fun a b -> E.Lt (a, b))
  | E.Gte (a, b) -> go2 acc a b (fun a b -> E.Gte (a, b))
  | E.Lte (a, b) -> go2 acc a b (fun a b -> E.Lte (a, b))
  | E.Mod (a, b) -> go2 acc a b (fun a b -> E.Mod (a, b))
  | E.Ellipsis e ->
      let acc, e = go acc e in
      (acc, E.Ellipsis e)

and map_accum_in_obj_key f acc k =
  let module K = Hcl_parser_value.Obj_key in
  match k with
  | K.Bare _ | K.Quoted _ -> (acc, k)
  | K.Template parts ->
      let acc, parts = CCList.fold_map (map_accum_in_template_part f) acc parts in
      (acc, K.Template parts)
  | K.Computed e ->
      let acc, e = map_accum_in_expr f acc e in
      (acc, K.Computed e)
  | K.Expr e ->
      let acc, e = map_accum_in_expr f acc e in
      (acc, K.Expr e)

and map_accum_in_template_part f acc part =
  let module T = Hcl_parser_value.Template_part in
  let parts acc ps = CCList.fold_map (map_accum_in_template_part f) acc ps in
  match part with
  | T.Literal _ -> (acc, part)
  | T.Interpolation { expr; strip_before; strip_after } ->
      let acc, expr = map_accum_in_expr f acc expr in
      (acc, T.Interpolation { expr; strip_before; strip_after })
  | T.If_directive { cond; then_; else_; strip_before; strip_after } ->
      let acc, cond = map_accum_in_expr f acc cond in
      let acc, then_ = parts acc then_ in
      let acc, else_ =
        match else_ with
        | None -> (acc, None)
        | Some ps ->
            let acc, ps = parts acc ps in
            (acc, Some ps)
      in
      (acc, T.If_directive { cond; then_; else_; strip_before; strip_after })
  | T.For_directive { vars; input; body; strip_before; strip_after } ->
      let acc, input = map_accum_in_expr f acc input in
      let acc, body = parts acc body in
      (acc, T.For_directive { vars; input; body; strip_before; strip_after })

let unit_f f () e = CCOption.map (fun r -> ((), r)) (f e)
let map_in_expr f expr = snd (map_accum_in_expr (unit_f f) () expr)
let map_in_template_part f part = snd (map_accum_in_template_part (unit_f f) () part)

let fold_in_expr f init expr =
  let module E = Hcl_parser_value.Expr in
  let module K = Hcl_parser_value.Obj_key in
  let module T = Hcl_parser_value.Template_part in
  let rec go acc e =
    match f acc e with
    | `Stop a -> a
    | `Continue acc -> (
        match e with
        | E.Id _
        | E.String _
        | E.Int _
        | E.Float _
        | E.Bool _
        | E.Null
        | E.Splat
        | E.Heredoc _
        | E.Heredoc' _ -> acc
        | E.Template parts | E.Template_heredoc (_, parts) -> CCList.fold_left go_template acc parts
        | E.Tuple items -> CCList.fold_left go acc items
        | E.Object pairs ->
            CCList.fold_left
              (fun acc (k, v) ->
                let acc = go_obj_key acc k in
                go acc v)
              acc
              pairs
        | E.Fun_call (_, args) -> CCList.fold_left go acc args
        | E.For_tuple { input; output; cond; _ } ->
            let acc = go acc input in
            let acc = go acc output in
            CCOption.map_or ~default:acc (go acc) cond
        | E.For_object { input; key_output; value_output; cond; _ } ->
            let acc = go acc input in
            let acc = go acc key_output in
            let acc = go acc value_output in
            CCOption.map_or ~default:acc (go acc) cond
        | E.Cond { if_; then_; else_ } ->
            let acc = go acc if_ in
            let acc = go acc then_ in
            go acc else_
        | E.Idx (a, b)
        | E.Add (a, b)
        | E.Subtract (a, b)
        | E.Mult (a, b)
        | E.Div (a, b)
        | E.Log_and (a, b)
        | E.Log_or (a, b)
        | E.Equal (a, b)
        | E.Not_equal (a, b)
        | E.Gt (a, b)
        | E.Lt (a, b)
        | E.Gte (a, b)
        | E.Lte (a, b)
        | E.Mod (a, b) ->
            let acc = go acc a in
            go acc b
        | E.Attr (e, _) | E.Not e | E.Minus e | E.Ellipsis e -> go acc e)
  and go_obj_key acc k =
    match k with
    | K.Bare _ | K.Quoted _ -> acc
    | K.Template parts -> CCList.fold_left go_template acc parts
    | K.Computed e | K.Expr e -> go acc e
  and go_template acc part =
    match part with
    | T.Literal _ -> acc
    | T.Interpolation { expr; _ } -> go acc expr
    | T.If_directive { cond; then_; else_; _ } ->
        let acc = go acc cond in
        let acc = CCList.fold_left go_template acc then_ in
        CCOption.map_or ~default:acc (CCList.fold_left go_template acc) else_
    | T.For_directive { input; body; _ } ->
        let acc = go acc input in
        CCList.fold_left go_template acc body
  in
  go init expr

let map_in_body f ast =
  let rec map_item item =
    match item with
    | Hcl_parser_value.Block { type_; labels; body } ->
        Hcl_parser_value.Block { type_; labels; body = CCList.map map_item body }
    | Hcl_parser_value.Attribute (name, expr) ->
        Hcl_parser_value.Attribute (name, map_in_expr f expr)
  in
  CCList.map map_item ast
