let run _config _storage =
  Brtl_ep.run_json ~f:(fun ctx ->
      let body =
        Sgs_api_components_version_response.(
          to_yojson
            { version = Sg_version.version; state_schema_version = Sg_state_schema_version.version })
        |> Yojson.Safe.to_string
      in
      Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx))
