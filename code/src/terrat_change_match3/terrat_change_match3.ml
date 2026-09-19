module R = Terrat_base_repo_config_v1
module Dirspace_map = Terrat_data.Dirspace_map
module Dirspace_set = Terrat_data.Dirspace_set

module Dependency_edge = struct
  type t = {
    dependent : Terrat_dirspace.t;
    dependency : Terrat_dirspace.t;
    rule : string;
  }
  [@@deriving show, eq]
end

module Stack_boundary = struct
  type t = {
    dependent : Terrat_dirspace.t;
    dependent_stack : string;
    dependency : Terrat_dirspace.t;
    dependency_stack : string;
  }
  [@@deriving show, eq]
end

type synthesize_config_err =
  [ `Depends_on_cycle_err of Dependency_edge.t list
  | `Depends_on_crosses_stack_err of Stack_boundary.t
  | `Workspace_in_multiple_stacks_err of Terrat_dirspace.t
  | `Workspace_matches_no_stacks_err of Terrat_dirspace.t
  | `Stack_not_found_err of string
  | `Stack_cycle_err of string list
  ]
[@@deriving show]

exception Synthesize_config_err of synthesize_config_err

module Stack_config = struct
  type t = {
    name : string;
    paths : string list list;
    config : Terrat_base_repo_config_v1.Stacks.Stack.t;
  }
  [@@deriving show, eq, to_yojson]
end

module Dirspace_config = struct
  type t = {
    dirspace : Terrat_dirspace.t;
    file_pattern_matcher : string -> bool; [@opque]
    lock_branch_target : Terrat_base_repo_config_v1.Dirs.Dir.Branch_target.t;
    stack_config : Terrat_base_repo_config_v1.Stacks.Stack.t;
    stack_name : string;
    stack_paths : string list list;
    tags : Terrat_tag_set.t;
    when_modified : Terrat_base_repo_config_v1.When_modified.t;
  }
  [@@deriving show]

  let to_yojson t =
    let module Ds = struct
      type t = {
        dir : string;
        workspace : string;
      }
      [@@deriving to_yojson]
    end in
    let module T = struct
      type t = {
        dirspace : Ds.t;
        tags : string list;
        when_modified : Terrat_base_repo_config_v1.When_modified.t;
      }
      [@@deriving to_yojson]
    end in
    T.to_yojson
      {
        T.dirspace =
          {
            Ds.dir = t.dirspace.Terrat_dirspace.dir;
            workspace = t.dirspace.Terrat_dirspace.workspace;
          };
        tags = Terrat_tag_set.to_list t.tags;
        when_modified = t.when_modified;
      }
end

(* Does [dependency] declare a [depends_on] that [dependent] answers?  The
   [modified_by] relation is not tested here: [collect_dependents] follows it
   through [modifies_lookup], which reaches every dirspace it names rather than
   only those the topology already joins. *)
let match_dependency ~dependent ~dependency =
  let module Wm = R.When_modified in
  let module Depends_on = R.Depends_on in
  let { Dirspace_config.dirspace; tags; _ } = dependent in
  let { Dirspace_config.dirspace = working_dirspace; when_modified = { Wm.depends_on; _ }; _ } =
    dependency
  in
  CCOption.map_or
    ~default:false
    (fun { Depends_on.tag_query; prune_on_no_change = _ } ->
      let ctx = Terrat_tag_query.Ctx.make ~working_dirspace ~dirspace () in
      Terrat_tag_query.match_ ~ctx ~tag_set:tags tag_query)
    depends_on

(* Does [dependency] have to wait for [dependent]?  [stack_rule] says which of
   the stack rules of [dependency] count as an edge.  The two callers below
   differ only in that. *)
let match_stack_dependency ~stack_rule ~dependent ~dependency =
  let module Wm = R.When_modified in
  let module Depends_on = R.Depends_on in
  let module S = R.Stacks.Stack in
  let { Dirspace_config.dirspace; tags; stack_name; _ } = dependent in
  let {
    Dirspace_config.dirspace = working_dirspace;
    when_modified = { Wm.depends_on; _ };
    stack_config = { S.rules; type_ = _; variables = _ };
    _;
  } =
    dependency
  in
  CCList.mem ~eq:CCString.equal stack_name (stack_rule rules)
  || CCOption.map_or
       ~default:false
       (fun { Depends_on.tag_query; prune_on_no_change = _ } ->
         let ctx = Terrat_tag_query.Ctx.make ~working_dirspace ~dirspace () in
         Terrat_tag_query.match_ ~ctx ~tag_set:tags tag_query)
       depends_on

(* The edge of the plan layering.  [apply_after] is deliberately absent: it
   orders applies, and a dirspace that it holds back must still plan with the
   dirspaces it plans with. *)
let match_plan_after_dependency ~dependent ~dependency =
  let module Rules = R.Stacks.Rules in
  match_stack_dependency
    ~stack_rule:(fun { Rules.plan_after; apply_after = _; auto_apply = _; modified_by = _ } ->
      plan_after)
    ~dependent
    ~dependency

(* The edge of the layering that counts how many rounds are left.  A round ends
   with an apply, so [apply_after] is a real edge here. *)
let match_apply_after_dependency ~dependent ~dependency =
  let module Rules = R.Stacks.Rules in
  match_stack_dependency
    ~stack_rule:(fun { Rules.plan_after; apply_after; auto_apply = _; modified_by = _ } ->
      plan_after @ apply_after)
    ~dependent
    ~dependency

(* [matches] are those dirspace configs that we have identified from the diff.
   [dirspaces] is all dirspaces in the configuration file.  [topology] maps a
   dirspace to every dirspace that depends on it.  [modifies_lookup] maps a
   stack name to every dirspace config whose stack declares [modified_by]
   against it.  From this we produce every dirspace that is modified or should
   be considered modified.

   Both relations are followed in ONE walk.  Following them in turn instead
   would lose a dirspace that declares [depends_on] against something that
   [modified_by] brought in, because the [depends_on] step would already be
   over by then.

   Walk each dirspace one time, not each path to it.  Whether a dirspace is
   collected depends on the edge we arrive by, but what it expands to depends
   only on itself, so a dirspace we have already expanded can be skipped.
   Without [seen] this walks every path, and the number of paths through a
   diamond doubles with each level.  [seen] also ends a [modified_by] cycle,
   which nothing in the configuration forbids -- [assert_no_stack_cycle] covers
   nested stacks, [plan_after] and [apply_after], but not [modified_by]. *)
let collect_dependents topology modifies_lookup dirspaces matches =
  let rec go acc matches =
    CCListLabels.fold_left
      ~f:(fun
          ((seen, dirspace_configs) as unchanged)
          ({ Dirspace_config.dirspace; stack_name; _ } as dirspace_config)
        ->
        if Dirspace_set.mem dirspace seen then unchanged
        else
          go
            (Dirspace_set.add dirspace seen, dirspace_config :: dirspace_configs)
            (CCList.filter_map
               (fun ds ->
                 let open CCOption.Infix in
                 Dirspace_map.get ds dirspaces
                 >>= fun dependency ->
                 if match_dependency ~dependent:dirspace_config ~dependency then Some dependency
                 else None)
               (Dirspace_map.get_or ~default:[] dirspace topology)
            @ Sln_map.String.get_or ~default:[] stack_name modifies_lookup))
      ~init:acc
      matches
  in
  CCList.rev @@ snd @@ go (Dirspace_set.empty, []) matches

(* [topo] maps a dirspace to those dirspaces that must wait for it.
   [dirspaces] is every matched dirspace, with no duplicates.

   Layer zero is every dirspace with no dependency of its own.  A dirspace
   leaves the frontier only when its last dependency has left, so the round it
   leaves in is [1 + max] of the layers of its dependencies.  That is the
   earliest layer its dependencies permit.

   This is Kahn's algorithm, run one frontier at a time.  Each dirspace is
   visited one time and each edge is relaxed one time, so the cost is
   [O((V + E) log V)] for [V] dirspaces and [E] edges. *)
let layers_of_topology topo dirspaces =
  let in_degree =
    Dirspace_map.fold
      (fun _ dependents acc ->
        CCListLabels.fold_left
          ~f:(fun acc dependent ->
            Dirspace_map.add dependent (1 + Dirspace_map.get_or ~default:0 dependent acc) acc)
          ~init:acc
          dependents)
      topo
      Dirspace_map.empty
  in
  let rec go acc in_degree = function
    | [] -> CCList.rev acc
    | frontier ->
        let in_degree, next =
          CCListLabels.fold_left
            ~f:(fun acc dirspace ->
              CCListLabels.fold_left
                ~f:(fun (in_degree, next) dependent ->
                  let n = Dirspace_map.get_or ~default:0 dependent in_degree - 1 in
                  (Dirspace_map.add dependent n in_degree, if n = 0 then dependent :: next else next))
                ~init:acc
                (Dirspace_map.get_or ~default:[] dirspace topo))
            ~init:(in_degree, [])
            frontier
        in
        go (frontier :: acc) in_degree (CCList.rev next)
  in
  go
    []
    in_degree
    (CCList.filter (fun ds -> Dirspace_map.get_or ~default:0 ds in_degree = 0) dirspaces)

(* The dirspaces that wait for [dirspace], keeping only the edges that [edge]
   calls real.  [topology] is (dependency -> dependents). *)
let dependents_of ~edge topology dirspaces dirspace =
  let dependent = Dirspace_map.find dirspace dirspaces in
  CCList.filter_map
    (fun ds ->
      let open CCOption.Infix in
      Dirspace_map.get ds dirspaces
      >>= fun dependency -> if edge ~dependent ~dependency then Some ds else None)
    (Dirspace_map.get_or ~default:[] dirspace topology)

(* An edge [X -> Z] for every path from [X] to [Z] whose interior dirspaces are
   all outside [match_set].

   A dirspace that is not running cannot hold anything back, but it must not
   break the order between the two dirspaces it sits between.  An applied
   dependency drops out and its dependent moves up, which is the point of the
   whole exercise.  A dirspace that [prune_no_change_dirspaces] removed keeps
   the order it carried, which a direct-edge rule loses.

   [topology_of_dirspace_configs] has already proved the graph acyclic, so this
   recursion terminates without a visit set.  The memo makes it one visit per
   dirspace. *)
let contracted_topo ~edge topology dirspaces match_set matches =
  (* [memo] is threaded through every call so that it accumulates across the
     whole traversal, and each dirspace is expanded one time. *)
  let rec reach memo dirspace =
    match Dirspace_map.get dirspace memo with
    | Some reached -> (memo, reached)
    | None ->
        let memo, reached =
          CCListLabels.fold_left
            ~f:(fun (memo, acc) ds ->
              if Dirspace_set.mem ds match_set then (memo, Dirspace_set.add ds acc)
              else
                let memo, reached = reach memo ds in
                (memo, Dirspace_set.union acc reached))
            ~init:(memo, Dirspace_set.empty)
            (dependents_of ~edge topology dirspaces dirspace)
        in
        (Dirspace_map.add dirspace reached memo, reached)
  in
  CCList.rev
  @@ snd
  @@ CCListLabels.fold_left
       ~f:(fun (memo, acc) dirspace ->
         let memo, reached = reach memo dirspace in
         (memo, (dirspace, Dirspace_set.to_list reached) :: acc))
       ~init:(Dirspace_map.empty, [])
       matches

let sort ?(topo = `Direct) ~edge topology dirspaces matches =
  (* The in-degree count needs each dirspace one time.  A duplicate would
     inflate the in-degree of everything that waits on it, and those dirspaces
     would never leave the frontier. *)
  let matches =
    CCList.rev
    @@ snd
    @@ CCListLabels.fold_left
         ~f:(fun ((seen, acc) as unchanged) { Dirspace_config.dirspace; _ } ->
           if Dirspace_set.mem dirspace seen then unchanged
           else (Dirspace_set.add dirspace seen, dirspace :: acc))
         ~init:(Dirspace_set.empty, [])
         matches
  in
  let match_set = Dirspace_set.of_list matches in
  let topo =
    Dirspace_map.of_list
    @@
    match topo with
    | `Contracted -> contracted_topo ~edge topology dirspaces match_set matches
    | `Direct ->
        (* Keep only those edges whose ends are both in the match set: a
           dependent that is not itself running imposes no order on anything. *)
        CCList.map
          (fun dirspace ->
            ( dirspace,
              CCList.filter
                (CCFun.flip Dirspace_set.mem match_set)
                (dependents_of ~edge topology dirspaces dirspace) ))
          matches
  in
  let layers = layers_of_topology topo matches in
  (* Every match is in exactly one layer.  A missing one means a cycle, and that
     should be detected in the synthesize step. *)
  if CCList.length (CCList.flatten layers) <> CCList.length matches then assert false;
  CCList.map (CCList.map (CCFun.flip Dirspace_map.find dirspaces)) layers

module Config = struct
  type t = {
    symlinks : string list CCTrie.String.t; [@opaque]
    dirspaces : Dirspace_config.t Dirspace_map.t;
    topology : Terrat_dirspace.t list Dirspace_map.t;
    stack_topology : string list Sln_map.String.t;
    stacks : Stack_config.t Sln_map.String.t;
  }
  [@@deriving show]

  let to_yojson t =
    let module T = struct
      type t = Dirspace_config.t list [@@deriving to_yojson]
    end in
    T.to_yojson (Iter.to_list (Dirspace_map.values t.dirspaces))

  let dirspace_configs t = t.dirspaces
  let stack_topology t = t.stack_topology
  let stacks t = t.stacks
end

(* We are actually going to build the topology in the reverse direction.  It
   should be (A -> B_list) A depends on the results of B_list.  But we're going
   to switch it such that all B's depend on A before they can run.  This is
   because:

   1. For cyclic dependency check, it doesn't matter the actual direction.

   2. We want to use this as a lookup such that we can take a match we have and
      look up all those that depend on it running first. *)
(* Two dirspaces are in the same stack when the paths to their stacks have a
   name in common: the stack itself when it is the same stack, an ancestor when
   they are two stacks nested under one.  A dirspace always shares a name with
   itself, so a [depends_on] that matches its own dirspace is never a boundary
   crossing. *)
let shares_a_stack a b =
  let names
      {
        Dirspace_config.stack_paths;
        dirspace = _;
        file_pattern_matcher = _;
        lock_branch_target = _;
        stack_config = _;
        stack_name = _;
        tags = _;
        when_modified = _;
      } =
    CCList.flatten stack_paths
  in
  let b = names b in
  CCList.exists (fun n -> CCList.mem ~eq:CCString.equal n b) (names a)

(* [Tsort.sort] answers a cycle with the nodes that never became isolated, which
   is the cycle AND everything downstream of it, in hash order.  That is enough
   to know there is a cycle and too little to report one, so ask for the
   strongly connected components instead: a component of more than one dirspace
   is a cycle, and so is a component of one dirspace that waits for itself.
   Report the edges inside it, each with the rule that made it. *)
let cycle_edges topology edges =
  let component_is_a_cycle = function
    | [] -> false
    | [ ds ] ->
        CCList.exists (Terrat_dirspace.equal ds) (Dirspace_map.get_or ~default:[] ds topology)
    | _ :: _ :: _ -> true
  in
  match
    CCList.find_opt
      component_is_a_cycle
      (Tsort.find_strongly_connected_components (Dirspace_map.to_list topology))
  with
  | Some component ->
      let member ds = CCList.exists (Terrat_dirspace.equal ds) component in
      CCList.filter
        (fun { Dependency_edge.dependent; dependency; rule = _ } ->
          member dependent && member dependency)
        edges
  (* [Tsort.sort] said there is a cycle and the components disagree.  That should
     not happen, and answering with every edge in the configuration would put a
     repository-sized list into a pull request comment, so answer with none and
     let the heading carry the message. *)
  | None -> []

let topology_of_dirspace_configs dirspaces =
  let module Wm = R.When_modified in
  let module Depends_on = R.Depends_on in
  let module S = R.Stacks.Stack in
  let module Rules = R.Stacks.Rules in
  let dirspaces = Dirspace_map.to_list dirspaces in
  let topology, edges =
    CCListLabels.fold_left
      ~f:(fun
          acc
          ( working_dirspace,
            ({
               Dirspace_config.when_modified =
                 {
                   Wm.depends_on;
                   autoapply = _;
                   autoplan = _;
                   autoplan_draft_pr = _;
                   file_patterns = _;
                   prechecks = _;
                 };
               stack_config =
                 {
                   S.rules = { Rules.plan_after; apply_after; modified_by = _; auto_apply = _ };
                   type_ = _;
                   variables = _;
                 };
               stack_name = working_stack_name;
               dirspace = _;
               file_pattern_matcher = _;
               lock_branch_target = _;
               stack_paths = _;
               tags = _;
             } as working_config) )
        ->
        (* A dirspace that declares no order over anything cannot make an edge
           with any partner, so its whole scan of [dirspaces] is dead work.  This
           is the common case -- most directories declare nothing -- and the
           scan is the whole of the quadratic cost, so skipping it here is what
           keeps a large repository affordable. *)
        if CCOption.is_none depends_on && CCList.is_empty plan_after && CCList.is_empty apply_after
        then acc
        else
          (* Both rules are closed transitively when the stacks are expanded, so
             these lists grow with the number of stacks.  The membership test
             below runs for every dirspace in the repository, so pay for the sets
             one time here rather than a list scan for each partner. *)
          let plan_after = Sln_set.String.of_list plan_after in
          let apply_after = Sln_set.String.of_list apply_after in
          CCListLabels.fold_left
            ~f:(fun
                (topology, edges)
                ( dirspace,
                  ({
                     Dirspace_config.tags;
                     stack_name;
                     dirspace = _;
                     file_pattern_matcher = _;
                     lock_branch_target = _;
                     stack_config = _;
                     stack_paths = _;
                     when_modified = _;
                   } as config) )
              ->
              let depends_on_matches =
                CCOption.map_or
                  ~default:false
                  (fun { Depends_on.tag_query; prune_on_no_change = _ } ->
                    (* The context is built here, and not once for the pair,
                       because only a [depends_on] needs it. *)
                    let ctx = Terrat_tag_query.Ctx.make ~working_dirspace ~dirspace () in
                    Terrat_tag_query.match_ ~ctx ~tag_set:tags tag_query)
                  depends_on
              in
              (* [depends_on] orders dirspaces inside a stack.  Reaching out of
                 the stack is the error a stack rule would be, and the two are
                 tested apart: a pair that a stack rule also orders must still
                 report it. *)
              if depends_on_matches && not (shares_a_stack working_config config) then
                raise
                  (Synthesize_config_err
                     (`Depends_on_crosses_stack_err
                        {
                          Stack_boundary.dependent = working_dirspace;
                          dependent_stack = working_stack_name;
                          dependency = dirspace;
                          dependency_stack = stack_name;
                        }));
              let plan_after_matches = Sln_set.String.mem stack_name plan_after in
              let apply_after_matches = Sln_set.String.mem stack_name apply_after in
              (* The pair with no edge must allocate nothing.  The labels cost
                 one record per edge, and there are as many edges as the
                 configuration declares. *)
              if not (depends_on_matches || plan_after_matches || apply_after_matches) then
                (topology, edges)
              else
                let edge rule =
                  { Dependency_edge.dependent = working_dirspace; dependency = dirspace; rule }
                in
                let edges = if apply_after_matches then edge "apply_after" :: edges else edges in
                let edges = if plan_after_matches then edge "plan_after" :: edges else edges in
                let edges = if depends_on_matches then edge "depends_on" :: edges else edges in
                (* This adds [working_dirspace] to the list of dirspaces that
                   depend on [dirspace] being completed before they can run. *)
                (Dirspace_map.add_to_list dirspace working_dirspace topology, edges))
            ~init:acc
            dirspaces)
      ~init:(Dirspace_map.empty, [])
      dirspaces
  in
  match Tsort.sort @@ Dirspace_map.to_list topology with
  | Tsort.Sorted _ -> topology
  | Tsort.ErrorCycle _ ->
      raise
        (Synthesize_config_err (`Depends_on_cycle_err (cycle_edges topology (CCList.rev edges))))

let build_symlinks =
  CCListLabels.fold_left
    ~f:(fun acc (src, dst) ->
      match CCTrie.String.find dst acc with
      | Some srcs -> CCTrie.String.add dst (src :: srcs) acc
      | None -> CCTrie.String.add dst [ src ] acc)
    ~init:CCTrie.String.empty

let compile_file_pattern_matcher file_patterns =
  let not_patterns, patterns = CCList.partition R.File_pattern.is_negate file_patterns in
  let patterns_match fname = CCList.exists (CCFun.flip R.File_pattern.is_match fname) patterns in
  let not_patterns_match fname =
    CCList.for_all (CCFun.flip R.File_pattern.is_match fname) not_patterns
  in
  fun fname -> patterns_match fname && not_patterns_match fname

let match_stacks dirspace tags stacks =
  CCList.filter
    (fun (_, config) ->
      match config with
      | { R.Stacks.Stack.type_ = R.Stacks.Type_.Stack tag_query; _ } ->
          Terrat_tag_query.match_
            ~ctx:(Terrat_tag_query.Ctx.make ~dirspace ())
            ~tag_set:tags
            tag_query
      | _ -> false)
    stacks

let build_stack_paths_lookup stacks =
  let module V1 = Terrat_base_repo_config_v1 in
  let module S = V1.Stacks in
  let deps =
    Sln_map.String.fold
      (fun k { S.Stack.type_; _ } acc ->
        let stacks =
          match type_ with
          | S.Type_.Nested stacks -> stacks
          | S.Type_.Stack _ -> []
        in
        CCListLabels.fold_left ~f:(fun acc s -> Sln_map.String.add_to_list s k acc) ~init:acc stacks)
      stacks
      Sln_map.String.empty
  in
  let rec go ~path name =
    match Sln_map.String.find_opt name deps with
    | Some parents -> CCList.flat_map (fun p -> go ~path:(p :: path) p) parents
    | None -> [ path ]
  in
  Sln_map.String.fold
    (fun k { S.Stack.type_; _ } acc ->
      match type_ with
      | S.Type_.Nested _ -> acc
      | S.Type_.Stack _ -> Sln_map.String.add k (go ~path:[ k ] k) acc)
    stacks
    Sln_map.String.empty

(* We want to support two operations around nested stacks.

   1. When a nested stack is defined we want to take its rules and variables
      section and recursively apply it to all stacks that it references.

   2. When a nested stack is referenced in a rule, we want to expand the rule
      out and incorporate it into the existing rule.

   The following configuration:

   stacks:
     names:
       databases:
         stacks:
           - database1
           - database2
         rules:
           modified_by:
             - base
       database1:
         tag_query: 'dir:database1'
       database2:
         tag_query: 'dir:database2'
       base:
         tag_query: 'dir:base'
       webservice:
         tag_query: 'dir:webservice'
         rules:
           modified_by:
             - databases

   Will be translated to:

   stacks:
     names:
       database1:
         tag_query: 'dir:database1'
         rules:
           modified_by:
             - base
       database2:
         tag_query: 'dir:database2'
         rules:
           modified_by:
             - base
       base:
         tag_query: 'dir:base'
       webservice:
         tag_query: 'dir:webservice'
         rules:
           modified_by:
             - database1
             - database2

   The one difference that makes this more than just a mechanical transformation
   is that the stackname [databases] is applied to the tags of [database1] and
   [database2]. *)

let stack_lookup name stacks =
  match Sln_map.String.find_opt name stacks with
  | Some stack -> stack
  | None -> raise (Synthesize_config_err (`Stack_not_found_err name))

let build_stack_lookup kv stacks =
  let module V1 = Terrat_base_repo_config_v1 in
  let module S = V1.Stacks in
  let rec collect_stacks path k =
    match stack_lookup k stacks with
    | { S.Stack.type_ = S.Type_.Nested ss; _ } ->
        CCList.flatten @@ CCList.map (fun s -> collect_stacks (k :: path) s) ss
    | { S.Stack.type_ = S.Type_.Stack _; _ } -> [ k ]
  in
  Sln_map.String.fold
    (fun k { S.Stack.type_; _ } acc ->
      match type_ with
      | S.Type_.Stack _ -> acc
      | S.Type_.Nested stack_refs ->
          CCListLabels.fold_left
            ~f:(fun acc s ->
              let k, v = kv k s in
              Sln_map.String.add_to_list k v acc)
            ~init:acc
            (CCList.flatten (CCList.map (fun s -> collect_stacks [ k ] s) stack_refs)))
    stacks
    Sln_map.String.empty

(* Lookup nested stack name -> stack names *)
let build_nested_to_stack_lookup stacks = build_stack_lookup (fun k v -> (k, v)) stacks

(* Lookup stack name -> nested stack names *)
let build_stack_to_nested_lookup stacks = build_stack_lookup (fun k v -> (v, k)) stacks

(* Build a lookup of a stack to which other stacks it modifies. *)
let build_modifies_lookup dirspace_configs =
  let module V1 = Terrat_base_repo_config_v1 in
  let module S = V1.Stacks in
  CCListLabels.fold_left
    ~f:(fun
        acc
        ({
           Dirspace_config.stack_name = _;
           stack_config = { S.Stack.rules = { S.Rules.modified_by; _ }; _ };
           _;
         } as dc)
      ->
      CCListLabels.fold_left
        ~f:(fun acc s -> Sln_map.String.add_to_list s dc acc)
        ~init:acc
        modified_by)
    ~init:Sln_map.String.empty
    dirspace_configs

let rec collect_deps ?(acc = []) ~accessor stacks names =
  let module V1 = Terrat_base_repo_config_v1 in
  let module S = V1.Stacks in
  names
  @ CCListLabels.fold_left
      ~f:(fun acc n ->
        if not (CCList.mem ~eq:CCString.equal n acc) then
          collect_deps ~acc:(n :: acc) ~accessor stacks [ n ]
        else acc)
      ~init:acc
  @@ CCList.flat_map (fun { S.Stack.rules; _ } -> accessor rules)
  @@ CCList.map (CCFun.flip Sln_map.String.find stacks) names

(* Expand a config by any nested stacks its related to.  This expands it in two ways:

   1. For any nested stacks that reference us, we want to expand any rules they have into us.

   2. Any nested stacks that are referenced in a rule we want to expand to the
      concrete stack name.

   3. All transitive dependencies are expanded out.  So if A depends on B which
      depends on C, A will depend on B and C.

   We also want to do it in this order because we want any nested stacks to then
   be expanded out after they are added to the rules. *)
let expand_stack_config name config nested_to_stack_lookup stack_to_nested_lookup stacks =
  let module V1 = Terrat_base_repo_config_v1 in
  let module S = V1.Stacks in
  let module R = S.Rules in
  let { S.Stack.type_ = _; rules; variables } = config in
  let variables =
    CCListLabels.fold_left
      ~f:(fun acc s ->
        let { S.Stack.variables; _ } = stack_lookup s stacks in
        (* Merge variables but for any overlapping variables take the ones that
           already exist instead of overwriting them *)
        Sln_map.String.union (fun _ v _ -> Some v) acc variables)
      ~init:variables
      (Sln_map.String.get_or ~default:[] name stack_to_nested_lookup)
  in
  let { R.modified_by; plan_after; apply_after; auto_apply } =
    CCListLabels.fold_left
      ~f:(fun { R.modified_by; plan_after; apply_after; auto_apply } s ->
        let { S.Stack.rules; _ } = stack_lookup s stacks in
        {
          R.modified_by = modified_by @ rules.R.modified_by;
          plan_after = plan_after @ rules.R.plan_after;
          apply_after = apply_after @ rules.R.apply_after;
          auto_apply = CCOption.or_ ~else_:auto_apply rules.R.auto_apply;
        })
      ~init:rules
      (Sln_map.String.get_or ~default:[] name stack_to_nested_lookup)
  in
  let rules =
    {
      R.modified_by =
        Sln_set.String.dedup_list
        @@ collect_deps ~accessor:(fun { R.modified_by; _ } -> modified_by) stacks
        @@ CCList.flat_map
             (fun s -> Sln_map.String.get_or ~default:[ s ] s nested_to_stack_lookup)
             modified_by;
      plan_after =
        Sln_set.String.dedup_list
        @@ collect_deps ~accessor:(fun { R.plan_after; _ } -> plan_after) stacks
        @@ CCList.flat_map
             (fun s -> Sln_map.String.get_or ~default:[ s ] s nested_to_stack_lookup)
             plan_after;
      apply_after =
        Sln_set.String.dedup_list
        @@ collect_deps ~accessor:(fun { R.apply_after; _ } -> apply_after) stacks
        @@ CCList.flat_map
             (fun s -> Sln_map.String.get_or ~default:[ s ] s nested_to_stack_lookup)
             apply_after;
      auto_apply;
    }
  in
  { config with S.Stack.rules; variables }

let assert_all_stacks_exist stacks =
  let module V1 = Terrat_base_repo_config_v1 in
  let module S = V1.Stacks in
  Sln_map.String.iter
    (fun _ { S.Stack.type_; rules; variables = _ } ->
      let nested_stacks =
        match type_ with
        | S.Type_.Nested stacks -> stacks
        | S.Type_.Stack _ -> []
      in
      let { S.Rules.modified_by; plan_after; apply_after; auto_apply = _ } = rules in
      let all_stacks = nested_stacks @ modified_by @ plan_after @ apply_after in
      CCList.iter (fun s -> ignore (stack_lookup s stacks)) all_stacks)
    stacks

let assert_no_stack_cycle stacks =
  let module V1 = Terrat_base_repo_config_v1 in
  let module S = V1.Stacks in
  let deps =
    Sln_map.String.fold
      (fun k { S.Stack.type_; rules; _ } acc ->
        let stacks =
          match type_ with
          | S.Type_.Nested stacks -> stacks
          | S.Type_.Stack _ -> []
        in
        let { S.Rules.plan_after; apply_after; _ } = rules in
        Sln_map.String.add k (stacks @ plan_after @ apply_after) acc)
      stacks
      Sln_map.String.empty
  in
  let topo = Sln_map.String.to_list deps in
  match Tsort.sort topo with
  | Tsort.Sorted _ -> ()
  | Tsort.ErrorCycle cycle -> raise (Synthesize_config_err (`Stack_cycle_err cycle))

let synthesize_config ~index repo_config =
  let module V1 = Terrat_base_repo_config_v1 in
  let module S = V1.Stacks in
  try
    let symlinks = build_symlinks index.R.Index.symlinks in
    let stacks = R.stacks repo_config in
    assert_all_stacks_exist stacks.R.Stacks.names;
    assert_no_stack_cycle stacks.R.Stacks.names;
    let stack_paths_lookup = build_stack_paths_lookup stacks.R.Stacks.names in
    (* Lookup up for a stack name to the stacks nested under it. *)
    let nested_to_stack_lookup = build_nested_to_stack_lookup stacks.R.Stacks.names in
    (* Lookup of a stack to any stacks that nest it. *)
    let stack_to_nested_lookup = build_stack_to_nested_lookup stacks.R.Stacks.names in
    let stacks =
      Sln_map.String.mapi
        (fun name config ->
          match config with
          | { S.Stack.type_ = S.Type_.Stack _; _ } ->
              expand_stack_config
                name
                config
                nested_to_stack_lookup
                stack_to_nested_lookup
                stacks.R.Stacks.names
          | { S.Stack.type_ = S.Type_.Nested _; _ } -> config)
        stacks.R.Stacks.names
    in
    let stack_topology =
      Sln_map.String.map (fun { S.Stack.rules = { S.Rules.plan_after; _ }; _ } -> plan_after) stacks
    in
    let no_default_stack = not (Sln_map.String.mem "default" stacks) in
    let stack_configs = Sln_map.String.to_list stacks in
    let dirspaces =
      repo_config
      |> R.dirs
      |> Sln_map.String.to_list
      |> CCList.flat_map (fun (dirname, config) ->
          let module D = R.Dirs.Dir in
          let module Ws = R.Dirs.Workspace in
          let module Wm = R.When_modified in
          CCList.flat_map
            (fun (workspace, workspace_config) ->
              let dirspace = { Terrat_dirspace.dir = dirname; workspace } in
              let tags = Terrat_tag_set.of_list workspace_config.Ws.tags in
              (* Determine which stack the dirspace is part of.  In this
                    implementation, a dirspace can only be part of a single
                    stack.  If a dirspace does not match any stack AND there is
                    no [default] stack configured by the user, the dirspace
                    implicitly gets made part of the default stack.  In the
                    future, this dirspace should actually be filtered out rather
                    than fail. *)
              let stack_name, stack_config =
                match match_stacks dirspace tags stack_configs with
                | [] when no_default_stack ->
                    ( "default",
                      R.Stacks.Stack.make ~type_:(R.Stacks.Type_.Stack Terrat_tag_query.any) () )
                | [] -> raise (Synthesize_config_err (`Workspace_matches_no_stacks_err dirspace))
                | [ (stack_name, stack_config) ] -> (stack_name, stack_config)
                | _ :: _ ->
                    raise (Synthesize_config_err (`Workspace_in_multiple_stacks_err dirspace))
              in
              let tags =
                Terrat_tag_set.of_list
                  (CCList.map
                     (fun n -> "stack_name:" ^ n)
                     (stack_name
                     :: Sln_map.String.get_or ~default:[] stack_name stack_to_nested_lookup)
                  @ workspace_config.Ws.tags)
              in
              (* If the dirspace is explicitly ignored via an empty
                    [file_patterns], do not even include it so that we don't
                    waste time trying to match against it. *)
              match workspace_config.Ws.when_modified.Wm.file_patterns with
              | [] -> []
              | _ :: _ ->
                  [
                    ( dirspace,
                      {
                        Dirspace_config.dirspace;
                        file_pattern_matcher =
                          compile_file_pattern_matcher
                            workspace_config.Ws.when_modified.Wm.file_patterns;
                        lock_branch_target = config.D.lock_branch_target;
                        stack_config;
                        stack_name;
                        stack_paths =
                          (match Sln_map.String.find_opt stack_name stack_paths_lookup with
                          | Some paths -> paths
                          | None when CCString.equal stack_name "default" -> [ [ "default" ] ]
                          | None -> assert false);
                        tags;
                        when_modified = workspace_config.Ws.when_modified;
                      } );
                  ])
            (Sln_map.String.to_list config.D.workspaces @ Sln_map.String.to_list config.D.stacks))
    in
    let default_stack =
      CCList.find_opt
        (fun (_, { Dirspace_config.stack_name; _ }) -> CCString.equal "default" stack_name)
        dirspaces
    in
    (* Construct our stacks.  The one sticky part is that if there is no
       configured "default" stack but one has been discovered while processing
       all the dirspaces, then we need to add it to our stacks. *)
    let stacks, stack_topology =
      let stacks =
        Sln_map.String.filter_map
          (fun name config ->
            match config with
            | { S.Stack.type_ = S.Type_.Nested _; _ } -> None
            | config ->
                Some
                  { Stack_config.name; config; paths = Sln_map.String.find name stack_paths_lookup })
          stacks
      in
      match default_stack with
      | Some
          (_, { Dirspace_config.stack_name = name; stack_paths = paths; stack_config = config; _ })
        when not (Sln_map.String.mem "default" stacks) ->
          (* Add the default stack information *)
          let stacks = Sln_map.String.add "default" { Stack_config.name; config; paths } stacks in
          let stack_topology = Sln_map.String.add "default" [] stack_topology in
          (stacks, stack_topology)
      | Some _ | None -> (stacks, stack_topology)
    in
    let dirspaces = Dirspace_map.of_list dirspaces in
    let topology = topology_of_dirspace_configs dirspaces in
    Ok { Config.symlinks; dirspaces; topology; stack_topology; stacks }
  with Synthesize_config_err err ->
    Error (err : synthesize_config_err :> [> synthesize_config_err ])

let make_dir_map file_list =
  CCList.fold_left
    (fun acc fname ->
      let dirname = Filename.dirname fname in
      Sln_map.String.add_to_list dirname fname acc)
    Sln_map.String.empty
    file_list

let files_of_diff = function
  | Terrat_change.Diff.Add { filename }
  | Terrat_change.Diff.Change { filename }
  | Terrat_change.Diff.Remove { filename } -> [ filename ]
  | Terrat_change.Diff.Move { filename; previous_filename } -> [ filename; previous_filename ]

let match_dir_map dirspaces dir_map =
  snd
    (Sln_map.String.fold
       (fun _ files ((dirspaces, _matches) as acc) ->
         Dirspace_map.fold
           (fun dirspace
                ({ Dirspace_config.file_pattern_matcher; _ } as dirspace_config)
                ((dirspaces, matches) as acc)
              ->
             if CCList.exists file_pattern_matcher files then
               (Dirspace_map.remove dirspace dirspaces, dirspace_config :: matches)
             else acc)
           dirspaces
           acc)
       dir_map
       (dirspaces, []))

let prune_no_change_dirspaces real_change_set layers =
  let module Wm = R.When_modified in
  let module Depends_on = R.Depends_on in
  let keep { Dirspace_config.dirspace; when_modified = { Wm.depends_on; _ }; _ } =
    Dirspace_set.mem dirspace real_change_set
    || CCOption.map_or
         ~default:true
         (fun { Depends_on.prune_on_no_change; _ } -> not prune_on_no_change)
         depends_on
  in
  layers
  |> CCList.map (CCList.filter keep)
  |> CCList.filter (function
    | [] -> false
    | _ :: _ -> true)

let match_diff_list ?(force_matches = []) config diff_list =
  (* If this fpath maps to a symlink we want to rewrite it to be the symlink *)
  let map_symlink_file_path symlinks fpath =
    match
      ( CCTrie.String.find fpath symlinks,
        Iter.head (CCTrie.String.below (Filename.dirname fpath) symlinks) )
    with
    | Some srcs, _ ->
        CCList.map (fun src -> CCString.replace ~which:`Left ~sub:fpath ~by:src fpath) srcs
    | _, Some (dst, srcs) when CCString.prefix ~pre:dst fpath ->
        CCList.map (fun src -> CCString.replace ~which:`Left ~sub:dst ~by:src fpath) srcs
    | _, (Some _ | None) -> [ fpath ]
  in
  let modifies_lookup =
    build_modifies_lookup @@ Iter.to_list @@ Dirspace_map.values config.Config.dirspaces
  in
  let real_matches =
    diff_list
    |> CCList.flat_map files_of_diff
    |> CCList.flat_map (map_symlink_file_path config.Config.symlinks)
    |> make_dir_map
    |> match_dir_map config.Config.dirspaces
    |> CCList.append force_matches
  in
  let real_change_set =
    Dirspace_set.of_list (CCList.map (fun { Dirspace_config.dirspace; _ } -> dirspace) real_matches)
  in
  real_matches
  |> collect_dependents config.Config.topology modifies_lookup config.Config.dirspaces
  |> sort ~edge:match_plan_after_dependency config.Config.topology config.Config.dirspaces
  |> prune_no_change_dirspaces real_change_set

(* Both of these re-layer a subset of a run, so both contract through the
   dirspaces they are not given.  They differ only in which stack rule counts
   as an edge. *)
let layers_of config dirspace_configs =
  sort
    ~topo:`Contracted
    ~edge:match_plan_after_dependency
    config.Config.topology
    config.Config.dirspaces
    dirspace_configs

let apply_layers_of config dirspace_configs =
  sort
    ~topo:`Contracted
    ~edge:match_apply_after_dependency
    config.Config.topology
    config.Config.dirspaces
    dirspace_configs

let of_dirspace config dirspace = Dirspace_map.get dirspace config.Config.dirspaces

let merge_with_dedup l1 l2 =
  let map_of_list l =
    Dirspace_map.of_list
      (CCList.map
         (fun ({ Dirspace_config.dirspace; _ } as dirspace_config) -> (dirspace, dirspace_config))
         l)
  in
  let m1 = map_of_list l1 in
  let m2 = map_of_list l2 in
  Iter.to_list (Dirspace_map.values (Dirspace_map.union (fun _ v _ -> Some v) m1 m2))

let match_tag_query ~tag_query { Dirspace_config.dirspace; tags; _ } =
  let ctx = Terrat_tag_query.Ctx.make ~dirspace () in
  Terrat_tag_query.match_ ~ctx ~tag_set:tags tag_query
