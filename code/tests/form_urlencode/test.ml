(* Expected values are the output of Go's [url.QueryEscape] / OpenTofu's
   [urlencode], verified against the tofu console as the oracle. *)
let encode_test =
  Oth.test ~name:"encode" (fun _ ->
      let check ~input ~expected =
        Oth.Assert.Eq.string ~expected ~actual:(Form_urlencode.encode input)
      in
      (* space -> '+', '!' -> %21 (the form-encoding rule [uri] cannot produce). *)
      check ~input:"Hello World!" ~expected:"Hello+World%21";
      (* unreserved set is kept verbatim. *)
      check ~input:"AZaz09-_.~" ~expected:"AZaz09-_.~";
      (* reserved/sub-delims are percent-encoded with uppercase hex; a literal
         '+' becomes %2B (distinct from an encoded space). *)
      check ~input:"a+b=c/d?e&f#g" ~expected:"a%2Bb%3Dc%2Fd%3Fe%26f%23g";
      (* empty string round-trips to empty. *)
      check ~input:"" ~expected:"";
      ())

let () =
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> encode_test)
