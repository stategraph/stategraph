select password_hash
from users
where id = $user_id
  and state = 'active'
