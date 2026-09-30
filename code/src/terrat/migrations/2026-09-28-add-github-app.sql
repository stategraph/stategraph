create table github_app (
  client_id text not null,
  client_secret text not null,
  created_at timestamp with time zone not null default (now()),
  html_url text not null,
  id bigint primary key,
  loaded_at timestamp with time zone,
  pem text not null,
  slug text not null,
  webhook_secret text not null
);

create unique index github_app_singleton_idx on github_app ((true));
