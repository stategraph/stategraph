create table if not exists github_unified_comments(
    -- the id github gave us, null until the first unified comment is posted
    comment_id bigint,
    repository bigint not null,
    pull_number bigint not null,
    dirty bigint not null default 0,
    created_at timestamptz not null default current_timestamp,
    foreign key (repository, pull_number) references github_pull_requests (repository, pull_number),
    primary key (repository, pull_number)
);
