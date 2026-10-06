insert into oauth2_sessions (key, namespace, config_hash, data, expires_at)
values ($key, $namespace, $config_hash, $data, now() + ($ttl_seconds || ' seconds')::interval)
on conflict (namespace, key)
do update set data = excluded.data, expires_at = excluded.expires_at, config_hash = excluded.config_hash
