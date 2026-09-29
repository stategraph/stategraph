-- The link holding one installation, whichever tenant holds it.
select
  tenant_id,
  provider,
  installation_core_id,
  to_char(created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
from tenant_vcs_installations
where provider = $provider and installation_core_id = $installation_core_id
