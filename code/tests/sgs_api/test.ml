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
      Sgs_api_users.List.route ()
      --> fun type_ search cursor limit -> Some (type_, search, cursor, limit))

let match_users_detail =
  match_query Brtl_rtng.Route.(Sgs_api_users.Detail.route () --> CCOption.return)

(* [Sgs_service_users_ep_list.run] takes [type_ search cursor limit]. The handler gets the query
   parameters in the order of the parameters in api.json: [type_] is the user-type enum and the next
   two are [string option]. If api.json changes their order, this test fails instead of the handler
   silently getting them swapped. *)
let test_list_params_order =
  Oth.test ~name:"Users list query parameters keep the order of the handler arguments" (fun _ ->
      let type_, search, cursor, _ =
        Oth.Assert.some (match_users_list "/api/v1/users?type=user&search=s&cursor=c")
      in
      Oth.Assert.Eq.option
        ~eq:Sgs_api_components.User_type.equal
        ~pp:Sgs_api_components.User_type.pp
        ~expected:(Some `User)
        ~actual:type_;
      Oth.Assert.Eq.string_option ~expected:(Some "s") ~actual:search;
      Oth.Assert.Eq.string_option ~expected:(Some "c") ~actual:cursor)

let test_list_type_accepts_only_user_type_enum =
  Oth.test ~name:"Users list route accepts only declared user types" (fun _ ->
      Oth.Assert.none (match_users_list "/api/v1/users?type=usr");
      Oth.Assert.none (match_users_list "/api/v1/users?type=User");
      let type_, _, _, _ = Oth.Assert.some (match_users_list "/api/v1/users?type=api") in
      Oth.Assert.Eq.option
        ~eq:Sgs_api_components.User_type.equal
        ~pp:Sgs_api_components.User_type.pp
        ~expected:(Some `Api)
        ~actual:type_)

let test_list_limit_default =
  Oth.test ~name:"Users list limit is 25 when it is absent" (fun _ ->
      let _, _, _, limit = Oth.Assert.some (match_users_list "/api/v1/users") in
      Oth.Assert.Eq.int ~expected:25 ~actual:limit;
      let _, _, _, limit = Oth.Assert.some (match_users_list "/api/v1/users?limit=5") in
      Oth.Assert.Eq.int ~expected:5 ~actual:limit)

let test_detail_user_id_is_a_uuid =
  Oth.test ~name:"Users detail matches only a UUID user_id" (fun _ ->
      let id = "c0708dee-4e89-470a-a4b8-83cbc4051327" in
      Oth.Assert.eq
        ~eq:Uuidm.equal
        ~pp:Uuidm.pp
        (Oth.Assert.some (Uuidm.of_string id))
        (Oth.Assert.some (match_users_detail ("/api/v1/users/detail?user_id=" ^ id)));
      Oth.Assert.none (match_users_detail "/api/v1/users/detail?user_id=not-a-uuid");
      Oth.Assert.none (match_users_detail "/api/v1/users/detail"))

let match_tenant_members =
  match_query
    Brtl_rtng.Route.(
      Sgs_api_tenants.List_members.route ()
      --> fun tenant_id search role cursor limit -> Some (tenant_id, search, role, cursor, limit))

(* The tenant id is a UUID in api.json, so the route matches only a UUID, and the handler gets it
   before the query parameters. *)
let test_tenant_members_tenant_id_is_a_uuid =
  Oth.test ~name:"Tenant members matches only a UUID tenant_id, given before the query" (fun _ ->
      let id = "c0708dee-4e89-470a-a4b8-83cbc4051327" in
      let tenant_id, _, _, cursor, limit =
        Oth.Assert.some (match_tenant_members ("/api/v1/tenants/" ^ id ^ "/members?cursor=c"))
      in
      Oth.Assert.eq ~eq:Uuidm.equal ~pp:Uuidm.pp (Oth.Assert.some (Uuidm.of_string id)) tenant_id;
      Oth.Assert.Eq.string_option ~expected:(Some "c") ~actual:cursor;
      Oth.Assert.Eq.int ~expected:25 ~actual:limit;
      Oth.Assert.none (match_tenant_members "/api/v1/tenants/not-a-uuid/members"))

let () =
  Oth.run
    ~file:__FILE__
    ~setup:(fun () -> Ok ())
    ~teardown:(fun _ -> ())
    (fun _ ->
      Oth.parallel
        [
          test_list_params_order;
          test_list_type_accepts_only_user_type_enum;
          test_list_limit_default;
          test_detail_user_id_is_a_uuid;
          test_tenant_members_tenant_id_is_a_uuid;
        ])
