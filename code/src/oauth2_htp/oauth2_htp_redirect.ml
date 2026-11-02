let src = Logs.Src.create "oauth2_htp_redirect"

module Logs = (val Logs.src_log src : Logs.LOG)

(* Used to check final redirects are not susceptible to open redirects.  Matches //, /\ and both of
   these with whitespace or dot segments in between (eg / / or / \).  [Re]'s Perl syntax has no
   [\v], so the class is spelled out. *)
let invalid_redirect_re =
  let open Re in
  let slash = set "/\\" in
  let whitespace = set " \t\n\011\012\r" in
  compile (seq [ slash; alt [ rep whitespace; repn (char '.') 1 (Some 2) ]; slash ])

let trim_prefix ~pre s = CCOption.get_or ~default:s (CCString.chop_prefix ~pre s)

type port =
  | Default
  | Any
  | Port of int

(* An allowed domain is a host with an optional [:port] or [:*]. Anything else is all host. *)
let parse_allowed_domain domain =
  let uri = Uri.of_string ("//" ^ domain) in
  match (Uri.host uri, Uri.port uri, Uri.path uri) with
  | Some host, Some port, "" -> (host, Port port)
  | Some host, None, "" -> (host, Default)
  | Some host, None, "*" -> (host, Any)
  | (Some _ | None), _, _ -> (domain, Default)

let split_host_port hostport =
  match parse_allowed_domain hostport with
  | host, Default -> (host, "")
  | host, Any -> (host, "*")
  | host, Port port -> (host, CCInt.to_string port)

let is_hostname_allowed hostname allowed_host =
  (* Perfect match between hostname and allowed_host. *)
  CCString.equal hostname (trim_prefix ~pre:"." allowed_host)
  || CCString.equal hostname (trim_prefix ~pre:"*." allowed_host)
  (* hostname is a sub domain of allowed_host. *)
  || (CCString.prefix ~pre:"." allowed_host && CCString.suffix ~suf:allowed_host hostname)
  || CCString.prefix ~pre:"*." allowed_host
     && CCString.suffix ~suf:(CCString.drop 1 allowed_host) hostname

let is_endpoint_allowed endpoint allowed_domains =
  let hostname = CCOption.get_or ~default:"" (Uri.host endpoint) in
  CCList.exists
    (fun allowed_domain ->
      let allowed_host, allowed_port = parse_allowed_domain allowed_domain in
      (not (CCString.is_empty allowed_host))
      && is_hostname_allowed hostname allowed_host
      &&
      (* Without a port in the allowed domain, only the scheme's default port is allowed. *)
      match (allowed_port, Uri.port endpoint) with
      | Any, _ | Default, None -> true
      | Port allowed, Some port -> CCInt.equal allowed port
      | Default, Some _ | Port _, None -> false)
    allowed_domains

let is_valid_redirect ~allowed_domains redirect =
  let uri = Uri.of_string redirect in
  match (Uri.scheme uri, Uri.host uri) with
  | None, None when CCString.prefix ~pre:"/" redirect && not (Re.execp invalid_redirect_re redirect)
    -> true
  | Some ("http" | "https"), _ -> (
      match is_endpoint_allowed uri allowed_domains with
      | true -> true
      | false ->
          Logs.info (fun m ->
              m "Rejecting invalid redirect %S: domain / port not in whitelist" redirect);
          false)
  | (Some _ | None), _ ->
      Logs.info (fun m ->
          m "Rejecting invalid redirect %S: not an absolute or relative URL" redirect);
      false
