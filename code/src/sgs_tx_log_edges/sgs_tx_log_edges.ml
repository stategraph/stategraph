module Edge = Sgs_tx_log_data.Edge

let qualify_address module_address addr = module_address ^ "." ^ addr

(* Resolve a [module.<name>.<attr>] reference to the fully qualified child
   output address [module.<name>.output.<attr>] (the address under which the
   child output node is stored), returning [None] for any other shape.

   The address construction is delegated to [Sg_tf_references.address_of_reference]
   so there is a single source of truth for the [module.X.attr ->
   module.X.output.attr] shape (pinned by the [addresses_module_output] tests);
   this function only narrows that resolver to the module-output case so the
   caller can decide whether to emit the resolved child-output edge. *)
let rewrite_module_output_ref ref_ =
  match ref_ with
  | "module" :: _ :: attr :: _ when attr <> "module" -> Sg_tf_references.address_of_reference ref_
  | _ -> None

(* Emit one edge JSON object per (qualified target address, attr_path).
   Each edge captures a single reference from a consumer HCL node to a target,
   in the structured shape the cone walk's substitution decision joins on.
   [refs] is the raw [Reference_set] from [Sg_tf_references.references] /
   [depends_on_references]; the function applies [rewrite_module_output_ref]
   (emitting two edges where applicable — one to the truncated module base,
   one to the resolved child output) and module-address qualification.
   [from_depends_on] tags depends_on-sourced refs so the cone walk can skip
   them when deciding substitution but still rewrite them at render time. *)
let edges_of_references ~module_address ~from_depends_on ~selectors refs =
  let qualify s = CCOption.map_or ~default:s (fun mp -> qualify_address mp s) module_address in
  (* The SELECTOR that a reference carries, when the expression named one member of what it reads
     with no evaluation: [p["K"]], [p[0]], or [lookup(p, "K", d)]. See
     [Sg_tf_references.selectors]. It goes on [index_kind] and [index_val], which no step of the
     current walk reads, thus a record of it changes no bundle. It lets the second walk ask "did the
     member that THIS consumer reads move", and not "did anything in the producer move". *)
  let selector_of ref_ = CCList.assoc_opt ~eq:(CCList.equal CCString.equal) ref_ selectors in
  let index_of_selector = function
    | None -> (`Null, `Null)
    | Some (Sg_tf_references.Selector.Key k) -> (`String "string", `String k)
    | Some (Sg_tf_references.Selector.Index n) -> (`String "int", `Int n)
  in
  let edge ?selector ?(names_a_node = true) ~to_addr ~attr_path ~resolvable () =
    let index_kind, index_val = index_of_selector selector in
    {
      Edge.to_addr;
      attr_path;
      index_kind;
      index_val;
      is_bare = CCList.is_empty attr_path;
      (* Whether [to_addr] names a node.  Derived beside the address it describes, by
         {!Sg_tf_references.names_a_node}, so that the apply can drop an edge which points at
         nothing without matching the address as text -- RFD 1008 forbids that of SQL.

         It defaults to true here and reads as true when absent downstream, because absent is what a
         transaction an older client staged has, and the rule this replaces kept every edge whose
         address it could not fault. *)
      names_a_node = Some names_a_node;
      resolvable;
      from_depends_on;
    }
  in
  (* A read that names the module and no output depends on EVERY output that the module declares.
     It has the same address as the bare block edge, with a mark on [attr_path]. See
     [Sg_tf_references.module_all_outputs_attr]. *)
  let all_outputs_edge name =
    edge
      ~to_addr:(qualify ("module." ^ name))
      ~attr_path:[ Sg_tf_references.module_all_outputs_attr ]
      ~resolvable:false
      ()
  in
  Sg_tf_references.Reference_set.fold
    (fun ref_ acc ->
      let is_wildcard = CCList.mem ~eq:CCString.equal "*" ref_ in
      match Sg_tf_references.address_of_reference ref_ with
      | None ->
          (* Dynamic module-output lookups ([["module"; X; "*"]]) cannot be
             resolved to a single concrete path; emit a bare unresolvable edge
             to the module base so the cone walk still follows the structural
             dependency but never substitutes. *)
          if is_wildcard then
            match ref_ with
            | "module" :: name :: _ ->
                edge ~to_addr:(qualify ("module." ^ name)) ~attr_path:[] ~resolvable:false ()
                :: all_outputs_edge name
                :: acc
            | _ -> acc
          else acc
      | Some base_addr ->
          (* Derived structurally, next to the address it pairs with — never by
             re-splitting a joined reference, which would shatter a map key that
             itself contains a "." (["main.tf"], ["example.com"]).  See
             [Sg_tf_references.attr_path_of_reference] for the full rationale. *)
          let attr_path = Sg_tf_references.attr_path_of_reference ref_ in
          let selector = selector_of ref_ in
          let base_edge =
            edge
              ?selector
              ~names_a_node:(Sg_tf_references.names_a_node ref_)
              ~to_addr:(qualify base_addr)
              ~attr_path
              ~resolvable:true
              ()
          in
          let extra =
            CCOption.map_or
              ~default:[]
              (fun rewritten ->
                (* rewrite_module_output_ref synthesises
                   "module.<name>.output.<attr>" from a reference of shape
                   ["module"; <name>; <attr>; <rest>...]; the [<rest>] tail
                   becomes the attr_path on the resolved child-output edge. *)
                match ref_ with
                | "module" :: _ :: _ :: rest ->
                    [
                      edge
                        ?selector
                        ~to_addr:(qualify rewritten)
                        ~attr_path:rest
                        ~resolvable:true
                        ();
                    ]
                | _ -> [])
              (rewrite_module_output_ref ref_)
          in
          (* Module-block fallback: a [module.X.attr] reference also needs
             to pull the enclosing [module "X"] call block into the
             subgraph, otherwise the reified HCL references an undeclared
             module.  For local modules the cone walk usually reaches the
             module block via parent_module_committed on a child node, but
             that path only fires during blast; for a cone seed that
             references [module.X.attr] without anyone reaching back to
             [module.X] via blast (the failure mode integration tests
             surface as "Reference to undeclared module"), we need an
             explicit bare edge to [module.X].  Mirror of the fallback
             [Sg_tf_references.addresses] used to add. *)
          let module_block_fallback =
            match ref_ with
            | "module" :: name :: _ :: _ ->
                [ edge ~to_addr:(qualify ("module." ^ name)) ~attr_path:[] ~resolvable:true () ]
            | _ -> []
          in
          (* [module.X] with no attribute: the whole module object. *)
          let all_outputs =
            match ref_ with
            | [ "module"; name ] -> [ all_outputs_edge name ]
            | _ -> []
          in
          (* THE BASE EDGE IS THE SAME READ, WRITTEN WHOLE. For a reference with the shape
             [module.X.out.a], the base address and the rewritten address are ONE address, because
             [Sg_tf_references.address_of_reference] resolves the module read to the output node.
             [attr_path_of_reference] gives [] for the module case, by design. Thus two edges reach
             the same node, one that names ["a"] and one that names the whole value, and the server
             admits a consumer of the whole value whatever moved.

             A walk that narrows one edge at a time cannot see past that. The empty path is a
             whole-value read that no guard can refuse, thus the narrow edge never gets its answer.
             Measured on per_attr/child_output_a: the server reifies each reader of each attribute,
             and the narrowing does nothing.

             This code drops the base edge only where [extra] carries a tail to that same address
             that is NOT empty, which is the one case where the two edges disagree. A true whole
             read, [module.X.out], has an empty tail and keeps its edge. A consumer that reads BOTH
             spellings still writes the whole-value edge from its own reference. *)
          let base_edges =
            match (rewrite_module_output_ref ref_, ref_) with
            | Some rewritten, "module" :: _ :: _ :: _ :: _
              when CCString.equal (qualify rewritten) (qualify base_addr) -> []
            | _ -> [ base_edge ]
          in
          (base_edges @ extra) @ module_block_fallback @ all_outputs @ acc)
    refs
    []
