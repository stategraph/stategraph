insert into jobs (
  context_id,
  params,
  state,
  initiator,
  continuation_of
) values (
  $context_id,
  $parameters,
  $state,
  $initiator,
  $continuation_of
)
returning
    id,
    to_char(created_at, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
    to_char(updated_at, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')
