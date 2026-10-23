begin;
alter table private.account_security add column is_blocked boolean not null default false, add column is_admin boolean not null default false;
create table private.user_access_events(id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users(id), user_id uuid not null references auth.users(id), action text not null check(action in ('created','blocked','released')), created_at timestamptz not null default now());
alter table private.user_access_events enable row level security;
create index user_access_events_actor_idx on private.user_access_events(actor_id);
create index user_access_events_user_time_idx on private.user_access_events(user_id,created_at desc);
revoke all on private.user_access_events from public,anon,authenticated;
create or replace function private.ready() returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and exists(select 1 from private.account_security where user_id=auth.uid() and not must_change_password and not is_blocked)$$;
create or replace function private.account_status() returns jsonb language sql security definer set search_path='' as $$select jsonb_build_object('user_id',auth.uid(),'must_change_password',coalesce(s.must_change_password,true),'is_blocked',coalesce(s.is_blocked,true),'is_admin',coalesce(s.is_admin,false)) from (select 1) x left join private.account_security s on s.user_id=auth.uid()$$;
create function private.manage_users(actor uuid, operation text, target uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if not exists(select 1 from private.account_security where user_id=actor and is_admin and not is_blocked and not must_change_password) then raise insufficient_privilege using message='Administrador ativo necessário'; end if;
 if operation='authorize' then return 'true'::jsonb; end if;
 if operation='list' then
 select coalesce(jsonb_agg(row_data order by row_data->>'email'),'[]'::jsonb) into result from (select jsonb_build_object('id',u.id,'email',u.email,'name',p.full_name,'is_admin',s.is_admin,'is_blocked',s.is_blocked,'must_change_password',s.must_change_password,'last_sign_in_at',u.last_sign_in_at) row_data from private.account_security s join auth.users u on u.id=s.user_id join public.profiles p on p.id=u.id) q;
 return result;
 end if;
 if operation not in ('block','release','created') or target is null then raise exception 'Operação inválida'; end if;
 if operation='block' and (target=actor or exists(select 1 from private.account_security where user_id=target and is_admin)) then raise exception 'Administradores não podem ser bloqueados por este painel'; end if;
 if operation in ('block','release') then update private.account_security set is_blocked=(operation='block'),updated_at=now() where user_id=target; if not found then raise exception 'Usuário não encontrado'; end if; end if;
 insert into private.user_access_events(actor_id,user_id,action) values(actor,target,case operation when 'block' then 'blocked' when 'release' then 'released' else 'created' end);
 return jsonb_build_object('ok',true);
end $$;
revoke all on function private.manage_users(uuid,text,uuid) from public,anon,authenticated;
grant execute on function private.manage_users(uuid,text,uuid) to service_role;
create function public.backend_manage_users(actor uuid,operation text,target uuid default null) returns jsonb language sql security invoker set search_path='' as $$select private.manage_users(actor,operation,target)$$;
revoke all on function public.backend_manage_users(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.backend_manage_users(uuid,text,uuid) to service_role;
commit;
