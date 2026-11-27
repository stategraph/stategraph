(* Self-hosted checks for list assertions.

   As in [tags_test.ml], checks go through [check] rather than [assert], because the release profile
   compiles with -noassert. *)

let check msg b = if not b then failwith ("check failed: " ^ msg)

let fails f =
  match f () with
  | () -> false
  | exception _ -> true

let failure_message f =
  match f () with
  | () -> failwith "expected an assertion failure"
  | exception exn -> Printexc.to_string exn

module Case_insensitive_list = Oth.Assert.Make (struct
  type t = string

  let equal a b = CCString.equal (CCString.lowercase_ascii a) (CCString.lowercase_ascii b)
  let pp fmt s = Format.fprintf fmt "element(%s)" s
  let show = Format.asprintf "%a" pp
end)

let () =
  check
    "a member passes"
    (not (fails (fun () -> Oth.Assert.List.str_mem ~searched:"b" [ "a"; "b"; "c" ])));
  check
    "an absent string fails"
    (fails (fun () -> Oth.Assert.List.str_mem ~searched:"d" [ "a"; "b"; "c" ]));
  check "the empty list fails" (fails (fun () -> Oth.Assert.List.str_mem ~searched:"a" []));
  check
    "a message does not change the answer"
    (fails (fun () -> Oth.Assert.List.str_mem ~fail_msg:"why" ~searched:"d" [ "a" ]));
  check
    "an absent string passes str_not_mem"
    (not (fails (fun () -> Oth.Assert.List.str_not_mem ~searched:"d" [ "a"; "b"; "c" ])));
  check
    "the empty list passes str_not_mem"
    (not (fails (fun () -> Oth.Assert.List.str_not_mem ~searched:"a" [])));
  check
    "a member fails str_not_mem"
    (fails (fun () -> Oth.Assert.List.str_not_mem ~searched:"b" [ "a"; "b"; "c" ]));
  check
    "a message does not change the answer of str_not_mem"
    (fails (fun () -> Oth.Assert.List.str_not_mem ~fail_msg:"why" ~searched:"a" [ "a" ]));

  let module L = Oth.Assert.String_list in
  L.eq ~expected:[] ~actual:[];
  L.eq ~expected:[ "a"; "b" ] ~actual:[ "a"; "b" ];
  let msg = failure_message (fun () -> L.eq ~expected:[ "a"; "b" ] ~actual:[ "b"; "c"; "d" ]) in
  check "list equality reports differing items" (CCString.mem ~sub:"Item 0 differs" msg);
  check "list equality reports extra items" (CCString.mem ~sub:"1 extra item(s)" msg);
  let msg = failure_message (fun () -> L.eq ~expected:[ "a"; "b" ] ~actual:[ "a" ]) in
  check "list equality reports missing items" (CCString.mem ~sub:"1 missing item(s)" msg);
  L.all_mem ~haystack:[ "a"; "b" ] ~needles:[ "b"; "a"; "a" ];
  L.all_mem ~haystack:[] ~needles:[];
  check
    "membership uses whole elements"
    (fails (fun () -> L.all_mem ~haystack:[ "abc" ] ~needles:[ "a" ]));
  let msg = failure_message (fun () -> L.all_mem ~haystack:[] ~needles:[ "first"; "second" ]) in
  check "all_mem reports the first missing element" (CCString.mem ~sub:"first" msg);
  check "all_mem stops at the first missing element" (not (CCString.mem ~sub:"second" msg));
  L.none_mem ~haystack:[] ~needles:[ "a" ];
  L.none_mem ~haystack:[ "a" ] ~needles:[];
  L.none_mem ~haystack:[ "abc" ] ~needles:[ "a"; "b" ];
  let msg =
    failure_message (fun () ->
        L.none_mem ~haystack:[ "first"; "second" ] ~needles:[ "first"; "second" ])
  in
  check "none_mem reports the first present element" (CCString.mem ~sub:"first" msg);
  check "none_mem stops at the first present element" (not (CCString.mem ~sub:"second" msg));

  Case_insensitive_list.eq ~expected:[ "A" ] ~actual:[ "a" ];
  Case_insensitive_list.all_mem ~haystack:[ "A" ] ~needles:[ "a" ];
  Case_insensitive_list.none_mem ~haystack:[ "A" ] ~needles:[ "b" ];
  let msg =
    failure_message (fun () -> Case_insensitive_list.none_mem ~haystack:[ "A" ] ~needles:[ "a" ])
  in
  check "custom printer renders the failing element" (CCString.mem ~sub:"element(a)" msg);

  let module I = Oth.Assert.Int_list in
  I.eq ~expected:[ 1; 2 ] ~actual:[ 1; 2 ];
  I.all_mem ~haystack:[ 1; 2 ] ~needles:[ 2; 1 ];
  I.none_mem ~haystack:[ 1; 2 ] ~needles:[ 3 ];
  let msg = failure_message (fun () -> I.all_mem ~haystack:[ 1 ] ~needles:[ 2 ]) in
  check "integer failure prints the missing element" (CCString.mem ~sub:"2" msg);

  let module B = Oth.Assert.Bool_list in
  B.eq ~expected:[ true; false ] ~actual:[ true; false ];
  B.all_mem ~haystack:[ true ] ~needles:[ true ];
  B.none_mem ~haystack:[ true ] ~needles:[ false ];
  let msg = failure_message (fun () -> B.all_mem ~haystack:[ true ] ~needles:[ false ]) in
  check "boolean failure prints the missing element" (CCString.mem ~sub:"false" msg);

  let uuid s =
    match Uuidm.of_string s with
    | Some u -> u
    | None -> failwith "invalid UUID fixture"
  in
  let u1 = uuid "00000000-0000-0000-0000-000000000001" in
  let u1_copy = uuid "00000000-0000-0000-0000-000000000001" in
  let u2 = uuid "00000000-0000-0000-0000-000000000002" in
  let module U = Oth.Assert.Uuidm_list in
  U.eq ~expected:[ u1 ] ~actual:[ u1_copy ];
  U.all_mem ~haystack:[ u1 ] ~needles:[ u1_copy ];
  U.none_mem ~haystack:[ u1 ] ~needles:[ u2 ];
  let msg = failure_message (fun () -> U.all_mem ~haystack:[ u1 ] ~needles:[ u2 ]) in
  check "UUID failure prints the missing UUID" (CCString.mem ~sub:(Uuidm.to_string u2) msg);
  check
    "UUID membership rejects present values"
    (fails (fun () -> U.none_mem ~haystack:[ u1 ] ~needles:[ u1_copy ]))
