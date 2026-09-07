module Ctx = Brtl_ctx
module Rspnc = Brtl_rspnc

module Handler = struct
  type t = (string, unit) Ctx.t -> (string, Rspnc.t) Ctx.t Abb.Future.t
end

module type BODY_DECODER = sig
  type v

  val get : string -> v option
  val string : v -> string option
  val int : v -> int option
  val bool : v -> bool option
  val array : v -> v list option

  (* This is awkward.  The actual implementation will only consume one of these
     but we have to pass them all in because I can't think of a better way to
     accomplish this with the API *)
  val decode :
    (Yojson.Safe.t -> ('a, string) result) ->
    ((string * string list) list -> 'a option) ->
    'a option
end

module Route = struct
  module Path = struct
    type 'a t = int -> string -> (int * 'a) option

    let extract idx s =
      if s.[idx] = '/' then
        match CCString.index_from_opt s (idx + 1) '/' with
        | Some eidx -> Some (eidx, Uri.pct_decode (CCString.sub s (idx + 1) (eidx - idx - 1)))
        | None ->
            Some
              ( String.length s,
                Uri.pct_decode (CCString.sub s (idx + 1) (String.length s - idx - 1)) )
      else None

    let ud f idx s =
      let open CCOption.Infix in
      extract idx s >>= fun (idx, s) -> CCOption.wrap f s >>= fun v -> v >>= fun v -> Some (idx, v)

    let string = ud CCOption.return
    let int = ud (CCFun.compose int_of_string CCOption.return)
    let uuid = ud Uuidm.of_string

    let any idx s =
      if s.[idx] = '/' then
        let len = String.length s - idx - 1 in
        Some (String.length s, Uri.pct_decode (CCString.sub s (idx + 1) len))
      else None
  end

  module Query = struct
    type 'a t = string * (string list option -> 'a option)

    let ud n f =
      ( n,
        function
        | Some (v :: _) -> CCOption.(flatten (wrap f v))
        | Some [] | None -> None )

    let ud_array n f =
      ( n,
        function
        | Some vs -> CCOption.(flatten (wrap f vs))
        | None -> None )

    let option (n, f) =
      ( n,
        function
        | Some _ as v -> (
            match f v with
            | None -> None
            | r -> Some r)
        | None -> Some None )

    let option_default def (n, f) =
      ( n,
        function
        | Some _ as v -> f v
        | None -> Some def )

    let string n = ud n CCOption.return
    let int n = ud n CCFun.(int_of_string %> CCOption.return)
    let uuid n = ud n Uuidm.of_string

    let bool n =
      ud n (function
        | "true" -> Some true
        | "false" -> Some false
        | _ -> None)

    let rec apply_arr' acc f = function
      | [] -> Some (List.rev acc)
      | v :: vs -> (
          match f (Some [ v ]) with
          | Some r -> apply_arr' (r :: acc) f vs
          | None -> None)

    let array (n, f) =
      ( n,
        function
        | Some vs -> apply_arr' [] f vs
        | None -> None )

    let present n =
      ( n,
        function
        | Some [] -> Some ()
        | Some _ | None -> None )
  end

  module Body = struct
    type 'a t = (module BODY_DECODER) -> 'a option
    type 'a v = { v : 'v. (module BODY_DECODER with type v = 'v) -> 'v -> 'a option }

    let k n { v } (module D : BODY_DECODER) =
      match D.get n with
      | Some value -> v (module D) value
      | None -> None

    (* let array (type v) { v } =
     *   {
     *     v =
     *       (fun (module D : BODY_DECODER with type v = v) (arr : v) ->
     *         let open CCOption.Infix in
     *         D.array arr
     *         >>= fun values -> CCOption.sequence_l (CCList.map (v (module D : BODY_DECODER)) values));
     *   } *)

    let ud { v } f =
      {
        v =
          (fun (type v) (module D : BODY_DECODER with type v = v) value ->
            let open CCOption.Infix in
            v (module D : BODY_DECODER with type v = v) value >>= fun value -> f value);
      }

    let string =
      { v = (fun (type v) (module D : BODY_DECODER with type v = v) (v : v) -> D.string v) }

    let int = { v = (fun (type v) (module D : BODY_DECODER with type v = v) (v : v) -> D.int v) }
    let bool = { v = (fun (type v) (module D : BODY_DECODER with type v = v) (v : v) -> D.bool v) }

    let option n { v } (module D : BODY_DECODER) =
      match D.get n with
      | Some value -> (
          (* Only pass on if the extraction works *)
          match v (module D) value with
          | None -> None
          | x -> Some x)
      | None -> Some None

    let option_default n default { v } (module D : BODY_DECODER) =
      match D.get n with
      | Some value -> (
          (* Only pass on if the extraction works *)
          match v (module D) value with
          | None -> None
          | x -> x)
      | None -> Some default

    let decode
        ?(json = fun _ -> Error "not implemented")
        ?(form = fun _ -> None)
        ()
        (module D : BODY_DECODER) =
      D.decode json form
  end

  module Body_form = struct
    let make s =
      let body = Uri.of_string ("?" ^ s) in
      Some
        (module struct
          type v = string list

          let get k = Uri.get_query_param' body k
          let array vs = Some (CCList.map (fun v -> [ v ]) vs)
          let string = CCList.head_opt

          let int = function
            | v :: _ -> CCInt.of_string v
            | _ -> None

          let bool = function
            | "true" :: _ -> Some true
            | "false" :: _ -> Some false
            | _ -> None

          let decode _ form = form (Uri.query body)
        end : BODY_DECODER)
  end

  module Body_json = struct
    let make s =
      try
        let body = Yojson.Safe.from_string s in
        Some
          (module struct
            type v = Yojson.Safe.t

            let get k =
              match Yojson.Safe.Util.member k body with
              | `Null -> None
              | v -> Some v

            let array v = try Some (Yojson.Safe.Util.to_list v) with _ -> None
            let string = Yojson.Safe.Util.to_string_option
            let int = Yojson.Safe.Util.to_int_option
            let bool = Yojson.Safe.Util.to_bool_option
            let decode json _ = CCResult.to_opt (json body)
          end : BODY_DECODER)
      with _ -> None
  end

  module Body_noop = struct
    type v = unit

    let get _ = None
    let array () = raise (Failure "Body_noop - array - not implemented")
    let string () = raise (Failure "Body_noop - string - not implemented")
    let int () = raise (Failure "Body_noop - int - not implemented")
    let bool () = raise (Failure "Body_noop - bool - not implemented")
    let decode _ _ = None
  end

  type ('f, 'r) t =
    (* | Host : string -> ('r, 'r) t *)
    | Rel : ('r, 'r) t
    | Path_const : (('f, 'r) t * string) -> ('f, 'r) t
    | Path_var : (('f, 'a -> 'r) t * 'a Path.t) -> ('f, 'r) t
    | Query_var : (('f, 'a -> 'r) t * 'a Query.t) -> ('f, 'r) t
    | Body_var : (('f, 'a -> 'r) t * 'a Body.t) -> ('f, 'r) t

  let rec to_string : type f r. (f, r) t -> string =
   fun t ->
    match t with
    | Rel -> ""
    | Path_const (t, c) -> to_string t ^ "/" ^ c
    | Path_var (t, _) -> to_string t ^ "/<var>"
    | Query_var (t, (n, _)) -> to_string t ^ "(?" ^ n ^ ")"
    | Body_var (t, _) -> to_string t ^ "<body>"

  module Route = struct
    (* Remember the name of Furi.t first *)
    type ('f, 'r) _t = ('f, 'r) t
    type 'r t = Route : (('f, 'r) _t * 'f) -> 'r t
  end

  let rel = Rel
  let ( / ) t s = Path_const (t, Uri.pct_encode ~component:`Path s)
  let ( /% ) t v = Path_var (t, v)
  let ( /? ) t v = Query_var (t, v)
  let ( /* ) t v = Body_var (t, v)
  let route t f = Route.Route (t, f)
  let ( --> ) = route

  module Witness = struct
    type ('f, 'r) t =
      | Start : ('r, 'r) t
      | Var : (('f, 'a -> 'r) t * 'a) -> ('f, 'r) t
  end

  (* [path] and [query] are properties of the REQUEST, not of the route being tried, so they are
     decoded once by [match_ctx'] and threaded through here. [Uri.path] and [Uri.query] each
     re-decode the URI and allocate afresh; taken per recursion step they were paid once per path
     segment of every route the matcher tried before reaching the right one, so the cost of dispatch
     grew with a route's position in the table -- 0.4 ms at index 2, 17 ms at index 97 of 108. The
     most frequent request this server serves is an actuator task poll, and it sits near the end of
     that table. *)
  let rec test_ctx : type f r.
      (module BODY_DECODER) ->
      path:string ->
      query:(string * string list) list ->
      (f, r) t ->
      (int * (f, r) Witness.t) option =
   fun body ~path ~query t ->
    match t with
    | Rel -> Some (0, Witness.Start)
    | Path_const (t, s) ->
        let open CCOption.Infix in
        test_ctx body ~path ~query t
        >>= fun (idx, wit) ->
        if idx < String.length path then
          let s = "/" ^ s in
          let len = String.length s in
          if CCString.is_sub ~sub:s 0 path idx ~sub_len:len then Some (idx + len, wit) else None
        else None
    | Path_var (t, v) ->
        let open CCOption.Infix in
        test_ctx body ~path ~query t
        >>= fun (idx, wit) ->
        if idx < String.length path then
          v idx path >>= fun (idx, value) -> Some (idx, Witness.Var (wit, value))
        else None
    | Query_var (t, (n, v)) ->
        let open CCOption.Infix in
        test_ctx body ~path ~query t
        >>= fun (idx, wit) ->
        (* The Uri library gives you all query params as mappings to list with
           [query], so we filter the one we care about, which will be a list of
           lists, and if that list is empty we know that there is query param,
           so we map that to [None] other wise we flatten the list so it's like
           (name -> list), and operate on that. *)
        let q =
          let qp =
            CCList.filter_map (function
              | qn, vs when CCString.equal qn n -> Some vs
              | _ -> None)
            @@ query
          in
          match qp with
          | [] -> None
          | vs -> Some (CCList.flatten vs)
        in
        v q >>= fun value -> Some (idx, Witness.Var (wit, value))
    | Body_var (t, body_var) ->
        let open CCOption.Infix in
        test_ctx body ~path ~query t
        >>= fun (idx, wit) -> body_var body >>= fun value -> Some (idx, Witness.Var (wit, value))

  let rec apply_ctx' : type f r x. (f, x) Witness.t -> (x -> r) -> f -> r =
   fun w k ->
    let open Witness in
    match w with
    | Start -> k
    | Var (wit, v) ->
        let k f = k (f v) in
        apply_ctx' wit k

  let apply_ctx : type f r. (f, r) Witness.t -> f -> r = fun wit -> apply_ctx' wit (fun x -> x)

  let match_ctx' ~default rs ctx body =
    let uri = Brtl_ctx.Request.uri (Brtl_ctx.request ctx) in
    let path = Uri.path uri in
    let query = Uri.query uri in
    let path_len = String.length path in
    let rec go = function
      | [] -> default ctx
      | Route.Route (t, f) :: rs -> (
          match test_ctx body ~path ~query t with
          | Some (idx, wit) when path_len = idx ->
              (* Ensure the whole URI path has been consumed *)
              apply_ctx wit f
          | Some _ | None -> go rs)
    in
    go rs

  let match_ctx ~default rs ctx =
    match Brtl_ctx.Request.meth (Brtl_ctx.request ctx) with
    | `DELETE | `PATCH | `POST | `PUT -> (
        match
          Cohttp.Header.get (Brtl_ctx.Request.headers (Brtl_ctx.request ctx)) "content-type"
        with
        | Some
            ( "application/json"
            | "application/x-javascript"
            | "text/javascript"
            | "text/x-javascript"
            | "text/x-json" ) -> (
            match Body_json.make (Brtl_ctx.body ctx) with
            | Some body -> match_ctx' ~default rs ctx body
            | None -> match_ctx' ~default rs ctx (module Body_noop))
        | _ -> (
            match Body_form.make (Brtl_ctx.body ctx) with
            | Some body -> match_ctx' ~default rs ctx body
            | None -> match_ctx' ~default rs ctx (module Body_noop)))
    | _ -> match_ctx' ~default rs ctx (module Body_noop)
end

module Method = struct
  type t = Cohttp.Code.meth
end

type t = {
  default : Handler.t;
  routes : (Method.t, (string, unit) Brtl_ctx.t -> Handler.t) Hashtbl.t;
}

let create ~default routes_list =
  let route_default _ = default in
  let tmp = Hashtbl.create 10 in
  ListLabels.iter ~f:(fun (meth, route) -> CCHashtbl.add_list tmp meth route) routes_list;
  let routes = Hashtbl.create 10 in
  Hashtbl.iter
    (fun meth rts ->
      Hashtbl.add routes meth (Route.match_ctx ~default:route_default (CCList.rev rts)))
    tmp;
  { default; routes }

let route ctx t =
  match CCHashtbl.get t.routes Ctx.(Request.meth (request ctx)) with
  | Some routes -> routes ctx
  | None -> t.default
