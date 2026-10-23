begin;
-- Existing workspaces are preserved; only new workspaces require a connected owner.
create table private.drive_connections(
 id uuid primary key default gen_random_uuid(),user_id uuid not null unique references auth.users(id) on delete cascade,
 google_subject text not null,email text not null,refresh_secret_id uuid not null references vault.secrets(id),
 root_folder_id text not null check(length(root_folder_id) between 1 and 200),
 status text not null default 'pending' check(status in ('pending','connected','reconnect_required')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table private.drive_connections enable row level security;
create policy no_client_access on private.drive_connections for all to anon,authenticated using(false) with check(false);
revoke all on private.drive_connections from public,anon,authenticated;
create index drive_connections_secret_idx on private.drive_connections(refresh_secret_id);
create table private.drive_board_folders(
 id uuid primary key default gen_random_uuid(),board_id uuid not null unique,workspace_id uuid not null,
 owner_id uuid not null references auth.users(id),drive_folder_id text not null unique,
 foreign key(workspace_id,board_id) references public.boards(workspace_id,id) on delete cascade);
alter table private.drive_board_folders enable row level security;
create policy no_client_access on private.drive_board_folders for all to anon,authenticated using(false) with check(false);
revoke all on private.drive_board_folders from public,anon,authenticated;
create index drive_board_folders_workspace_idx on private.drive_board_folders(workspace_id,board_id);
create index drive_board_folders_owner_idx on private.drive_board_folders(owner_id);
create table private.drive_connection_events(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),actor_id uuid references auth.users(id),status text not null,created_at timestamptz not null default now());
alter table private.drive_connection_events enable row level security;
create policy no_client_access on private.drive_connection_events for all to anon,authenticated using(false) with check(false);
revoke all on private.drive_connection_events from public,anon,authenticated;
create index drive_connection_events_user_time_idx on private.drive_connection_events(user_id,created_at desc);
create index drive_connection_events_actor_idx on private.drive_connection_events(actor_id);
create function private.audit_drive_connection() returns trigger language plpgsql security definer set search_path='' as $$begin insert into private.drive_connection_events(user_id,actor_id,status) values(new.user_id,coalesce(auth.uid(),new.user_id),new.status);return new;end $$;
revoke all on function private.audit_drive_connection() from public,anon,authenticated;
create trigger audit_drive_connection after insert or update on private.drive_connections for each row execute function private.audit_drive_connection();
-- OAuth starts before the first workspace exists.
alter table public.oauth_states alter column workspace_id drop not null;
create function private.owner_drive_status() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('connected',coalesce(d.status='connected',false),'status',coalesce(d.status,'not_connected'),'email',d.email)
 from (select 1) x left join private.drive_connections d on d.user_id=auth.uid()
$$;
revoke all on function private.owner_drive_status() from public,anon;
grant execute on function private.owner_drive_status() to authenticated;
create function public.owner_drive_status() returns jsonb language sql security invoker set search_path='' as $$select private.owner_drive_status()$$;
revoke all on function public.owner_drive_status() from public,anon;
grant execute on function public.owner_drive_status() to authenticated;
create or replace function private.account_status() returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_object('user_id',auth.uid(),'must_change_password',coalesce(s.must_change_password,true),'is_blocked',coalesce(s.is_blocked,true),'is_admin',coalesce(s.is_admin,false),'profile_role',case when s.is_admin then 'admin' else coalesce(s.account_type,'guest') end,'drive_connected',coalesce(d.status='connected',false),'drive_email',d.email,'drive_required',coalesce(s.is_admin or s.account_type='user',false) and coalesce(d.status<>'connected',true)) from (select 1) x left join private.account_security s on s.user_id=auth.uid() left join private.drive_connections d on d.user_id=auth.uid()
$$;
create function private.bind_workspace_drive() returns trigger language plpgsql security definer set search_path='' as $$
begin
 select refresh_secret_id into new.drive_secret_id from private.drive_connections where user_id=new.owner_id and status='connected';
 if new.drive_secret_id is null then raise insufficient_privilege using message='Conecte seu Google Drive antes de criar um workspace'; end if;
 return new;
end $$;
revoke all on function private.bind_workspace_drive() from public,anon,authenticated;
create trigger bind_workspace_drive before insert on public.workspaces for each row execute function private.bind_workspace_drive();
create function private.queue_workspace_folder() returns trigger language plpgsql security definer set search_path='' as $$begin perform public.enqueue('background_tasks',jsonb_build_object('type','drive_folder','workspace_id',new.id,'actor_id',new.owner_id));return new;end $$;
revoke all on function private.queue_workspace_folder() from public,anon,authenticated;
create trigger queue_workspace_folder after insert on public.workspaces for each row execute function private.queue_workspace_folder();
create or replace function public.backend_oauth_state(actor uuid,workspace uuid,state_hash text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from private.account_security where user_id=actor and not is_blocked and not must_change_password and (is_admin or account_type='user')) then raise insufficient_privilege; end if;
 if workspace is not null and not exists(select 1 from public.workspaces where id=workspace and owner_id=actor) then raise insufficient_privilege; end if;
 if length(state_hash)<>64 then raise exception 'Invalid state'; end if;
 insert into public.oauth_states(user_id,workspace_id,state_hash,expires_at) values(actor,workspace,state_hash,now()+interval '10 minutes');
end $$;
create or replace function public.backend_consume_state(hash text) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.oauth_states;
begin
 update public.oauth_states set used_at=now() where state_hash=hash and used_at is null and expires_at>now() returning * into s;
 if s.id is null or not exists(select 1 from private.account_security where user_id=s.user_id and not is_blocked and not must_change_password and (is_admin or account_type='user')) then raise exception 'Invalid OAuth state'; end if;
 return to_jsonb(s);
end $$;
revoke all on function public.backend_oauth_state(uuid,uuid,text),public.backend_consume_state(text) from public,anon,authenticated;
grant execute on function public.backend_oauth_state(uuid,uuid,text),public.backend_consume_state(text) to service_role;
-- Obsolete per-workspace connection cannot bypass the owner connection workflow.
create or replace function public.backend_connect_drive(actor uuid,workspace uuid,refresh_token text) returns void language plpgsql security definer set search_path='' as $$begin raise exception 'Use account-level Drive authorization';end $$;
revoke all on function public.backend_connect_drive(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.backend_connect_drive(uuid,uuid,text) to service_role;
create function private.owner_drive(actor uuid,operation text,payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare d private.drive_connections; sid uuid; item record; folder text; w uuid;
begin
 if not exists(select 1 from private.account_security where user_id=actor and not is_blocked and not must_change_password and (is_admin or account_type='user')) then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,58422));
 select * into d from private.drive_connections where user_id=actor for update;
 if operation='get' then
 if d.id is null then return 'null'::jsonb; end if;
 return to_jsonb(d);
 elsif operation='prepare' then
 if length(coalesce(payload->>'subject',''))<1 or length(coalesce(payload->>'email',''))<3 or length(coalesce(payload->>'root_id',''))<1 then raise exception 'Invalid identity'; end if;
 if d.id is not null and d.google_subject<>payload->>'subject' then raise exception 'Reconecte a mesma conta Google para preservar os arquivos'; end if;
 sid:=d.refresh_secret_id;
 if length(coalesce(payload->>'refresh_token',''))>0 then sid:=public.backend_store_secret(payload->>'refresh_token',sid); end if;
 if sid is null then raise exception 'Google did not return offline authorization'; end if;
 insert into private.drive_connections(user_id,google_subject,email,refresh_secret_id,root_folder_id) values(actor,payload->>'subject',payload->>'email',sid,payload->>'root_id')
 on conflict(user_id) do update set refresh_secret_id=excluded.refresh_secret_id,email=excluded.email,updated_at=now() returning * into d;
 return to_jsonb(d);
 elsif operation='finish' then
 if d.id is null or d.root_folder_id is distinct from (payload->>'root_id') then raise exception 'Invalid root'; end if;
 update private.drive_connections set status='connected',updated_at=now() where id=d.id;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 update public.workspaces set drive_secret_id=d.refresh_secret_id where owner_id=actor;
 for item in select id from public.workspaces where owner_id=actor loop
 perform public.enqueue('background_tasks',jsonb_build_object('type','drive_folder','workspace_id',item.id,'actor_id',actor));
 end loop;
 return jsonb_build_object('ok',true);
 elsif operation='invalidate' then
 update private.drive_connections set status='reconnect_required',updated_at=now() where user_id=actor;return jsonb_build_object('ok',true);
 elsif operation='containers' then
 return coalesce((select jsonb_agg(jsonb_build_object('id',id,'folder_id',drive_folder_id)) from public.workspaces where owner_id=actor and drive_folder_id is not null),'[]'::jsonb);
 elsif operation='board_folder' then
 select workspace_id into w from public.boards b where b.id=(payload->>'board_id')::uuid and exists(select 1 from public.workspaces x where x.id=b.workspace_id and x.owner_id=actor);
 if w is null or d.status<>'connected' or d.id is null then raise insufficient_privilege; end if;
 select drive_folder_id into folder from private.drive_board_folders where board_id=(payload->>'board_id')::uuid;
 if folder is not null or nullif(payload->>'folder_id','') is null then return jsonb_build_object('folder_id',folder);end if;
 insert into private.drive_board_folders(board_id,workspace_id,owner_id,drive_folder_id) values((payload->>'board_id')::uuid,w,actor,payload->>'folder_id') on conflict(board_id) do nothing;
 select drive_folder_id into folder from private.drive_board_folders where board_id=(payload->>'board_id')::uuid;
 return jsonb_build_object('folder_id',folder);
 end if;
 raise exception 'Invalid operation';
end $$;
revoke all on function private.owner_drive(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function private.owner_drive(uuid,text,jsonb) to service_role;
create function public.backend_owner_drive(actor uuid,operation text,payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select private.owner_drive(actor,operation,payload)$$;
revoke all on function public.backend_owner_drive(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.backend_owner_drive(uuid,text,jsonb) to service_role;
commit;
