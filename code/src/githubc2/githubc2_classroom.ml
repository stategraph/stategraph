module List_assignments_for_a_classroom = struct
  module Parameters = struct
    type t = {
      classroom_id : int;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "classrooms"
    /% Path.int
    / "assignments"
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Simple_classroom_assignment.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/classrooms/{classroom_id}/assignments"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("classroom_id", Var (params.classroom_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_a_classroom = struct
  module Parameters = struct
    type t = { classroom_id : int } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "classrooms" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Classroom.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/classrooms/{classroom_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("classroom_id", Var (params.classroom_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_classrooms = struct
  module Parameters = struct
    type t = {
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel / "classrooms" /? option_default 1 (int "page") /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Simple_classroom.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/classrooms"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:[]
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_assignment_grades = struct
  module Parameters = struct
    type t = { assignment_id : int } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "assignments" /% Path.int / "grades"

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Classroom_assignment_grade.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/assignments/{assignment_id}/grades"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("assignment_id", Var (params.assignment_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end

module List_accepted_assignments_for_an_assignment = struct
  module Parameters = struct
    type t = {
      assignment_id : int;
      page : int; [@default 1]
      per_page : int; [@default 30]
    }
    [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route.Query in
    let open Brtl_rtng.Route in
    rel
    / "assignments"
    /% Path.int
    / "accepted_assignments"
    /? option_default 1 (int "page")
    /? option_default 30 (int "per_page")

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Classroom_accepted_assignment.t list
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/assignments/{assignment_id}/accepted_assignments"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("assignment_id", Var (params.assignment_id, Int)) ])
      ~query_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("page", Var (params.page, Int)); ("per_page", Var (params.per_page, Int)) ])
      ~url
      ~responses:Responses.t
      `Get
end

module Get_an_assignment = struct
  module Parameters = struct
    type t = { assignment_id : int } [@@deriving make, show, eq]
  end

  let route () =
    let open Brtl_rtng.Route in
    rel / "assignments" /% Path.int

  module Responses = struct
    module OK = struct
      type t = Githubc2_components.Classroom_assignment.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Not_found = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    module Gone = struct
      type t = Githubc2_components.Basic_error.t
      [@@deriving yojson { strict = false; meta = false }, show, eq]
    end

    type t =
      [ `OK of OK.t
      | `Not_found of Not_found.t
      | `Gone of Gone.t
      ]
    [@@deriving show, eq]

    let t =
      [
        ("200", Openapi.of_json_body (fun v -> `OK v) OK.of_yojson);
        ("404", Openapi.of_json_body (fun v -> `Not_found v) Not_found.of_yojson);
        ("410", Openapi.of_json_body (fun v -> `Gone v) Gone.of_yojson);
      ]
  end

  let url = "/assignments/{assignment_id}"

  let make params =
    Openapi.Request.make
      ~headers:[]
      ~url_params:
        (let open Openapi.Request.Var in
         let open Parameters in
         [ ("assignment_id", Var (params.assignment_id, Int)) ])
      ~query_params:[]
      ~url
      ~responses:Responses.t
      `Get
end
