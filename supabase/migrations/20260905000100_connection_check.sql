-- Run once, as the project owner, in garage99-dev SQL Editor.
-- Only synthetic connectivity data belongs in this publicly readable table.
begin;

create table public.connection_check (
    id text primary key,
    message text not null
);

alter table public.connection_check enable row level security;
revoke all on table public.connection_check
    from public, anon, authenticated, service_role;
grant usage on schema public to anon, authenticated;
grant select on table public.connection_check to anon, authenticated;

create policy connection_check_public_read
    on public.connection_check for select
    to anon, authenticated
    using (true);

comment on table public.connection_check is
    'Garage99 development connectivity probe. Synthetic public data only.';

commit;
