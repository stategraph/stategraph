type t = {
  app_id : int;
  created_at : string;
  html_url : string;
  loaded : bool;
  slug : string;
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
