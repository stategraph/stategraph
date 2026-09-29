let src = Logs.Src.create "eplib"

module Logs_lib = Logs
module Logs = (val Logs.src_log src : Logs.LOG)

let error_response_body ~id ~data =
  let module Err = Sgs_api_components_error_response in
  Yojson.Safe.to_string (Err.to_yojson { Err.id; data = Some data })

let respond_error ~status ~id ~data ctx =
  Brtl_ctx.set_response (Brtl_rspnc.create ~status (error_response_body ~id ~data)) ctx

(* A 500 defaults to an empty body: there is usually nothing the caller can act on, and whatever
   went wrong belongs in the logs rather than the response. [body] is for the endpoints that do have
   something to say -- pass {!error_response_body} to send the [error-response] the API conventions
   describe. Shared so the shape stays identical everywhere rather than being spelled out at each
   arm that reports an internal fault. *)
let respond_internal_error ?(body = "") ctx =
  Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error body) ctx

(* The half every access responder ([respond_tenant_access_err], and those of [Sgs_common]) shares.  Split out so an endpoint that checks more than one
   kind of access can name each refusal by its own constructor and answer the database faults once,
   instead of matching two [*_access_err] unions whose Pgsql halves overlap. *)
let log_db_err ?(src = src) ctx = function
  | #Pgsql_io.err as err ->
      Logs_lib.err ~src (fun m -> m "%s : DB_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err)
  | #Pgsql_pool.err as err ->
      Logs_lib.err ~src (fun m -> m "%s : DB_ERROR : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err)

let respond_db_err ?src ?body ctx err =
  log_db_err ?src ctx err;
  respond_internal_error ?body ctx

(* Every endpoint that mints a session fails the same two ways when the signing material cannot be
   read, and has nothing of its own to say about either.  Shared so the status, the id and the log
   line stay identical at every one of them rather than drifting apart.  [body] carries the
   endpoint's own wording, as it does for [respond_db_err].

   The two constructors are logged apart because they are different operator problems: an
   [encryption_keys] with no [rsa] row against a row that is not a usable RSA private key. *)
let log_signing_key_err ctx = function
  | `Key_not_found_err ->
      Logs.err (fun m -> m "%s : DB_ERROR : No session signing key found" (Brtl_ctx.token ctx))
  | `Bad_signing_key_err msg ->
      Logs.err (fun m -> m "%s : DB_ERROR : Bad session signing key : %s" (Brtl_ctx.token ctx) msg)

let respond_signing_key_err ?body ctx err =
  log_signing_key_err ctx err;
  respond_internal_error ?body ctx

type tenant_access_err =
  [ Sgs_tenant.enforce_user_err
  | Pgsql_pool.err
  ]

let log_tenant_access_denied ctx (`User_not_in_tenant_err ids) =
  Logs.warn (fun m ->
      m
        "%s : ACCESS_DENIED : %a"
        (Brtl_ctx.token ctx)
        Sgs_tenant.pp_enforce_user_err
        (`User_not_in_tenant_err ids : Sgs_tenant.enforce_user_err))

(* A caller who is not a member of the tenant is 403 [TENANT_MEMBERSHIP_REQUIRED], never the bare 401
   a missing session produces: the console retries a 401 and then bounces to sign-in, which is the
   wrong story to tell someone whose session is fine.

   [Sgs_tenant.enforce_user_err] subsumes [Pgsql_io.err], and subsuming it is what had a deadlock or
   a statement timeout answered as a denial.  Naming the refusal by its own constructor keeps the
   three arms disjoint, so nothing here depends on their order. *)
let respond_tenant_access_err ctx = function
  | (#Pgsql_io.err | #Pgsql_pool.err) as err -> respond_db_err ~src ctx err
  | `User_not_in_tenant_err _ as err ->
      log_tenant_access_denied ctx err;
      Brtl_ctx.set_response
        (Brtl_rspnc.create
           ~status:`Forbidden
           (error_response_body
              ~id:"TENANT_MEMBERSHIP_REQUIRED"
              ~data:"You are not a member of this tenant"))
        ctx

(* The page cursor every keyset-paged listing hands out.  See the interface for what it carries and
   why both halves are needed. *)
module Cursor = struct
  let sep = '|'
  let encode ~timestamp ~id = timestamp ^ CCString.of_char sep ^ Uuidm.to_string id

  let decode c =
    match CCString.Split.left ~by:(CCString.of_char sep) c with
    | Some (timestamp, id) -> CCOption.map (fun id -> (timestamp, id)) (Uuidm.of_string id)
    | None -> None
end
