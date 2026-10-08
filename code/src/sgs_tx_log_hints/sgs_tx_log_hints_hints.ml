module For_each_body_refs = struct
  type t = Sgs_tx_log_hints_for_each_body_ref_hint.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module For_each_refs = struct
  type t = Sgs_tx_log_hints_for_each_ref_hint.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

module Object_attr_refs = struct
  type t = Sgs_tx_log_hints_object_attr_ref_hint.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  for_each_body_refs : For_each_body_refs.t option; [@default None]
  for_each_refs : For_each_refs.t option; [@default None]
  object_attr_refs : Object_attr_refs.t option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
