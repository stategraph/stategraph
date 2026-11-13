module type S = sig
  val parallel_applies : bool

  val overlaps :
    request_id:string ->
    installation:Uuidm.t ->
    tx:Uuidm.t ->
    other_tx_ids:Uuidm.t list ->
    (Sln_set.String.t Sln_map.Uuidm.t, [> `Error ]) result Abb.Future.t

  val reserve :
    request_id:string ->
    installation:Uuidm.t ->
    holder:string ->
    pull_request:string ->
    txs:Uuidm.t list ->
    (unit, [> `Error ]) result Abb.Future.t

  val release : request_id:string -> holder:string -> (unit, [> `Error ]) result Abb.Future.t

  val release_hold :
    request_id:string -> pull_request:string -> (unit, [> `Error ]) result Abb.Future.t
end

type t = (module S)

module Standalone = struct
  let parallel_applies = false

  let overlaps ~request_id:_ ~installation:_ ~tx:_ ~other_tx_ids:_ =
    Abb.Future.return (Ok Sln_map.Uuidm.empty)

  let reserve ~request_id:_ ~installation:_ ~holder:_ ~pull_request:_ ~txs:_ =
    Abb.Future.return (Ok ())

  let release ~request_id:_ ~holder:_ = Abb.Future.return (Ok ())
  let release_hold ~request_id:_ ~pull_request:_ = Abb.Future.return (Ok ())
end
