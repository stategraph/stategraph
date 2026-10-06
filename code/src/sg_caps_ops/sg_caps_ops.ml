module Scope = Sg_caps_trie_scope

let grant_scope caps = function
  | `Admin -> caps.Sg_caps.admin
  | `Users_manage -> caps.Sg_caps.users_manage

module Tenant_scope = struct
  type coverage =
    | Not_covered
    | Exact
    | Wider
  [@@deriving show, eq]

  let coverage scope tenant =
    if not (Scope.mem scope tenant) then Not_covered
    else
      match Scope.literals scope with
      | `Literals [ only ] when CCString.equal only tenant -> Exact
      | `Literals _ | `Infinite -> Wider
end

type tenant_grant =
  [ `Admin
  | `Users_manage
  ]
[@@deriving show, eq]

let tenant_coverage caps grant ~tenant = Tenant_scope.coverage (grant_scope caps grant) tenant
let grants_tenant caps grant ~tenant = Scope.mem (grant_scope caps grant) tenant
let is_instance_admin caps = Scope.is_full caps.Sg_caps.admin

let is_some_tenants_admin caps =
  (not (Scope.is_empty caps.Sg_caps.admin)) && not (Scope.is_full caps.Sg_caps.admin)

(* Whether [actor] holds at least as much authority over users as [target] does. One direction, and
   not strict: an actor covers its equals too, and [authority_over] is what asks both ways to reject
   them.

   Writing [A[t]] for a grant naming that tenant:

     admin[t1]         covers          users-manage[t1]
     users-manage[t1]  does not cover  admin[t1]

   So a tenant administrator outranks a users-manage holder confined to that tenant, while no amount
   of users-manage reaches an admin grant. *)
let covers_authority ~actor ~target =
  Scope.entails actor.Sg_caps.admin target.Sg_caps.admin
  && Scope.entails
       (Scope.union actor.Sg_caps.admin actor.Sg_caps.users_manage)
       target.Sg_caps.users_manage

type authority =
  | Dominates
  | Peer_or_greater
  | Tenant_out_of_scope of string
[@@deriving show, eq]

(* The tenants a user is reached in, by either grant: administering a tenant reaches its users, and
   so does managing them. *)
let users_reach caps = Scope.union caps.Sg_caps.admin caps.Sg_caps.users_manage

(* The one-tenant half of [users_reach] *)
let reaches_user_tenant ~actor ~tenant = Scope.mem (users_reach actor) tenant

(* A target in no tenant leaves no tenant unreached, so an empty [target_tenants] answers [None] for
   any actor, even one reaching no tenant at all. *)
let unreached_tenant ~actor ~target_tenants =
  let reach = users_reach actor in
  CCList.find_opt (fun t -> not (Scope.mem reach t)) target_tenants

let authority_over ~actor ~target ~target_tenants =
  match covers_authority ~actor ~target with
  | false -> Peer_or_greater
  | true when covers_authority ~actor:target ~target:actor -> Peer_or_greater
  | true -> (
      match unreached_tenant ~actor ~target_tenants with
      | Some tenant -> Tenant_out_of_scope tenant
      | None -> Dominates)

type tenant_scope_err =
  | Instance_capability of string
  | Grants_beyond_tenant of string
[@@deriving show, eq]

let tenant_scope_err_to_string = function
  | Instance_capability name ->
      Printf.sprintf
        "the %s capability is not scoped to a tenant, so a tenant rule cannot grant it"
        name
  | Grants_beyond_tenant name -> Printf.sprintf "the %s grant reaches beyond this tenant" name

(* The states a reach names outside one tenant, or [None] when it reaches anything out there that no
   state of its own names.

   A grant that names no tenant is still bounded to one when everything it reaches beyond that
   tenant sits on states it names, because the caller can then confirm those states belong to the
   tenant. A rule that answers for the states it does not name cannot be confirmed that way: its
   answer covers states of every other tenant. *)
let states_named_beyond ~within reach =
  let beyond = Sg_caps_reach.diff reach within in
  if Sg_caps_reach.is_empty beyond then Some []
  else
    let rules = CCList.flat_map snd (Sg_caps_reach.to_rules beyond) in
    let reaches_something (_, addresses) = not (Scope.is_empty addresses) in
    let names_a_family = function
      | Sg_caps_trie.Pattern.Prefix _, _ -> true
      | Sg_caps_trie.Pattern.Literal _, _ -> false
    in
    let reaching = CCList.filter reaches_something rules in
    if CCList.exists names_a_family reaching then None
    else
      match
        CCList.filter_map
          (function
            | Sg_caps_trie.Pattern.Literal state, _ -> Some state
            | Sg_caps_trie.Pattern.Prefix _, _ -> None)
          reaching
      with
      | [] -> None
      | states -> Some states

(* Whether a grant a tenant's administrator writes stays inside that tenant, and which states the
   caller must confirm belong to it for that answer to hold. The capabilities that are not about
   tenants at all cannot be granted this way, however narrow they look. *)
let scoped_to_tenant ~tenant caps =
  let open CCResult.Infix in
  let only_tenant = CCResult.get_or ~default:Scope.empty (Scope.of_strings [ tenant ]) in
  let check_absent name ~present = if present then Error (Instance_capability name) else Ok () in
  let check_tenant_only name scope =
    if Scope.entails only_tenant scope then Ok () else Error (Grants_beyond_tenant name)
  in
  let check_action name actions =
    let within = Sg_caps_reach.make ~tenants:only_tenant ~states:Scope.full ~addresses:Scope.full in
    let axis reach =
      match states_named_beyond ~within reach with
      | Some states -> Ok states
      | None -> Error (Grants_beyond_tenant name)
    in
    axis actions.Sg_caps.modified
    >>= fun modified -> axis actions.Sg_caps.pulled_in >|= fun pulled_in -> modified @ pulled_in
  in
  check_absent "access-token-create" ~present:caps.Sg_caps.access_token_create
  >>= fun () ->
  check_absent "access-token-refresh" ~present:caps.Sg_caps.access_token_refresh
  >>= fun () ->
  check_absent "sudo" ~present:(not (Scope.is_empty caps.Sg_caps.sudo))
  >>= fun () ->
  check_tenant_only "admin" caps.Sg_caps.admin
  >>= fun () ->
  check_tenant_only "users-manage" caps.Sg_caps.users_manage
  >>= fun () ->
  check_action "commit" caps.Sg_caps.commit
  >>= fun commit_states ->
  check_action "preview" caps.Sg_caps.preview
  >|= fun preview_states -> commit_states @ preview_states

type action =
  [ `Commit
  | `Preview
  ]
[@@deriving show, eq]

let actions caps = function
  | `Commit -> caps.Sg_caps.commit
  | `Preview -> caps.Sg_caps.preview

(* What a preview or commit grant reaches along one axis, with the [admin] grant read into it: an
   administrator of a tenant answers for the action there, whatever the action grant says. *)
let reach caps action axis =
  let actions = actions caps action in
  let reach =
    match axis with
    | `Modified -> actions.Sg_caps.modified
    | `Pulled_in -> actions.Sg_caps.pulled_in
  in
  Sg_caps_reach.union
    reach
    (Sg_caps_reach.make ~tenants:caps.Sg_caps.admin ~states:Scope.full ~addresses:Scope.full)

type states_denial =
  | State_not_granted
  | Resource_not_granted
[@@deriving show, eq]

(* Why one (state, address) pair of a transaction is refused, or [None] when it is not. A state that
   reaches no address at all is out of scope; one that reaches some but not this address refuses the
   resource. This is the reference the SQL check below is compared against. *)
let states_denial reach ~tenant ~state_id ~fq_address =
  let addresses = Sg_caps_reach.addresses reach ~tenant ~state:state_id in
  if Scope.mem addresses fq_address then None
  else if Scope.is_empty addresses then Some State_not_granted
  else Some Resource_not_granted

module Db_checks = struct
  type rule = {
    state : string;
    neg : bool;
    prefix : bool;
    pat : string;
  }
  [@@deriving show, eq]

  type caps = {
    governed : string list;
    rules : rule list;
  }
  [@@deriving show, eq]

  (* The rules of one scope, as the query takes them, with its catch-all spelled out.
     [Scope.to_rules] leaves the rule matching everything out when it refuses, because reading the
     rules back refuses what no rule names; the query has no such default -- an address that matches
     no rule joins nothing and is judged allowed -- so the refusal that every other rule is an
     exception to has to be written down here. *)
  let address_rules ~state addresses =
    let encoded =
      CCList.map
        (fun (p, allowed) ->
          match p with
          | Sg_caps_trie.Pattern.Prefix pat -> { state; neg = not allowed; prefix = true; pat }
          | Sg_caps_trie.Pattern.Literal pat -> { state; neg = not allowed; prefix = false; pat })
        (Scope.to_rules addresses)
    in
    match encoded with
    | { prefix = true; pat = ""; _ } :: _ -> encoded
    | _ :: _ | [] -> { state; neg = true; prefix = true; pat = "" } :: encoded

  (* The state rules of one tenant, as the columns of the refusal queries. A state rule is a state
     id, or ["*"] for the states no rule names; a rule that names a family of states has no
     counterpart in a query that resolves a state by equality, and is refused rather than widened.

     [governed] is the states that reach at least one address: it is what tells a refused resource
     from a state that is out of scope, which the two are indistinguishable in the rules alone. *)
  let encode reach ~tenant =
    let key = function
      | Sg_caps_trie.Pattern.Prefix "" -> Ok "*"
      | Sg_caps_trie.Pattern.Prefix prefix -> Error (`Unencodable_state_err (prefix ^ "*"))
      | Sg_caps_trie.Pattern.Literal state -> Ok state
    in
    let open CCResult.Infix in
    CCResult.map_l
      (fun (pattern, addresses) ->
        key pattern
        >|= fun state -> (state, Scope.is_empty addresses, address_rules ~state addresses))
      (Sg_caps_reach.state_rules reach ~tenant)
    >|= fun states ->
    {
      governed =
        CCList.filter_map (fun (state, empty, _) -> if empty then None else Some state) states;
      rules = CCList.flat_map (fun (_, _, rules) -> rules) states;
    }
end

(* Whether a tenant is reached at all, and whether everything of it is: the first says a refusal is
   about the tenant rather than its resources, the second that nothing of it can be refused. *)
let reaches_tenant reach ~tenant =
  CCList.exists
    (fun (_, addresses) -> not (Scope.is_empty addresses))
    (Sg_caps_reach.state_rules reach ~tenant)

let reaches_every_address reach ~tenant =
  CCList.for_all
    (fun (_, addresses) -> Scope.is_full addresses)
    (Sg_caps_reach.state_rules reach ~tenant)
