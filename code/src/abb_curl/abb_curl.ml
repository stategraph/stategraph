let () = Curl.global_init Curl.CURLINIT_GLOBALALL
let src = Logs.Src.create "abb_curl"

module Logs = (val Logs.src_log src : Logs.LOG)
module Int_map = CCMap.Make (CCInt)

external unsafe_int_of_file_descr : Unix.file_descr -> int = "%identity"

module Method = struct
  type body = string

  type t =
    [ `GET
    | `PUT of body option
    | `POST of body option
    | `DELETE of body option
    | `PATCH of body option
    | `Custom of string * body option
    ]
end

module Status = struct
  type t =
    [ `Continue
    | `Switching_protocols
    | `Processing_webdav_rfc_2518
    | `Checkpoint
    | `Ok
    | `Created
    | `Accepted
    | `Non_authoritative_information_since_http_1_1
    | `No_content
    | `Reset_content
    | `Partial_content
    | `Multi_status_webdav_rfc_4918
    | `Already_reported_webdav_rfc_5842
    | `Im_used_rfc_3229
    | `Multiple_choices
    | `Moved_permanently
    | `Found
    | `See_other
    | `Not_modified
    | `Use_proxy_since_http_1_1
    | `Switch_proxy
    | `Temporary_redirect_since_http_1_1
    | `Permanent_redirect
    | `Bad_request
    | `Unauthorized
    | `Payment_required
    | `Forbidden
    | `Not_found
    | `Method_not_allowed
    | `Not_acceptable
    | `Proxy_authentication_required
    | `Request_timeout
    | `Conflict
    | `Gone
    | `Length_required
    | `Precondition_failed
    | `Request_entity_too_large
    | `Request_uri_too_long
    | `Unsupported_media_type
    | `Requested_range_not_satisfiable
    | `Expectation_failed
    | `Im_a_teapot_rfc_2324
    | `Enhance_your_calm
    | `Unprocessable_entity_webdav_rfc_4918
    | `Locked_webdav_rfc_4918
    | `Failed_dependency_webdav_rfc_4918
    | `Upgrade_required_rfc_2817
    | `Precondition_required
    | `Too_many_requests
    | `Request_header_fields_too_large
    | `No_response
    | `Retry_with
    | `Blocked_by_windows_parental_controls
    | `Wrong_exchange_server
    | `Client_closed_request
    | `Internal_server_error
    | `Not_implemented
    | `Bad_gateway
    | `Service_unavailable
    | `Gateway_timeout
    | `Http_version_not_supported
    | `Variant_also_negotiates_rfc_2295
    | `Insufficient_storage_webdav_rfc_4918
    | `Loop_detected_webdav_rfc_5842
    | `Bandwidth_limit_exceeded_apache_bw_limited_extension
    | `Not_extended_rfc_2774
    | `Network_authentication_required
    | `Network_read_timeout_error
    | `Network_connect_timeout_error
    | `Unknown of int
    ]

  let of_int = function
    | 100 -> `Continue
    | 101 -> `Switching_protocols
    | 102 -> `Processing_webdav_rfc_2518
    | 103 -> `Checkpoint
    | 200 -> `Ok
    | 201 -> `Created
    | 202 -> `Accepted
    | 203 -> `Non_authoritative_information_since_http_1_1
    | 204 -> `No_content
    | 205 -> `Reset_content
    | 206 -> `Partial_content
    | 207 -> `Multi_status_webdav_rfc_4918
    | 208 -> `Already_reported_webdav_rfc_5842
    | 226 -> `Im_used_rfc_3229
    | 300 -> `Multiple_choices
    | 301 -> `Moved_permanently
    | 302 -> `Found
    | 303 -> `See_other
    | 304 -> `Not_modified
    | 305 -> `Use_proxy_since_http_1_1
    | 306 -> `Switch_proxy
    | 307 -> `Temporary_redirect_since_http_1_1
    | 308 -> `Permanent_redirect
    | 400 -> `Bad_request
    | 401 -> `Unauthorized
    | 402 -> `Payment_required
    | 403 -> `Forbidden
    | 404 -> `Not_found
    | 405 -> `Method_not_allowed
    | 406 -> `Not_acceptable
    | 407 -> `Proxy_authentication_required
    | 408 -> `Request_timeout
    | 409 -> `Conflict
    | 410 -> `Gone
    | 411 -> `Length_required
    | 412 -> `Precondition_failed
    | 413 -> `Request_entity_too_large
    | 414 -> `Request_uri_too_long
    | 415 -> `Unsupported_media_type
    | 416 -> `Requested_range_not_satisfiable
    | 417 -> `Expectation_failed
    | 418 -> `Im_a_teapot_rfc_2324
    | 420 -> `Enhance_your_calm
    | 422 -> `Unprocessable_entity_webdav_rfc_4918
    | 423 -> `Locked_webdav_rfc_4918
    | 424 -> `Failed_dependency_webdav_rfc_4918
    | 426 -> `Upgrade_required_rfc_2817
    | 428 -> `Precondition_required
    | 429 -> `Too_many_requests
    | 431 -> `Request_header_fields_too_large
    | 444 -> `No_response
    | 449 -> `Retry_with
    | 450 -> `Blocked_by_windows_parental_controls
    | 451 -> `Wrong_exchange_server
    | 499 -> `Client_closed_request
    | 500 -> `Internal_server_error
    | 501 -> `Not_implemented
    | 502 -> `Bad_gateway
    | 503 -> `Service_unavailable
    | 504 -> `Gateway_timeout
    | 505 -> `Http_version_not_supported
    | 506 -> `Variant_also_negotiates_rfc_2295
    | 507 -> `Insufficient_storage_webdav_rfc_4918
    | 508 -> `Loop_detected_webdav_rfc_5842
    | 509 -> `Bandwidth_limit_exceeded_apache_bw_limited_extension
    | 510 -> `Not_extended_rfc_2774
    | 511 -> `Network_authentication_required
    | 598 -> `Network_read_timeout_error
    | 599 -> `Network_connect_timeout_error
    | code -> `Unknown code

  let to_int = function
    | `Continue -> 100
    | `Switching_protocols -> 101
    | `Processing_webdav_rfc_2518 -> 102
    | `Checkpoint -> 103
    | `Ok -> 200
    | `Created -> 201
    | `Accepted -> 202
    | `Non_authoritative_information_since_http_1_1 -> 203
    | `No_content -> 204
    | `Reset_content -> 205
    | `Partial_content -> 206
    | `Multi_status_webdav_rfc_4918 -> 207
    | `Already_reported_webdav_rfc_5842 -> 208
    | `Im_used_rfc_3229 -> 226
    | `Multiple_choices -> 300
    | `Moved_permanently -> 301
    | `Found -> 302
    | `See_other -> 303
    | `Not_modified -> 304
    | `Use_proxy_since_http_1_1 -> 305
    | `Switch_proxy -> 306
    | `Temporary_redirect_since_http_1_1 -> 307
    | `Permanent_redirect -> 308
    | `Bad_request -> 400
    | `Unauthorized -> 401
    | `Payment_required -> 402
    | `Forbidden -> 403
    | `Not_found -> 404
    | `Method_not_allowed -> 405
    | `Not_acceptable -> 406
    | `Proxy_authentication_required -> 407
    | `Request_timeout -> 408
    | `Conflict -> 409
    | `Gone -> 410
    | `Length_required -> 411
    | `Precondition_failed -> 412
    | `Request_entity_too_large -> 413
    | `Request_uri_too_long -> 414
    | `Unsupported_media_type -> 415
    | `Requested_range_not_satisfiable -> 416
    | `Expectation_failed -> 417
    | `Im_a_teapot_rfc_2324 -> 418
    | `Enhance_your_calm -> 420
    | `Unprocessable_entity_webdav_rfc_4918 -> 422
    | `Locked_webdav_rfc_4918 -> 423
    | `Failed_dependency_webdav_rfc_4918 -> 424
    | `Upgrade_required_rfc_2817 -> 426
    | `Precondition_required -> 428
    | `Too_many_requests -> 429
    | `Request_header_fields_too_large -> 431
    | `No_response -> 444
    | `Retry_with -> 449
    | `Blocked_by_windows_parental_controls -> 450
    | `Wrong_exchange_server -> 451
    | `Client_closed_request -> 499
    | `Internal_server_error -> 500
    | `Not_implemented -> 501
    | `Bad_gateway -> 502
    | `Service_unavailable -> 503
    | `Gateway_timeout -> 504
    | `Http_version_not_supported -> 505
    | `Variant_also_negotiates_rfc_2295 -> 506
    | `Insufficient_storage_webdav_rfc_4918 -> 507
    | `Loop_detected_webdav_rfc_5842 -> 508
    | `Bandwidth_limit_exceeded_apache_bw_limited_extension -> 509
    | `Not_extended_rfc_2774 -> 510
    | `Network_authentication_required -> 511
    | `Network_read_timeout_error -> 598
    | `Network_connect_timeout_error -> 599
    | `Unknown code -> code

  let is_success t =
    let code = to_int t in
    200 <= code && code < 300

  let to_string = function
    | `Continue -> "Continue"
    | `Switching_protocols -> "Switching protocols"
    | `Processing_webdav_rfc_2518 -> "Processing webdav rfc 2518"
    | `Checkpoint -> "Checkpoint"
    | `Ok -> "Ok"
    | `Created -> "Created"
    | `Accepted -> "Accepted"
    | `Non_authoritative_information_since_http_1_1 ->
        "Non-authoritative information since_http/1.1"
    | `No_content -> "No content"
    | `Reset_content -> "Reset content"
    | `Partial_content -> "Partial content"
    | `Multi_status_webdav_rfc_4918 -> "Multi status webdav rfc 4918"
    | `Already_reported_webdav_rfc_5842 -> "Already reported webdav rfc 5842"
    | `Im_used_rfc_3229 -> "I'm used rfc 3229"
    | `Multiple_choices -> "Multiple choices"
    | `Moved_permanently -> "Moved permanently"
    | `Found -> "Found"
    | `See_other -> "See other"
    | `Not_modified -> "Not modified"
    | `Use_proxy_since_http_1_1 -> "Use proxy since http/1.1"
    | `Switch_proxy -> "Switch proxy"
    | `Temporary_redirect_since_http_1_1 -> "Temporary redirect since http/1.1"
    | `Permanent_redirect -> "Permanent redirect"
    | `Bad_request -> "Bad request"
    | `Unauthorized -> "Unauthorized"
    | `Payment_required -> "Payment required"
    | `Forbidden -> "Forbidden"
    | `Not_found -> "Not found"
    | `Method_not_allowed -> "Method not allowed"
    | `Not_acceptable -> "Not acceptable"
    | `Proxy_authentication_required -> "Proxy authentication required"
    | `Request_timeout -> "Request timeout"
    | `Conflict -> "Conflict"
    | `Gone -> "Gone"
    | `Length_required -> "Length required"
    | `Precondition_failed -> "Precondition failed"
    | `Request_entity_too_large -> "Request entity too large"
    | `Request_uri_too_long -> "Request uri too long"
    | `Unsupported_media_type -> "Unsupported media type"
    | `Requested_range_not_satisfiable -> "Requested range not satisfiable"
    | `Expectation_failed -> "Expectation failed"
    | `Im_a_teapot_rfc_2324 -> "I'm a teapot rfc 2324"
    | `Enhance_your_calm -> "Enhance your calm"
    | `Unprocessable_entity_webdav_rfc_4918 -> "Unprocessable entity webdav rfc 4918"
    | `Locked_webdav_rfc_4918 -> "Locked webdav rfc 4918"
    | `Failed_dependency_webdav_rfc_4918 -> "Failed dependency webdav rfc 4918"
    | `Upgrade_required_rfc_2817 -> "Upgrade required rfc 2817"
    | `Precondition_required -> "Precondition required"
    | `Too_many_requests -> "Too many requests"
    | `Request_header_fields_too_large -> "Request header fields too large"
    | `No_response -> "No response"
    | `Retry_with -> "Retry with"
    | `Blocked_by_windows_parental_controls -> "Blocked by windows parental controls"
    | `Wrong_exchange_server -> "Wrong exchange server"
    | `Client_closed_request -> "Client closed request"
    | `Internal_server_error -> "Internal server error"
    | `Not_implemented -> "Not implemented"
    | `Bad_gateway -> "Bad gateway"
    | `Service_unavailable -> "Service unavailable"
    | `Gateway_timeout -> "Gateway timeout"
    | `Http_version_not_supported -> "Http version not supported"
    | `Variant_also_negotiates_rfc_2295 -> "Variant also negotiates rfc 2295"
    | `Insufficient_storage_webdav_rfc_4918 -> "Insufficient storage webdav rfc 4918"
    | `Loop_detected_webdav_rfc_5842 -> "Loop detected webdav rfc 5842"
    | `Bandwidth_limit_exceeded_apache_bw_limited_extension ->
        "Bandwidth limit exceeded apache bw limited extension"
    | `Not_extended_rfc_2774 -> "Not extended rfc 2774"
    | `Network_authentication_required -> "Network authentication required"
    | `Network_read_timeout_error -> "Network read timeout error"
    | `Network_connect_timeout_error -> "Network connect timeout error"
    | `Unknown code -> CCInt.to_string code
end

module Headers = struct
  module M = Sln_map.String

  type t = string M.t

  let empty = M.empty
  let add k v t = M.add (CCString.lowercase_ascii k) v t
  let get k t = M.get (CCString.lowercase_ascii k) t

  let add_if_not_present k v t =
    match get k t with
    | Some _ -> t
    | None -> add k v t

  let rem k t = M.remove (CCString.lowercase_ascii k) t
  let to_list = M.to_list
  let of_list ls = M.of_list (CCList.map (fun (k, v) -> (CCString.lowercase_ascii k, v)) ls)
end

module Response = struct
  type t = {
    status : Status.t;
    headers : Headers.t;
  }

  let status t = t.status
  let headers t = t.headers
end

module Options = struct
  type opt =
    | Follow_location
    | Http_version of [ `Http2 | `Http1_1 ]
    | Curlopts of Curl.curlOption list

  type t = opt list

  let default = [ Follow_location ]

  let with_opt opt t =
    opt
    :: CCList.remove
         ~eq:(fun v1 v2 ->
           match (v1, v2) with
           | Http_version _, Http_version _ -> true
           | v1, v2 -> v1 = v2)
         ~key:opt
         t

  let without_opt opt = CCList.filter (( <> ) opt)
end

module Id = struct
  module Gen = struct
    type t = int

    let make () = 0
    let next t = (CCInt.to_string t, t + 1)
  end

  type t = string
end

module Make (Abb : Abb_intf.S with type Native.t = Unix.file_descr) = struct
  module Service_local = Abb_service_local.Make (Abb)
  module Fc = Abb_future_combinators.Make (Abb.Future)
  module Method = Method
  module Status = Status
  module Headers = Headers
  module Response = Response
  module Options = Options

  type request_err =
    [ `Closed
    | `Cancelled
    | `Curl_err of string
    ]
  [@@deriving show, eq]

  module Connector = struct
    module Id_map = CCMap.Make (CCString)

    module Request = struct
      type t = {
        options : Options.t;
        headers : Headers.t;
        body_reader : string -> unit Abb.Future.t;
        meth_ : Method.t;
        uri : Uri.t;
        id : Id.t;
      }
    end

    module In_event = struct
      type t =
        | Request of Request.t
        | Cancel of Id.t
        | Shutdown
    end

    module Out_event = struct
      type t =
        | Ret of (Id.t * (Response.t, request_err) result)
        | Body of (Id.t * string)
    end

    let trigger_bytes = Bytes.of_string "0"

    let trigger_eventfd eventfd =
      try ignore (UnixLabels.write eventfd ~buf:trigger_bytes ~pos:0 ~len:1)
      with Unix.Unix_error (Unix.EAGAIN, _, _) | Unix.Unix_error (Unix.EWOULDBLOCK, _, _) ->
        Logs.debug (fun m -> m "TRIGGER_EVENTFD_FULL : pipe already signaled, skipping")

    let consume_eventfd eventfd =
      let buf = Bytes.create 4 in
      try ignore (UnixLabels.read eventfd ~buf ~pos:0 ~len:(Bytes.length buf))
      with Unix.Unix_error (Unix.EAGAIN, _, _) | Unix.Unix_error (Unix.EWOULDBLOCK, _, _) -> ()

    module Loop = struct
      type t = {
        loop : Luv.Loop.t;
        timer : Luv.Timer.t;
        trigger_eventfd : Unix.file_descr;
        wait_eventfd : Unix.file_descr;
        in_event : In_event.t Queue.t;
        out_event : Out_event.t Queue.t;
        mutex : Mutex.t;
        mt : Curl.Multi.mt;
        curl_opts : Curl.curlOption list;
        (* Descriptors we could not arm a poll on, and the idle handle that
           drains them.  [socket_function] runs inside libcurl and must not call
           back into it, so the recovery is deferred to the next loop turn. *)
        fail_idle : Luv.Idle.t;
        mutable failed_fds : Unix.file_descr list;
        mutable polls : Luv.Poll.t Int_map.t;
        mutable requests : Request.t Id_map.t;
        mutable responses : Response.t Id_map.t;
        mutable handles : Curl.t Id_map.t;
        mutable shutdown : bool;
      }

      let trigger_out_events t =
        Mutex.protect t.mutex (fun () ->
            if Queue.length t.out_event > 0 then trigger_eventfd t.trigger_eventfd)

      let rec process_finished t =
        match Curl.Multi.remove_finished t.mt with
        | Some (handle, exit_code) when exit_code = Curl.CURLE_OK -> (
            let id =
              match Curl.getinfo handle Curl.CURLINFO_PRIVATE with
              | Curl.CURLINFO_String id -> id
              | Curl.CURLINFO_Long _ -> assert false
              | Curl.CURLINFO_Double _ -> assert false
              | Curl.CURLINFO_StringList _ -> assert false
              | Curl.CURLINFO_StringListList _ -> assert false
              | Curl.CURLINFO_Socket _ -> assert false
              | Curl.CURLINFO_Version _ -> assert false
            in
            let status =
              match Curl.getinfo handle Curl.CURLINFO_RESPONSE_CODE with
              | Curl.CURLINFO_Long status -> Status.of_int status
              | Curl.CURLINFO_String _ -> assert false
              | Curl.CURLINFO_Double _ -> assert false
              | Curl.CURLINFO_StringList _ -> assert false
              | Curl.CURLINFO_StringListList _ -> assert false
              | Curl.CURLINFO_Socket _ -> assert false
              | Curl.CURLINFO_Version _ -> assert false
            in
            Curl.cleanup handle;
            match Id_map.get id t.responses with
            | Some resp ->
                t.responses <- Id_map.remove id t.responses;
                t.requests <- Id_map.remove id t.requests;
                t.handles <- Id_map.remove id t.handles;
                Mutex.protect t.mutex (fun () ->
                    Queue.add (Out_event.Ret (id, Ok { resp with Response.status })) t.out_event);
                process_finished t
            | None -> assert false)
        | Some (handle, exit_code) -> (
            let id =
              match Curl.getinfo handle Curl.CURLINFO_PRIVATE with
              | Curl.CURLINFO_String id -> id
              | Curl.CURLINFO_Long _ -> assert false
              | Curl.CURLINFO_Double _ -> assert false
              | Curl.CURLINFO_StringList _ -> assert false
              | Curl.CURLINFO_StringListList _ -> assert false
              | Curl.CURLINFO_Socket _ -> assert false
              | Curl.CURLINFO_Version _ -> assert false
            in
            Curl.cleanup handle;
            match Id_map.get id t.responses with
            | Some _resp ->
                t.responses <- Id_map.remove id t.responses;
                t.requests <- Id_map.remove id t.requests;
                t.handles <- Id_map.remove id t.handles;
                Mutex.protect t.mutex (fun () ->
                    Queue.add
                      (Out_event.Ret (id, Error (`Curl_err (Curl.strerror exit_code))))
                      t.out_event);
                process_finished t
            | None -> assert false)
        | None -> ()

      (* Drive curl so it observes that [fd] is unusable and completes the
         transfer with an error.  Only ever called from [Loop.run] -- the poll's
         own error callback, or [drain_failed_fds] -- never from inside one of
         libcurl's callbacks. *)
      let fail_socket t fd =
        ignore (Curl.Multi.action t.mt fd Curl.Multi.EV_IN);
        process_finished t;
        trigger_out_events t

      (* Runs from [Loop.run], not from inside libcurl, so driving curl here is
         legal.  Stops itself once the backlog is empty. *)
      let drain_failed_fds t =
        ignore (Luv.Idle.stop t.fail_idle);
        let fds = t.failed_fds in
        t.failed_fds <- [];
        CCList.iter (fail_socket t) fds

      let socket_function t fd poll =
        let fd_int = unsafe_int_of_file_descr fd in
        let ensure_poll events =
          let poll_handle =
            match Int_map.get fd_int t.polls with
            | Some p ->
                ignore (Luv.Poll.stop p);
                Some p
            | None -> (
                (* [uv_poll_init] is fallible: curl may have closed this
                   descriptor already, or it may be one epoll refuses.  Report it
                   as a failed transfer rather than raising -- luv's default
                   handler for an exception escaping a callback prints it and
                   calls [exit 2], so this would end the whole process. *)
                match Luv.Poll.init ~loop:t.loop fd_int with
                | Ok p ->
                    t.polls <- Int_map.add fd_int p t.polls;
                    Some p
                | Error err ->
                    Logs.err (fun m ->
                        m "SOCKET_FUNCTION : fd=%d : POLL_INIT : %s" fd_int (Luv.Error.strerror err));
                    None)
          in
          match poll_handle with
          | None ->
              (* Hand the descriptor to the idle handle rather than driving curl
                 from here.  Two reasons it cannot be done inline: this runs
                 inside [curl_multi_socket_action], so calling [action] /
                 [remove_handle] / [easy_cleanup] would re-enter libcurl from one
                 of its own callbacks, and curl re-registering the same socket
                 would recurse straight back into us.  Nor can the transfer
                 simply be left alone: curl reports timeout [-1] once it is only
                 waiting on socket readiness, which STOPS [t.timer], so with no
                 poll armed and no timer there is nothing left to complete the
                 request and the caller waits forever. *)
              t.failed_fds <- fd :: t.failed_fds;
              ignore (Luv.Idle.start t.fail_idle (fun () -> drain_failed_fds t))
          | Some poll_handle ->
              ignore
                (Luv.Poll.start poll_handle events (fun result ->
                     match result with
                     | Ok events ->
                         let has_readable = List.mem `READABLE events in
                         let has_writable = List.mem `WRITABLE events in
                         if has_readable then ignore (Curl.Multi.action t.mt fd Curl.Multi.EV_IN);
                         if has_writable then ignore (Curl.Multi.action t.mt fd Curl.Multi.EV_OUT);
                         process_finished t;
                         trigger_out_events t
                     | Error _ -> fail_socket t fd))
        in
        match poll with
        | Curl.Multi.POLL_NONE -> ()
        | Curl.Multi.POLL_IN ->
            Logs.debug (fun m -> m "SOCKET_FUNCTION : fd=%d : POLL_IN" fd_int);
            ensure_poll [ `READABLE ]
        | Curl.Multi.POLL_OUT ->
            Logs.debug (fun m -> m "SOCKET_FUNCTION : fd=%d : POLL_OUT" fd_int);
            ensure_poll [ `WRITABLE ]
        | Curl.Multi.POLL_INOUT ->
            Logs.debug (fun m -> m "SOCKET_FUNCTION : fd=%d : POLL_INOUT" fd_int);
            ensure_poll [ `READABLE; `WRITABLE ]
        | Curl.Multi.POLL_REMOVE -> (
            Logs.debug (fun m -> m "SOCKET_FUNCTION : fd=%d : POLL_REMOVE" fd_int);
            match Int_map.get fd_int t.polls with
            | Some p ->
                ignore (Luv.Poll.stop p);
                Luv.Handle.close p CCFun.id;
                t.polls <- Int_map.remove fd_int t.polls
            | None -> ())

      let maybe_set_body_writer handle = function
        | Some body ->
            let pos = ref 0 in
            let length = CCString.length body in
            Curl.set_postfieldsize handle length;
            Curl.set_readfunction handle (fun n ->
                if !pos < length then (
                  let len = length - !pos in
                  let pos' = !pos in
                  pos := !pos + CCInt.min n len;
                  CCString.sub body pos' (CCInt.min n len))
                else "");
            (* The body lives entirely in memory, so let curl rewind it whenever
               it needs to resend the request: following a redirect,
               re-establishing a connection that was dropped mid-send, replaying
               after a proxy or TLS-inspecting middlebox interrupts the stream,
               etc.  Without a seek function curl cannot rewind the read callback
               and fails these resends with CURLE_SEND_FAIL_REWIND ("Send failed
               since rewinding of the data stream failed"). *)
            Curl.set_seekfunction handle (fun offset cmd ->
                let target =
                  match cmd with
                  | Curl.SEEK_SET -> Int64.to_int offset
                  | Curl.SEEK_CUR -> !pos + Int64.to_int offset
                  | Curl.SEEK_END -> length + Int64.to_int offset
                in
                if target >= 0 && target <= length then (
                  pos := target;
                  Curl.SEEKFUNC_OK)
                else Curl.SEEKFUNC_FAIL)
        | None -> ()

      let setup_request handle meth_ headers uri =
        let debug_enabled = ref false in
        Logs.debug (fun m ->
            debug_enabled := true;
            m "Verbose enabled");
        Curl.set_verbose handle !debug_enabled;
        Curl.set_url handle (Uri.to_string uri);
        (match meth_ with
        | `GET -> ()
        | `PUT body ->
            Curl.set_put handle true;
            maybe_set_body_writer handle body
        | `POST body ->
            Curl.set_post handle true;
            (* Use set_postfields for POST - set_readfunction alone doesn't work without set_postfieldsize *)
            Curl.set_postfields handle (CCOption.get_or ~default:"" body)
        | `DELETE body ->
            Curl.set_customrequest handle "DELETE";
            maybe_set_body_writer handle body
        | `PATCH body ->
            Curl.set_customrequest handle "PATCH";
            maybe_set_body_writer handle body
        | `Custom (meth_, body) ->
            Curl.set_customrequest handle meth_;
            maybe_set_body_writer handle body);
        let response_body = Buffer.create 100 in
        Curl.set_writefunction handle (fun s ->
            Buffer.add_string response_body s;
            CCString.length s);
        Curl.set_httpheader
          handle
          (CCList.map (fun (k, v) -> k ^ ": " ^ v) (Headers.to_list headers))

      let setup_response t handle id =
        Curl.set_headerfunction handle (fun s ->
            match CCString.Split.left ~by:":" s with
            | Some (k, v) -> (
                let k = CCString.trim k in
                let v = CCString.trim v in
                match Id_map.get id t.responses with
                | Some ({ Response.headers; _ } as resp) ->
                    t.responses <-
                      Id_map.add
                        id
                        { resp with Response.headers = Headers.add k v headers }
                        t.responses;
                    CCString.length s
                | None ->
                    t.responses <-
                      Id_map.add
                        id
                        {
                          Response.status = `Internal_server_error;
                          headers = Headers.of_list [ (k, v) ];
                        }
                        t.responses;
                    CCString.length s)
            | None -> CCString.length s);
        Curl.set_writefunction handle (fun s ->
            Mutex.protect t.mutex (fun () -> Queue.add (Out_event.Body (id, s)) t.out_event);
            CCString.length s)

      let process_request
          t
          ({ Request.options; headers; body_reader = _; meth_; uri; id; _ } as request) =
        Logs.debug (fun m -> m "process_request : id=%s : uri=%a" id Uri.pp uri);
        let handle = Curl.init () in
        t.requests <- Id_map.add id request t.requests;
        t.responses <-
          Id_map.add
            id
            { Response.status = `Internal_server_error; headers = Headers.empty }
            t.responses;
        t.handles <- Id_map.add id handle t.handles;
        CCList.iter (fun opt -> Curl.setopt handle opt) t.curl_opts;
        CCList.iter
          (function
            | Options.Follow_location -> Curl.set_followlocation handle true
            | Options.Http_version `Http1_1 -> Curl.set_httpversion handle Curl.HTTP_VERSION_1_1
            | Options.Http_version `Http2 -> Curl.set_httpversion handle Curl.HTTP_VERSION_2
            | Options.Curlopts opts -> CCList.iter (fun opt -> Curl.setopt handle opt) opts)
          options;
        (* Use our id to track this *)
        Curl.setopt handle (Curl.CURLOPT_PRIVATE id);
        setup_request handle meth_ headers uri;
        setup_response t handle id;
        Curl.Multi.add t.mt handle

      let process_cancel t id =
        match Id_map.get id t.handles with
        | Some handle ->
            Curl.Multi.remove t.mt handle;
            Curl.cleanup handle;
            t.requests <- Id_map.remove id t.requests;
            t.responses <- Id_map.remove id t.responses;
            t.handles <- Id_map.remove id t.handles
        | None -> ()

      let process_shutdown t =
        Id_map.iter (fun id _ -> process_cancel t id) t.handles;
        Curl.Multi.cleanup t.mt;
        t.shutdown <- true

      let rec process_in_events t =
        Logs.debug (fun m -> m "process_in_events");
        let event = Mutex.protect t.mutex (fun () -> Queue.take_opt t.in_event) in
        match event with
        | Some (In_event.Request request) ->
            process_request t request;
            process_in_events t
        | Some (In_event.Cancel id) ->
            process_cancel t id;
            process_in_events t
        | Some In_event.Shutdown -> process_shutdown t
        | None -> ()

      let curlopts_of_env () =
        CCList.filter_map
          (fun (env, f) ->
            match Sys.getenv_opt env with
            | Some env -> f env
            | None -> None)
          [
            ( "CURL_SSL_OPTS",
              function
              | "n" -> Some (Curl.CURLOPT_SSL_OPTIONS [ Curl.CURLSSLOPT_NATIVE_CA ])
              | _ -> None );
            ("SSL_CERT_DIR", fun path -> Some (Curl.CURLOPT_CAPATH path));
            ("SSL_CERT_FILE", fun path -> Some (Curl.CURLOPT_CAINFO path));
          ]

      (* Body of the curl loop domain.  Named rather than inlined in
         [Domain.spawn] so the [Luv.Poll.init] result can be matched without the
         match colliding with the caller's [try ... with]. *)
      let run_loop_domain' t =
        (* If we cannot watch the wake pipe there is no loop to run.  Say so
           plainly rather than raising out of a [get_ok] and relying on the
           caller's [try ... with] to turn a bare [Invalid_argument] into a log
           line that does not name the cause. *)
        match Luv.Poll.init ~loop:t.loop (unsafe_int_of_file_descr t.wait_eventfd) with
        | Error err -> Logs.err (fun m -> m "LOOP : WAIT_POLL_INIT : %s" (Luv.Error.strerror err))
        | Ok wait_poll ->
            ignore
              (Luv.Poll.start wait_poll [ `READABLE ] (fun _result ->
                   consume_eventfd t.wait_eventfd;
                   process_in_events t;
                   if t.shutdown then (
                     ignore (Luv.Timer.stop t.timer);
                     Luv.Handle.close t.timer CCFun.id;
                     ignore (Luv.Idle.stop t.fail_idle);
                     Luv.Handle.close t.fail_idle CCFun.id;
                     t.failed_fds <- [];
                     ignore (Luv.Poll.stop wait_poll);
                     Luv.Handle.close wait_poll CCFun.id;
                     Int_map.iter
                       (fun _ p ->
                         ignore (Luv.Poll.stop p);
                         Luv.Handle.close p CCFun.id)
                       t.polls;
                     t.polls <- Int_map.empty)
                   else (
                     process_finished t;
                     trigger_out_events t)));
            ignore (Curl.Multi.action_timeout t.mt);
            ignore (Luv.Loop.run ~loop:t.loop ());
            ignore (Luv.Loop.close t.loop)

      let run_loop_domain t =
        try run_loop_domain' t
        with exn ->
          Logs.err (fun m -> m "--- %s %s ---" (Printexc.to_string exn) (Printexc.get_backtrace ()))

      let start () =
        let wait_loop_eventfd, trigger_server_eventfd = Unix.pipe ~cloexec:true () in
        let wait_server_eventfd, trigger_loop_eventfd = Unix.pipe ~cloexec:true () in
        UnixLabels.set_nonblock wait_loop_eventfd;
        UnixLabels.set_nonblock trigger_loop_eventfd;
        UnixLabels.set_nonblock wait_server_eventfd;
        UnixLabels.set_nonblock trigger_server_eventfd;
        let loop = Luv.Loop.init () |> Result.get_ok in
        let timer = Luv.Timer.init ~loop () |> Result.get_ok in
        let fail_idle = Luv.Idle.init ~loop () |> Result.get_ok in
        let t =
          {
            loop;
            timer;
            fail_idle;
            failed_fds = [];
            trigger_eventfd = trigger_loop_eventfd;
            wait_eventfd = wait_loop_eventfd;
            in_event = Queue.create ();
            out_event = Queue.create ();
            mutex = Mutex.create ();
            mt = Curl.Multi.create ();
            curl_opts = curlopts_of_env ();
            polls = Int_map.empty;
            requests = Id_map.empty;
            responses = Id_map.empty;
            handles = Id_map.empty;
            shutdown = false;
          }
        in
        Curl.Multi.set_socket_function t.mt (socket_function t);
        Curl.Multi.set_timer_function t.mt (function
          | -1 ->
              Logs.debug (fun m -> m "TIMER : DISABLE");
              ignore (Luv.Timer.stop t.timer)
          | timeout_ms ->
              Logs.debug (fun m -> m "TIMER : SET : %d" timeout_ms);
              ignore (Luv.Timer.stop t.timer);
              ignore
                (Luv.Timer.start t.timer timeout_ms (fun () ->
                     Curl.Multi.action_timeout t.mt;
                     process_finished t;
                     trigger_out_events t)));
        ignore (Domain.spawn (fun () -> run_loop_domain t));
        (wait_server_eventfd, trigger_server_eventfd, t.mutex, t.in_event, t.out_event)
    end

    module Server = struct
      type response_envelope = (Request.t, (Response.t, request_err) result) Service_local.Request.t

      module Msg = struct
        type t =
          | Request of response_envelope
          | Cancel of Id.t
          | Iterate
      end

      (* [wait_eventfd] and [iterate_fut] are kept on the record to anchor the resources
         for their lifetime; the rest of the code reads through other fields. *)
      type t = {
        wait_eventfd : Unix.file_descr;
        trigger_eventfd : Unix.file_descr;
        mutex : Mutex.t;
        in_event : In_event.t Queue.t;
        out_event : Out_event.t Queue.t;
        iterate_fut : unit Abb.Future.t;
        body_readers : (string -> unit Abb.Future.t) Id_map.t;
        responses : response_envelope Id_map.t;
      }
      [@@warning "-69"]

      (* Send the curl result back to the caller via the reply chan
         embedded in the request envelope.  The reply chan may be closed
         already (caller aborted) -- the send returns [`Chan_closed] and
         we drop the result.  Matches [Service_local.respond]'s
         behaviour. *)
      let send_reply (req : response_envelope) result =
        let open Abb.Future.Infix_monad in
        Abb.Chan.send (Service_local.Request.reply_chan req) (`Det result)
        >>= function
        | Ok () | Error `Chan_closed -> Abb.Future.return ()

      let rec process_events t =
        let event = Mutex.protect t.mutex (fun () -> Queue.take_opt t.out_event) in
        match event with
        | Some (Out_event.Ret (id, ret)) -> (
            let open Abb.Future.Infix_monad in
            match Id_map.get id t.responses with
            | Some req ->
                let request = Service_local.Request.payload req in
                Logs.debug (fun m -> m "RET : id=%s : uri=%a" id Uri.pp request.Request.uri);
                send_reply req ret
                >>= fun () ->
                process_events
                  {
                    t with
                    body_readers = Id_map.remove id t.body_readers;
                    responses = Id_map.remove id t.responses;
                  }
            | None -> process_events t)
        | Some (Out_event.Body (id, string)) -> (
            let open Abb.Future.Infix_monad in
            match Id_map.get id t.body_readers with
            | Some body_reader -> body_reader string >>= fun () -> process_events t
            | None -> process_events t)
        | None -> Abb.Future.return t

      let handle_msg t = function
        | Msg.Request req ->
            let request = Service_local.Request.payload req in
            let id = request.Request.id in
            Logs.debug (fun m -> m "MSG : REQUEST : id=%s : uri=%a" id Uri.pp request.Request.uri);
            let body_reader = request.Request.body_reader in
            let t =
              {
                t with
                body_readers = Id_map.add id body_reader t.body_readers;
                responses = Id_map.add id req t.responses;
              }
            in
            Mutex.protect t.mutex (fun () -> Queue.add (In_event.Request request) t.in_event);
            trigger_eventfd t.trigger_eventfd;
            Abb.Future.return t
        | Msg.Cancel id ->
            let open Abb.Future.Infix_monad in
            Logs.debug (fun m -> m "MSG : CANCEL : id=%s" id);
            Mutex.protect t.mutex (fun () -> Queue.add (In_event.Cancel id) t.in_event);
            trigger_eventfd t.trigger_eventfd;
            (match Id_map.get id t.responses with
              | Some req -> send_reply req (Error `Cancelled)
              | None -> Fc.unit)
            >>= fun () ->
            Abb.Future.return
              {
                t with
                body_readers = Id_map.remove id t.body_readers;
                responses = Id_map.remove id t.responses;
              }
        | Msg.Iterate -> process_events t

      let rec loop t chan =
        let open Abb.Future.Infix_monad in
        Abb.Chan.recv chan
        >>= function
        | Ok msg -> handle_msg t msg >>= fun t -> loop t chan
        | Error `Chan_closed ->
            Mutex.protect t.mutex (fun () -> Queue.add In_event.Shutdown t.in_event);
            trigger_eventfd t.trigger_eventfd;
            Abb.Future.return ()

      let rec iterate_loop eventfd buf chan =
        let open Abb.Future.Infix_monad in
        Logs.debug (fun m -> m "ITERATE_LOOP");
        Abb.File.read eventfd ~buf ~pos:0 ~len:(Bytes.length buf)
        >>= fun _ ->
        Abb.Chan.send chan Msg.Iterate
        >>= function
        | Ok () -> iterate_loop eventfd buf chan
        | Error `Chan_closed -> Abb.Future.return ()

      let start chan =
        let open Abb.Future.Infix_monad in
        let wait_eventfd, trigger_eventfd, mutex, in_event, out_event = Loop.start () in
        Abb.Future.fork
          (let buf = Bytes.create 4 in
           let eventfd = Abb.File.of_native wait_eventfd in
           iterate_loop eventfd buf chan)
        >>= fun iterate_fut ->
        let t =
          {
            wait_eventfd;
            trigger_eventfd;
            mutex;
            in_event;
            out_event;
            iterate_fut;
            body_readers = Id_map.empty;
            responses = Id_map.empty;
          }
        in
        loop t chan
    end

    type t = {
      w : Server.Msg.t Service_local.t;
      mutable id_gen : Id.Gen.t;
    }

    let create () =
      let open Abb.Future.Infix_monad in
      Service_local.create Server.start
      >>= fun w ->
      Logs.debug (fun m -> m "STARTED");
      Abb.Future.return { w; id_gen = Id.Gen.make () }

    let destroy t =
      Abb.Chan.close t.w;
      Abb.Future.return ()

    let send_to_chan chan msg =
      let open Abb.Future.Infix_monad in
      Abb.Chan.send chan msg
      >>| function
      | Ok () -> Ok ()
      | Error `Chan_closed -> Error `Closed

    let request t options headers body_reader meth_ uri =
      let id, id_gen = Id.Gen.next t.id_gen in
      t.id_gen <- id_gen;
      let curl_req = { Request.options; headers; body_reader; meth_; uri; id } in
      (* [Service_local.call] handles reply-chan allocation, send,
         recv, and re-materialization on the caller's State.t.  The
         returned future carries the response result; if the service
         is closed the call yields [Error `Chan_closed] which we
         surface as [Error `Closed] to match the existing API. *)
      let response_fut =
        let open Abb.Future.Infix_monad in
        Service_local.call t.w (fun req -> Server.Msg.Request req) curl_req
        >>= function
        | Ok res -> Abb.Future.return res
        | Error `Chan_closed -> Fc.return_err `Closed
      in
      Fc.return_ok (id, response_fut)

    let cancel t id = send_to_chan t.w (Server.Msg.Cancel id)
  end

  let default_connector = Connector.create ()

  let call ?connector ?(options = Options.default) ?(headers = Headers.empty) meth_ uri =
    let open Abb.Future.Infix_monad in
    Fc.protect_finally
      ~setup:(fun () ->
        let open Abb.Future.Infix_monad in
        let connector =
          match connector with
          | None -> default_connector
          | Some connector -> Abb.Future.return connector
        in
        connector
        >>= fun connector ->
        let open Fc.Infix_result_monad in
        let buf = Buffer.create 10 in
        let body s =
          Buffer.add_string buf s;
          Abb.Future.return ()
        in
        Connector.request connector options headers body meth_ uri
        >>| fun (id, p) -> (connector, id, buf, p))
      (fun res ->
        let open Fc.Infix_result_monad in
        Abb.Future.return res >>= fun (_, _, buf, p) -> p >>| fun resp -> (resp, Buffer.contents buf))
      ~finally:(fun res ->
        Fc.ignore
          (let open Fc.Infix_result_monad in
           Abb.Future.return res
           >>= fun (connector, id, _, _) ->
           (* We don't know if we are really destroying a connector or not, so
              however we got to this [finally], then cancel the request.  If we
              are in the [finally] because the request ended successfully, then
              this is a noop. *)
           Connector.cancel connector id))
    >>= function
    | Ok res -> Fc.return_ok res
    | Error (#request_err as err) -> Fc.return_err err

  let get ?connector ?options ?headers uri = call ?connector ?options ?headers `GET uri
  let put ?connector ?options ?headers ?body uri = call ?connector ?options ?headers (`PUT body) uri

  let post ?connector ?options ?headers ?body uri =
    call ?connector ?options ?headers (`POST body) uri

  let delete ?connector ?options ?headers uri = call ?connector ?options ?headers (`DELETE None) uri
end
