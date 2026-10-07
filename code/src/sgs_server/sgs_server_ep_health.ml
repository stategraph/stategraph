let run _config _storage =
  Brtl_ep.run_json ~f:(fun ctx ->
      Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK "") ctx))
