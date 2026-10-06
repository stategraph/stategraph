delete from oauth2_sessions
where namespace = $namespace
  and key = $key
