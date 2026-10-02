let setup () = `In_app
let new_user_tenant () = `Default_tenant
let github_app () = `Console
let api_mode () = None
let record_first_touch ~config:_ ~identity:_ = Abb.Future.return (Ok ())

let send_tenant_invite
    ~config:_
    ~identity:_
    ~to_:_
    ~tenant_name:_
    ~inviter_name:_
    ~inviter_email:_
    ~accept_url:_
    ~expires_at:_
    ~idempotency_key:_ =
  Abb.Future.return (Error `Not_configured_err)
