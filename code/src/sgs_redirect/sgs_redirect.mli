(** Validation for a redirect target that arrives on a request and ends up in a [Location] header.

    Both functions answer [None] for a value that must not be redirected to. The caller decides what
    to do instead: fall back to a destination it chose itself, or answer with no [Location] at all.
*)

(** [path s] is [Some s] when [s] is a site-relative path. It must start with a ['/'], its second
    character must be neither ['/'] nor ['\\'] (both open an authority, so ["//evil.com"] names
    another origin and browsers normalize the backslash form), it must carry no CR or LF (either
    would split the response header), and a standards parse of it must find neither a scheme nor a
    host. Anything else is [None]. *)
val path : string -> string option

(** [url ~ui_base s] is [path s] for a site-relative [s], and [Some s] for an absolute [s] whose
    scheme, host and port match [ui_base] — hosts compared case-insensitively, and the default port
    filled in for http and https. Anything else is [None].

    Use it wherever the target may legitimately be absolute, which includes every redirect the
    console itself supplies: in development it sends the full [ui_base] origin because the console
    and the API are served from different ports. [path] is for a target that must stay
    site-relative. *)
val url : ui_base:string -> string -> string option
