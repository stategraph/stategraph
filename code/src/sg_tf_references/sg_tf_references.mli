(** Reference and address manipulation for Terraform configuration.

    A {i reference} is the token path of a configuration-object read, as it appears in HCL:
    [aws_instance.web.id] is [["aws_instance"; "web"; "id"]]. An {i address} is the canonical name
    of the node that reference resolves to: ["aws_instance.web"]. This module owns the walkers that
    harvest references out of expressions and blocks, and the functions that turn a reference into
    the address (and attribute path) it names.

    It deliberately knows nothing about root modules, tfvars, attribute lookup, or file loading —
    everything here is a pure function of an already-parsed HCL value. {!Sg_tf_eval} builds on top
    of it. *)

module Address_set : CCSet.S with type elt = string
module Reference_set : CCSet.S with type elt = string list
module Data_reference_map : module type of Sln_map.String

(** [expr_references expr] returns all non-literal references in a single expression, {b including}
    Terraform built-in meta-references whose root is [each], [count], or [path]. This is the
    expression-level counterpart of {!references'}, not of {!references}. *)
val expr_references : Hcl_parser_value.Expr.t -> Reference_set.t

(** [references v] returns all non-literal references in [v], excluding Terraform built-in
    meta-references whose root is [each], [count], or [path].

    Splat indexing is transparent: [module.child[*].bar] produces the same reference
    [["module"; "child"; "bar"]] as [module.child.bar]. *)
val references : Hcl_parser_value.t -> Reference_set.t

(** [references' v] returns all non-literal references in [v], including Terraform built-in
    meta-references ([each.*], [count.*], [path.*]). *)
val references' : Hcl_parser_value.t -> Reference_set.t

(** The ONE member of a value that a read picks out, when the expression says which without any
    evaluation. *)
module Selector : sig
  type t =
    | Key of string
    | Index of int
  [@@deriving show, eq]
end

(** [selectors v] returns every STATIC selector in [v], as (reference, selector) pairs.

    Three shapes say which member a read wants: [p["K"]], [p[0]], and [lookup(p, "K", d)].
    [lookup(p, "K", d)] is [p["K"]] written as a call, and Terraform evaluates the two in the same
    way. A key that the evaluator must calculate says nothing, thus such a read gives no selector
    here.

    {!references} drops this on purpose, because indexing is transparent there:
    [module.child[0].bar] and [module.child.bar] give ONE reference. This function is the dual. An
    edge that carries the selector lets a walk ask "did the member that THIS consumer reads move",
    and not "did anything in the producer move". See the [key] guard in the expand/mark/sweep RFD.
*)
val selectors : Hcl_parser_value.t -> (string list * Selector.t) list

(** [expr_selectors expr] is {!selectors} for a single expression.

    The ARGUMENT of a module call needs it. The argument binds one child [variable], and the edge
    that records the read starts at that child. The child holds only a type. Thus the key must cross
    the module boundary together with the input that it belongs to. *)
val expr_selectors : Hcl_parser_value.Expr.t -> (string list * Selector.t) list

(** How a comprehension's loop variable is consumed inside the comprehension body. *)
module Var_reads : sig
  type t = {
    attrs : string list;  (** attribute names read off the variable, sorted and deduped *)
    whole : bool;  (** the variable is also used as a whole value *)
  }
end

(** A comprehension, reduced to what a consumer needs to decide what its loop variable's reads mean.
*)
module Comprehension : sig
  type t = {
    var : string;
        (** the VALUE identifier — the one that ranges over the collection's elements. HCL binds
            [for k, v in coll] as (key, value), so this is the LAST identifier; reads off the key
            name nothing. *)
    input : Hcl_parser_value.Expr.t;  (** the collection being iterated *)
    reads : Var_reads.t;  (** how [var] is consumed in the body, [cond] included *)
  }
end

(** [comprehension_of_expr expr] is [Some c] when [expr] is a [for] comprehension (tuple or object),
    [None] otherwise. It exists so callers do not have to re-derive which identifier is the value —
    an asymmetry that differs between expression comprehensions and template [%\{ for \}]
    directives. *)
val comprehension_of_expr : Hcl_parser_value.Expr.t -> Comprehension.t option

(** [depends_on_references v] returns the references collected only from [depends_on] attributes
    inside [v] (recursing into nested blocks). [references] and [references'] deliberately skip
    [depends_on] so its targets do not pull blocks into the subgraph; this walker is the dual, used
    by the reifier to know which addresses a node's [depends_on] refers to. *)
val depends_on_references : Hcl_parser_value.t -> Reference_set.t

(** [check_block_references v] returns references collected only from inside [precondition],
    [postcondition], [validation], or [assert] blocks. Terraform rejects [condition] expressions
    that resolve to pure literals (no configuration-object reference), so these refs must not drive
    boundary-substitution decisions — see [Sgs_tx_log.process_hcl_value], which emits them as bare
    edges so the cone walk still admits the target but the substitution decision skips it. *)
val check_block_references : Hcl_parser_value.t -> Reference_set.t

(** [address_of_reference ref_] converts a single reference (string list) to its canonical Terraform
    HCL address. Namespace mappings are applied: ["outputs"] is translated to ["output"] to match
    the HCL block type. Returns [None] if the reference is too short.

    To obtain the attribute path a consumer read WITHIN that address, use {!attr_path_of_reference}
    — never re-derive it from this string. *)
val address_of_reference : string list -> string option

(** [address_tokens_of_reference ref_] is the same answer as tokens, before the join.

    One match derives both, so a caller that needs to inspect what the address consumed does not
    take the joined string apart again. *)
val address_tokens_of_reference : string list -> string list option

(** [names_a_node ref_] is whether the address {!address_of_reference} gives names a node.

    It does not when the last token the address consumed is the splat [*]: [module.X.*] resolves to
    [module.X.output.*], and no node has that address. The reference is real — it reads every output
    of the module — but the address is not a name, and an edge carrying it points at nothing. The
    apply drops such an edge; this is what lets it do so without matching the address as text.

    Not the same question as "does this reference contain a splat". For [aws_instance.web.*.id] the
    address is [aws_instance.web], which names a node and which the apply keeps. *)
val names_a_node : string list -> bool

(** [attr_path_of_reference ref_] is the reference tail beyond the tokens {!address_of_reference}
    consumed: the attribute path read within the node the address names.
    [["local"; "config"; "x"; "z"]] gives [["x"; "z"]] (address ["local.config"]).

    Use this whenever you need an attr_path. Do NOT recover one by joining a reference with ["."]
    and stripping the address off the resulting string — a prefix match on text rather than on
    structure goes wrong in two ways.

    Reachable in current behaviour (and has been since #685): a token can reproduce the [".output."]
    separator {!address_of_reference} synthesises for a module output, so a child module with an
    output named [output] makes [module.m.output.output] a spurious string prefix of
    [module.m.output.output.x]. The textual form attributes ["x"] to the base edge; the correct tail
    is [["output"; "x"]], and this function returns [[]], which over-approximates rather than
    pointing at the wrong field.

    Once static map-key folding lands: folding puts the RAW key into the reference path, and a key
    may itself contain a ["."] ([["main.tf"]], [["example.com"]], [["1.2.3"]]). Re-splitting would
    shatter such a key into several segments, whose attr_path would then never match the
    single-segment path recorded elsewhere for that key — silently dropping a consumer rather than
    over-approximating it. Reference segments cannot contain a ["."] yet, so that failure is latent.

    Returns [[]] for [outputs.X] and [module.X.attr], whose addresses are rewrites rather than
    verbatim prefixes of the reference. *)
val attr_path_of_reference : string list -> string list

(** [addresses refs] converts a set of references to their canonical Terraform address strings,
    stripping trailing attribute accesses. For example, [["aws_instance"; "foo"; "bar"]] becomes
    ["aws_instance.foo"] and [["data"; "baz"; "zoom"]] becomes ["data.baz.zoom"]. References too
    short to form a valid address are skipped. *)
val addresses : Reference_set.t -> Address_set.t

(** [split_remote_tf_state_references refs] partitions remote state references from [refs]. For each
    reference of the form [data.terraform_remote_state.<name>.<rest...>], it groups the stripped
    sub-references by their data block address. For example,
    [["data"; "terraform_remote_state"; "network"; "outputs"; "vpc_id"]] produces a map entry with
    key ["data.terraform_remote_state.network"] and value [{["outputs"; "vpc_id"]}].
    Non-remote-state references are dropped. *)
val split_remote_tf_state_references : Reference_set.t -> Reference_set.t Data_reference_map.t

(** The attr path marking an edge that depends on EVERY output of the module the edge points at.

    A read that names a module but no output — [module.X] whole, or a dynamically indexed
    [module.X[expr]] — has no single output to depend on. Such a read earns a second edge to the
    module block carrying this attr path, and the walk matches it against any output node whose
    [module_address] is that block: no output admitted, no consumer admitted; one output admitted,
    consumer admitted. The same-state counterpart of the [<*all-outputs*>] address
    {!split_remote_tf_state_references} emits for a whole-[.outputs] read of a remote state. *)
val module_all_outputs_attr : string

(** The address that a [remote_tf_state_refs] entry records for a read of the whole [.outputs]
    object, or of the bare data block, of a remote state. Such a read names no one output, thus the
    walk fans this address out to each root [output] node of the producing state. No real address
    can hold it, because a terraform identifier cannot contain [*] or [<]. *)
val remote_tf_state_all_outputs_sentinel_addr : string

(** Static parse of a leaf reference expression into the four pieces the boundary-substitution
    machinery needs. Used both to decide whether a cone-side resource can be inlined as a state
    literal and to drive the actual rewrite. Returns [None] for shapes that cannot be safely
    substituted against state — dynamic indexes, splats, function-call heads, anything that isn't a
    concrete chain rooted at an [Id]. *)
module Address : sig
  module Index : sig
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

  val of_expr : Hcl_parser_value.Expr.t -> t option
end

(** Test-only. Production reads a comprehension's variable through {!comprehension_of_expr}, which
    reports the reads as part of {!Comprehension.t}; the standalone walker underneath it is
    exercised directly only by the unit tests. *)
module Tests : sig
  (** [reads_of_var ~var expr] reports how the loop variable [var] is read inside [expr].
      [Var_reads.attrs] holds the attribute names read off it ([sa.id] contributes ["id"]);
      [Var_reads.whole] is [true] when the variable is used in a way that names no single member of
      it — a bare read, a splat, an index, an integer attribute.

      A nested comprehension rebinding [var] shadows it, so reads under that binding belong to the
      inner variable and are not reported here. That comprehension's [input] is evaluated in the
      outer scope and IS still walked.

      This reports the shape of the reads; it does not decide what they mean. What [sa.id] refers to
      depends on whether the collection is a map of module instances or an object of module outputs,
      which is a property of the module block rather than of this expression — see [Sg_tx_builder]'s
      ref-hints visitor, which owns that decision. *)
  val reads_of_var : var:string -> Hcl_parser_value.Expr.t -> Var_reads.t
end
