select data
from oauth2_sessions
where namespace = $namespace
  and key = $key
  and expires_at > now()
