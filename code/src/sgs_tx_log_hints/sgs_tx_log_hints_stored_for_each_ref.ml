module Keys = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  ds : string option; [@default None]
  fq_address : string;
  keys : Keys.t option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
