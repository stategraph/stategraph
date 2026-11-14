module Additional = struct
  type t = string [@@deriving yojson { strict = false; meta = true }, show, eq]
end

include Json_schema.Additional_properties.Make (Json_schema.Empty_obj) (Additional)
