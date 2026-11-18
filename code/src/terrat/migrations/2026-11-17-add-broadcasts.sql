create table broadcasts (
  created_at timestamp with time zone not null default (now()),
  created_by text not null,
  ends_at timestamp with time zone not null,
  id uuid primary key default gen_random_uuid(),
  level text not null check (level in ('info', 'warning', 'critical')),
  message text not null check (char_length(message) >= 1 and char_length(message) <= 4000),
  updated_at timestamp with time zone,
  updated_by text,
  vcs text check (vcs in ('github', 'gitlab')),
  check (created_at < ends_at)
);

create index broadcasts_ends_at_idx on broadcasts (ends_at);
