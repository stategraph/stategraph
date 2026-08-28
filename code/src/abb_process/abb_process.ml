type output_err =
  [ Abb_intf.Errors.spawn
  | Abb_intf.Errors.write
  | Abb_intf.Errors.read
  | Abb_intf.Errors.close
  ]
[@@deriving show]

type check_output_err =
  [ output_err
  | `Run_error of Abb_intf.Process.t * string * string * Abb_intf.Process.Exit_code.t
  ]
[@@deriving show]

let args ?env program args = Abb_intf.Process.{ exec_name = program; args = program :: args; env }

module Make (Abb : Abb_intf.S with type Native.t = Unix.file_descr) = struct
  module Fut_comb = Abb_future_combinators.Make (Abb.Future)

  let read_all file =
    let buffer = Buffer.create 1024 in
    let bytes = Bytes.create 1024 in
    let len = Bytes.length bytes in
    let rec read_data buffer file bytes =
      let open Fut_comb.Infix_result_monad in
      Abb.File.read file ~buf:bytes ~pos:0 ~len
      >>= function
      | 0 -> Abb.File.close file >>| fun _ -> Buffer.contents buffer
      | n ->
          Buffer.add_subbytes buffer bytes 0 n;
          read_data buffer file bytes
    in
    read_data buffer file bytes

  let output ?input process =
    let open Fut_comb.Infix_result_monad in
    let stdin_r, stdin_w = Unix.pipe ~cloexec:false () in
    let stdout_r, stdout_w = Unix.pipe ~cloexec:false () in
    let stderr_r, stderr_w = Unix.pipe ~cloexec:false () in
    Unix.set_nonblock stdout_r;
    Unix.set_nonblock stderr_r;
    Unix.set_close_on_exec stdin_w;
    Unix.set_close_on_exec stdout_r;
    Unix.set_close_on_exec stderr_r;
    match Abb.Process.spawn ~stdin:stdin_r ~stdout:stdout_w ~stderr:stderr_w process with
    | Ok process -> (
        Unix.close stdin_r;
        Unix.close stdout_w;
        Unix.close stderr_w;
        let stdin_w = Abb.File.of_native stdin_w in
        let stdout_r = Abb.File.of_native stdout_r in
        let stderr_r = Abb.File.of_native stderr_r in
        (match input with
          | Some input ->
              Abb.File.write
                stdin_w
                Abb_intf.Write_buf.
                  [ { buf = Bytes.of_string input; pos = 0; len = String.length input } ]
              >>| fun n ->
              assert (n = String.length input);
              ()
          | None -> Fut_comb.return_ok ())
        >>= fun () ->
        Abb.File.close stdin_w
        >>= fun () ->
        let open Abb.Future.Infix_monad in
        Abb.Future.Infix_app.(
          (fun stdout stderr exit_code -> (stdout, stderr, exit_code))
          <$> read_all stdout_r
          <*> read_all stderr_r
          <*> Abb.Process.wait process)
        >>| function
        | Ok stdout, Ok stderr, exit_code -> Ok (stdout, stderr, exit_code)
        | (Error _ as err), _, _ | _, (Error _ as err), _ -> err)
    | Error _ as err -> Abb.Future.return err

  let check_output ?input process =
    let open Abb.Future.Infix_monad in
    output ?input process
    >>= function
    | Ok (stdout, stderr, Abb_intf.Process.Exit_code.Exited 0) -> Fut_comb.return_ok (stdout, stderr)
    | Ok (stdout, stderr, exit_code) ->
        Fut_comb.return_err (`Run_error (process, stdout, stderr, exit_code))
    | Error err -> Fut_comb.return_err err
end
