module Attr_path = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Index_kind = struct
  type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Index_val = struct
  type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  attr_path : Attr_path.t;
  from_depends_on : bool;
  index_kind : Index_kind.t;
  index_val : Index_val.t;
  is_bare : bool;
  names_a_node : bool option; [@default None]
  resolvable : bool;
  to_addr : string;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
