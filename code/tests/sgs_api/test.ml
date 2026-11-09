(* The query parameters given to the handler of [route], or [None] if [route] does not match a GET
   of [uri]. *)
let match_query route uri =
  Brtl_rtng.Route.match_ctx
    ~default:(fun _ -> None)
    [ route ]
    (Brtl_ctx.set_body "" (Brtl_ctx.create "127.0.0.1" (Brtl_ctx.Request.make (Uri.of_string uri))))

let match_users_list =
  match_query
    Brtl_rtng.Route.(
      Sgs_api_users.List.route (rel / "users")
      --> fun type_ search cursor limit -> Some (type_, search, cursor, limit))

let match_users_detail =
  match_query
    Brtl_rtng.Route.(Sgs_api_users.Detail.route (rel / "users" / "detail") --> CCOption.return)

(* [Sgs_service_users_ep_list.run] takes [type_ search cursor limit]. The handler gets the query
   parameters in the order of the parameters in api.json, and the first three are all
   [string option]: if api.json changes their order, this test fails instead of the handler
   silently getting them swapped. *)
let test_list_params_order =
  Oth.test ~name:"Users list query parameters keep the order of the handler arguments" (fun _ ->
      let type_, search, cursor, _ =
        Oth.Assert.some (match_users_list "/users?type=t&search=s&cursor=c")
      in
      Oth.Assert.Eq.string_option ~expected:(Some "t") ~actual:type_;
      Oth.Assert.Eq.string_option ~expected:(Some "s") ~actual:search;
      Oth.Assert.Eq.string_option ~expected:(Some "c") ~actual:cursor)

let test_list_limit_default =
  Oth.test ~name:"Users list limit is 25 when it is absent" (fun _ ->
      let _, _, _, limit = Oth.Assert.some (match_users_list "/users") in
      Oth.Assert.Eq.int ~expected:25 ~actual:limit;
      let _, _, _, limit = Oth.Assert.some (match_users_list "/users?limit=5") in
      Oth.Assert.Eq.int ~expected:5 ~actual:limit)

let test_detail_user_id_is_a_uuid =
  Oth.test ~name:"Users detail matches only a UUID user_id" (fun _ ->
      let id = "c0708dee-4e89-470a-a4b8-83cbc4051327" in
      Oth.Assert.eq
        ~eq:Uuidm.equal
        ~pp:Uuidm.pp
        (Oth.Assert.some (Uuidm.of_string id))
        (Oth.Assert.some (match_users_detail ("/users/detail?user_id=" ^ id)));
      Oth.Assert.none (match_users_detail "/users/detail?user_id=not-a-uuid");
      Oth.Assert.none (match_users_detail "/users/detail"))

let () =
  Oth.run
    ~file:__FILE__
    ~setup:(fun () -> Ok ())
    ~teardown:(fun _ -> ())
    (fun _ ->
      Oth.parallel
        [ test_list_params_order; test_list_limit_default; test_detail_user_id_is_a_uuid ])
