module Level = struct
  type t =
    | Info
    | Warning
    | Critical
  [@@deriving eq, show]

  let of_string = function
    | "info" -> Some Info
    | "warning" -> Some Warning
    | "critical" -> Some Critical
    | _ -> None

  let alert = function
    | Info -> "NOTE"
    | Warning -> "WARNING"
    | Critical -> "CAUTION"
end

type t = {
  level : Level.t;
  message : string;
}
[@@deriving eq, show]

let lines message =
  message
  |> CCString.replace ~sub:"\r\n" ~by:"\n"
  |> CCString.rdrop_while (Char.equal '\n')
  |> CCString.split_on_char '\n'

let to_kv broadcasts =
  `List
    (CCList.map
       (fun { level; message } ->
         `Assoc
           [
             ("alert", `String (Level.alert level));
             ("lines", `List (CCList.map (fun line -> `String line) (lines message)));
           ])
       broadcasts)

module Sql = struct
  let select_active_broadcasts_sql = Mql_sql.read [%blob "sql/select_active_broadcasts.sql"]

  let select_active_broadcasts =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* level *)
      Ret.text
      //
      (* message *)
      Ret.text
      /^ select_active_broadcasts_sql
      /% Var.text "vcs")
end

let string_of_vcs = function
  | `Github -> "github"
  | `Gitlab -> "gitlab"

let of_row ~request_id (level, message) =
  match Level.of_string level with
  | Some level -> Some { level; message }
  | None ->
      Logs.warn (fun m -> m "%s : BROADCAST : UNKNOWN_LEVEL : %s" request_id level);
      None

let active ~request_id ~vcs db =
  let open Abb.Future.Infix_monad in
  Pgsql_io.Prepared_stmt.fetch
    db
    Sql.select_active_broadcasts
    ~f:(fun level message -> (level, message))
    (string_of_vcs vcs)
  >>= function
  | Ok rows -> Abb.Future.return (Ok (CCList.filter_map (of_row ~request_id) rows))
  | Error (#Pgsql_io.err as err) ->
      Logs.err (fun m -> m "%s : BROADCAST : FETCH : %a" request_id Pgsql_io.pp_err err);
      Abb.Future.return (Error `Error)
