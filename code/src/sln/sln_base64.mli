(** [encode s] is [s] in padded RFC 4648 base64, the variant {!is_valid} accepts.

    Base64 exists here to make arbitrary bytes storable as text. A PostgreSQL [jsonb] column rejects
    invalid UTF-8 and rejects [\u0000] even when escaped, and it silently reorders object keys; a
    value routed through here meets none of those, because the encoding output is plain ASCII with
    no structure of its own. Callers holding bytes that are known text and want to keep them
    readable in the column should not use this -- see {!Sln_utf8.split} for splitting text on
    codepoint boundaries instead. *)
val encode : string -> string

(** [decode s] is the bytes [s] encodes, or [`Msg] describing why it is not valid base64.

    The result type is the point. [Base64.decode_exn] responds to malformed input by padding it out
    with trailing NULs and returning it, so a damaged value decodes into a plausible shorter one
    that no downstream check can tell from the real thing. Callers must propagate the error rather
    than fall back to using [s] as-is: base64 is a proper subset of text, so a raw value can decode
    successfully into something entirely different, and guessing which representation a value is in
    is exactly the ambiguity encoding it was meant to remove. *)
val decode : string -> (string, [> `Msg of string ]) result

(** [decode_rfc2045 s] is the bytes that [s] encodes. It permits the line breaks that RFC 2045
    permits. Each other malformation is an error.

    PostgreSQL [encode(..., 'base64')] breaks its output after each 76 characters, and it uses a
    bare LF where the RFC specifies CRLF. {!decode} refuses a line break of either form. A value
    that is short enough has no line break, thus {!decode} is sufficient for a small value. It fails
    on the first value that is long enough to wrap. *)
val decode_rfc2045 : string -> (string, [> `Msg of string ]) result

(** [is_valid s] is whether [s] is well-formed RFC 4648 base64 {b with} padding: a length that is a
    multiple of four, every character drawn from [A-Za-z0-9+/], and zero, one or two [=] occurring
    only as the final characters.

    The guarantee runs one way: everything [is_valid] accepts, [Base64.decode] decodes, and
    everything [Base64.encode] produces, [is_valid] accepts. It is not the exact complement of
    [Base64.decode] and does not try to be -- [Base64.decode "===="] succeeds, returning the empty
    string, where [is_valid "===="] is [false]. That degenerate all-padding form is not something an
    encoder emits, so a value carrying it is damaged whatever the decoder makes of it, and the
    stricter answer is the useful one.

    The strictness is the point: this stands in for a decode that happens somewhere else later, so
    accepting anything that decode would reject would make the answer worthless. Note that the RFC
    2045 variant, which tolerates embedded newlines, is {i not} accepted here -- a caller reading
    base64 produced by PostgreSQL's [encode(..., 'base64')] wants a line-tolerant decoder, not this
    predicate.

    Validity is a statement about encoding only. It says nothing about what the decoded bytes mean,
    so it catches truncation, corruption and double-encoding but not a well-formed encoding of the
    wrong content.

    The empty string is valid: it is the encoding of no bytes.

    [is_valid] does not decode, so it costs one pass and allocates nothing regardless of length. *)
val is_valid : string -> bool
