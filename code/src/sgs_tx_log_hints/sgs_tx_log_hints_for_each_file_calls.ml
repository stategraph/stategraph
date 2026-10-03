module Body = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Collection = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  body : Body.t;
  collection : Collection.t;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
