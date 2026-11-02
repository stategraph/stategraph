type t = {
  name : string;
  value : string;
  max_age : int;
  secure : bool;
}

let to_set_cookie_header t =
  Printf.sprintf
    "%s=%s; Path=/; Max-Age=%d; HttpOnly%s; SameSite=Lax"
    t.name
    t.value
    t.max_age
    (if t.secure then "; Secure" else "")

let add_to_response ts rspnc =
  CCList.fold_left
    (fun rspnc t -> Brtl_rspnc.add_header "Set-Cookie" (to_set_cookie_header t) rspnc)
    rspnc
    ts
