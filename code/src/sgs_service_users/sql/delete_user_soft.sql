update users
set state = 'deleted'
where id = $user_id
  and state = 'active'
returning id
