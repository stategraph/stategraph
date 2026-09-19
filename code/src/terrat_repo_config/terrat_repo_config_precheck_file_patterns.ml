module File_patterns = struct
  type t = string list [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = { file_patterns : File_patterns.t }
[@@deriving yojson { strict = true; meta = true }, make, show, eq]
