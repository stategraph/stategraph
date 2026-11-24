-- The installation_id here is the authenticated one: it comes from looking up
-- the webhook secret the request presented, not from the payload.  The
-- repository id, owner and name all come from the payload, so the conflict
-- guard has to check that the row already present belongs to the same
-- installation.  Without that check any holder of a valid webhook secret can
-- rewrite the owner and name of a repository belonging to a different
-- installation by sending an event naming that repository's id, and the owning
-- installation later reads those columns back and uses them with its own
-- access token.
insert into gitlab_installation_repositories as r (
       id,
       installation_id,
       name,
       owner
) values (
       $id,
       $installation_id,
       $name,
       $owner
) on conflict (id)
do update set (owner, name) = (excluded.owner, excluded.name)
where r.installation_id = excluded.installation_id
      and (r.owner, r.name) <> (excluded.owner, excluded.name)
