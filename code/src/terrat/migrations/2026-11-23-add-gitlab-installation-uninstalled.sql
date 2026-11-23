insert into gitlab_installation_states (id) values ('uninstalled') on conflict (id) do nothing;

alter table gitlab_installations
    add column uninstalled_by text,
    add column uninstalled_at timestamp with time zone;
