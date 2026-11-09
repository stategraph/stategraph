(* The retry rule of the forge calls.  A [Missing_response] is the answer that did not come back,
   and the calls that read the checks or dispatch a run try it again; a rate limit, a timeout and a
   ref that the forge says is gone are verdicts and are not tried again. *)

module Api = Terrat_vcs_api_github
module Oth_abb = Oth_abb.Make (Abb)

let tags = [ "vcs_api_github" ]

let response body =
  Openapi.Response.make
    ~headers:[]
    ~request_uri:(Uri.of_string "https://api.github.com/repos/owner/repo")
    ~status:502
    body

let missing body = Error (`Missing_response (response body))

let check ~name ~expected ~actual () =
  Oth_abb.test ~name ~tags (fun () ->
      Oth.Assert.eq ~eq:Bool.equal ~pp:Format.pp_print_bool expected actual;
      Abb.Future.return ())

let tests =
  Oth_abb.parallel
    [
      check
        ~name:"a missing response is retried"
        ~expected:true
        ~actual:(Api.retryable_missing_response (missing "gateway"))
        ();
      check
        ~name:"a missing response that says the ref is gone is not retried"
        ~expected:false
        ~actual:
          (Api.retryable_missing_response
             (missing {|{"message":"No ref found for: refs/heads/gone"}|}))
        ();
      check
        ~name:"a timeout is not retried"
        ~expected:false
        ~actual:(Api.retryable_missing_response (Error `Timeout))
        ();
      check
        ~name:"a rate limit is not retried"
        ~expected:false
        ~actual:(Api.retryable_missing_response (Error `Rate_limit_err))
        ();
      check
        ~name:"a successful call is not retried"
        ~expected:false
        ~actual:(Api.retryable_missing_response (Ok ()))
        ();
      (* The production call sites compose the rule with [finite_tries], so the pair is what the
         test pins: a fault is tried again, and the answer that ends the retries is the last one. *)
      Oth_abb.test ~name:"a fault is tried again and the last answer is returned" ~tags (fun () ->
          let calls = ref 0 in
          let f () =
            incr calls;
            Abb.Future.return (if !calls < 3 then missing "gateway" else Ok "done")
          in
          let open Abb.Future.Infix_monad in
          Abbs_fc.retry
            ~f
            ~while_:(Abbs_fc.finite_tries 4 Api.retryable_missing_response)
            ~betwixt:(fun _ -> Abb.Future.return ())
          >>= fun r ->
          (match r with
          | Ok "done" -> ()
          | Ok _ -> Oth.Assert.false_ "the retry answered the wrong value"
          | Error _ -> Oth.Assert.false_ "the retry gave up on a fault");
          Oth.Assert.eq ~eq:Int.equal ~pp:Format.pp_print_int 3 !calls;
          Abb.Future.return ());
    ]

let () =
  Oth_abb.run
    ~file:__FILE__
    ~setup:(fun () -> Abbs_fc.return_ok ())
    ~teardown:(fun () -> Abb.Future.return ())
    (fun () -> tests)
