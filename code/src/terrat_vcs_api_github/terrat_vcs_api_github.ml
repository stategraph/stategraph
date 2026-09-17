let src = Logs.Src.create "vcs_api_github"

module Logs = (val Logs.src_log src : Logs.LOG)

let cache_capacity_mb_in_kb = ( * ) 1024
let kb_of_bytes b = CCInt.max 1 (b / 1024)
let fetch_pull_request_tries = 6
let fetch_file_length_of_git_hash = CCString.length "aa2022e256fc3435d05d9d8ca0ef0ad0805e6ea5"

let probably_is_git_hash =
  CCString.for_all (function
    | '0' .. '9' | 'a' .. 'f' -> true
    | _ -> false)

module Metrics = struct
  let namespace = "terrat"
  let subsystem = "vcs_api_github"

  let cache_fn_call_count =
    let help = "Count of cache calls by function with hit or miss or evict" in
    let family =
      Prmths.Counter.v_labels
        ~label_names:[ "lifetime"; "fn"; "type" ]
        ~help
        ~namespace
        ~subsystem
        "cache_fn_call_count"
    in
    fun ~l ~fn t -> Prmths.Counter.labels family [ l; fn; t ]

  let github_errors_total = Terrat_metrics.errors_total ~m:subsystem ~t:"github"

  let fetch_pull_request_errors_total =
    let help = "Number of errors in fetching a pull request" in
    Prmths.Counter.v ~help ~namespace ~subsystem "fetch_pull_request_errors_total"

  let pull_request_mergeable_state_count =
    let help = "Counts for the different mergeable states in pull requests fetches" in
    Prmths.Counter.v_label
      ~label_name:"mergeable_state"
      ~help
      ~namespace
      ~subsystem
      "pull_request_mergeable_state_count"
end

module Config = struct
  type t = {
    config : Terrat_config.t;
    github : Terrat_config.Github.t;
  }

  type vcs_config = Terrat_config.Github.t

  let make ~config ~vcs_config () = { config; github = vcs_config }
  let config t = t.config
  let vcs_config t = t.github
end

module User = struct
  module Id = struct
    type t = string [@@deriving yojson, show, eq]

    let of_string = CCOption.return
    let to_string = CCFun.id
  end

  type t = string [@@deriving yojson]

  let make = CCFun.id
  let id = CCFun.id
  let to_string = CCFun.id
end

module Account = struct
  module Id = struct
    type t = int [@@deriving yojson, show, eq]

    let of_string = CCInt.of_string
    let to_string = CCInt.to_string
  end

  type t = { installation_id : int } [@@deriving make, show, yojson, eq]

  let make installation_id = { installation_id }
  let id t = t.installation_id
  let to_string t = CCInt.to_string t.installation_id
end

module Comment = struct
  module Id = struct
    type t = int [@@deriving eq, ord, show, yojson]

    let of_string = CCInt.of_string
    let to_string = CCInt.to_string
  end

  type t = { id : Id.t } [@@deriving eq, yojson]

  let make ~id () = { id }
  let id t = t.id
end

module Repo = struct
  module Id = struct
    type t = int [@@deriving yojson, show, eq]

    let of_string = CCInt.of_string
    let to_string = CCInt.to_string
  end

  type t = {
    id : int;
    name : string;
    owner : string;
  }
  [@@deriving show, eq, yojson]

  let make ~id ~name ~owner () = { id; name; owner }
  let id t = t.id
  let name t = t.name
  let owner t = t.owner
  let to_string t = t.owner ^ "/" ^ t.name
end

module Remote_repo = struct
  module R = Githubc2_components.Full_repository
  module U = Githubc2_components.Simple_user

  type t = R.t [@@deriving yojson]

  let to_repo
      {
        R.primary =
          { R.Primary.id; owner = { U.primary = { U.Primary.login = owner; _ }; _ }; name; _ };
        _;
      } =
    Repo.make ~id:(CCInt64.to_int id) ~owner ~name ()

  let default_branch t = t.R.primary.R.Primary.default_branch
  let is_archived t = t.R.primary.R.Primary.archived
end

module Ref = struct
  type t = string [@@deriving show, eq, yojson]

  let to_string = CCFun.id
  let of_string = CCFun.id
end

module Directory_entry = struct
  type kind =
    [ `Dir
    | `File
    | `Submodule
    | `Symlink
    ]
  [@@deriving show, eq]

  type t = {
    kind : kind;
    name : string;
    size : int;
  }
  [@@deriving show, eq]

  let make ~kind ~name ~size () = { kind; name; size }
  let kind t = t.kind
  let name t = t.name
  let size t = t.size
end

module Pull_request = struct
  module Id = struct
    type t = int [@@deriving yojson, show, eq]

    let of_string = CCInt.of_string
    let to_string = CCInt.to_string
  end

  include Terrat_pull_request

  type 'diff t = (Id.t, 'diff, Repo.t, Ref.t) Terrat_pull_request.t [@@deriving show, to_yojson]
end

module Client = struct
  let on_hit fn () = Prmths.Counter.inc_one (Metrics.cache_fn_call_count ~l:"global" ~fn "hit")
  let on_miss fn () = Prmths.Counter.inc_one (Metrics.cache_fn_call_count ~l:"global" ~fn "miss")
  let on_evict fn () = Prmths.Counter.inc_one (Metrics.cache_fn_call_count ~l:"global" ~fn "evict")

  module Client_cache = Abbs_cache.Expiring.Make (struct
    type k = Account.t [@@deriving eq]
    type v = Githubc2_abb.t
    type err = Terrat_vcs_api.call_err
    type args = unit -> (v, err) result Abb.Future.t

    let fetch f = f ()
    let weight _ = 1
  end)

  module Fetch_directory_cache = struct
    module M = struct
      type k = Account.t * Repo.t * Ref.t * string [@@deriving eq]
      type v = Directory_entry.t list option
      type err = Terrat_github.fetch_directory_err
      type args = unit -> (v, err) result Abb.Future.t

      let fetch f = f ()

      let weight v =
        CCOption.map_or
          ~default:1
          (fun entries ->
            kb_of_bytes
              (CCList.fold_left
                 (fun weight entry -> weight + CCString.length (Directory_entry.name entry) + 16)
                 0
                 entries))
          v
    end

    module By_rev = Abbs_cache.Expiring.Make (M)
  end

  module Fetch_file_cache = struct
    module M = struct
      type k = Account.t * Repo.t * Ref.t * string [@@deriving eq]
      type v = Githubc2_components.Content_file.t option
      type err = Terrat_github.fetch_file_err
      type args = unit -> (v, err) result Abb.Future.t

      let fetch f = f ()

      let weight v =
        CCOption.map_or
          ~default:1
          CCFun.(
            Githubc2_components.Content_file.to_yojson
            %> Yojson.Safe.to_string
            %> CCString.length
            %> kb_of_bytes)
          v
    end

    module By_rev = Abbs_cache.Expiring.Make (M)
  end

  module Fetch_repo_cache = Abbs_cache.Expiring.Make (struct
    type k = Account.t * (string * string) [@@deriving eq]
    type v = Remote_repo.t
    type err = Terrat_github.fetch_repo_err
    type args = unit -> (v, err) result Abb.Future.t

    let fetch f = f ()

    let weight remote_repo =
      kb_of_bytes (CCString.length (Yojson.Safe.to_string (Remote_repo.to_yojson remote_repo)))
  end)

  (* Layered on top of [Fetch_repo_cache] on purpose.  [Abbs_cache.Expiring]
     deletes [Error] entries, so the 404 for a repository that does not exist
     is never kept there and the request goes out on every repository config
     load.  This cache keeps the selected centralized repository of an owner,
     and [Ok None] when no repository is selected.

     It is a second cache, and not a longer-lived value in the first one,
     because the two answers want different lifetimes.  A repository that
     exists stays in [Fetch_repo_cache] as long as any other repository
     metadata.  The selection must expire quickly, so that a repository somebody
     creates, or a configuration file somebody adds, becomes visible soon.  When
     an entry here expires and the repositories do exist, the inner cache
     answers without a request. *)
  module Fetch_centralized_repo_cache = Abbs_cache.Expiring.Make (struct
    type k = Account.t * string [@@deriving eq]
    type v = Remote_repo.t option
    type err = Terrat_vcs_api.call_err
    type args = unit -> (v, err) result Abb.Future.t

    let fetch f = f ()

    let weight v =
      CCOption.map_or
        ~default:1
        CCFun.(Remote_repo.to_yojson %> Yojson.Safe.to_string %> CCString.length %> kb_of_bytes)
        v
  end)

  (* Only [fetch_branch_sha_cached] reads this, and only the repository
     configuration load uses that function.  The plain [fetch_branch_sha] stays
     uncached, because the evaluator also uses it to find the ref that a run
     executes against, and that answer must be current. *)
  module Fetch_branch_sha_cache = Abbs_cache.Expiring.Make (struct
    type k = Account.t * Repo.t * Ref.t [@@deriving eq]
    type v = Ref.t option
    type err = Terrat_github.fetch_branch_err
    type args = unit -> (v, err) result Abb.Future.t

    let fetch f = f ()

    (* A commit SHA is 40 bytes, thus each entry counts as one and [capacity] is
       a count of branches. *)
    let weight _ = 1
  end)

  module Fetch_tree_cache = struct
    module M = struct
      type k = Account.t * Repo.t * Ref.t [@@deriving eq]
      type v = string list
      type err = Terrat_github.get_tree_err
      type args = unit -> (v, err) result Abb.Future.t

      let fetch f = f ()
      let weight v = kb_of_bytes (CCList.fold_left (fun weight v -> weight + CCString.length v) 0 v)
    end

    module By_rev = Abbs_cache.Expiring.Make (M)
  end

  module Globals = struct
    let client_cache =
      Client_cache.create
        {
          Abbs_cache.Expiring.on_hit = on_hit "create_client";
          on_miss = on_miss "create_client";
          on_evict = on_evict "create_client";
          duration = Duration.of_min 1;
          capacity = 500;
        }

    let fetch_directory_by_rev_cache =
      Fetch_directory_cache.By_rev.create
        {
          Abbs_cache.Expiring.on_hit = on_hit "fetch_directory_by_rev";
          on_miss = on_miss "fetch_directory_by_rev";
          on_evict = on_evict "fetch_directory_by_rev";
          duration = Duration.of_min 1;
          capacity = cache_capacity_mb_in_kb 100;
        }

    let fetch_file_by_rev_cache =
      Fetch_file_cache.By_rev.create
        {
          Abbs_cache.Expiring.on_hit = on_hit "fetch_file_by_rev";
          on_miss = on_miss "fetch_file_by_rev";
          on_evict = on_evict "fetch_file_by_rev";
          duration = Duration.of_min 1;
          capacity = cache_capacity_mb_in_kb 100;
        }

    let fetch_repo_cache =
      Fetch_repo_cache.create
        {
          Abbs_cache.Expiring.on_hit = on_hit "fetch_repo";
          on_miss = on_miss "fetch_repo";
          on_evict = on_evict "fetch_repo";
          duration = Duration.of_min 1;
          capacity = cache_capacity_mb_in_kb 20;
        }

    let fetch_branch_sha_cache =
      Fetch_branch_sha_cache.create
        {
          Abbs_cache.Expiring.on_hit = on_hit "fetch_branch_sha";
          on_miss = on_miss "fetch_branch_sha";
          on_evict = on_evict "fetch_branch_sha";
          duration = Duration.of_sec 10;
          capacity = 5000;
        }

    let fetch_centralized_repo_cache =
      Fetch_centralized_repo_cache.create
        {
          Abbs_cache.Expiring.on_hit = on_hit "fetch_centralized_repo";
          on_miss = on_miss "fetch_centralized_repo";
          on_evict = on_evict "fetch_centralized_repo";
          duration = Duration.of_sec 10;
          capacity = cache_capacity_mb_in_kb 20;
        }

    let fetch_tree_by_rev_cache =
      Fetch_tree_cache.By_rev.create
        {
          Abbs_cache.Expiring.on_hit = on_hit "fetch_tree_by_rev";
          on_miss = on_miss "fetch_tree_by_rev";
          on_evict = on_evict "fetch_tree_by_rev";
          duration = Duration.of_min 1;
          capacity = cache_capacity_mb_in_kb 100;
        }
  end

  type native = Githubc2_abb.t

  type t = {
    account : Account.t;
    client : Githubc2_abb.t;
    fetch_branch_sha_cache : Fetch_branch_sha_cache.t;
    fetch_centralized_repo_cache : Fetch_centralized_repo_cache.t;
    fetch_directory_by_rev_cache : Fetch_directory_cache.By_rev.t;
    fetch_file_by_rev_cache : Fetch_file_cache.By_rev.t;
    fetch_repo_cache : Fetch_repo_cache.t;
    fetch_tree_by_rev_cache : Fetch_tree_cache.By_rev.t;
  }

  let make ~account ~client () =
    {
      account;
      client;
      fetch_branch_sha_cache = Globals.fetch_branch_sha_cache;
      fetch_centralized_repo_cache = Globals.fetch_centralized_repo_cache;
      fetch_directory_by_rev_cache = Globals.fetch_directory_by_rev_cache;
      fetch_file_by_rev_cache = Globals.fetch_file_by_rev_cache;
      fetch_repo_cache = Globals.fetch_repo_cache;
      fetch_tree_by_rev_cache = Globals.fetch_tree_by_rev_cache;
    }

  let to_native t = t.client
end

(* A call GitHub did not answer inside the call timeout.  It is reported apart
   from [`Error] so that the user is told GitHub is unresponsive, rather than
   that something inside Terrateam broke.  [operation] names the call and is
   printed in the comment the user sees. *)
let vcs_api_timeout_err ~request_id operation =
  Prmths.Counter.inc_one Metrics.github_errors_total;
  Logs.err (fun m -> m "%s : %s : TIMEOUT" request_id operation);
  Abbs_future_combinators.return_err (`Vcs_api_timeout_err operation)

(* The branch does not exist is [Ok None], not an error, so that it is a value a
   cache can keep. *)
let fetch_branch_sha' client repo ref_ =
  let open Abb.Future.Infix_monad in
  let module B = Githubc2_components.Branch_with_protection in
  let module C = Githubc2_components.Commit in
  Terrat_github.fetch_branch
    ~owner:repo.Repo.owner
    ~repo:repo.Repo.name
    ~branch:ref_
    client.Client.client
  >>| function
  | Ok { B.primary = { B.Primary.commit = { C.primary = { C.Primary.sha; _ }; _ }; _ }; _ } ->
      Ok (Some sha)
  | Error (`Not_found _) -> Ok None
  | Error (#Terrat_github.fetch_branch_err as err) -> Error err

let fetch_branch_sha_res ~request_id = function
  | Ok sha -> Abbs_future_combinators.return_ok sha
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_BRANCH_SHA"
  | Error (#Terrat_github.fetch_branch_err as err) ->
      Logs.info (fun m ->
          m "%s : FETCH_BRANCH_SHA : %a" request_id Terrat_github.pp_fetch_branch_err err);
      Abbs_future_combinators.return_err `Error

let fetch_branch_sha ~request_id client repo ref_ =
  let open Abb.Future.Infix_monad in
  fetch_branch_sha' client repo ref_ >>= fetch_branch_sha_res ~request_id

let fetch_branch_sha_cached ~request_id client repo ref_ =
  let open Abb.Future.Infix_monad in
  Client.Fetch_branch_sha_cache.fetch
    client.Client.fetch_branch_sha_cache
    (client.Client.account, repo, ref_)
    (fun () -> fetch_branch_sha' client repo ref_)
  >>= fetch_branch_sha_res ~request_id

let fetch_directory ~request_id client repo ref_ path =
  let module D = Githubc2_components.Content_directory.Items in
  let open Abb.Future.Infix_monad in
  let fetch () =
    Terrat_github.fetch_directory
      ~owner:repo.Repo.owner
      ~repo:repo.Repo.name
      ~ref_
      ~path
      client.Client.client
    >>| CCResult.map
          (CCOption.map
             (CCList.map (fun entry ->
                  let primary = entry.D.primary in
                  {
                    Directory_entry.kind = primary.D.Primary.type_;
                    name = primary.D.Primary.name;
                    size = primary.D.Primary.size;
                  })))
  in
  (if CCString.length ref_ = fetch_file_length_of_git_hash && probably_is_git_hash ref_ then
     Client.Fetch_directory_cache.By_rev.fetch
       client.Client.fetch_directory_by_rev_cache
       (client.Client.account, repo, ref_, path)
       fetch
   else fetch ())
  >>= function
  | Ok _ as r -> Abb.Future.return r
  (* A path that holds a file, a symlink or a submodule holds no entries, which
     is what the 404 means as well, and [Terrat_github.fetch_directory] already
     answers [None] for that.  A repository that names a file [.terrateam] must
     not fail every configuration load. *)
  | Error `Not_directory -> Abbs_future_combinators.return_ok None
  (* The contents endpoint refuses to list a directory that holds too many
     entries.  The caller must read the names it wants directly. *)
  | Error (`Forbidden _ as err) ->
      Logs.info (fun m ->
          m
            "%s : FETCH_DIRECTORY : LISTING_UNAVAILABLE : %a"
            request_id
            Terrat_github.pp_fetch_directory_err
            err);
      Abbs_future_combinators.return_err `Listing_unavailable
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_DIRECTORY"
  | Error (#Terrat_github.fetch_directory_err as err) ->
      Logs.info (fun m ->
          m "%s : FETCH_DIRECTORY : %a" request_id Terrat_github.pp_fetch_directory_err err);
      Abbs_future_combinators.return_err `Error

let fetch_file ~request_id client repo ref_ path =
  let module C = Githubc2_components.Content_file in
  let open Abb.Future.Infix_monad in
  (* If we think the reference looks like a git hash, we know that the content
       of the file will never change, so we cache that in an LRU cache.
       Otherwise, we use an expiring cache. *)
  let fetch () =
    Terrat_github.fetch_file
      ~owner:repo.Repo.owner
      ~repo:repo.Repo.name
      ~ref_
      ~path
      client.Client.client
  in
  (if CCString.length ref_ = fetch_file_length_of_git_hash && probably_is_git_hash ref_ then
     Client.Fetch_file_cache.By_rev.fetch
       client.Client.fetch_file_by_rev_cache
       (client.Client.account, repo, ref_, path)
       fetch
   else fetch ())
  >>= function
  | Ok (Some { C.primary = { C.Primary.encoding = "base64"; content; _ }; _ }) ->
      Abbs_future_combinators.return_ok
        (Some (Base64.decode_exn (CCString.replace ~sub:"\n" ~by:"" content)))
  | Ok (Some { C.primary = { C.Primary.content; _ }; _ }) ->
      Abbs_future_combinators.return_ok (Some content)
  | Ok None -> Abbs_future_combinators.return_ok None
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_FILE"
  | Error (#Terrat_github.fetch_file_err as err) ->
      Logs.info (fun m -> m "%s : FETCH_FILE : %a" request_id Terrat_github.pp_fetch_file_err err);
      Abbs_future_combinators.return_err `Error

let fetch_remote_repo ~request_id client repo =
  let open Abb.Future.Infix_monad in
  let fetch () =
    Terrat_github.fetch_repo ~owner:repo.Repo.owner ~repo:repo.Repo.name client.Client.client
  in
  Client.Fetch_repo_cache.fetch
    client.Client.fetch_repo_cache
    (client.Client.account, (Repo.owner repo, Repo.name repo))
    fetch
  >>= function
  | Ok _ as r -> Abb.Future.return r
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_REMOTE_REPO"
  | Error (#Terrat_github.fetch_repo_err as err) ->
      Logs.info (fun m ->
          m "%s : FETCH_REMOTE_REPO : %a" request_id Terrat_github.pp_fetch_repo_err err);
      Abbs_future_combinators.return_err `Error

let create_client' config { Account.installation_id } =
  let open Abbs_future_combinators.Infix_result_monad in
  Terrat_github.get_installation_access_token config.Config.github installation_id
  >>| fun access_token ->
  let github_client = Terrat_github.create config.Config.github (`Token access_token) in
  github_client

let create_client ~request_id config account _db =
  let open Abb.Future.Infix_monad in
  let fetch () =
    create_client' config account
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error `Timeout -> vcs_api_timeout_err ~request_id "CREATE_CLIENT"
    | Error (#Terrat_github.get_installation_access_token_err as err) ->
        Logs.err (fun m ->
            m "%s: ERROR : %a" request_id Terrat_github.pp_get_installation_access_token_err err);
        Abbs_future_combinators.return_err `Error
  in
  Client.Client_cache.fetch Client.Globals.client_cache account fetch
  >>= function
  | Ok github_client ->
      Abbs_future_combinators.return_ok (Client.make ~account ~client:github_client ())
  | Error (`Vcs_api_timeout_err _ as err) -> Abbs_future_combinators.return_err err
  | Error `Error -> Abbs_future_combinators.return_err `Error

let fetch_tree ~request_id client repo ref_ =
  let open Abb.Future.Infix_monad in
  let fetch () =
    Terrat_github.get_tree
      ~owner:repo.Repo.owner
      ~repo:repo.Repo.name
      ~sha:ref_
      client.Client.client
  in
  (if CCString.length ref_ = fetch_file_length_of_git_hash && probably_is_git_hash ref_ then
     Client.Fetch_tree_cache.By_rev.fetch
       client.Client.fetch_tree_by_rev_cache
       (client.Client.account, repo, ref_)
       fetch
   else fetch ())
  >>= function
  | Ok _ as r -> Abb.Future.return r
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_TREE"
  | Error (#Terrat_github.get_tree_err as err) ->
      Logs.info (fun m -> m "%s : FETCH_TREE : %a" request_id Terrat_github.pp_get_tree_err err);
      Abbs_future_combinators.return_err `Error

(* Read through [Fetch_repo_cache] so that a repository that exists keeps the
   lifetime of any other repository metadata. *)
let fetch_centralized_repo ~request_id client owner =
  let open Abbs_future_combinators.Infix_result_monad in
  let module Cr = Terrat_vcs_api.Centralized_repo in
  let fetch_remote_repo name =
    let open Abb.Future.Infix_monad in
    Client.Fetch_repo_cache.fetch
      client.Client.fetch_repo_cache
      (client.Client.account, (owner, name))
      (fun () -> Terrat_github.fetch_repo ~owner ~repo:name client.Client.client)
    >>= function
    | Ok remote_repo -> Abbs_future_combinators.return_ok (Some remote_repo)
    | Error (`Not_found _) -> Abbs_future_combinators.return_ok None
    | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_CENTRALIZED_REPO"
    | Error (#Terrat_github.fetch_repo_err as err) ->
        Logs.info (fun m ->
            m "%s : FETCH_CENTRALIZED_REPO : %a" request_id Terrat_github.pp_fetch_repo_err err);
        Abbs_future_combinators.return_err `Error
  in
  (* One recursive read of the tree answers this for a repository of any shape,
     and it is kept by revision in [Fetch_tree_cache]. *)
  let holds_config repo ref_ =
    let open Abbs_future_combinators.Infix_result_monad in
    fetch_tree ~request_id client repo ref_ >>| CCList.exists Cr.is_config_path
  in
  let lookup name =
    fetch_remote_repo name
    >>= function
    | None -> Abbs_future_combinators.return_ok None
    | Some remote_repo -> (
        let repo = Remote_repo.to_repo remote_repo in
        fetch_branch_sha_cached ~request_id client repo (Remote_repo.default_branch remote_repo)
        >>= function
        | None -> Abbs_future_combinators.return_ok None
        | Some ref_ ->
            holds_config repo ref_ >>| fun holds -> if holds then Some remote_repo else None)
  in
  let open Abb.Future.Infix_monad in
  Client.Fetch_centralized_repo_cache.fetch
    client.Client.fetch_centralized_repo_cache
    (client.Client.account, owner)
    (fun () -> Cr.select lookup)
  >>= function
  | Ok _ as r -> Abb.Future.return r
  | Error (#Terrat_vcs_api.call_err as err) -> Abbs_future_combinators.return_err err

let comment_on_pull_request ~request_id client pull_request body =
  let open Abb.Future.Infix_monad in
  Terrat_github.publish_comment
    ~owner:(Repo.owner (Terrat_pull_request.repo pull_request))
    ~repo:(Repo.name (Terrat_pull_request.repo pull_request))
    ~pull_number:(Terrat_pull_request.id pull_request)
    ~body:(Terrat_comment.add_self_marker body)
    client.Client.client
  >>= function
  | Ok id -> Abbs_future_combinators.return_ok id
  | Error `Timeout -> vcs_api_timeout_err ~request_id "COMMENT_ON_PULL_REQUEST"
  | Error (#Terrat_github.publish_comment_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.info (fun m ->
          m "%s : COMMENT_ON_PULL_REQUEST : %a" request_id Terrat_github.pp_publish_comment_err err);
      Abbs_future_combinators.return_err `Error

let delete_pull_request_comment ~request_id client pull_request comment_id =
  let open Abb.Future.Infix_monad in
  Terrat_github.delete_comment
    ~owner:(Repo.owner (Terrat_pull_request.repo pull_request))
    ~repo:(Repo.name (Terrat_pull_request.repo pull_request))
    ~comment_id
    client.Client.client
  >>= function
  | Ok () -> Abbs_future_combinators.return_ok ()
  | Error (#Terrat_github.delete_comment_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.err (fun m ->
          m
            "%s : DELETE_COMMENT_ON_PULL_REQUEST : %a"
            request_id
            Terrat_github.pp_delete_comment_err
            err);
      (* Ignore all errors as this can fail for a bunch of reasons and we don't
         want to block the actual commenting *)
      Abbs_future_combinators.return_ok ()

let minimize_pull_request_comment ~request_id client pull_request comment_id =
  let open Abb.Future.Infix_monad in
  Terrat_github.minimize_comment
    ~owner:(Repo.owner (Terrat_pull_request.repo pull_request))
    ~repo:(Repo.name (Terrat_pull_request.repo pull_request))
    ~comment_id
    client.Client.client
  >>= function
  | Ok () as r -> Abb.Future.return r
  | Error (#Terrat_github.minimize_comment_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.err (fun m ->
          m
            "%s : MINIMIZE_COMMENT_ON_PULL_REQUEST : %a"
            request_id
            Terrat_github.pp_minimize_comment_err
            err);
      (* Ignore all errors as this can fail for a bunch of reasons and we don't
         want to block the actual commenting *)
      Abbs_future_combinators.return_ok ()

let diff_of_github_diff =
  CCList.map
    Githubc2_components.Diff_entry.(
      function
      | { primary = { Primary.filename; status = `Added | `Copied; _ }; _ } ->
          Terrat_change.Diff.Add { filename }
      | { primary = { Primary.filename; status = `Removed; _ }; _ } ->
          Terrat_change.Diff.Remove { filename }
      | { primary = { Primary.filename; status = `Modified | `Changed | `Unchanged; _ }; _ } ->
          Terrat_change.Diff.Change { filename }
      | {
          primary =
            { Primary.filename; status = `Renamed; previous_filename = Some previous_filename; _ };
          _;
        } -> Terrat_change.Diff.Move { filename; previous_filename }
      | _ -> assert false)

let fetch_diff_files ~request_id ~base_ref ~branch_ref repo client =
  let run =
    let open Abbs_future_combinators.Infix_result_monad in
    Terrat_github.fetch_diff_files
      ~owner:(Repo.owner repo)
      ~repo:(Repo.name repo)
      ~base_ref:(Ref.to_string base_ref)
      ~branch_ref:(Ref.to_string branch_ref)
      client.Client.client
    >>| fun github_diff ->
    (* TODO: Unique the diff?  Not sure if this is necessary? *)
    let diff = diff_of_github_diff github_diff in
    diff
  in
  let open Abb.Future.Infix_monad in
  run
  >>= function
  | Ok _ as r -> Abb.Future.return r
  | Error `Error -> Abbs_future_combinators.return_err `Error
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_DIFF_FILES"
  | Error (#Terrat_github.fetch_diff_files_err as err) ->
      Logs.info (fun m ->
          m "%s : FETCH_DIFF_FILES : %a" request_id Terrat_github.pp_fetch_diff_files_err err);
      Abbs_future_combinators.return_err `Error

let fetch_diff ~client ~owner ~repo pull_number =
  let open Abbs_future_combinators.Infix_result_monad in
  Terrat_github.fetch_pull_request_files ~owner ~repo ~pull_number client.Client.client
  >>| fun github_diff ->
  let diff = diff_of_github_diff github_diff in
  diff

let fetch_pull_request' request_id _account client repo pull_request_id =
  let owner = repo.Repo.owner in
  let repo_name = repo.Repo.name in
  let open Abbs_future_combinators.Infix_result_monad in
  Abbs_future_combinators.Infix_result_app.(
    (fun resp diff -> (resp, diff))
    <$> Terrat_github.fetch_pull_request
          ~owner
          ~repo:repo_name
          ~pull_number:pull_request_id
          client.Client.client
    <*> fetch_diff ~client ~owner ~repo:repo_name pull_request_id)
  >>| fun (pr, diff) ->
  let module Ghc_comp = Githubc2_components in
  let module Pr = Ghc_comp.Pull_request in
  let module Head = Pr.Primary.Head in
  let module Base = Pr.Primary.Base in
  let module User = Ghc_comp.Simple_user in
  let {
    Ghc_comp.Pull_request.primary =
      {
        Ghc_comp.Pull_request.Primary.head;
        base;
        state;
        merged;
        merged_at;
        merge_commit_sha;
        mergeable_state;
        draft;
        title;
        user = User.{ primary = Primary.{ login; _ }; _ };
        _;
      };
    _;
  } =
    pr
  in
  let base_branch_name = Base.(base.primary.Primary.ref_) in
  let base_sha = Base.(base.primary.Primary.sha) in
  let head_sha = Head.(head.primary.Primary.sha) in
  let branch_name = Head.(head.primary.Primary.ref_) in
  let draft = CCOption.get_or ~default:false draft in
  Prmths.Counter.inc_one (Metrics.pull_request_mergeable_state_count mergeable_state);
  Logs.info (fun m ->
      m
        "%s : PULL_REQUEST : pull_number=%d : base_branch_name=%s : base_ref=%s : branch_name=%s : \
         branch_ref=%s : merged=%s : mergable_state=%s : merge_commit_sha=%s : merged_at=%s"
        request_id
        pull_request_id
        base_branch_name
        base_sha
        branch_name
        head_sha
        (Bool.to_string merged)
        mergeable_state
        (CCOption.get_or ~default:"" merge_commit_sha)
        (CCOption.get_or ~default:"" merged_at));
  Terrat_pull_request.make
    ~base_branch_name
    ~base_ref:base_sha
    ~branch_name
    ~branch_ref:head_sha
    ~id:pull_request_id
    ~state:
      (match (merge_commit_sha, state, merged, merged_at) with
      | _, `Open, _, _ -> Terrat_pull_request.State.Open
      | Some merge_commit_sha, `Closed, true, Some merged_at ->
          Terrat_pull_request.State.(Merged Merged.{ merged_hash = merge_commit_sha; merged_at })
      | _, `Closed, false, _ -> Terrat_pull_request.State.Closed
      | _, _, _, _ -> assert false)
    ~title:(Some title)
    ~user:(Some login)
    ~repo
    ~diff
    ~draft
    ~provisional_merge_ref:merge_commit_sha
    ()

let fetch_pull_request ~request_id account client repo pull_request_id =
  let open Abb.Future.Infix_monad in
  let fetch () =
    Logs.info (fun m ->
        m
          "%s : FETCH_PULL_REQUEST : repo=%s : pull_request_id=%s"
          request_id
          (Repo.to_string repo)
          (Pull_request.Id.to_string pull_request_id));
    fetch_pull_request' request_id account client repo pull_request_id
  in
  let f () =
    fetch ()
    >>= function
    | Ok ret -> Abbs_future_combinators.return_ok ret
    | Error
        ( `Not_found _
        | `Internal_server_error _
        | `Not_modified
        | `Service_unavailable _
        | `Not_acceptable _ ) as err -> Abb.Future.return err
    | Error `Error ->
        Prmths.Counter.inc_one Metrics.github_errors_total;
        Logs.err (fun m -> m "%s : ERROR : repo=%s : ERROR" request_id (Repo.to_string repo));
        Abbs_future_combinators.return_err `Error
    | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_PULL_REQUEST"
    | Error (#Terrat_github.fetch_pull_request_err as err) ->
        Prmths.Counter.inc_one Metrics.github_errors_total;
        Logs.err (fun m ->
            m
              "%s : ERROR : repo=%s : %a"
              request_id
              (Repo.to_string repo)
              Terrat_github.pp_fetch_pull_request_err
              err);
        Abbs_future_combinators.return_err `Error
  in
  Abbs_future_combinators.retry
    ~f
    ~while_:
      (Abbs_future_combinators.finite_tries fetch_pull_request_tries (function
        | Error _ -> true
        | Ok _ -> false))
    ~betwixt:
      (Abbs_future_combinators.series ~start:2.0 ~step:(( *. ) 1.5) (fun n _ ->
           Prmths.Counter.inc_one Metrics.fetch_pull_request_errors_total;
           Abb.Sys.sleep (CCFloat.min n 8.0)))
  >>= function
  | Ok ret -> Abbs_future_combinators.return_ok ret
  | Error (`Not_found _)
  | Error (`Internal_server_error _)
  | Error `Not_modified
  | Error (`Service_unavailable _)
  | Error (`Not_acceptable _)
  | Error `Error -> Abbs_future_combinators.return_err `Error
  | Error (`Vcs_api_timeout_err _ as err) -> Abbs_future_combinators.return_err err

(* GitHub computes the merge asynchronously and answers [unknown] until it is done, so this call
   waits for it.  It is its own request, and not part of [fetch_pull_request], because only the
   apply requirements need the answer: when the wait lived in [fetch_pull_request] every caller paid
   it, including the plan, tree and index paths that never read the result. *)
let fetch_pull_request_mergeable ~request_id repo pull_request_id client =
  let module Ghc_comp = Githubc2_components in
  let open Abb.Future.Infix_monad in
  let mergeable_state pr =
    pr.Ghc_comp.Pull_request.primary.Ghc_comp.Pull_request.Primary.mergeable_state
  in
  let f () =
    Logs.info (fun m ->
        m
          "%s : FETCH_PULL_REQUEST_MERGEABLE : repo=%s : pull_request_id=%s"
          request_id
          (Repo.to_string repo)
          (Pull_request.Id.to_string pull_request_id));
    Terrat_github.fetch_pull_request
      ~owner:(Repo.owner repo)
      ~repo:(Repo.name repo)
      ~pull_number:pull_request_id
      client.Client.client
    >>= function
    | Ok _ as ret -> Abb.Future.return ret
    | Error `Error ->
        Prmths.Counter.inc_one Metrics.github_errors_total;
        Logs.err (fun m -> m "%s : ERROR : repo=%s : ERROR" request_id (Repo.to_string repo));
        Abbs_future_combinators.return_err `Error
    | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_PULL_REQUEST_MERGEABLE"
    | Error (#Terrat_github.fetch_pull_request_err as err) ->
        Prmths.Counter.inc_one Metrics.github_errors_total;
        Logs.err (fun m ->
            m
              "%s : ERROR : repo=%s : %a"
              request_id
              (Repo.to_string repo)
              Terrat_github.pp_fetch_pull_request_err
              err);
        Abbs_future_combinators.return_err `Error
  in
  Abbs_future_combinators.retry
    ~f
    ~while_:
      (Abbs_future_combinators.finite_tries fetch_pull_request_tries (function
        | Error _ -> true
        | Ok pr -> CCString.equal "unknown" (mergeable_state pr)))
    ~betwixt:
      (Abbs_future_combinators.series ~start:2.0 ~step:(( *. ) 1.5) (fun n _ ->
           Prmths.Counter.inc_one Metrics.fetch_pull_request_errors_total;
           Abb.Sys.sleep (CCFloat.min n 8.0)))
  >>= function
  | Ok pr ->
      let mergeable = pr.Ghc_comp.Pull_request.primary.Ghc_comp.Pull_request.Primary.mergeable in
      Prmths.Counter.inc_one (Metrics.pull_request_mergeable_state_count (mergeable_state pr));
      Logs.info (fun m ->
          m
            "%s : PULL_REQUEST_MERGEABLE : pull_request_id=%s : mergable_state=%s : mergeable=%s"
            request_id
            (Pull_request.Id.to_string pull_request_id)
            (mergeable_state pr)
            (CCOption.map_or ~default:"<none>" Bool.to_string mergeable));
      Abbs_future_combinators.return_ok mergeable
  | Error `Error -> Abbs_future_combinators.return_err `Error
  | Error (`Vcs_api_timeout_err _ as err) -> Abbs_future_combinators.return_err err

let react_to_comment ~request_id client pull_request comment_id =
  let open Abb.Future.Infix_monad in
  let repo = Terrat_pull_request.repo pull_request in
  Terrat_github.react_to_comment
    ~owner:(Repo.owner repo)
    ~repo:(Repo.name repo)
    ~comment_id
    client.Client.client
  >>= function
  | Ok () -> Abbs_future_combinators.return_ok ()
  | Error `Timeout -> vcs_api_timeout_err ~request_id "REACT_TO_COMMENT"
  | Error (#Terrat_github.publish_reaction_err as err) ->
      Logs.info (fun m ->
          m "%s : REACT_TO_COMMENT : %a" request_id Terrat_github.pp_publish_reaction_err err);
      Abbs_future_combinators.return_err `Error

let create_commit_checks ~request_id ~brand client repo ref_ checks =
  let open Abb.Future.Infix_monad in
  Logs.info (fun m -> m "%s : CREATE_COMMIT_CHECKS : num=%d" request_id (CCList.length checks));
  (* Titles are canonical ("terrateam ...") internally; the brand is applied
     only here, at the VCS boundary. *)
  let checks =
    CCList.map
      (fun c ->
        {
          c with
          Terrat_commit_check.title =
            Terrat_check_title.branded_with ~brand c.Terrat_commit_check.title;
        })
      checks
  in
  Terrat_vcs_api_github_commit_check.create
    ~owner:(Repo.owner repo)
    ~repo:(Repo.name repo)
    ~ref_
    ~checks
    client.Client.client
  >>= function
  | Ok () -> Abbs_future_combinators.return_ok ()
  | Error `Timeout -> vcs_api_timeout_err ~request_id "CREATE_COMMIT_CHECKS"
  | Error (#Githubc2_abb.call_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.err (fun m -> m "%s : ERROR : %a" request_id Githubc2_abb.pp_call_err err);
      Abbs_future_combinators.return_err `Error

let fetch_commit_checks ~request_id client repo ref_ =
  let open Abb.Future.Infix_monad in
  let owner = Repo.owner repo in
  let repo = Repo.name repo in
  Abbs_time_it.run
    (fun time -> Logs.info (fun m -> m "%s : LIST_COMMIT_CHECKS : %f" request_id time))
    (fun () ->
      Terrat_vcs_api_github_commit_check.list
        ~log_id:request_id
        ~owner
        ~repo
        ~ref_
        client.Client.client)
  >>= function
  | Ok checks ->
      (* Normalize fetched titles so internal comparisons accept both brands. *)
      Abbs_future_combinators.return_ok
        (CCList.map
           (fun c ->
             {
               c with
               Terrat_commit_check.title = Terrat_check_title.canonical c.Terrat_commit_check.title;
             })
           checks)
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_COMMIT_CHECKS"
  | Error (#Terrat_vcs_api_github_commit_check.list_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.info (fun m ->
          m
            "%s : FETCH_COMMIT_CHECKS : %a"
            request_id
            Terrat_vcs_api_github_commit_check.pp_list_err
            err);
      Abbs_future_combinators.return_err `Error

let fetch_pull_request_reviews ~request_id repo pull_request_id client =
  let open Abb.Future.Infix_monad in
  let owner = Repo.owner repo in
  let repo = Repo.name repo in
  let pull_number = pull_request_id in
  Terrat_github.Pull_request_reviews.list ~owner ~repo ~pull_number client.Client.client
  >>= function
  | Ok reviews ->
      let module Prr = Githubc2_components.Pull_request_review in
      Abbs_future_combinators.return_ok
        (CCList.map
           (fun Prr.{ primary = Primary.{ node_id; state; user; _ }; _ } ->
             Terrat_pull_request_review.
               {
                 id = node_id;
                 status =
                   (match state with
                   | "APPROVED" -> Status.Approved
                   | _ -> Status.Unknown);
                 user =
                   CCOption.map
                     (fun Githubc2_components.Nullable_simple_user.
                            { primary = Primary.{ login; _ }; _ }
                        -> login)
                     user;
               })
           reviews)
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_PULL_REQUEST_REVIEWS"
  | Error (#Terrat_github.Pull_request_reviews.list_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.info (fun m -> m "%s : %a" request_id Terrat_github.Pull_request_reviews.pp_list_err err);
      Abbs_future_combinators.return_err `Error

let fetch_pull_request_requested_reviews ~request_id repo pull_number client =
  let module Resp = Githubc2_pulls.List_requested_reviewers.Responses in
  let run =
    let open Abbs_future_combinators.Infix_result_monad in
    Githubc2_abb.call
      client.Client.client
      Githubc2_pulls.List_requested_reviewers.(
        make (Parameters.make ~owner:repo.Repo.owner ~repo:repo.Repo.name ~pull_number))
    >>| fun resp ->
    let module Rr = Githubc2_components.Pull_request_review_request in
    let (`OK { Rr.primary = { Rr.Primary.teams; users }; _ }) = Openapi.Response.value resp in
    let module T = Githubc2_components_team in
    let module U = Githubc2_components_simple_user in
    CCList.map
      (fun { T.primary = { T.Primary.name; _ }; _ } ->
        Terrat_base_repo_config_v1.Access_control.Match.Team name)
      teams
    @ CCList.map
        (fun { U.primary = { U.Primary.login; _ }; _ } ->
          Terrat_base_repo_config_v1.Access_control.Match.User login)
        users
  in
  let open Abb.Future.Infix_monad in
  run
  >>= function
  | Ok _ as r -> Abb.Future.return r
  | Error (#Resp.t as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.info (fun m -> m "%s : FETCH_PULL_REQUEST_REQUESTED_REVIEWS : %a" request_id Resp.pp err);
      Abbs_future_combinators.return_err `Error
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_PULL_REQUEST_REQUESTED_REVIEWS"
  | Error (#Githubc2_abb.call_err as err) ->
      Logs.err (fun m ->
          m "%s : FETCH_PULL_REQUEST_REQUESTED_REVIEWS: %a" request_id Githubc2_abb.pp_call_err err);
      Abbs_future_combinators.return_err `Error

let fetch_pull_request_review_decision ~request_id repo pull_number client =
  let module D = Terrat_pull_request_review.Decision in
  let open Abb.Future.Infix_monad in
  Terrat_github.fetch_pull_request_review_decision
    ~owner:repo.Repo.owner
    ~repo:repo.Repo.name
    ~pull_number
    client.Client.client
  >>= function
  | Ok None -> Abbs_future_combinators.return_ok None
  | Ok (Some "APPROVED") -> Abbs_future_combinators.return_ok (Some D.Approved)
  | Ok (Some "CHANGES_REQUESTED") -> Abbs_future_combinators.return_ok (Some D.Changes_requested)
  | Ok (Some "REVIEW_REQUIRED") -> Abbs_future_combinators.return_ok (Some D.Review_required)
  | Ok (Some decision) ->
      (* A value outside the documented enum means GitHub changed the API under
         us.  Erroring is safer than guessing which way it should resolve. *)
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.err (fun m ->
          m "%s : FETCH_PULL_REQUEST_REVIEW_DECISION : UNKNOWN : %s" request_id decision);
      Abbs_future_combinators.return_err `Error
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FETCH_PULL_REQUEST_REVIEW_DECISION"
  | Error (#Terrat_github.fetch_pull_request_review_decision_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.err (fun m ->
          m
            "%s : FETCH_PULL_REQUEST_REVIEW_DECISION : %a"
            request_id
            Terrat_github.pp_fetch_pull_request_review_decision_err
            err);
      Abbs_future_combinators.return_err `Error

(* The merge of a pull request.

   GitHub has two merge endpoints.  The asynchronous one is the only one that can
   merge a pull request which is part of a stack -- GitHub's documentation says a
   stack "cannot be merged with the legacy synchronous merge endpoints" -- and it
   merges an unstacked pull request just as well, so it is the one to reach for.
   It is recent, so a GitHub Enterprise Server that has not been upgraded answers
   404 for it; those installations fall back to the synchronous endpoint.

   Failures divide in two, and the distinction is the whole point of the split:

   [`Merge_retry] is a merge that is not ready yet.  Most often GitHub still
   reports a required check as pending for a while after the check was set, so the
   first attempts are refused and later ones succeed.  Only these are retried.

   [`Merge_err] is a merge GitHub declined for a settled reason.  Retrying cannot
   help, and the caller reports the message to the user.

   Every response GitHub describes maps to one of the two, so an automerge that
   fails always says why.  It used to be that only a 405 or a 409 carrying a
   message did, and every other failure became an internal error that was written
   to the log and never reached the pull request. *)

let merge_err_of_basic_error what err =
  let module Be = Githubc2_components.Basic_error in
  let { Be.primary = { Be.Primary.message; _ }; _ } = err in
  `Merge_err (CCOption.get_or ~default:what message)

(* The detail of an asynchronous merge.  Which fields are set depends on the
   status, so they are all optional; see the note on this schema in
   api_schemas/github_api/README.md. *)
let merge_async_detail result =
  let module R = Githubc2_components.Pull_request_merge_async_result in
  let module D = R.Details in
  let { R.details; _ } = result in
  let { D.primary = { D.Primary.message; uuid; _ }; _ } = details in
  (message, uuid)

let merge_async_message ~default result = CCOption.get_or ~default (fst (merge_async_detail result))

(* Ask for the result of an asynchronous merge until it settles.  A merge of a
   whole stack takes several seconds, so this needs a longer budget than a single
   call, but it must still end: a merge left pending is reported rather than
   waited on for ever, because the merge may yet land and asking again is safe
   only through the 409 that says one is already enqueued. *)
let poll_merge_async request_id client repo pull_number uuid =
  let open Abbs_future_combinators.Infix_result_monad in
  let module R = Githubc2_components.Pull_request_merge_async_result in
  let num_tries = 10 in
  let settled = function
    | Ok (`Pending _) -> false
    | Ok (`Settled _) | Error _ -> true
  in
  Abbs_future_combinators.retry
    ~f:(fun () ->
      let open Abb.Future.Infix_monad in
      Githubc2_abb.call
        client.Client.client
        Githubc2_pulls.Get_merge_async_result.(
          make Parameters.(make ~owner:repo.Repo.owner ~repo:repo.Repo.name ~pull_number ~uuid))
      >>= function
      | Ok resp -> (
          match Openapi.Response.value resp with
          | `OK ({ R.status = `Merged | `Enqueued; _ } as result) ->
              Logs.info (fun m ->
                  m
                    "%s : MERGE_PULL_REQUEST : ASYNC_SETTLED : uuid=%s : %s"
                    request_id
                    uuid
                    (merge_async_message ~default:"merged" result));
              Abbs_future_combinators.return_ok (`Settled ())
          | `OK ({ R.status = `Failed; _ } as result) ->
              Abbs_future_combinators.return_err
                (`Merge_err (merge_async_message ~default:"The merge failed." result))
          | `OK ({ R.status = `Pending; _ } as result) ->
              Abbs_future_combinators.return_ok (`Pending result)
          | `Forbidden err | `Not_found err ->
              Abbs_future_combinators.return_err
                (merge_err_of_basic_error "GitHub would not report the result of the merge." err))
      | Error `Timeout -> vcs_api_timeout_err ~request_id "MERGE_PULL_REQUEST_ASYNC_RESULT"
      | Error (#Githubc2_abb.call_err as err) ->
          Logs.info (fun m ->
              m
                "%s : MERGE_PULL_REQUEST : ASYNC_RESULT : %a"
                request_id
                Githubc2_abb.pp_call_err
                err);
          Abbs_future_combinators.return_err
            (`Merge_err "GitHub sent a response that could not be read."))
    ~while_:(Abbs_future_combinators.finite_tries num_tries (fun r -> not (settled r)))
    ~betwixt:
      (Abbs_future_combinators.series ~start:1.5 ~step:(( *. ) 1.5) (fun n _ -> Abb.Sys.sleep n))
  >>= function
  | `Settled () -> Abbs_future_combinators.return_ok ()
  | `Pending _ ->
      (* Do not send the merge again.  It may still land, and a second request is
         only safe because of the 409 that says one is already enqueued. *)
      Abbs_future_combinators.return_err
        (`Merge_err "The merge did not finish in time.  Look at the pull request for its state.")

let merge_pull_request_async request_id client pull_request ~merge_method ~commit_title =
  let open Abbs_future_combinators.Infix_result_monad in
  let module R = Githubc2_components.Pull_request_merge_async_result in
  let repo = Terrat_pull_request.repo pull_request in
  let pull_number = Terrat_pull_request.id pull_request in
  Githubc2_abb.call
    client.Client.client
    Githubc2_pulls.Merge_async.(
      make
        ~body:
          Request_body.(
            make
              Primary.(
                make
                  ~commit_title:(Some commit_title)
                  ~merge_method:(Some merge_method)
                    (* Terrateam has no merge queue support, so ask for the merge
                       that the synchronous endpoint used to perform. *)
                  ~merge_action:(Some `Direct_merge)
                  ()))
        Parameters.(make ~owner:repo.Repo.owner ~repo:repo.Repo.name ~pull_number))
  >>= fun resp ->
  (* [settle] is the same for every status that carries a result, because what to
     do next is in the result and not in the status.  A 409 is one of them: it
     says a merge is already enqueued and describes that merge, so following it is
     right, and it is how the synchronous endpoint's "Merge already in progress"
     was treated. *)
  let settle result =
    match result.R.status with
    | `Merged | `Enqueued -> Abbs_future_combinators.return_ok ()
    | `Pending -> (
        match snd (merge_async_detail result) with
        | Some uuid -> poll_merge_async request_id client repo pull_number uuid
        | None ->
            Abbs_future_combinators.return_err
              (`Merge_err "GitHub accepted the merge but gave no way to follow it."))
    | `Failed ->
        Abbs_future_combinators.return_err
          (`Merge_err (merge_async_message ~default:"The merge failed." result))
  in
  match Openapi.Response.value resp with
  | `OK result | `Accepted result | `Conflict result -> settle result
  | `Bad_request result ->
      (* The pull request is not ready to be merged.  A required check that GitHub
         has not caught up with is the usual cause, so this is worth another try. *)
      Abbs_future_combinators.return_err
        (`Merge_retry
           (merge_async_message ~default:"The pull request is not ready to merge." result))
  | `Not_found _ ->
      (* This GitHub does not have the asynchronous merge endpoint. *)
      Abbs_future_combinators.return_err `Async_unsupported
  | `Forbidden err ->
      Abbs_future_combinators.return_err
        (merge_err_of_basic_error "GitHub would not permit the merge." err)
  | `Unprocessable_entity err ->
      let module Ve = Githubc2_components.Validation_error in
      let { Ve.primary = { Ve.Primary.message; _ }; _ } = err in
      Abbs_future_combinators.return_err (`Merge_err message)

let merge_pull_request_sync client pull_request ~merge_method ~commit_title =
  let open Abbs_future_combinators.Infix_result_monad in
  let repo = Terrat_pull_request.repo pull_request in
  let pull_number = Terrat_pull_request.id pull_request in
  let module Mna = Githubc2_pulls.Merge.Responses.Method_not_allowed in
  let module Cf = Githubc2_pulls.Merge.Responses.Conflict in
  let module Ve = Githubc2_components.Validation_error in
  Githubc2_abb.call
    client.Client.client
    Githubc2_pulls.Merge.(
      make
        ~body:
          Request_body.(
            make
              Primary.(make ~commit_title:(Some commit_title) ~merge_method:(Some merge_method) ()))
        Parameters.(make ~owner:repo.Repo.owner ~repo:repo.Repo.name ~pull_number))
  >>= fun resp ->
  match Openapi.Response.value resp with
  | `OK _ -> Abbs_future_combinators.return_ok ()
  | `Method_not_allowed { Mna.primary = { Mna.Primary.message = Some message; _ }; _ }
    when CCString.equal "Merge already in progress" message -> Abbs_future_combinators.return_ok ()
  | `Method_not_allowed { Mna.primary = { Mna.Primary.message; _ }; _ } ->
      Abbs_future_combinators.return_err
        (`Merge_err (CCOption.get_or ~default:"GitHub would not merge the pull request." message))
  | `Conflict { Cf.primary = { Cf.Primary.message; _ }; _ } ->
      (* The head moved, or a check has not settled.  Both are worth another try. *)
      Abbs_future_combinators.return_err
        (`Merge_retry (CCOption.get_or ~default:"The pull request is not ready to merge." message))
  | `Forbidden err ->
      Abbs_future_combinators.return_err
        (merge_err_of_basic_error "GitHub would not permit the merge." err)
  | `Not_found err ->
      Abbs_future_combinators.return_err
        (merge_err_of_basic_error "GitHub could not find the pull request." err)
  | `Unprocessable_entity { Ve.primary = { Ve.Primary.message; _ }; _ } ->
      Abbs_future_combinators.return_err (`Merge_err message)

let merge_pull_request' ?(retain_pr_title = false) request_id client pull_request merge_strategy =
  let module Ms = Terrat_base_repo_config_v1.Automerge.Merge_strategy in
  let repo = Terrat_pull_request.repo pull_request in
  let merge_method =
    match merge_strategy with
    | Ms.Auto -> `Merge
    | Ms.Merge -> `Merge
    | Ms.Squash -> `Squash
    | Ms.Rebase -> `Rebase
  in
  let commit_title =
    match (retain_pr_title, Terrat_pull_request.title pull_request) with
    | true, Some title -> Printf.sprintf "%s (#%d)" title (Terrat_pull_request.id pull_request)
    | (true | false), (Some _ | None) ->
        Printf.sprintf "Terrateam Automerge #%d" (Terrat_pull_request.id pull_request)
  in
  let merge ~merge_method =
    let open Abb.Future.Infix_monad in
    merge_pull_request_async request_id client pull_request ~merge_method ~commit_title
    >>= function
    | Error `Async_unsupported ->
        Logs.info (fun m ->
            m
              "%s : MERGE_PULL_REQUEST : ASYNC_UNSUPPORTED : %s : %s : %d"
              request_id
              (Repo.owner repo)
              (Repo.name repo)
              (Terrat_pull_request.id pull_request));
        merge_pull_request_sync client pull_request ~merge_method ~commit_title
    | ( Ok ()
      | Error
          ( `Merge_err _ | `Merge_retry _ | `Timeout | `Vcs_api_timeout_err _
          | #Githubc2_abb.call_err ) ) as r -> Abb.Future.return r
  in
  Logs.info (fun m ->
      m
        "%s : MERGE_PULL_REQUEST : %s : %s : %d"
        request_id
        (Repo.owner repo)
        (Repo.name repo)
        (Terrat_pull_request.id pull_request));
  let open Abb.Future.Infix_monad in
  merge ~merge_method
  >>= function
  | Error (`Merge_err _) when merge_strategy = Ms.Auto && merge_method <> `Squash ->
      (* [Auto] means "whatever this repository allows".  A repository that does
         not allow merge commits declines the merge, so squash is the fallback,
         which is what the synchronous path did on a 405. *)
      Logs.info (fun m ->
          m
            "%s : MERGE_METHOD_NOT_ALLOWED : METHOD %s : %s : %s : %d"
            request_id
            (Ms.to_string merge_strategy)
            (Repo.owner repo)
            (Repo.name repo)
            (Terrat_pull_request.id pull_request));
      merge ~merge_method:`Squash
  | r -> Abb.Future.return r

let merge_pull_request ~request_id ?retain_pr_title client pull_request merge_strategy =
  (* GitHub can still report a required status check as pending for a while after
     the check has been set, so a merge that is going to succeed refuses the first
     attempts.  A flat two second sleep gave that about eight seconds end to end,
     short enough that ordinary propagation exhausted it and the pull request was
     left unmerged with every check green.  Back off the way the rest of the
     GitHub calls do, which measures at about fifty seconds against a real repo.
     The cost is that a merge failing for a settled reason, a missing review say,
     takes that long to be reported, which is the cheaper of the two mistakes.
     Note [finite_tries] permits one attempt more than the count it is given. *)
  let num_tries = 6 in
  let open Abb.Future.Infix_monad in
  Abbs_future_combinators.retry
    ~f:(fun () ->
      merge_pull_request' ?retain_pr_title request_id client pull_request merge_strategy
      >>= function
      | Ok _ as ret -> Abb.Future.return ret
      | Error `Timeout -> vcs_api_timeout_err ~request_id "MERGE_PULL_REQUEST"
      | Error (#Githubc2_abb.call_err as err) ->
          Logs.info (fun m ->
              m "%s : MERGE_PULL_REQUEST : %a" request_id Githubc2_abb.pp_call_err err);
          (* GitHub answered with something this client cannot read.  That is still
             a merge that did not happen, and the user is owed a reason. *)
          Abbs_future_combinators.return_err
            (`Merge_err "GitHub sent a response that could not be read.")
      | Error ((`Merge_err _ | `Merge_retry _) as err) ->
          Logs.info (fun m ->
              m
                "%s : MERGE_PULL_REQUEST : %s"
                request_id
                (match err with
                | `Merge_err message -> "MERGE_ERR : " ^ message
                | `Merge_retry message -> "MERGE_RETRY : " ^ message));
          Abbs_future_combinators.return_err err
      | Error (`Vcs_api_timeout_err _) as err -> Abb.Future.return err)
    ~while_:
      (Abbs_future_combinators.finite_tries num_tries (function
        | Error (`Merge_retry _) -> true
        | Ok _ | Error _ -> false))
    ~betwixt:
      (Abbs_future_combinators.series ~start:1.5 ~step:(( *. ) 1.5) (fun n _ -> Abb.Sys.sleep n))
  >>= function
  (* The tries ran out on a merge that was never ready.  Tell the user why rather
     than letting it become an internal error nobody sees. *)
  | Error (`Merge_retry message) -> Abbs_future_combinators.return_err (`Merge_err message)
  | (Ok () | Error (`Merge_err _ | `Error | `Vcs_api_timeout_err _)) as r -> Abb.Future.return r

let delete_branch' request_id client repo branch =
  let open Abbs_future_combinators.Infix_result_monad in
  Logs.info (fun m ->
      m
        "%s : DELETE_PULL_REQUEST_BRANCH : %s : %s : %s"
        request_id
        repo.Repo.owner
        repo.Repo.name
        branch);
  Githubc2_abb.call
    client.Client.client
    Githubc2_git.Delete_ref.(
      make Parameters.(make ~owner:repo.Repo.owner ~repo:repo.Repo.name ~ref_:("heads/" ^ branch)))
  >>| fun resp ->
  match Openapi.Response.value resp with
  | `No_content -> ()
  | `Unprocessable_entity ->
      (* GitHub sends this with no body, so there is nothing to log but the branch. *)
      Logs.info (fun m ->
          m
            "%s : DELETE_PULL_REQUEST_BRANCH : %s : %s : %s : UNPROCESSABLE_ENTITY"
            request_id
            repo.Repo.owner
            repo.Repo.name
            branch);
      ()
  | `Conflict err ->
      Logs.info (fun m ->
          m
            "%s : DELETE_PULL_REQUEST_BRANCH : %s : %s : %s : %a"
            request_id
            repo.Repo.owner
            repo.Repo.name
            branch
            Githubc2_components.Basic_error.pp
            err);
      ()

let delete_branch ~request_id client repo branch =
  let open Abb.Future.Infix_monad in
  delete_branch' request_id client repo branch
  >>= function
  | Ok _ as ret -> Abb.Future.return ret
  | Error `Timeout -> vcs_api_timeout_err ~request_id "DELETE_BRANCH"
  | Error (#Githubc2_abb.call_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.info (fun m ->
          m "%s : DELETE_PULL_REQUEST_BRANCH : %a" request_id Githubc2_abb.pp_call_err err);
      Abbs_future_combinators.return_err `Error
  | Error `Error -> Abbs_future_combinators.return_err `Error

let is_member_of_team ~request_id ~team ~user repo client =
  let open Abb.Future.Infix_monad in
  Terrat_github.get_team_membership_in_org ~org:(Repo.owner repo) ~team ~user client.Client.client
  >>= function
  | Ok _ as res -> Abb.Future.return res
  | Error `Timeout -> vcs_api_timeout_err ~request_id "IS_MEMBER_OF_TEAM"
  | Error (#Terrat_github.get_team_membership_in_org_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.info (fun m ->
          m
            "%s : DELETE_PULL_REQUEST_BRANCH : %a"
            request_id
            Terrat_github.pp_get_team_membership_in_org_err
            err);
      Abbs_future_combinators.return_err `Error

let get_repo_role ~request_id repo user client =
  let open Abb.Future.Infix_monad in
  Terrat_github.get_repo_collaborator_permission
    ~org:(Repo.owner repo)
    ~repo:(Repo.name repo)
    ~user
    client.Client.client
  >>= function
  | Ok _ as res -> Abb.Future.return res
  | Error `Timeout -> vcs_api_timeout_err ~request_id "GET_REPO_ROLE"
  | Error (#Terrat_github.get_repo_collaborator_permission_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.info (fun m ->
          m
            "%s : DELETE_PULL_REQUEST_BRANCH : %a"
            request_id
            Terrat_github.pp_get_repo_collaborator_permission_err
            err);
      Abbs_future_combinators.return_err `Error

let get_org_role ~request_id ~org user client =
  let open Abb.Future.Infix_monad in
  Terrat_github.get_org_membership ~org ~user:(User.to_string user) client.Client.client
  >>= function
  | Ok _ as res -> Abb.Future.return res
  | Error `Timeout -> vcs_api_timeout_err ~request_id "GET_ORG_ROLE"
  | Error (#Terrat_github.get_org_membership_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.info (fun m ->
          m "%s : GET_ORG_ROLE : %a" request_id Terrat_github.pp_get_org_membership_err err);
      Abbs_future_combinators.return_err `Error

let find_workflow_file ~request_id repo client =
  let open Abb.Future.Infix_monad in
  Terrat_github.find_workflow_file
    ~owner:(Repo.owner repo)
    ~repo:(Repo.name repo)
    client.Client.client
  >>= function
  | Ok _ as res -> Abb.Future.return res
  | Error `Timeout -> vcs_api_timeout_err ~request_id "FIND_WORKFLOW_FILE"
  | Error (#Terrat_github.get_installation_access_token_err as err) ->
      Prmths.Counter.inc_one Metrics.github_errors_total;
      Logs.info (fun m ->
          m
            "%s : FIND_WORKFLOW_FILE : %a"
            request_id
            Terrat_github.pp_get_installation_access_token_err
            err);
      Abbs_future_combinators.return_err `Error
