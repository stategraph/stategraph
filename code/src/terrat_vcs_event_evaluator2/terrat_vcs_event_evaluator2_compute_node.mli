(** What a compute node can do, and whether it can do one more thing.

    A compute node is one action run. Neither of these answers needs the VCS, so they live apart
    from the state machine that uses them and a test can ask them directly. *)

(** How many work manifests one action run may perform.

    The action stops after eleven turns of its loop, to catch a server that never says done. A node
    that gave out more work than that would leave a work manifest on a run that has gone, and
    nothing would perform it. The chain of layers is what makes that reachable: a job of many layers
    gives a node one work manifest for each of them.

    This is the hard ceiling. [batch_runs.max_work_manifests_per_node] is the configured cap, and it
    only lowers this one, so an action of any version is safe. *)
val max_work_manifests_per_compute_node : int

(** Spread the work manifests of one creation call over the nodes that call makes.

    A node is one action run, and its startup is paid once. The work is therefore spread as evenly
    as the cap allows over as few nodes as the cap requires: ten work manifests with a cap of nine
    make two nodes of five, and not nine and one, because a node of nine and one makes the last work
    manifest wait for a whole run of its own. A count that does not divide evenly leaves a
    difference of one work manifest between the nodes, never more.

    [max_per_node] is held between one and [max_work_manifests_per_compute_node], as it is in
    [can_run]. An empty list makes no nodes. *)
val spread_over_nodes : max_per_node:int -> 'a list -> 'a list list

(** The capabilities of a node made for one work manifest.

    The node has taken that work manifest, so it is charged for it here. A charge is made when the
    work manifest is given to the node, and not when it runs.

    The phase comes from the work manifest the node is made for, and it stays the same for the life
    of the node: a node that takes a second work manifest writes the record back with this field
    untouched. *)
val capabilities_of :
  ('a, 'b) Terrat_work_manifest3.Existing.t -> Terrat_job_context.Compute_node.Capabilities.t

(** Whether a compute node can run a work manifest.

    A node is one action run. [environment] and [runs_on] are inputs of the workflow dispatch, so
    the VCS fixes them when it schedules the job, and a work manifest that joins the run takes the
    values of the run. They must therefore agree. The refs must agree as well, because one job
    evaluation covers the working branch and the destination branch, and the action of a node has
    one of them checked out.

    A node takes work while it is [Queued] or [Starting]. A node is [Queued] from the moment the
    server makes it until the dispatcher starts its action run, so a node that one creation call
    made takes the rest of the work of that call. A [Running] node takes nothing: its result
    evaluation forks in the background and gives its next layer a node of its own.

    [max_work_manifests_per_node] is how many work manifests one action run may perform. It is the
    cap the repository configuration gives now, and not one the node carries, and it is held between
    one and [max_work_manifests_per_compute_node].

    The three steps that prepare a job pass this test without a special case. They carry no
    environment, no runs_on and no dirspace, so they agree with each other.

    The configuration answers first: [merge_steps] gives the steps that may join a run, and a step
    it does not name always takes a run of its own. *)
val can_run :
  merge_steps:Terrat_base_repo_config_v1.Batch_runs.Merge_steps.t ->
  max_work_manifests_per_node:int ->
  Terrat_job_context.Compute_node.t ->
  ('a, 'b) Terrat_work_manifest3.Existing.t ->
  bool
