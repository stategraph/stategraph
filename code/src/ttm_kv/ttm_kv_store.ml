type err = Ttm_client.create_err [@@deriving show]

type t = {
  client : Ttm_client.t;
  installation : string;
  vcs : string;
}

type key = string [@@deriving to_yojson]
type path = string
type data = Yojson.Safe.t [@@deriving to_yojson]
type cap = Terrat_user_caps.t [@@deriving to_yojson]

module Record = struct
  type 'a t = {
    committed : bool;
    created_at : string;
    data : 'a;
    idx : int;
    key : key;
    size : int;
    version : int;
    read_caps : cap list option;
    write_caps : cap list option;
  }
  [@@deriving to_yojson]

  let committed t = t.committed
  let created_at t = t.created_at
  let data t = t.data
  let idx t = t.idx
  let key t = t.key
  let size t = t.size
  let version t = t.version
  let read_caps t = t.read_caps
  let write_caps t = t.write_caps
end

type data_record = data Record.t [@@deriving to_yojson]

module C = struct
  type 'a t = ('a, err) result Abb.Future.t
end

let yojson_of_caps = [%to_yojson: Terrat_user_caps.t list]
let caps_of_yojson = [%of_yojson: Terrat_user_caps.t list]
let create ~vcs ~installation client = { client; installation; vcs }

let get ?select ?idx ?committed ~key t =
  let open Abbs_future_combinators.Infix_result_monad in
  Ttm_client.call
    t.client
    Terrat_api_kv.Get.(
      make
        (Parameters.make ~select ~idx ~committed ~key ~vcs:t.vcs ~installation_id:t.installation ()))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `Forbidden -> Error `Refresh_token_err
  | `Not_found -> Ok None
  | `OK
      {
        Terrat_api_components_kv_record.committed;
        created_at;
        data;
        idx;
        key;
        size;
        version;
        read_caps;
        write_caps;
      } ->
      Ok
        (Some
           {
             Record.committed;
             created_at;
             data;
             idx;
             key;
             size;
             version;
             read_caps = CCOption.map CCFun.(caps_of_yojson %> CCResult.get_or_failwith) read_caps;
             write_caps = CCOption.map CCFun.(caps_of_yojson %> CCResult.get_or_failwith) write_caps;
           })

let set ?read_caps ?write_caps ?idx ?committed ~key data t =
  let open Abbs_future_combinators.Infix_result_monad in
  let body =
    {
      Terrat_api_components_kv_set.committed;
      data;
      idx;
      read_caps = CCOption.map yojson_of_caps read_caps;
      write_caps = CCOption.map yojson_of_caps write_caps;
    }
  in
  Ttm_client.call
    t.client
    Terrat_api_kv.Set.(make ~body (Parameters.make ~installation_id:t.installation ~vcs:t.vcs ~key))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK
      {
        Terrat_api_components_kv_record.committed;
        created_at;
        data = _;
        idx;
        key;
        size;
        version;
        read_caps;
        write_caps;
      } ->
      (* Data returned from the server is empty, so we replace it with the data
         we just sent.  Gotta save those bytes. *)
      Ok
        {
          Record.committed;
          created_at;
          data;
          idx;
          key;
          size;
          version;
          read_caps = CCOption.map CCFun.(caps_of_yojson %> CCResult.get_or_failwith) read_caps;
          write_caps = CCOption.map CCFun.(caps_of_yojson %> CCResult.get_or_failwith) write_caps;
        }
  | `Forbidden -> Error `Refresh_token_err

let cas ?read_caps ?write_caps ?idx ?committed ?version ~key data t =
  let open Abbs_future_combinators.Infix_result_monad in
  let body =
    {
      Terrat_api_components_kv_cas.committed;
      data;
      idx;
      version;
      read_caps = CCOption.map yojson_of_caps read_caps;
      write_caps = CCOption.map yojson_of_caps write_caps;
    }
  in
  Ttm_client.call
    t.client
    Terrat_api_kv.Cas.(make ~body (Parameters.make ~installation_id:t.installation ~vcs:t.vcs ~key))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK
      {
        Terrat_api_components_kv_record.committed;
        created_at;
        data = _;
        idx;
        key;
        size;
        version;
        read_caps;
        write_caps;
      } ->
      (* Data returned from the server is empty, so we replace it with the data
         we just sent.  Gotta save those bytes. *)
      Ok
        (Some
           {
             Record.committed;
             created_at;
             data;
             idx;
             key;
             size;
             version;
             read_caps = CCOption.map CCFun.(caps_of_yojson %> CCResult.get_or_failwith) read_caps;
             write_caps = CCOption.map CCFun.(caps_of_yojson %> CCResult.get_or_failwith) write_caps;
           })
  | `Bad_request -> Ok None
  | `Forbidden -> Error `Refresh_token_err

let delete ?idx ?version ~key t =
  let open Abbs_future_combinators.Infix_result_monad in
  Ttm_client.call
    t.client
    Terrat_api_kv.Delete.(
      make (Parameters.make ~installation_id:t.installation ~vcs:t.vcs ~idx ~version ~key ()))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK { Terrat_api_components_kv_delete.result } -> Ok result
  | `Forbidden -> Error `Refresh_token_err

let count ?committed:_ ~key:_ _t = raise (Failure "nyi")
let size ?idx:_ ?committed:_ ~key:_ _t = raise (Failure "nyi")

let iter ?select ?idx ?inclusive ?prefix ?committed ?limit ~key t =
  let open Abbs_future_combinators.Infix_result_monad in
  Ttm_client.call
    t.client
    Terrat_api_kv.Iter.(
      make
        (Parameters.make
           ~select
           ~idx
           ~committed
           ~limit
           ~prefix
           ~inclusive
           ~key
           ~vcs:t.vcs
           ~installation_id:t.installation
           ()))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `Forbidden -> Error `Refresh_token_err
  | `OK { Terrat_api_components_kv_record_list.results } ->
      Ok
        (CCList.map
           (fun {
                  Terrat_api_components_kv_record.committed;
                  created_at;
                  data;
                  idx;
                  key;
                  size;
                  version;
                  read_caps;
                  write_caps;
                }
              ->
             {
               Record.committed;
               created_at;
               data;
               idx;
               key;
               size;
               version;
               read_caps = CCOption.map CCFun.(caps_of_yojson %> CCResult.get_or_failwith) read_caps;
               write_caps =
                 CCOption.map CCFun.(caps_of_yojson %> CCResult.get_or_failwith) write_caps;
             })
           results)

let commit ~keys t =
  let open Abbs_future_combinators.Infix_result_monad in
  let body =
    {
      Terrat_api_components_kv_commit.keys =
        CCList.map (fun (key, idx) -> { Terrat_api_components_kv_commit.Keys.Items.key; idx }) keys;
    }
  in
  Ttm_client.call
    t.client
    Terrat_api_kv.Commit.(make ~body (Parameters.make ~installation_id:t.installation ~vcs:t.vcs))
  >>? fun resp ->
  match Openapi.Response.value resp with
  | `OK { Terrat_api_components_kv_commit_result.keys } ->
      Ok
        (CCList.map
           (fun { Terrat_api_components_kv_commit_result.Keys.Items.key; idx } -> (key, idx))
           keys)
  | `Forbidden -> Error `Refresh_token_err
