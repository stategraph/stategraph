select id, password_hash
from users
where email = $email
  and type = 'user'
  and state = 'active'
