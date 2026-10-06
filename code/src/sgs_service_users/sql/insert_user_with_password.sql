insert into users (name, email, type, password_hash, capability_trie, base_capability_trie, state)
values ($name, $email, $type, $password_hash, $capability_trie, $capability_trie, 'active')
returning id
