let ui_base = "https://app.stategraph.cloud"

let path_test ~name ~input ~expected =
  Oth.test ~tags:[ "redirect" ] ~name (fun _ ->
      Oth.Assert.Eq.string_option ~expected ~actual:(Sgs_redirect.path input))

let url_test ?(ui_base = ui_base) ~name ~input ~expected () =
  Oth.test ~tags:[ "redirect" ] ~name (fun _ ->
      Oth.Assert.Eq.string_option ~expected ~actual:(Sgs_redirect.url ~ui_base input))

let path_tests =
  [
    path_test ~name:"path: a site-relative path" ~input:"/dashboard" ~expected:(Some "/dashboard");
    path_test
      ~name:"path: a tab is stripped by browsers and opens an authority"
      ~input:"/\t/evil.com"
      ~expected:None;
    path_test
      ~name:"path: repeated tabs before a protocol-relative authority"
      ~input:"/\t\t//evil.com"
      ~expected:None;
    path_test ~name:"path: a NUL is not transmittable" ~input:"/\000/evil.com" ~expected:None;
    path_test ~name:"path: a raw space is not transmittable" ~input:"/ /evil.com" ~expected:None;
    path_test ~name:"path: the root" ~input:"/" ~expected:(Some "/");
    path_test
      ~name:"path: query and fragment ride along"
      ~input:"/states?page=2#top"
      ~expected:(Some "/states?page=2#top");
    path_test
      ~name:"path: protocol-relative names another origin"
      ~input:"//evil.com"
      ~expected:None;
    path_test
      ~name:"path: a backslash opens an authority the same way"
      ~input:"/\\evil.com"
      ~expected:None;
    path_test ~name:"path: an absolute https URL" ~input:"https://attacker.com" ~expected:None;
    path_test ~name:"path: an absolute http URL" ~input:"http://attacker.com" ~expected:None;
    path_test ~name:"path: a javascript scheme" ~input:"javascript:alert(1)" ~expected:None;
    path_test ~name:"path: a bare host" ~input:"attacker.com" ~expected:None;
    path_test ~name:"path: no leading slash" ~input:"dashboard" ~expected:None;
    path_test ~name:"path: the empty string" ~input:"" ~expected:None;
    path_test
      ~name:"path: a carriage return would split the header"
      ~input:"/x\r\nSet-Cookie: session=1"
      ~expected:None;
    path_test
      ~name:"path: a line feed would split the header"
      ~input:"/x\nLocation: /y"
      ~expected:None;
  ]

let url_tests =
  [
    url_test
      ~name:"url: a site-relative path still passes"
      ~input:"/dashboard"
      ~expected:(Some "/dashboard")
      ();
    url_test
      ~name:"url: an absolute URL on our own origin"
      ~input:"https://app.stategraph.cloud/dashboard"
      ~expected:(Some "https://app.stategraph.cloud/dashboard")
      ();
    url_test
      ~name:"url: the host compares case-insensitively"
      ~input:"https://APP.Stategraph.Cloud/dashboard"
      ~expected:(Some "https://APP.Stategraph.Cloud/dashboard")
      ();
    url_test
      ~name:"url: an explicit default port is the same origin"
      ~input:"https://app.stategraph.cloud:443/dashboard"
      ~expected:(Some "https://app.stategraph.cloud:443/dashboard")
      ();
    url_test
      ~name:"url: a trailing slash on ui_base does not matter"
      ~ui_base:"https://app.stategraph.cloud/"
      ~input:"https://app.stategraph.cloud/dashboard"
      ~expected:(Some "https://app.stategraph.cloud/dashboard")
      ();
    url_test
      ~name:"url: another scheme is another origin"
      ~input:"http://app.stategraph.cloud/dashboard"
      ~expected:None
      ();
    url_test
      ~name:"url: another port is another origin"
      ~input:"https://app.stategraph.cloud:8443/dashboard"
      ~expected:None
      ();
    url_test ~name:"url: another host" ~input:"https://attacker.com" ~expected:None ();
    url_test
      ~name:"url: our host as a prefix of the attacker's"
      ~input:"https://app.stategraph.cloud.attacker.com/dashboard"
      ~expected:None
      ();
    url_test
      ~name:"url: our host in the userinfo of the attacker's"
      ~input:"https://app.stategraph.cloud@attacker.com/dashboard"
      ~expected:None
      ();
    url_test
      ~name:"url: protocol-relative to our own host"
      ~input:"//app.stategraph.cloud"
      ~expected:None
      ();
    url_test
      ~name:"url: a carriage return would split the header"
      ~input:"https://app.stategraph.cloud/x\r\nSet-Cookie: session=1"
      ~expected:None
      ();
    url_test
      ~name:"url: a tab hides userinfo, so the browser host is the attacker's"
      ~input:"https://app.stategraph.cloud\t@attacker.com/x"
      ~expected:None
      ();
    url_test
      ~name:"url: a backslash hides userinfo for an RFC 3986 follower"
      ~input:"https://app.stategraph.cloud\\@attacker.com/x"
      ~expected:None
      ();
    url_test
      ~name:"url: a tab terminates the authority for the standards parse only"
      ~input:"https://app.stategraph.cloud\t.attacker.com/x"
      ~expected:None
      ();
    url_test
      ~name:"url: the dev console origin, explicit non-default port"
      ~ui_base:"http://localhost:3000"
      ~input:"http://localhost:3000/dashboard"
      ~expected:(Some "http://localhost:3000/dashboard")
      ();
    url_test
      ~name:"url: another port on the dev host is another origin"
      ~ui_base:"http://localhost:3000"
      ~input:"http://localhost:3001/dashboard"
      ~expected:None
      ();
    url_test
      ~name:"url: a ui_base with no origin accepts no absolute URL"
      ~ui_base:""
      ~input:"https://attacker.com"
      ~expected:None
      ();
  ]

let test = Oth.parallel (path_tests @ url_tests)
let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
