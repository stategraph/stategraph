(** [application/x-www-form-urlencoded] string encoding, matching Go's [url.QueryEscape] (and
    therefore Terraform's [urlencode] function).

    This is deliberately NOT RFC 3986 percent-encoding (as in the [uri] library): the unreserved set
    [A-Za-z0-9-_.~] is kept verbatim, a space becomes ['+'], and every other byte is percent-encoded
    as [%XX] with uppercase hex. The ['+']-for-space rule is the HTML form-encoding convention,
    which RFC 3986 encoders ([uri]) do not implement. *)
val encode : string -> string
