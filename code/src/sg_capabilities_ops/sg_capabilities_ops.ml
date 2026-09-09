(* A [states] map entry whose resource list is [null] ([None]) means "all resources" in that state,
   i.e. ["*"].  Shared by [mask] here and by [Sgs_session.Caps.satisfies].  It lives here rather than
   on [Sgs_session_caps_states] because that module is generated from session-capabilities.json. *)
let state_resources = CCOption.get_or ~default:[ "*" ]

let granted = function
  | Some true -> true
  | _ -> false

(* [mask ~mask input] restricts [input] by [mask]: a capability is granted in
   the result only if both [input] and [mask] grant it.  Note the same
   [None]-asymmetry as [Sgs_session.Caps.satisfies]: for booleans and object-valued capabilities
   [None] means "not granted" (so masking is a logical AND, and an object is
   [Some] only when both sides are [Some]); for list-valued capabilities [None]
   and a list containing ["*"] both mean "all", and masking is intersection,
   producing a concrete, deduped list ([all] masked by [all] stays "all"). *)
let mask ~mask input =
  let open Sgs_session_caps_capabilities in
  (* AND with [None] meaning not-granted.  An untouched field ([None] on both
     sides) stays [None] rather than collapsing to [Some false], so masking
     does not pollute capabilities neither side mentioned. *)
  let mask_bool i m =
    match (i, m) with
    | None, None -> None
    | _ -> Some (granted i && granted m)
  in
  let dedup = CCList.sort_uniq ~cmp:CCString.compare in
  (* The overlap of two prefix globs is the narrower one, or nothing if they are disjoint, so using
     [Sg_caps_match.subsumes] (rather than string equality) makes the positive intersection exact --
     e.g. [a.b] survives masking by [a.*]. *)
  let glob_inter pa pb =
    CCList.flat_map
      (fun a ->
        CCList.filter_map
          (fun b ->
            if Sg_caps_match.subsumes a b then Some b
            else if Sg_caps_match.subsumes b a then Some a
            else None)
          pb)
      pa
  in
  let is_all_opt = CCOption.map_or ~default:true Sg_caps_match.grants_all in
  (* Combine two concrete allow-lists so that the result allows a value iff both inputs do.
     Inputs are normalized first (so an all-negation list carries its implicit ["*"]).  When one
     side is ["*"]-plus-negations it allows everything except its negations, so the intersection is
     the other side's positives with both sides' negations unioned.  Otherwise the positives are
     intersected glob-aware via [glob_inter], making the result the exact intersection -- it never
     out-grants either parent, and no longer under-grants on differing globs. *)
  let combine a b =
    let split l = CCList.partition Sg_caps_match.is_negation (Sg_caps_match.normalize_list l) in
    let na, pa = split a in
    let nb, pb = split b in
    let has_star = CCList.exists (CCString.equal "*") in
    (* An empty positive list grants nothing -- the literal [[]] deny-all, which
       [normalize_list] leaves empty (unlike the negation-only forms, which gain an
       implicit ["*"]).  Intersecting "nothing" with anything is still "nothing".
       Without this guard the [has_star] branches below would drop the empty side
       and resurrect the *other* side's negations as an almost-everything grant
       (e.g. [combine [] ["!secret"]] = [["!secret"]]), over-granting past a
       deny-all parent. *)
    if CCList.is_empty pa || CCList.is_empty pb then [ "!*" ]
    else if has_star pa then dedup (pb @ na @ nb)
    else if has_star pb then dedup (pa @ na @ nb)
    else
      (* Disjoint positives intersect to nothing -- a deny-all.  We must NOT then fall through to
         [na @ nb], a negations-only list, which [matches] reads as "everything except those"
         (an over-grant of both parents).  Only carry the negations when a positive survives the
         intersection; otherwise the result is deny-all, exactly like the empty-positive guard. *)
      let pos = glob_inter pa pb in
      if CCList.is_empty pos then [ "!*" ] else dedup (pos @ na @ nb)
  in
  (* Non-optional [string list], where ["*"] (with no negation) means "all". *)
  let mask_str_list i m =
    if Sg_caps_match.grants_all i then dedup m
    else if Sg_caps_match.grants_all m then dedup i
    else combine i m
  in
  (* [string list option], where [None]/["*"] mean "all". *)
  let mask_list i m =
    match (is_all_opt i, is_all_opt m) with
    | true, true -> None
    | true, false -> CCOption.map dedup m
    | false, true -> CCOption.map dedup i
    | false, false -> (
        match (i, m) with
        | Some i, Some m -> Some (combine i m)
        | _ -> None)
  in
  let mask_opt f i m =
    match (i, m) with
    | Some i, Some m -> Some (f i m)
    | _ -> None
  in
  (* [states] is a restriction: a [state_id -> resource list] map where [None] means "all
     states/resources" and a [null] value means "all resources" in that state.  Masking keeps a
     state only when both sides grant it, using most-specific-wins ([Sg_caps_match.lookup]: exact
     key, else the ["*"] key).  Result keys are the explicit (non-["*"]) keys of either side, plus
     ["*"] only when both sides carry it; each kept resource list is masked via [mask_str_list]. *)
  let mask_states i m =
    let assoc s = Sln_map.String.to_list (Sgs_session_caps_states.additional s) in
    let star b = CCList.assoc_opt ~eq:CCString.equal "*" b in
    let mask_entry ri rm = Some (mask_str_list (state_resources ri) (state_resources rm)) in
    match (i, m) with
    | Some si, Some sm ->
        let bi = assoc si and bm = assoc sm in
        let keys =
          CCList.filter_map (fun (k, _) -> if CCString.equal k "*" then None else Some k) (bi @ bm)
          |> CCList.sort_uniq ~cmp:CCString.compare
        in
        let entry k =
          match (Sg_caps_match.lookup bi k, Sg_caps_match.lookup bm k) with
          | Some ri, Some rm -> Some (k, mask_entry ri rm)
          | _ -> None
        in
        let concrete = CCList.filter_map entry keys in
        let star_entry =
          match (star bi, star bm) with
          | Some ri, Some rm -> [ ("*", mask_entry ri rm) ]
          | _ -> []
        in
        let additional =
          CCList.fold_left
            (fun acc (k, v) -> Sln_map.String.add k v acc)
            Sln_map.String.empty
            (concrete @ star_entry)
        in
        Some (Sgs_session_caps_states.make ~additional Json_schema.Empty_obj.t)
    (* [None] = "all" is the identity for intersection, so fall back to whichever
       side is present ([None] when neither is). *)
    | _ -> CCOption.or_ ~else_:m i
  in
  let mask_commit i m =
    let open Sgs_session_caps_commit in
    {
      states = mask_states i.states m.states;
      subgraph = mask_states i.subgraph m.subgraph;
      tenants = mask_list i.tenants m.tenants;
    }
  in
  let mask_preview i m =
    let open Sgs_session_caps_preview in
    {
      states = mask_states i.states m.states;
      subgraph = mask_states i.subgraph m.subgraph;
      tenants = mask_list i.tenants m.tenants;
    }
  in
  let mask_sudo i m =
    {
      Sgs_session_caps_sudo.users =
        mask_str_list i.Sgs_session_caps_sudo.users m.Sgs_session_caps_sudo.users;
    }
  in
  let mask_users_manage i m =
    {
      Sgs_session_caps_users_manage.tenants =
        mask_list i.Sgs_session_caps_users_manage.tenants m.Sgs_session_caps_users_manage.tenants;
    }
  in
  let mask_admin i m =
    {
      Sgs_session_caps_admin.tenants =
        mask_list i.Sgs_session_caps_admin.tenants m.Sgs_session_caps_admin.tenants;
    }
  in
  {
    access_token_create = mask_bool input.access_token_create mask.access_token_create;
    access_token_refresh = mask_bool input.access_token_refresh mask.access_token_refresh;
    admin = mask_opt mask_admin input.admin mask.admin;
    commit = mask_opt mask_commit input.commit mask.commit;
    preview = mask_opt mask_preview input.preview mask.preview;
    sudo = mask_opt mask_sudo input.sudo mask.sudo;
    users_manage = mask_opt mask_users_manage input.users_manage mask.users_manage;
  }

(* [union a b] is the dual of [mask]: a capability is granted in the result if [a] OR [b] grants it.
   Where [mask] is the exact greatest lower bound, [union] is a sound *upper* bound (it grants at
   least everything each parent does): booleans are OR'd, an object is present when either side has
   it, and list scopes are set-unioned -- with [None] / ["*"] ("all") absorbing.  Negations are kept
   glob-aware (a side's negation survives only where the other side grants nothing it denies), so
   [union] is *exact* whenever the join is representable as a prefix-glob allow-list.  It can still
   over-grant in the irreducible cases where the join is a cone minus a sub-cone with a point
   re-granted inside -- a shape the flat allow-list cannot express (that would need a decision-tree
   capability form).  The result is re-normalized so its allow-lists are canonical.

   [union] is commutative and idempotent, and [make ()] is its identity, but it is NOT associative:
   because the irreducible over-grant above is order-dependent, [(a ∪ b) ∪ c] can differ from
   [a ∪ (b ∪ c)] once a negation meets a positive that partially refills its cone (see the
   [union_not_associative_negations] test).  It IS associative over negation-free operands, where it
   degenerates to exact set-union (see [prop_union_associative_positive]).  Callers that fold [union]
   (e.g. [Sgs_caps_rules.eval]) therefore get an order-dependent -- but always sound -- result. *)
let union a b =
  let open Sgs_session_caps_capabilities in
  (* OR with [None] meaning not-granted. An untouched field ([None] on both sides) stays [None]. *)
  let union_bool i m =
    match (i, m) with
    | None, None -> None
    | _ -> Some (granted i || granted m)
  in
  let dedup = CCList.sort_uniq ~cmp:CCString.compare in
  let is_all_opt = CCOption.map_or ~default:true Sg_caps_match.grants_all in
  (* Combine two concrete allow-lists so the result allows a value iff *either* input does.  Dual of
     [mask]'s [combine]: positives are unioned (concatenated -- exact, since matching a list of globs
     is the union of what each matches) and negations are kept glob-aware via [keep_negs].  A deny-all
     parent ([[]] empty positives) is the join identity, so the other side passes through verbatim; a
     ["*"] side contributes the universe.  Sound (never grants less than either parent), and exact
     except in the irreducible cone-minus-subcone-plus-point case (see [union]'s doc and the
     union_irreducible_over_grant test). *)
  let denies_all l = CCList.equal CCString.equal (Sg_caps_match.canonicalize_list l) [ "!*" ] in
  let combine a b =
    (* Deny-all ([[]] / ["!*"] / positives fully cancelled) is the join identity: [bottom ∪ x = x].
       Detect it up front via [canonicalize_list] (which folds every deny-all form to ["!*"]) BEFORE
       [split]'s [normalize_list] materializes the implicit ["*"] on an all-negation list -- that
       ["*"] would slip past the empty-positive branches below and over-grant (e.g. the deny-all
       ["!*"] unioned with ["a"] would wrongly become ["*"], all).  Keeping this an exact identity is
       what makes [union] associative: an intermediate deny-all can no longer taint a later union. *)
    if denies_all a then Sg_caps_match.canonicalize_list b
    else if denies_all b then Sg_caps_match.canonicalize_list a
    else
      let split l = CCList.partition Sg_caps_match.is_negation (Sg_caps_match.normalize_list l) in
      let na, pa = split a in
      let nb, pb = split b in
      let has_star = CCList.exists (CCString.equal "*") in
      let body n = CCOption.get_or ~default:n (CCString.chop_prefix ~pre:"!" n) in
      (* Keep a negation [!q] from one side only when it removes nothing the *other* side grants -- i.e.
       [q]'s cone is disjoint from every positive the other side carries, or the other side also denies
       it (one of its negations subsumes [q]).  Otherwise the other side positively refills (part of)
       the hole, so a global negation would wrongly deny that; drop it (the forced over-grant).  This
       is the glob-aware dual of [mask]'s [glob_inter]. *)
      let keep_negs ns ~others_pos ~others_neg =
        CCList.filter
          (fun n ->
            let q = body n in
            (not (CCList.exists (fun p -> Sg_caps_match.intersects q p) others_pos))
            || CCList.exists (fun m -> Sg_caps_match.subsumes (body m) q) others_neg)
          ns
      in
      let negs =
        keep_negs na ~others_pos:pb ~others_neg:nb @ keep_negs nb ~others_pos:pa ~others_neg:na
      in
      if CCList.is_empty pa then dedup (pb @ nb)
      else if CCList.is_empty pb then dedup (pa @ na)
      else if has_star pa || has_star pb then dedup ("*" :: negs)
      else dedup (pa @ pb @ negs)
  in
  (* Non-optional [string list], where ["*"] (with no negation) means "all". *)
  let union_str_list i m =
    if Sg_caps_match.grants_all i || Sg_caps_match.grants_all m then [ "*" ] else combine i m
  in
  (* [string list option], where [None]/["*"] mean "all".  [None] is the canonical "all": if two
     concrete lists happen to union to a grants-all result, collapse it to [None] so that "all" has a
     single representation.  Without this, one association order can yield [None] (via the [is_all_opt]
     branch) while another yields [Some ["*"]] (via [combine]) -- both "all", but not structurally
     equal, which would break [union] associativity. *)
  let union_list i m =
    match (is_all_opt i, is_all_opt m) with
    | true, true | true, false | false, true -> None
    | false, false -> (
        match (i, m) with
        | Some i, Some m ->
            let r = combine i m in
            if Sg_caps_match.grants_all r then None else Some r
        | _ -> None)
  in
  let union_opt f i m =
    match (i, m) with
    | Some i, Some m -> Some (f i m)
    | (Some _ as x), None | None, (Some _ as x) -> x
    | None, None -> None
  in
  (* Dual of [mask_states]: a state is granted when *either* side grants it (union the keys), and per
     state the resources are unioned (a side that does not resolve a key grants nothing there).
     [None] ("all states / all resources") absorbs in a union. *)
  let union_states i m =
    let assoc s = Sln_map.String.to_list (Sgs_session_caps_states.additional s) in
    let star b = CCList.assoc_opt ~eq:CCString.equal "*" b in
    let resources = CCOption.map_or ~default:[] state_resources in
    match (i, m) with
    | None, _ | _, None -> None
    | Some si, Some sm ->
        let bi = assoc si and bm = assoc sm in
        let keys =
          CCList.filter_map (fun (k, _) -> if CCString.equal k "*" then None else Some k) (bi @ bm)
          |> CCList.sort_uniq ~cmp:CCString.compare
        in
        let res b k = resources (Sg_caps_match.lookup b k) in
        let concrete =
          CCList.map (fun k -> (k, Some (union_str_list (res bi k) (res bm k)))) keys
        in
        let star_entry =
          match (star bi, star bm) with
          | None, None -> []
          | sbi, sbm -> [ ("*", Some (union_str_list (resources sbi) (resources sbm))) ]
        in
        let additional =
          CCList.fold_left
            (fun acc (k, v) -> Sln_map.String.add k v acc)
            Sln_map.String.empty
            (concrete @ star_entry)
        in
        Some (Sgs_session_caps_states.make ~additional Json_schema.Empty_obj.t)
  in
  let union_commit i m =
    Sgs_session_caps_commit.
      {
        states = union_states i.states m.states;
        subgraph = union_states i.subgraph m.subgraph;
        tenants = union_list i.tenants m.tenants;
      }
  in
  let union_preview i m =
    Sgs_session_caps_preview.
      {
        states = union_states i.states m.states;
        subgraph = union_states i.subgraph m.subgraph;
        tenants = union_list i.tenants m.tenants;
      }
  in
  let union_sudo i m = Sgs_session_caps_sudo.{ users = union_str_list i.users m.users } in
  let union_users_manage i m =
    Sgs_session_caps_users_manage.{ tenants = union_list i.tenants m.tenants }
  in
  let union_admin i m = Sgs_session_caps_admin.{ tenants = union_list i.tenants m.tenants } in
  Sgs_session_caps_norm.normalize
    {
      access_token_create = union_bool a.access_token_create b.access_token_create;
      access_token_refresh = union_bool a.access_token_refresh b.access_token_refresh;
      admin = union_opt union_admin a.admin b.admin;
      commit = union_opt union_commit a.commit b.commit;
      preview = union_opt union_preview a.preview b.preview;
      sudo = union_opt union_sudo a.sudo b.sudo;
      users_manage = union_opt union_users_manage a.users_manage b.users_manage;
    }

module Tenant_scope = struct
  type coverage =
    | Not_covered
    | Exact
    | Wider
  [@@deriving show, eq]

  (* [excludes ~negation ~value] is true when [negation] denies [value].  Asking [matches] with an
     explicit ["*"] positive isolates the negation: the list allows everything the negation does not,
     so a non-match means [negation] is what denied [value].  Going through [matches] rather than
     stripping the leading ['!'] here keeps the (admittedly obscure) ["!!x"] form -- a negation of the
     literal ["!x"] -- interpreted the same way evaluation interprets it. *)
  let excludes ~negation ~value = not (Sg_caps_match.matches [ "*"; negation ] value)

  let coverage ~list ~value =
    match list with
    | None -> Wider (* an absent list is the installation-wide grant *)
    | Some list ->
        if not (Sg_caps_match.matches list value) then Not_covered
        else
          let without = CCList.filter (fun pattern -> not (CCString.equal pattern value)) list in
          (* [Exact] means "removing the literal actually stops the match".  Deciding it by mere
             presence of the literal would classify ["T"; "*"] as [Exact], and revoking would then
             remove ["T"] while ["*"] kept granting -- a half-revoke reported as a success. *)
          if CCList.length without = CCList.length list then Wider
          else if Sg_caps_match.matches without value then Wider
          else Exact

  (* [canonicalize_list] collapses every deny-all shape to exactly ["!*"], so canonicalizing first
     makes this robust for any input rather than only for the output of {!revoke}. *)
  let grants_nothing = function
    | None -> false
    | Some list -> CCList.equal CCString.equal (Sg_caps_match.canonicalize_list list) [ "!*" ]

  let grant ~list ~value =
    match list with
    (* Already installation-wide.  Narrowing to a one-element allow-list here would turn granting
       one tenant into revoking every other one. *)
    | None -> Ok None
    (* Already permitted: canonicalize but otherwise leave it alone, so a list that permits [value]
       via an implicit or explicit ["*"] keeps permitting everything else too. *)
    | Some list when Sg_caps_match.matches list value ->
        Ok (Some (Sg_caps_match.canonicalize_list list))
    (* Permits nothing at all, so [value] alone is the whole grant.  Checked before the negation
       analysis below because a deny-all is exactly the shape whose negation (["!*"]) may not be
       dropped -- yet replacing the entire list cannot widen past [value]. *)
    | Some list when grants_nothing (Some list) -> Ok (Some [ value ])
    | Some list ->
        (* [value] is denied while other values are permitted, so some negation is responsible and
           has to go -- [canonicalize_list] alone would keep it and let the negation win, making the
           grant a silent no-op.

           Dropping a negation is only sound when its cone is exactly [value]: dropping ["!a*"] to
           permit ["ab"] would re-permit ["ac"] as well, granting authority nobody asked for.  A
           wider denial makes the result ("this cone, minus that sub-cone, but with this one value
           back") unrepresentable as a flat prefix-glob allow-list -- the same irreducibility
           {!union} documents -- so it is refused rather than approximated in either direction.

           [normalize_list] runs first because an all-negation list carries an implicit ["*"] that
           adding an explicit positive would destroy: ["!b"] permits everything except [b], yet
           [["b"; "!b"]] canonicalizes to just [["b"]] -- a silent narrowing. *)
        let list = Sg_caps_match.normalize_list list in
        let blocking, keep =
          CCList.partition
            (fun pattern -> Sg_caps_match.is_negation pattern && excludes ~negation:pattern ~value)
            list
        in
        if CCList.for_all (fun negation -> CCString.equal (CCString.drop 1 negation) value) blocking
        then Ok (Some (Sg_caps_match.canonicalize_list (value :: keep)))
        else Error `Unrepresentable_grant_err

  let revoke ~list ~value =
    match coverage ~list ~value with
    | Not_covered -> Ok list (* idempotent *)
    | Wider -> Error `Wider_grant_err
    | Exact ->
        let list = CCOption.get_or ~default:[] list in
        Ok
          (Some
             (Sg_caps_match.canonicalize_list
                (CCList.filter (fun pattern -> not (CCString.equal pattern value)) list)))
end

type tenant_grant =
  [ `Admin
  | `Users_manage
  ]

(* The capability names as they appear in session-capabilities.json, so log lines and error details
   match what an operator sees in the stored JSON. *)
let show_tenant_grant = function
  | `Admin -> "admin"
  | `Users_manage -> "users-manage"

let pp_tenant_grant fmt g = Format.pp_print_string fmt (show_tenant_grant g)

let tenant_scope caps = function
  | `Admin ->
      CCOption.map
        (fun a -> a.Sgs_session_caps_admin.tenants)
        caps.Sgs_session_caps_capabilities.admin
  | `Users_manage ->
      CCOption.map
        (fun u -> u.Sgs_session_caps_users_manage.tenants)
        caps.Sgs_session_caps_capabilities.users_manage

(** [tenants_opt] is [Some _] when granting rights, is [None] when removing rights. *)
let set_tenant_scope caps g tenants_opt =
  let open Sgs_session_caps_capabilities in
  let tenants = tenants_opt in
  match g with
  | `Admin -> { caps with admin = Some { Sgs_session_caps_admin.tenants } }
  | `Users_manage -> { caps with users_manage = Some { Sgs_session_caps_users_manage.tenants } }

let clear_tenant_grant caps g =
  let open Sgs_session_caps_capabilities in
  match g with
  | `Admin -> { caps with admin = None }
  | `Users_manage -> { caps with users_manage = None }

let is_instance_admin caps =
  match tenant_scope caps `Admin with
  | Some None -> true (* present, and no allow-list to narrow it: every tenant *)
  | Some (Some tenants) when Sg_caps_match.grants_all tenants ->
      (* [...; "*"; no_negation; ....] *) true
  | Some (Some _) | None -> false

let is_some_tenants_admin caps =
  match tenant_scope caps `Admin with
  (* Administers what the list names: it permits something, but not everything -- everything is
     [is_instance_admin]'s answer, and nothing at all leaves an [admin] key authorizing no tenant. *)
  | Some (Some tenants) ->
      (not (Sg_caps_match.grants_all tenants)) && not (Tenant_scope.grants_nothing (Some tenants))
  | Some None | None -> false

type instance_admin =
  [ `Instance_admin
  | `No_admin
  ]

let set_instance_admin admin caps =
  match admin with
  | `Instance_admin -> set_tenant_scope caps `Admin None
  | `No_admin -> clear_tenant_grant caps `Admin

let tenant_coverage caps g tenant =
  match tenant_scope caps g with
  | None -> Tenant_scope.Not_covered (* the capability itself is absent *)
  | Some tenants -> Tenant_scope.coverage ~list:tenants ~value:tenant

let grant_tenant ~grants ~tenant caps =
  let apply acc g =
    match acc with
    | Error _ as err -> err
    | Ok caps -> (
        match tenant_scope caps g with
        (* Capability absent: create it scoped to this tenant alone. *)
        | None -> Ok (set_tenant_scope caps g (Some [ tenant ]))
        | Some tenants -> (
            match Tenant_scope.grant ~list:tenants ~value:tenant with
            | Error `Unrepresentable_grant_err -> Error (`Unrepresentable_grant_err g)
            | Ok tenants -> Ok (set_tenant_scope caps g tenants)))
  in
  CCResult.map Sgs_session_caps_norm.normalize (CCList.fold_left apply (Ok caps) grants)

let revoke_tenant ~grants ~tenant caps =
  let apply acc g =
    match acc with
    | Error _ as err -> err
    | Ok caps -> (
        match tenant_scope caps g with
        | None -> Ok caps (* capability absent: nothing to revoke *)
        | Some tenants -> (
            match Tenant_scope.revoke ~list:tenants ~value:tenant with
            | Error `Wider_grant_err -> Error (`Wider_grant_err g)
            | Ok tenants when Tenant_scope.grants_nothing tenants ->
                (* The allow-list now permits nothing, so drop the capability rather than leaving
                   an empty one behind: every API that reports a user's role derives it from the
                   key's presence ([capabilities -> 'admin' is not null], e.g.
                   sql/select_users_list.sql), and a deny-all [admin] object would still read as
                   "admin". *)
                Ok (clear_tenant_grant caps g)
            | Ok tenants -> Ok (set_tenant_scope caps g tenants)))
  in
  CCResult.map Sgs_session_caps_norm.normalize (CCList.fold_left apply (Ok caps) grants)

type tenant_scope_err =
  | Instance_capability of string
  | Grants_beyond_tenant of string
[@@deriving show, eq]

let tenant_scope_err_to_string = function
  | Instance_capability c ->
      Printf.sprintf
        {|the %s capability is installation-wide and cannot be granted by a tenant-scoped rule|}
        c
  | Grants_beyond_tenant c ->
      Printf.sprintf
        {|the %s grant reaches beyond this tenant; a tenant rule may only grant capabilities scoped to this tenant|}
        c

(* [names_exactly_tenant] is true when [list] permits [tenant] and nothing else -- the sole shape a
   tenant-scoped grant may carry in a [tenants] allow-list.  [Exact] alone is not enough: ["T"; "U"]
   covers [T] exactly yet still grants [U], so we also require that removing [T] leaves a list that
   grants nothing (an absent list, a glob, or any other tenant all fail this). *)
let names_exactly_tenant ~tenant list =
  match Tenant_scope.coverage ~list ~value:tenant with
  | Tenant_scope.Exact -> (
      match Tenant_scope.revoke ~list ~value:tenant with
      | Ok remaining -> Tenant_scope.grants_nothing remaining
      | Error `Wider_grant_err -> false)
  | Tenant_scope.Not_covered | Tenant_scope.Wider -> false

(* The one place a [tenants] allow-list is judged against the single tenant a rule may grant to. *)
let confined_to_tenant ~tenant ~name tenants =
  if names_exactly_tenant ~tenant tenants then Ok () else Error (Grants_beyond_tenant name)

(* The state ids a [commit]/[preview] grant names across its [states] and [subgraph] maps. *)
let state_ids_of states subgraph =
  let ids = function
    | None -> []
    | Some s -> CCList.map fst (Sln_map.String.to_list (Sgs_session_caps_states.additional s))
  in
  ids states @ ids subgraph

(* First of all, return [Error Grants_beyond_tenant] if [tenants] is more than the single [tenant].

   If this is fine, return the state_ids whose membership must be in [tenant] for
   the combination [(states; subgraph; tenants)] to be bounded to [tenant]. *)
let state_ids_to_check ~tenant ~name ~states ~subgraph ~tenants =
  let ids = state_ids_of states subgraph in
  match tenants with
  (* No tenant scope, but explicit states: bounded once those states are confirmed to be [tenant]'s. *)
  | None when not (CCList.is_empty ids) -> Ok ids
  (* Otherwise the [tenants] list itself must name exactly [tenant] (this also rejects the fully
     unbounded case -- no tenant scope and no states). *)
  | None | Some _ -> CCResult.map (fun () -> ids) (confined_to_tenant ~tenant ~name tenants)

let scoped_to_tenant ~tenant caps =
  let open CCResult.Infix in
  let module Caps = Sgs_session_caps_capabilities in
  let check_absent name ~present = if present then Error (Instance_capability name) else Ok () in
  let check_tenant_only name = function
    | None -> Ok ()
    | Some tenants -> confined_to_tenant ~tenant ~name tenants
  in
  check_absent "access-token-create" ~present:Caps.(caps.access_token_create = Some true)
  >>= fun () ->
  check_absent "access-token-refresh" ~present:Caps.(caps.access_token_refresh = Some true)
  >>= fun () ->
  check_absent "sudo" ~present:Caps.(CCOption.is_some caps.sudo)
  >>= fun () ->
  check_tenant_only
    "admin"
    (CCOption.map (fun a -> a.Sgs_session_caps_admin.tenants) caps.Caps.admin)
  >>= fun () ->
  check_tenant_only
    "users-manage"
    (CCOption.map (fun u -> u.Sgs_session_caps_users_manage.tenants) caps.Caps.users_manage)
  >>= fun () ->
  (match caps.Caps.commit with
    | None -> Ok []
    | Some c ->
        state_ids_to_check
          ~tenant
          ~name:"commit"
          ~states:c.Sgs_session_caps_commit.states
          ~subgraph:c.Sgs_session_caps_commit.subgraph
          ~tenants:c.Sgs_session_caps_commit.tenants)
  >>= fun commit_ids ->
  (match caps.Caps.preview with
    | None -> Ok []
    | Some p ->
        state_ids_to_check
          ~tenant
          ~name:"preview"
          ~states:p.Sgs_session_caps_preview.states
          ~subgraph:p.Sgs_session_caps_preview.subgraph
          ~tenants:p.Sgs_session_caps_preview.tenants)
  >>= fun preview_ids -> Ok (commit_ids @ preview_ids)
