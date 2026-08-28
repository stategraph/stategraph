let src = Logs.Src.create "terrat_ep_tenv"

module Logs = (val Logs.src_log src : Logs.LOG)
module Abb_io_file = Abb_io_file.Make (Abb)

module Metrics = struct
  let namespace = "terrat"
  let subsystem = "ep_tenv"

  let cache_fn_call_count =
    let help = "Count of cache calls by function with hit or miss or evict" in
    let family =
      Prmths.Counter.v_labels
        ~label_names:[ "lifetime"; "fn"; "type" ]
        ~help
        ~namespace
        ~subsystem
        "cache_fn_call_count"
    in
    fun ~l ~fn t -> Prmths.Counter.labels family [ l; fn; t ]
end

module Http = Abb_curl.Make (Abb)
module Cache = Abb_cache.Make (Abb)

module Sql = struct
  let validate_work_manifest =
    Pgsql_io.Typed_sql.(
      sql
      //
      (* id *)
      Ret.uuid
      /^ "select id from work_manifests where id = $id and state = 'running'"
      /% Var.uuid "id")
end

module V = struct
  type t = {
    headers : (string * string) list;
    body_path : string;
  }
  [@@deriving yojson]
end

module Tenv_cache = Cache.Filesystem.Make (struct
  type k = string [@@deriving eq]
  type v = V.t

  type err =
    [ Http.request_err
    | Abb_intf.Errors.write
    | Abb_intf.Errors.rename
    | Abb_io_file.with_file_err
    ]

  type args = unit -> (v, err) result Abb.Future.t

  let fetch f = f ()
  let weight = CCFun.(V.to_yojson %> Yojson.Safe.to_string %> CCString.length)
end)

let on_hit fn () = Prmths.Counter.inc_one (Metrics.cache_fn_call_count ~l:"global" ~fn "hit")
let on_miss fn () = Prmths.Counter.inc_one (Metrics.cache_fn_call_count ~l:"global" ~fn "miss")
let on_evict fn () = Prmths.Counter.inc_one (Metrics.cache_fn_call_count ~l:"global" ~fn "evict")

let cache_path =
  Filename.concat (CCOption.get_or ~default:"/tmp" @@ Sys.getenv_opt "TERRAT_CACHE_DIR") "tenv"

let tenv_cache =
  Tenv_cache.create
    {
      Cache.Filesystem.on_hit = on_hit "tenv";
      on_miss = on_miss "tenv";
      on_evict = on_evict "tenv";
      path = cache_path;
      to_string = CCFun.(V.to_yojson %> Yojson.Safe.pretty_to_string);
      of_string =
        CCFun.(
          CCOption.wrap Yojson.Safe.from_string
          %> CCOption.flat_map (V.of_yojson %> CCOption.of_result)
          %> CCOption.flat_map (fun ({ V.body_path; _ } as v) ->
              (* Ensure that the path the body is actually written to exists,
                    otherwise we could get into a scenario where the body is
                    gone and we keep on returning a non-existent path *)
              if not (Sys.file_exists body_path) then None else Some v));
    }

let get _config storage _origin work_manifest_id path ctx =
  let open Abb.Future.Infix_monad in
  Pgsql_pool.with_conn storage ~f:(fun db ->
      Pgsql_io.Prepared_stmt.fetch db Sql.validate_work_manifest ~f:CCFun.id work_manifest_id)
  >>= function
  | Ok [] -> Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Forbidden "") ctx)
  | Ok (_ :: _) -> (
      let fetch () =
        let open Abbs_future_combinators.Infix_result_monad in
        let url = Uri.with_path (Uri.of_string "https://github.com") path in
        Http.get url
        >>= function
        | resp, body when Http.(Status.is_success @@ Response.status resp) ->
            let headers = Http.Response.headers resp in
            let headers_of_interest =
              CCList.filter_map
                (fun h -> CCOption.map (fun v -> (h, v)) @@ Http.Headers.get h headers)
                [ "content-length"; "content-type" ]
            in
            let body_path = Filename.concat cache_path @@ Digest.to_hex @@ Digest.string body in
            Abb_io_file.write_file ~fname:(body_path ^ ".tmp") body
            >>= fun () ->
            Abb.File.rename ~src:(body_path ^ ".tmp") ~dst:body_path
            >>| fun () -> { V.body_path; headers = headers_of_interest }
        | resp, _ ->
            Abbs_future_combinators.return_err
              (`Curl_err
                 (Printf.sprintf
                    "Bad response: %s"
                    (Http.Status.to_string @@ Http.Response.status resp)))
      in
      Tenv_cache.fetch tenv_cache path fetch
      >>= function
      | Ok v ->
          let headers = Cohttp.Header.of_list v.V.headers in
          let body writer =
            let open Abb.Future.Infix_monad in
            Abb_io_file.with_file_in v.V.body_path ~f:(fun fin ->
                let buf = Bytes.create 4096 in
                let rec loop () =
                  Abb.File.read fin ~buf ~pos:0 ~len:(Bytes.length buf)
                  >>= function
                  | Ok 0 -> Abbs_future_combinators.return_ok ()
                  | Ok n ->
                      Brtl_rspnc.Http.Response_io.write_body writer (Bytes.sub_string buf 0 n)
                      >>= fun () -> loop ()
                  | Error _ ->
                      Logs.err (fun m -> m "%s : GET : STREAM_ERROR" (Brtl_ctx.token ctx));
                      Abbs_future_combinators.return_ok ()
                in
                loop ())
            >>= fun _ -> Abb.Future.return ()
          in
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create_stream ~headers ~status:`OK body) ctx)
      | Error (`Cache_err (#Cache.Filesystem.cache_err as err)) ->
          Logs.err (fun m ->
              m "%s : GET : %a" (Brtl_ctx.token ctx) Cache.Filesystem.pp_cache_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (`Fetch_err (#Http.request_err as err)) ->
          Logs.err (fun m -> m "%s : GET : %a" (Brtl_ctx.token ctx) Http.pp_request_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (`Fetch_err (#Abb_intf.Errors.write as err)) ->
          Logs.err (fun m -> m "%s : GET : %a" (Brtl_ctx.token ctx) Abb_intf.Errors.pp_write err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (`Fetch_err (#Abb_intf.Errors.rename as err)) ->
          Logs.err (fun m -> m "%s : GET : %a" (Brtl_ctx.token ctx) Abb_intf.Errors.pp_rename err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
      | Error (`Fetch_err (#Abb_io_file.with_file_err as err)) ->
          Logs.err (fun m ->
              m "%s : GET : %a" (Brtl_ctx.token ctx) Abb_io_file.pp_with_file_err err);
          Abb.Future.return
            (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx))
  | Error (#Pgsql_pool.err as err) ->
      Logs.err (fun m -> m "%s : GET : %a" (Brtl_ctx.token ctx) Pgsql_pool.pp_err err);
      Abb.Future.return
        (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
  | Error (#Pgsql_io.err as err) ->
      Logs.err (fun m -> m "%s : GET : %a" (Brtl_ctx.token ctx) Pgsql_io.pp_err err);
      Abb.Future.return
        (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`Internal_server_error "") ctx)
