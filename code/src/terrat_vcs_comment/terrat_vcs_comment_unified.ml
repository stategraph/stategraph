module Status = struct
  type t =
    | Failed
    | Planned
    | Pending
    | Applied
  [@@deriving ord, show]

  let rank = function
    | Failed -> 0
    | Planned -> 1
    | Pending -> 2
    | Applied -> 3
end

module Tier = struct
  type t =
    | Details of int
    | Table
    | Truncated of int
  [@@deriving ord, show]
end

module type S = sig
  type t
  type el [@@deriving ord, show]
  type comment_id [@@deriving ord, show]

  val query_comment_id : t -> (comment_id option, [> `Error ]) result Abb.Future.t
  val query_els : t -> (el list, [> `Error ]) result Abb.Future.t
  val render : t -> Tier.t -> el list -> string

  val update_comment :
    t -> comment_id -> string -> (unit, [> `Not_found | `Error ]) result Abb.Future.t

  val post_comment : t -> string -> (comment_id, [> `Error ]) result Abb.Future.t
  val upsert_comment_id : t -> comment_id -> (unit, [> `Error ]) result Abb.Future.t
  val dirspace : el -> Terrat_dirspace.t
  val status : el -> Status.t
  val has_changes : el -> bool
  val max_comment_length : int
end

module Make (M : S) = struct
  let compare_el el1 el2 =
    let module Cmp = struct
      type t = int * bool * Terrat_dirspace.t [@@deriving ord]
    end in
    (* [not has_changes] so elements with changes sort first within a status *)
    let key el = (Status.rank (M.status el), not (M.has_changes el), M.dirspace el) in
    Cmp.compare (key el1) (key el2)

  let sort_els els = CCList.sort compare_el els

  (* Tiers from richest to most compact.  The last tier is used unconditionally
     if nothing else fits, so it must always be renderable: a handful of table
     rows plus a truncation notice. *)
  let tiers els =
    let n = CCList.length els in
    CCList.filter_map
      CCFun.id
      [
        Some (Tier.Details n);
        (if n > 20 then Some (Tier.Details 20) else None);
        (if n > 5 then Some (Tier.Details 5) else None);
        Some Tier.Table;
        (if n > 100 then Some (Tier.Truncated 100) else None);
        (if n > 50 then Some (Tier.Truncated 50) else None);
        Some (Tier.Truncated 10);
      ]

  let fit t els =
    let rec first_fit = function
      | [] -> assert false
      | [ tier ] -> M.render t tier els
      | tier :: rest ->
          let body = M.render t tier els in
          if CCString.length body < M.max_comment_length then body else first_fit rest
    in
    first_fit (tiers els)

  let publish t body =
    let open Abbs_future_combinators.Infix_result_monad in
    let post_fresh () =
      M.post_comment t body >>= fun comment_id -> M.upsert_comment_id t comment_id
    in
    M.query_comment_id t
    >>= function
    | None -> post_fresh ()
    | Some comment_id -> (
        let (* The raw future is opened only here: a comment the caller recorded but that no longer
           exists is reposted, and [`Not_found] must not escape into the result type. *)
          open
          Abb.Future.Infix_monad
        in
        M.update_comment t comment_id body
        >>= function
        | Ok () -> Abbs_future_combinators.return_ok ()
        | Error `Not_found -> post_fresh ()
        | Error `Error -> Abbs_future_combinators.return_err `Error)

  let run t =
    let open Abbs_future_combinators.Infix_result_monad in
    M.query_els t
    >>= function
    | [] ->
        (* Nothing to say about the pull request (for example the window
           between a push and its run being created): leave the existing
           comment untouched rather than publishing an empty table. *)
        Abbs_future_combinators.return_ok ()
    | els ->
        let sorted = sort_els els in
        let body = fit t sorted in
        publish t body
end
