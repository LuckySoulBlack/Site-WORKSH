begin;
alter table public.profiles add column phone text not null default '';
alter table public.profiles add column job text not null default '';
alter table public.profiles add column theme text not null default 'system' check(theme in ('light','dark','system'));
grant update(phone,job,theme) on public.profiles to authenticated;
alter table public.workspaces add column description text not null default '';
alter table public.workspaces add column modules text[] not null default array['kanban','calendar','people','reports','activity'];
alter table public.workspaces add column company jsonb not null default '{}'::jsonb check(octet_length(company::text)<=8192);
grant select(description,modules,company),update(description,modules,company) on public.workspaces to authenticated;
alter table public.tasks add column due date;
alter table public.tasks add column priority text not null default 'normal' check(priority in ('low','normal','high','urgent'));
alter table public.tasks add column checklist jsonb not null default '[]'::jsonb check(jsonb_typeof(checklist)='array' and octet_length(checklist::text)<=16384);
alter table public.tasks add column assignee_id uuid references auth.users(id) on delete set null;
create index tasks_assignee_idx on public.tasks(assignee_id);
grant insert(due,priority,checklist,assignee_id),update(due,priority,checklist,assignee_id) on public.tasks to authenticated;
create function private.validate_assignee() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.assignee_id is not null and not exists(select 1 from public.boards b join public.workspaces w on w.id=b.workspace_id where b.id=new.board_id and
 (w.owner_id=new.assignee_id or exists(select 1 from public.board_members m where m.board_id=b.id and m.user_id=new.assignee_id))) then raise exception 'Assignee must have board access'; end if;
 return new;
end $$;
revoke all on function private.validate_assignee() from public,anon,authenticated;
create trigger validate_assignee before insert or update of assignee_id on public.tasks for each row execute function private.validate_assignee();

drop function public.create_workspace(text);
create function public.create_workspace(workspace_name text,workspace_id uuid default null) returns uuid language plpgsql security definer set search_path='' as $$
declare w uuid;
begin
 if not private.ready() then raise exception 'Password change required' using errcode='42501'; end if;
 insert into public.workspaces(id,name,owner_id) values(coalesce(workspace_id,gen_random_uuid()),workspace_name,auth.uid()) returning id into w;
 insert into public.workspace_members(workspace_id,user_id,role,must_change_password,invited_by) values(w,auth.uid(),'owner',false,auth.uid());
 return w;
end $$;
revoke all on function public.create_workspace(text,uuid) from public,anon;
grant execute on function public.create_workspace(text,uuid) to authenticated;

-- Private metadata lookup: names only; membership remains the authorization source.
create or replace function public.shared_profiles(b uuid) returns table(id uuid,full_name text) language sql stable security definer set search_path='' as $$
 select p.id,p.full_name from public.profiles p where private.is_board_member(b) and
 (p.id in(select user_id from public.board_members where board_id=b) or p.id in(select w.owner_id from public.workspaces w join public.boards x on x.workspace_id=w.id where x.id=b))
$$;
commit;
