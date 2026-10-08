module Inputs = struct
  type t = Sgs_tx_log_hints_realized_object_input.t list
  [@@deriving yojson { strict = false; meta = true }, show, eq]
end

type t = {
  canon : string;
  certain : bool option; [@default None]
  inputs : Inputs.t option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, make, show, eq]
