(* Whether the authenticated email is validated against one of the provided domains. *)
let is_email_valid_with_domains email allowed_domains =
  let atom = CCOption.get_or ~default:email (CCList.last_opt (CCString.split_on_char '@' email)) in
  CCList.exists
    (fun domain ->
      (* Allow if the domain is a perfect suffix match with the email. *)
      CCString.suffix ~suf:("@" ^ domain) email
      (* Allow if the domain is prefixed with . or *. and the last element, split on @, has the
         domain as a suffix. *)
      || (CCString.prefix ~pre:"." domain && CCString.suffix ~suf:domain atom)
      || CCString.prefix ~pre:"*." domain
         && CCString.suffix ~suf:(CCString.sub domain 1 (CCString.length domain - 1)) atom)
    allowed_domains

let create ~email_domains =
  let allow_all = Sln_list.String.mem "*" email_domains in
  let domains = CCList.map CCString.lowercase_ascii email_domains in
  fun email ->
    match email with
    | "" -> false
    | _ when allow_all -> true
    | email -> is_email_valid_with_domains (CCString.lowercase_ascii email) domains
