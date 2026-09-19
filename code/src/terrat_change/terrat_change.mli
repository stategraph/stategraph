(** A change that is a diff. *)
module Diff : sig
  type t =
    | Add of { filename : string }
    | Change of { filename : string }
    | Remove of { filename : string }
    | Move of {
        filename : string;
        previous_filename : string;
      }
  [@@deriving yojson, eq, show]

  (** The largest number of files that a VCS reports for one pull request. GitHub stops at this
      number and does not say that it stopped. *)
  val max_reported_files : int

  (** [true] when the diff is as long as the VCS reports at most. Such a diff can be short of the
      true change, thus a test that reads it can give a wrong answer, and a caller that cannot
      afford a wrong answer must treat it as no answer at all. *)
  val may_be_truncated : t list -> bool
end

module Dirspace = Terrat_dirspace

module Dirspaceflow : sig
  module Workflow : sig
    type t = {
      idx : int;
      workflow : Terrat_base_repo_config_v1.Workflows.Entry.t;
    }
    [@@deriving eq, show]
  end

  type 'a t = {
    dirspace : Dirspace.t;
    workflow : 'a;
    variables : string Sln_map.String.t option;
  }
  [@@deriving eq, show]

  val to_dirspace : 'a t -> Dirspace.t
end
