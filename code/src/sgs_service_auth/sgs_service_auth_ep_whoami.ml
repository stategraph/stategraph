let user_type_to_api = function
  | Sgs_user.Type_.User -> `User
  | Sgs_user.Type_.Api -> `Api
  | Sgs_user.Type_.System -> `System

let run _config _storage =
  Sgs_user_session.with_session ~caps:Sgs_user_session.Caps.allow_all ~f:(fun session ->
      Brtl_ep.run_json ~f:(fun ctx ->
          let user = Sgs_user_session.Session.user session in
          let module U = Sgs_api_components.User in
          let body =
            Yojson.Safe.to_string
            @@ U.to_yojson
                 {
                   U.auth_origin = Sgs_user.auth_origin user;
                   email = Sgs_user.email user;
                   id = Uuidm.to_string @@ Sgs_user.id user;
                   type_ = user_type_to_api @@ Sgs_user.type_ user;
                   name = Sgs_user.name user;
                   avatar_url = Sgs_user.avatar_url user;
                   capabilities =
                     Sg_caps_json.to_wire (Sgs_user_session.Session.capabilities session);
                 }
          in
          Abb.Future.return (Brtl_ctx.set_response (Brtl_rspnc.create ~status:`OK body) ctx)))
