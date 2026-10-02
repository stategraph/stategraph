(* Self-hosted checks for [Oth.Assert.List.str_mem] and [Oth.Assert.List.str_not_mem].

   As in [tags_test.ml], checks go through [check] rather than [assert], because the release profile
   compiles with -noassert. *)

let check msg b = if not b then failwith ("check failed: " ^ msg)

let fails f =
  match f () with
  | () -> false
  | exception _ -> true

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
    (fails (fun () -> Oth.Assert.List.str_not_mem ~fail_msg:"why" ~searched:"a" [ "a" ]))
