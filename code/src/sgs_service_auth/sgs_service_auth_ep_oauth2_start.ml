let src = Logs.Src.create "ep_oauth2_start"

module Logs = (val Logs.src_log src : Logs.LOG)

let run oauth2 _provider =
  Brtl_ep.run ~content_type:"text/html" ~f:(fun ctx ->
      let open Abb.Future.Infix_monad in
      Abb.Sys.time ()
      >>= fun now ->
      Oauth2_htp.oauth_start
        ~now
        (Sgs_service_oauth2.Provider.authenticator oauth2)
        (Oauth2_htp_request.of_ctx ctx)
      >>| function
      | Ok { Oauth2_htp.Start_result.login_url; set_cookies } ->
          let headers = Cohttp.Header.of_list [ ("Location", login_url) ] in
          Brtl_ctx.set_response
            (Oauth2_htp_cookie.add_to_response
               set_cookies
               (Brtl_rspnc.create ~status:`Found ~headers ""))
            ctx
      | Error err ->
          Logs.err (fun m -> m "%s : OAUTH2_START : %a" (Brtl_ctx.token ctx) Oauth2_htp.pp_err err);
          Sgs_eplib.respond_internal_error ~body:"Sign-in failed" ctx)
