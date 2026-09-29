(* A Location value has to survive the trip byte for byte. Browsers delete every ASCII tab, LF and
   CR before parsing a URL, so a value a standards parse reads as site-relative can name an
   authority by the time the browser sees it; CR and LF also split the response header. Backslash
   appears in no RFC 3986 production, and the two parsers disagree about it. Allow printable ASCII
   only, backslash excluded. *)
let is_transmittable s =
  CCString.for_all (fun c -> Char.code c > 0x20 && Char.code c < 0x7f && not (Char.equal c '\\')) s

(* A second character of '/' or '\\' opens an authority, so a value that reads as site-relative can
   still name another origin. Browsers normalize the backslash form to the slash form. *)
let opens_authority s = CCString.length s > 1 && (Char.equal s.[1] '/' || Char.equal s.[1] '\\')

let default_port = function
  | "https" -> Some 443
  | "http" -> Some 80
  | _ -> None

let origin_port uri =
  CCOption.or_ ~else_:(CCOption.flat_map default_port (Uri.scheme uri)) (Uri.port uri)

let host uri = CCOption.map CCString.lowercase_ascii (Uri.host uri)

let same_origin ~base uri =
  match (Uri.scheme base, host base) with
  | Some base_scheme, Some base_host ->
      CCOption.equal CCString.equal (Some base_scheme) (Uri.scheme uri)
      && CCOption.equal CCString.equal (Some base_host) (host uri)
      && CCOption.equal CCInt.equal (origin_port base) (origin_port uri)
  | None, None | None, Some _ | Some _, None -> false

let path s =
  let uri = Uri.of_string s in
  match (Uri.scheme uri, Uri.host uri) with
  | None, None when CCString.prefix ~pre:"/" s && (not (opens_authority s)) && is_transmittable s ->
      Some s
  | None, None | None, Some _ | Some _, None | Some _, Some _ -> None

let url ~ui_base s =
  match path s with
  | Some _ as safe -> safe
  | None when is_transmittable s && same_origin ~base:(Uri.of_string ui_base) (Uri.of_string s) ->
      Some s
  | None -> None
