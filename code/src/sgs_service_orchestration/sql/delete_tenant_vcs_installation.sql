delete from tenant_vcs_installations
where tenant_id = $tenant_id and provider = $provider and installation_core_id = $installation_core_id
returning provider
