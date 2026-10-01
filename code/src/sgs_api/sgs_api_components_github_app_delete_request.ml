type t = { app_id : int } [@@deriving yojson { strict = false; meta = true }, show, eq]
