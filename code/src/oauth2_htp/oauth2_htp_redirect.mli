(** Redirect validation: checking that the destination a sign-in returns to is safe. *)

(** Split [host:port], accepting a ["*"] port and stripping the brackets of an IPv6 host. A
    non-numeric port is part of the host. *)
val split_host_port : string -> string * string

(** Whether the host and port of [endpoint] match one of [allowed_domains]: [example.com] exactly,
    [.example.com] or [*.example.com] for the domain or any subdomain, each with an optional [:port]
    or [:*]. Without a port only the default port is allowed. *)
val is_endpoint_allowed : Uri.t -> string list -> bool

(** A path on this host that cannot be read as a protocol-relative URL, or an absolute [http(s)] URL
    on one of [allowed_domains]. *)
val is_valid_redirect : allowed_domains:string list -> string -> bool
