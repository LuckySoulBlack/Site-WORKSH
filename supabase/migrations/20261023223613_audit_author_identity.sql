-- Preserve author names after profile renames and account deletion.
alter table public.audit_events add column actor_name text;
create function private.capture_audit_actor_name() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 select nullif(btrim(p.full_name),'') into new.actor_name
 from public.profiles p where p.id=new.actor_id;
 return new;
end;
$$;
revoke all on function private.capture_audit_actor_name() from public,anon,authenticated,service_role;
create trigger capture_audit_actor_name before insert on public.audit_events
for each row execute function private.capture_audit_actor_name();
-- Legacy names reflect current profiles, not necessarily names at the event date.
update public.audit_events a set actor_name=nullif(btrim(p.full_name),'')
from public.profiles p where p.id=a.actor_id and a.actor_name is null;
comment on column public.audit_events.actor_name is 'Server-captured author name; legacy rows resolved from current profiles. Existing RLS unchanged.';
