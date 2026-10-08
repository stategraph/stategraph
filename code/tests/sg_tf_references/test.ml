module Rs = Sg_tf_references.Reference_set

(** Parse HCL string and collect references (excluding each/count/path) *)
let refs_of_string s =
  let values = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string s) in
  CCList.fold_left (fun acc v -> Rs.union acc (Sg_tf_references.references v)) Rs.empty values

(** Parse HCL string and collect all references (including each/count/path) *)
let refs_of_string' s =
  let values = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string s) in
  CCList.fold_left (fun acc v -> Rs.union acc (Sg_tf_references.references' v)) Rs.empty values

let pp_reference_set fmt s =
  Format.fprintf
    fmt
    "{%a}"
    (Format.pp_print_list
       ~pp_sep:(fun fmt () -> Format.fprintf fmt ", ")
       (fun fmt l -> Format.fprintf fmt "[%s]" (CCString.concat "; " l)))
    (Rs.to_list s)

let assert_refs expected actual = Oth.Assert.eq ~eq:Rs.equal ~pp:pp_reference_set expected actual
let rs_of_list l = Rs.of_list l

(* Expression tests *)

let literal_no_refs =
  Oth.test ~name:"literal_no_refs" (fun _ ->
      let actual = refs_of_string {|x = "hello"|} in
      assert_refs (rs_of_list []) actual;
      ())

let numeric_literals =
  Oth.test ~name:"numeric_literals" (fun _ ->
      let actual = refs_of_string {|x = 1 + 2|} in
      assert_refs (rs_of_list []) actual;
      ())

let simple_id_ref =
  Oth.test ~name:"simple_id_ref" (fun _ ->
      let actual = refs_of_string {|x = foo|} in
      assert_refs (rs_of_list [ [ "foo" ] ]) actual;
      ())

let dotted_ref =
  Oth.test ~name:"dotted_ref" (fun _ ->
      let actual = refs_of_string {|x = aws_instance.main|} in
      assert_refs (rs_of_list [ [ "aws_instance"; "main" ] ]) actual;
      ())

let deep_dotted_ref =
  Oth.test ~name:"deep_dotted_ref" (fun _ ->
      let actual = refs_of_string {|x = aws_instance.main.id|} in
      assert_refs (rs_of_list [ [ "aws_instance"; "main"; "id" ] ]) actual;
      ())

let multiple_refs_in_expr =
  Oth.test ~name:"multiple_refs_in_expr" (fun _ ->
      let actual = refs_of_string {|x = a + b|} in
      assert_refs (rs_of_list [ [ "a" ]; [ "b" ] ]) actual;
      ())

let index_ref =
  Oth.test ~name:"index_ref" (fun _ ->
      let actual = refs_of_string {|x = list[0]|} in
      assert_refs (rs_of_list [ [ "list" ] ]) actual;
      ())

(* Attribute-only splat ([e.*]) is transparent: the reference is the splatted
   base.  Regression for the bug where the base was dropped, leaving a module
   block referencing a local whose declaration was pruned from the reified
   subgraph (tofu: "undeclared local value"). *)
let attr_splat_ref =
  Oth.test ~name:"attr_splat_ref" (fun _ ->
      let actual = refs_of_string {|x = local.xs.*.name|} in
      assert_refs (rs_of_list [ [ "local"; "xs" ] ]) actual;
      ())

let attr_splat_bare_ref =
  Oth.test ~name:"attr_splat_bare_ref" (fun _ ->
      let actual = refs_of_string {|x = local.xs.*|} in
      assert_refs (rs_of_list [ [ "local"; "xs" ] ]) actual;
      ())

(* Index splat ([e[*]]) already worked; kept as a sibling control. *)
let index_splat_ref =
  Oth.test ~name:"index_splat_ref" (fun _ ->
      let actual = refs_of_string {|x = local.xs[*].name|} in
      assert_refs (rs_of_list [ [ "local"; "xs"; "name" ] ]) actual;
      ())

(* A heredoc body is lexed as a raw string and is not run through the template
   transform, so its [${...}] interpolations must be parsed here to collect
   their references.  Regression for the same dropped-reference bug as the attr
   splat (a heredoc-interpolated local pruned from the reified subgraph). *)
let heredoc_interp_ref =
  Oth.test ~name:"heredoc_interp_ref" (fun _ ->
      let actual = refs_of_string "x = <<EOT\n${local.foo}\nEOT\n" in
      assert_refs (rs_of_list [ [ "local"; "foo" ] ]) actual;
      ())

let heredoc_indented_interp_ref =
  Oth.test ~name:"heredoc_indented_interp_ref" (fun _ ->
      let actual = refs_of_string "x = <<-EOT\n${local.bar}\nEOT\n" in
      assert_refs (rs_of_list [ [ "local"; "bar" ] ]) actual;
      ())

let heredoc_multi_ref =
  Oth.test ~name:"heredoc_multi_ref" (fun _ ->
      let actual = refs_of_string "x = <<EOT\n${local.a}-${var.b}\nEOT\n" in
      assert_refs (rs_of_list [ [ "local"; "a" ]; [ "var"; "b" ] ]) actual;
      ())

let heredoc_no_interp =
  Oth.test ~name:"heredoc_no_interp" (fun _ ->
      let actual = refs_of_string "x = <<EOT\njust literal text\nEOT\n" in
      assert_refs (rs_of_list []) actual;
      ())

let not_ref =
  Oth.test ~name:"not_ref" (fun _ ->
      let actual = refs_of_string {|x = !flag|} in
      assert_refs (rs_of_list [ [ "flag" ] ]) actual;
      ())

let conditional_refs =
  Oth.test ~name:"conditional_refs" (fun _ ->
      let actual = refs_of_string {|x = c ? t : e|} in
      assert_refs (rs_of_list [ [ "c" ]; [ "t" ]; [ "e" ] ]) actual;
      ())

let tuple_refs =
  Oth.test ~name:"tuple_refs" (fun _ ->
      let actual = refs_of_string {|x = [a, "literal", b]|} in
      assert_refs (rs_of_list [ [ "a" ]; [ "b" ] ]) actual;
      ())

let object_refs =
  Oth.test ~name:"object_refs" (fun _ ->
      let actual = refs_of_string "x = {\n  key = resource.value\n}" in
      assert_refs (rs_of_list [ [ "resource"; "value" ] ]) actual;
      ())

let func_call_refs =
  Oth.test ~name:"func_call_refs" (fun _ ->
      let actual = refs_of_string {|x = toset(a, b)|} in
      assert_refs (rs_of_list [ [ "a" ]; [ "b" ] ]) actual;
      ())

let func_call_ellipsis_refs =
  Oth.test ~name:"func_call_ellipsis_refs" (fun _ ->
      let actual = refs_of_string {|x = merge(defaults, overrides...)|} in
      assert_refs (rs_of_list [ [ "defaults" ]; [ "overrides" ] ]) actual;
      ())

let for_object_grouping_refs =
  Oth.test ~name:"for_object_grouping_refs" (fun _ ->
      let actual = refs_of_string {|x = {for k, v in input : k => v...}|} in
      assert_refs (rs_of_list [ [ "input" ] ]) actual;
      ())

let for_tuple_bound_vars =
  Oth.test ~name:"for_tuple_bound_vars" (fun _ ->
      let actual = refs_of_string {|x = [for item in list : item]|} in
      assert_refs (rs_of_list [ [ "list" ] ]) actual;
      ())

let for_object_bound_vars =
  Oth.test ~name:"for_object_bound_vars" (fun _ ->
      let actual = refs_of_string {|x = {for k, v in map : k => v}|} in
      assert_refs (rs_of_list [ [ "map" ] ]) actual;
      ())

(* A comprehension over a module collection contributes ONLY the coarse collection reference, and
   that is this layer's final answer.

   Whether [sa.service_account_id] names an output at all depends on what [module.child] is: a map of
   module INSTANCES (iterated), where the read names one output, or an object of OUTPUTS
   (non-iterated), where [sa] is an output value and the read reaches inside it. That is a property
   of the module BLOCK, which this library never sees -- it is a pure function of one already-parsed
   value.

   The refinement therefore belongs to [Sg_tx_builder]'s ref-hints visitor, which knows
   [iterated_modules] and the child's declared outputs, and which already resolves the sibling cases
   ([module.X[idx]], [keys(module.X)], and locals that alias a module). {!Sg_tf_references.Tests.reads_of_var}
   below is the walker it uses to see the reads. Do not "fix" this test by teaching the extractor to
   guess. *)
let for_object_module_collection_stays_coarse =
  Oth.test ~name:"for_object_module_collection_stays_coarse" (fun _ ->
      let actual =
        refs_of_string
          {|locals {
             m = {for name, sa in module.child : name => {
               account_id = sa.service_account_id
               email      = sa.service_account_email
             }}
           }|}
      in
      assert_refs (rs_of_list [ [ "module"; "child" ] ]) actual;
      ())

(* --- reads_of_var: how a comprehension's loop variable is consumed --------------------------- *)

(** Parse [x = <expr>] and hand back the expression, for the walkers that take one. *)
let expr_of_string s =
  let values = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string ("x = " ^ s)) in
  match values with
  | [ Hcl_parser_value.Attribute ("x", expr) ] -> expr
  | _ -> Oth.Assert.false_ ("expected a single attribute from: " ^ s)

let pp_var_reads fmt { Sg_tf_references.Var_reads.attrs; whole } =
  Format.fprintf fmt "{attrs = [%s]; whole = %b}" (CCString.concat "; " attrs) whole

let pp_comprehension fmt = function
  | None -> Format.fprintf fmt "not a comprehension"
  | Some (var, reads) -> Format.fprintf fmt "var = %s; reads = %a" var pp_var_reads reads

let var_reads ?(whole = false) attrs = { Sg_tf_references.Var_reads.attrs; whole }

(* Assert which identifier a comprehension binds as its VALUE, and how the body reads it. [input] is
   not compared -- the caller matches on it separately. *)
let assert_comprehension ~expected s =
  let actual =
    CCOption.map
      (fun { Sg_tf_references.Comprehension.var; input = _; reads } -> (var, reads))
      (Sg_tf_references.comprehension_of_expr (expr_of_string s))
  in
  Oth.Assert.eq ~eq:(fun a b -> Stdlib.compare a b = 0) ~pp:pp_comprehension expected actual

let assert_var_reads ~var ~expected s =
  let actual = Sg_tf_references.Tests.reads_of_var ~var (expr_of_string s) in
  Oth.Assert.eq ~eq:(fun a b -> Stdlib.compare a b = 0) ~pp:pp_var_reads expected actual

let comprehension_two_identifiers_binds_the_value =
  Oth.test ~name:"comprehension_two_identifiers_binds_the_value" (fun _ ->
      (* [for k, sa in coll]: [k] is the key and [sa] the value.  Binding the wrong one would read
         the body's attributes off a string. *)
      assert_comprehension
        ~expected:(Some ("sa", var_reads [ "account_id"; "email" ]))
        {|{for k, sa in module.child : k => { a = sa.account_id, b = sa.email }}|};
      ())

let comprehension_one_identifier_binds_the_value =
  Oth.test ~name:"comprehension_one_identifier_binds_the_value" (fun _ ->
      assert_comprehension
        ~expected:(Some ("sa", var_reads [ "id" ]))
        {|[for sa in module.child : sa.id]|};
      ())

let comprehension_not_a_comprehension =
  Oth.test ~name:"comprehension_not_a_comprehension" (fun _ ->
      assert_comprehension ~expected:None {|module.child.id|};
      ())

let comprehension_whole_value_read =
  Oth.test ~name:"comprehension_whole_value_read" (fun _ ->
      (* The value is passed on entire: nothing names a single member of it. *)
      assert_comprehension
        ~expected:(Some ("sa", var_reads ~whole:true []))
        {|{for k, sa in module.child : k => sa}|};
      ())

let comprehension_attrs_and_whole =
  Oth.test ~name:"comprehension_attrs_and_whole" (fun _ ->
      assert_comprehension
        ~expected:(Some ("sa", var_reads ~whole:true [ "id" ]))
        {|{for k, sa in module.child : k => merge(sa, { x = sa.id })}|};
      ())

let comprehension_nested_attr_takes_head =
  Oth.test ~name:"comprehension_nested_attr_takes_head" (fun _ ->
      (* [sa.net.id] reads the member [net]; what is read inside it is not this variable's business. *)
      assert_comprehension
        ~expected:(Some ("sa", var_reads [ "net" ]))
        {|[for sa in module.child : sa.net.id]|};
      ())

let comprehension_index_is_whole =
  Oth.test ~name:"comprehension_index_is_whole" (fun _ ->
      (* A dynamic index names no member statically, so the whole value is in play. *)
      assert_comprehension
        ~expected:(Some ("sa", var_reads ~whole:true []))
        {|[for sa in module.child : sa[local.k]]|};
      ())

let comprehension_splat_is_whole =
  Oth.test ~name:"comprehension_splat_is_whole" (fun _ ->
      assert_comprehension
        ~expected:(Some ("sa", var_reads ~whole:true []))
        {|[for sa in module.child : sa.*]|};
      ())

let comprehension_reads_in_cond =
  Oth.test ~name:"comprehension_reads_in_cond" (fun _ ->
      (* The [if] guard reads the variable too, and is part of the comprehension's body scope. *)
      assert_comprehension
        ~expected:(Some ("sa", var_reads [ "enabled"; "id" ]))
        {|[for sa in module.child : sa.id if sa.enabled]|};
      ())

let comprehension_shadowed_by_inner_comprehension =
  Oth.test ~name:"comprehension_shadowed_by_inner_comprehension" (fun _ ->
      (* The inner [sa] is a different variable, so [sa.inner] belongs to it.  The inner
         comprehension's INPUT is evaluated in the outer scope, so [sa.nets] is attributed here. *)
      assert_comprehension
        ~expected:(Some ("sa", var_reads [ "nets" ]))
        {|[for sa in module.child : [for sa in sa.nets : sa.inner]]|};
      ())

let comprehension_untouched_variable =
  Oth.test ~name:"comprehension_untouched_variable" (fun _ ->
      assert_comprehension
        ~expected:(Some ("sa", var_reads []))
        {|{for k, sa in module.child : k => local.other}|};
      ())

let reads_of_var_template_directive_shadows =
  Oth.test ~name:"reads_of_var_template_directive_shadows" (fun _ ->
      (* A template [%{ for }] rebinds the name too, so reads inside its body belong to the inner
         binding.  [Template_part.For_directive.vars] is (value, optional key) -- the OPPOSITE order
         from an expression comprehension -- and shadowing covers both, so this holds either way. *)
      assert_var_reads
        ~var:"sa"
        ~expected:(var_reads [])
        {|"%{ for k, sa in module.child }${sa.id}%{ endfor }"|};
      ())

let reads_of_var_template_directive_input_is_outer =
  Oth.test ~name:"reads_of_var_template_directive_input_is_outer" (fun _ ->
      (* The directive's INPUT is evaluated before the rebinding takes effect. *)
      assert_var_reads
        ~var:"sa"
        ~expected:(var_reads [ "nets" ])
        {|"%{ for n in sa.nets }${n}%{ endfor }"|};
      ())

let for_with_cond =
  Oth.test ~name:"for_with_cond" (fun _ ->
      let actual = refs_of_string {|x = [for item in list : item if item != ""]|} in
      assert_refs (rs_of_list [ [ "list" ] ]) actual;
      ())

let for_external_ref_in_cond =
  Oth.test ~name:"for_external_ref_in_cond" (fun _ ->
      let actual = refs_of_string {|x = [for item in list : item if other]|} in
      assert_refs (rs_of_list [ [ "list" ]; [ "other" ] ]) actual;
      ())

(* Block tests *)

let resource_block =
  Oth.test ~name:"resource_block" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_instance" "main" {
             ami = var.ami_id
             instance_type = var.instance_type
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "ami_id" ]; [ "var"; "instance_type" ] ]) actual;
      ())

let nested_blocks =
  Oth.test ~name:"nested_blocks" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_security_group" "main" {
             name = var.sg_name
             ingress {
               from_port = var.port
             }
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "sg_name" ]; [ "var"; "port" ] ]) actual;
      ())

let block_with_mixed =
  Oth.test ~name:"block_with_mixed" (fun _ ->
      let actual =
        refs_of_string
          {|resource "null" "main" {
             a = var.x
             b = "literal"
             c = var.y
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "x" ]; [ "var"; "y" ] ]) actual;
      ())

let empty_block =
  Oth.test ~name:"empty_block" (fun _ ->
      let actual = refs_of_string {|resource "aws_instance" "main" {
            }|} in
      assert_refs (rs_of_list []) actual;
      ())

(* [lifecycle.ignore_changes] lists attribute names of the resource itself, not
   references; extracting refs from them would invent bogus dependency edges (and
   the evaluator would drop them with Variable_not_found). *)
let lifecycle_ignore_changes_not_ref =
  Oth.test ~name:"lifecycle_ignore_changes_not_ref" (fun _ ->
      let actual =
        refs_of_string'
          {|resource "random_id" "r" {
             byte_length = 8
             lifecycle {
               ignore_changes = [byte_length, keepers]
             }
           }|}
      in
      assert_refs (rs_of_list []) actual;
      ())

(* A provisioner's [when]/[on_failure] are keywords ([destroy]/[continue]), not
   references; real attributes in the same block (e.g. [command]) still flow. *)
let provisioner_when_on_failure_not_ref =
  Oth.test ~name:"provisioner_when_on_failure_not_ref" (fun _ ->
      let actual =
        refs_of_string'
          {|resource "null_resource" "n" {
             provisioner "local-exec" {
               when       = destroy
               on_failure = continue
               command    = var.cmd
             }
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "cmd" ] ]) actual;
      ())

(* A [variable] block's [type] is a type constraint (e.g. [string],
   [object({...})]), not a reference; extracting refs from it would invent bogus
   dependency edges to a resource/local named after a type keyword (and the
   evaluator would drop them with Variable_not_found). *)
let variable_type_not_ref =
  Oth.test ~name:"variable_type_not_ref" (fun _ ->
      let actual =
        refs_of_string'
          {|variable "cfg" {
             type    = object({ name = string, tags = map(string), size = number, on = bool })
             default = null
           }|}
      in
      assert_refs (rs_of_list []) actual;
      ())

let multiple_top_level =
  Oth.test ~name:"multiple_top_level" (fun _ ->
      let actual = refs_of_string {|a = var.x
                                    b = var.y|} in
      assert_refs (rs_of_list [ [ "var"; "x" ]; [ "var"; "y" ] ]) actual;
      ())

(* Template string tests *)

let template_single_interp =
  Oth.test ~name:"template_single_interp" (fun _ ->
      let actual = refs_of_string {|x = "hello ${var.name}"|} in
      assert_refs (rs_of_list [ [ "var"; "name" ] ]) actual;
      ())

let template_multiple_interps =
  Oth.test ~name:"template_multiple_interps" (fun _ ->
      let actual = refs_of_string {|x = "${var.prefix}-${var.suffix}"|} in
      assert_refs (rs_of_list [ [ "var"; "prefix" ]; [ "var"; "suffix" ] ]) actual;
      ())

let template_no_interp =
  Oth.test ~name:"template_no_interp" (fun _ ->
      let actual = refs_of_string {|x = "just a plain string"|} in
      assert_refs (rs_of_list []) actual;
      ())

let template_complex_expr =
  Oth.test ~name:"template_complex_expr" (fun _ ->
      let actual = refs_of_string {|x = "count is ${length(var.items)}"|} in
      assert_refs (rs_of_list [ [ "var"; "items" ] ]) actual;
      ())

let template_in_block =
  Oth.test ~name:"template_in_block" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_instance" "main" {
             tags = {
               Name = "web-${var.env}"
             }
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "env" ] ]) actual;
      ())

(* Cross-block reference tests *)

let resource_refs_resource =
  Oth.test ~name:"resource_refs_resource" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_subnet" "main" {
             vpc_id = aws_vpc.main.id
           }|}
      in
      assert_refs (rs_of_list [ [ "aws_vpc"; "main"; "id" ] ]) actual;
      ())

let resource_refs_variable =
  Oth.test ~name:"resource_refs_variable" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_instance" "main" {
             instance_type = var.instance_type
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "instance_type" ] ]) actual;
      ())

let module_ref =
  Oth.test ~name:"module_ref" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_instance" "main" {
             subnet_id = module.network.subnet_id
           }|}
      in
      assert_refs (rs_of_list [ [ "module"; "network"; "subnet_id" ] ]) actual;
      ())

let module_ref_splat =
  Oth.test ~name:"module_ref_splat" (fun _ ->
      (* Splat is transparent: module.grandchild[*].bar extracts the same
         reference as module.grandchild.bar. *)
      let actual = refs_of_string {|output "test" { value = module.grandchild[*].bar }|} in
      assert_refs (rs_of_list [ [ "module"; "grandchild"; "bar" ] ]) actual;
      ())

let module_ref_index =
  Oth.test ~name:"module_ref_index" (fun _ ->
      (* Integer index is transparent: module.grandchild[0].bar extracts the same
         reference as module.grandchild.bar. *)
      let actual = refs_of_string {|output "test" { value = module.grandchild[0].bar }|} in
      assert_refs (rs_of_list [ [ "module"; "grandchild"; "bar" ] ]) actual;
      ())

let module_ref_string_index =
  Oth.test ~name:"module_ref_string_index" (fun _ ->
      (* String index is transparent: module.grandchild["foo"].bar extracts the same
         reference as module.grandchild.bar. *)
      let actual = refs_of_string {|output "test" { value = module.grandchild["foo"].bar }|} in
      assert_refs (rs_of_list [ [ "module"; "grandchild"; "bar" ] ]) actual;
      ())

let module_ref_dynamic_index =
  Oth.test ~name:"module_ref_dynamic_index" (fun _ ->
      (* Dynamic index is transparent for the qualified name, and the index
         expression's own references are also collected. *)
      let actual =
        refs_of_string {|output "test" { value = module.grandchild[local.mylocal].bar }|}
      in
      assert_refs (rs_of_list [ [ "module"; "grandchild"; "bar" ]; [ "local"; "mylocal" ] ]) actual;
      ())

let local_dynamic_index =
  Oth.test ~name:"local_dynamic_index" (fun _ ->
      (* C4 regression guard: a dynamic index into a local map records the
         base collection [local.m] (so the subgraph still seeds it) plus the
         index expression's own ref [var.k] — the edge is never dropped. *)
      let actual = refs_of_string {|x = local.m[var.k]|} in
      assert_refs (rs_of_list [ [ "local"; "m" ]; [ "var"; "k" ] ]) actual;
      ())

let resource_dynamic_index =
  Oth.test ~name:"resource_dynamic_index" (fun _ ->
      (* C4 regression guard: a dynamic index on a managed resource keeps the
         base address [aws_instance.foo.id] and collects the index ref. *)
      let actual = refs_of_string {|x = aws_instance.foo[var.i].id|} in
      assert_refs (rs_of_list [ [ "aws_instance"; "foo"; "id" ]; [ "var"; "i" ] ]) actual;
      ())

(* A [for_each] instance key on a managed resource is transparent: the key selects
   an instance, it is not part of the dependency path.  Sibling of
   [module_ref_string_index], which pins the same invariant for [module] roots —
   this one covers the resource/data roots, the commoner [for_each] shape. *)
let resource_string_index_transparent =
  Oth.test ~name:"resource_string_index_transparent" (fun _ ->
      let actual = refs_of_string {|x = aws_instance.foo["us-east"].id|} in
      assert_refs (rs_of_list [ [ "aws_instance"; "foo"; "id" ] ]) actual;
      ())

(* Same invariant for [data] roots, the third indexable root kind alongside
   [module] and [resource].  Unlike the characterization tests below, these must
   hold BOTH before and after any string-index folding: a [data] source's instance
   key is a selector, never part of the dependency path. *)

(* [for_each] instance key plus a trailing attribute. *)
let data_string_index_transparent =
  Oth.test ~name:"data_string_index_transparent" (fun _ ->
      let actual = refs_of_string {|x = data.aws_ami.foo["k"].id|} in
      assert_refs (rs_of_list [ [ "data"; "aws_ami"; "foo"; "id" ] ]) actual;
      ())

(* Bare instance key, no trailing attribute (exercises the plain [Idx] path). *)
let data_bare_string_index_transparent =
  Oth.test ~name:"data_bare_string_index_transparent" (fun _ ->
      let actual = refs_of_string {|x = data.aws_ami.foo["k"]|} in
      assert_refs (rs_of_list [ [ "data"; "aws_ami"; "foo" ] ]) actual;
      ())

(* Indexing INTO a data source's attribute — not an instance key.  Pins that
   fine-grained path tracking does not reach through a data-source attribute
   directly; only a decode-local ([<decoder>(...)] bound in [locals]) gets it. *)
let data_attr_string_index_transparent =
  Oth.test ~name:"data_attr_string_index_transparent" (fun _ ->
      let actual = refs_of_string {|x = data.local_file.cfg.content["k"]|} in
      assert_refs (rs_of_list [ [ "data"; "local_file"; "cfg"; "content" ] ]) actual;
      ())

(* A static string index under a [var] root is transparent too: only the base
   collection [var.config] is recorded, the key does not extend the path. *)
let var_string_index_ref =
  Oth.test ~name:"var_string_index_ref" (fun _ ->
      let actual = refs_of_string {|x = var.config["a"]|} in
      assert_refs (rs_of_list [ [ "var"; "config" ] ]) actual;
      ())

(* Variants of the same shape, each exercising a distinct path through
   [extract_qualified_name] / [from_expr].  All of them record today's behaviour —
   a static string index is transparent and never extends the reference path — so
   the diff to these expectations is precisely the behavioural change the
   fine-grained-delta commit introduces. *)

(* Dot-then-bracket: the bracket is dropped, the dotted prefix is kept. *)
let local_dot_then_string_index =
  Oth.test ~name:"local_dot_then_string_index" (fun _ ->
      let actual = refs_of_string {|x = local.config.a["b"]|} in
      assert_refs (rs_of_list [ [ "local"; "config"; "a" ] ]) actual;
      ())

(* Two brackets: both are dropped, leaving just the base collection. *)
let local_nested_string_index =
  Oth.test ~name:"local_nested_string_index" (fun _ ->
      let actual = refs_of_string {|x = local.config["a"]["b"]|} in
      assert_refs (rs_of_list [ [ "local"; "config" ] ]) actual;
      ())

(* Two brackets then an attribute: the attribute is dropped as well, because the
   inner bracket makes the whole chain unresolvable as a qualified name. *)
let local_nested_string_index_then_attr =
  Oth.test ~name:"local_nested_string_index_then_attr" (fun _ ->
      let actual = refs_of_string {|x = local.config["a"]["b"].c|} in
      assert_refs (rs_of_list [ [ "local"; "config" ] ]) actual;
      ())

(* Bracket then two attributes: only the FIRST attribute after the bracket
   survives — the bracket key is dropped and the tail is not appended. *)
let local_string_index_then_attrs =
  Oth.test ~name:"local_string_index_then_attrs" (fun _ ->
      let actual = refs_of_string {|x = local.config["a"].b.c|} in
      assert_refs (rs_of_list [ [ "local"; "config"; "b" ] ]) actual;
      ())

(* Same shape under a [var] root. *)
let var_nested_string_index =
  Oth.test ~name:"var_nested_string_index" (fun _ ->
      let actual = refs_of_string {|x = var.cfg["a"]["b"]|} in
      assert_refs (rs_of_list [ [ "var"; "cfg" ] ]) actual;
      ())

(* Inside a string template interpolation. *)
let local_string_index_in_template =
  Oth.test ~name:"local_string_index_in_template" (fun _ ->
      let actual = refs_of_string {|x = "pre-${local.config["a"]}"|} in
      assert_refs (rs_of_list [ [ "local"; "config" ] ]) actual;
      ())

(* Several indexed references in one expression, under both foldable roots. *)
let string_index_multiple_refs =
  Oth.test ~name:"string_index_multiple_refs" (fun _ ->
      let actual = refs_of_string {|x = [local.a["k"], var.b["j"]]|} in
      assert_refs (rs_of_list [ [ "local"; "a" ]; [ "var"; "b" ] ]) actual;
      ())

let template_refs_other_block =
  Oth.test ~name:"template_refs_other_block" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_route53_record" "web" {
             name = "web-${aws_instance.web.id}"
           }|}
      in
      assert_refs (rs_of_list [ [ "aws_instance"; "web"; "id" ] ]) actual;
      ())

let multiple_cross_refs =
  Oth.test ~name:"multiple_cross_refs" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_subnet" "main" {
             vpc_id = aws_vpc.main.id
             cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
           }|}
      in
      assert_refs
        (rs_of_list [ [ "aws_vpc"; "main"; "id" ]; [ "aws_vpc"; "main"; "cidr_block" ] ])
        actual;
      ())

let local_and_var_refs =
  Oth.test ~name:"local_and_var_refs" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_instance" "main" {
             name = local.name
             env = var.env
           }|}
      in
      assert_refs (rs_of_list [ [ "local"; "name" ]; [ "var"; "env" ] ]) actual;
      ())

(* Terraform meta-argument tests using references' (includes each/count/path) *)

let for_each_each_key_value' =
  Oth.test ~name:"for_each_each_key_value'" (fun _ ->
      let actual =
        refs_of_string'
          {|resource "aws_instance" "main" {
             for_each = var.instances
             name = each.key
             instance_type = each.value.type
           }|}
      in
      assert_refs
        (rs_of_list [ [ "var"; "instances" ]; [ "each"; "key" ]; [ "each"; "value"; "type" ] ])
        actual;
      ())

let count_index' =
  Oth.test ~name:"count_index'" (fun _ ->
      let actual =
        refs_of_string'
          {|resource "aws_instance" "main" {
             count = var.instance_count
             name = "server-${count.index}"
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "instance_count" ]; [ "count"; "index" ] ]) actual;
      ())

let path_module' =
  Oth.test ~name:"path_module'" (fun _ ->
      let actual =
        refs_of_string'
          {|resource "aws_instance" "main" {
            user_data = file("${path.module}/scripts/init.sh")
           }|}
      in
      assert_refs (rs_of_list [ [ "path"; "module" ] ]) actual;
      ())

let path_root' =
  Oth.test ~name:"path_root'" (fun _ ->
      let actual =
        refs_of_string'
          {|resource "null_resource" "main" {
             triggers = {
               script = file("${path.root}/scripts/setup.sh")
             }
           }|}
      in
      assert_refs (rs_of_list [ [ "path"; "root" ] ]) actual;
      ())

let count_and_cross_ref' =
  Oth.test ~name:"count_and_cross_ref'" (fun _ ->
      let actual =
        refs_of_string'
          {|resource "aws_instance" "main" {
             count = length(var.subnets)
             subnet_id = var.subnets[count.index]
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "subnets" ]; [ "count"; "index" ] ]) actual;
      ())

let for_each_with_cross_ref' =
  Oth.test ~name:"for_each_with_cross_ref'" (fun _ ->
      let actual =
        refs_of_string'
          {|resource "aws_security_group_rule" "main" {
             for_each = var.rules
             security_group_id = aws_security_group.main.id
             from_port = each.value.port
           }|}
      in
      assert_refs
        (rs_of_list
           [
             [ "var"; "rules" ]; [ "aws_security_group"; "main"; "id" ]; [ "each"; "value"; "port" ];
           ])
        actual;
      ())

(* Terraform meta-argument tests using references (excludes each/count/path) *)

let for_each_excludes_each =
  Oth.test ~name:"for_each_excludes_each" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_instance" "main" {
             for_each = var.instances
             name = each.key
             instance_type = each.value.type
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "instances" ] ]) actual;
      ())

let count_excludes_count =
  Oth.test ~name:"count_excludes_count" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_instance" "main" {
             count = var.instance_count
             name = "server-${count.index}"
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "instance_count" ] ]) actual;
      ())

let path_excluded =
  Oth.test ~name:"path_excluded" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_instance" "main" {
             user_data = file("${path.module}/scripts/init.sh")
           }|}
      in
      assert_refs (rs_of_list []) actual;
      ())

let count_cross_ref_excludes_count =
  Oth.test ~name:"count_cross_ref_excludes_count" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_instance" "main" {
             count = length(var.subnets)
             subnet_id = var.subnets[count.index]
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "subnets" ] ]) actual;
      ())

let for_each_cross_ref_excludes_each =
  Oth.test ~name:"for_each_cross_ref_excludes_each" (fun _ ->
      let actual =
        refs_of_string
          {|resource "aws_security_group_rule" "main" {
              for_each = var.rules
              security_group_id = aws_security_group.main.id
              from_port = each.value.port
           }|}
      in
      assert_refs (rs_of_list [ [ "var"; "rules" ]; [ "aws_security_group"; "main"; "id" ] ]) actual;
      ())

let for_each_for_comprehension_collects_input =
  Oth.test ~name:"for_each_for_comprehension_collects_input" (fun _ ->
      let actual =
        refs_of_string
          {|resource "terraform_data" "bar" {
              for_each = { for k, v in local.foo : k => v }
              input = each.key
           }|}
      in
      assert_refs (rs_of_list [ [ "local"; "foo" ] ]) actual;
      ())

let references_test =
  Oth.serial
    [
      (* Expression tests *)
      literal_no_refs;
      numeric_literals;
      simple_id_ref;
      dotted_ref;
      deep_dotted_ref;
      multiple_refs_in_expr;
      index_ref;
      attr_splat_ref;
      attr_splat_bare_ref;
      index_splat_ref;
      heredoc_interp_ref;
      heredoc_indented_interp_ref;
      heredoc_multi_ref;
      heredoc_no_interp;
      not_ref;
      conditional_refs;
      tuple_refs;
      object_refs;
      func_call_refs;
      func_call_ellipsis_refs;
      for_object_grouping_refs;
      for_tuple_bound_vars;
      for_object_bound_vars;
      for_object_module_collection_stays_coarse;
      comprehension_two_identifiers_binds_the_value;
      comprehension_one_identifier_binds_the_value;
      comprehension_not_a_comprehension;
      comprehension_whole_value_read;
      comprehension_attrs_and_whole;
      comprehension_nested_attr_takes_head;
      comprehension_index_is_whole;
      comprehension_splat_is_whole;
      comprehension_reads_in_cond;
      comprehension_shadowed_by_inner_comprehension;
      comprehension_untouched_variable;
      reads_of_var_template_directive_shadows;
      reads_of_var_template_directive_input_is_outer;
      for_with_cond;
      for_external_ref_in_cond;
      (* Block tests *)
      resource_block;
      nested_blocks;
      block_with_mixed;
      empty_block;
      lifecycle_ignore_changes_not_ref;
      provisioner_when_on_failure_not_ref;
      variable_type_not_ref;
      multiple_top_level;
      (* Template string tests *)
      template_single_interp;
      template_multiple_interps;
      template_no_interp;
      template_complex_expr;
      template_in_block;
      (* Cross-block reference tests *)
      resource_refs_resource;
      resource_refs_variable;
      module_ref;
      module_ref_splat;
      module_ref_index;
      module_ref_string_index;
      module_ref_dynamic_index;
      local_dynamic_index;
      resource_dynamic_index;
      resource_string_index_transparent;
      data_string_index_transparent;
      data_bare_string_index_transparent;
      data_attr_string_index_transparent;
      var_string_index_ref;
      local_dot_then_string_index;
      local_nested_string_index;
      local_nested_string_index_then_attr;
      local_string_index_then_attrs;
      var_nested_string_index;
      local_string_index_in_template;
      string_index_multiple_refs;
      template_refs_other_block;
      multiple_cross_refs;
      local_and_var_refs;
      (* Meta-argument tests with references' *)
      for_each_each_key_value';
      count_index';
      path_module';
      path_root';
      count_and_cross_ref';
      for_each_with_cross_ref';
      (* Meta-argument tests with references (excludes meta) *)
      for_each_excludes_each;
      count_excludes_count;
      path_excluded;
      count_cross_ref_excludes_count;
      for_each_cross_ref_excludes_each;
      for_each_for_comprehension_collects_input;
    ]

(* attr_path_of_reference tests *)

(* [attr_path_of_reference] is the companion of [address_of_reference]: the tail
   beyond the tokens the address consumed.  It is THE place to derive an attr_path;
   the contract that matters most is that a folded map key stays ONE segment even
   when the key itself contains a ".". *)

let pp_strs fmt l = Format.fprintf fmt "[%s]" (CCString.concat "; " l)

let assert_path expected actual =
  Oth.Assert.eq ~eq:(CCList.equal CCString.equal) ~pp:pp_strs expected actual

let attr_path_local_tail =
  Oth.test ~name:"attr_path_local_tail" (fun _ ->
      assert_path
        [ "x"; "z" ]
        (Sg_tf_references.attr_path_of_reference [ "local"; "config"; "x"; "z" ]);
      ())

(* A forward-guard, not a live regression: reference segments cannot contain a "."
   until static map-key folding lands (the lexer admits none in an identifier).
   Once folding puts a RAW key into the path, joining on "." and re-splitting would
   yield ["example"; "com"] and stop matching the single-segment path recorded for
   that key. *)
let attr_path_dotted_key_is_one_segment =
  Oth.test ~name:"attr_path_dotted_key_is_one_segment" (fun _ ->
      assert_path
        [ "example.com" ]
        (Sg_tf_references.attr_path_of_reference [ "local"; "config"; "example.com" ]);
      ())

let attr_path_var_dotted_key =
  Oth.test ~name:"attr_path_var_dotted_key" (fun _ ->
      assert_path [ "1.2.3" ] (Sg_tf_references.attr_path_of_reference [ "var"; "cfg"; "1.2.3" ]);
      ())

let attr_path_no_tail =
  Oth.test ~name:"attr_path_no_tail" (fun _ ->
      assert_path [] (Sg_tf_references.attr_path_of_reference [ "local"; "config" ]);
      ())

let attr_path_data_consumes_three =
  Oth.test ~name:"attr_path_data_consumes_three" (fun _ ->
      assert_path
        [ "id" ]
        (Sg_tf_references.attr_path_of_reference [ "data"; "aws_ami"; "ubuntu"; "id" ]);
      ())

let attr_path_ephemeral_consumes_three =
  Oth.test ~name:"attr_path_ephemeral_consumes_three" (fun _ ->
      assert_path
        [ "value" ]
        (Sg_tf_references.attr_path_of_reference [ "ephemeral"; "t"; "n"; "value" ]);
      ())

let attr_path_resource_consumes_two =
  Oth.test ~name:"attr_path_resource_consumes_two" (fun _ ->
      assert_path [ "id" ] (Sg_tf_references.attr_path_of_reference [ "aws_instance"; "foo"; "id" ]);
      ())

(* [outputs.X] and [module.X.attr] resolve to REWRITTEN addresses ([output.X],
   [module.X.output.attr]) which are not verbatim prefixes of the reference, so no
   tail can be attributed to them. *)
let attr_path_outputs_is_empty =
  Oth.test ~name:"attr_path_outputs_is_empty" (fun _ ->
      assert_path [] (Sg_tf_references.attr_path_of_reference [ "outputs"; "name"; "x" ]);
      ())

let attr_path_module_is_empty =
  Oth.test ~name:"attr_path_module_is_empty" (fun _ ->
      assert_path [] (Sg_tf_references.attr_path_of_reference [ "module"; "m"; "out"; "sub" ]);
      ())

(* The shape where a structural derivation and a textual one part company: an
   output literally named [output] makes the synthesised address
   [module.m.output.output] a spurious string PREFIX of the reference, so
   stripping it textually yields ["x"].  Structurally the answer is [], the same
   as every other module root.  ([] over-approximates — an empty path selects the
   whole attributes object — whereas ["x"] named the wrong field entirely; the
   true tail here is ["output"; "x"].)  Sibling of [module_output_named_output]
   in code/tests/sgs_tx_log/test.ml, which pins the same case end-to-end. *)
let attr_path_module_output_named_output =
  Oth.test ~name:"attr_path_module_output_named_output" (fun _ ->
      assert_path
        []
        (Sg_tf_references.attr_path_of_reference [ "module"; "m"; "output"; "output"; "x" ]);
      ())

let attr_path_singleton_is_empty =
  Oth.test ~name:"attr_path_singleton_is_empty" (fun _ ->
      assert_path [] (Sg_tf_references.attr_path_of_reference [ "local" ]);
      ())

let attr_path_of_reference_test =
  Oth.serial
    [
      attr_path_local_tail;
      attr_path_dotted_key_is_one_segment;
      attr_path_var_dotted_key;
      attr_path_no_tail;
      attr_path_data_consumes_three;
      attr_path_ephemeral_consumes_three;
      attr_path_resource_consumes_two;
      attr_path_outputs_is_empty;
      attr_path_module_is_empty;
      attr_path_module_output_named_output;
      attr_path_singleton_is_empty;
    ]

(* addresses tests *)

module As = Sg_tf_references.Address_set

let pp_address_set fmt s =
  Format.fprintf
    fmt
    "{%a}"
    (Format.pp_print_list ~pp_sep:(fun fmt () -> Format.fprintf fmt ", ") Format.pp_print_string)
    (As.to_list s)

let assert_addrs expected actual = Oth.Assert.eq ~eq:As.equal ~pp:pp_address_set expected actual
let as_of_list l = As.of_list l

let addresses_resource =
  Oth.test ~name:"addresses_resource" (fun _ ->
      let refs = rs_of_list [ [ "aws_instance"; "foo"; "bar" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "aws_instance.foo" ]) actual;
      ())

let addresses_data_source =
  Oth.test ~name:"addresses_data_source" (fun _ ->
      let refs = rs_of_list [ [ "data"; "aws_ami"; "ubuntu"; "id" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "data.aws_ami.ubuntu" ]) actual;
      ())

let addresses_ephemeral =
  Oth.test ~name:"addresses_ephemeral" (fun _ ->
      (* #1033 — an ephemeral resource reference is 3-token (like data); the instance
         name must be kept so the edge matches the 3-part block node. *)
      let refs =
        rs_of_list [ [ "ephemeral"; "aws_secretsmanager_secret_version"; "e"; "secret_string" ] ]
      in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "ephemeral.aws_secretsmanager_secret_version.e" ]) actual;
      ())

let addresses_var =
  Oth.test ~name:"addresses_var" (fun _ ->
      let refs = rs_of_list [ [ "var"; "instance_type" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "var.instance_type" ]) actual;
      ())

let addresses_local =
  Oth.test ~name:"addresses_local" (fun _ ->
      let refs = rs_of_list [ [ "local"; "name" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "local.name" ]) actual;
      ())

let addresses_module =
  Oth.test ~name:"addresses_module" (fun _ ->
      (* [module.network.subnet_id] resolves to both the child output node
         [module.network.output.subnet_id] AND the module block
         [module.network].  The block is included as a fallback for
         remote-source modules whose output nodes don't exist in the
         graph. *)
      let refs = rs_of_list [ [ "module"; "network"; "subnet_id" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "module.network"; "module.network.output.subnet_id" ]) actual;
      ())

let addresses_output =
  Oth.test ~name:"addresses_output" (fun _ ->
      let refs = rs_of_list [ [ "output"; "url" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "output.url" ]) actual;
      ())

let addresses_terraform =
  Oth.test ~name:"addresses_terraform" (fun _ ->
      let refs = rs_of_list [ [ "terraform"; "workspace" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "terraform.workspace" ]) actual;
      ())

let addresses_dedup =
  Oth.test ~name:"addresses_dedup" (fun _ ->
      let refs =
        rs_of_list [ [ "aws_instance"; "foo"; "id" ]; [ "aws_instance"; "foo"; "public_ip" ] ]
      in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "aws_instance.foo" ]) actual;
      ())

let addresses_bare_skipped =
  Oth.test ~name:"addresses_bare_skipped" (fun _ ->
      let refs = rs_of_list [ [ "foo" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list []) actual;
      ())

let addresses_empty =
  Oth.test ~name:"addresses_empty" (fun _ ->
      let refs = Rs.empty in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list []) actual;
      ())

let addresses_test =
  Oth.serial
    [
      addresses_resource;
      addresses_data_source;
      addresses_ephemeral;
      addresses_var;
      addresses_local;
      addresses_module;
      addresses_output;
      addresses_terraform;
      addresses_dedup;
      addresses_bare_skipped;
      addresses_empty;
    ]

(* split_remote_tf_state_references tests *)

module Drm = Sg_tf_references.Data_reference_map

let pp_drm fmt m =
  Format.fprintf fmt "{";
  Drm.iter (fun k v -> Format.fprintf fmt "%s => %a; " k pp_reference_set v) m;
  Format.fprintf fmt "}"

let drm_equal a b = Drm.equal Rs.equal a b
let assert_drm expected actual = Oth.Assert.eq ~eq:drm_equal ~pp:pp_drm expected actual

let split_single_remote_state =
  Oth.test ~name:"split_single_remote_state" (fun _ ->
      let refs =
        rs_of_list [ [ "data"; "terraform_remote_state"; "network"; "outputs"; "vpc_id" ] ]
      in
      let actual = Sg_tf_references.split_remote_tf_state_references refs in
      let expected =
        Drm.singleton "data.terraform_remote_state.network" (rs_of_list [ [ "outputs"; "vpc_id" ] ])
      in
      assert_drm expected actual;
      ())

let split_multiple_refs_same_remote =
  Oth.test ~name:"split_multiple_refs_same_remote" (fun _ ->
      let refs =
        rs_of_list
          [
            [ "data"; "terraform_remote_state"; "network"; "outputs"; "vpc_id" ];
            [ "data"; "terraform_remote_state"; "network"; "outputs"; "subnet_ids" ];
          ]
      in
      let actual = Sg_tf_references.split_remote_tf_state_references refs in
      let expected =
        Drm.singleton
          "data.terraform_remote_state.network"
          (rs_of_list [ [ "outputs"; "vpc_id" ]; [ "outputs"; "subnet_ids" ] ])
      in
      assert_drm expected actual;
      ())

let split_multiple_remote_states =
  Oth.test ~name:"split_multiple_remote_states" (fun _ ->
      let refs =
        rs_of_list
          [
            [ "data"; "terraform_remote_state"; "network"; "outputs"; "vpc_id" ];
            [ "data"; "terraform_remote_state"; "database"; "outputs"; "endpoint" ];
          ]
      in
      let actual = Sg_tf_references.split_remote_tf_state_references refs in
      let expected =
        Drm.of_list
          [
            ("data.terraform_remote_state.network", rs_of_list [ [ "outputs"; "vpc_id" ] ]);
            ("data.terraform_remote_state.database", rs_of_list [ [ "outputs"; "endpoint" ] ]);
          ]
      in
      assert_drm expected actual;
      ())

let split_non_remote_state_skipped =
  Oth.test ~name:"split_non_remote_state_skipped" (fun _ ->
      let refs = rs_of_list [ [ "data"; "aws_ami"; "ubuntu"; "id" ] ] in
      let actual = Sg_tf_references.split_remote_tf_state_references refs in
      assert_drm Drm.empty actual;
      ())

let split_mixed_refs =
  Oth.test ~name:"split_mixed_refs" (fun _ ->
      let refs =
        rs_of_list
          [
            [ "data"; "terraform_remote_state"; "network"; "outputs"; "vpc_id" ];
            [ "aws_instance"; "main"; "id" ];
            [ "var"; "env" ];
          ]
      in
      let actual = Sg_tf_references.split_remote_tf_state_references refs in
      let expected =
        Drm.singleton "data.terraform_remote_state.network" (rs_of_list [ [ "outputs"; "vpc_id" ] ])
      in
      assert_drm expected actual;
      ())

let split_empty_refs =
  Oth.test ~name:"split_empty_refs" (fun _ ->
      let actual = Sg_tf_references.split_remote_tf_state_references Rs.empty in
      assert_drm Drm.empty actual;
      ())

let split_hcl_remote_state =
  Oth.test ~name:"split_hcl_remote_state" (fun _ ->
      let refs =
        refs_of_string
          {|resource "null_resource" "example" {
              triggers = {
                vpc_id = data.terraform_remote_state.network.outputs.vpc_id
              }
            }|}
      in
      let actual = Sg_tf_references.split_remote_tf_state_references refs in
      let expected =
        Drm.singleton "data.terraform_remote_state.network" (rs_of_list [ [ "outputs"; "vpc_id" ] ])
      in
      assert_drm expected actual;
      ())

let split_remote_state_test =
  Oth.serial
    [
      split_single_remote_state;
      split_multiple_refs_same_remote;
      split_multiple_remote_states;
      split_non_remote_state_skipped;
      split_mixed_refs;
      split_empty_refs;
      split_hcl_remote_state;
    ]

(* Module output ref addressing tests — [address_of_reference] resolves
   module output reads to the output node's fully-qualified address
   [module.<name>.output.<attr>], which the subgraph traversal matches
   directly against the child output node. *)

(* [names_a_node] is what the apply uses to drop an edge whose address points at nothing, and it
   replaced [ref not like '%.*'] in [update_state_apply_tx.sql] -- RFD 1008 forbids SQL matching an
   identifier as text.

   The two cases must not be confused, and the second is why [is_wildcard] could not be used.  A
   splat at the end of what the address consumes gives an address no node has; a splat anywhere
   else leaves an address that names a node perfectly well, and dropping that edge would reify too
   little.  The pairs below are exactly the rule, stated against the address each one produces. *)
let names_a_node_rule =
  Oth.test ~name:"names_a_node_rule" (fun _ ->
      let case ~ref_ ~expect_address ~expect_names =
        Oth.Assert.Eq.string
          ~expected:expect_address
          ~actual:(CCOption.get_or ~default:"<none>" (Sg_tf_references.address_of_reference ref_));
        Oth.Assert.eq
          ~eq:Bool.equal
          ~pp:Format.pp_print_bool
          expect_names
          (Sg_tf_references.names_a_node ref_)
      in
      (* The splat ends the consumed address: no node is called [module.X.output.*]. *)
      case
        ~ref_:[ "module"; "child"; "*" ]
        ~expect_address:"module.child.output.*"
        ~expect_names:false;
      (* The splat is beyond the address, which stops at the resource.  This edge is kept today and
         must stay kept: [is_wildcard] would have dropped it. *)
      case
        ~ref_:[ "aws_instance"; "web"; "*"; "id" ]
        ~expect_address:"aws_instance.web"
        ~expect_names:true;
      (* Ordinary reads, for contrast. *)
      case ~ref_:[ "local"; "cfg" ] ~expect_address:"local.cfg" ~expect_names:true;
      case
        ~ref_:[ "module"; "child"; "out" ]
        ~expect_address:"module.child.output.out"
        ~expect_names:true;
      ())

let addresses_module_output =
  Oth.test ~name:"addresses_module_output" (fun _ ->
      let refs = rs_of_list [ [ "module"; "child"; "output_abc123" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "module.child"; "module.child.output.output_abc123" ]) actual;
      ())

let addresses_module_output_multiple =
  Oth.test ~name:"addresses_module_output_multiple" (fun _ ->
      let refs =
        rs_of_list
          [ [ "module"; "child"; "output_abc123" ]; [ "module"; "child"; "output_def567" ] ]
      in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs
        (as_of_list
           [
             "module.child";
             "module.child.output.output_abc123";
             "module.child.output.output_def567";
           ])
        actual;
      ())

let addresses_module_bare =
  Oth.test ~name:"addresses_module_bare" (fun _ ->
      (* Bare [module.child] with no attribute — e.g. inside [keys(module.child)]
         — resolves to the module block address. *)
      let refs = rs_of_list [ [ "module"; "child" ] ] in
      let actual = Sg_tf_references.addresses refs in
      assert_addrs (as_of_list [ "module.child" ]) actual;
      ())

let addresses_module_truncation_test =
  Oth.serial
    [
      names_a_node_rule;
      addresses_module_output;
      addresses_module_output_multiple;
      addresses_module_bare;
    ]

let selectors_of_string s =
  let values = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string s) in
  CCList.flat_map Sg_tf_references.selectors values

let show_selector (ref_, sel) =
  Printf.sprintf
    "%s=%s"
    (CCString.concat "." ref_)
    (match sel with
    | Sg_tf_references.Selector.Key k -> k
    | Sg_tf_references.Selector.Index n -> string_of_int n)

let selectors_test =
  let case ~name ~expected hcl =
    Oth.test ~name (fun _ ->
        let actual =
          CCList.sort CCString.compare (CCList.map show_selector (selectors_of_string hcl))
        in
        Oth.Assert.Eq.string_list ~expected:(CCList.sort CCString.compare expected) ~actual;
        ())
  in
  Oth.serial
    [
      (* [lookup] with a literal key is the shape [test_min_over_reify] depends on. *)
      case
        ~name:"selector_lookup_literal_key"
        ~expected:[ "local.ports_by_rack=R01" ]
        {|x = lookup(local.ports_by_rack, "R01", "")|};
      (* The same selection written as an index. *)
      case
        ~name:"selector_index_literal_key"
        ~expected:[ "local.ports_by_rack=R01" ]
        {|x = local.ports_by_rack["R01"]|};
      (* An index that carries an attribute after it: the reference keeps the attribute, and the
         selector is the index. *)
      case
        ~name:"selector_index_then_attr"
        ~expected:[ "module.distribution_switches.switch=1" ]
        {|x = module.distribution_switches["1"].switch|};
      (* An integer index. *)
      case ~name:"selector_int_index" ~expected:[ "local.xs=0" ] {|x = local.xs[0]|};
      (* A key that must be computed says nothing: the guard stays unknown and the walk follows. *)
      case ~name:"selector_dynamic_index" ~expected:[] {|x = local.xs[var.k]|};
      case
        ~name:"selector_lookup_dynamic_key"
        ~expected:[]
        {|x = lookup(local.ports_by_rack, var.rack, "")|};
      (* A plain attribute read is not a selector: [attr_path] already carries it. *)
      case ~name:"selector_plain_attr" ~expected:[] {|x = local.config.name|};
    ]

let () =
  Random.self_init ();
  Oth.run
    ~file:__FILE__
    ~setup:(fun () -> Ok ())
    ~teardown:(fun _ -> ())
    (fun _ ->
      Oth.parallel
        [
          references_test;
          attr_path_of_reference_test;
          addresses_test;
          split_remote_state_test;
          addresses_module_truncation_test;
          selectors_test;
        ])
