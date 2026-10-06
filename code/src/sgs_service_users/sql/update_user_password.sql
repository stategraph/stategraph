update users
set password_hash = $password_hash
where id = $user_id
  and state = 'active'
  and password_hash is not null
returning id
