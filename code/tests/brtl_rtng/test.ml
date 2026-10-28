module Oth_abb = Oth_abb.Make (Abb)
module Fut = Abb.Future

let ctx path =
  Brtl_ctx.create "test" (Cohttp.Request.make (Uri.of_string path)) |> Brtl_ctx.set_body ""

let route_a = Brtl_rtng.Route.((rel / "a") --> "a")
let route_b = Brtl_rtng.Route.((rel / "b") --> "b")
let exclaim = Brtl_rtng.Route.Route.map (fun s -> s ^ "!")
let matched path routes = Brtl_rtng.Route.match_ctx ~default:(fun _ -> "default") routes (ctx path)

let test_map =
  Oth_abb.test
    ~tags:[ "brtl_rtng" ]
    ~name:"a mapped route matches the requests of its route and transforms what it gives"
    (fun () ->
      Oth_abb.Assert.Eq.string ~expected:"a!" ~actual:(matched "/a" [ exclaim route_a ]);
      Oth_abb.Assert.Eq.string ~expected:"a!!" ~actual:(matched "/a" [ exclaim (exclaim route_a) ]);
      (* The whole path must still be consumed. *)
      Oth_abb.Assert.Eq.string ~expected:"default" ~actual:(matched "/a/more" [ exclaim route_a ]);
      (* A mapped route that does not match lets the next route match. *)
      Oth_abb.Assert.Eq.string ~expected:"b" ~actual:(matched "/b" [ exclaim route_a; route_b ]);
      Fut.return ())

let () =
  Oth_abb.run
    ~file:__FILE__
    ~setup:(fun () -> Abbs_fc.return_ok ())
    ~teardown:(fun () -> Fut.return ())
    (fun () -> Oth_abb.serial [ test_map ])
