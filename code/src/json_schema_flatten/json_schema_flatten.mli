(** Flatten a multi-file JSON schema document into a single self-contained one.

    Foreign references of the form ["<path>#/definitions/<Name>"], or
    ["<path>#/components/schemas/<Name>"] into an OpenAPI document, are resolved against
    [search_path] (and the referencing file's directory). By default the referenced definition is
    inlined into the document's ["definitions"] and the ref rewritten to an internal
    ["#/definitions/<canonical>"] (the canonical name is namespaced by the foreign file's stem).
    Files named in [file_link] (matched by the ref's path, then by basename) are instead referenced
    via ["#/file-link/<MODULE_BASE>/<Name>"] and are neither loaded nor inlined. Internal ["#/..."]
    refs of the root document are left untouched; internal refs of an inlined definition point into
    its own file, so they are inlined the same way.

    For example, with [api.json] holding [{"components": {"schemas": {"tx": ...}}}], the ref
    [{"$ref": "api.json#/components/schemas/tx"}] becomes:
    {v
      {"$ref": "#/definitions/api_tx"}               by default
      {"$ref": "#/file-link/Sgs_api_components/tx"}  with ("api.json", "Sgs_api_components")
    v}

    Transitive foreign refs are flattened recursively; cycles are broken by reusing the canonical
    name of an already-visited definition.

    Raises [Failure] if a foreign file cannot be located, a referenced definition is missing, or a
    foreign ref uses an unsupported pointer. *)
val flatten_document :
  search_path:string list ->
  file_link:(string * string) list ->
  root_file:string ->
  Yojson.Safe.t ->
  Yojson.Safe.t
