let src = Logs.Src.create "cohttp_abb.tls"

module Logs = (val Logs.src_log src : Logs.LOG)

module Make (Abb : Abb_intf.S with type Native.t = Unix.file_descr) = struct
  module Http = Cohttp_abb.Make (Abb)
  module Abb_tls = Abb_tls.Make (Abb)

  let get_env name =
    CCOption.or_
      ~else_:(Sys.getenv_opt (CCString.uppercase_ascii name))
      (Sys.getenv_opt (CCString.lowercase_ascii name))

  let env_list name =
    CCOption.map_or
      ~default:[]
      CCFun.(CCString.split_on_char ',' %> CCList.map CCString.trim)
      (get_env name)

  let client_channel () =
    let no_verify_tls_cert = env_list "no_verify_tls_cert" in
    let no_verify_tls_name = env_list "no_verify_tls_name" in
    let local_certs_dir = Sys.getenv_opt "CERTS_DIR" in
    fun ~host sock ->
      let config = Otls.Tls_config.create () in
      ignore (Otls.Tls_config.set_alpn config "http/1.1");
      CCOption.iter
        (fun local_certs_dir ->
          Logs.debug (fun m -> m "CERTS_DIR : %s" local_certs_dir);
          ignore (Otls.Tls_config.set_ca_path config local_certs_dir))
        local_certs_dir;
      if Sln_list.String.mem host no_verify_tls_cert || no_verify_tls_cert = [ "*" ] then (
        Logs.debug (fun m ->
            m "NO_VERIFY_CERT : %s : %s" host (CCString.concat " " no_verify_tls_cert));
        Otls.Tls_config.insecure_noverifycert config);
      if Sln_list.String.mem host no_verify_tls_name || no_verify_tls_name = [ "*" ] then (
        Logs.debug (fun m ->
            m "NO_VERIFY_NAME : %s : %s" host (CCString.concat " " no_verify_tls_name));
        Otls.Tls_config.insecure_noverifyname config);
      Fun.protect
        ~finally:(fun () -> Otls.Tls_config.destroy config)
        (fun () -> Abb_tls.client_tcp sock config host)

  let connector () = Http.Client.Connector.of_env ~channel:(client_channel ()) ()
end
