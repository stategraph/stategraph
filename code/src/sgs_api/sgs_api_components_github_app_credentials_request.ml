type t = {
  app_id : int;
  client_secret : string option; [@default None]
  pem : string option; [@default None]
  webhook_secret : string option; [@default None]
}
[@@deriving yojson { strict = false; meta = true }, show, eq]
