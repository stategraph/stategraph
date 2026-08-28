module Strategy = struct
  type t =
    | Append
    | Delete
    | Minimize
  [@@deriving ord, show]
end

module type S = sig
  type t
  type el [@@deriving ord, show]
  type comment_id [@@deriving ord, show]

  val query_comment_id : t -> el -> (comment_id option, [> `Error ]) result Abb.Future.t
  val query_els_for_comment_id : t -> comment_id -> (el list, [> `Error ]) result Abb.Future.t
  val upsert_comment_id : t -> el list -> comment_id -> (unit, [> `Error ]) result Abb.Future.t
  val delete_comment : t -> comment_id -> (unit, [> `Error ]) result Abb.Future.t
  val minimize_comment : t -> comment_id -> (unit, [> `Error ]) result Abb.Future.t
  val post_comment : t -> el list -> (comment_id, [> `Error ]) result Abb.Future.t
  val rendered_length : t -> el list -> int
  val dirspace : el -> Terrat_dirspace.t
  val strategy : el -> Strategy.t
  val compact : el -> el
  val max_comment_length : int
end

module Make (M : S) = struct
  module By_strategy = Terrat_data.Group_by (struct
    type t = M.el
    type key = Strategy.t

    let key = M.strategy
    let compare = Strategy.compare
  end)

  module Id_set = CCSet.Make (struct
    type t = M.comment_id

    let compare = M.compare_comment_id
  end)

  module El_set = CCSet.Make (struct
    type t = M.el

    let compare el1 el2 = Terrat_dirspace.compare (M.dirspace el1) (M.dirspace el2)
  end)

  let partition_by_strategy els = By_strategy.group els
  let compact t e = if M.rendered_length t [ e ] < M.max_comment_length then e else M.compact e

  let find_existing_comments_for_el t els =
    let open Abbs_future_combinators.Infix_result_monad in
    let module Alr = Abbs_future_combinators.List_result in
    Alr.filter_map ~f:(fun el -> M.query_comment_id t el) els
    >>| fun cids ->
    let uniq = Id_set.of_list cids |> Id_set.to_list in
    uniq

  let find_all_els_from t comment_ids =
    let open Abbs_future_combinators.Infix_result_monad in
    let module Alr = Abbs_future_combinators.List_result in
    Alr.map ~f:(M.query_els_for_comment_id t) comment_ids
    >>| fun elss ->
    let flat = CCList.flatten elss in
    let set = El_set.of_list flat in
    let list = El_set.to_list set in
    list

  let split_by_size t els =
    let combine (groups, curr_acc) r =
      if M.rendered_length t (r :: curr_acc) < M.max_comment_length then (groups, r :: curr_acc)
      else (CCList.rev curr_acc :: groups, [ r ])
    in
    let groups, rest = CCList.fold_left combine ([], []) els in
    CCList.rev (CCList.rev rest :: groups) |> CCList.filter CCFun.(CCList.is_empty %> not)

  let fetch_and_apply fn t els =
    let open Abbs_future_combinators.Infix_result_monad in
    let module Alr = Abbs_future_combinators.List_result in
    find_existing_comments_for_el t els
    >>= fun cids ->
    Alr.iter ~f:fn cids
    >>= fun () ->
    find_all_els_from t cids
    >>= fun els' ->
    (* Do not confuse "els" with "els'", the first being new changes and the
       latter being "every element that may be related to the new" stuff. 

       When assembling a new comment we need to make sure we are not forgetting 
       old outputs as well. So even if you do a "terrateam plan dir:tf1", we
       we also need to pull off old plans for 'dir:tf2' and 'dir:tf2' (example)
       and add them back to the new VCS comment. *)
    let og_els = El_set.of_list els in
    let union =
      CCList.fold_left
        (fun acc el -> if El_set.mem el acc then acc else El_set.add el acc)
        og_els
        els'
    in
    let compressed = El_set.map (compact t) union in
    let sorted = CCList.sort M.compare_el (El_set.to_list compressed) in
    let split = split_by_size t sorted in
    Alr.iter
      ~f:(fun es -> M.post_comment t es >>= fun new_cid -> M.upsert_comment_id t es new_cid)
      split

  let append t els =
    let open Abbs_future_combinators.Infix_result_monad in
    let module Alr = Abbs_future_combinators.List_result in
    let append_single t els = M.post_comment t els >>= fun cid -> M.upsert_comment_id t els cid in
    let compressed = CCList.map (compact t) els in
    let sorted = CCList.sort M.compare_el compressed in
    let split = split_by_size t sorted in
    Alr.iter ~f:(append_single t) split

  let delete t els = fetch_and_apply (M.delete_comment t) t els
  let minimize t els = fetch_and_apply (M.minimize_comment t) t els

  let run t els =
    let open Abbs_future_combinators.Infix_result_monad in
    let groups = partition_by_strategy els in
    match groups with
    | [] -> M.post_comment t [] >>| fun _ -> ()
    | _ ->
        Abbs_future_combinators.List_result.iter
          ~f:(function
            | Strategy.Append, els -> append t els
            | Strategy.Delete, els -> delete t els
            | Strategy.Minimize, els -> minimize t els)
          groups
end
