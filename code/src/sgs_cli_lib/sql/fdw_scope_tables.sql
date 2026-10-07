-- Foreign tables that only the tenant scope of the MQL page reads (#2469).
-- They are NOT in the catalog, thus an MQL query cannot name them. This file
-- is hand-written, not generated.
--
-- work_manifests is the base table of the *_work_manifests views and has no
-- provider. select_mql_page_terrateam_ctes.sql scopes the tables that a work
-- manifest keys through it, so that each such table is one foreign scan.
--
-- #2469: This table is necessary only because the foreign data wrapper
-- abstraction is leaky.
-- Statements are separated by single newlines to match the ";\n" splitter.
drop foreign table if exists terrateam.work_manifests;
create foreign table terrateam.work_manifests (
  id uuid,
  repo uuid
) server terrateam_fdw options (schema_name 'public', table_name 'work_manifests');
