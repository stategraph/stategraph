module User = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = { user : User.t } [@@deriving yojson { strict = true; meta = true }, make, show, eq]
