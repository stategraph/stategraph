type t = { stale_config_min : int }
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
