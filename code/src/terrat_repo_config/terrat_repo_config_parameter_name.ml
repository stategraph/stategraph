module Values = struct
  type t = string list option [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  fail_if_set : bool; [@default false]
  values : Values.t option; [@default None]
}
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
