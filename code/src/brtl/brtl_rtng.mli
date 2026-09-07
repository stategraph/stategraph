module Handler : sig
  type t = (string, unit) Brtl_ctx.t -> (string, Brtl_rspnc.t) Brtl_ctx.t Abb.Future.t
end

module Route : sig
  (** A URL pattern. *)
  type ('f, 'r) t

  (** Create a string representation of a route. This is vaguely URL-like but not a URL. *)
  val to_string : ('f, 'r) t -> string

  (** Extractions from the URI path. *)
  module Path : sig
    type 'a t

    (** A user defined extraction. The function is passed the string which contains a segment of a
        URI path, which is the content between two slashes or at the end of the string. *)
    val ud : (string -> 'a option) -> 'a t

    (** Extract a string from the path. *)
    val string : string t

    (** Extract an int from the path. *)
    val int : int t

    (** Extract a UUID from the path. A segment that is not a UUID does not match the route, so the
        handler is never reached with an id it would have to re-validate. *)
    val uuid : Uuidm.t t

    (** Extract whatever remains of the path. There must be something left on the rest of the path.
        For example, if a route only as [Path.any] and the URI is [http://test.com], this will not
        match the [Path.any], but [http://test.com/] will. This applies for any point in the path.
    *)
    val any : string t
  end

  (** Extractions for query parameters. *)
  module Query : sig
    type 'a t

    (** Given the name of a query parameter, pass the value into the string and convert it to the
        type. *)
    val ud : string -> (string -> 'a option) -> 'a t

    val ud_array : string -> (string list -> 'a option) -> 'a t

    (** An optional parameter *)
    val option : 'a t -> 'a option t

    (** An optional parameter with a default value *)
    val option_default : 'a -> 'a t -> 'a t

    (** Extract a string from the query parameter. *)
    val string : string -> string t

    (** Extract an int from the query parameters. *)
    val int : string -> int t

    (** Extract a UUID from the query parameters. A value that is not a UUID does not match the
        route, so the handler is never reached with an id it would have to re-validate. *)
    val uuid : string -> Uuidm.t t

    (** Extract a bool from the query parameters. *)
    val bool : string -> bool t

    (** Extract an array of elements *)
    val array : 'a t -> 'a list t

    (** If a value is present with no value *)
    val present : string -> unit t
  end

  (** Extractions for the body. *)
  module Body : sig
    type 'a t
    type 'a v

    (* Extract a value based o its key and convert it *)
    val k : string -> 'a v -> 'a t

    (* val array : 'a v -> 'a list t *)

    val ud : 'a v -> ('a -> 'b option) -> 'b v

    (** Extract a string from the query parameter. *)
    val string : string v

    (** Extract an int from the query parameters. *)
    val int : int v

    (** Extract a bool from the query parameters. *)
    val bool : bool v

    (** Optional value. This only applies if the value is there and is successfully extracted or it
        is not present at all. If the key is found but does not successfully convert, it this fails.
    *)
    val option : string -> 'a v -> 'a option t

    (** Same but applies a default value in the case that the key is no found at all. *)
    val option_default : string -> 'a -> 'a v -> 'a t

    (** Convert the whole body to an object using the various decoders. This works by reviewing the
        [content-type] of the request and dispatching the correct decoder. If the coder for the
        [content-type] is not present, the request fails to match this route. *)
    val decode :
      ?json:(Yojson.Safe.t -> ('a, string) result) ->
      ?form:((string * string list) list -> 'a option) ->
      unit ->
      'a t
  end

  (** Represents a route, which is a URL pattern and the function it should be applied to. *)
  module Route : sig
    type 'r t
  end

  (** The start of a path. *)
  val rel : ('r, 'r) t

  (** Match a string portion of the path. *)
  val ( / ) : ('f, 'r) t -> string -> ('f, 'r) t

  (** Extract a variable from the path. *)
  val ( /% ) : ('f, 'a -> 'r) t -> 'a Path.t -> ('f, 'r) t

  (** Extract a variable from the query. *)
  val ( /? ) : ('f, 'a -> 'r) t -> 'a Query.t -> ('f, 'r) t

  (** Extract a variable from the body *)
  val ( /* ) : ('f, 'a -> 'r) t -> 'a Body.t -> ('f, 'r) t

  (** Create a route of a URL and a function that matches the types being extracted. *)
  val route : ('f, 'r) t -> 'f -> 'r Route.t

  (** Infix operator for {!route}. *)
  val ( --> ) : ('f, 'r) t -> 'f -> 'r Route.t

  (** Given a list of routes, match an input URI and execute the associated route function. If no
      matches are found, execute the [default] function.

      If the request type is [POST], the body will be decoded based on the content-type. Only JSON
      and form encoded are supported. If the body fails to decode then the request matching will
      continue on without the decoded body. *)
  val match_ctx :
    default:((string, unit) Brtl_ctx.t -> 'r) -> 'r Route.t list -> (string, unit) Brtl_ctx.t -> 'r
end

module Method : sig
  type t = Cohttp.Code.meth
end

type t

val create : default:Handler.t -> (Method.t * Handler.t Route.Route.t) list -> t
val route : (string, unit) Brtl_ctx.t -> t -> Handler.t
