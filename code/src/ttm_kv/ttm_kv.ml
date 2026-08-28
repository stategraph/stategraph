let src = Logs.Src.create "kv"

module Logs = (val Logs.src_log src : Logs.LOG)

let file_chunk_size = 1024 * 100
let chunk_slots = 10
let default_api_base = "https://app.terrateam.io"

module Cli = struct
  module C = Cmdliner

  let cap_conv =
    C.Arg.Conv.make
      ~docv:"CAP"
      ~parser:(fun s ->
        (* If the string starts with a mustache then assume it's a JSON object
           literal, otherwise wrap it in quotes because it's a string. *)
        let s =
          if not (CCString.starts_with ~prefix:"{" (CCString.trim s)) then "\"" ^ s ^ "\"" else s
        in
        try
          let json = Yojson.Safe.from_string s in
          match Terrat_user_caps.of_yojson json with
          | Ok cap -> Ok cap
          | Error s -> Error s
        with Yojson.Json_error s -> Error s)
      ~pp:Terrat_user_caps.pp
      ()

  let draft =
    let doc = "Data is uncommitted (default false)" in
    C.Arg.(value & flag & info [ "draft"; "d" ] ~doc)

  let exclusive =
    let doc = "Exclude the first matching key in results (default false, or inclusive)" in
    C.Arg.(value & flag & info [ "exclusive" ] ~doc)

  let idx =
    let doc = "Index to operate on (default 0)" in
    C.Arg.(value & opt (some int) None & info [ "idx" ] ~doc)

  let version =
    let doc = "Version of the record" in
    C.Arg.(value & opt (some int) None & info [ "version" ] ~doc)

  let select =
    let doc = "Select part of data.  Empty string means 'nothing'" in
    C.Arg.(value & opt_all string [] & info [ "select"; "s" ] ~doc)

  let read_caps =
    let doc = "List of capabilities required to read the row (can be specified multiple times)" in
    C.Arg.(value & opt_all cap_conv [] & info [ "read-cap" ] ~doc)

  let write_caps =
    let doc = "List of capabilities required to update the row (can be specified multiple times)" in
    C.Arg.(value & opt_all cap_conv [] & info [ "write-cap" ] ~doc)

  let prefix =
    let doc = "Require key starts with prefix" in
    C.Arg.(value & flag & info [ "p"; "prefix" ] ~doc)

  let output =
    let doc = "Output format of row.  Options are data and JSON" in
    C.Arg.(
      value
      & opt (enum [ ("data", `Data); ("record", `Record) ]) `Data
      & info [ "output"; "o" ] ~doc)

  let limit =
    let doc = "Limit number of results" in
    C.Arg.(value & opt (some int) None & info [ "limit" ] ~doc)

  let key =
    let doc = "The key" in
    C.Arg.(required & pos 0 (some string) None & info [] ~doc ~docv:"KEY")

  let keys =
    let doc =
      "List of keys.  The format is of 'idx:key' if a specific index of a key should be \
       committed.  And ':key' or 'key' if all of the entries of the key should be committed."
    in
    C.Arg.(value & pos_all string [] & info [] ~doc ~docv:"KEYS")

  let api_base =
    let doc = "API base for KV calls" in
    C.Arg.(required & opt (some string) (Some default_api_base) & info [ "api-base" ] ~doc)

  let vcs =
    let doc = "VCS name (github, gitlab)" in
    C.Arg.(
      required
      & opt (some (enum [ ("github", "github"); ("gitlab", "gitlab") ])) None
      & info [ "vcs" ] ~doc)

  let installation_id =
    let doc = "ID of installation" in
    C.Arg.(required & opt (some string) None & info [ "i"; "installation-id" ] ~doc)

  let src =
    let doc =
      "A path on the file system or KV-store.  Paths on the file system are just the path, paths \
       to the KV store must start be of the form 'kv://<key>'"
    in
    C.Arg.(required & pos 0 (some string) None & info [] ~doc ~docv:"SRC")

  let dst =
    let doc =
      "A path on the file system or KV-store.  Paths on the file system are just the path, paths \
       to the KV store must start be of the form 'kv://<key>'"
    in
    C.Arg.(required & pos ~rev:true 0 (some string) None & info [] ~doc ~docv:"DST")
end

let wrap_opt_list = function
  | [] -> None
  | xs -> Some xs

let run f =
  match Abb.Scheduler.run_with_state f with
  | `Det (Ok n) -> exit n
  | `Det (Error _) -> exit 1
  | `Aborted ->
      Logs.err (fun m -> m "Aborted");
      exit 1
  | `Exn (exn, bt_opt) ->
      Logs.err (fun m -> m "%s" (Printexc.to_string exn));
      CCOption.iter
        (fun bt -> Logs.err (fun m -> m "%s" (Printexc.raw_backtrace_to_string bt)))
        bt_opt;
      exit 1

let output_result succ fut =
  let open Abb.Future.Infix_monad in
  fut
  >>| function
  | Ok r -> succ r
  | Error (#Ttm_kv_store.err as err) ->
      Logs.err (fun m -> m "%a" Ttm_kv_store.pp_err err);
      Ok 1

module Get = struct
  let run api_base vcs installation draft idx select output key () =
    let f () =
      let open Abbs_future_combinators.Infix_result_monad in
      Ttm_client.create ~base_url:(Uri.of_string api_base) ()
      >>= fun client ->
      let store = Ttm_kv_store.create ~vcs ~installation client in
      let select =
        match select with
        | [] -> None
        | paths -> Some paths
      in
      output_result
        (function
          | Some r when output = `Data ->
              print_endline @@ Yojson.Safe.pretty_to_string @@ Ttm_kv_store.Record.data r;
              Ok 0
          | Some r ->
              print_endline @@ Yojson.Safe.pretty_to_string @@ Ttm_kv_store.data_record_to_yojson r;
              Ok 0
          | None -> Ok 1)
        (Ttm_kv_store.get ?select ?idx ~committed:(not draft) ~key store)
    in
    run f

  let cmd logs =
    let module C = Cmdliner in
    let doc = "Get a value" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "get" ~doc ~exits)
      C.Term.(
        const run
        $ Cli.api_base
        $ Cli.vcs
        $ Cli.installation_id
        $ Cli.draft
        $ Cli.idx
        $ Cli.select
        $ Cli.output
        $ Cli.key
        $ logs)
end

module Set = struct
  let run api_base vcs installation read_caps write_caps draft idx output key () =
    let f () =
      let open Abbs_future_combinators.Infix_result_monad in
      let read_caps = wrap_opt_list read_caps in
      let write_caps = wrap_opt_list write_caps in
      try
        Abbs_io_file.read_all ~buf_size:4096 Abb.File.stdin
        >>= fun data ->
        let data = Yojson.Safe.from_string data in
        Ttm_client.create ~base_url:(Uri.of_string api_base) ()
        >>= fun client ->
        let store = Ttm_kv_store.create ~vcs ~installation client in
        output_result
          (function
            | r when output = `Data ->
                print_endline @@ Yojson.Safe.pretty_to_string @@ Ttm_kv_store.Record.data r;
                Ok 0
            | r ->
                print_endline
                @@ Yojson.Safe.pretty_to_string
                @@ Ttm_kv_store.data_record_to_yojson r;
                Ok 0)
          (Ttm_kv_store.set ?read_caps ?write_caps ?idx ~committed:(not draft) ~key data store)
      with Yojson.Json_error err ->
        Printf.eprintf "Error parsing data: %s\n" err;
        Abbs_future_combinators.return_ok 1
    in
    run f

  let cmd logs =
    let module C = Cmdliner in
    let doc = "Set a value" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "set" ~doc ~exits)
      C.Term.(
        const run
        $ Cli.api_base
        $ Cli.vcs
        $ Cli.installation_id
        $ Cli.read_caps
        $ Cli.write_caps
        $ Cli.draft
        $ Cli.idx
        $ Cli.output
        $ Cli.key
        $ logs)
end

module Cas = struct
  let run api_base vcs installation read_caps write_caps draft idx output version key () =
    let f () =
      let open Abbs_future_combinators.Infix_result_monad in
      let read_caps = wrap_opt_list read_caps in
      let write_caps = wrap_opt_list write_caps in
      try
        Abbs_io_file.read_all ~buf_size:4096 Abb.File.stdin
        >>= fun data ->
        let data = Yojson.Safe.from_string data in
        Ttm_client.create ~base_url:(Uri.of_string api_base) ()
        >>= fun client ->
        let store = Ttm_kv_store.create ~vcs ~installation client in
        output_result
          (function
            | Some r when output = `Data ->
                print_endline @@ Yojson.Safe.pretty_to_string @@ Ttm_kv_store.Record.data r;
                Ok 0
            | Some r ->
                print_endline
                @@ Yojson.Safe.pretty_to_string
                @@ Ttm_kv_store.data_record_to_yojson r;
                Ok 0
            | None -> Ok 1)
          (Ttm_kv_store.cas
             ?read_caps
             ?write_caps
             ?idx
             ~committed:(not draft)
             ?version
             ~key
             data
             store)
      with Yojson.Json_error err ->
        Printf.eprintf "Error parsing data: %s\n" err;
        Abbs_future_combinators.return_ok 1
    in
    run f

  let cmd logs =
    let module C = Cmdliner in
    let doc = "Set a value conditionally" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "cas" ~doc ~exits)
      C.Term.(
        const run
        $ Cli.api_base
        $ Cli.vcs
        $ Cli.installation_id
        $ Cli.read_caps
        $ Cli.write_caps
        $ Cli.draft
        $ Cli.idx
        $ Cli.output
        $ Cli.version
        $ Cli.key
        $ logs)
end

module Iter = struct
  let run api_base vcs installation draft idx prefix exclusive select limit output key () =
    let f () =
      let open Abbs_future_combinators.Infix_result_monad in
      Ttm_client.create ~base_url:(Uri.of_string api_base) ()
      >>= fun client ->
      let store = Ttm_kv_store.create ~vcs ~installation client in
      let select =
        match select with
        | [] -> None
        | paths -> Some paths
      in
      output_result
        (function
          | rs when output = `Data ->
              print_endline
              @@ Yojson.Safe.pretty_to_string
              @@ `List (CCList.map Ttm_kv_store.Record.data rs);
              Ok 0
          | rs ->
              print_endline
              @@ Yojson.Safe.pretty_to_string
              @@ `List (CCList.map Ttm_kv_store.data_record_to_yojson rs);
              Ok 0)
        (Ttm_kv_store.iter
           ?select
           ?idx
           ~inclusive:(not exclusive)
           ~prefix
           ?limit
           ~committed:(not draft)
           ~key
           store)
    in
    run f

  let cmd logs =
    let module C = Cmdliner in
    let doc = "Iterate keys" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "iter" ~doc ~exits)
      C.Term.(
        const run
        $ Cli.api_base
        $ Cli.vcs
        $ Cli.installation_id
        $ Cli.draft
        $ Cli.idx
        $ Cli.prefix
        $ Cli.exclusive
        $ Cli.select
        $ Cli.limit
        $ Cli.output
        $ Cli.key
        $ logs)
end

module Commit = struct
  let run api_base vcs installation keys () =
    let f () =
      let open Abbs_future_combinators.Infix_result_monad in
      Ttm_client.create ~base_url:(Uri.of_string api_base) ()
      >>= fun client ->
      let store = Ttm_kv_store.create ~vcs ~installation client in
      let keys =
        CCList.map
          (fun k ->
            match CCString.Split.left ~by:":" k with
            | Some ("", k) -> (k, None)
            | Some (idx, k) -> (k, CCInt.of_string idx)
            | None -> (k, None))
          keys
      in
      output_result
        (fun rs ->
          print_endline
          @@ Yojson.Safe.pretty_to_string
          @@ `List
               (CCList.map (fun (k, idx) -> `Assoc [ ("key", `String k); ("idx", `Int idx) ]) rs);
          Ok 0)
        (Ttm_kv_store.commit ~keys store)
    in
    run f

  let cmd logs =
    let module C = Cmdliner in
    let doc = "Commit keys" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "commit" ~doc ~exits)
      C.Term.(const run $ Cli.api_base $ Cli.vcs $ Cli.installation_id $ Cli.keys $ logs)
end

module Delete = struct
  let run api_base vcs installation version idx _output key () =
    let f () =
      let open Abbs_future_combinators.Infix_result_monad in
      Ttm_client.create ~base_url:(Uri.of_string api_base) ()
      >>= fun client ->
      let store = Ttm_kv_store.create ~vcs ~installation client in
      output_result
        (function
          | true -> Ok 0
          | false -> Ok 1)
        (Ttm_kv_store.delete ?idx ?version ~key store)
    in
    run f

  let cmd logs =
    let module C = Cmdliner in
    let doc = "Delete a key" in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "delete" ~doc ~exits)
      C.Term.(
        const run
        $ Cli.api_base
        $ Cli.vcs
        $ Cli.installation_id
        $ Cli.version
        $ Cli.idx
        $ Cli.output
        $ Cli.key
        $ logs)
end

module Cp = struct
  exception Invalid_path_combination_exn

  module Payload = struct
    type t = {
      chk : string;
      data : string;
    }
    [@@deriving yojson { strict = false }]
  end

  let validate_path path =
    if CCString.starts_with ~prefix:"kv://" path then
      `Kv (CCString.drop (CCString.length "kv://") path)
    else `Path path

  let validate_src_dst src dst =
    match (validate_path src, validate_path dst) with
    | `Path _, `Path _ | `Kv _, `Kv _ -> raise Invalid_path_combination_exn
    | `Kv src, `Path dst -> `Download (src, dst)
    | `Path src, `Kv dst -> `Upload (src, dst)

  let run_download store draft src dst =
    let download_chunk store idx =
      let open Abb.Future.Infix_monad in
      Logs.debug (fun m -> m "Downloading: idx=%d" idx);
      Ttm_kv_store.get ~idx ~committed:(not draft) ~key:src store
      >>= function
      | Ok r -> Abbs_future_combinators.return_ok (idx, r)
      | Error (#Ttm_kv_store.err as err) -> Abbs_future_combinators.return_err (idx, err)
    in
    let process_chunk fout chunk =
      let open Abb.Future.Infix_monad in
      chunk
      >>= function
      | Ok (_, None) -> Abbs_future_combinators.return_ok `Done
      | Ok (idx, Some r) -> (
          match Payload.of_yojson @@ Ttm_kv_store.Record.data r with
          | Ok { Payload.chk; data } when chk <> "sha256:" ^ Sha256.(to_hex @@ string data) ->
              Logs.err (fun m ->
                  m
                    "Download failed: idx=%d : chk=%s: expected_chk=%s"
                    idx
                    ("sha256:" ^ Sha256.(to_hex @@ string data))
                    chk);
              raise (Failure "nyi")
          | Ok { Payload.data; chk = _ } -> (
              let data = Base64.decode_exn data in
              Abb.File.write
                fout
                Abb_intf.Write_buf.
                  [ { buf = Bytes.unsafe_of_string data; pos = 0; len = CCString.length data } ]
              >>= function
              | Ok n when n <> CCString.length data -> raise (Failure "nyi")
              | Ok _ -> Abbs_future_combinators.return_ok `Cont
              | Error _ -> raise (Failure "nyi"))
          | Error _ -> raise (Failure "nyi"))
      | Error _ -> raise (Failure "nyi")
    in
    let rec loop store idx fout src chunks =
      if CCList.length chunks < chunk_slots then
        let open Abb.Future.Infix_monad in
        Abb.Future.fork (download_chunk store idx)
        >>= fun fut -> loop store (idx + 1) fout src (chunks @ [ fut ])
      else
        match chunks with
        | [] -> assert false
        | c :: rest -> (
            let open Abb.Future.Infix_monad in
            process_chunk fout c
            >>= function
            | Ok `Done ->
                Abbs_future_combinators.List.iter ~f:Abb.Future.abort rest
                >>= fun () -> Abbs_future_combinators.return_ok ()
            | Ok `Cont -> loop store idx fout src rest
            | Error _ ->
                Abbs_future_combinators.List.iter ~f:Abb.Future.abort rest
                >>= fun () -> raise (Failure "nyi"))
    in
    let run =
      Logs.debug (fun m -> m "Processing file: %s" dst);
      Abbs_io_file.with_file_out dst ~f:(fun fout -> loop store 0 fout src [])
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok () -> Abbs_future_combinators.return_ok 0
    | Error (#Ttm_client.create_err as err) ->
        Logs.err (fun m -> m "%a" Ttm_client.pp_create_err err);
        Abbs_future_combinators.return_ok 1
    | Error (#Abb_intf.Errors.write as err) ->
        Logs.err (fun m -> m "%a" Abb_intf.Errors.pp_write err);
        Abbs_future_combinators.return_ok 1
    | Error (#Abbs_io_file.with_file_err as err) ->
        Logs.err (fun m -> m "%a" Abbs_io_file.pp_with_file_err err);
        Abbs_future_combinators.return_ok 1

  let run_upload store draft read_caps write_caps src dst =
    let upload_chunk draft idx checksum chunk =
      let open Abb.Future.Infix_monad in
      let data = `Assoc [ ("chk", `String checksum); ("data", `String chunk) ] in
      Logs.debug (fun m -> m "Uploading: idx=%d : chk=%s" idx checksum);
      Ttm_kv_store.cas ?read_caps ?write_caps ~idx ~committed:(not draft) ~key:dst data store
      >>= function
      | Ok _ -> Abbs_future_combinators.return_ok ()
      | Error (#Ttm_kv_store.err as err) -> Abbs_future_combinators.return_err err
    in
    let rec loop store draft idx fin dst chunks =
      if CCList.length chunks < chunk_slots then
        let open Abb.Future.Infix_monad in
        let buf = Bytes.create file_chunk_size in
        Abb.File.read fin ~buf ~pos:0 ~len:(Bytes.length buf)
        >>= function
        | Ok 0 ->
            Abbs_future_combinators.all chunks
            >>= fun results ->
            let open Abbs_future_combinators.Infix_result_monad in
            Abb.Future.return (CCResult.flatten_l results) >>| fun _ -> ()
        | Ok n ->
            let chunk = Base64.encode_string @@ Bytes.sub_string buf 0 n in
            let checksum = "sha256:" ^ Sha256.(to_hex @@ string chunk) in
            Abb.Future.fork (upload_chunk draft idx checksum chunk)
            >>= fun fut -> loop store draft (idx + 1) fin dst (fut :: chunks)
        | Error _ -> raise (Failure "nyi")
      else
        let open Abb.Future.Infix_monad in
        Abbs_future_combinators.firstl chunks
        >>= function
        | Ok (), rest -> loop store draft idx fin dst rest
        | (Error _ as err), rest ->
            Abbs_future_combinators.List.iter ~f:Abb.Future.abort rest
            >>= fun () -> Abb.Future.return err
    in
    let run =
      let open Abb.Future.Infix_monad in
      Logs.debug (fun m -> m "Deleting key: %s" dst);
      Ttm_kv_store.delete ~key:dst store
      >>= function
      | Ok _ ->
          Logs.debug (fun m -> m "Processing file: %s" src);
          Abbs_io_file.with_file_in src ~f:(fun fin -> loop store draft 0 fin dst [])
      | Error (#Ttm_kv_store.err as err) -> Abbs_future_combinators.return_err err
    in
    let open Abb.Future.Infix_monad in
    run
    >>= function
    | Ok () -> Abbs_future_combinators.return_ok 0
    | Error (#Ttm_client.create_err as err) ->
        Logs.err (fun m -> m "%a" Ttm_client.pp_create_err err);
        Abbs_future_combinators.return_ok 1
    | Error (#Abb_intf.Errors.read as err) ->
        Logs.err (fun m -> m "%a" Abb_intf.Errors.pp_read err);
        Abbs_future_combinators.return_ok 1
    | Error (#Abbs_io_file.with_file_err as err) ->
        Logs.err (fun m -> m "%a" Abbs_io_file.pp_with_file_err err);
        Abbs_future_combinators.return_ok 1

  let run_op store draft read_caps write_caps = function
    | `Download (src, dst) -> run_download store draft src dst
    | `Upload (src, dst) -> run_upload store draft read_caps write_caps src dst

  let run api_base vcs installation read_caps write_caps draft src dst () =
    let f () =
      let read_caps = wrap_opt_list read_caps in
      let write_caps = wrap_opt_list write_caps in
      try
        let open Abbs_future_combinators.Infix_result_monad in
        Logs.debug (fun m -> m "Validating paths %s %s" src dst);
        let op = validate_src_dst src dst in
        Logs.debug (fun m -> m "Creating client");
        Ttm_client.create ~base_url:(Uri.of_string api_base) ()
        >>= fun client ->
        let store = Ttm_kv_store.create ~vcs ~installation client in
        run_op store draft read_caps write_caps op
      with Invalid_path_combination_exn ->
        Logs.err (fun m ->
            m
              "One path must be a local file path and the other must be a path in the KV-store.  \
               Specify a KV-store path via 'kv://<key>'");
        Abbs_future_combinators.return_ok 1
    in
    run f

  let cmd logs =
    let module C = Cmdliner in
    let doc = "Copy a file to or from the kv store." in
    let exits = C.Cmd.Exit.defaults in
    C.Cmd.v
      (C.Cmd.info "cp" ~doc ~exits)
      C.Term.(
        const run
        $ Cli.api_base
        $ Cli.vcs
        $ Cli.installation_id
        $ Cli.read_caps
        $ Cli.write_caps
        $ Cli.draft
        $ Cli.src
        $ Cli.dst
        $ logs)
end

let cmd logs =
  let module C = Cmdliner in
  let doc = "Key-value store" in
  let info = Cmdliner.Cmd.info ~doc "kv" in
  C.Cmd.group
    info
    [
      Get.cmd logs;
      Set.cmd logs;
      Cas.cmd logs;
      Iter.cmd logs;
      Commit.cmd logs;
      Delete.cmd logs;
      Cp.cmd logs;
    ]
