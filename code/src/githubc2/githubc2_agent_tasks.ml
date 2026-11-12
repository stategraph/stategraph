module Get_task_by_id = struct
  module Parameters = struct
    type t = { task_id : string } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "agents" / "tasks" /% Path.string

  module Responses = struct
    module OK = struct
      module All_of = struct
        module Primary = struct
          module Artifacts = struct
            module Items = struct
              module Primary = struct
                module Data = struct
                  module V0 = struct
                    module Primary = struct
                      type t = {
                        global_id : string option; [@default None]
                        id : int64;
                      }
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                  end

                  module V1 = struct
                    module Primary = struct
                      type t = {
                        base_ref : string;
                        head_ref : string;
                      }
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                  end

                  type t =
                    | V0 of V0.t
                    | V1 of V1.t
                  [@@deriving show, eq]

                  let of_yojson =
                    Json_schema.one_of
                      (let open CCResult in
                       [
                         (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                         (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                       ])

                  let to_yojson = function
                    | V0 v -> V0.to_yojson v
                    | V1 v -> V1.to_yojson v
                end

                module Provider = struct
                  let t_of_yojson = function
                    | `String "github" -> Ok `Github
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Github -> `String "github"

                  type t = ([ `Github ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Type = struct
                  let t_of_yojson = function
                    | `String "branch" -> Ok `Branch
                    | `String "pull" -> Ok `Pull
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Branch -> `String "branch"
                    | `Pull -> `String "pull"

                  type t =
                    ([ `Branch
                     | `Pull
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                type t = {
                  data : Data.t;
                  provider : Provider.t;
                  type_ : Type.t; [@key "type"]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Creator = struct
            module V0 = struct
              module Primary = struct
                type t = { id : int64 option [@default None] }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = V0 of V0.t [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [ (fun v -> map (fun v -> V0 v) (V0.of_yojson v)) ])

            let to_yojson = function
              | V0 v -> V0.to_yojson v
          end

          module Creator_type = struct
            let t_of_yojson = function
              | `String "organization" -> Ok `Organization
              | `String "user" -> Ok `User
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Organization -> `String "organization"
              | `User -> `String "user"

            type t =
              ([ `Organization
               | `User
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Custom_agent = struct
            module Primary = struct
              type t = { id : string option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Owner = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Repository = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Sessions = struct
            module Items = struct
              module Primary = struct
                module Error = struct
                  module Primary = struct
                    type t = { message : string option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Owner = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Repository = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module State = struct
                  let t_of_yojson = function
                    | `String "cancelled" -> Ok `Cancelled
                    | `String "completed" -> Ok `Completed
                    | `String "failed" -> Ok `Failed
                    | `String "idle" -> Ok `Idle
                    | `String "in_progress" -> Ok `In_progress
                    | `String "queued" -> Ok `Queued
                    | `String "timed_out" -> Ok `Timed_out
                    | `String "waiting_for_user" -> Ok `Waiting_for_user
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Cancelled -> `String "cancelled"
                    | `Completed -> `String "completed"
                    | `Failed -> `String "failed"
                    | `Idle -> `String "idle"
                    | `In_progress -> `String "in_progress"
                    | `Queued -> `String "queued"
                    | `Timed_out -> `String "timed_out"
                    | `Waiting_for_user -> `String "waiting_for_user"

                  type t =
                    ([ `Cancelled
                     | `Completed
                     | `Failed
                     | `Idle
                     | `In_progress
                     | `Queued
                     | `Timed_out
                     | `Waiting_for_user
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Usage = struct
                  module Primary = struct
                    module Type = struct
                      let t_of_yojson = function
                        | `String "ai_credits" -> Ok `Ai_credits
                        | `String "premium_requests" -> Ok `Premium_requests
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Ai_credits -> `String "ai_credits"
                        | `Premium_requests -> `String "premium_requests"

                      type t =
                        ([ `Ai_credits
                         | `Premium_requests
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      amount : float;
                      type_ : Type.t; [@key "type"]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module User = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = {
                  base_ref : string option; [@default None]
                  completed_at : string option; [@default None]
                  created_at : string;
                  error : Error.t option; [@default None]
                  head_ref : string option; [@default None]
                  id : string;
                  model : string option; [@default None]
                  name : string option; [@default None]
                  owner : Owner.t option; [@default None]
                  prompt : string option; [@default None]
                  repository : Repository.t option; [@default None]
                  state : State.t;
                  task_id : string option; [@default None]
                  updated_at : string option; [@default None]
                  usage : Usage.t option; [@default None]
                  user : User.t option; [@default None]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module State = struct
            let t_of_yojson = function
              | `String "cancelled" -> Ok `Cancelled
              | `String "completed" -> Ok `Completed
              | `String "failed" -> Ok `Failed
              | `String "idle" -> Ok `Idle
              | `String "in_progress" -> Ok `In_progress
              | `String "queued" -> Ok `Queued
              | `String "timed_out" -> Ok `Timed_out
              | `String "waiting_for_user" -> Ok `Waiting_for_user
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Cancelled -> `String "cancelled"
              | `Completed -> `String "completed"
              | `Failed -> `String "failed"
              | `Idle -> `String "idle"
              | `In_progress -> `String "in_progress"
              | `Queued -> `String "queued"
              | `Timed_out -> `String "timed_out"
              | `Waiting_for_user -> `String "waiting_for_user"

            type t =
              ([ `Cancelled
               | `Completed
               | `Failed
               | `Idle
               | `In_progress
               | `Queued
               | `Timed_out
               | `Waiting_for_user
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module User_collaborators = struct
            module Items = struct
              module Primary = struct
                type t = { id : int64 option [@default None] }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          type t = {
            archived_at : string option; [@default None]
            artifacts : Artifacts.t option; [@default None]
            created_at : string;
            creator : Creator.t option; [@default None]
            creator_type : Creator_type.t option; [@default None]
            custom_agent : Custom_agent.t option; [@default None]
            html_url : string option; [@default None]
            id : string;
            name : string option; [@default None]
            owner : Owner.t option; [@default None]
            repository : Repository.t option; [@default None]
            session_count : int option; [@default None]
            sessions : Sessions.t option; [@default None]
            state : State.t;
            updated_at : string option; [@default None]
            url : string option; [@default None]
            user_collaborators : User_collaborators.t option; [@default None]
          }
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module T = struct
        module Primary = struct
          module Artifacts = struct
            module Items = struct
              module Primary = struct
                module Data = struct
                  module V0 = struct
                    module Primary = struct
                      type t = {
                        global_id : string option; [@default None]
                        id : int64;
                      }
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                  end

                  module V1 = struct
                    module Primary = struct
                      type t = {
                        base_ref : string;
                        head_ref : string;
                      }
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                  end

                  type t =
                    | V0 of V0.t
                    | V1 of V1.t
                  [@@deriving show, eq]

                  let of_yojson =
                    Json_schema.one_of
                      (let open CCResult in
                       [
                         (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                         (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                       ])

                  let to_yojson = function
                    | V0 v -> V0.to_yojson v
                    | V1 v -> V1.to_yojson v
                end

                module Provider = struct
                  let t_of_yojson = function
                    | `String "github" -> Ok `Github
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Github -> `String "github"

                  type t = ([ `Github ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Type = struct
                  let t_of_yojson = function
                    | `String "branch" -> Ok `Branch
                    | `String "pull" -> Ok `Pull
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Branch -> `String "branch"
                    | `Pull -> `String "pull"

                  type t =
                    ([ `Branch
                     | `Pull
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                type t = {
                  data : Data.t;
                  provider : Provider.t;
                  type_ : Type.t; [@key "type"]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Creator = struct
            module V0 = struct
              module Primary = struct
                type t = { id : int64 option [@default None] }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = V0 of V0.t [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [ (fun v -> map (fun v -> V0 v) (V0.of_yojson v)) ])

            let to_yojson = function
              | V0 v -> V0.to_yojson v
          end

          module Creator_type = struct
            let t_of_yojson = function
              | `String "organization" -> Ok `Organization
              | `String "user" -> Ok `User
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Organization -> `String "organization"
              | `User -> `String "user"

            type t =
              ([ `Organization
               | `User
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Custom_agent = struct
            module Primary = struct
              type t = { id : string option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Owner = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Repository = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Sessions = struct
            module Items = struct
              module Primary = struct
                module Error = struct
                  module Primary = struct
                    type t = { message : string option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Owner = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Repository = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module State = struct
                  let t_of_yojson = function
                    | `String "cancelled" -> Ok `Cancelled
                    | `String "completed" -> Ok `Completed
                    | `String "failed" -> Ok `Failed
                    | `String "idle" -> Ok `Idle
                    | `String "in_progress" -> Ok `In_progress
                    | `String "queued" -> Ok `Queued
                    | `String "timed_out" -> Ok `Timed_out
                    | `String "waiting_for_user" -> Ok `Waiting_for_user
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Cancelled -> `String "cancelled"
                    | `Completed -> `String "completed"
                    | `Failed -> `String "failed"
                    | `Idle -> `String "idle"
                    | `In_progress -> `String "in_progress"
                    | `Queued -> `String "queued"
                    | `Timed_out -> `String "timed_out"
                    | `Waiting_for_user -> `String "waiting_for_user"

                  type t =
                    ([ `Cancelled
                     | `Completed
                     | `Failed
                     | `Idle
                     | `In_progress
                     | `Queued
                     | `Timed_out
                     | `Waiting_for_user
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Usage = struct
                  module Primary = struct
                    module Type = struct
                      let t_of_yojson = function
                        | `String "ai_credits" -> Ok `Ai_credits
                        | `String "premium_requests" -> Ok `Premium_requests
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Ai_credits -> `String "ai_credits"
                        | `Premium_requests -> `String "premium_requests"

                      type t =
                        ([ `Ai_credits
                         | `Premium_requests
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      amount : float;
                      type_ : Type.t; [@key "type"]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module User = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = {
                  base_ref : string option; [@default None]
                  completed_at : string option; [@default None]
                  created_at : string;
                  error : Error.t option; [@default None]
                  head_ref : string option; [@default None]
                  id : string;
                  model : string option; [@default None]
                  name : string option; [@default None]
                  owner : Owner.t option; [@default None]
                  prompt : string option; [@default None]
                  repository : Repository.t option; [@default None]
                  state : State.t;
                  task_id : string option; [@default None]
                  updated_at : string option; [@default None]
                  usage : Usage.t option; [@default None]
                  user : User.t option; [@default None]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module State = struct
            let t_of_yojson = function
              | `String "cancelled" -> Ok `Cancelled
              | `String "completed" -> Ok `Completed
              | `String "failed" -> Ok `Failed
              | `String "idle" -> Ok `Idle
              | `String "in_progress" -> Ok `In_progress
              | `String "queued" -> Ok `Queued
              | `String "timed_out" -> Ok `Timed_out
              | `String "waiting_for_user" -> Ok `Waiting_for_user
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Cancelled -> `String "cancelled"
              | `Completed -> `String "completed"
              | `Failed -> `String "failed"
              | `Idle -> `String "idle"
              | `In_progress -> `String "in_progress"
              | `Queued -> `String "queued"
              | `Timed_out -> `String "timed_out"
              | `Waiting_for_user -> `String "waiting_for_user"

            type t =
              ([ `Cancelled
               | `Completed
               | `Failed
               | `Idle
               | `In_progress
               | `Queued
               | `Timed_out
               | `Waiting_for_user
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module User_collaborators = struct
            module Items = struct
              module Primary = struct
                type t = { id : int64 option [@default None] }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          type t = {
            archived_at : string option; [@default None]
            artifacts : Artifacts.t option; [@default None]
            created_at : string;
            creator : Creator.t option; [@default None]
            creator_type : Creator_type.t option; [@default None]
            custom_agent : Custom_agent.t option; [@default None]
            html_url : string option; [@default None]
            id : string;
            name : string option; [@default None]
            owner : Owner.t option; [@default None]
            repository : Repository.t option; [@default None]
            session_count : int option; [@default None]
            sessions : Sessions.t option; [@default None]
            state : State.t;
            updated_at : string option; [@default None]
            url : string option; [@default None]
            user_collaborators : User_collaborators.t option; [@default None]
          }
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = T.t [@@deriving yojson { strict = false; meta = false }, show, eq]

      let of_yojson json =
        let open CCResult in
        flat_map (fun _ -> T.of_yojson json) (All_of.of_yojson json)
    end

    module Bad_request = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unauthorized = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Forbidden = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_found = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unprocessable_entity = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/agents/tasks/{task_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("task_id", Var (params.task_id, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_tasks = struct
  module Parameters = struct
    module Direction = struct
      let t_of_yojson = function
        | `String "asc" -> Ok `Asc
        | `String "desc" -> Ok `Desc
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Asc -> `String "asc"
        | `Desc -> `String "desc"

      type t =
        ([ `Asc
         | `Desc
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "updated_at" -> Ok `Updated_at
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Updated_at -> `String "updated_at"

      type t =
        ([ `Created_at
         | `Updated_at
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      direction : Direction.t; [@default `Desc]
      is_archived : bool; [@default false]
      page : int; [@default 1]
      per_page : int; [@default 30]
      since : string option; [@default None]
      sort : Sort.t; [@default `Updated_at]
      state : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "agents"
    / "tasks"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option_default
         `Updated_at
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "state")
    /? option_default false (bool "is_archived")
    /? option (string "since")

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Tasks = struct
          module Items = struct
            module Primary = struct
              module Artifacts = struct
                module Items = struct
                  module Primary = struct
                    module Data = struct
                      module V0 = struct
                        module Primary = struct
                          type t = {
                            global_id : string option; [@default None]
                            id : int64;
                          }
                          [@@deriving yojson { strict = false; meta = true }, show, eq]
                        end

                        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                      end

                      module V1 = struct
                        module Primary = struct
                          type t = {
                            base_ref : string;
                            head_ref : string;
                          }
                          [@@deriving yojson { strict = false; meta = true }, show, eq]
                        end

                        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                      end

                      type t =
                        | V0 of V0.t
                        | V1 of V1.t
                      [@@deriving show, eq]

                      let of_yojson =
                        Json_schema.one_of
                          (let open CCResult in
                           [
                             (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                             (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                           ])

                      let to_yojson = function
                        | V0 v -> V0.to_yojson v
                        | V1 v -> V1.to_yojson v
                    end

                    module Provider = struct
                      let t_of_yojson = function
                        | `String "github" -> Ok `Github
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Github -> `String "github"

                      type t = ([ `Github ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Type = struct
                      let t_of_yojson = function
                        | `String "branch" -> Ok `Branch
                        | `String "pull" -> Ok `Pull
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Branch -> `String "branch"
                        | `Pull -> `String "pull"

                      type t =
                        ([ `Branch
                         | `Pull
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      data : Data.t;
                      provider : Provider.t;
                      type_ : Type.t; [@key "type"]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Creator = struct
                module V0 = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = V0 of V0.t [@@deriving show, eq]

                let of_yojson =
                  Json_schema.one_of
                    (let open CCResult in
                     [ (fun v -> map (fun v -> V0 v) (V0.of_yojson v)) ])

                let to_yojson = function
                  | V0 v -> V0.to_yojson v
              end

              module Creator_type = struct
                let t_of_yojson = function
                  | `String "organization" -> Ok `Organization
                  | `String "user" -> Ok `User
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Organization -> `String "organization"
                  | `User -> `String "user"

                type t =
                  ([ `Organization
                   | `User
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Custom_agent = struct
                module Primary = struct
                  type t = { id : string option [@default None] }
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              module Owner = struct
                module Primary = struct
                  type t = { id : int64 option [@default None] }
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              module Repository = struct
                module Primary = struct
                  type t = { id : int64 option [@default None] }
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              module State = struct
                let t_of_yojson = function
                  | `String "cancelled" -> Ok `Cancelled
                  | `String "completed" -> Ok `Completed
                  | `String "failed" -> Ok `Failed
                  | `String "idle" -> Ok `Idle
                  | `String "in_progress" -> Ok `In_progress
                  | `String "queued" -> Ok `Queued
                  | `String "timed_out" -> Ok `Timed_out
                  | `String "waiting_for_user" -> Ok `Waiting_for_user
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Cancelled -> `String "cancelled"
                  | `Completed -> `String "completed"
                  | `Failed -> `String "failed"
                  | `Idle -> `String "idle"
                  | `In_progress -> `String "in_progress"
                  | `Queued -> `String "queued"
                  | `Timed_out -> `String "timed_out"
                  | `Waiting_for_user -> `String "waiting_for_user"

                type t =
                  ([ `Cancelled
                   | `Completed
                   | `Failed
                   | `Idle
                   | `In_progress
                   | `Queued
                   | `Timed_out
                   | `Waiting_for_user
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module User_collaborators = struct
                module Items = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                archived_at : string option; [@default None]
                artifacts : Artifacts.t option; [@default None]
                created_at : string;
                creator : Creator.t option; [@default None]
                creator_type : Creator_type.t option; [@default None]
                custom_agent : Custom_agent.t option; [@default None]
                html_url : string option; [@default None]
                id : string;
                name : string option; [@default None]
                owner : Owner.t option; [@default None]
                repository : Repository.t option; [@default None]
                session_count : int option; [@default None]
                state : State.t;
                updated_at : string option; [@default None]
                url : string option; [@default None]
                user_collaborators : User_collaborators.t option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          tasks : Tasks.t;
          total_active_count : int option; [@default None]
          total_archived_count : int option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Bad_request = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unauthorized = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Forbidden = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unprocessable_entity = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/agents/tasks"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("state", Var (params.state, Option String));
           ("is_archived", Var (params.is_archived, Bool));
           ("since", Var (params.since, Option String));
         ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_task_by_repo_and_id = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
      task_id : string;
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "agents" / "repos" /% Path.string /% Path.string / "tasks" /% Path.string

  module Responses = struct
    module OK = struct
      module All_of = struct
        module Primary = struct
          module Artifacts = struct
            module Items = struct
              module Primary = struct
                module Data = struct
                  module V0 = struct
                    module Primary = struct
                      type t = {
                        global_id : string option; [@default None]
                        id : int64;
                      }
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                  end

                  module V1 = struct
                    module Primary = struct
                      type t = {
                        base_ref : string;
                        head_ref : string;
                      }
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                  end

                  type t =
                    | V0 of V0.t
                    | V1 of V1.t
                  [@@deriving show, eq]

                  let of_yojson =
                    Json_schema.one_of
                      (let open CCResult in
                       [
                         (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                         (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                       ])

                  let to_yojson = function
                    | V0 v -> V0.to_yojson v
                    | V1 v -> V1.to_yojson v
                end

                module Provider = struct
                  let t_of_yojson = function
                    | `String "github" -> Ok `Github
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Github -> `String "github"

                  type t = ([ `Github ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Type = struct
                  let t_of_yojson = function
                    | `String "branch" -> Ok `Branch
                    | `String "pull" -> Ok `Pull
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Branch -> `String "branch"
                    | `Pull -> `String "pull"

                  type t =
                    ([ `Branch
                     | `Pull
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                type t = {
                  data : Data.t;
                  provider : Provider.t;
                  type_ : Type.t; [@key "type"]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Creator = struct
            module V0 = struct
              module Primary = struct
                type t = { id : int64 option [@default None] }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = V0 of V0.t [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [ (fun v -> map (fun v -> V0 v) (V0.of_yojson v)) ])

            let to_yojson = function
              | V0 v -> V0.to_yojson v
          end

          module Creator_type = struct
            let t_of_yojson = function
              | `String "organization" -> Ok `Organization
              | `String "user" -> Ok `User
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Organization -> `String "organization"
              | `User -> `String "user"

            type t =
              ([ `Organization
               | `User
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Custom_agent = struct
            module Primary = struct
              type t = { id : string option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Owner = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Repository = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Sessions = struct
            module Items = struct
              module Primary = struct
                module Error = struct
                  module Primary = struct
                    type t = { message : string option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Owner = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Repository = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module State = struct
                  let t_of_yojson = function
                    | `String "cancelled" -> Ok `Cancelled
                    | `String "completed" -> Ok `Completed
                    | `String "failed" -> Ok `Failed
                    | `String "idle" -> Ok `Idle
                    | `String "in_progress" -> Ok `In_progress
                    | `String "queued" -> Ok `Queued
                    | `String "timed_out" -> Ok `Timed_out
                    | `String "waiting_for_user" -> Ok `Waiting_for_user
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Cancelled -> `String "cancelled"
                    | `Completed -> `String "completed"
                    | `Failed -> `String "failed"
                    | `Idle -> `String "idle"
                    | `In_progress -> `String "in_progress"
                    | `Queued -> `String "queued"
                    | `Timed_out -> `String "timed_out"
                    | `Waiting_for_user -> `String "waiting_for_user"

                  type t =
                    ([ `Cancelled
                     | `Completed
                     | `Failed
                     | `Idle
                     | `In_progress
                     | `Queued
                     | `Timed_out
                     | `Waiting_for_user
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Usage = struct
                  module Primary = struct
                    module Type = struct
                      let t_of_yojson = function
                        | `String "ai_credits" -> Ok `Ai_credits
                        | `String "premium_requests" -> Ok `Premium_requests
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Ai_credits -> `String "ai_credits"
                        | `Premium_requests -> `String "premium_requests"

                      type t =
                        ([ `Ai_credits
                         | `Premium_requests
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      amount : float;
                      type_ : Type.t; [@key "type"]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module User = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = {
                  base_ref : string option; [@default None]
                  completed_at : string option; [@default None]
                  created_at : string;
                  error : Error.t option; [@default None]
                  head_ref : string option; [@default None]
                  id : string;
                  model : string option; [@default None]
                  name : string option; [@default None]
                  owner : Owner.t option; [@default None]
                  prompt : string option; [@default None]
                  repository : Repository.t option; [@default None]
                  state : State.t;
                  task_id : string option; [@default None]
                  updated_at : string option; [@default None]
                  usage : Usage.t option; [@default None]
                  user : User.t option; [@default None]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module State = struct
            let t_of_yojson = function
              | `String "cancelled" -> Ok `Cancelled
              | `String "completed" -> Ok `Completed
              | `String "failed" -> Ok `Failed
              | `String "idle" -> Ok `Idle
              | `String "in_progress" -> Ok `In_progress
              | `String "queued" -> Ok `Queued
              | `String "timed_out" -> Ok `Timed_out
              | `String "waiting_for_user" -> Ok `Waiting_for_user
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Cancelled -> `String "cancelled"
              | `Completed -> `String "completed"
              | `Failed -> `String "failed"
              | `Idle -> `String "idle"
              | `In_progress -> `String "in_progress"
              | `Queued -> `String "queued"
              | `Timed_out -> `String "timed_out"
              | `Waiting_for_user -> `String "waiting_for_user"

            type t =
              ([ `Cancelled
               | `Completed
               | `Failed
               | `Idle
               | `In_progress
               | `Queued
               | `Timed_out
               | `Waiting_for_user
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module User_collaborators = struct
            module Items = struct
              module Primary = struct
                type t = { id : int64 option [@default None] }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          type t = {
            archived_at : string option; [@default None]
            artifacts : Artifacts.t option; [@default None]
            created_at : string;
            creator : Creator.t option; [@default None]
            creator_type : Creator_type.t option; [@default None]
            custom_agent : Custom_agent.t option; [@default None]
            html_url : string option; [@default None]
            id : string;
            name : string option; [@default None]
            owner : Owner.t option; [@default None]
            repository : Repository.t option; [@default None]
            session_count : int option; [@default None]
            sessions : Sessions.t option; [@default None]
            state : State.t;
            updated_at : string option; [@default None]
            url : string option; [@default None]
            user_collaborators : User_collaborators.t option; [@default None]
          }
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      module T = struct
        module Primary = struct
          module Artifacts = struct
            module Items = struct
              module Primary = struct
                module Data = struct
                  module V0 = struct
                    module Primary = struct
                      type t = {
                        global_id : string option; [@default None]
                        id : int64;
                      }
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                  end

                  module V1 = struct
                    module Primary = struct
                      type t = {
                        base_ref : string;
                        head_ref : string;
                      }
                      [@@deriving yojson { strict = false; meta = true }, show, eq]
                    end

                    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                  end

                  type t =
                    | V0 of V0.t
                    | V1 of V1.t
                  [@@deriving show, eq]

                  let of_yojson =
                    Json_schema.one_of
                      (let open CCResult in
                       [
                         (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                         (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                       ])

                  let to_yojson = function
                    | V0 v -> V0.to_yojson v
                    | V1 v -> V1.to_yojson v
                end

                module Provider = struct
                  let t_of_yojson = function
                    | `String "github" -> Ok `Github
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Github -> `String "github"

                  type t = ([ `Github ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Type = struct
                  let t_of_yojson = function
                    | `String "branch" -> Ok `Branch
                    | `String "pull" -> Ok `Pull
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Branch -> `String "branch"
                    | `Pull -> `String "pull"

                  type t =
                    ([ `Branch
                     | `Pull
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                type t = {
                  data : Data.t;
                  provider : Provider.t;
                  type_ : Type.t; [@key "type"]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Creator = struct
            module V0 = struct
              module Primary = struct
                type t = { id : int64 option [@default None] }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = V0 of V0.t [@@deriving show, eq]

            let of_yojson =
              Json_schema.one_of
                (let open CCResult in
                 [ (fun v -> map (fun v -> V0 v) (V0.of_yojson v)) ])

            let to_yojson = function
              | V0 v -> V0.to_yojson v
          end

          module Creator_type = struct
            let t_of_yojson = function
              | `String "organization" -> Ok `Organization
              | `String "user" -> Ok `User
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Organization -> `String "organization"
              | `User -> `String "user"

            type t =
              ([ `Organization
               | `User
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module Custom_agent = struct
            module Primary = struct
              type t = { id : string option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Owner = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Repository = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          module Sessions = struct
            module Items = struct
              module Primary = struct
                module Error = struct
                  module Primary = struct
                    type t = { message : string option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Owner = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module Repository = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module State = struct
                  let t_of_yojson = function
                    | `String "cancelled" -> Ok `Cancelled
                    | `String "completed" -> Ok `Completed
                    | `String "failed" -> Ok `Failed
                    | `String "idle" -> Ok `Idle
                    | `String "in_progress" -> Ok `In_progress
                    | `String "queued" -> Ok `Queued
                    | `String "timed_out" -> Ok `Timed_out
                    | `String "waiting_for_user" -> Ok `Waiting_for_user
                    | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                  let t_to_yojson = function
                    | `Cancelled -> `String "cancelled"
                    | `Completed -> `String "completed"
                    | `Failed -> `String "failed"
                    | `Idle -> `String "idle"
                    | `In_progress -> `String "in_progress"
                    | `Queued -> `String "queued"
                    | `Timed_out -> `String "timed_out"
                    | `Waiting_for_user -> `String "waiting_for_user"

                  type t =
                    ([ `Cancelled
                     | `Completed
                     | `Failed
                     | `Idle
                     | `In_progress
                     | `Queued
                     | `Timed_out
                     | `Waiting_for_user
                     ]
                    [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                  [@@deriving yojson { strict = false; meta = false }, show, eq]
                end

                module Usage = struct
                  module Primary = struct
                    module Type = struct
                      let t_of_yojson = function
                        | `String "ai_credits" -> Ok `Ai_credits
                        | `String "premium_requests" -> Ok `Premium_requests
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Ai_credits -> `String "ai_credits"
                        | `Premium_requests -> `String "premium_requests"

                      type t =
                        ([ `Ai_credits
                         | `Premium_requests
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      amount : float;
                      type_ : Type.t; [@key "type"]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module User = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = {
                  base_ref : string option; [@default None]
                  completed_at : string option; [@default None]
                  created_at : string;
                  error : Error.t option; [@default None]
                  head_ref : string option; [@default None]
                  id : string;
                  model : string option; [@default None]
                  name : string option; [@default None]
                  owner : Owner.t option; [@default None]
                  prompt : string option; [@default None]
                  repository : Repository.t option; [@default None]
                  state : State.t;
                  task_id : string option; [@default None]
                  updated_at : string option; [@default None]
                  usage : Usage.t option; [@default None]
                  user : User.t option; [@default None]
                }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module State = struct
            let t_of_yojson = function
              | `String "cancelled" -> Ok `Cancelled
              | `String "completed" -> Ok `Completed
              | `String "failed" -> Ok `Failed
              | `String "idle" -> Ok `Idle
              | `String "in_progress" -> Ok `In_progress
              | `String "queued" -> Ok `Queued
              | `String "timed_out" -> Ok `Timed_out
              | `String "waiting_for_user" -> Ok `Waiting_for_user
              | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

            let t_to_yojson = function
              | `Cancelled -> `String "cancelled"
              | `Completed -> `String "completed"
              | `Failed -> `String "failed"
              | `Idle -> `String "idle"
              | `In_progress -> `String "in_progress"
              | `Queued -> `String "queued"
              | `Timed_out -> `String "timed_out"
              | `Waiting_for_user -> `String "waiting_for_user"

            type t =
              ([ `Cancelled
               | `Completed
               | `Failed
               | `Idle
               | `In_progress
               | `Queued
               | `Timed_out
               | `Waiting_for_user
               ]
              [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
            [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          module User_collaborators = struct
            module Items = struct
              module Primary = struct
                type t = { id : int64 option [@default None] }
                [@@deriving yojson { strict = false; meta = true }, show, eq]
              end

              include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
            end

            type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
          end

          type t = {
            archived_at : string option; [@default None]
            artifacts : Artifacts.t option; [@default None]
            created_at : string;
            creator : Creator.t option; [@default None]
            creator_type : Creator_type.t option; [@default None]
            custom_agent : Custom_agent.t option; [@default None]
            html_url : string option; [@default None]
            id : string;
            name : string option; [@default None]
            owner : Owner.t option; [@default None]
            repository : Repository.t option; [@default None]
            session_count : int option; [@default None]
            sessions : Sessions.t option; [@default None]
            state : State.t;
            updated_at : string option; [@default None]
            url : string option; [@default None]
            user_collaborators : User_collaborators.t option; [@default None]
          }
          [@@deriving yojson { strict = false; meta = true }, show, eq]
        end

        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
      end

      type t = T.t [@@deriving yojson { strict = false; meta = false }, show, eq]

      let of_yojson json =
        let open CCResult in
        flat_map (fun _ -> T.of_yojson json) (All_of.of_yojson json)
    end

    module Bad_request = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unauthorized = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Forbidden = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_found = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unprocessable_entity = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/agents/repos/{owner}/{repo}/tasks/{task_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("owner", Var (params.owner, String));
           ("repo", Var (params.repo, String));
           ("task_id", Var (params.task_id, String));
         ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module Create_task_in_repo = struct
  module Parameters = struct
    type t = {
      owner : string;
      repo : string;
    }
    [@@deriving make, show, eq]
  end

  module Request_body = struct
    module Primary = struct
      type t = {
        base_ref : string option; [@default None]
        create_pull_request : bool; [@default false]
        custom_agent : string option; [@default None]
        head_ref : string option; [@default None]
        model : string option; [@default None]
        prompt : string;
      }
      [@@deriving make, yojson { strict = false; meta = true }, show, eq]
    end

    include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "agents" / "repos" /% Path.string /% Path.string / "tasks"

  module Responses = struct
    module Created = struct
      module Primary = struct
        module Artifacts = struct
          module Items = struct
            module Primary = struct
              module Data = struct
                module V0 = struct
                  module Primary = struct
                    type t = {
                      global_id : string option; [@default None]
                      id : int64;
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                module V1 = struct
                  module Primary = struct
                    type t = {
                      base_ref : string;
                      head_ref : string;
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t =
                  | V0 of V0.t
                  | V1 of V1.t
                [@@deriving show, eq]

                let of_yojson =
                  Json_schema.one_of
                    (let open CCResult in
                     [
                       (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                       (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                     ])

                let to_yojson = function
                  | V0 v -> V0.to_yojson v
                  | V1 v -> V1.to_yojson v
              end

              module Provider = struct
                let t_of_yojson = function
                  | `String "github" -> Ok `Github
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Github -> `String "github"

                type t = ([ `Github ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Type = struct
                let t_of_yojson = function
                  | `String "branch" -> Ok `Branch
                  | `String "pull" -> Ok `Pull
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Branch -> `String "branch"
                  | `Pull -> `String "pull"

                type t =
                  ([ `Branch
                   | `Pull
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                data : Data.t;
                provider : Provider.t;
                type_ : Type.t; [@key "type"]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        module Creator = struct
          module V0 = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = V0 of V0.t [@@deriving show, eq]

          let of_yojson =
            Json_schema.one_of
              (let open CCResult in
               [ (fun v -> map (fun v -> V0 v) (V0.of_yojson v)) ])

          let to_yojson = function
            | V0 v -> V0.to_yojson v
        end

        module Creator_type = struct
          let t_of_yojson = function
            | `String "organization" -> Ok `Organization
            | `String "user" -> Ok `User
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Organization -> `String "organization"
            | `User -> `String "user"

          type t =
            ([ `Organization
             | `User
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        module Custom_agent = struct
          module Primary = struct
            type t = { id : string option [@default None] }
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Owner = struct
          module Primary = struct
            type t = { id : int64 option [@default None] }
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module Repository = struct
          module Primary = struct
            type t = { id : int64 option [@default None] }
            [@@deriving yojson { strict = false; meta = true }, show, eq]
          end

          include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
        end

        module State = struct
          let t_of_yojson = function
            | `String "cancelled" -> Ok `Cancelled
            | `String "completed" -> Ok `Completed
            | `String "failed" -> Ok `Failed
            | `String "idle" -> Ok `Idle
            | `String "in_progress" -> Ok `In_progress
            | `String "queued" -> Ok `Queued
            | `String "timed_out" -> Ok `Timed_out
            | `String "waiting_for_user" -> Ok `Waiting_for_user
            | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

          let t_to_yojson = function
            | `Cancelled -> `String "cancelled"
            | `Completed -> `String "completed"
            | `Failed -> `String "failed"
            | `Idle -> `String "idle"
            | `In_progress -> `String "in_progress"
            | `Queued -> `String "queued"
            | `Timed_out -> `String "timed_out"
            | `Waiting_for_user -> `String "waiting_for_user"

          type t =
            ([ `Cancelled
             | `Completed
             | `Failed
             | `Idle
             | `In_progress
             | `Queued
             | `Timed_out
             | `Waiting_for_user
             ]
            [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
          [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        module User_collaborators = struct
          module Items = struct
            module Primary = struct
              type t = { id : int64 option [@default None] }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          archived_at : string option; [@default None]
          artifacts : Artifacts.t option; [@default None]
          created_at : string;
          creator : Creator.t option; [@default None]
          creator_type : Creator_type.t option; [@default None]
          custom_agent : Custom_agent.t option; [@default None]
          html_url : string option; [@default None]
          id : string;
          name : string option; [@default None]
          owner : Owner.t option; [@default None]
          repository : Repository.t option; [@default None]
          session_count : int option; [@default None]
          state : State.t;
          updated_at : string option; [@default None]
          url : string option; [@default None]
          user_collaborators : User_collaborators.t option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Bad_request = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unauthorized = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Forbidden = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unprocessable_entity = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `Created of Created.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("201", Openapi.of_json_body (fun v -> `Created v) Created.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/agents/repos/{owner}/{repo}/tasks"

  let make ~body =
   fun params ->
    Openapi.Request.make
      ~body:(Request_body.to_yojson body)
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Post
end

module List_tasks_for_repo = struct
  module Parameters = struct
    module Creator_id = struct
      type t = int list [@@deriving show, eq]
    end

    module Direction = struct
      let t_of_yojson = function
        | `String "asc" -> Ok `Asc
        | `String "desc" -> Ok `Desc
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Asc -> `String "asc"
        | `Desc -> `String "desc"

      type t =
        ([ `Asc
         | `Desc
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    module Sort = struct
      let t_of_yojson = function
        | `String "created_at" -> Ok `Created_at
        | `String "updated_at" -> Ok `Updated_at
        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

      let t_to_yojson = function
        | `Created_at -> `String "created_at"
        | `Updated_at -> `String "updated_at"

      type t =
        ([ `Created_at
         | `Updated_at
         ]
        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
      [@@deriving show, eq]
    end

    type t = {
      creator_id : Creator_id.t option; [@default None]
      direction : Direction.t; [@default `Desc]
      is_archived : bool; [@default false]
      owner : string;
      page : int; [@default 1]
      per_page : int; [@default 30]
      repo : string;
      since : string option; [@default None]
      sort : Sort.t; [@default `Updated_at]
      state : string option; [@default None]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "agents"
    / "repos"
    /% Path.string
    /% Path.string
    / "tasks"
    /? option_default 30 (int "per_page")
    /? option_default 1 (int "page")
    /? option_default
         `Updated_at
         (ud "sort" (fun value -> CCResult.to_opt (Parameters.Sort.t_of_yojson (`String value))))
    /? option_default
         `Desc
         (ud "direction" (fun value ->
              CCResult.to_opt (Parameters.Direction.t_of_yojson (`String value))))
    /? option (string "state")
    /? option_default false (bool "is_archived")
    /? option (string "since")
    /? option (array (int "creator_id"))

  module Responses = struct
    module OK = struct
      module Primary = struct
        module Tasks = struct
          module Items = struct
            module Primary = struct
              module Artifacts = struct
                module Items = struct
                  module Primary = struct
                    module Data = struct
                      module V0 = struct
                        module Primary = struct
                          type t = {
                            global_id : string option; [@default None]
                            id : int64;
                          }
                          [@@deriving yojson { strict = false; meta = true }, show, eq]
                        end

                        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                      end

                      module V1 = struct
                        module Primary = struct
                          type t = {
                            base_ref : string;
                            head_ref : string;
                          }
                          [@@deriving yojson { strict = false; meta = true }, show, eq]
                        end

                        include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                      end

                      type t =
                        | V0 of V0.t
                        | V1 of V1.t
                      [@@deriving show, eq]

                      let of_yojson =
                        Json_schema.one_of
                          (let open CCResult in
                           [
                             (fun v -> map (fun v -> V0 v) (V0.of_yojson v));
                             (fun v -> map (fun v -> V1 v) (V1.of_yojson v));
                           ])

                      let to_yojson = function
                        | V0 v -> V0.to_yojson v
                        | V1 v -> V1.to_yojson v
                    end

                    module Provider = struct
                      let t_of_yojson = function
                        | `String "github" -> Ok `Github
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Github -> `String "github"

                      type t = ([ `Github ][@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    module Type = struct
                      let t_of_yojson = function
                        | `String "branch" -> Ok `Branch
                        | `String "pull" -> Ok `Pull
                        | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                      let t_to_yojson = function
                        | `Branch -> `String "branch"
                        | `Pull -> `String "pull"

                      type t =
                        ([ `Branch
                         | `Pull
                         ]
                        [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                      [@@deriving yojson { strict = false; meta = false }, show, eq]
                    end

                    type t = {
                      data : Data.t;
                      provider : Provider.t;
                      type_ : Type.t; [@key "type"]
                    }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Creator = struct
                module V0 = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = V0 of V0.t [@@deriving show, eq]

                let of_yojson =
                  Json_schema.one_of
                    (let open CCResult in
                     [ (fun v -> map (fun v -> V0 v) (V0.of_yojson v)) ])

                let to_yojson = function
                  | V0 v -> V0.to_yojson v
              end

              module Creator_type = struct
                let t_of_yojson = function
                  | `String "organization" -> Ok `Organization
                  | `String "user" -> Ok `User
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Organization -> `String "organization"
                  | `User -> `String "user"

                type t =
                  ([ `Organization
                   | `User
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module Custom_agent = struct
                module Primary = struct
                  type t = { id : string option [@default None] }
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              module Owner = struct
                module Primary = struct
                  type t = { id : int64 option [@default None] }
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              module Repository = struct
                module Primary = struct
                  type t = { id : int64 option [@default None] }
                  [@@deriving yojson { strict = false; meta = true }, show, eq]
                end

                include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
              end

              module State = struct
                let t_of_yojson = function
                  | `String "cancelled" -> Ok `Cancelled
                  | `String "completed" -> Ok `Completed
                  | `String "failed" -> Ok `Failed
                  | `String "idle" -> Ok `Idle
                  | `String "in_progress" -> Ok `In_progress
                  | `String "queued" -> Ok `Queued
                  | `String "timed_out" -> Ok `Timed_out
                  | `String "waiting_for_user" -> Ok `Waiting_for_user
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Cancelled -> `String "cancelled"
                  | `Completed -> `String "completed"
                  | `Failed -> `String "failed"
                  | `Idle -> `String "idle"
                  | `In_progress -> `String "in_progress"
                  | `Queued -> `String "queued"
                  | `Timed_out -> `String "timed_out"
                  | `Waiting_for_user -> `String "waiting_for_user"

                type t =
                  ([ `Cancelled
                   | `Completed
                   | `Failed
                   | `Idle
                   | `In_progress
                   | `Queued
                   | `Timed_out
                   | `Waiting_for_user
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              module User_collaborators = struct
                module Items = struct
                  module Primary = struct
                    type t = { id : int64 option [@default None] }
                    [@@deriving yojson { strict = false; meta = true }, show, eq]
                  end

                  include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
                end

                type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                archived_at : string option; [@default None]
                artifacts : Artifacts.t option; [@default None]
                created_at : string;
                creator : Creator.t option; [@default None]
                creator_type : Creator_type.t option; [@default None]
                custom_agent : Custom_agent.t option; [@default None]
                html_url : string option; [@default None]
                id : string;
                name : string option; [@default None]
                owner : Owner.t option; [@default None]
                repository : Repository.t option; [@default None]
                session_count : int option; [@default None]
                state : State.t;
                updated_at : string option; [@default None]
                url : string option; [@default None]
                user_collaborators : User_collaborators.t option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          tasks : Tasks.t;
          total_active_count : int option; [@default None]
          total_archived_count : int option; [@default None]
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Bad_request = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unauthorized = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Forbidden = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Not_found = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    module Unprocessable_entity = struct
      module Primary = struct
        module Errors = struct
          module Items = struct
            module Primary = struct
              module Code = struct
                let t_of_yojson = function
                  | `String "already_exists" -> Ok `Already_exists
                  | `String "custom" -> Ok `Custom
                  | `String "invalid" -> Ok `Invalid
                  | `String "missing" -> Ok `Missing
                  | `String "missing_field" -> Ok `Missing_field
                  | `String "unprocessable" -> Ok `Unprocessable
                  | json -> Error ("Unknown value: " ^ Yojson.Safe.pretty_to_string json)

                let t_to_yojson = function
                  | `Already_exists -> `String "already_exists"
                  | `Custom -> `String "custom"
                  | `Invalid -> `String "invalid"
                  | `Missing -> `String "missing"
                  | `Missing_field -> `String "missing_field"
                  | `Unprocessable -> `String "unprocessable"

                type t =
                  ([ `Already_exists
                   | `Custom
                   | `Invalid
                   | `Missing
                   | `Missing_field
                   | `Unprocessable
                   ]
                  [@of_yojson t_of_yojson] [@to_yojson t_to_yojson])
                [@@deriving yojson { strict = false; meta = false }, show, eq]
              end

              type t = {
                code : Code.t;
                message : string option; [@default None]
              }
              [@@deriving yojson { strict = false; meta = true }, show, eq]
            end

            include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
          end

          type t = Items.t list [@@deriving yojson { strict = false; meta = false }, show, eq]
        end

        type t = {
          documentation_url : string;
          errors : Errors.t option; [@default None]
          message : string;
        }
        [@@deriving yojson { strict = false; meta = true }, show, eq]
      end

      include Json_schema.Additional_properties.Make (Primary) (Json_schema.Obj)
    end

    type t =
      [ `OK of OK.t
      | `Bad_request of Bad_request.t
      | `Unauthorized of Unauthorized.t
      | `Forbidden of Forbidden.t
      | `Not_found of Not_found.t
      | `Unprocessable_entity of Unprocessable_entity.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("400", Openapi.of_json_body (fun v -> `Bad_request v) Bad_request.of_yojson);
        ("401", Openapi.of_json_body (fun v -> `Unauthorized v) Unauthorized.of_yojson);
        ("403", Openapi.of_json_body (fun v -> `Forbidden v) Forbidden.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ( "422",
          Openapi.of_json_body (fun v -> `Unprocessable_entity v) Unprocessable_entity.of_yojson );
      ]
  end

  let url = "/agents/repos/{owner}/{repo}/tasks"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("owner", Var (params.owner, String)); ("repo", Var (params.repo, String)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [
           ("per_page", Var (params.per_page, Int));
           ("page", Var (params.page, Int));
           ("sort", Var (params.sort, Enum Sort.t_to_yojson));
           ("direction", Var (params.direction, Enum Direction.t_to_yojson));
           ("state", Var (params.state, Option String));
           ("is_archived", Var (params.is_archived, Bool));
           ("since", Var (params.since, Option String));
           ("creator_id", Var (params.creator_id, Option (Array Int)));
         ])
      ~url
      ~responses:Responses.t
      `Get
end
