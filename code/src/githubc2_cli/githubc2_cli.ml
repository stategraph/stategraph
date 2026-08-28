let run () =
  let open Abbs_future_combinators.Infix_result_monad in
  let client = Githubc2_abb.create ~user_agent:"Gihubc2 Test Client" (`Token Sys.argv.(1)) in
  Githubc2_abb.collect_all
    client
    Githubc2_activity.List_repos_starred_by_authenticated_user.(make (Parameters.make ()))
  >>| fun repos ->
  print_endline (Githubc2_activity.List_repos_starred_by_authenticated_user.Responses.OK.show repos);
  Printf.printf "Num = %d\n" (CCList.length repos);
  ()
(* let open Abbs_future_combinators.Infix_result_monad in
 * Ghc.Schema.create ()
 * >>= fun schema ->
 * Ghc.create schema (`Token Sys.argv.(1))
 * >>= fun ghc ->
 * print_endline "Requesting repos";
 * Ghc.collect_all ghc (Ghc.starred ghc)
 * (\* Ghc.call ghc (Ghc.user_orgs ghc)
 *  * >>= fun orgs ->
 *  * Printf.printf "Num orgs = %d\n" (List.length (Ghc.Response.value orgs));
 *  * List_result.map
 *  *   ~f:(fun org -> Ghc.collect_all ghc (Ghc.Response.Org.repos_url org))
 *  *   (Ghc.Response.value orgs) *\)
 * >>= fun repos ->
 * print_endline "Requesting issues";
 * (\* let repos = repos |> List.map Ghc.Response.value |> List.concat in *\)
 * Printf.printf "Num repos = %d\n" (List.length repos);
 * List_result.map
 *   ~f:(fun repo ->
 *     Printf.printf "Loading issues for = %s\n%!" (Ghc.Response.Repo.name repo);
 *     Ghc.collect_all ghc (Ghc.Response.Repo.issues_url repo))
 *   repos
 * >>= fun issues ->
 * let issues = List.concat issues in
 * Printf.printf "Num issues = %d\n" (List.length issues);
 * Abb.Future.return (Ok ()) *)

let main () =
  match Abb.Scheduler.run_with_state run with
  | `Det (Ok _) -> ()
  | `Det (Error `Error) ->
      Printf.eprintf "Request_failed\n";
      exit 1
  | `Det (Error (#Githubc2_abb.call_err as err)) ->
      Printf.eprintf "Request failed: %s\n" (Githubc2_abb.show_call_err err);
      exit 1
  | `Aborted ->
      Printf.eprintf "Aborted";
      exit 2
  | `Exn (exn, bt_opt) ->
      Printf.eprintf "Exn = %s\n" (Printexc.to_string exn);
      CCOption.iter (fun bt -> Printf.eprintf "%s\n" (Printexc.raw_backtrace_to_string bt)) bt_opt;
      exit 3

let () = main ()
