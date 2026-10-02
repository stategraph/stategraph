type cond =
  | Group of string
  | Any of cond list
  | All of cond list
[@@deriving show]

type rule = {
  id : Uuidm.t;
  tenant_id : Uuidm.t;
  created_at : string;
  created_by : Uuidm.t;
  description : string option;
  condition : cond;
  grant : Sg_caps.t;
}

type err = Pgsql_io.err [@@deriving show]

(* A [Group p] leaf holds iff some of the user's groups matches the prefix-glob [p]; the leaf reuses
   the capability matcher so group patterns share the one tested, ReDoS-safe glob syntax. *)
let rec matches cond ~groups =
  match cond with
  | Group p -> CCList.exists (fun g -> Sg_caps_match.matches ~patterns:[ p ] g) groups
  | Any cs -> CCList.exists (fun c -> matches c ~groups) cs
  | All cs -> CCList.for_all (fun c -> matches c ~groups) cs

(* Join the grants of every matching rule. The join is exact, commutative and associative, and
   [empty] is its neutral element, so this is beautifully simple. *)
let eval rules ~groups =
  CCList.fold_left
    (fun caps r -> if matches r.condition ~groups then Sg_caps.union caps r.grant else caps)
    Sg_caps.empty
    rules

(* Manually defined, so that the JSON is more intuitive. Admins may have to write it by hand. *)
let rec cond_to_yojson = function
  | Group p -> `Assoc [ ("group", `String p) ]
  | Any cs -> `Assoc [ ("any", `List (CCList.map cond_to_yojson cs)) ]
  | All cs -> `Assoc [ ("all", `List (CCList.map cond_to_yojson cs)) ]

(* Manually defined, so that the JSON is more intuitive. Admins may have to write it by hand. *)
let rec cond_of_yojson (json : Yojson.Safe.t) =
  (* Decode a homogeneous list of sub-conditions, short-circuiting on the first failure. *)
  let decode_list cs =
    CCList.fold_right
      (fun c acc ->
        match (acc, cond_of_yojson c) with
        | Ok cs, Ok c -> Ok (c :: cs)
        | (Error _ as e), _ | _, (Error _ as e) -> e)
      cs
      (Ok [])
  in
  match json with
  | `Assoc [ ("group", `String p) ] -> Ok (Group p)
  | `Assoc [ ("any", `List cs) ] -> CCResult.map (fun cs -> Any cs) (decode_list cs)
  | `Assoc [ ("all", `List cs) ] -> CCResult.map (fun cs -> All cs) (decode_list cs)
  | _ ->
      Error
        {|expected a single-operator-key condition object with one of these keys: "group", or "any", or "all"|}

let rec validate_cond = function
  | Group p ->
      if Sg_caps_match.is_valid_pattern p then Ok ()
      else Error (Printf.sprintf "invalid group pattern: %S" p)
  | Any cs | All cs ->
      CCList.fold_left
        (fun acc c ->
          match acc with
          | Ok () -> validate_cond c
          | Error _ as e -> e)
        (Ok ())
        cs

module Sql = struct
  (* The columns and their [Ret] order, shared by the global {!list_alive} (login recompute) and the
     per-tenant {!list_alive_by_tenant} (management list). *)
  let rule_returns f =
    Pgsql_io.Typed_sql.(
      f
      //
      (* id *)
      Ret.uuid
      //
      (* tenant_id *)
      Ret.uuid
      //
      (* created_at *)
      Ret.text
      //
      (* created_by *)
      Ret.uuid
      //
      (* description *)
      Ret.(option text)
      //
      (* condition *)
      Ret.(u json (fun json -> CCResult.to_opt (cond_of_yojson json)))
      //
      (* capability_trie *)
      Sgs_user.caps_ret)

  let list_alive () =
    Pgsql_io.Typed_sql.(rule_returns sql /^ [%blob "./sql/list_alive_caps_groups_rules.sql"])

  let list_alive_by_tenant () =
    Pgsql_io.Typed_sql.(
      rule_returns sql
      /^ [%blob "./sql/list_alive_caps_group_rules_by_tenant.sql"]
      /% Var.uuid "tenant_id")

  let get_alive_by_tenant () =
    Pgsql_io.Typed_sql.(
      rule_returns sql
      /^ [%blob "./sql/get_alive_caps_group_rule_by_tenant.sql"]
      /% Var.uuid "tenant_id"
      /% Var.uuid "id")

  let add () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ [%blob "./sql/add_groups_rules.sql"]
      /% Var.uuid "tenant_id"
      /% Var.uuid "created_by"
      /% Var.(option (text "description"))
      /% Var.json "condition"
      /% Var.json "capability_trie")

  let soft_delete () =
    Pgsql_io.Typed_sql.(
      sql
      // Ret.uuid
      /^ [%blob "./sql/soft_delete_groups_rules.sql"]
      /% Var.uuid "id"
      /% Var.uuid "tenant_id")
end

let mk_rule id tenant_id created_at created_by description condition grant =
  { id; tenant_id; created_at; created_by; description; condition; grant }

let list_alive db = Pgsql_io.Prepared_stmt.fetch db (Sql.list_alive ()) ~f:mk_rule

let list_alive_by_tenant ~tenant_id db =
  Pgsql_io.Prepared_stmt.fetch db (Sql.list_alive_by_tenant ()) ~f:mk_rule tenant_id

let get_alive_by_tenant ~tenant_id id db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.get_alive_by_tenant ()) ~f:mk_rule tenant_id id
  >>| CCList.head_opt

let add ~tenant_id ~created_by ~description ~condition ~grant db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    (Sql.add ())
    ~f:CCFun.id
    tenant_id
    created_by
    description
    (cond_to_yojson condition)
    (Sg_caps_json.to_json grant)
  >>= function
  | id :: _ -> Abb.Future.return (Ok id)
  | [] -> assert false

let soft_delete ~tenant_id id db =
  let open Abbs_fc.Infix_result_monad in
  Pgsql_io.Prepared_stmt.fetch db (Sql.soft_delete ()) ~f:CCFun.id id tenant_id
  >>| fun deleted -> not (CCList.is_empty deleted)
