with prev as (
  select tenant_id
  from tenant_vcs_installations
  where provider = $provider and installation_core_id = $installation_core_id
), ins as (
  insert into tenant_vcs_installations (tenant_id, provider, installation_core_id)
  select t.id, $provider, $installation_core_id
  from tenants t
  where t.id = $tenant_id
  on conflict (provider, installation_core_id)
  do update set tenant_id = excluded.tenant_id, updated_at = now()
  returning tenant_id, provider, installation_core_id, created_at, updated_at
)
select
  ins.tenant_id,
  ins.provider,
  ins.installation_core_id,
  to_char(ins.created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  to_char(ins.updated_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  prev.tenant_id
from ins left join prev on true
