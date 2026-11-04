module Merge_steps = Terrat_vcs_event_evaluator2_merge_steps
module Tjc = Terrat_job_context
module Wm = Terrat_work_manifest3

let max_work_manifests_per_compute_node = 9

(* The configuration gives the cap, and the server holds it between one and the
   turns of the action loop.  The schema rejects a value outside that range, but a
   configuration built in memory can hold one, and a cap below one would let no
   work manifest join a node. *)
let clamp_max_per_node max_per_node =
  CCInt.max 1 (CCInt.min max_per_node max_work_manifests_per_compute_node)

(* The states of a node that can take work.  A node is [Queued] from the moment
   the server makes it until the dispatcher starts its action run, and [Starting]
   while that run polls.  A node this very call made is [Queued], so it must be
   admitted, or the work of one call could not spread over the nodes the call
   made.  [Running] is out: the join happens while the node is [Starting], and a
   [Running] node's result evaluation forks in the background and gives its next
   layer a node of its own. *)
let can_take_work = function
  | Tjc.Compute_node.State.Queued | Tjc.Compute_node.State.Starting -> true
  | Tjc.Compute_node.State.Running | Tjc.Compute_node.State.Terminated -> false

(* Spread work over as few nodes as the cap requires, as evenly as it allows.
   Ten work manifests with a cap of nine make two nodes of five, and not nine and
   one: a node of nine and one makes the last work manifest wait for a whole run
   of its own.

   [CCList.chunks] is not enough on its own.  It splits at a fixed size, so a
   count that does not divide evenly leaves the remainder in the last group.  The
   sizes are therefore computed first: every node takes [count / nodes], and the
   first [count mod nodes] take one more. *)
let spread_over_nodes ~max_per_node work_manifests =
  let max_per_node = clamp_max_per_node max_per_node in
  let count = CCList.length work_manifests in
  if count = 0 then []
  else
    let nodes = (count + max_per_node - 1) / max_per_node in
    let base = count / nodes in
    let extra = count mod nodes in
    let rec split sizes work_manifests =
      match sizes with
      | [] -> []
      | size :: sizes ->
          let group, rest = CCList.take_drop size work_manifests in
          group :: split sizes rest
    in
    split (CCList.init nodes (fun i -> base + if i < extra then 1 else 0)) work_manifests

let capabilities_of { Wm.branch_ref; environment; runs_on; steps; _ } =
  {
    Tjc.Compute_node.Capabilities.flags = [];
    sha = branch_ref;
    environment;
    runs_on;
    used_work_manifests = 1;
    merge_phase = Merge_steps.phase_of steps;
  }

let can_run ~merge_steps ~max_work_manifests_per_node compute_node work_manifest =
  let module C = Tjc.Compute_node in
  let module Cap = C.Capabilities in
  let module Rp = Terrat_vcs_event_evaluator2_batch.Run_params in
  let { Cap.environment; runs_on; used_work_manifests; merge_phase; _ } =
    compute_node.C.capabilities
  in
  Merge_steps.permits merge_steps ~node_phase:merge_phase work_manifest.Wm.steps
  && can_take_work compute_node.C.state
  && used_work_manifests < clamp_max_per_node max_work_manifests_per_node
  && CCString.equal compute_node.C.capabilities.Cap.sha work_manifest.Wm.branch_ref
  && Rp.equal (environment, runs_on) (work_manifest.Wm.environment, work_manifest.Wm.runs_on)
