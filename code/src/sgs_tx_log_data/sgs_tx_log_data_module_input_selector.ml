module Val = struct
  type t = Yojson.Safe.t [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  kind : string;
  to_ : string; [@key "to"]
  to_call : string option; [@default None]
  val_ : Val.t; [@key "val"]
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
