include
  Terrat_vcs_api.S
    with type Account.Id.t = int
     and type Config.vcs_config = Terrat_config.Gitlab.t
     and type Client.native = Openapic_abb.t
     and type User.Id.t = string
     and type Pull_request.Id.t = int
     and type Repo.Id.t = int

(** What a response that may be a rate limit rejection warrants. [`No_wait] if it is not one,
    [`Wait secs] to back off for [secs] and try again, and [`Fail secs] when [secs] is longer than
    [max_wait]. [max_wait] is the time budget the call was given: a back off longer than the budget
    cannot be honoured without overrunning it, thus the call gives up rather than sleeps.

    GitLab signals a rate limit with status 403 or 429 and the unprefixed [ratelimit-*] headers.

    The clock comes in as [now] rather than being read here, so the policy can be exercised without
    a scheduler.

    {v
      headers:[ ("retry-after", "5") ] ~status:429 ~max_wait:20.0  ->  `Wait 5.0
      headers:[ ("retry-after", "3600") ] ~status:429 ~max_wait:20.0  ->  `Fail 3600.0
    v} *)
val rate_limit_decision :
  headers:(string * string) list ->
  status:int ->
  now:float ->
  max_wait:float ->
  [ `Fail of float | `Wait of float | `No_wait ]

(** Whether a failed call to the forge is a transport fault worth trying again. [`Missing_response]
    is the answer the client has no binding for: the request reached the forge and the status it
    answered with is not one the API declares. A rate limit and a timeout have their own answers at
    the call sites and are not retried here. A 4xx among them is a verdict on the work, not a fault,
    and trying it again cannot change it; a 5xx is the forge failing while it answers. *)
val retryable_missing_response :
  ('a, [> `Missing_response of string Openapi.Response.t ]) result -> bool

(** The retrying call every request to the forge goes through: it tries again while the forge still
    answers with a fault or a 5xx, backs off between tries, and waits out a rate limit within the
    budget the caller's timeout gives it. *)
val call :
  ?tries:int ->
  Openapic_abb.t ->
  'a Openapi.Request.t ->
  ('a Openapi.Response.t, [> Openapic_abb.call_err ]) result Abb.Future.t

(** Whether a merge request can merge, from the [detailed_merge_status] and [has_conflicts] of the
    GitLab merge request API. Only a conflict makes it unmergeable. Approvals, discussions, draft
    state and pipelines do not. [None] while GitLab still computes the merge, or when it does not
    report [has_conflicts].

    GitLab reports in [detailed_merge_status] the first check that fails, and it runs the conflict
    check after the policy checks. A merge request that is not approved thus reports [not_approved]
    whether or not it conflicts. [detailed_merge_status] only tells whether the merge is computed,
    and [has_conflicts] gives the answer.

    {v
      ~detailed_merge_status:(Some "not_approved") ~has_conflicts:(Some false)  ->  Some true
      ~detailed_merge_status:(Some "not_approved") ~has_conflicts:(Some true)   ->  Some false
      ~detailed_merge_status:(Some "checking")     ~has_conflicts:(Some false)  ->  None
    v} *)
val mergeable_of_status :
  detailed_merge_status:string option -> has_conflicts:bool option -> bool option
