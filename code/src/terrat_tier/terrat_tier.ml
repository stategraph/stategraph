module Check = struct
  type users_per_month = {
    users : string list;
    limit : int;
  }
  [@@deriving show]

  type runs_per_month = {
    used : int;
    limit : int;
  }
  [@@deriving show]

  type t = {
    tier_name : string;
    users_per_month : users_per_month option;
    runs_per_month : runs_per_month option;
  }
  [@@deriving show]
end

module Retention = struct
  type t = { runs : int [@default CCInt.max_int] }
  [@@deriving make, show, eq, yojson { strict = false }]
end

(* Features are stored as jsonb in the tiers table and rows are added in
   production ahead of code deploys, so parsing must ignore unknown fields. *)
type t = {
  num_users_per_month : int; [@default CCInt.max_int]
  runs_per_month : int; [@default CCInt.max_int]
  private_runners : int; [@default CCInt.max_int]
  retention_days : Retention.t; [@default Retention.make ()]
}
[@@deriving show, eq, yojson { strict = false }]

(* The Open Source caps: what an oss binary clamps an installation's tier
   features down to, regardless of what the tier row says. Only users are
   capped; runs are unlimited. *)
let oss =
  {
    num_users_per_month = 3;
    runs_per_month = CCInt.max_int;
    private_runners = CCInt.max_int;
    retention_days = Retention.make ();
  }

(* Field-wise minimum of [t] and [caps]: a tier can never exceed the caps and
   an already-lower tier keeps its own limits. Retention is left as [t]'s --
   it is parsed but enforced nowhere today. *)
let clamp ~caps t =
  {
    num_users_per_month = CCInt.min caps.num_users_per_month t.num_users_per_month;
    runs_per_month = CCInt.min caps.runs_per_month t.runs_per_month;
    private_runners = CCInt.min caps.private_runners t.private_runners;
    retention_days = t.retention_days;
  }
