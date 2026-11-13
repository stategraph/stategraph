(** What the orchestration asks Stategraph when it evaluates an apply, in the words of the
    orchestration: transactions are the ids the stored plans name, read by the orchestration, and an
    installation is the core id of the VCS installation the repository belongs to.

    The implementation is a module argument of the VCS service. The unified server, where the
    Stategraph database is at hand, gives it Stategraph in its process; the orchestration on its own
    gives it {!Standalone}. *)

module type S = sig
  (** Whether the orchestration reaches Stategraph. Parallel applies need it: the reservation of an
      apply's transactions and the hold of their commit are what keep them safe, and only the reader
      makes them. *)
  val parallel_applies : bool

  (** The transactions of [other_tx_ids] that stand against [tx], each with the addresses of the
      nodes the two share: each shares a node with [tx] that at least one of them does more than
      read, and it is applying, it committed after [tx] opened, or its commit is held. Those are the
      transactions whose commit, or whose committed state, Stategraph refuses [tx] for; a
      transaction committed before [tx] opened and not held is not one, as [tx] was planned over it.

      Only the transactions of the tenants of [installation] are seen: a transaction of another
      tenant, or an id that names no transaction, stands against nothing. *)
  val overlaps :
    request_id:string ->
    installation:Uuidm.t ->
    tx:Uuidm.t ->
    other_tx_ids:Uuidm.t list ->
    (Sln_set.String.t Sln_map.Uuidm.t, [> `Error ]) result Abb.Future.t

  (** Reserve [txs] for the apply of [holder], the work manifest about to commit them: from now
      until that commit, or until [release], Stategraph refuses an overlapping commit of another
      transaction as it would for a transaction being committed. This closes the window between the
      check of an apply and its commit. A reservation nobody releases lapses after an hour. A
      transaction that is not previewed, or not of the tenants of [installation], is not reserved,
      and that is no error: the commit then decides on its own. [pull_request] names the pull
      request of the apply: it is the key of the hold the commit takes, see {!release_hold}.
      Stategraph knows the key as an opaque string; what it names is the orchestration's. *)
  val reserve :
    request_id:string ->
    installation:Uuidm.t ->
    holder:string ->
    pull_request:string ->
    txs:Uuidm.t list ->
    (unit, [> `Error ]) result Abb.Future.t

  (** Give back the transactions [holder] reserved and did not commit. *)
  val release : request_id:string -> holder:string -> (unit, [> `Error ]) result Abb.Future.t

  (** A reserved transaction commits under a hold keyed by the pull request the reservation named,
      and the commit stands against every overlapping transaction, whenever it opened, until the
      hold goes; all but one reserved under the same key, a later plan of the pull request, which
      contains the change. A plan made after the commit from a branch that lacks the pull request's
      change would revert it, and Stategraph cannot tell such a plan apart: only the orchestration
      knows the pull request is not merged. [release_hold] lets go of the holds keyed by
      [pull_request], once it merged, was closed or was unlocked. *)
  val release_hold :
    request_id:string -> pull_request:string -> (unit, [> `Error ]) result Abb.Future.t
end

type t = (module S)

(** The orchestration on its own, with no Stategraph in its process: it has nothing to ask, so
    nothing overlaps, nothing is reserved and nothing is held, and no dirspace applies in parallel.
    Stategraph's commit refuses an overlapping apply when it runs, as it always has. *)
module Standalone : S
