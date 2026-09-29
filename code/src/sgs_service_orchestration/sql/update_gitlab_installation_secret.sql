update terrateam_admin.gitlab_installations
set webhook_secret = encode(gen_random_bytes(32), 'hex')
where id = $group_id
returning webhook_secret
