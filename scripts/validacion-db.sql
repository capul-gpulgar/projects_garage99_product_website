-- Run ALL this file in garage99-dev SQL Editor after the migration.
-- Repeatable: only touches the synthetic row garage99-db-check.
select current_database(), current_user, now();

begin;
insert into public.connection_check (id, message)
values ('garage99-db-check', 'garage99-dev: creado')
on conflict (id) do update set message = excluded.message;

do $$
begin
    if not exists (
        select 1 from public.connection_check
        where id = 'garage99-db-check' and message = 'garage99-dev: creado'
    ) then
        raise exception 'FAIL: insert/select';
    end if;
end $$;

select * from public.connection_check where id = 'garage99-db-check';
update public.connection_check
set message = 'garage99-dev: lectura verificada'
where id = 'garage99-db-check';

do $$
begin
    if not exists (
        select 1 from public.connection_check
        where id = 'garage99-db-check'
          and message = 'garage99-dev: lectura verificada'
    ) then
        raise exception 'FAIL: update';
    end if;
end $$;
commit;

begin;
delete from public.connection_check where id = 'garage99-db-check';
do $$
begin
    if exists (
        select 1 from public.connection_check where id = 'garage99-db-check'
    ) then
        raise exception 'FAIL: delete';
    end if;
end $$;
rollback;

do $$
declare
    app_role text;
    operation text;
begin
    if not exists (
        select 1 from public.connection_check
        where id = 'garage99-db-check'
          and message = 'garage99-dev: lectura verificada'
    ) then
        raise exception 'FAIL: rollback did not restore the row';
    end if;

    if not (select relrowsecurity from pg_class
            where oid = 'public.connection_check'::regclass) then
        raise exception 'FAIL: RLS is disabled';
    end if;

    foreach app_role in array array['anon', 'authenticated'] loop
        if not has_table_privilege(app_role, 'public.connection_check', 'SELECT') then
            raise exception 'FAIL: SELECT denied for %', app_role;
        end if;
        foreach operation in array array['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'] loop
            if has_table_privilege(app_role, 'public.connection_check', operation) then
                raise exception 'FAIL: % allowed for %', operation, app_role;
            end if;
        end loop;
    end loop;
end $$;

-- Exercise RLS with the actual anonymous role, not just the DB owner.
begin;
set local role anon;
do $$
begin
    if not exists (
        select 1 from public.connection_check
        where id = 'garage99-db-check'
          and message = 'garage99-dev: lectura verificada'
    ) then
        raise exception 'FAIL: anonymous read';
    end if;
end $$;
rollback;

select 'PASS: SQL CRUD, rollback, RLS and grants' as result,
       current_database() as database_name, now() as checked_at,
       id, message
from public.connection_check where id = 'garage99-db-check';
