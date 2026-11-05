module Transaction = struct
  type t = {
    created_at : string;
    completed_at : string option;
  }
end

module type S = sig
  val transactions :
    request_id:string ->
    installation:Uuidm.t ->
    txs:Uuidm.t list ->
    (Transaction.t Sln_map.Uuidm.t, [> `Error ]) result Abb.Future.t

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
    txs:Uuidm.t list ->
    (unit, [> `Error ]) result Abb.Future.t

  val release : request_id:string -> holder:string -> (unit, [> `Error ]) result Abb.Future.t
end

type t = (module S)

module Standalone = struct
  let transactions ~request_id:_ ~installation:_ ~txs:_ = Abb.Future.return (Ok Sln_map.Uuidm.empty)

  let overlaps ~request_id:_ ~installation:_ ~tx:_ ~other_tx_ids:_ =
    Abb.Future.return (Ok Sln_map.Uuidm.empty)

  let reserve ~request_id:_ ~installation:_ ~holder:_ ~txs:_ = Abb.Future.return (Ok ())
  let release ~request_id:_ ~holder:_ = Abb.Future.return (Ok ())
end
