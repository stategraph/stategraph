module Oth_abb = Oth_abb.Make (Abb)

module Eh = struct
  type el = {
    rendered_length : int;
    dirspace : Terrat_dirspace.t;
    is_success : bool;
    strategy : Terrat_vcs_comment.Strategy.t;
  }
  [@@deriving show]

  type comment_id = int [@@deriving ord, show]

  type t =
    | Query_comment_id of el * (comment_id option, [ `Error ]) result
    | Query_els_for_comment_id of comment_id * (el list, [ `Error ]) result
    | Upsert_comment_id of el list * comment_id * (unit, [ `Error ]) result
    | Minimize_comment of comment_id * (unit, [ `Error ]) result
    | Post_comment of el list * (comment_id, [ `Error ]) result
  [@@deriving show]

  type commands = t list [@@deriving show]
end

module API_id = struct
  let create start = Atomic.make start
  let next counter = Atomic.fetch_and_add counter 1 + 1
end

module H = struct
  type t = Eh.commands ref
  type el = Eh.el [@@deriving show]
  type comment_id = Eh.comment_id [@@deriving ord, show]

  module Cmp = struct
    type t = bool * Terrat_dirspace.t [@@deriving ord]
  end

  let query_comment_id t el1 =
    match !t with
    | Eh.Query_comment_id (el2, cmd_result) :: rest when el1 = el2 ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result : ('a, [ `Error ]) result Abb.Future.t :> ('a, [> `Error ]) result Abb.Future.t)
    | es ->
        Printf.printf "\n\tQUERY COMMENT_ID INPUT: %s%!\n" (Eh.show_el el1);
        Printf.printf "\n\tQUERY COMMENT_ID LOG: %s%!\n" (Eh.show_commands es);
        Oth.Assert.false_ "test: unexpected value"

  let query_els_for_comment_id t cid =
    match !t with
    | Eh.Query_els_for_comment_id (cid2, cmd_result) :: rest when cid = cid2 ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result : ('a, [ `Error ]) result Abb.Future.t :> ('a, [> `Error ]) result Abb.Future.t)
    | es ->
        Printf.printf "\n\tQUERY ELS INPUT: %d%!\n" cid;
        Printf.printf "\n\tQUERY ELS FOR COMMENT_ID LOG: %s%!\n" (Eh.show_commands es);
        Oth.Assert.false_ "test: unexpected value"

  let upsert_comment_id t _els cid =
    match !t with
    | Eh.Upsert_comment_id (_els2, cid2, cmd_result) :: rest when cid = cid2 ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result : ('a, [ `Error ]) result Abb.Future.t :> ('a, [> `Error ]) result Abb.Future.t)
    | es ->
        Printf.printf "\n\tUPSERT INPUT: %d%!\n" cid;
        Printf.printf "\n\tUPSERT LOG: %s%!\n" (Eh.show_commands es);
        Oth.Assert.false_ "test: unexpected value"

  let delete_comment t cid =
    let es = !t in
    Printf.printf "\n\tDELETE INPUT: %d%!\n" cid;
    Printf.printf "\n\tDELETE LOG: %s%!\n" (Eh.show_commands es);
    Oth.Assert.false_ "test: unexpected value"

  let minimize_comment t cid =
    match !t with
    | Eh.Minimize_comment (cid2, cmd_result) :: rest when cid = cid2 ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result : ('a, [ `Error ]) result Abb.Future.t :> ('a, [> `Error ]) result Abb.Future.t)
    | es ->
        Printf.printf "\n\tMINIMIZE INPUT: %d%!\n" cid;
        Printf.printf "\n\tMINIMIZE LOG: %s%!\nCID_INPUT=%d\n%!" (Eh.show_commands es) cid;
        Oth.Assert.false_ "test: unexpected value"

  let post_comment t els =
    match !t with
    | Eh.Post_comment (els2, cmd_result) :: rest when els = els2 ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result : ('a, [ `Error ]) result Abb.Future.t :> ('a, [> `Error ]) result Abb.Future.t)
    | es ->
        let show = [%show: Eh.el list] in
        Printf.printf "\n\tPOST COMMENT INPUTS: %s%!\n" (show els);
        Printf.printf "\n\tPOST COMMENT LOG: %s%!\n" (Eh.show_commands es);
        Oth.Assert.false_ "test: unexpected value"

  let rendered_length _ els = CCList.fold_left (fun acc el -> acc + el.Eh.rendered_length) 0 els
  let dirspace el = el.Eh.dirspace
  let strategy el = el.Eh.strategy
  let compact el = { el with Eh.rendered_length = 1 }

  let compare_el el1 el2 =
    Cmp.compare (el1.Eh.is_success, el1.Eh.dirspace) (el2.Eh.is_success, el2.Eh.dirspace)

  let max_comment_length = 100
end

module Shared = struct
  let random_string n =
    let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" in
    let len = String.length chars in
    let result = Bytes.create n in
    for i = 0 to n - 1 do
      let random_index = Random.int len in
      Bytes.set result i chars.[random_index]
    done;
    Bytes.to_string result

  let random_el min_len max_len =
    let module C = Terrat_vcs_comment in
    let module D = Terrat_dirspace in
    let rendered_length = Random.int_in_range ~min:min_len ~max:max_len in
    let dirspace = D.{ dir = random_string 10; workspace = random_string 10 } in
    let is_success = Random.bool () in
    let strategy =
      match Random.int_in_range ~min:0 ~max:2 with
      | 0 -> C.Strategy.Append
      | _ -> C.Strategy.Append
    in
    Eh.{ rendered_length; dirspace; is_success; strategy }

  let create_el dir workspace is_success rendered_length strategy =
    let module D = Terrat_dirspace in
    let dirspace = D.{ dir; workspace } in
    Eh.{ rendered_length; dirspace; is_success; strategy }

  let gen_els n min max = CCList.init n (fun _ -> random_el min max)
end

module Make_wrapper = struct
  let run t els =
    let open Abb.Future.Infix_monad in
    let module Cm = Terrat_vcs_comment.Make (H) in
    Cm.run t els
    >>= function
    | Ok () -> (
        match !t with
        | [] -> Abb.Future.return (Ok ())
        | es ->
            Printf.printf "\n\tT: %s%!\n" (Eh.show_commands es);
            Oth.Assert.false_ "test: unexpected value")
    | Error e -> Abb.Future.return (Error e)
end

let test_basic =
  let _empty_els =
    Oth_abb.test ~desc:"Noop flow" ~name:"[Basic] Empty elements" (fun () ->
        let open Abb.Future.Infix_monad in
        let els = [] in
        let t = ref [] in
        Make_wrapper.run t els
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Basic] Empty elements: unexpected value")
  in
  let simple_post =
    Oth_abb.test ~name:"[Basic] Single post comment flow" (fun () ->
        let open Abb.Future.Infix_monad in
        (* TODO: Remove this random data gen *)
        let els = Shared.gen_els 1 10 20 in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let t = ref [ Eh.Post_comment (els, Ok cid1); Eh.Upsert_comment_id (els, cid1, Ok ()) ] in
        Make_wrapper.run t els
        >>= function
        | Ok _ -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Basic] Single post comment flow: unexpected value")
  in
  Oth_abb.parallel [ simple_post ]

let test_errors =
  let post_comment =
    Oth_abb.test
      ~desc:"Errors during post_comment are handled correctly"
      ~name:"[Error] Check error handling"
      (fun () ->
        let open Abb.Future.Infix_monad in
        (* TODO: Remove this random data gen *)
        let els = Shared.gen_els 1 10 20 in
        let t = ref [ Eh.Post_comment (els, Error `Error) ] in
        Make_wrapper.run t els
        >>= function
        | Ok _ -> Oth.Assert.false_ "[Error] Check error handling: unexpected value"
        | Error `Error -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Error] Check error handling: unexpected value")
  in
  Oth_abb.parallel [ post_comment ]

let test_append_strategy =
  let multiple_small =
    Oth_abb.test
      ~desc:
        "Given 3 elements with rendered length smaller than the ceiling, but that can't be \
         combined into a single cluster, we will generate 3 comments"
      ~name:"[Append] Multiple Small #1"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let len = H.max_comment_length - 1 in
        let st = C.Strategy.Append in
        let el1 = Shared.create_el "A" "A" false len st in
        let el2 = Shared.create_el "B" "B" true len st in
        let el3 = Shared.create_el "C" "C" false len st in
        let els = [ el1; el2; el3 ] in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let cid2 = API_id.next counter in
        let cid3 = API_id.next counter in
        let t =
          ref
            [
              Eh.Post_comment ([ el1 ], Ok cid1);
              Eh.Upsert_comment_id ([ el1 ], cid1, Ok ());
              Eh.Post_comment ([ el3 ], Ok cid2);
              Eh.Upsert_comment_id ([ el3 ], cid2, Ok ());
              Eh.Post_comment ([ el2 ], Ok cid3);
              Eh.Upsert_comment_id ([ el2 ], cid3, Ok ());
            ]
        in
        Make_wrapper.run t els
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Append] Multiple Small #1: unexpected value")
  in
  let multiple_big =
    Oth_abb.test
      ~desc:
        "Given 3 elements with rendered length bigger than the ceiling, but will be compacted to \
         fit into a single cluster, generate a single comment"
      ~name:"[Append] Multiple Big #1"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let len = H.max_comment_length + 1 in
        let st = C.Strategy.Append in
        let el1 = Shared.create_el "A" "A" false len st in
        let el2 = Shared.create_el "B" "B" true len st in
        let el3 = Shared.create_el "C" "C" false len st in
        let els = [ el1; el2; el3 ] in
        let elsc = CCList.map H.compact [ el1; el3; el2 ] in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let t = ref [ Eh.Post_comment (elsc, Ok cid1); Eh.Upsert_comment_id (elsc, cid1, Ok ()) ] in
        Make_wrapper.run t els
        >>= function
        | Ok _ -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Append] Multiple Big #1: unexpected value")
  in
  let multiple_mixed =
    Oth_abb.test
      ~desc:
        "Given 4 elements with mixed rendered lengths, get smaller comments into a single cluster, \
         compact the big ones and also fit them into a smaller cluster"
      ~name:"[Append] Mixed #1"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let half = H.max_comment_length / 2 in
        let st = C.Strategy.Append in
        let el1 = Shared.create_el "A" "A" false half st in
        let el2 = Shared.create_el "B" "B" true (half - 1) st in
        let el3 = Shared.create_el "C" "C" false (half - 1) st in
        let el4 = Shared.create_el "D" "D" true (H.max_comment_length + 1) st in
        let els = [ el1; el2; el3; el4 ] in
        let el4c = H.compact el4 in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let cid2 = API_id.next counter in
        let t =
          ref
            [
              Eh.Post_comment ([ el1; el3 ], Ok cid1);
              Eh.Upsert_comment_id ([ el1; el3 ], cid1, Ok ());
              Eh.Post_comment ([ el2; el4c ], Ok cid2);
              Eh.Upsert_comment_id ([ el2; el4c ], cid2, Ok ());
            ]
        in
        Make_wrapper.run t els
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Append] Mixed #1: unexpected value")
  in
  Oth_abb.parallel [ multiple_small; multiple_big; multiple_mixed ]

let test_delete_strategy =
  let multiple_small =
    Oth_abb.test
      ~desc:
        "Given 3 elements with rendered length smaller than the ceiling, but that can't be \
         combined into a single cluster, we will generate 3 comments"
      ~name:"[Delete] Multiple Small #1"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let len = H.max_comment_length - 1 in
        let st = C.Strategy.Delete in
        let el1 = Shared.create_el "A" "A" false len st in
        let el2 = Shared.create_el "B" "B" true len st in
        let el3 = Shared.create_el "C" "C" false len st in
        let els = [ el1; el2; el3 ] in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let cid2 = API_id.next counter in
        let cid3 = API_id.next counter in
        let t =
          ref
            [
              Eh.Query_comment_id (el1, Ok None);
              Eh.Query_comment_id (el2, Ok None);
              Eh.Query_comment_id (el3, Ok None);
              Eh.Post_comment ([ el1 ], Ok cid1);
              Eh.Upsert_comment_id ([ el1 ], cid1, Ok ());
              Eh.Post_comment ([ el3 ], Ok cid2);
              Eh.Upsert_comment_id ([ el3 ], cid2, Ok ());
              Eh.Post_comment ([ el2 ], Ok cid3);
              Eh.Upsert_comment_id ([ el2 ], cid3, Ok ());
            ]
        in
        Make_wrapper.run t els
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Delete] Multiple Small #1: unexpected value")
  in
  let multiple_big =
    Oth_abb.test
      ~desc:
        "Given 3 elements with rendered length bigger than the ceiling, but will be compacted to \
         fit into a single cluster, generate a single comment"
      ~name:"[Delete] Multiple Big #1"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let len = H.max_comment_length + 1 in
        let st = C.Strategy.Delete in
        let el1 = Shared.create_el "A" "A" false len st in
        let el2 = Shared.create_el "B" "B" true len st in
        let el3 = Shared.create_el "C" "C" false len st in
        let els = [ el1; el2; el3 ] in
        let elsc = CCList.map H.compact [ el1; el3; el2 ] in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let t =
          ref
            [
              Eh.Query_comment_id (el1, Ok None);
              Eh.Query_comment_id (el2, Ok None);
              Eh.Query_comment_id (el3, Ok None);
              Eh.Post_comment (elsc, Ok cid1);
              Eh.Upsert_comment_id (elsc, cid1, Ok ());
            ]
        in
        Make_wrapper.run t els
        >>= function
        | Ok _ -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Delete] Multiple Big #1: unexpected value")
  in
  let multiple_mixed =
    Oth_abb.test
      ~desc:
        "Given 4 elements with mixed rendered lengths, get smaller comments into a single cluster, \
         compact the big ones and also fit them into a smaller cluster"
      ~name:"[Delete] Mixed #1"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let half = H.max_comment_length / 2 in
        let st = C.Strategy.Delete in
        let el1 = Shared.create_el "A" "A" false half st in
        let el2 = Shared.create_el "B" "B" true (half - 1) st in
        let el3 = Shared.create_el "C" "C" false (half - 1) st in
        let el4 = Shared.create_el "D" "D" true (H.max_comment_length + 1) st in
        let els = [ el1; el2; el3; el4 ] in
        let el4c = H.compact el4 in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let cid2 = API_id.next counter in
        let t =
          ref
            [
              Eh.Query_comment_id (el1, Ok None);
              Eh.Query_comment_id (el2, Ok None);
              Eh.Query_comment_id (el3, Ok None);
              Eh.Query_comment_id (el4, Ok None);
              Eh.Post_comment ([ el1; el3 ], Ok cid1);
              Eh.Upsert_comment_id ([ el1; el3 ], cid1, Ok ());
              Eh.Post_comment ([ el2; el4c ], Ok cid2);
              Eh.Upsert_comment_id ([ el2; el4c ], cid2, Ok ());
            ]
        in
        Make_wrapper.run t els
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Delete] Mixed #1: unexpected value")
  in
  Oth_abb.parallel [ multiple_small; multiple_big; multiple_mixed ]

let test_minimize_strategy =
  let multiple_small =
    Oth_abb.test
      ~desc:
        "Given 3 elements with rendered length smaller than the ceiling, but that can't be \
         combined into a single cluster, we will generate 3 comments"
      ~name:"[Minimize] Multiple Small #1"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let len = H.max_comment_length - 1 in
        let st = C.Strategy.Minimize in
        let el1 = Shared.create_el "A" "A" false len st in
        let el2 = Shared.create_el "B" "B" true len st in
        let el3 = Shared.create_el "C" "C" false len st in
        let els = [ el1; el2; el3 ] in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let cid2 = API_id.next counter in
        let cid3 = API_id.next counter in
        let t =
          ref
            [
              Eh.Query_comment_id (el1, Ok None);
              Eh.Query_comment_id (el2, Ok None);
              Eh.Query_comment_id (el3, Ok None);
              Eh.Post_comment ([ el1 ], Ok cid1);
              Eh.Upsert_comment_id ([ el1 ], cid1, Ok ());
              Eh.Post_comment ([ el3 ], Ok cid3);
              Eh.Upsert_comment_id ([ el3 ], cid3, Ok ());
              Eh.Post_comment ([ el2 ], Ok cid2);
              Eh.Upsert_comment_id ([ el2 ], cid2, Ok ());
            ]
        in
        Make_wrapper.run t els
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Minimize] Multiple Small #1: unexpected value")
  in
  let multiple_small_with_two_groupings =
    Oth_abb.test
      ~desc:
        "Given 4 elements with rendered length smaller than the ceiling, but that can't be \
         combined into a single cluster, we will generate 2 groupings that will become separate \
         comments."
      ~name:"[Minimize] Multiple Small #2"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let st = C.Strategy.Minimize in
        let el1 = Shared.create_el "A" "A" false 30 st in
        let el2 = Shared.create_el "B" "B" false 30 st in
        let el3 = Shared.create_el "C" "C" false 30 st in
        let el4 = Shared.create_el "D" "D" false 30 st in
        let els = [ el1; el2; el3; el4 ] in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let cid2 = API_id.next counter in
        let t =
          ref
            [
              Eh.Query_comment_id (el1, Ok None);
              Eh.Query_comment_id (el2, Ok None);
              Eh.Query_comment_id (el3, Ok None);
              Eh.Query_comment_id (el4, Ok None);
              Eh.Post_comment ([ el1; el2; el3 ], Ok cid1);
              Eh.Upsert_comment_id ([ el1; el2; el3 ], cid1, Ok ());
              Eh.Post_comment ([ el4 ], Ok cid2);
              Eh.Upsert_comment_id ([ el4 ], cid2, Ok ());
            ]
        in
        Make_wrapper.run t els
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Minimize] Multiple Small #2: unexpected value")
  in
  let multiple_small_with_old_comment =
    Oth_abb.test
      ~desc:
        "Given 2 elements with rendered length smaller than the ceiling, but that can't be \
         combined into a single cluster, and 1 comment that is an older version of the first one, \
         We'll generate two new comments and minimize the old one."
      ~name:"[Minimize] Multiple Small #3"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let len = H.max_comment_length - 1 in
        let st = C.Strategy.Minimize in
        let el1 = Shared.create_el "A" "A" false len st in
        let el2 = Shared.create_el "B" "B" true len st in
        let els1 = [ el1; el2 ] in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let cid2 = API_id.next counter in
        let t1 =
          ref
            [
              Eh.Query_comment_id (el1, Ok None);
              Eh.Query_comment_id (el2, Ok None);
              Eh.Post_comment ([ el1 ], Ok cid1);
              Eh.Upsert_comment_id ([ el1 ], cid1, Ok ());
              Eh.Post_comment ([ el2 ], Ok cid2);
              Eh.Upsert_comment_id ([ el2 ], cid2, Ok ());
            ]
        in
        Make_wrapper.run t1 els1
        >>= function
        | Ok () -> (
            (* Dirspace A/A is re-run and now evaluates to true *)
            let el3 = Shared.create_el "A" "A" true len st in
            let els2 = [ el3 ] in
            let cid3 = API_id.next counter in
            let t2 =
              ref
                [
                  (* Check that C1 is already posted, minimize it *)
                  Eh.Query_comment_id (el3, Ok (Some cid1));
                  Eh.Minimize_comment (cid1, Ok ());
                  Eh.Query_els_for_comment_id (cid1, Ok []);
                  Eh.Post_comment ([ el3 ], Ok cid3);
                  Eh.Upsert_comment_id ([ el3 ], cid3, Ok ());
                ]
            in
            Make_wrapper.run t2 els2
            >>= function
            | Ok () -> Abb.Future.return ()
            | Error _ -> Oth.Assert.false_ "[Minimize] Multiple Small #3: unexpected value")
        | Error _ -> Oth.Assert.false_ "[Minimize] Multiple Small #3: unexpected value")
  in
  let multiple_big =
    Oth_abb.test
      ~desc:
        "Given 3 elements with rendered length bigger than the ceiling, but that will be compacted \
         to fit into a single cluster, generate a single comment"
      ~name:"[Minimize] Multiple Big #1"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let len = H.max_comment_length + 1 in
        let st = C.Strategy.Minimize in
        let el1 = Shared.create_el "A" "A" false len st in
        let el2 = Shared.create_el "B" "B" true len st in
        let el3 = Shared.create_el "C" "C" false len st in
        let els = [ el1; el2; el3 ] in
        let elsc = CCList.map H.compact [ el1; el3; el2 ] in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let t =
          ref
            [
              Eh.Query_comment_id (el1, Ok None);
              Eh.Query_comment_id (el2, Ok None);
              Eh.Query_comment_id (el3, Ok None);
              Eh.Post_comment (elsc, Ok cid1);
              Eh.Upsert_comment_id (elsc, cid1, Ok ());
            ]
        in
        Make_wrapper.run t els
        >>= function
        | Ok _ -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Minimize] Multiple Big #1: unexpected value")
  in
  let multiple_big_with_old_comment =
    Oth_abb.test
      ~desc:
        "Given 3 elements with rendered length bigger than the ceiling, but that will be compacted \
         to fit into a single cluster, generate a single comment"
      ~name:"[Minimize] Multiple Big #2"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let len = H.max_comment_length + 1 in
        let st = C.Strategy.Minimize in
        let el1 = Shared.create_el "A" "A" false len st in
        let el2 = Shared.create_el "B" "B" true len st in
        let el3 = Shared.create_el "C" "C" false len st in
        let els1 = [ el1; el2; el3 ] in
        let elsc = CCList.map H.compact [ el1; el3; el2 ] in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let t1 =
          ref
            [
              Eh.Query_comment_id (el1, Ok None);
              Eh.Query_comment_id (el2, Ok None);
              Eh.Query_comment_id (el3, Ok None);
              Eh.Post_comment (elsc, Ok cid1);
              Eh.Upsert_comment_id (elsc, cid1, Ok ());
            ]
        in
        Make_wrapper.run t1 els1
        >>= function
        | Ok () -> (
            (* Dirspaces A/A and C/C are re-run and now evaluate to true *)
            let el1t = Shared.create_el "A" "A" true len st in
            let el3t = Shared.create_el "C" "C" true len st in
            let els2 = [ el1t; el3t ] in
            let el2c = H.compact el2 in
            let els_expected = [ el1t; el2; el3t ] in
            let els2c = CCList.map H.compact els_expected in
            let cid2 = API_id.next counter in
            let t2 =
              ref
                [
                  Eh.Query_comment_id (el1t, Ok (Some cid1));
                  Eh.Query_comment_id (el3t, Ok (Some cid1));
                  Eh.Minimize_comment (cid1, Ok ());
                  Eh.Query_els_for_comment_id (cid1, Ok [ el2c ]);
                  Eh.Post_comment (els2c, Ok cid2);
                  Eh.Upsert_comment_id (els2c, cid2, Ok ());
                ]
            in
            Make_wrapper.run t2 els2
            >>= function
            | Ok () -> Abb.Future.return ()
            | Error _ -> Oth.Assert.false_ "[Minimize] Multiple Big #2: unexpected value")
        | Error _ -> Oth.Assert.false_ "[Minimize] Multiple Big #2: unexpected value")
  in
  let multiple_mixed =
    Oth_abb.test
      ~desc:
        "Given 4 elements with mixed rendered lengths, get smaller comments into a single cluster, \
         compact the big ones and also fit them into a smaller cluster"
      ~name:"[Minimize] Mixed #1"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module C = Terrat_vcs_comment in
        let half = H.max_comment_length / 2 in
        let st = C.Strategy.Delete in
        let el1 = Shared.create_el "A" "A" false half st in
        let el2 = Shared.create_el "B" "B" true (half - 1) st in
        let el3 = Shared.create_el "C" "C" false (half - 1) st in
        let el4 = Shared.create_el "D" "D" true (H.max_comment_length + 1) st in
        let els = [ el1; el2; el3; el4 ] in
        let el4c = H.compact el4 in
        let counter = API_id.create 0 in
        let cid1 = API_id.next counter in
        let cid2 = API_id.next counter in
        let t =
          ref
            [
              Eh.Query_comment_id (el1, Ok None);
              Eh.Query_comment_id (el2, Ok None);
              Eh.Query_comment_id (el3, Ok None);
              Eh.Query_comment_id (el4, Ok None);
              Eh.Post_comment ([ el1; el3 ], Ok cid1);
              Eh.Upsert_comment_id ([ el1; el3 ], cid1, Ok ());
              Eh.Post_comment ([ el2; el4c ], Ok cid2);
              Eh.Upsert_comment_id ([ el2; el4c ], cid2, Ok ());
            ]
        in
        Make_wrapper.run t els
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Minimize] Mixed #1: unexpected value")
  in
  Oth_abb.parallel
    [
      multiple_small;
      multiple_small_with_two_groupings;
      multiple_small_with_old_comment;
      multiple_big;
      multiple_big_with_old_comment;
      multiple_mixed;
    ]

(* Scripted-queue harness for Terrat_vcs_comment_unified, analogous to
   [Eh]/[H] above but with the unified comment command set. *)
module Ehu = struct
  type el = {
    dirspace : Terrat_dirspace.t;
    status : Terrat_vcs_comment_unified.Status.t;
    has_changes : bool;
    size : int;
  }
  [@@deriving ord, show]

  type comment_id = int [@@deriving ord, show]

  type t =
    | Query_els of (el list, [ `Error ]) result
    | Query_comment_id of (comment_id option, [ `Error ]) result
    | Update_comment of comment_id * string * (unit, [ `Not_found | `Error ]) result
    | Post_comment of string * (comment_id, [ `Error ]) result
    | Upsert_comment_id of comment_id * (unit, [ `Error ]) result
  [@@deriving show]

  type commands = t list [@@deriving show]
end

module Hu = struct
  module U = Terrat_vcs_comment_unified

  type t = Ehu.commands ref
  type el = Ehu.el [@@deriving ord, show]
  type comment_id = Ehu.comment_id [@@deriving ord, show]

  let table_row_cost = 2

  let query_els t =
    match !t with
    | Ehu.Query_els cmd_result :: rest ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result : ('a, [ `Error ]) result Abb.Future.t :> ('a, [> `Error ]) result Abb.Future.t)
    | es ->
        Printf.printf "\n\tQUERY ELS LOG: %s%!\n" (Ehu.show_commands es);
        Oth.Assert.false_ "test: unexpected value"

  let query_comment_id t =
    match !t with
    | Ehu.Query_comment_id cmd_result :: rest ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result : ('a, [ `Error ]) result Abb.Future.t :> ('a, [> `Error ]) result Abb.Future.t)
    | es ->
        Printf.printf "\n\tQUERY COMMENT_ID LOG: %s%!\n" (Ehu.show_commands es);
        Oth.Assert.false_ "test: unexpected value"

  let tier_label = function
    | U.Tier.Details n -> Printf.sprintf "details(%d)" n
    | U.Tier.Table -> "table"
    | U.Tier.Truncated n -> Printf.sprintf "truncated(%d)" n

  (* Pure renderer.  The body records the tier and the element order so tests
     can assert on both, and its length is a deterministic function of the
     tier and the element sizes so tests can force tier selection via [size]
     and [max_comment_length]. *)
  let render _ tier els =
    let shown =
      match tier with
      | U.Tier.Details _ | U.Tier.Table -> els
      | U.Tier.Truncated n -> CCList.take n els
    in
    let order =
      CCString.concat "," (CCList.map (fun el -> el.Ehu.dirspace.Terrat_dirspace.dir) shown)
    in
    let content_length =
      match tier with
      | U.Tier.Details n ->
          CCList.fold_left (fun acc el -> acc + el.Ehu.size) 0 (CCList.take n els)
          + (CCList.length els * table_row_cost)
      | U.Tier.Table -> CCList.length els * table_row_cost
      | U.Tier.Truncated _ -> CCList.length shown * table_row_cost
    in
    Printf.sprintf "%s|%s|%s" (tier_label tier) order (CCString.make content_length 'x')

  let update_comment t cid body =
    match !t with
    | Ehu.Update_comment (cid2, body2, cmd_result) :: rest when cid = cid2 && body = body2 ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result
          : ('a, [ `Not_found | `Error ]) result Abb.Future.t
          :> ('a, [> `Not_found | `Error ]) result Abb.Future.t)
    | es ->
        Printf.printf "\n\tUPDATE COMMENT INPUT: %d %s%!\n" cid body;
        Printf.printf "\n\tUPDATE COMMENT LOG: %s%!\n" (Ehu.show_commands es);
        Oth.Assert.false_ "test: unexpected value"

  let post_comment t body =
    match !t with
    | Ehu.Post_comment (body2, cmd_result) :: rest when body = body2 ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result : ('a, [ `Error ]) result Abb.Future.t :> ('a, [> `Error ]) result Abb.Future.t)
    | es ->
        Printf.printf "\n\tPOST COMMENT INPUT: %s%!\n" body;
        Printf.printf "\n\tPOST COMMENT LOG: %s%!\n" (Ehu.show_commands es);
        Oth.Assert.false_ "test: unexpected value"

  let upsert_comment_id t cid =
    match !t with
    | Ehu.Upsert_comment_id (cid2, cmd_result) :: rest when cid = cid2 ->
        t := rest;
        let abb_result = Abb.Future.return cmd_result in
        (abb_result : ('a, [ `Error ]) result Abb.Future.t :> ('a, [> `Error ]) result Abb.Future.t)
    | es ->
        Printf.printf "\n\tUPSERT INPUT: %d%!\n" cid;
        Printf.printf "\n\tUPSERT LOG: %s%!\n" (Ehu.show_commands es);
        Oth.Assert.false_ "test: unexpected value"

  let dirspace el = el.Ehu.dirspace
  let status el = el.Ehu.status
  let has_changes el = el.Ehu.has_changes
  let max_comment_length = 100
end

module Shared_unified = struct
  let create_el dir status has_changes size =
    let module D = Terrat_dirspace in
    { Ehu.dirspace = D.{ dir; workspace = "default" }; status; has_changes; size }

  (* [render] is pure so the expected body is just the renderer applied to the
     expected tier and the expected sorted order. *)
  let expected_body tier els = Hu.render (ref []) tier els
end

module Make_unified_wrapper = struct
  let run t =
    let open Abb.Future.Infix_monad in
    let module Cm = Terrat_vcs_comment_unified.Make (Hu) in
    Cm.run t
    >>= function
    | Ok () -> (
        match !t with
        | [] -> Abbs_future_combinators.return_ok ()
        | es ->
            Printf.printf "\n\tT: %s%!\n" (Ehu.show_commands es);
            Oth.Assert.false_ "test: unexpected value")
    | Error e -> Abbs_future_combinators.return_err e
end

let test_unified_basic =
  let empty_els =
    Oth_abb.test
      ~desc:"No elements means the comment is left untouched and nothing else is called"
      ~name:"[Unified] Empty elements"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let t = ref [ Ehu.Query_els (Ok []) ] in
        Make_unified_wrapper.run t
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Unified] Empty elements: unexpected value")
  in
  let first_post =
    Oth_abb.test
      ~desc:"No tracked comment yet: post a fresh comment and record its id"
      ~name:"[Unified] First publish posts and upserts"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module U = Terrat_vcs_comment_unified in
        let el1 = Shared_unified.create_el "A" U.Status.Planned true 10 in
        let els = [ el1 ] in
        let body = Shared_unified.expected_body (U.Tier.Details 1) els in
        let t =
          ref
            [
              Ehu.Query_els (Ok els);
              Ehu.Query_comment_id (Ok None);
              Ehu.Post_comment (body, Ok 1);
              Ehu.Upsert_comment_id (1, Ok ());
            ]
        in
        Make_unified_wrapper.run t
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Unified] First publish posts and upserts: unexpected value")
  in
  let existing_update =
    Oth_abb.test
      ~desc:"A tracked comment is updated in place with no post or upsert"
      ~name:"[Unified] Existing comment is updated"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module U = Terrat_vcs_comment_unified in
        let el1 = Shared_unified.create_el "A" U.Status.Planned true 10 in
        let els = [ el1 ] in
        let body = Shared_unified.expected_body (U.Tier.Details 1) els in
        let t =
          ref
            [
              Ehu.Query_els (Ok els);
              Ehu.Query_comment_id (Ok (Some 42));
              Ehu.Update_comment (42, body, Ok ());
            ]
        in
        Make_unified_wrapper.run t
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Unified] Existing comment is updated: unexpected value")
  in
  Oth_abb.parallel [ empty_els; first_post; existing_update ]

let test_unified_errors =
  let update_not_found =
    Oth_abb.test
      ~desc:"A tracked comment that was deleted falls back to posting a fresh comment"
      ~name:"[Unified] Update not found falls back to post"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module U = Terrat_vcs_comment_unified in
        let el1 = Shared_unified.create_el "A" U.Status.Planned true 10 in
        let els = [ el1 ] in
        let body = Shared_unified.expected_body (U.Tier.Details 1) els in
        let t =
          ref
            [
              Ehu.Query_els (Ok els);
              Ehu.Query_comment_id (Ok (Some 42));
              Ehu.Update_comment (42, body, Error `Not_found);
              Ehu.Post_comment (body, Ok 43);
              Ehu.Upsert_comment_id (43, Ok ());
            ]
        in
        Make_unified_wrapper.run t
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ ->
            Oth.Assert.false_ "[Unified] Update not found falls back to post: unexpected value")
  in
  let update_error =
    Oth_abb.test
      ~desc:"An error during update_comment is propagated"
      ~name:"[Unified] Update error is propagated"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module U = Terrat_vcs_comment_unified in
        let el1 = Shared_unified.create_el "A" U.Status.Planned true 10 in
        let els = [ el1 ] in
        let body = Shared_unified.expected_body (U.Tier.Details 1) els in
        let t =
          ref
            [
              Ehu.Query_els (Ok els);
              Ehu.Query_comment_id (Ok (Some 42));
              Ehu.Update_comment (42, body, Error `Error);
            ]
        in
        Make_unified_wrapper.run t
        >>= function
        | Ok _ -> Oth.Assert.false_ "[Unified] Update error is propagated: unexpected value"
        | Error `Error ->
            Oth.Assert.List.empty !t;
            Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Unified] Update error is propagated: unexpected value")
  in
  Oth_abb.parallel [ update_not_found; update_error ]

let test_unified_sorting =
  let mixed_order =
    Oth_abb.test
      ~desc:
        "Elements arrive at render sorted by status rank, then has_changes (changes first), then \
         dirspace, regardless of input order"
      ~name:"[Unified] Sorting"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module U = Terrat_vcs_comment_unified in
        let el_applied = Shared_unified.create_el "a" U.Status.Applied false 5 in
        let el_failed = Shared_unified.create_el "z" U.Status.Failed true 5 in
        let el_planned_changes = Shared_unified.create_el "m" U.Status.Planned true 5 in
        let el_planned_no_changes = Shared_unified.create_el "b" U.Status.Planned false 5 in
        let el_pending = Shared_unified.create_el "q" U.Status.Pending false 5 in
        let els =
          [ el_applied; el_planned_no_changes; el_pending; el_failed; el_planned_changes ]
        in
        (* Failed first, then planned with changes before planned without
           (despite "b" < "m"), then pending, then applied. *)
        let sorted =
          [ el_failed; el_planned_changes; el_planned_no_changes; el_pending; el_applied ]
        in
        let body = Shared_unified.expected_body (U.Tier.Details 5) sorted in
        let t =
          ref
            [
              Ehu.Query_els (Ok els);
              Ehu.Query_comment_id (Ok None);
              Ehu.Post_comment (body, Ok 1);
              Ehu.Upsert_comment_id (1, Ok ());
            ]
        in
        Make_unified_wrapper.run t
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Unified] Sorting: unexpected value")
  in
  Oth_abb.parallel [ mixed_order ]

let test_unified_tiers =
  let table_tier =
    Oth_abb.test
      ~desc:"Oversized details force degradation to the table tier"
      ~name:"[Unified] Tier degradation to table"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module U = Terrat_vcs_comment_unified in
        let el1 = Shared_unified.create_el "a" U.Status.Planned true 40 in
        let el2 = Shared_unified.create_el "b" U.Status.Planned true 40 in
        let el3 = Shared_unified.create_el "c" U.Status.Planned true 40 in
        let els = [ el1; el2; el3 ] in
        (* Details 3 renders 3 * 40 + 3 * table_row_cost > max_comment_length,
           so the table tier is chosen. *)
        let body = Shared_unified.expected_body U.Tier.Table els in
        let t =
          ref
            [
              Ehu.Query_els (Ok els);
              Ehu.Query_comment_id (Ok None);
              Ehu.Post_comment (body, Ok 1);
              Ehu.Upsert_comment_id (1, Ok ());
            ]
        in
        Make_unified_wrapper.run t
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Unified] Tier degradation to table: unexpected value")
  in
  let details_five_tier =
    Oth_abb.test
      ~desc:"More than 5 elements that do not all fit degrade to details for the first 5"
      ~name:"[Unified] Tier degradation to details 5"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module U = Terrat_vcs_comment_unified in
        let el1 = Shared_unified.create_el "a" U.Status.Planned true 10 in
        let el2 = Shared_unified.create_el "b" U.Status.Planned true 10 in
        let el3 = Shared_unified.create_el "c" U.Status.Planned true 10 in
        let el4 = Shared_unified.create_el "d" U.Status.Planned true 10 in
        let el5 = Shared_unified.create_el "e" U.Status.Planned true 10 in
        let el6 = Shared_unified.create_el "f" U.Status.Planned true 60 in
        let els = [ el1; el2; el3; el4; el5; el6 ] in
        (* Details 6 includes the oversized 6th element and does not fit;
           Details 5 drops its details and does. *)
        let body = Shared_unified.expected_body (U.Tier.Details 5) els in
        let t =
          ref
            [
              Ehu.Query_els (Ok els);
              Ehu.Query_comment_id (Ok None);
              Ehu.Post_comment (body, Ok 1);
              Ehu.Upsert_comment_id (1, Ok ());
            ]
        in
        Make_unified_wrapper.run t
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Unified] Tier degradation to details 5: unexpected value")
  in
  let truncated_tier =
    Oth_abb.test
      ~desc:
        "When even the full table does not fit, degradation ends at the unconditional truncated \
         tier"
      ~name:"[Unified] Tier degradation to truncated"
      (fun () ->
        let open Abb.Future.Infix_monad in
        let module U = Terrat_vcs_comment_unified in
        let els =
          CCList.init 60 (fun i ->
              Shared_unified.create_el (Printf.sprintf "d%02d" i) U.Status.Planned true 0)
        in
        (* 60 table rows exceed max_comment_length, as do the first 50, so the
           final Truncated 10 tier is used. *)
        let body = Shared_unified.expected_body (U.Tier.Truncated 10) els in
        let t =
          ref
            [
              Ehu.Query_els (Ok els);
              Ehu.Query_comment_id (Ok None);
              Ehu.Post_comment (body, Ok 1);
              Ehu.Upsert_comment_id (1, Ok ());
            ]
        in
        Make_unified_wrapper.run t
        >>= function
        | Ok () -> Abb.Future.return ()
        | Error _ -> Oth.Assert.false_ "[Unified] Tier degradation to truncated: unexpected value")
  in
  Oth_abb.parallel [ table_tier; details_five_tier; truncated_tier ]

let test =
  Oth_abb.(
    parallel
      [
        test_basic;
        test_errors;
        test_append_strategy;
        test_delete_strategy;
        test_minimize_strategy;
        test_unified_basic;
        test_unified_errors;
        test_unified_sorting;
        test_unified_tiers;
      ])

let () =
  Random.self_init ();
  Oth_abb.run
    ~file:__FILE__
    ~setup:(fun () -> Abb.Future.return (Ok ()))
    ~teardown:(fun () -> Abb.Future.return ())
    (fun () -> test)
