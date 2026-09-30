(* The two answers the App endpoints share. They are one sentence each and they
   drifted the moment there were three copies. *)

let respond_unavailable ctx =
  Sgs_eplib.respond_error
    ~status:`Service_unavailable
    ~id:"GITHUB_APP_UNAVAILABLE"
    ~data:"The orchestration engine's admin channel is not configured on this server."
    ctx

(* One answer for "there is no such App here any more", whether the row is gone
   or is a different App: both mean the console is looking at something this
   server no longer has, and both are fixed by reloading. *)
let respond_stale ctx =
  Sgs_eplib.respond_error
    ~status:`Conflict
    ~id:"GITHUB_APP_STALE"
    ~data:"This is no longer the GitHub App this server holds. Reload the page."
    ctx
