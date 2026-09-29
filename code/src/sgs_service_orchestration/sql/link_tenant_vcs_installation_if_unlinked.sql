-- Link an installation to a tenant only when it is linked to nobody. Unlike
-- upsert_tenant_vcs_installation.sql this never moves an installation between
-- tenants: the self-serve claim path proves control of an *unclaimed*
-- installation, and proving that says nothing about the tenant currently
-- holding it. ON CONFLICT DO NOTHING makes the check and the write one
-- statement, so two callers racing for the same installation cannot both win;
-- the loser gets no row back.
insert into tenant_vcs_installations (tenant_id, provider, installation_core_id)
values ($tenant_id, $provider, $installation_core_id)
on conflict (provider, installation_core_id) do nothing
returning
  tenant_id,
  provider,
  installation_core_id,
  to_char(created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
