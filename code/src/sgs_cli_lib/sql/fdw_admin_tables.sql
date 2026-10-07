-- Narrow write channel for console-driven provisioning (#1442 PR 21). This is
-- NOT generated from the catalog: it is hand-written, lives in its own schema
-- (terrateam_admin), and is reached only by the provisioning endpoints through
-- the dedicated provisioner user mapping — never by the read-only MQL surface.
--
-- postgres_fdw transmits EVERY column a foreign table declares on INSERT (an
-- omitted column is sent as the local value, i.e. NULL — the remote DEFAULT
-- does NOT fire). So the insert path uses a foreign table that declares only
-- the columns the caller supplies; the remote DEFAULTs for state and
-- webhook_secret then apply, and a separate narrow read-back table exposes the
-- generated webhook_secret + state. access_token is write-only from the
-- console's perspective (set on insert, never declared on the read table).
-- Statements are separated by single newlines to match the ";\n" splitter.
drop foreign table if exists terrateam_admin.gitlab_installations_insert;
create foreign table terrateam_admin.gitlab_installations_insert (
  id bigint,
  name text,
  access_token text
) server terrateam_admin_fdw options (schema_name 'public', table_name 'gitlab_installations');
drop foreign table if exists terrateam_admin.gitlab_installations;
create foreign table terrateam_admin.gitlab_installations (
  id bigint,
  name text,
  state text,
  webhook_secret text
) server terrateam_admin_fdw options (schema_name 'public', table_name 'gitlab_installations');
drop foreign table if exists terrateam_admin.gitlab_installations_map;
create foreign table terrateam_admin.gitlab_installations_map (
  installation_id bigint,
  core_id uuid
) server terrateam_admin_fdw options (schema_name 'public', table_name 'gitlab_installations_map');
-- The write side. It declares no created_at, so that column's remote DEFAULT
-- fires on insert; loaded_at is declared because the key rotation clears it,
-- and it is nullable with no default, so sending NULL on an insert is what the
-- row would have had anyway. What this role may actually read and write is
-- decided remotely, by the column grants in docker/stategraph/service/terrat.
drop foreign table if exists terrateam_admin.github_app_write;
create foreign table terrateam_admin.github_app_write (
  id bigint,
  slug text,
  pem text,
  client_id text,
  client_secret text,
  webhook_secret text,
  html_url text,
  loaded_at timestamp with time zone
) server terrateam_admin_fdw options (schema_name 'public', table_name 'github_app');
drop foreign table if exists terrateam_admin.github_app;
create foreign table terrateam_admin.github_app (
  id bigint,
  slug text,
  client_id text,
  client_secret text,
  html_url text,
  created_at timestamp with time zone,
  loaded_at timestamp with time zone
) server terrateam_admin_fdw options (schema_name 'public', table_name 'github_app');
