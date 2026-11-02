(** Deciding whether an authenticated email address is allowed. *)

(** [create ~email_domains] builds the email validator. An email is valid if it matches one of
    [email_domains] — [example.com] as an exact domain, [.example.com] or [*.example.com] as that
    domain or any subdomain, [*] as everything. Comparison is case insensitive and the empty email
    is never valid. *)
val create : email_domains:string list -> string -> bool
