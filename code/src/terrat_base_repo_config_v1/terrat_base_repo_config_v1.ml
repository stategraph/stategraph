module V1 = Terrat_repo_config.Version_1

let config_schema = [%blob "../../../../api_schemas/terrat/config-schema.json"]

let timezone_abbreviations =
  Sln_set.String.of_list
    [
      "ACDT";
      "ACST";
      "ACT";
      "ACT";
      "ACWST";
      "ADT";
      "AEDT";
      "AEST";
      "AEST";
      "AEDT";
      "AFT";
      "AKDT";
      "AKST";
      "ALMT";
      "AMST";
      "AMT";
      "AMT";
      "ANAT";
      "AQTT";
      "ART";
      "AST";
      "AST";
      "AWST";
      "AZOST";
      "AZOT";
      "AZT";
      "BNT";
      "BIOT";
      "BIT";
      "BOT";
      "BRST";
      "BRT";
      "BST";
      "BST";
      "BST";
      "BTT";
      "CAT";
      "CCT";
      "CDT";
      "CDT";
      "CEST";
      "CET";
      "CHADT";
      "CHAST";
      "CHOT";
      "CHOST";
      "CHST";
      "CHUT";
      "CIST";
      "CKT";
      "CLST";
      "CLT";
      "COST";
      "COT";
      "CST";
      "CST";
      "CST";
      "CST";
      "CDT";
      "CVT";
      "CWST";
      "CXT";
      "DAVT";
      "DDUT";
      "DFT";
      "EASST";
      "EAST";
      "EAT";
      "ECT";
      "ECT";
      "EDT";
      "EEST";
      "EET";
      "EGST";
      "EGT";
      "EST";
      "EST";
      "EDT";
      "FET";
      "FJT";
      "FKST";
      "FKT";
      "FNT";
      "GALT";
      "GAMT";
      "GET";
      "GFT";
      "GILT";
      "GIT";
      "GMT";
      "GST";
      "GST";
      "GYT";
      "HDT";
      "HAEC";
      "HST";
      "HKT";
      "HMT";
      "HOVST";
      "HOVT";
      "ICT";
      "IDLW";
      "IDT";
      "IOT";
      "IRDT";
      "IRKT";
      "IRST";
      "IST";
      "IST";
      "IST";
      "JST";
      "KALT";
      "KGT";
      "KOST";
      "KRAT";
      "KST";
      "LHST";
      "LHST";
      "LINT";
      "MAGT";
      "MART";
      "MAWT";
      "MDT";
      "MET";
      "MEST";
      "MHT";
      "MIST";
      "MIT";
      "MMT";
      "MSK";
      "MST";
      "MST";
      "MST";
      "MDT";
      "MUT";
      "MVT";
      "MYT";
      "NCT";
      "NDT";
      "NFT";
      "NOVT";
      "NPT";
      "NST";
      "NT";
      "NUT";
      "NZDT";
      "NZST";
      "OMST";
      "ORAT";
      "PDT";
      "PET";
      "PETT";
      "PGT";
      "PHOT";
      "PHT";
      "PHST";
      "PKT";
      "PMDT";
      "PMST";
      "PONT";
      "PST";
      "PST";
      "PDT";
      "PWT";
      "PYST";
      "PYT";
      "RET";
      "ROTT";
      "SAKT";
      "SAMT";
      "SAST";
      "SBT";
      "SCT";
      "SDT";
      "SGT";
      "SLST";
      "SRET";
      "SRT";
      "SST";
      "SYOT";
      "TAHT";
      "THA";
      "TFT";
      "TJT";
      "TKT";
      "TLT";
      "TMT";
      "TRT";
      "TOT";
      "TST";
      "TVT";
      "ULAST";
      "ULAT";
      "UTC";
      "UYST";
      "UYT";
      "UZT";
      "VET";
      "VLAT";
      "VOLT";
      "VOST";
      "VUT";
      "WAKT";
      "WAST";
      "WAT";
      "WEST";
      "WET";
      "WIB";
      "WIT";
      "WITA";
      "WGST";
      "WGT";
      "WST";
      "YAKT";
      "YEKT";
    ]

let map_opt f = function
  | None -> Ok None
  | Some v ->
      let open CCResult.Infix in
      f v >>= fun v -> Ok (Some v)

let map_opt_if_true test f v = if test v then Some (f v) else None

module Pattern = struct
  type t = {
    s : string;
    p : Lua_pattern.t;
  }

  let make s =
    match Lua_pattern.of_string s with
    | Some p -> Ok { s; p }
    | None -> Error (`Pattern_parse_err s)

  let is_match { p; _ } str = CCOption.is_some (Lua_pattern.find str p)
  let pattern { s; _ } = s
  let equal p1 p2 = CCString.equal (pattern p1) (pattern p2)
  let pp formatter { s; _ } = Format.fprintf formatter "%s" s
  let show { s; _ } = s
  let to_string { s; _ } = s
  let to_yojson { s; _ } = `String s

  let of_yojson = function
    | `String s -> CCResult.map_err (fun _ -> "Pattern_parse_err " ^ s) (make s)
    | _ -> Error "Expected string"
end

module Tag_query = struct
  type t = Terrat_tag_query.t [@@deriving eq]

  let any = Terrat_tag_query.any
  let to_yojson t = `String (Terrat_tag_query.to_string t)

  let of_yojson = function
    | `String s -> (
        match Terrat_tag_query.of_string s with
        | Ok t -> Ok t
        | Error (`Tag_query_error (_query, err)) -> Error err)
    | _ -> Error "Expected string"

  let pp formatter t = Format.fprintf formatter "%s" (Terrat_tag_query.to_string t)
  let show = Terrat_tag_query.to_string
end

module Workflow_step = struct
  (* Helper modules *)
  module Cmd = struct
    type t = string list [@@deriving show, yojson, eq]
  end

  module Run_on = struct
    type t =
      | Failure
      | Always
      | Success
    [@@deriving show, yojson, eq]
  end

  module Visible_on = struct
    type t =
      | Always
      | Failure
      | Success
    [@@deriving show, yojson, eq]

    let to_string = function
      | Always -> "always"
      | Failure -> "failure"
      | Success -> "success"
  end

  module Retry = struct
    type t = {
      backoff : float; [@default 1.5]
      enabled : bool; [@default false]
      initial_sleep : int; [@default 5]
      tries : int; [@default 3]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Gate = struct
    type t = {
      any_of : string list option; [@default None]
      all_of : string list option; [@default None]
      any_of_count : int option; [@default None]
      token : string option; [@default None]
      name : string option; [@default None]
    }
    [@@deriving make, show, yojson, eq]
  end

  (* Workflow steps *)
  module Env = struct
    module Exec = struct
      type t = {
        cmd : Cmd.t;
        name : string;
        sensitive : bool; [@default false]
        trim_trailing_newlines : bool; [@default true]
      }
      [@@deriving make, show, yojson, eq]
    end

    module Source = struct
      type t = {
        cmd : Cmd.t;
        sensitive : bool; [@default false]
      }
      [@@deriving make, show, yojson, eq]
    end

    type t =
      | Exec of Exec.t
      | Source of Source.t
    [@@deriving show, yojson, eq]
  end

  module Oidc = struct
    module Aws = struct
      type t = {
        assume_role_arn : string option;
        assume_role_enabled : bool; [@default true]
        audience : string option;
        duration : int; [@default 3600]
        region : string; [@default "us-east-1"]
        role_arn : string;
        session_name : string; [@default "terrateam"]
      }
      [@@deriving make, show, yojson, eq]
    end

    module Azure = struct
      type t = {
        audience : string option;
        client_id : string;
        subscription_id : string option;
        tenant_id : string;
      }
      [@@deriving make, show, yojson, eq]
    end

    module Gcp = struct
      type t = {
        access_token_lifetime : int; [@default 3600]
        access_token_subject : string option;
        audience : string option;
        project_id : string option;
        service_account : string;
        workload_identity_provider : string;
      }
      [@@deriving make, show, yojson, eq]
    end

    type t =
      | Aws of Aws.t
      | Azure of Azure.t
      | Gcp of Gcp.t
    [@@deriving show, yojson, eq]
  end

  module Format = struct
    type t =
      | Code
      | Raw
      | Markdown
      | Code_lang of string
    [@@deriving show, yojson, eq]
  end

  module Run = struct
    type t = {
      capture_output : bool; [@default false]
      cmd : Cmd.t;
      env : string Sln_map.String.t option;
      format : Format.t; [@default Format.Code]
      ignore_errors : bool; [@default false]
      on_error : Yojson.Safe.t list; [@default []]
      run_on : Run_on.t; [@default Run_on.Success]
      visible_on : Visible_on.t; [@default Visible_on.Failure]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Init = struct
    type t = {
      env : string Sln_map.String.t option;
      extra_args : string list; [@default []]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Plan = struct
    module Mode = struct
      type t =
        | Strict
        | Fast_and_loose
      [@@deriving show, yojson, eq]
    end

    type t = {
      env : string Sln_map.String.t option;
      extra_args : string list; [@default []]
      mode : Mode.t; [@default Mode.Strict]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Apply = struct
    type t = {
      env : string Sln_map.String.t option;
      extra_args : string list; [@default []]
      retry : Retry.t option;
    }
    [@@deriving make, show, yojson, eq]
  end

  module Conftest = struct
    type t = {
      env : string Sln_map.String.t option;
      extra_args : string list; [@default []]
      gate : Gate.t option; [@default None]
      ignore_errors : bool; [@default false]
      run_on : Run_on.t; [@default Run_on.Success]
      visible_on : Visible_on.t; [@default Visible_on.Failure]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Checkov = struct
    type t = {
      env : string Sln_map.String.t option;
      extra_args : string list; [@default []]
      gate : Gate.t option; [@default None]
      ignore_errors : bool; [@default false]
      run_on : Run_on.t; [@default Run_on.Success]
      visible_on : Visible_on.t; [@default Visible_on.Failure]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Opa = struct
    module Fail_on = struct
      type t =
        | Defined
        | Undefined
      [@@deriving show, yojson, eq]
    end

    type t = {
      env : string Sln_map.String.t option;
      extra_args : string list; [@default []]
      fail_on : Fail_on.t; [@default Fail_on.Undefined]
      gate : Gate.t option; [@default None]
      ignore_errors : bool; [@default false]
      run_on : Run_on.t; [@default Run_on.Success]
      visible_on : Visible_on.t; [@default Visible_on.Failure]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Gates = struct
    type t = {
      env : string Sln_map.String.t option;
      cmd : Cmd.t;
      run_on : Run_on.t; [@default Run_on.Success]
    }
    [@@deriving make, show, yojson, eq]
  end
end

module Access_control = struct
  module Match = struct
    type t =
      | User of string
      | Team of string
      | Role of string
      | Any
    [@@deriving show, eq, ord]

    let make m =
      match CCString.Split.left ~by:":" m with
      | Some ("user", user) -> Ok (User user)
      | Some ("team", team) -> Ok (Team team)
      | Some (("role" | "repo"), repo) ->
          (* Support 'repo' for backwards compatibility reasons. *)
          Ok (Role repo)
      | _ when CCString.equal m "*" -> Ok Any
      | _ -> Error (`Match_parse_err m)

    let to_string = function
      | User user -> "user:" ^ user
      | Team team -> "team:" ^ team
      | Role role -> "role:" ^ role
      | Any -> "*"

    let to_yojson t =
      let module T = struct
        type t = string [@@deriving to_yojson]
      end in
      T.to_yojson (to_string t)

    let of_yojson json =
      let module T = struct
        type t = string [@@deriving of_yojson]
      end in
      let open CCResult.Infix in
      T.of_yojson json
      >>= fun m -> CCResult.map_err (fun (`Match_parse_err _) -> "Match parse err: " ^ m) (make m)
  end

  module Match_list = struct
    type t = Match.t list [@@deriving show, yojson, eq]
  end

  module Policy = struct
    type t = {
      apply : Match_list.t; [@default [ Match.Any ]]
      apply_autoapprove : Match_list.t; [@default []]
      apply_force : Match_list.t; [@default []]
      apply_with_superapproval : Match_list.t; [@default []]
      plan : Match_list.t; [@default [ Match.Any ]]
      superapproval : Match_list.t; [@default []]
      tag_query : Tag_query.t;
    }
    [@@deriving make, show, yojson, eq]
  end

  module Policy_list = struct
    type t = Policy.t list [@@deriving show, yojson, eq]
  end

  type t = {
    apply_require_all_dirspace_access : bool; [@default true]
    ci_config_update : Match_list.t; [@default [ Match.Any ]]
    enabled : bool; [@default true]
    files : Match_list.t Sln_map.String.t; [@default Sln_map.String.empty]
    plan_require_all_dirspace_access : bool; [@default false]
    policies : Policy_list.t; [@default [ Policy.make ~tag_query:Terrat_tag_query.any () ]]
    terrateam_config_update : Match_list.t; [@default [ Match.Any ]]
    unlock : Match_list.t; [@default [ Match.Any ]]
  }
  [@@deriving make, show, yojson, eq]
end

module Apply_requirements = struct
  module Apply_after_merge = struct
    type t = { enabled : bool [@default false] } [@@deriving make, show, yojson, eq]
  end

  module Approved = struct
    type t = {
      all_of : Access_control.Match_list.t; [@default []]
      any_of : Access_control.Match_list.t; [@default []]
      any_of_count : int; [@default 1]
      enabled : bool; [@default false]
      require_completed_reviews : bool; [@default false]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Merge_conflicts = struct
    type t = { enabled : bool [@default true] } [@@deriving make, show, yojson, eq]
  end

  module Status_checks = struct
    type t = {
      enabled : bool; [@default true]
      ignore_matching : string list; [@default []]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Check = struct
    type t = {
      apply_after_merge : Apply_after_merge.t; [@default Apply_after_merge.make ()]
      approved : Approved.t; [@default Approved.make ()]
      merge_conflicts : Merge_conflicts.t; [@default Merge_conflicts.make ()]
      require_ready_for_review_pr : bool; [@default true]
      status_checks : Status_checks.t; [@default Status_checks.make ()]
      tag_query : Tag_query.t; [@default Terrat_tag_query.any]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Check_list = struct
    type t = Check.t list [@@deriving show, yojson, eq]
  end

  type t = {
    checks : Check_list.t; [@default [ Check.make ~approved:(Approved.make ~enabled:false ()) () ]]
    create_pending_apply_check : bool; [@default true]
    create_completed_apply_check_on_noop : bool; [@default false]
  }
  [@@deriving make, show, yojson, eq]
end

module Automerge = struct
  module Merge_strategy = struct
    type t =
      | Auto
      | Merge
      | Rebase
      | Squash
    [@@deriving show, yojson, eq]

    let make = function
      | `Auto -> Auto
      | `Merge -> Merge
      | `Rebase -> Rebase
      | `Squash -> Squash

    let to_string = function
      | Auto -> "auto"
      | Merge -> "merge"
      | Rebase -> "rebase"
      | Squash -> "squash"
  end

  type t = {
    delete_branch : bool; [@default false]
    enabled : bool; [@default false]
    merge_strategy : Merge_strategy.t; [@default Merge_strategy.Auto]
    require_explicit_apply : bool; [@default false]
    retain_pr_title : bool; [@default false]
  }
  [@@deriving make, show, yojson, eq]
end

module Batch_runs = struct
  type t = {
    enabled : bool; [@default false]
    max_workspaces_per_batch : int; [@default 1]
  }
  [@@deriving make, show, yojson, eq]
end

module Config_builder = struct
  type t = {
    enabled : bool; [@default false]
    script : string option;
  }
  [@@deriving make, show, yojson, eq]
end

module Cost_estimation = struct
  module Provider = struct
    type t = Infracost [@@deriving show, yojson, eq]
  end

  type t = {
    currency : string; [@default "USD"]
    enabled : bool; [@default true]
    provider : Provider.t; [@default Provider.Infracost]
  }
  [@@deriving make, show, yojson, eq]
end

module Default_branch_overrides = struct
  type t = string list [@@deriving show, yojson, eq]

  let make () = [ "access_control"; "apply_requirements"; "destination_branches" ]
end

module Destination_branches = struct
  module Destination_branch = struct
    type t = {
      branch : string;
      source_branches : string list; [@default [ "*" ]]
    }
    [@@deriving make, show, yojson, eq]
  end

  type t = Destination_branch.t list [@@deriving show, yojson, eq]
end

module File_pattern = struct
  type t = {
    s : string;
    p : Path_glob.Glob.globber;
    negate : bool;
    prefix : string;
    suffix : string;
    words : string list;
  }

  let sanitize =
    CCFun.(
      CCString.replace ~sub:"${WORKSPACE}" ~by:"\\$\\{WORKSPACE\\}"
      %> CCString.replace ~sub:"${DIR}" ~by:"\\$\\{DIR\\}")

  let make s =
    try
      let negate, s' =
        if CCString.prefix ~pre:"!" s then (true, CCString.drop 1 s) else (false, s)
      in
      (* [prefix], [suffix], and [words] allow optimizing some of the checks in
         the case that globbing is too expensive.  This can happen in very large
         repositories with lots of files and globs with lots of wild cards. *)
      let prefix =
        match CCString.index_opt s' '*' with
        | Some idx -> CCString.sub s' 0 idx
        | None -> s'
      in
      let suffix =
        match CCString.rindex_opt s' '*' with
        | Some idx -> CCString.sub s' (idx + 1) (CCString.length s' - (idx + 1))
        | None -> s'
      in
      let words =
        CCList.map
          (* Strip any dir separators around the string.  If a glob looks like
             [**/foo] that will match [foo]. *)
          CCFun.(
            CCString.drop_while (( = ) '/')
            %> CCString.rev
            %> CCString.drop_while (( = ) '/')
            %> CCString.rev)
        @@ CCList.filter (fun word ->
            (* [3] is just an arbitrary limit of what a string that adds value
               in discriminating a check is. Short strings are likely to not
               tell us much. *)
            CCString.length word > 3)
        @@ CCString.split_on_char '*' s'
      in
      Ok { s; p = Path_glob.Glob.parse ("<" ^ sanitize s' ^ ">"); negate; prefix; suffix; words }
    with Path_glob.Glob.Parse_error err -> Error (`Glob_parse_err (s, err))

  let is_match { p; negate; prefix = pre; suffix = suf; words; _ } str =
    (* Evaluating a glob can be expensive, so we do as many cheap checks as we
       can prior to evaluating the globa. *)
    let m =
      CCString.prefix ~pre str
      && CCString.suffix ~suf str
      && CCList.for_all (fun word -> CCString.mem ~sub:word str) words
      && Path_glob.Glob.eval p str
    in
    if negate then not m else m

  let is_negate { negate; _ } = negate
  let file_pattern { s; _ } = s
  let equal fp1 fp2 = CCString.equal (file_pattern fp1) (file_pattern fp2)
  let pp formatter { s; _ } = Format.fprintf formatter "%s" s
  let show { s; _ } = s
  let to_string { s; _ } = s
  let to_yojson { s; _ } = `String s

  let of_yojson = function
    | `String s -> CCResult.map_err (fun _ -> "Glob_parse_err " ^ s) (make s)
    | _ -> Error "Expected string"
end

module File_pattern_list = struct
  type t = File_pattern.t list [@@deriving show, yojson, eq]
end

module Depends_on = struct
  type t = {
    tag_query : Tag_query.t;
    prune_on_no_change : bool; [@default false]
  }
  [@@deriving make, show, yojson, eq]
end

module When_modified = struct
  type t = {
    autoapply : bool; [@default false]
    autoplan : bool; [@default true]
    autoplan_draft_pr : bool; [@default true]
    depends_on : Depends_on.t option;
    file_patterns : File_pattern_list.t;
        [@default
          [
            CCResult.get_exn (File_pattern.make "${DIR}/*.tf");
            CCResult.get_exn (File_pattern.make "${DIR}/*.tfvars");
          ]]
  }
  [@@deriving make, show, yojson, eq]
end

module Dirs = struct
  module Workspace = struct
    type t = {
      tags : string list; [@default []]
      when_modified : When_modified.t; [@default When_modified.make ()]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Dir = struct
    module Branch_target = struct
      type t =
        | All
        | Dest_branch
      [@@deriving show, yojson, eq]
    end

    type t = {
      create_and_select_workspace : bool; [@default true]
      create_if_missing : bool; [@default false]
      lock_branch_target : Branch_target.t; [@default Branch_target.All]
      stacks : Workspace.t Sln_map.String.t; [@default Sln_map.String.empty]
      tags : string list; [@default []]
      workspaces : Workspace.t Sln_map.String.t;
          [@default Sln_map.String.of_list [ ("default", Workspace.make ()) ]]
    }
    [@@deriving make, show, yojson, eq]
  end

  type t = Dir.t Sln_map.String.t [@@deriving show, yojson, eq]
end

module Drift = struct
  module Window = struct
    type t = {
      end_ : string;
      start : string;
    }
    [@@deriving show, yojson, eq]

    let make ~start ~end_ () =
      match (CCString.Split.right ~by:" " start, CCString.Split.right ~by:" " end_) with
      | Some (_, tz), _ when not (Sln_set.String.mem tz timezone_abbreviations) ->
          Error (`Window_parse_timezone_err tz)
      | _, Some (_, tz) when not (Sln_set.String.mem tz timezone_abbreviations) ->
          Error (`Window_parse_timezone_err tz)
      | None, _ | _, None -> Error (`Window_parse_timezone_err "")
      | _, _ -> Ok { start; end_ }
  end

  module Schedule = struct
    module Sched = struct
      type t =
        | Hourly
        | Daily
        | Weekly
        | Monthly
      [@@deriving show, yojson, eq]

      let to_string = function
        | Hourly -> "hourly"
        | Daily -> "daily"
        | Weekly -> "weekly"
        | Monthly -> "monthly"
    end

    type t = {
      tag_query : Tag_query.t;
      schedule : Sched.t;
      reconcile : bool; [@default false]
      window : Window.t option;
    }
    [@@deriving make, show, yojson, eq]
  end

  type t = {
    enabled : bool; [@default false]
    schedules : Schedule.t Sln_map.String.t; [@default Sln_map.String.empty]
  }
  [@@deriving make, show, yojson, eq]
end

module Engine = struct
  module Tf_outputs = struct
    type t = { collect : bool [@default true] } [@@deriving make, show, yojson, eq]
  end

  module Custom = struct
    type t = {
      apply : string list option;
      diff : string list option;
      init : string list option;
      outputs : string list option;
      plan : string list option;
      unsafe_apply : string list option;
    }
    [@@deriving make, show, yojson, eq]
  end

  module Fly = struct
    type t = { config_file : string } [@@deriving make, show, yojson, eq]
  end

  module Cdktf = struct
    type t = {
      outputs : Tf_outputs.t; [@default Tf_outputs.make ()]
      override_tf_cmd : string option;
      tf_cmd : string; [@default "terraform"]
      tf_version : string; [@default "latest"]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Opentofu = struct
    type t = {
      outputs : Tf_outputs.t; [@default Tf_outputs.make ()]
      override_tf_cmd : string option;
      version : string option;
    }
    [@@deriving make, show, yojson, eq]
  end

  module Stategraph = struct
    type t = {
      outputs : Tf_outputs.t; [@default Tf_outputs.make ()]
      override_tf_cmd : string option;
      tf_cmd : string; [@default "terraform"]
      tf_version : string option;
      version : string option;
    }
    [@@deriving make, show, yojson, eq]
  end

  module Terraform = struct
    type t = {
      outputs : Tf_outputs.t; [@default Tf_outputs.make ()]
      override_tf_cmd : string option;
      version : string option;
    }
    [@@deriving make, show, yojson, eq]
  end

  module Terragrunt = struct
    type t = {
      outputs : Tf_outputs.t; [@default Tf_outputs.make ()]
      override_tf_cmd : string option;
      tf_cmd : string; [@default "terraform"]
      tf_version : string option;
      version : string option;
    }
    [@@deriving make, show, yojson, eq]
  end

  type t =
    | Cdktf of Cdktf.t
    | Custom of Custom.t
    | Fly of Fly.t
    | Opentofu of Opentofu.t
    | Other of Yojson.Safe.t
    | Pulumi
    | Stategraph of Stategraph.t
    | Terraform of Terraform.t
    | Terragrunt of Terragrunt.t
  [@@deriving show, yojson, eq]
end

module Hooks = struct
  module Drift_create_issue = struct
    module Group_by = struct
      type t =
        [ `All
        | `Dirspace
        ]
      [@@deriving show, yojson, eq]
    end

    type t = { group_by : Group_by.t [@default `All] } [@@deriving make, show, yojson, eq]
  end

  module Hook_op = struct
    type t =
      | Drift_create_issue of Drift_create_issue.t
      | Env of Workflow_step.Env.t
      | Oidc of Workflow_step.Oidc.t
      | Run of Workflow_step.Run.t
      | Gates of Workflow_step.Gates.t
    [@@deriving show, yojson, eq]
  end

  module Hook_op_list = struct
    type t = Hook_op.t list [@@deriving show, yojson, eq]
  end

  module Hook = struct
    type t = {
      pre : Hook_op_list.t; [@default []]
      post : Hook_op_list.t; [@default []]
    }
    [@@deriving make, show, yojson, eq]
  end

  type t = {
    all : Hook.t; [@default Hook.make ()]
    apply : Hook.t; [@default Hook.make ()]
    plan : Hook.t; [@default Hook.make ()]
  }
  [@@deriving make, show, yojson, eq]
end

module Indexer = struct
  type t = {
    build_tag : string option;
    enabled : bool; [@default false]
  }
  [@@deriving make, show, yojson, eq]
end

module Integrations = struct
  module Resourcely = struct
    type t = {
      enabled : bool; [@default false]
      extra_args : string list; [@default []]
    }
    [@@deriving make, show, yojson, eq]
  end

  type t = { resourcely : Resourcely.t [@default Resourcely.make ()] }
  [@@deriving make, show, yojson, eq]
end

module Notifications = struct
  module Policy = struct
    module Strategy = struct
      type t =
        | Append
        | Delete
        | Minimize
      [@@deriving show, yojson, eq]
    end

    type t = {
      tag_query : Tag_query.t;
      comment_strategy : Strategy.t; [@default Strategy.Minimize]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Summary = struct
    (* Enterprise feature: the comment summary header only renders in the
       Enterprise Edition.  Defaults to disabled so Open Source users are not
       blocked by the premium-feature gate on the default configuration. *)
    type t = { enabled : bool [@default false] } [@@deriving make, show, yojson, eq]
  end

  type t = {
    policies : Policy.t list; [@default [ Policy.make ~tag_query:Tag_query.any () ]]
    summary : Summary.t; [@default Summary.make ()]
  }
  [@@deriving make, show, yojson, eq]
end

module Stacks = struct
  module Rules = struct
    type t = {
      apply_after : string list; [@default []]
      auto_apply : bool option; [@default None]
      modified_by : string list; [@default []]
      plan_after : string list; [@default []]
    }
    [@@deriving make, show, yojson, eq]
  end

  module Type_ = struct
    type t =
      | Nested of string list
      | Stack of Tag_query.t
    [@@deriving show, yojson, eq]
  end

  module Stack = struct
    type t = {
      type_ : Type_.t;
      rules : Rules.t; [@default Rules.make ()]
      variables : string Sln_map.String.t; [@default Sln_map.String.empty]
    }
    [@@deriving make, show, yojson, eq]
  end

  type t = {
    names : Stack.t Sln_map.String.t;
        [@default
          Sln_map.String.singleton "default" (Stack.make ~type_:(Type_.Stack Tag_query.any) ())]
  }
  [@@deriving make, show, yojson, eq]
end

module Storage = struct
  module Plans = struct
    module Cmd = struct
      type t = {
        delete : Workflow_step.Cmd.t option;
        fetch : Workflow_step.Cmd.t;
        store : Workflow_step.Cmd.t;
      }
      [@@deriving make, show, yojson, eq]
    end

    module S3 = struct
      type t = {
        access_key_id : string option;
        bucket : string;
        delete_extra_args : string list; [@default []]
        delete_used_plans : bool; [@default true]
        fetch_extra_args : string list; [@default []]
        path : string option;
        region : string;
        secret_access_key : string option;
        store_extra_args : string list; [@default []]
      }
      [@@deriving make, show, yojson, eq]
    end

    type t =
      | Terrateam
      | Cmd of Cmd.t
      | S3 of S3.t
    [@@deriving show, yojson, eq]
  end

  type t = { plans : Plans.t [@default Plans.Terrateam] } [@@deriving make, show, yojson, eq]
end

module Tags = struct
  module Branch = struct
    type t = Pattern.t Sln_map.String.t [@@deriving show, yojson, eq]
  end

  type t = {
    branch : Branch.t; [@default Sln_map.String.empty]
    dest_branch : Branch.t; [@default Sln_map.String.empty]
  }
  [@@deriving make, show, yojson, eq]
end

module Tree_builder = struct
  type t = {
    enabled : bool; [@default false]
    script : string; [@default ""]
  }
  [@@deriving make, show, yojson, eq]
end

module Workflows = struct
  module Entry = struct
    module Op = struct
      type t =
        | Init of Workflow_step.Init.t
        | Plan of Workflow_step.Plan.t
        | Apply of Workflow_step.Apply.t
        | Run of Workflow_step.Run.t
        | Env of Workflow_step.Env.t
        | Oidc of Workflow_step.Oidc.t
        | Checkov of Workflow_step.Checkov.t
        | Conftest of Workflow_step.Conftest.t
        | Opa of Workflow_step.Opa.t
        | Gates of Workflow_step.Gates.t
      [@@deriving show, yojson, eq]
    end

    module Op_list = struct
      type t = Op.t list [@@deriving show, yojson, eq]
    end

    module Lock_policy = struct
      type t =
        | Apply
        | Merge
        | None
        | Strict
      [@@deriving show, yojson, eq]
    end

    type t = {
      apply : Op_list.t;
          [@default
            [ Op.Init (Workflow_step.Init.make ()); Op.Apply (Workflow_step.Apply.make ()) ]]
      engine : Engine.t; [@default Engine.(Terraform (Terraform.make ()))]
      environment : string option;
      integrations : Integrations.t; [@default Integrations.make ()]
      lock_policy : Lock_policy.t; [@default Lock_policy.Strict]
      plan : Op_list.t;
          [@default [ Op.Init (Workflow_step.Init.make ()); Op.Plan (Workflow_step.Plan.make ()) ]]
      runs_on : Yojson.Safe.t option; [@default None]
      tag_query : Tag_query.t;
    }
    [@@deriving make, show, yojson, eq]
  end

  type t = Entry.t list [@@deriving show, yojson, eq]
end

module View = struct
  type t = {
    access_control : Access_control.t; [@default Access_control.make ()]
    apply_requirements : Apply_requirements.t; [@default Apply_requirements.make ()]
    automerge : Automerge.t; [@default Automerge.make ()]
    batch_runs : Batch_runs.t; [@default Batch_runs.make ()]
    config_builder : Config_builder.t; [@default Config_builder.make ()]
    cost_estimation : Cost_estimation.t; [@default Cost_estimation.make ()]
    create_and_select_workspace : bool; [@default true]
    default_branch_overrides : Default_branch_overrides.t option; [@default None]
    destination_branches : Destination_branches.t; [@default []]
    dirs : Dirs.t; [@default Sln_map.String.empty]
    drift : Drift.t; [@default Drift.make ()]
    enabled : bool; [@default true]
    engine : Engine.t; [@default Engine.(Terraform (Terraform.make ()))]
    hooks : Hooks.t; [@default Hooks.make ()]
    indexer : Indexer.t; [@default Indexer.make ()]
    integrations : Integrations.t; [@default Integrations.make ()]
    notifications : Notifications.t; [@default Notifications.make ()]
    parallel_runs : int; [@default 3]
    stacks : Stacks.t; [@default Stacks.make ()]
    storage : Storage.t; [@default Storage.make ()]
    tags : Tags.t; [@default Tags.make ()]
    tree_builder : Tree_builder.t; [@default Tree_builder.make ()]
    when_modified : When_modified.t; [@default When_modified.make ()]
    workflows : Workflows.t; [@default []]
  }
  [@@deriving make, show, yojson, eq]
end

module Ctx = struct
  type t = {
    dest_branch : string;
    branch : string;
  }

  let make ~dest_branch ~branch () = { dest_branch; branch }
end

module Index = struct
  module Dep = struct
    type t = Module of string [@@deriving eq]
  end

  type t = {
    deps : Dep.t list Sln_map.String.t;
    symlinks : (string * string) list;
  }
  [@@deriving eq]

  let empty = { symlinks = []; deps = Sln_map.String.empty }
  let make ~symlinks deps = { symlinks; deps = Sln_map.String.of_list deps }
end

type raw
type derived
type 'a t = View.t

type of_version_1_err =
  [ `Access_control_ci_config_update_match_parse_err of string
  | `Access_control_file_match_parse_err of string * string
  | `Access_control_policy_apply_autoapprove_match_parse_err of string
  | `Access_control_policy_apply_force_match_parse_err of string
  | `Access_control_policy_apply_match_parse_err of string
  | `Access_control_policy_apply_with_superapproval_match_parse_err of string
  | `Access_control_policy_plan_match_parse_err of string
  | `Access_control_policy_superapproval_match_parse_err of string
  | `Access_control_policy_tag_query_err of string * string
  | `Access_control_terrateam_config_update_match_parse_err of string
  | `Access_control_unlock_match_parse_err of string
  | `Apply_requirements_approved_all_of_match_parse_err of string
  | `Apply_requirements_approved_any_of_match_parse_err of string
  | `Apply_requirements_check_tag_query_err of string * string
  | `Depends_on_err of string * string
  | `Drift_tag_query_err of string * string
  | `Glob_parse_err of string * string
  | `Notification_policy_tag_query_err of string * string
  | `Pattern_parse_err of string
  | `Stack_config_tag_query_err of string * string
  | `Window_parse_timezone_err of string
  | `Workflows_tag_query_parse_err of string * string
  ]
[@@deriving show]

type of_version_1_json_err =
  [ of_version_1_err
  | `Repo_config_schema_err of Jsonschema_check.Validation_err.t list
  ]
[@@deriving show]

let of_view = CCFun.id
let to_view = CCFun.id
let default = View.make ()

(* Converters for the sub elements *)
let of_version_1_match = Access_control.Match.make
let of_version_1_match_list = CCResult.map_l of_version_1_match

let of_version_1_access_control_files files =
  let module Ac = Terrat_repo_config_access_control in
  let files = Ac.Files.additional files in
  let ret =
    files
    |> Sln_map.String.to_list
    |> CCResult.map_l (fun (path, match_list) ->
        match of_version_1_match_list match_list with
        | Ok match_list -> Ok (path, match_list)
        | Error (`Match_parse_err err) -> Error (`Access_control_file_match_parse_err (path, err)))
  in
  let open CCResult.Infix in
  ret >>= fun r -> Ok (Sln_map.String.of_list r)

let of_version_1_access_control_policies policies =
  let module Acp = Terrat_repo_config_access_control_policy in
  CCResult.map_l
    (fun {
           Acp.apply;
           apply_autoapprove;
           apply_force;
           apply_with_superapproval;
           plan;
           superapproval;
           tag_query;
         }
       ->
      let open CCResult.Infix in
      CCResult.map_err
        (function
          | `Tag_query_error err -> `Access_control_policy_tag_query_err err)
        (Terrat_tag_query.of_string tag_query)
      >>= fun tag_query ->
      CCResult.map_err
        (function
          | `Match_parse_err err -> `Access_control_policy_apply_match_parse_err err)
        (map_opt of_version_1_match_list apply)
      >>= fun apply ->
      CCResult.map_err
        (function
          | `Match_parse_err err -> `Access_control_policy_apply_autoapprove_match_parse_err err)
        (map_opt of_version_1_match_list apply_autoapprove)
      >>= fun apply_autoapprove ->
      CCResult.map_err
        (function
          | `Match_parse_err err -> `Access_control_policy_apply_force_match_parse_err err)
        (map_opt of_version_1_match_list apply_force)
      >>= fun apply_force ->
      CCResult.map_err
        (function
          | `Match_parse_err err ->
              `Access_control_policy_apply_with_superapproval_match_parse_err err)
        (map_opt of_version_1_match_list apply_with_superapproval)
      >>= fun apply_with_superapproval ->
      CCResult.map_err
        (function
          | `Match_parse_err err -> `Access_control_policy_plan_match_parse_err err)
        (map_opt of_version_1_match_list plan)
      >>= fun plan ->
      CCResult.map_err
        (function
          | `Match_parse_err err -> `Access_control_policy_superapproval_match_parse_err err)
        (map_opt of_version_1_match_list superapproval)
      >>= fun superapproval ->
      Ok
        (Access_control.Policy.make
           ?apply
           ?apply_autoapprove
           ?apply_force
           ?apply_with_superapproval
           ?plan
           ?superapproval
           ~tag_query
           ()))
    policies

let get_apply_requirements_checks_approved =
  let open CCResult.Infix in
  let module Ap = Terrat_repo_config.Apply_requirements_checks_approved in
  let module Ap1 = Terrat_repo_config.Apply_requirements_checks_approved_1 in
  let module Ap2 = Terrat_repo_config.Apply_requirements_checks_approved_2 in
  function
  | Ap.Apply_requirements_checks_approved_1 { Ap1.count; enabled } ->
      Ok (Apply_requirements.Approved.make ~any_of_count:count ~enabled ())
  | Ap.Apply_requirements_checks_approved_2
      { Ap2.enabled; all_of; any_of; any_of_count; require_completed_reviews } ->
      CCResult.map_err
        (function
          | `Match_parse_err err -> `Apply_requirements_approved_all_of_match_parse_err err)
        (map_opt of_version_1_match_list all_of)
      >>= fun all_of ->
      CCResult.map_err
        (function
          | `Match_parse_err err -> `Apply_requirements_approved_any_of_match_parse_err err)
        (map_opt of_version_1_match_list any_of)
      >>= fun any_of ->
      Ok
        (Apply_requirements.Approved.make
           ~enabled
           ?all_of
           ?any_of
           ~any_of_count
           ~require_completed_reviews
           ())

let get_apply_requirements_checks_apply_after_merge =
  let module Afm = Terrat_repo_config_apply_requirements_checks_apply_after_merge in
  fun { Afm.enabled } -> Ok (Apply_requirements.Apply_after_merge.make ~enabled ())

let get_apply_requirements_checks_merge_conflicts =
  let module Mc = Terrat_repo_config_apply_requirements_checks_merge_conflicts in
  fun { Mc.enabled } -> Ok (Apply_requirements.Merge_conflicts.make ~enabled ())

let get_apply_requirements_checks_status_checks =
  let module Sc = Terrat_repo_config_apply_requirements_checks_status_checks in
  fun { Sc.enabled; ignore_matching } ->
    Ok (Apply_requirements.Status_checks.make ~enabled ?ignore_matching ())

let of_version_1_apply_requirements_checks =
  let module Ar = Apply_requirements in
  let module Trc = Terrat_repo_config in
  let module Checks = Trc.Apply_requirements_checks in
  let module C1 = Terrat_repo_config.Apply_requirements_checks_1 in
  let module C2 = Terrat_repo_config.Apply_requirements_checks_2 in
  function
  | None -> Ok [ Ar.Check.make ~tag_query:Terrat_tag_query.any () ]
  | Some (Checks.Apply_requirements_checks_1 { C1.approved; merge_conflicts; status_checks }) ->
      let open CCResult.Infix in
      map_opt get_apply_requirements_checks_approved approved
      >>= fun approved ->
      map_opt get_apply_requirements_checks_merge_conflicts merge_conflicts
      >>= fun merge_conflicts ->
      map_opt get_apply_requirements_checks_status_checks status_checks
      >>= fun status_checks ->
      Ok
        [
          Ar.Check.make ~tag_query:Terrat_tag_query.any ?approved ?merge_conflicts ?status_checks ();
        ]
  | Some (Checks.Apply_requirements_checks_2 checks) ->
      let open CCResult.Infix in
      let module I = C2.Items in
      CCResult.map_l
        (fun {
               I.apply_after_merge;
               approved;
               merge_conflicts;
               require_ready_for_review_pr;
               status_checks;
               tag_query;
             }
           ->
          CCResult.map_err
            (function
              | `Tag_query_error err -> `Apply_requirements_check_tag_query_err err)
            (Terrat_tag_query.of_string tag_query)
          >>= fun tag_query ->
          map_opt
            (fun ap ->
              get_apply_requirements_checks_approved
                (Trc.Apply_requirements_checks_approved.Apply_requirements_checks_approved_2 ap))
            approved
          >>= fun approved ->
          map_opt get_apply_requirements_checks_merge_conflicts merge_conflicts
          >>= fun merge_conflicts ->
          map_opt get_apply_requirements_checks_status_checks status_checks
          >>= fun status_checks ->
          map_opt get_apply_requirements_checks_apply_after_merge apply_after_merge
          >>= fun apply_after_merge ->
          Ok
            (Ar.Check.make
               ~require_ready_for_review_pr
               ~tag_query
               ?apply_after_merge
               ?approved
               ?merge_conflicts
               ?status_checks
               ()))
        checks

let of_version_1_file_patterns fp = CCResult.map_l File_pattern.make fp

let of_version_1_depends_on depends_on =
  let module D = Terrat_repo_config_depends_on in
  let module Obj = Terrat_repo_config_depends_on_object in
  match depends_on with
  | D.Depends_on_tag_query s ->
      CCResult.map
        (fun tag_query -> { Depends_on.tag_query; prune_on_no_change = false })
        (Terrat_tag_query.of_string s)
  | D.Depends_on_object { Obj.tag_query; prune_on_no_change } ->
      CCResult.map
        (fun tag_query -> { Depends_on.tag_query; prune_on_no_change })
        (Terrat_tag_query.of_string tag_query)

let of_version_1_dirs_when_modified default_when_modified when_modified =
  let open CCResult.Infix in
  let module Wm = When_modified in
  let module Wmn = Terrat_repo_config_when_modified_nullable in
  let { Wmn.autoapply; autoplan; autoplan_draft_pr; depends_on; file_patterns } = when_modified in
  let default_when_modified =
    CCOption.get_or ~default:(When_modified.make ()) default_when_modified
  in
  CCResult.map_err
    (function
      | _ -> failwith "nyi")
    (map_opt of_version_1_depends_on depends_on)
  >>= fun depends_on ->
  map_opt of_version_1_file_patterns file_patterns
  >>= fun file_patterns ->
  Ok
    (When_modified.make
       ?depends_on:(CCOption.or_ ~else_:default_when_modified.Wm.depends_on depends_on)
       ~autoapply:(CCOption.get_or ~default:default_when_modified.Wm.autoapply autoapply)
       ~autoplan:(CCOption.get_or ~default:default_when_modified.Wm.autoplan autoplan)
       ~autoplan_draft_pr:
         (CCOption.get_or ~default:default_when_modified.Wm.autoplan_draft_pr autoplan_draft_pr)
       ~file_patterns:
         (CCOption.get_or ~default:default_when_modified.Wm.file_patterns file_patterns)
       ())

let of_version_1_workspace default_when_modified workspace =
  let open CCResult.Infix in
  let module Ws = Terrat_repo_config_workspaces in
  let { Ws.Additional.tags; when_modified } = workspace in
  map_opt (of_version_1_dirs_when_modified default_when_modified) when_modified
  >>= fun when_modified ->
  let when_modified = CCOption.or_ ~else_:default_when_modified when_modified in
  Ok (Dirs.Workspace.make ?tags ?when_modified ())

let of_version_1_run_on =
  let module R = Workflow_step.Run_on in
  function
  | `Failure -> R.Failure
  | `Always -> R.Always
  | `Success -> R.Success

let of_version_1_visible_on =
  let module V = Workflow_step.Visible_on in
  function
  | `Always -> V.Always
  | `Failure -> V.Failure
  | `Success -> V.Success

let of_version_1_run_format =
  let module F = Workflow_step.Format in
  let module Fmt = Terrat_repo_config_hook_op_run_format in
  let module Obj = Terrat_repo_config_hook_op_run_format_obj in
  function
  | Fmt.Hook_op_run_format_str `Code -> F.Code
  | Fmt.Hook_op_run_format_str `Raw -> F.Raw
  | Fmt.Hook_op_run_format_str `Markdown -> F.Markdown
  | Fmt.Hook_op_run_format_obj { Obj.type_ = `Code; lang } -> F.Code_lang lang

let of_version_1_hook_op =
  let module Op = Terrat_repo_config_hook_op in
  function
  | Op.Hook_op_drift_create_issue op ->
      let module D = Terrat_repo_config_hook_op_drift_create_issue in
      let { D.group_by; type_ = _ } = op in
      let group_by =
        match group_by with
        | `All -> `All
        | `Dirspace -> `Dirspace
      in
      Ok (Hooks.Hook_op.Drift_create_issue { Hooks.Drift_create_issue.group_by })
  | Op.Hook_op_env_exec op ->
      let module Op = Terrat_repo_config_hook_op_env_exec in
      let { Op.cmd; method_ = _; name; sensitive; trim_trailing_newlines; type_ = _ } = op in
      Ok
        (Hooks.Hook_op.Env
           Workflow_step.Env.(Exec (Exec.make ~cmd ~name ~sensitive ~trim_trailing_newlines ())))
  | Op.Hook_op_env_source op ->
      let module Op = Terrat_repo_config_hook_op_env_source in
      let { Op.cmd; method_ = _; sensitive; type_ = _ } = op in
      Ok (Hooks.Hook_op.Env Workflow_step.Env.(Source (Source.make ~cmd ~sensitive ())))
  | Op.Hook_op_oidc op -> (
      let module Op = Terrat_repo_config_hook_op_oidc in
      let module Aws = Terrat_repo_config_hook_op_oidc_aws in
      let module Azure = Terrat_repo_config_hook_op_oidc_azure in
      let module Gcp = Terrat_repo_config_hook_op_oidc_gcp in
      match op with
      | Op.Hook_op_oidc_aws
          {
            Aws.assume_role_arn;
            assume_role_enabled;
            audience;
            duration;
            provider = _;
            region;
            role_arn;
            session_name;
            type_ = _;
          } ->
          Ok
            (Hooks.Hook_op.Oidc
               Workflow_step.Oidc.(
                 Aws
                   (Aws.make
                      ?assume_role_arn
                      ?audience
                      ~assume_role_enabled
                      ~duration
                      ~region
                      ~role_arn
                      ~session_name
                      ())))
      | Op.Hook_op_oidc_azure
          { Azure.audience; client_id; provider = _; subscription_id; tenant_id; type_ = _ } ->
          Ok
            (Hooks.Hook_op.Oidc
               Workflow_step.Oidc.(
                 Azure (Azure.make ?audience ?subscription_id ~client_id ~tenant_id ())))
      | Op.Hook_op_oidc_gcp
          {
            Gcp.access_token_lifetime;
            access_token_subject;
            audience;
            project_id;
            provider = _;
            service_account;
            type_ = _;
            workload_identity_provider;
          } ->
          Ok
            (Hooks.Hook_op.Oidc
               Workflow_step.Oidc.(
                 Gcp
                   (Gcp.make
                      ?access_token_subject
                      ?audience
                      ?project_id
                      ~access_token_lifetime
                      ~service_account
                      ~workload_identity_provider
                      ()))))
  | Op.Hook_op_run op ->
      let open CCResult.Infix in
      let module Op = Terrat_repo_config_hook_op_run in
      let {
        Op.capture_output;
        cmd;
        env;
        format;
        run_on;
        type_ = _;
        ignore_errors;
        visible_on;
        on_error;
      } =
        op
      in
      let run_on = CCOption.map of_version_1_run_on run_on in
      let visible_on = CCOption.map of_version_1_visible_on visible_on in
      let format = CCOption.map of_version_1_run_format format in
      map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
      >>= fun env ->
      Ok
        (Hooks.Hook_op.Run
           (Workflow_step.Run.make
              ~capture_output
              ~cmd
              ~ignore_errors
              ?visible_on
              ?env
              ?format
              ?run_on
              ?on_error
              ()))
  | Op.Hook_op_gates op ->
      let open CCResult.Infix in
      let module Op = Terrat_repo_config_hook_op_gates in
      let { Op.cmd; env; run_on; type_ = _ } = op in
      let run_on = CCOption.map of_version_1_run_on run_on in
      map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
      >>= fun env -> Ok (Hooks.Hook_op.Gates (Workflow_step.Gates.make ~cmd ?env ?run_on ()))
  | Op.Hook_op_slack _ -> assert false

let of_version_1_drift_schedule = function
  | `Hourly -> Drift.Schedule.Sched.Hourly
  | `Daily -> Drift.Schedule.Sched.Daily
  | `Weekly -> Drift.Schedule.Sched.Weekly
  | `Monthly -> Drift.Schedule.Sched.Monthly

let of_version_1_workflow_op_plan_mode = function
  | `Strict -> Workflow_step.Plan.Mode.Strict
  | `Fast_and_loose -> Workflow_step.Plan.Mode.Fast_and_loose

let of_version_1_gate gate =
  let module G = Terrat_repo_config_gate in
  let { G.all_of; any_of; any_of_count; token; name } = gate in
  Ok { Workflow_step.Gate.all_of; any_of; any_of_count; token; name }

let of_version_1_workflow_op_list ops =
  let open CCResult.Infix in
  let module Op = Terrat_repo_config_workflow_op_list.Items in
  let module O = Workflows.Entry.Op in
  CCResult.map_l
    (function
      | Op.Workflow_op_init op ->
          let module Op = Terrat_repo_config_workflow_op_init in
          let { Op.env; extra_args; type_ = _ } = op in
          map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
          >>= fun env -> Ok (O.Init (Workflow_step.Init.make ?env ?extra_args ()))
      | Op.Workflow_op_plan op ->
          let module Op = Terrat_repo_config_workflow_op_plan in
          let { Op.env; extra_args; mode; type_ = _ } = op in
          let mode = of_version_1_workflow_op_plan_mode mode in
          map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
          >>= fun env -> Ok (O.Plan (Workflow_step.Plan.make ?env ?extra_args ~mode ()))
      | Op.Workflow_op_apply op ->
          let module R = Terrat_repo_config_retry in
          let module Op = Terrat_repo_config_workflow_op_apply in
          let { Op.env; extra_args; retry; type_ = _ } = op in
          map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
          >>= fun env ->
          map_opt
            (fun { R.backoff; enabled; initial_sleep; tries } ->
              Ok (Workflow_step.Retry.make ~backoff ~enabled ~initial_sleep ~tries ()))
            retry
          >>= fun retry -> Ok (O.Apply (Workflow_step.Apply.make ?env ?extra_args ?retry ()))
      | Op.Hook_op_run op ->
          let module Op = Terrat_repo_config_hook_op_run in
          let {
            Op.capture_output;
            cmd;
            env;
            format;
            run_on;
            type_ = _;
            ignore_errors;
            visible_on;
            on_error;
          } =
            op
          in
          let run_on = CCOption.map of_version_1_run_on run_on in
          let visible_on = CCOption.map of_version_1_visible_on visible_on in
          let format = CCOption.map of_version_1_run_format format in
          map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
          >>= fun env ->
          Ok
            (O.Run
               (Workflow_step.Run.make
                  ~capture_output
                  ~cmd
                  ~ignore_errors
                  ?env
                  ?format
                  ?run_on
                  ?visible_on
                  ?on_error
                  ()))
      | Op.Hook_op_gates op ->
          let module Op = Terrat_repo_config_hook_op_gates in
          let { Op.cmd; env; run_on; type_ = _ } = op in
          let run_on = CCOption.map of_version_1_run_on run_on in
          map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
          >>= fun env -> Ok (O.Gates (Workflow_step.Gates.make ~cmd ?env ?run_on ()))
      | Op.Hook_op_slack _ -> assert false
      | Op.Hook_op_env_exec op ->
          let module Op = Terrat_repo_config_hook_op_env_exec in
          let { Op.cmd; method_ = _; name; sensitive; trim_trailing_newlines; type_ = _ } = op in
          Ok
            (O.Env
               Workflow_step.Env.(Exec (Exec.make ~cmd ~name ~sensitive ~trim_trailing_newlines ())))
      | Op.Hook_op_env_source op ->
          let module Op = Terrat_repo_config_hook_op_env_source in
          let { Op.cmd; method_ = _; sensitive; type_ = _ } = op in
          Ok (O.Env Workflow_step.Env.(Source (Source.make ~cmd ~sensitive ())))
      | Op.Hook_op_oidc op -> (
          let module Op = Terrat_repo_config_hook_op_oidc in
          let module Aws = Terrat_repo_config_hook_op_oidc_aws in
          let module Azure = Terrat_repo_config_hook_op_oidc_azure in
          let module Gcp = Terrat_repo_config_hook_op_oidc_gcp in
          match op with
          | Op.Hook_op_oidc_aws
              {
                Aws.assume_role_arn;
                assume_role_enabled;
                audience;
                duration;
                provider = _;
                region;
                role_arn;
                session_name;
                type_ = _;
              } ->
              Ok
                (O.Oidc
                   Workflow_step.Oidc.(
                     Aws
                       (Aws.make
                          ?assume_role_arn
                          ?audience
                          ~assume_role_enabled
                          ~duration
                          ~region
                          ~role_arn
                          ~session_name
                          ())))
          | Op.Hook_op_oidc_azure
              { Azure.audience; client_id; provider = _; subscription_id; tenant_id; type_ = _ } ->
              Ok
                (O.Oidc
                   Workflow_step.Oidc.(
                     Azure (Azure.make ?audience ?subscription_id ~client_id ~tenant_id ())))
          | Op.Hook_op_oidc_gcp
              {
                Gcp.access_token_lifetime;
                access_token_subject;
                audience;
                project_id;
                provider = _;
                service_account;
                type_ = _;
                workload_identity_provider;
              } ->
              Ok
                (O.Oidc
                   Workflow_step.Oidc.(
                     Gcp
                       (Gcp.make
                          ?access_token_subject
                          ?audience
                          ?project_id
                          ~access_token_lifetime
                          ~service_account
                          ~workload_identity_provider
                          ()))))
      | Op.Workflow_op_conftest op ->
          let module Op = Terrat_repo_config_workflow_op_conftest in
          let { Op.env; extra_args; gate; ignore_errors; run_on; visible_on; type_ = _ } = op in
          let run_on = CCOption.map of_version_1_run_on run_on in
          let visible_on = CCOption.map of_version_1_visible_on visible_on in
          map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
          >>= fun env ->
          map_opt of_version_1_gate gate
          >>= fun gate ->
          let extra_args = CCOption.get_or ~default:[] extra_args in
          Ok
            (O.Conftest
               (Workflow_step.Conftest.make
                  ?env
                  ~extra_args
                  ~gate
                  ~ignore_errors
                  ?run_on
                  ?visible_on
                  ()))
      | Op.Workflow_op_checkov op ->
          let module Op = Terrat_repo_config_workflow_op_checkov in
          let { Op.env; extra_args; gate; ignore_errors; run_on; visible_on; type_ = _ } = op in
          let run_on = CCOption.map of_version_1_run_on run_on in
          let visible_on = CCOption.map of_version_1_visible_on visible_on in
          map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
          >>= fun env ->
          map_opt of_version_1_gate gate
          >>= fun gate ->
          let extra_args = CCOption.get_or ~default:[] extra_args in
          Ok
            (O.Checkov
               (Workflow_step.Checkov.make
                  ?env
                  ~extra_args
                  ~gate
                  ~ignore_errors
                  ?run_on
                  ?visible_on
                  ()))
      | Op.Workflow_op_opa op ->
          let module Op = Terrat_repo_config_workflow_op_opa in
          let { Op.env; extra_args; fail_on; gate; ignore_errors; run_on; visible_on; type_ = _ } =
            op
          in
          let fail_on =
            match fail_on with
            | `Defined -> Workflow_step.Opa.Fail_on.Defined
            | `Undefined -> Workflow_step.Opa.Fail_on.Undefined
          in
          let run_on = CCOption.map of_version_1_run_on run_on in
          let visible_on = CCOption.map of_version_1_visible_on visible_on in
          map_opt (fun { Op.Env.additional; _ } -> Ok additional) env
          >>= fun env ->
          map_opt of_version_1_gate gate
          >>= fun gate ->
          let extra_args = CCOption.get_or ~default:[] extra_args in
          Ok
            (O.Opa
               (Workflow_step.Opa.make
                  ?env
                  ~extra_args
                  ~fail_on
                  ~gate
                  ~ignore_errors
                  ?run_on
                  ?visible_on
                  ())))
    ops

let of_version_1_engine_tf_outputs outputs =
  let module O = Terrat_repo_config.Engine_tf_outputs in
  let { O.collect } = outputs in
  Engine.Tf_outputs.make ?collect ()

let of_version_1_workflow_engine cdktf terraform_version terragrunt default_engine engine =
  let ( default_tf_cmd,
        default_tf_version,
        default_override_tf_cmd,
        default_wrapper_version,
        default_tf_outputs ) =
    match default_engine with
    | Some Engine.(Opentofu { Opentofu.version; override_tf_cmd; outputs; _ }) ->
        (Some "tofu", version, override_tf_cmd, None, Some outputs)
    | Some
        Engine.(Terragrunt { Terragrunt.tf_cmd; tf_version; version; override_tf_cmd; outputs; _ })
      -> (Some tf_cmd, tf_version, override_tf_cmd, version, Some outputs)
    | Some Engine.(Terraform { Terraform.version; override_tf_cmd; outputs; _ }) ->
        (Some "terraform", version, override_tf_cmd, None, Some outputs)
    | _ -> (Some "terraform", None, None, None, None)
  in
  match (cdktf, terraform_version, terragrunt, engine) with
  | _, _, _, Some engine -> (
      let module E = Terrat_repo_config_engine in
      match engine with
      | E.Engine_other _ as other -> Ok (Some (Engine.Other (E.to_yojson other)))
      | E.Engine_custom custom ->
          let module E = Terrat_repo_config_engine_custom in
          let { E.apply; init; plan; diff; unsafe_apply; outputs; name = _ } = custom in
          Ok (Some Engine.(Custom (Custom.make ?apply ?init ?plan ?diff ?unsafe_apply ?outputs ())))
      | E.Engine_fly fly ->
          let module E = Terrat_repo_config_engine_fly in
          let { E.config_file; name = _ } = fly in
          Ok (Some Engine.(Fly (Fly.make ~config_file)))
      | E.Engine_cdktf cdktf ->
          let module E = Terrat_repo_config_engine_cdktf in
          Ok
            (Some
               Engine.(
                 Cdktf
                   (Cdktf.make
                      ?outputs:
                        (CCOption.or_ ~else_:default_tf_outputs
                        @@ CCOption.map of_version_1_engine_tf_outputs cdktf.E.outputs)
                      ?override_tf_cmd:
                        (CCOption.or_ ~else_:default_override_tf_cmd cdktf.E.override_tf_cmd)
                      ?tf_cmd:(CCOption.or_ ~else_:default_tf_cmd cdktf.E.tf_cmd)
                      ?tf_version:(CCOption.or_ ~else_:default_tf_version cdktf.E.tf_version)
                      ())))
      | E.Engine_opentofu ot ->
          let module E = Terrat_repo_config_engine_opentofu in
          Ok
            (Some
               Engine.(
                 Opentofu
                   (Opentofu.make
                      ?version:(CCOption.or_ ~else_:default_tf_version ot.E.version)
                      ?outputs:
                        (CCOption.or_ ~else_:default_tf_outputs
                        @@ CCOption.map of_version_1_engine_tf_outputs ot.E.outputs)
                      ?override_tf_cmd:
                        (CCOption.or_ ~else_:default_override_tf_cmd ot.E.override_tf_cmd)
                      ())))
      | E.Engine_terraform tf ->
          let module E = Terrat_repo_config_engine_terraform in
          Ok
            (Some
               Engine.(
                 Terraform
                   (Terraform.make
                      ?version:(CCOption.or_ ~else_:default_tf_version tf.E.version)
                      ?outputs:
                        (CCOption.or_ ~else_:default_tf_outputs
                        @@ CCOption.map of_version_1_engine_tf_outputs tf.E.outputs)
                      ?override_tf_cmd:
                        (CCOption.or_ ~else_:default_override_tf_cmd tf.E.override_tf_cmd)
                      ())))
      | E.Engine_terragrunt tg ->
          let module E = Terrat_repo_config_engine_terragrunt in
          Ok
            (Some
               Engine.(
                 Terragrunt
                   (Terragrunt.make
                      ?outputs:
                        (CCOption.or_ ~else_:default_tf_outputs
                        @@ CCOption.map of_version_1_engine_tf_outputs tg.E.outputs)
                      ?override_tf_cmd:
                        (CCOption.or_ ~else_:default_override_tf_cmd tg.E.override_tf_cmd)
                      ?tf_cmd:(CCOption.or_ ~else_:default_tf_cmd tg.E.tf_cmd)
                      ?tf_version:(CCOption.or_ ~else_:default_tf_version tg.E.tf_version)
                      ?version:(CCOption.or_ ~else_:default_wrapper_version tg.E.version)
                      ())))
      | E.Engine_pulumi _ -> Ok (Some Engine.Pulumi)
      | E.Engine_stategraph sg ->
          let module E = Terrat_repo_config_engine_stategraph in
          Ok
            (Some
               Engine.(
                 Stategraph
                   (Stategraph.make
                      ?outputs:
                        (CCOption.or_ ~else_:default_tf_outputs
                        @@ CCOption.map of_version_1_engine_tf_outputs sg.E.outputs)
                      ?override_tf_cmd:
                        (CCOption.or_ ~else_:default_override_tf_cmd sg.E.override_tf_cmd)
                      ?tf_cmd:(CCOption.or_ ~else_:default_tf_cmd sg.E.tf_cmd)
                      ?tf_version:(CCOption.or_ ~else_:default_tf_version sg.E.tf_version)
                      ?version:(CCOption.or_ ~else_:default_wrapper_version sg.E.version)
                      ()))))
  | true, _, _, _ ->
      (* Cdktf *)
      Ok (Some Engine.(Cdktf (Cdktf.make ?tf_cmd:default_tf_cmd ?tf_version:default_tf_version ())))
  | _, Some terraform_version, _, None ->
      Ok
        (Some
           Engine.(
             Terraform
               (Terraform.make
                  ~version:terraform_version
                  ?override_tf_cmd:default_override_tf_cmd
                  ())))
  | _, _, true, None ->
      (* Terragrunt *)
      Ok
        (Some
           Engine.(
             Terragrunt
               (Terragrunt.make
                  ?tf_cmd:default_tf_cmd
                  ?tf_version:default_tf_version
                  ?version:default_wrapper_version
                  ?override_tf_cmd:default_override_tf_cmd
                  ())))
  | _, _, _, None -> Ok default_engine

let of_version_1_workflow_integrations default_integrations integrations =
  let open CCResult.Infix in
  let module I = Terrat_repo_config_integrations in
  match integrations with
  | Some { I.resourcely } ->
      map_opt
        (fun { I.Resourcely.enabled; extra_args } ->
          Ok (Integrations.Resourcely.make ~enabled ?extra_args ()))
        resourcely
      >>= fun resourcely -> Ok (Some (Integrations.make ?resourcely ()))
  | None -> Ok default_integrations

(* Converters for the top level fields *)
let of_version_1_access_control access_control =
  let open CCResult.Infix in
  let module Ac = Terrat_repo_config_access_control in
  let {
    Ac.apply_require_all_dirspace_access;
    ci_config_update;
    enabled;
    files;
    plan_require_all_dirspace_access;
    policies;
    terrateam_config_update;
    unlock;
  } =
    access_control
  in
  CCResult.map_err
    (function
      | `Match_parse_err err -> `Access_control_ci_config_update_match_parse_err err)
    (map_opt of_version_1_match_list ci_config_update)
  >>= fun ci_config_update ->
  CCResult.map_err
    (function
      | `Match_parse_err err -> `Access_control_terrateam_config_update_match_parse_err err)
    (map_opt of_version_1_match_list terrateam_config_update)
  >>= fun terrateam_config_update ->
  map_opt of_version_1_access_control_files files
  >>= fun files ->
  CCResult.map_err
    (function
      | `Match_parse_err err -> `Access_control_unlock_match_parse_err err)
    (map_opt of_version_1_match_list unlock)
  >>= fun unlock ->
  map_opt of_version_1_access_control_policies policies
  >>= fun policies ->
  Ok
    (Access_control.make
       ~apply_require_all_dirspace_access
       ?ci_config_update
       ~enabled
       ?files
       ~plan_require_all_dirspace_access
       ?policies
       ?terrateam_config_update
       ?unlock
       ())

let of_version_1_apply_requirements apply_requirements =
  let open CCResult.Infix in
  let module Ar = Terrat_repo_config_apply_requirements in
  let { Ar.checks; create_pending_apply_check; create_completed_apply_check_on_noop } =
    apply_requirements
  in
  of_version_1_apply_requirements_checks checks
  >>= fun checks ->
  Ok
    (Apply_requirements.make
       ~checks
       ~create_pending_apply_check
       ~create_completed_apply_check_on_noop
       ())

let of_version_automerge automerge =
  let module Am = Terrat_repo_config_automerge in
  let { Am.delete_branch; enabled; merge_strategy; require_explicit_apply; retain_pr_title } =
    automerge
  in
  let merge_strategy = Automerge.Merge_strategy.make merge_strategy in
  Ok
    (Automerge.make
       ~delete_branch
       ~enabled
       ~merge_strategy
       ~require_explicit_apply
       ~retain_pr_title
       ())

let of_version_1_batch_runs batch_runs =
  let module Br = Terrat_repo_config_batch_runs in
  let { Br.enabled; max_workspaces_per_batch } = batch_runs in
  Ok (Batch_runs.make ~enabled ~max_workspaces_per_batch ())

let of_version_1_config_builder { Terrat_repo_config.Config_builder.enabled; script } =
  Ok (Config_builder.make ~enabled ?script ())

let of_version_1_tree_builder { Terrat_repo_config.Tree_builder.enabled; script } =
  Ok (Tree_builder.make ~enabled ?script ())

let of_version_1_cost_estimation { V1.Cost_estimation.currency; enabled; provider = `Infracost } =
  Ok (Cost_estimation.make ~currency ~enabled ())

let of_version_1_destination_branches destination_branches =
  let module I = V1.Destination_branches.Items in
  let module Obj = Terrat_repo_config_destination_branch_object in
  let module Ds = Destination_branches.Destination_branch in
  CCResult.map_l
    (function
      | I.Destination_branch_name branch -> Ok (Ds.make ~branch ())
      | I.Destination_branch_object { Obj.branch; source_branches } ->
          Ok (Ds.make ~branch ?source_branches ()))
    destination_branches

let of_version_1_when_modified when_modified =
  let open CCResult.Infix in
  let module Wm = Terrat_repo_config_when_modified in
  let update_file_patterns =
    (* Put a ${DIR} in front of the default when modified.  The when modified
       configuration in the repo config implicitly has this.  In
       {!synthesize_dir_config} we are making the dir configuration to match every
       file, so we need the default config to work as if it were written as a dir
       config.

       The rule is if then when_modified entry starts with globbing, then we
       actually want to put the '${DIR}' in front.  For example, [*.hcl] should map
       to [${DIR}/*.hcl].  If it starts with [**] then we want to remove that and
       replace it with [${DIR}] so that it does not match subdirs. *)
    CCList.map (function
      | s when CCString.prefix ~pre:"!**/" s -> "!${DIR}/" ^ CCString.drop 4 s
      | s when CCString.prefix ~pre:"!*" s -> "!${DIR}/" ^ CCString.drop 1 s
      | s when CCString.prefix ~pre:"**/" s -> "${DIR}/" ^ CCString.drop 3 s
      | s when CCString.prefix ~pre:"*" s -> "${DIR}/" ^ s
      | s -> s)
  in
  let { Wm.autoapply; autoplan; autoplan_draft_pr; depends_on; file_patterns } = when_modified in
  CCResult.map_err
    (function
      | `Tag_query_error err -> `Depends_on_err err)
    (map_opt of_version_1_depends_on depends_on)
  >>= fun depends_on ->
  of_version_1_file_patterns (update_file_patterns file_patterns)
  >>= fun file_patterns ->
  Ok (When_modified.make ?depends_on ~autoapply ~autoplan ~autoplan_draft_pr ~file_patterns ())

let of_version_1_dirs default_when_modified { V1.Dirs.additional; _ } =
  let open CCResult.Infix in
  let module D = Terrat_repo_config_dir in
  let module Ws = Terrat_repo_config_workspaces in
  let of_workspace default_when_modified { Ws.additional; _ } =
    CCResult.fold_l
      (fun acc (key, value) ->
        let open CCResult.Infix in
        of_version_1_workspace default_when_modified value
        >>= fun workspace -> Ok (Sln_map.String.add key workspace acc))
      Sln_map.String.empty
      (Sln_map.String.to_list additional)
  in
  CCResult.map_l
    (fun ( dir,
           {
             D.create_and_select_workspace;
             create_if_missing;
             lock_branch_target;
             stacks;
             tags;
             when_modified;
             workspaces;
           } )
       ->
      map_opt (of_version_1_dirs_when_modified default_when_modified) when_modified
      >>= fun when_modified ->
      let when_modified = CCOption.or_ ~else_:default_when_modified when_modified in
      let stacks, workspaces =
        if CCOption.is_none stacks && CCOption.is_none workspaces then
          ( stacks,
            Some
              (Ws.make
                 ~additional:(Sln_map.String.of_list [ ("default", Ws.Additional.make ()) ])
                 Json_schema.Empty_obj.t) )
        else (stacks, workspaces)
      in
      map_opt (of_workspace when_modified) stacks
      >>= fun stacks ->
      map_opt (of_workspace when_modified) workspaces
      >>= fun workspaces ->
      let lock_branch_target =
        CCOption.map
          (function
            | `All -> Dirs.Dir.Branch_target.All
            | `Dest_branch -> Dirs.Dir.Branch_target.Dest_branch)
          lock_branch_target
      in
      Ok
        ( dir,
          Dirs.Dir.make
            ~create_and_select_workspace
            ~create_if_missing
            ?lock_branch_target
            ?stacks
            ?tags
            ?workspaces
            () ))
    (Sln_map.String.to_list additional)
  >>= fun dirs -> Ok (Sln_map.String.of_list dirs)

let of_version_1_drift_1 drift =
  let open CCResult.Infix in
  let module Dr = Terrat_repo_config_drift_1 in
  let { Dr.enabled; reconcile; schedule; tag_query } = drift in
  let schedule = of_version_1_drift_schedule schedule in
  CCResult.map_err
    (function
      | `Tag_query_error err -> `Drift_tag_query_err err)
    (map_opt Terrat_tag_query.of_string tag_query)
  >>= fun tag_query ->
  let tag_query = CCOption.get_or ~default:Tag_query.any tag_query in
  Ok
    (Drift.make
       ~enabled
       ~schedules:
         (Sln_map.String.of_list
            [ ("default", Drift.Schedule.make ~tag_query ~schedule ~reconcile ()) ])
       ())

let of_version_1_drift_2 drift =
  let open CCResult.Infix in
  let module Dr = Terrat_repo_config_drift_2 in
  let module Schedule = Terrat_repo_config_drift_schedule in
  let { Dr.enabled; schedules } = drift in
  CCResult.map_l
    (fun (name, { Schedule.tag_query; reconcile; schedule; window }) ->
      let schedule = of_version_1_drift_schedule schedule in
      CCResult.map_err
        (function
          | `Tag_query_error err -> `Drift_tag_query_err err)
        (Terrat_tag_query.of_string tag_query)
      >>= fun tag_query ->
      map_opt (fun { Schedule.Window.start; end_ } -> Drift.Window.make ~start ~end_ ()) window
      >>= fun window -> Ok (name, Drift.Schedule.make ~tag_query ~reconcile ~schedule ?window ()))
    (Sln_map.String.to_list @@ Dr.Schedules.additional schedules)
  >>= fun schedules -> Ok (Drift.make ~enabled ~schedules:(Sln_map.String.of_list schedules) ())

let of_version_1_drift =
  let module V1 = Terrat_repo_config_version_1 in
  function
  | V1.Drift.Drift_1 drift -> of_version_1_drift_1 drift
  | V1.Drift.Drift_2 drift -> of_version_1_drift_2 drift

let of_version_1_engine default_tf_version engine =
  match (default_tf_version, engine) with
  | _, Some engine -> (
      let module E = Terrat_repo_config_engine in
      match engine with
      | E.Engine_other _ as other -> Ok (Some (Engine.Other (E.to_yojson other)))
      | E.Engine_custom custom ->
          let module E = Terrat_repo_config_engine_custom in
          let { E.apply; init; plan; diff; unsafe_apply; outputs; name = _ } = custom in
          Ok (Some Engine.(Custom (Custom.make ?apply ?init ?plan ?diff ?unsafe_apply ?outputs ())))
      | E.Engine_fly fly ->
          let module E = Terrat_repo_config_engine_fly in
          let { E.config_file; name = _ } = fly in
          Ok (Some Engine.(Fly (Fly.make ~config_file)))
      | E.Engine_cdktf cdktf ->
          let module E = Terrat_repo_config_engine_cdktf in
          Ok
            (Some
               Engine.(
                 Cdktf
                   (Cdktf.make
                      ?tf_cmd:cdktf.E.tf_cmd
                      ?tf_version:cdktf.E.tf_version
                      ?outputs:(CCOption.map of_version_1_engine_tf_outputs cdktf.E.outputs)
                      ?override_tf_cmd:cdktf.E.override_tf_cmd
                      ())))
      | E.Engine_opentofu ot ->
          let module E = Terrat_repo_config_engine_opentofu in
          Ok
            (Some
               Engine.(
                 Opentofu
                   (Opentofu.make
                      ?version:ot.E.version
                      ?outputs:(CCOption.map of_version_1_engine_tf_outputs ot.E.outputs)
                      ?override_tf_cmd:ot.E.override_tf_cmd
                      ())))
      | E.Engine_terraform tf ->
          let module E = Terrat_repo_config_engine_terraform in
          Ok
            (Some
               Engine.(
                 Terraform
                   (Terraform.make
                      ?version:tf.E.version
                      ?outputs:(CCOption.map of_version_1_engine_tf_outputs tf.E.outputs)
                      ?override_tf_cmd:tf.E.override_tf_cmd
                      ())))
      | E.Engine_terragrunt tg ->
          let module E = Terrat_repo_config_engine_terragrunt in
          Ok
            (Some
               Engine.(
                 Terragrunt
                   (Terragrunt.make
                      ?tf_cmd:tg.E.tf_cmd
                      ?tf_version:tg.E.tf_version
                      ?version:tg.E.version
                      ?outputs:(CCOption.map of_version_1_engine_tf_outputs tg.E.outputs)
                      ?override_tf_cmd:tg.E.override_tf_cmd
                      ())))
      | E.Engine_pulumi _ -> Ok (Some Engine.Pulumi)
      | E.Engine_stategraph sg ->
          let module E = Terrat_repo_config_engine_stategraph in
          Ok
            (Some
               Engine.(
                 Stategraph
                   (Stategraph.make
                      ?tf_cmd:sg.E.tf_cmd
                      ?tf_version:(CCOption.or_ ~else_:default_tf_version sg.E.tf_version)
                      ?version:sg.E.version
                      ?outputs:(CCOption.map of_version_1_engine_tf_outputs sg.E.outputs)
                      ?override_tf_cmd:sg.E.override_tf_cmd
                      ()))))
  | Some default_tf_version, _ ->
      Ok (Some Engine.(Terraform (Terraform.make ~version:default_tf_version ())))
  | None, None -> Ok None

let of_version_1_hooks_hook hook =
  let open CCResult.Infix in
  let module H = Terrat_repo_config_hook in
  let { H.post; pre } = hook in
  map_opt (CCResult.map_l of_version_1_hook_op) post
  >>= fun post ->
  map_opt (CCResult.map_l of_version_1_hook_op) pre
  >>= fun pre -> Ok (Hooks.Hook.make ?pre ?post ())

let of_version_1_hooks { V1.Hooks.all; apply; plan } =
  let open CCResult.Infix in
  map_opt of_version_1_hooks_hook all
  >>= fun all ->
  map_opt of_version_1_hooks_hook apply
  >>= fun apply ->
  map_opt of_version_1_hooks_hook plan >>= fun plan -> Ok (Hooks.make ?all ?apply ?plan ())

let of_version_1_indexer { V1.Indexer.build_tag; enabled } = Ok { Indexer.build_tag; enabled }

let of_version_1_integrations integrations =
  let module I = Terrat_repo_config_integrations in
  let { I.resourcely } = integrations in
  let resourcely =
    CCOption.map_or
      ~default:(Integrations.Resourcely.make ())
      (fun { I.Resourcely.enabled; extra_args } ->
        { Integrations.Resourcely.enabled; extra_args = CCOption.get_or ~default:[] extra_args })
      resourcely
  in
  Ok { Integrations.resourcely }

let of_version_1_stack_config names =
  let open CCResult.Infix in
  let module N = Terrat_repo_config_stacks.Names in
  let { N.additional = configs; _ } = names in
  CCResult.map_l (fun (k, v) ->
      let module S = Terrat_repo_config_stacks.Names.Additional in
      let module Sc = Terrat_repo_config_stack_config in
      let module Sn = Terrat_repo_config_stack_nested_config in
      let module V = Terrat_repo_config_stack_variables in
      (match v with
        | S.Stack_config { Sc.tag_query; rules; variables } ->
            CCResult.map_err
              (function
                | `Tag_query_error err -> `Stack_config_tag_query_err err)
              (Terrat_tag_query.of_string tag_query)
            >>= fun tag_query -> Ok (Stacks.Type_.Stack tag_query, rules, variables)
        | S.Stack_nested_config { Sn.stacks; rules; variables } ->
            Ok (Stacks.Type_.Nested stacks, rules, variables))
      >>= fun (type_, rules, variables) ->
      let module R = Terrat_repo_config_stack_rules in
      let { R.apply_after; auto_apply; modified_by; plan_after } =
        CCOption.get_or
          ~default:
            { R.apply_after = None; auto_apply = None; modified_by = None; plan_after = None }
          rules
      in
      let rules =
        {
          Stacks.Rules.apply_after = CCOption.get_or ~default:[] apply_after;
          auto_apply;
          modified_by = CCOption.get_or ~default:[] modified_by;
          plan_after = CCOption.get_or ~default:[] (CCOption.or_ ~else_:modified_by plan_after);
        }
      in
      let variables = CCOption.map (fun { V.additional = variables; _ } -> variables) variables in
      Ok (k, Stacks.Stack.make ~type_ ~rules ?variables ()))
  @@ Sln_map.String.to_list configs
  >>= fun configs -> Ok (Sln_map.String.of_list configs)

let of_version_1_stacks stacks =
  let open CCResult.Infix in
  let module S = Terrat_repo_config_stacks in
  let { S.names } = stacks in
  map_opt of_version_1_stack_config names >>= fun names -> Ok (Stacks.make ?names ())

let of_version_1_notification_policy policy =
  let open CCResult.Infix in
  let module P = Terrat_repo_config_notification_policy in
  let module Policy = Notifications.Policy in
  let { P.tag_query; comment_strategy } = policy in
  CCResult.map_err
    (function
      | `Tag_query_error err -> `Notification_policy_tag_query_err err)
    (Terrat_tag_query.of_string tag_query)
  >>= fun tag_query ->
  (match comment_strategy with
    | `Append -> Ok Policy.Strategy.Append
    | `Delete -> Ok Policy.Strategy.Delete
    | `Minimize -> Ok Policy.Strategy.Minimize)
  >>= fun comment_strategy -> Ok { Policy.tag_query; comment_strategy }

let of_version_1_notifications notifications =
  let open CCResult.Infix in
  let module N = Terrat_repo_config_notifications in
  let module Sn = Terrat_repo_config_notifications_summary in
  let { N.policies; summary } = notifications in
  let policies = CCOption.get_or ~default:[] policies in
  let summary =
    match summary with
    | Some { Sn.enabled } -> { Notifications.Summary.enabled }
    | None -> Notifications.Summary.make ()
  in
  CCResult.map_l of_version_1_notification_policy policies
  >>= fun policies -> Ok { Notifications.policies; summary }

let of_version_1_storage storage =
  let open CCResult.Infix in
  let { V1.Storage.plans } = storage in
  CCOption.map_or
    ~default:(Ok Storage.Plans.Terrateam)
    (function
      | V1.Storage.Plans.Storage_plan_terrateam _ -> Ok Storage.Plans.Terrateam
      | V1.Storage.Plans.Storage_plan_cmd v ->
          let module Cmd = Terrat_repo_config_storage_plan_cmd in
          let { Cmd.delete; fetch; store; method_ = _ } = v in
          Ok Storage.Plans.(Cmd { Cmd.delete; fetch; store })
      | V1.Storage.Plans.Storage_plan_s3 v ->
          let module S3 = Terrat_repo_config_storage_plan_s3 in
          let {
            S3.access_key_id;
            bucket;
            delete_extra_args;
            delete_used_plans;
            fetch_extra_args;
            path;
            region;
            secret_access_key;
            store_extra_args;
            method_ = _;
          } =
            v
          in
          Ok
            Storage.Plans.(
              S3
                (S3.make
                   ?access_key_id
                   ~bucket
                   ?delete_extra_args
                   ~delete_used_plans
                   ?fetch_extra_args
                   ?path
                   ~region
                   ?secret_access_key
                   ?store_extra_args
                   ())))
    plans
  >>= fun plans -> Ok { Storage.plans }

let of_version_1_tags_branches branches =
  let module Tb = Terrat_repo_config_custom_tags_branch in
  let { Tb.additional = branches; _ } = branches in
  let open CCResult.Infix in
  CCResult.map_l
    (fun (k, s) -> Pattern.make s >>= fun p -> Ok (k, p))
    (Sln_map.String.to_list branches)
  >>= fun branches -> Ok (Sln_map.String.of_list branches)

let of_version_1_tags tags =
  let open CCResult.Infix in
  let module T = Terrat_repo_config_custom_tags in
  let { T.branch; dest_branch } = tags in
  map_opt of_version_1_tags_branches branch
  >>= fun branch ->
  map_opt of_version_1_tags_branches dest_branch
  >>= fun dest_branch -> Ok (Tags.make ?branch ?dest_branch ())

let of_version_1_workflows_lock_policy = function
  | `Apply -> Workflows.Entry.Lock_policy.Apply
  | `Merge -> Workflows.Entry.Lock_policy.Merge
  | `None -> Workflows.Entry.Lock_policy.None
  | `Strict -> Workflows.Entry.Lock_policy.Strict

let of_version_1_workflows default_engine default_integrations workflows =
  let open CCResult.Infix in
  let module E = Terrat_repo_config_workflow_entry in
  CCResult.map_l
    (fun {
           E.apply;
           cdktf;
           engine;
           environment;
           integrations;
           lock_policy;
           plan;
           runs_on;
           tag_query;
           terraform_version;
           terragrunt;
         }
       ->
      map_opt of_version_1_workflow_op_list apply
      >>= fun apply ->
      of_version_1_workflow_engine cdktf terraform_version terragrunt default_engine engine
      >>= fun engine ->
      of_version_1_workflow_integrations default_integrations integrations
      >>= fun integrations ->
      let lock_policy = of_version_1_workflows_lock_policy lock_policy in
      map_opt of_version_1_workflow_op_list plan
      >>= fun plan ->
      CCResult.map_err
        (function
          | `Tag_query_error err -> `Workflows_tag_query_parse_err err)
        (Terrat_tag_query.of_string tag_query)
      >>= fun tag_query ->
      Ok
        (Workflows.Entry.make
           ?apply
           ?engine
           ?environment
           ?integrations
           ?plan
           ~runs_on
           ~lock_policy
           ~tag_query
           ()))
    workflows

let of_version_1 v1 =
  let {
    V1.access_control;
    apply_requirements;
    automerge;
    batch_runs;
    checkout_strategy = _;
    config_builder;
    cost_estimation;
    create_and_select_workspace;
    default_branch_overrides;
    default_tf_version;
    definitions = _;
    destination_branches;
    dirs;
    drift;
    enabled;
    engine;
    hooks;
    indexer;
    integrations;
    notifications;
    parallel_runs;
    stacks;
    storage;
    tags;
    tree_builder;
    version = _;
    when_modified;
    workflows;
  } =
    v1
  in
  let open CCResult.Infix in
  map_opt of_version_1_access_control access_control
  >>= fun access_control ->
  map_opt of_version_1_apply_requirements apply_requirements
  >>= fun apply_requirements ->
  map_opt of_version_automerge automerge
  >>= fun automerge ->
  map_opt of_version_1_batch_runs batch_runs
  >>= fun batch_runs ->
  map_opt of_version_1_config_builder config_builder
  >>= fun config_builder ->
  map_opt of_version_1_cost_estimation cost_estimation
  >>= fun cost_estimation ->
  map_opt of_version_1_destination_branches destination_branches
  >>= fun destination_branches ->
  map_opt of_version_1_when_modified when_modified
  >>= fun when_modified ->
  map_opt (of_version_1_dirs when_modified) dirs
  >>= fun dirs ->
  map_opt of_version_1_drift drift
  >>= fun drift ->
  of_version_1_engine default_tf_version engine
  >>= fun engine ->
  map_opt of_version_1_hooks hooks
  >>= fun hooks ->
  map_opt of_version_1_indexer indexer
  >>= fun indexer ->
  map_opt of_version_1_integrations integrations
  >>= fun integrations ->
  map_opt of_version_1_stacks stacks
  >>= fun stacks ->
  map_opt of_version_1_notifications notifications
  >>= fun notifications ->
  map_opt of_version_1_storage storage
  >>= fun storage ->
  map_opt of_version_1_tags tags
  >>= fun tags ->
  map_opt of_version_1_tree_builder tree_builder
  >>= fun tree_builder ->
  map_opt (of_version_1_workflows engine integrations) workflows
  >>= fun workflows ->
  Ok
    (View.make
       ?access_control
       ?apply_requirements
       ?automerge
       ?batch_runs
       ?config_builder
       ?cost_estimation
       ~create_and_select_workspace
       ~default_branch_overrides
       ?destination_branches
       ?dirs
       ?drift
       ~enabled
       ?engine
       ?hooks
       ?indexer
       ?integrations
       ?notifications
       ~parallel_runs
       ?stacks
       ?storage
       ?tags
       ?tree_builder
       ?when_modified
       ?workflows
       ())

let of_version_1_json json =
  match Terrat_repo_config.Version_1.of_yojson json with
  | Ok config -> of_version_1 config
  | Error err -> (
      match
        Jsonschema_check.validate_json_schema ~schema:config_schema (Yojson.Safe.to_string json)
      with
      | Ok () ->
          Error
            (`Repo_config_schema_err [ { Jsonschema_check.Validation_err.msg = err; path = "" } ])
      | Error errors -> Error (`Repo_config_schema_err errors))

let of_version_1_json_derived = of_version_1_json

let to_version_1_match_list =
  CCList.map (function
    | Access_control.Match.User user -> "user:" ^ user
    | Access_control.Match.Team team -> "team:" ^ team
    | Access_control.Match.Role role -> "role:" ^ role
    | Access_control.Match.Any -> "*")

let to_version_1_access_control_files files =
  let module Ac = Terrat_repo_config_access_control in
  Ac.Files.make
    ~additional:(Sln_map.String.map to_version_1_match_list files)
    Json_schema.Empty_obj.t

let to_version_1_policy_list =
  CCList.map
    (fun
      {
        Access_control.Policy.apply;
        apply_autoapprove;
        apply_force;
        apply_with_superapproval;
        plan;
        superapproval;
        tag_query;
      }
    ->
      let module P = Terrat_repo_config.Access_control_policy in
      {
        P.apply = Some (to_version_1_match_list apply);
        apply_autoapprove = Some (to_version_1_match_list apply_autoapprove);
        apply_force = Some (to_version_1_match_list apply_force);
        apply_with_superapproval = Some (to_version_1_match_list apply_with_superapproval);
        plan = Some (to_version_1_match_list plan);
        superapproval = Some (to_version_1_match_list superapproval);
        tag_query = Terrat_tag_query.to_string tag_query;
      })

let to_version_1_access_control ac =
  let module Ac = Terrat_repo_config.Access_control in
  {
    Ac.apply_require_all_dirspace_access = ac.Access_control.apply_require_all_dirspace_access;
    ci_config_update = Some (to_version_1_match_list ac.Access_control.ci_config_update);
    enabled = ac.Access_control.enabled;
    files = Some (to_version_1_access_control_files ac.Access_control.files);
    plan_require_all_dirspace_access = ac.Access_control.plan_require_all_dirspace_access;
    policies = Some (to_version_1_policy_list ac.Access_control.policies);
    terrateam_config_update =
      Some (to_version_1_match_list ac.Access_control.terrateam_config_update);
    unlock = Some (to_version_1_match_list ac.Access_control.unlock);
  }

let to_version_1_apply_requirements_apply_after_merge afm =
  let module Afm = Terrat_repo_config.Apply_requirements_checks_apply_after_merge in
  let { Apply_requirements.Apply_after_merge.enabled } = afm in
  { Afm.enabled }

let to_version_1_apply_requirements_approved approved =
  let module Ap = Terrat_repo_config.Apply_requirements_checks_approved_2 in
  let {
    Apply_requirements.Approved.all_of;
    any_of;
    any_of_count;
    enabled;
    require_completed_reviews;
  } =
    approved
  in
  {
    Ap.all_of = Some (to_version_1_match_list all_of);
    any_of = Some (to_version_1_match_list any_of);
    any_of_count;
    enabled;
    require_completed_reviews;
  }

let to_version_1_apply_requirements_merge_conflicts mc =
  let module Mc = Terrat_repo_config.Apply_requirements_checks_merge_conflicts in
  let { Apply_requirements.Merge_conflicts.enabled } = mc in
  { Mc.enabled }

let to_version_1_apply_requirements_status_checks sc =
  let module Sc = Terrat_repo_config.Apply_requirements_checks_status_checks in
  let { Apply_requirements.Status_checks.enabled; ignore_matching } = sc in
  { Sc.enabled; ignore_matching = Some ignore_matching }

let to_version_1_apply_requirements_checks =
  let module C2 = Terrat_repo_config.Apply_requirements_checks_2 in
  CCList.map
    (fun
      {
        Apply_requirements.Check.apply_after_merge;
        approved;
        merge_conflicts;
        require_ready_for_review_pr;
        status_checks;
        tag_query;
      }
    ->
      {
        C2.Items.apply_after_merge =
          Some (to_version_1_apply_requirements_apply_after_merge apply_after_merge);
        approved = Some (to_version_1_apply_requirements_approved approved);
        merge_conflicts = Some (to_version_1_apply_requirements_merge_conflicts merge_conflicts);
        require_ready_for_review_pr;
        status_checks = Some (to_version_1_apply_requirements_status_checks status_checks);
        tag_query = Terrat_tag_query.to_string tag_query;
      })

let to_version_1_apply_requirements ar =
  let module Ar = Terrat_repo_config.Apply_requirements in
  let module C = Terrat_repo_config.Apply_requirements_checks in
  let {
    Apply_requirements.checks;
    create_pending_apply_check;
    create_completed_apply_check_on_noop;
  } =
    ar
  in
  {
    Ar.checks = Some (C.Apply_requirements_checks_2 (to_version_1_apply_requirements_checks checks));
    create_pending_apply_check;
    create_completed_apply_check_on_noop;
  }

let to_version_1_automerge automerge =
  let module Am = Terrat_repo_config.Automerge in
  let module Ms = Automerge.Merge_strategy in
  let { Automerge.delete_branch; enabled; merge_strategy; require_explicit_apply; retain_pr_title }
      =
    automerge
  in
  let merge_strategy =
    match merge_strategy with
    | Ms.Auto -> `Auto
    | Ms.Merge -> `Merge
    | Ms.Rebase -> `Rebase
    | Ms.Squash -> `Squash
  in
  { Am.delete_branch; enabled; merge_strategy; require_explicit_apply; retain_pr_title }

let to_version_1_batch_runs batch_runs =
  let module Br = Terrat_repo_config.Batch_runs in
  let { Batch_runs.enabled; max_workspaces_per_batch } = batch_runs in
  { Br.enabled; max_workspaces_per_batch }

let to_version_1_config_builder config_builder =
  let module Cb = Terrat_repo_config.Config_builder in
  let { Config_builder.enabled; script } = config_builder in
  { Cb.enabled; script }

let to_version_1_tree_builder tree_builder =
  let module Tb = Terrat_repo_config.Tree_builder in
  let { Tree_builder.enabled; script } = tree_builder in
  { Tb.enabled; script = Some script }

let to_version_1_cost_estimation_provider = function
  | Cost_estimation.Provider.Infracost -> `Infracost

let to_version_1_cost_estimation cost_estimation =
  let module Ce = Terrat_repo_config.Version_1.Cost_estimation in
  let { Cost_estimation.currency; enabled; provider } = cost_estimation in
  { Ce.currency; enabled; provider = to_version_1_cost_estimation_provider provider }

let to_version_1_destination_branches db =
  let module Db = Terrat_repo_config.Version_1.Destination_branches in
  let module Obj = Terrat_repo_config.Destination_branch_object in
  CCList.map
    (fun { Destination_branches.Destination_branch.branch; source_branches } ->
      Db.Items.Destination_branch_object { Obj.branch; source_branches = Some source_branches })
    db

let to_version_1_depends_on { Depends_on.tag_query; prune_on_no_change } =
  Terrat_repo_config_depends_on.Depends_on_object
    {
      Terrat_repo_config_depends_on_object.tag_query = Terrat_tag_query.to_string tag_query;
      prune_on_no_change;
    }

let to_version_1_dirs_dir_when_modified wm =
  let module Wm = Terrat_repo_config.When_modified_nullable in
  let { When_modified.autoapply; autoplan; autoplan_draft_pr; depends_on; file_patterns } = wm in
  {
    Wm.autoapply = Some autoapply;
    autoplan = Some autoplan;
    autoplan_draft_pr = Some autoplan_draft_pr;
    depends_on = CCOption.map to_version_1_depends_on depends_on;
    file_patterns = Some (CCList.map File_pattern.to_string file_patterns);
  }

let to_version_1_dirs_dir_workspaces workspaces =
  let module Ws = Terrat_repo_config.Workspaces in
  Ws.make
    ~additional:
      (Sln_map.String.fold
         (fun k v acc ->
           let { Dirs.Workspace.tags; when_modified } = v in
           Sln_map.String.add
             k
             {
               Ws.Additional.tags = Some tags;
               when_modified = Some (to_version_1_dirs_dir_when_modified when_modified);
             }
             acc)
         workspaces
         Sln_map.String.empty)
    Json_schema.Empty_obj.t

let to_version_1_dirs_dir dirs =
  let module D = Terrat_repo_config.Dir in
  Sln_map.String.fold
    (fun k v acc ->
      let {
        Dirs.Dir.create_and_select_workspace;
        create_if_missing;
        lock_branch_target;
        stacks;
        tags;
        workspaces;
      } =
        v
      in
      Sln_map.String.add
        k
        {
          D.create_and_select_workspace;
          create_if_missing;
          lock_branch_target =
            (match lock_branch_target with
            | Dirs.Dir.Branch_target.All -> Some `All
            | Dirs.Dir.Branch_target.Dest_branch -> Some `Dest_branch);
          stacks =
            (if Sln_map.String.is_empty stacks then None
             else Some (to_version_1_dirs_dir_workspaces stacks));
          tags = Some tags;
          when_modified = None;
          workspaces =
            (if Sln_map.String.is_empty workspaces then None
             else Some (to_version_1_dirs_dir_workspaces workspaces));
        }
        acc)
    dirs
    Sln_map.String.empty

let to_version_1_dirs dirs =
  let module Ds = Terrat_repo_config.Version_1.Dirs in
  Ds.make ~additional:(to_version_1_dirs_dir dirs) Json_schema.Empty_obj.t

let to_version_1_drift drift =
  let module D = Terrat_repo_config.Drift_2 in
  let module Schedule = Terrat_repo_config_drift_schedule in
  let { Drift.enabled; schedules } = drift in
  let schedules =
    CCList.map
      (fun (name, { Drift.Schedule.tag_query; reconcile; schedule; window }) ->
        let window =
          CCOption.map (fun { Drift.Window.start; end_ } -> { Schedule.Window.start; end_ }) window
        in
        ( name,
          {
            Schedule.reconcile;
            schedule =
              (let module S = Drift.Schedule.Sched in
               match schedule with
               | S.Hourly -> `Hourly
               | S.Daily -> `Daily
               | S.Weekly -> `Weekly
               | S.Monthly -> `Monthly);
            tag_query = Terrat_tag_query.to_string tag_query;
            window;
          } ))
      (Sln_map.String.to_list schedules)
  in
  Terrat_repo_config_version_1.Drift.Drift_2
    {
      D.enabled;
      schedules =
        D.Schedules.make ~additional:(Sln_map.String.of_list schedules) Json_schema.Empty_obj.t;
    }

let to_version_1_engine_tf_outputs outputs =
  let module O = Terrat_repo_config.Engine_tf_outputs in
  let { Engine.Tf_outputs.collect } = outputs in
  { O.collect = Some collect }

let to_version_1_engine engine =
  let module E = Terrat_repo_config.Engine in
  let module O = Terrat_repo_config_engine_other in
  match engine with
  | Engine.Other other -> E.Engine_other (CCResult.get_exn @@ O.of_yojson other)
  | Engine.Custom custom ->
      let module Custom = Terrat_repo_config.Engine_custom in
      let { Engine.Custom.apply; init; plan; diff; unsafe_apply; outputs } = custom in
      E.Engine_custom { Custom.name = `Custom; apply; init; plan; diff; unsafe_apply; outputs }
  | Engine.Fly fly ->
      let module Fly = Terrat_repo_config.Engine_fly in
      let { Engine.Fly.config_file } = fly in
      E.Engine_fly { Fly.name = `Fly; config_file }
  | Engine.Cdktf cdktf ->
      let module Cdktf = Terrat_repo_config.Engine_cdktf in
      let { Engine.Cdktf.tf_cmd; tf_version; outputs; override_tf_cmd } = cdktf in
      E.Engine_cdktf
        {
          Cdktf.name = `Cdktf;
          tf_cmd = Some tf_cmd;
          tf_version = Some tf_version;
          outputs = Some (to_version_1_engine_tf_outputs outputs);
          override_tf_cmd;
        }
  | Engine.Opentofu ot ->
      let module Ot = Terrat_repo_config.Engine_opentofu in
      let { Engine.Opentofu.version; outputs; override_tf_cmd } = ot in
      E.Engine_opentofu
        {
          Ot.name = `Tofu;
          version;
          outputs = Some (to_version_1_engine_tf_outputs outputs);
          override_tf_cmd;
        }
  | Engine.Terraform tf ->
      let module Tf = Terrat_repo_config.Engine_terraform in
      let { Engine.Terraform.version; outputs; override_tf_cmd } = tf in
      E.Engine_terraform
        {
          Tf.name = `Terraform;
          version;
          outputs = Some (to_version_1_engine_tf_outputs outputs);
          override_tf_cmd;
        }
  | Engine.Terragrunt tg ->
      let module Tg = Terrat_repo_config.Engine_terragrunt in
      let { Engine.Terragrunt.tf_cmd; tf_version; version; outputs; override_tf_cmd } = tg in
      E.Engine_terragrunt
        {
          Tg.name = `Terragrunt;
          tf_cmd = Some tf_cmd;
          tf_version;
          version;
          outputs = Some (to_version_1_engine_tf_outputs outputs);
          override_tf_cmd;
        }
  | Engine.Pulumi ->
      let module P = Terrat_repo_config.Engine_pulumi in
      E.Engine_pulumi { P.name = `Pulumi }
  | Engine.Stategraph sg ->
      let module S = Terrat_repo_config.Engine_stategraph in
      let { Engine.Stategraph.tf_cmd; tf_version; version; outputs; override_tf_cmd } = sg in
      E.Engine_stategraph
        {
          S.name = `Stategraph;
          tf_cmd = Some tf_cmd;
          tf_version;
          version;
          outputs = Some (to_version_1_engine_tf_outputs outputs);
          override_tf_cmd;
        }

let to_version_1_run_on = function
  | Workflow_step.Run_on.Always -> `Always
  | Workflow_step.Run_on.Failure -> `Failure
  | Workflow_step.Run_on.Success -> `Success

let to_version_1_visible_on = function
  | Workflow_step.Visible_on.Always -> `Always
  | Workflow_step.Visible_on.Failure -> `Failure
  | Workflow_step.Visible_on.Success -> `Success

let to_version_1_run_format =
  let module F = Workflow_step.Format in
  let module Fmt = Terrat_repo_config_hook_op_run_format in
  let module Obj = Terrat_repo_config_hook_op_run_format_obj in
  function
  | F.Code -> Fmt.Hook_op_run_format_str `Code
  | F.Raw -> Fmt.Hook_op_run_format_str `Raw
  | F.Markdown -> Fmt.Hook_op_run_format_str `Markdown
  | F.Code_lang lang -> Fmt.Hook_op_run_format_obj { Obj.type_ = `Code; lang }

let to_version_1_lock_policy = function
  | Workflows.Entry.Lock_policy.Apply -> `Apply
  | Workflows.Entry.Lock_policy.Merge -> `Merge
  | Workflows.Entry.Lock_policy.None -> `None
  | Workflows.Entry.Lock_policy.Strict -> `Strict

let to_version_1_plan_mode = function
  | Workflow_step.Plan.Mode.Strict -> `Strict
  | Workflow_step.Plan.Mode.Fast_and_loose -> `Fast_and_loose

let to_version_1_hooks_op_env_exec env =
  let module E = Terrat_repo_config.Hook_op_env_exec in
  let { Workflow_step.Env.Exec.cmd; name; sensitive; trim_trailing_newlines } = env in
  { E.cmd; method_ = Some `Exec; name; sensitive; trim_trailing_newlines; type_ = `Env }

let to_version_1_hooks_op_env_source env =
  let module E = Terrat_repo_config.Hook_op_env_source in
  let { Workflow_step.Env.Source.cmd; sensitive } = env in
  { E.cmd; method_ = `Source; sensitive; type_ = `Env }

let to_version_1_hooks_op_oidc = function
  | Workflow_step.Oidc.Aws oidc ->
      let module Oidc = Terrat_repo_config.Hook_op_oidc in
      let module Aws = Terrat_repo_config.Hook_op_oidc_aws in
      let {
        Workflow_step.Oidc.Aws.assume_role_arn;
        assume_role_enabled;
        audience;
        duration;
        region;
        role_arn;
        session_name;
      } =
        oidc
      in
      Oidc.Hook_op_oidc_aws
        {
          Aws.assume_role_arn;
          assume_role_enabled;
          audience;
          duration;
          provider = Some `Aws;
          region;
          role_arn;
          session_name;
          type_ = `Oidc;
        }
  | Workflow_step.Oidc.Gcp oidc ->
      let module Oidc = Terrat_repo_config.Hook_op_oidc in
      let module Gcp = Terrat_repo_config.Hook_op_oidc_gcp in
      let {
        Workflow_step.Oidc.Gcp.access_token_lifetime;
        access_token_subject;
        audience;
        project_id;
        service_account;
        workload_identity_provider;
      } =
        oidc
      in
      Oidc.Hook_op_oidc_gcp
        {
          Gcp.access_token_lifetime;
          access_token_subject;
          audience;
          project_id;
          provider = `Gcp;
          service_account;
          type_ = `Oidc;
          workload_identity_provider;
        }
  | Workflow_step.Oidc.Azure oidc ->
      let module Oidc = Terrat_repo_config.Hook_op_oidc in
      let module Azure = Terrat_repo_config.Hook_op_oidc_azure in
      let { Workflow_step.Oidc.Azure.audience; client_id; subscription_id; tenant_id } = oidc in
      Oidc.Hook_op_oidc_azure
        { Azure.audience; client_id; provider = `Azure; subscription_id; tenant_id; type_ = `Oidc }

let to_version_1_hooks_op_run r =
  let module R = Terrat_repo_config.Hook_op_run in
  let {
    Workflow_step.Run.capture_output;
    cmd;
    env;
    format;
    run_on;
    ignore_errors;
    visible_on;
    on_error;
  } =
    r
  in
  {
    R.capture_output;
    cmd;
    env = CCOption.map (fun env -> R.Env.make ~additional:env Json_schema.Empty_obj.t) env;
    format = Some (to_version_1_run_format format);
    ignore_errors;
    run_on = Some (to_version_1_run_on run_on);
    type_ = `Run;
    visible_on = Some (to_version_1_visible_on visible_on);
    on_error = Some on_error;
  }

let to_version_1_hooks_op_gates g =
  let module G = Terrat_repo_config.Hook_op_gates in
  let { Workflow_step.Gates.cmd; env; run_on } = g in
  {
    G.cmd;
    env = CCOption.map (fun env -> G.Env.make ~additional:env Json_schema.Empty_obj.t) env;
    run_on = Some (to_version_1_run_on run_on);
    type_ = `Gates;
  }

let to_version_1_hooks_hook_list =
  let module Op = Terrat_repo_config.Hook_op in
  CCList.map (function
    | Hooks.Hook_op.Drift_create_issue { Hooks.Drift_create_issue.group_by } ->
        let module D = Terrat_repo_config.Hook_op_drift_create_issue in
        let group_by =
          match group_by with
          | `All -> `All
          | `Dirspace -> `Dirspace
        in
        Op.Hook_op_drift_create_issue { D.group_by; type_ = Some `Drift_create_issue }
    | Hooks.Hook_op.Env (Workflow_step.Env.Exec env) ->
        Op.Hook_op_env_exec (to_version_1_hooks_op_env_exec env)
    | Hooks.Hook_op.Env (Workflow_step.Env.Source env) ->
        Op.Hook_op_env_source (to_version_1_hooks_op_env_source env)
    | Hooks.Hook_op.Oidc oidc -> Op.Hook_op_oidc (to_version_1_hooks_op_oidc oidc)
    | Hooks.Hook_op.Run r -> Op.Hook_op_run (to_version_1_hooks_op_run r)
    | Hooks.Hook_op.Gates g -> Op.Hook_op_gates (to_version_1_hooks_op_gates g))

let to_version_1_hooks_hook hook =
  let module H = Terrat_repo_config.Hook in
  let { Hooks.Hook.pre; post } = hook in
  {
    H.post = Some (to_version_1_hooks_hook_list post);
    pre = Some (to_version_1_hooks_hook_list pre);
  }

let to_version_1_hooks hooks =
  let module H = Terrat_repo_config.Version_1.Hooks in
  let { Hooks.all; apply; plan } = hooks in
  {
    H.all = Some (to_version_1_hooks_hook all);
    apply = Some (to_version_1_hooks_hook apply);
    plan = Some (to_version_1_hooks_hook plan);
  }

let to_version_1_indexer indexer =
  let { Indexer.build_tag; enabled } = indexer in
  { V1.Indexer.build_tag; enabled }

let to_version_1_integrations integrations =
  let module I = Terrat_repo_config.Integrations in
  let { Integrations.resourcely = { Integrations.Resourcely.enabled; extra_args = _ } } =
    integrations
  in
  { I.resourcely = Some { I.Resourcely.enabled; extra_args = Some [] } }

let to_version_1_stacks stacks =
  let module S = Terrat_repo_config_stacks in
  let { Stacks.names } = stacks in
  let names =
    S.Names.make
      ~additional:
        (Sln_map.String.map
           (fun v ->
             let module S = Terrat_repo_config_stacks.Names.Additional in
             let module Sc = Terrat_repo_config_stack_config in
             let module Sn = Terrat_repo_config_stack_nested_config in
             let module V = Terrat_repo_config_stack_variables in
             let module R = Terrat_repo_config_stack_rules in
             let { Stacks.Stack.type_; rules; variables } = v in
             let { Stacks.Rules.modified_by; apply_after; auto_apply; plan_after } = rules in
             let rules =
               {
                 R.modified_by = Some modified_by;
                 apply_after = Some apply_after;
                 auto_apply;
                 plan_after = Some plan_after;
               }
             in
             match type_ with
             | Stacks.Type_.Stack tag_query ->
                 S.Stack_config
                   {
                     Sc.tag_query = Terrat_tag_query.to_string tag_query;
                     rules = Some rules;
                     variables = Some (V.make ~additional:variables Json_schema.Empty_obj.t);
                   }
             | Stacks.Type_.Nested stacks ->
                 S.Stack_nested_config
                   {
                     Sn.stacks;
                     rules = Some rules;
                     variables = Some (V.make ~additional:variables Json_schema.Empty_obj.t);
                   })
           names)
      Json_schema.Empty_obj.t
  in
  { S.names = Some names }

let to_version_1_notification_policy policy =
  let module P = Terrat_repo_config_notification_policy in
  let { Notifications.Policy.tag_query; comment_strategy } = policy in
  let comment_strategy =
    match comment_strategy with
    | Notifications.Policy.Strategy.Append -> `Append
    | Notifications.Policy.Strategy.Delete -> `Delete
    | Notifications.Policy.Strategy.Minimize -> `Minimize
  in
  { P.tag_query = Terrat_tag_query.to_string tag_query; comment_strategy }

let to_version_1_notifications notifications =
  let module N = Terrat_repo_config.Notifications in
  let module Sn = Terrat_repo_config.Notifications_summary in
  let { Notifications.policies; summary = { Notifications.Summary.enabled } } = notifications in
  {
    N.policies = Some (CCList.map to_version_1_notification_policy policies);
    summary = Some { Sn.enabled };
  }

let to_version_1_storage_plans plans =
  match plans with
  | Storage.Plans.Terrateam ->
      let module S = Terrat_repo_config.Storage_plan_terrateam in
      V1.Storage.Plans.Storage_plan_terrateam { S.method_ = `Terrateam }
  | Storage.Plans.Cmd cmd ->
      let module S = Terrat_repo_config.Storage_plan_cmd in
      let { Storage.Plans.Cmd.delete; fetch; store } = cmd in
      V1.Storage.Plans.Storage_plan_cmd { S.delete; fetch; method_ = `Cmd; store }
  | Storage.Plans.S3 s3 ->
      let module S = Terrat_repo_config.Storage_plan_s3 in
      let {
        Storage.Plans.S3.access_key_id;
        bucket;
        delete_extra_args;
        delete_used_plans;
        fetch_extra_args;
        path;
        region;
        secret_access_key;
        store_extra_args;
      } =
        s3
      in
      V1.Storage.Plans.Storage_plan_s3
        {
          S.access_key_id;
          bucket;
          delete_extra_args = Some delete_extra_args;
          delete_used_plans;
          fetch_extra_args = Some fetch_extra_args;
          method_ = `S3;
          path;
          region;
          secret_access_key;
          store_extra_args = Some store_extra_args;
        }

let to_version_1_storage storage =
  let { Storage.plans } = storage in
  { V1.Storage.plans = Some (to_version_1_storage_plans plans) }

let to_version_1_tags_branch branch =
  Terrat_repo_config.Custom_tags_branch.make
    ~additional:
      (Sln_map.String.fold
         (fun k v acc -> Sln_map.String.add k (Pattern.to_string v) acc)
         branch
         Sln_map.String.empty)
    Json_schema.Empty_obj.t

let to_version_1_tags tags =
  let module T = Terrat_repo_config.Custom_tags in
  let { Tags.branch; dest_branch } = tags in
  {
    T.branch = Some (to_version_1_tags_branch branch);
    dest_branch = Some (to_version_1_tags_branch dest_branch);
  }

let to_version_1_when_modified when_modified =
  let module Wm = Terrat_repo_config.When_modified in
  let { When_modified.autoapply; autoplan; autoplan_draft_pr; depends_on; file_patterns } =
    when_modified
  in
  {
    Wm.autoapply;
    autoplan;
    autoplan_draft_pr;
    depends_on = CCOption.map to_version_1_depends_on depends_on;
    file_patterns = CCList.map File_pattern.to_string file_patterns;
  }

let to_version_1_workflow_retry retry =
  let module R = Terrat_repo_config.Retry in
  let { Workflow_step.Retry.backoff; enabled; initial_sleep; tries } = retry in
  { R.backoff; enabled; initial_sleep; tries }

let to_version_1_gate gate =
  let module G = Terrat_repo_config_gate in
  let { Workflow_step.Gate.all_of; any_of; any_of_count; token; name } = gate in
  { G.all_of; any_of; any_of_count; token; name }

let to_version_1_workflows_op =
  let module Op = Terrat_repo_config.Workflow_op_list in
  CCList.map (function
    | Workflows.Entry.Op.Init init ->
        let module I = Terrat_repo_config.Workflow_op_init in
        let { Workflow_step.Init.env; extra_args } = init in
        Op.Items.Workflow_op_init
          {
            I.env = CCOption.map (fun env -> I.Env.make ~additional:env Json_schema.Empty_obj.t) env;
            extra_args = Some extra_args;
            type_ = `Init;
          }
    | Workflows.Entry.Op.Plan plan ->
        let module P = Terrat_repo_config.Workflow_op_plan in
        let { Workflow_step.Plan.env; extra_args; mode } = plan in
        Op.Items.Workflow_op_plan
          {
            P.env = CCOption.map (fun env -> P.Env.make ~additional:env Json_schema.Empty_obj.t) env;
            extra_args = Some extra_args;
            mode = to_version_1_plan_mode mode;
            type_ = `Plan;
          }
    | Workflows.Entry.Op.Apply apply ->
        let module A = Terrat_repo_config.Workflow_op_apply in
        let { Workflow_step.Apply.env; extra_args; retry } = apply in
        Op.Items.Workflow_op_apply
          {
            A.env = CCOption.map (fun env -> A.Env.make ~additional:env Json_schema.Empty_obj.t) env;
            extra_args = Some extra_args;
            retry = CCOption.map to_version_1_workflow_retry retry;
            type_ = `Apply;
          }
    | Workflows.Entry.Op.Run r -> Op.Items.Hook_op_run (to_version_1_hooks_op_run r)
    | Workflows.Entry.Op.Env (Workflow_step.Env.Exec env) ->
        Op.Items.Hook_op_env_exec (to_version_1_hooks_op_env_exec env)
    | Workflows.Entry.Op.Env (Workflow_step.Env.Source env) ->
        Op.Items.Hook_op_env_source (to_version_1_hooks_op_env_source env)
    | Workflows.Entry.Op.Oidc oidc -> Op.Items.Hook_op_oidc (to_version_1_hooks_op_oidc oidc)
    | Workflows.Entry.Op.Conftest ct ->
        let module C = Terrat_repo_config.Workflow_op_conftest in
        let { Workflow_step.Conftest.env; extra_args; gate; ignore_errors; run_on; visible_on } =
          ct
        in
        Op.Items.Workflow_op_conftest
          {
            C.type_ = `Conftest;
            env = CCOption.map (fun env -> C.Env.make ~additional:env Json_schema.Empty_obj.t) env;
            extra_args = Some extra_args;
            gate = CCOption.map to_version_1_gate gate;
            ignore_errors;
            run_on = Some (to_version_1_run_on run_on);
            visible_on = Some (to_version_1_visible_on visible_on);
          }
    | Workflows.Entry.Op.Checkov c ->
        let module C = Terrat_repo_config.Workflow_op_checkov in
        let { Workflow_step.Checkov.env; extra_args; gate; ignore_errors; run_on; visible_on } =
          c
        in
        Op.Items.Workflow_op_checkov
          {
            C.type_ = `Checkov;
            env = CCOption.map (fun env -> C.Env.make ~additional:env Json_schema.Empty_obj.t) env;
            extra_args = Some extra_args;
            gate = CCOption.map to_version_1_gate gate;
            ignore_errors;
            run_on = Some (to_version_1_run_on run_on);
            visible_on = Some (to_version_1_visible_on visible_on);
          }
    | Workflows.Entry.Op.Opa opa ->
        let module C = Terrat_repo_config.Workflow_op_opa in
        let { Workflow_step.Opa.env; extra_args; fail_on; gate; ignore_errors; run_on; visible_on }
            =
          opa
        in
        let fail_on =
          match fail_on with
          | Workflow_step.Opa.Fail_on.Defined -> `Defined
          | Workflow_step.Opa.Fail_on.Undefined -> `Undefined
        in
        Op.Items.Workflow_op_opa
          {
            C.type_ = `Opa;
            env = CCOption.map (fun env -> C.Env.make ~additional:env Json_schema.Empty_obj.t) env;
            extra_args = Some extra_args;
            fail_on;
            gate = CCOption.map to_version_1_gate gate;
            ignore_errors;
            run_on = Some (to_version_1_run_on run_on);
            visible_on = Some (to_version_1_visible_on visible_on);
          }
    | Workflows.Entry.Op.Gates gates -> Op.Items.Hook_op_gates (to_version_1_hooks_op_gates gates))

let to_version_1_workflows =
  CCList.map (fun entry ->
      let module E = Terrat_repo_config.Workflow_entry in
      let {
        Workflows.Entry.apply;
        engine;
        environment;
        integrations;
        lock_policy;
        plan;
        tag_query;
        runs_on;
      } =
        entry
      in
      {
        E.apply = Some (to_version_1_workflows_op apply);
        cdktf = false;
        engine = Some (to_version_1_engine engine);
        environment;
        integrations =
          map_opt_if_true
            CCFun.(Integrations.equal (Integrations.make ()) %> not)
            to_version_1_integrations
            integrations;
        lock_policy = to_version_1_lock_policy lock_policy;
        plan = Some (to_version_1_workflows_op plan);
        runs_on;
        tag_query = Terrat_tag_query.to_string tag_query;
        terraform_version = None;
        terragrunt = false;
      })

let to_version_1 t =
  let {
    View.access_control;
    apply_requirements;
    automerge;
    batch_runs;
    config_builder;
    cost_estimation;
    create_and_select_workspace;
    default_branch_overrides;
    destination_branches;
    dirs;
    drift;
    enabled;
    engine;
    hooks;
    indexer;
    integrations;
    notifications;
    parallel_runs;
    stacks;
    storage;
    tags;
    tree_builder;
    when_modified;
    workflows;
  } =
    t
  in
  {
    V1.access_control =
      map_opt_if_true
        CCFun.(Access_control.equal (Access_control.make ()) %> not)
        to_version_1_access_control
        access_control;
    apply_requirements =
      map_opt_if_true
        CCFun.(Apply_requirements.equal (Apply_requirements.make ()) %> not)
        to_version_1_apply_requirements
        apply_requirements;
    automerge =
      map_opt_if_true
        CCFun.(Automerge.equal (Automerge.make ()) %> not)
        to_version_1_automerge
        automerge;
    batch_runs =
      map_opt_if_true
        CCFun.(Batch_runs.equal (Batch_runs.make ()) %> not)
        to_version_1_batch_runs
        batch_runs;
    checkout_strategy = `Merge;
    config_builder =
      map_opt_if_true
        CCFun.(Config_builder.equal (Config_builder.make ()) %> not)
        to_version_1_config_builder
        config_builder;
    cost_estimation =
      map_opt_if_true
        CCFun.(Cost_estimation.equal (Cost_estimation.make ()) %> not)
        to_version_1_cost_estimation
        cost_estimation;
    create_and_select_workspace;
    default_branch_overrides;
    default_tf_version = None;
    definitions = None;
    destination_branches =
      map_opt_if_true (( <> ) []) to_version_1_destination_branches destination_branches;
    dirs = map_opt_if_true CCFun.(Sln_map.String.is_empty %> not) to_version_1_dirs dirs;
    drift = map_opt_if_true CCFun.(Drift.equal (Drift.make ()) %> not) to_version_1_drift drift;
    enabled;
    engine =
      map_opt_if_true
        CCFun.(Engine.equal Engine.(Terraform (Terraform.make ())) %> not)
        to_version_1_engine
        engine;
    hooks = map_opt_if_true CCFun.(Hooks.equal (Hooks.make ()) %> not) to_version_1_hooks hooks;
    indexer =
      map_opt_if_true CCFun.(Indexer.equal (Indexer.make ()) %> not) to_version_1_indexer indexer;
    integrations =
      map_opt_if_true
        CCFun.(Integrations.equal (Integrations.make ()) %> not)
        to_version_1_integrations
        integrations;
    notifications =
      map_opt_if_true
        CCFun.(Notifications.equal (Notifications.make ()) %> not)
        to_version_1_notifications
        notifications;
    parallel_runs;
    stacks = map_opt_if_true CCFun.(Stacks.equal (Stacks.make ()) %> not) to_version_1_stacks stacks;
    storage =
      map_opt_if_true CCFun.(Storage.equal (Storage.make ()) %> not) to_version_1_storage storage;
    tags = map_opt_if_true CCFun.(Tags.equal (Tags.make ()) %> not) to_version_1_tags tags;
    tree_builder =
      map_opt_if_true
        CCFun.(Tree_builder.equal (Tree_builder.make ()) %> not)
        to_version_1_tree_builder
        tree_builder;
    version = `V_1;
    when_modified =
      map_opt_if_true
        CCFun.(When_modified.equal (When_modified.make ()) %> not)
        to_version_1_when_modified
        when_modified;
    workflows = map_opt_if_true (( <> ) []) to_version_1_workflows workflows;
  }

let merge_with_default_branch_config ~default t =
  (* Some identifiers come from the default branch (generally for security
     reasons). The configuration for this is a list of root keys that should
     come from the default branch.  The easiest way to implement this to convert
     everything to the JSON representation, pull from default, then convert
     back.  Because we know everything was a valid repository configuration, we
     can elide error checking because this is just moving keys around and does
     not change the correctness of the configuration. *)
  let default_branch_overrides =
    "default_branch_overrides"
    :: CCOption.get_or
         ~default:(Default_branch_overrides.make ())
         default.View.default_branch_overrides
  in
  let default_json = Terrat_repo_config.Version_1.to_yojson @@ to_version_1 default in
  let t_json = Terrat_repo_config.Version_1.to_yojson @@ to_version_1 t in
  let t =
    CCListLabels.fold_left
      ~f:(fun t override ->
        CCList.Assoc.set
          ~eq:CCString.equal
          override
          (Yojson.Safe.Util.member override default_json)
          t)
      ~init:(Yojson.Safe.Util.to_assoc t_json)
      default_branch_overrides
  in
  `Assoc t
  |> Terrat_repo_config.Version_1.of_yojson
  |> CCResult.get_exn
  |> of_version_1
  |> CCResult.get_exn

(* Functionality around derive *)

let process_dot = CCString.replace ~which:`All ~sub:"/./" ~by:"/"

let rec process_dot_dot dirname =
  (* We want to support relative paths in file_patterns, to some extent.  We
     only support [/../], and it must be proceeded by a static directory,
     not a pattern.  The [${DIR}] variable must be expanded as well.  For
     example, [foo/bar/../baz] will be turned into [foo/baz].  But
     [foo/**/../baz] will result in [foo/baz] as well, removing the
     pattern.

     To do this, we recursively split it in [/../], then cut the end off the
     left portion and sew it back.  It's a little expensive in that it
     splits and join the string continuously, but it's an easy
     implementation. *)
  match CCString.Split.left ~by:"/../" dirname with
  | Some (l, r) -> (
      match CCString.Split.right ~by:"/" l with
      | Some (l', _) -> process_dot_dot (l' ^ "/" ^ r)
      | None -> process_dot_dot r)
  | None -> dirname

let process_relative_path dirname = process_dot_dot (process_dot dirname)

let build_symlinks =
  CCListLabels.fold_left
    ~f:(fun acc (src, dst) ->
      match CCTrie.String.find dst acc with
      | Some srcs -> CCTrie.String.add dst (src :: srcs) acc
      | None -> CCTrie.String.add dst [ src ] acc)
    ~init:CCTrie.String.empty

let map_symlink_file_path symlinks fpath =
  match Iter.head (CCTrie.String.below fpath symlinks) with
  | Some (dst, srcs) when CCString.prefix ~pre:dst fpath ->
      CCList.map (fun src -> CCString.replace ~which:`Left ~sub:dst ~by:src fpath) srcs
  | Some _ | None -> [ fpath ]

let match_branch_tag branch_name accessor repo_config =
  let tags = repo_config.View.tags in
  let branch_tags = Sln_map.String.to_list (accessor tags) in
  CCList.find_map
    (function
      | bt, pat when Pattern.is_match pat branch_name -> Some bt
      | _, _ -> None)
    branch_tags

let compute_branch_tag ctx repo_config =
  let module T = Tags in
  match_branch_tag ctx.Ctx.branch (fun { T.branch; _ } -> branch) repo_config

let compute_dest_branch_tag ctx repo_config =
  let module T = Tags in
  match_branch_tag ctx.Ctx.dest_branch (fun { T.dest_branch; _ } -> dest_branch) repo_config

let escape_glob s =
  let b = Buffer.create (CCString.length s) in
  CCString.iter
    (function
      | ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-' | '.' | ' ' | '/') as c ->
          Buffer.add_char b c
      | c ->
          Buffer.add_char b '\\';
          Buffer.add_char b c)
    s;
  Buffer.contents b

let update_file_patterns index module_paths dirname workspacename file_patterns =
  let sub, by =
    match dirname with
    | "." ->
        (* The [.] directory is special in that our directory listings do
           not start with [./].  So if the directory is "." we assume we can
           just chop off the [${DIR}/].  So [${DIR}/*.tf] becomes [*.tf]
           instead of [./*.tf] *)
        ("${DIR}/", "")
    | dirname -> ("${DIR}", escape_glob dirname)
  in
  if Sln_set.String.mem dirname module_paths then []
  else
    let file_patterns =
      match Sln_map.String.find_opt dirname index.Index.deps with
      | Some mods ->
          CCList.filter_map
            (function
              | Index.Dep.Module path ->
                  Some (Filename.concat "${DIR}" (Filename.concat path "*.tf")))
            mods
          @ CCList.map File_pattern.file_pattern file_patterns
      | None -> CCList.map File_pattern.file_pattern file_patterns
    in
    CCList.map
      (fun pat ->
        CCResult.get_exn
          (File_pattern.make
             (process_relative_path
                (CCString.replace
                   ~sub:"${WORKSPACE}"
                   ~by:(escape_glob workspacename)
                   (CCString.replace ~sub ~by pat)))))
      file_patterns

(* Unique a sorted, guaranteed to keep the first element *)
let[@tail_mod_cons] rec uniq_succ ~eq = function
  | [] -> []
  | x :: xx :: xs when eq x xx -> uniq_succ ~eq (x :: xs)
  | x :: xs -> x :: uniq_succ ~eq xs

let derive ~ctx ~index ~file_list repo_config =
  let update_dir_config ~global_tags ~module_paths ~index dirname config =
    let update_workspace tag_prefix name tags workspace_config =
      let tags =
        [ "dir:" ^ dirname; tag_prefix ^ ":" ^ name ] @ tags @ workspace_config.Dirs.Workspace.tags
      in
      let when_modified = workspace_config.Dirs.Workspace.when_modified in
      let file_patterns =
        update_file_patterns
          index
          module_paths
          dirname
          name
          when_modified.When_modified.file_patterns
      in
      let when_modified = { when_modified with When_modified.file_patterns } in
      { Dirs.Workspace.tags = Terrat_tag_set.(to_list (of_list tags)); when_modified }
    in
    let tags = Terrat_tag_set.(to_list (of_list (global_tags @ config.Dirs.Dir.tags))) in
    let workspaces =
      Sln_map.String.mapi
        (fun workspace workspace_config ->
          update_workspace "workspace" workspace tags workspace_config)
        config.Dirs.Dir.workspaces
    in
    let stacks =
      Sln_map.String.mapi
        (fun stack stack_config -> update_workspace "stack" stack tags stack_config)
        config.Dirs.Dir.stacks
    in
    { config with Dirs.Dir.tags; workspaces; stacks }
  in
  let symlinks = build_symlinks index.Index.symlinks in
  let file_list = CCList.flat_map (map_symlink_file_path symlinks) file_list in
  let branch_tags =
    match compute_branch_tag ctx repo_config with
    | Some branch -> [ "branch:" ^ branch ]
    | None -> []
  in
  let dest_branch_tags =
    match compute_dest_branch_tag ctx repo_config with
    | Some branch -> [ "dest_branch:" ^ branch ]
    | None -> []
  in
  let global_tags = branch_tags @ dest_branch_tags in
  let dirs = repo_config.View.dirs in
  let default_when_modified = repo_config.View.when_modified in
  (* A glob dir is defined by its key in the [dirs] section having an asterisk in it. *)
  let glob_dirs =
    dirs
    |> Sln_map.String.to_list
    (* We sort the dirs section by longest-first (in terms of number of
       characters).  The heuristic is that a longer directory specification is a
       more specific and thus, to be preferred in the search. *)
    |> CCList.sort (fun (d1, _) (d2, _) -> CCInt.compare (CCString.length d2) (CCString.length d1))
    (* Any dir with '*' is considered a glob, for example foo/bar/* *)
    |> CCList.filter (fun (d, _) -> CCString.contains d '*')
    |> CCList.map (fun (d, config) -> (CCResult.get_exn (File_pattern.make d), config))
  in
  (* And conversely, non glob dirs are those without an asterisk. *)
  let non_glob_dirs =
    dirs |> Sln_map.String.to_list |> CCList.filter (fun (d, _) -> not (CCString.contains d '*'))
  in
  (* [glob_dir_matches] are those that will be filled out from a dir glob.  A
     glob dir match must match a dir glob and not have an explicit match in
     the dirs section, because explicit matches always beat glob matches. *)
  let glob_dir_matches =
    file_list
    |> CCList.filter_map (fun fname ->
        (* Only going to synthesize directories that match the filename but
              also their directory is not explicitly specified in the dirs
              section of the config.  We then translate it back to the dirname.
              This means we will get the same match multiple times as we walk
              the file list so we then have to remove duplicates *)
        CCOption.map
          (fun (d, config) ->
            (* Include the length of the matched directory in the output,
                  this is used in the case of multiple directory configs
                  matching, we take the longer. *)
            (Filename.dirname fname, CCString.length (File_pattern.to_string d), config))
          (CCList.find_opt
             (fun (d, _) ->
               (not (Sln_map.String.mem (Filename.dirname fname) dirs))
               && File_pattern.is_match d fname)
             glob_dirs))
    |> CCList.sort (fun (d1, l1, _) (d2, l2, _) ->
        (* Sort in reveres order, we want the longer matches first. *)
        let module Cmp = struct
          type t = string * int [@@deriving ord]
        end in
        Cmp.compare (d2, l2) (d1, l1))
    |> CCList.map (fun (d1, _, config) -> (d1, config))
    |> uniq_succ ~eq:(fun (d1, _) (d2, _) -> CCString.equal d1 d2)
  in
  (* [specified_dirs] is all of those dirs that have been specified in the
     [dirs] section of the config.  But we also need to create dir entries for
     all of those files that match the global [when_modified] configuration. *)
  let specified_dirs = Sln_map.String.of_list (non_glob_dirs @ glob_dir_matches) in
  let remaining_dirs =
    let make_dir_map file_list =
      CCList.fold_left
        (fun acc fname ->
          let dirname = Filename.dirname fname in
          Sln_map.String.add_to_list dirname fname acc)
        Sln_map.String.empty
        file_list
    in
    let test =
      let module Wm = When_modified in
      let all_dir_match_patterns =
        (* All patterns start with "${DIR}" because we can do an optimization for file
           checking. *)
        CCList.for_all CCFun.(File_pattern.file_pattern %> CCString.prefix ~pre:"${DIR}/")
      in
      if all_dir_match_patterns default_when_modified.Wm.file_patterns then fun (dirname, fnames) ->
        let dirname = if CCString.equal "." dirname then "" else dirname ^ "/" in
        let file_patterns =
          CCList.map
            CCFun.(
              File_pattern.to_string
              %> CCString.replace ~sub:"${DIR}/" ~by:(escape_glob dirname)
              %> File_pattern.make
              %> CCResult.get_exn)
            default_when_modified.When_modified.file_patterns
        in
        CCList.exists
          (fun fname -> CCList.exists CCFun.(flip File_pattern.is_match fname) file_patterns)
          fnames
      else CCFun.const true
    in
    file_list
    |> CCList.filter (fun fname ->
        let dirname = Filename.dirname fname in
        not (Sln_map.String.mem dirname specified_dirs))
    |> make_dir_map
    |> Sln_map.String.to_list
    |> CCList.filter test
    |> CCList.map (fun (dirname, _) ->
        let dir = Dirs.Dir.make () in
        let dir =
          {
            dir with
            Dirs.Dir.workspaces =
              Sln_map.String.map
                (fun config -> { config with Dirs.Workspace.when_modified = default_when_modified })
                dir.Dirs.Dir.workspaces;
          }
        in
        (dirname, dir))
    |> Sln_map.String.of_list
  in
  let dirs = Sln_map.String.union (fun _ _ _ -> assert false) specified_dirs remaining_dirs in
  (* Now that we have all of our dirs expanded, we also want to fill out the
     other information, such as module paths and any tags. *)
  let module_paths =
    Sln_set.String.of_list
      (Sln_map.String.fold
         (fun path values acc ->
           CCList.filter_map
             (function
               | Index.Dep.Module mod_path ->
                   Some (process_relative_path (Filename.concat path mod_path)))
             values
           @ acc)
         index.Index.deps
         [])
  in
  let existing_dirs = Sln_set.String.of_list @@ CCList.map Filename.dirname file_list in
  let dirs =
    Sln_map.String.filter_map
      (fun dirname config ->
        (* It's possible that someone configured a directory that doesn't actually
           exist, but its file patterns matched something that does exist.  Filter
           those directories out *)
        if Sln_set.String.mem dirname existing_dirs then
          Some (update_dir_config ~global_tags ~module_paths ~index dirname config)
        else None)
      dirs
  in
  { repo_config with View.dirs }

let access_control t = t.View.access_control
let apply_requirements t = t.View.apply_requirements
let automerge t = t.View.automerge
let batch_runs t = t.View.batch_runs
let config_builder t = t.View.config_builder
let cost_estimation t = t.View.cost_estimation
let create_and_select_workspace t = t.View.create_and_select_workspace

let default_branch_overrides t =
  CCOption.get_or ~default:(Default_branch_overrides.make ()) t.View.default_branch_overrides

let destination_branches t = t.View.destination_branches
let dirs t = t.View.dirs
let drift t = t.View.drift
let enabled t = t.View.enabled
let engine t = t.View.engine
let hooks t = t.View.hooks
let indexer t = t.View.indexer
let integrations t = t.View.integrations
let notifications t = t.View.notifications
let parallel_runs t = t.View.parallel_runs
let stacks t = t.View.stacks
let storage t = t.View.storage
let tags t = t.View.tags
let tree_builder t = t.View.tree_builder
let when_modified t = t.View.when_modified
let workflows t = t.View.workflows
