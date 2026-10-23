begin;
alter table private.account_security add column account_type text not null default 'guest' check(account_type in ('user','guest'));
-- Preserve existing accounts; new board invitees and public signups start as guests.
update private.account_security set account_type='user';
alter table private.user_access_events drop constraint user_access_events_action_check;
alter table private.user_access_events add constraint user_access_events_action_check check(action in ('created','blocked','released','role_admin','role_user','role_guest','platform_invited'));
create or replace function private.account_status() returns jsonb language sql security definer set search_path='' as $$select jsonb_build_object('user_id',auth.uid(),'must_change_password',coalesce(s.must_change_password,true),'is_blocked',coalesce(s.is_blocked,true),'is_admin',coalesce(s.is_admin,false),'profile_role',case when s.is_admin then 'admin' else coalesce(s.account_type,'guest') end) from (select 1) x left join private.account_security s on s.user_id=auth.uid()$$;
create or replace function private.create_workspace(workspace_name text,workspace_id uuid default null) returns uuid language plpgsql security definer set search_path='' as $$
declare w uuid;
begin
 if not private.ready() or not exists(select 1 from private.account_security where user_id=auth.uid() and (is_admin or account_type='user')) then raise insufficient_privilege using message='Perfil Usuário ou Admin necessário para criar workspace'; end if;
 insert into public.workspaces(id,name,owner_id) values(coalesce(workspace_id,gen_random_uuid()),workspace_name,auth.uid()) returning id into w;
 insert into public.workspace_members(workspace_id,user_id,role,must_change_password,invited_by) values(w,auth.uid(),'owner',false,auth.uid());
 return w;
end $$;
create or replace function private.manage_users(actor uuid,operation text,target uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; is_target_admin boolean;
begin
 perform pg_advisory_xact_lock(674230108);
 if not exists(select 1 from private.account_security where user_id=actor and is_admin and not is_blocked and not must_change_password) then raise insufficient_privilege using message='Administrador ativo necessário'; end if;
 if operation='authorize' then return 'true'::jsonb; end if;
 if operation='list' then
 select coalesce(jsonb_agg(row_data order by row_data->>'email'),'[]'::jsonb) into result from (select jsonb_build_object('id',u.id,'email',u.email,'name',p.full_name,'is_admin',s.is_admin,'profile_role',case when s.is_admin then 'admin' else s.account_type end,'is_blocked',s.is_blocked,'must_change_password',s.must_change_password,'last_sign_in_at',u.last_sign_in_at) row_data from private.account_security s join auth.users u on u.id=s.user_id join public.profiles p on p.id=u.id) q;
 return result;
 end if;
 if operation not in ('block','release','created','role_admin','role_user','role_guest','platform_invited') or target is null then raise exception 'Operação inválida'; end if;
 select is_admin into is_target_admin from private.account_security where user_id=target for update;
 if not found then raise exception 'Usuário não encontrado'; end if;
 if operation='block' and (target=actor or is_target_admin) then raise exception 'Administradores protegidos não podem ser bloqueados'; end if;
 if operation like 'role_%' then
 if target=actor then raise exception 'Peça a outro administrador para alterar seu próprio perfil'; end if;
 if is_target_admin and operation<>'role_admin' and (select count(*) from private.account_security where is_admin and not is_blocked)<2 then raise exception 'Mantenha pelo menos um administrador'; end if;
 if operation='role_guest' and exists(select 1 from public.workspaces where owner_id=target) then raise exception 'O proprietário precisa manter o perfil Usuário ou Admin'; end if;
 update private.account_security set is_admin=(operation='role_admin'),account_type=case when operation='role_guest' then 'guest' else 'user' end,updated_at=now() where user_id=target;
 end if;
 if operation in ('block','release') then update private.account_security set is_blocked=(operation='block'),updated_at=now() where user_id=target; end if;
 insert into private.user_access_events(actor_id,user_id,action) values(actor,target,case operation when 'block' then 'blocked' when 'release' then 'released' else operation end);
 return jsonb_build_object('ok',true);
end $$;
-- Mail retries reuse the same encrypted initial password and delivery ID.
create table private.platform_invites(id uuid primary key default gen_random_uuid(),email text not null unique,invited_by uuid not null references auth.users(id),user_id uuid references auth.users(id),secret_id uuid references vault.secrets(id),lease_until timestamptz,lease_token uuid,sent_at timestamptz,created_at timestamptz not null default now());
alter table private.platform_invites enable row level security;
create policy no_client_access on private.platform_invites for all to anon,authenticated using(false) with check(false);
revoke all on private.platform_invites from public,anon,authenticated;
create index platform_invites_inviter_idx on private.platform_invites(invited_by);
create index platform_invites_user_idx on private.platform_invites(user_id);
create index platform_invites_secret_idx on private.platform_invites(secret_id);
create function private.platform_invite(actor uuid,email_address text,initial_secret text,invitation uuid default null,lease uuid default null,invitee uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare r private.platform_invites; sid uuid;
begin
 perform private.manage_users(actor,'authorize');
 if invitation is not null then
 select * into r from private.platform_invites where id=invitation and lease_token=lease and sent_at is null for update;
 if not found then raise exception 'Entrega indisponível'; end if;
 update private.platform_invites set user_id=invitee,sent_at=now(),secret_id=null,lease_token=null,lease_until=null where id=r.id;
 if r.secret_id is not null then delete from vault.secrets where id=r.secret_id; end if;
 perform private.manage_users(actor,'platform_invited',invitee);
 return jsonb_build_object('ok',true);
 end if;
 if length(initial_secret)>256 or email_address is null or length(email_address)>254 or position('@' in email_address)<2 then raise exception 'E-mail inválido'; end if;
 perform pg_advisory_xact_lock(hashtextextended(lower(btrim(email_address)),67423));
 select * into r from private.platform_invites where email=lower(btrim(email_address)) for update;
 if found then
 if r.sent_at is not null then return jsonb_build_object('already_sent',true); end if;
 if r.lease_until>now() then raise exception 'Convite em processamento; tente novamente em um minuto'; end if;
 update private.platform_invites set lease_token=gen_random_uuid(),lease_until=now()+interval '60 seconds' where id=r.id returning * into r;
 else
 sid:=vault.create_secret(initial_secret,'worksh_platform_invite_'||gen_random_uuid()::text);
 insert into private.platform_invites(email,invited_by,secret_id,lease_token,lease_until) values(lower(btrim(email_address)),actor,sid,gen_random_uuid(),now()+interval '60 seconds') returning * into r;
 end if;
 return to_jsonb(r)-'email';
end $$;
revoke all on function private.platform_invite(uuid,text,text,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function private.platform_invite(uuid,text,text,uuid,uuid,uuid) to service_role;
create function public.backend_platform_invite(actor uuid,email_address text,initial_secret text,invitation uuid default null,lease uuid default null,invitee uuid default null) returns jsonb language sql security invoker set search_path='' as $$select private.platform_invite(actor,email_address,initial_secret,invitation,lease,invitee)$$;
revoke all on function public.backend_platform_invite(uuid,text,text,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.backend_platform_invite(uuid,text,text,uuid,uuid,uuid) to service_role;
commit;
