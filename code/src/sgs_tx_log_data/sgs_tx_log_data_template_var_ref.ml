module Var_refs = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  var_name : string;
  var_refs : Var_refs.t;
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
