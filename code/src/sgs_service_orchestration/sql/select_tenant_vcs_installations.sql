select
  tenant_id,
  provider,
  installation_core_id,
  to_char(created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
from tenant_vcs_installations
where tenant_id = $tenant_id
order by provider, installation_core_id
