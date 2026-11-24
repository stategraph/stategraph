-- A member of the tenant, open or closed: the reopen of a closed tenant needs one.
select user_id from tenant_users where tenant_id = $tenant_id and user_id = $user_id
