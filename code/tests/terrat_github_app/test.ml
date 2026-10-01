(* When a process decides the App it runs is no longer the stored one. The rule
   covers the four writes the console can make. *)

module App = Terrat_github_app

let show = function
  | Some `Created -> "Created"
  | Some `Removed -> "Removed"
  | Some `Replaced -> "Replaced"
  | Some `Rotated -> "Rotated"
  | None -> "none"

(* The name is in the compared value, so a failure says which of the cases broke
   rather than only expected and actual. *)
let assert_stale ~name ~expected ~loaded stored =
  Oth.Assert.Eq.string
    ~expected:(name ^ ": " ^ show expected)
    ~actual:(name ^ ": " ^ show (App.stale ~loaded stored))

let test_rules =
  Oth.test ~name:"a process restarts exactly when the stored App is not the one it runs" (fun _ ->
      let a = App.Tests.token ~app_id:1L "a" in
      let a_rotated = App.Tests.token ~app_id:1L "a2" in
      let b = App.Tests.token ~app_id:2L "b" in
      (* Steady states: nothing stored and none running, or the same App both
         sides. *)
      assert_stale ~name:"idle" ~expected:None ~loaded:None None;
      assert_stale ~name:"same" ~expected:None ~loaded:(Some a) (Some a);
      (* The four writes. *)
      assert_stale ~name:"create" ~expected:(Some `Created) ~loaded:None (Some a);
      assert_stale ~name:"replace" ~expected:(Some `Replaced) ~loaded:(Some a) (Some b);
      (* Same App, other credentials: a rotated key, which reads differently in
         the log of a restart nobody asked for. *)
      assert_stale ~name:"rotate" ~expected:(Some `Rotated) ~loaded:(Some a) (Some a_rotated);
      assert_stale ~name:"delete" ~expected:(Some `Removed) ~loaded:(Some a) None;
      ())

let test = Oth.serial [ test_rules ]
let () = Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
