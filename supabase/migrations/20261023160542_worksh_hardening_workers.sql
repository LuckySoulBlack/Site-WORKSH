begin;
revoke execute on function public.rls_auto_enable() from public,anon,authenticated;
-- Explicit deny is deliberate: these tables are only used by privileged backend routines.
create policy backend_only on private.account_security for all to authenticated using(false) with check(false);
create policy backend_only on public.oauth_states for all to authenticated using(false) with check(false);

-- Remove PL/pgSQL ambiguity between API parameter names and column names.
do $$ declare f record; d text; begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where n.nspname='public' and l.lanname='plpgsql' and p.proname in ('create_workspace','grant_board_access','revoke_board_access','invite_to_board','accept_invitation','enfileirar_upload','enqueue','dequeue','ack','fail') loop
 d=pg_get_functiondef(f.oid); d=replace(d,'AS $function$','AS $function$'||chr(10)||'#variable_conflict use_variable'); execute d;
 end loop;
end $$;
alter table public.invitations add column lease_until timestamptz;
alter table public.invitations add column lease_token uuid;
alter table public.invitations add column attempts integer not null default 0;
alter table public.invitations add column last_error text;
create index invitations_pending_idx on public.invitations(created_at) where delivered_at is null and revoked_at is null;
grant select(delivered_at,attempts,last_error) on public.invitations to authenticated;
grant select(must_change_password) on private.account_security to service_role;

create function public.backend_claim_invite(invitation uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.invitations;
begin
 update public.invitations set lease_until=now()+interval '60 seconds',lease_token=gen_random_uuid(),attempts=attempts+1
 where id=invitation and delivered_at is null and revoked_at is null and expires_at>now() and attempts<5
 and (lease_until is null or lease_until<now()) returning * into i;
 if i.id is null then return null; end if;
 if not public.backend_access(i.invited_by,null,i.workspace_id,true) then
 update public.invitations set revoked_at=now(),last_error='Owner authorization revoked' where id=i.id; return null; end if;
 return to_jsonb(i);
end $$;
create function public.backend_finish_invite(invitation uuid,lease uuid,invitee uuid) returns void language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
 select delivery_secret_id into sid from public.invitations where id=invitation and lease_token=lease for update;
 update public.invitations set delivered_at=now(),invitee_id=invitee,delivery_secret_id=null,lease_until=null
 where id=invitation and lease_token=lease;
 if found and sid is not null then delete from vault.secrets where id=sid; end if;
end $$;
create function public.backend_claim_upload(job uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.upload_jobs;
begin
 update public.upload_jobs set status='uploading',lease_until=now()+interval '60 seconds',lease_token=gen_random_uuid(),attempts=attempts+1
 where id=job and status in ('pending','failed','uploading') and attempts<5
 and (lease_until is null or lease_until<now()) returning * into j;
 if j.id is null then return null; end if;
 if not public.backend_access(j.user_id,j.board_id,null,false) or not exists(select 1 from public.workspaces where id=j.workspace_id and owner_id=j.owner_id) then
 update public.upload_jobs set status='dead',last_error='Authorization revoked' where id=job; return null; end if;
 return to_jsonb(j);
end $$;
create function public.backend_finish_upload(job uuid,lease uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare j public.upload_jobs; a uuid;
begin
 select * into j from public.upload_jobs where id=job and lease_token=lease and status='uploading' for update;
 if j.id is null or j.drive_file_id is null then raise exception 'Lease lost'; end if;
 if not public.backend_access(j.user_id,j.board_id,null,false) then raise exception 'Authorization revoked'; end if;
 perform set_config('request.jwt.claim.sub',j.user_id::text,true);
 insert into public.attachments(board_id,task_id,file_name,mime,size_bytes,drive_file_id,uploaded_by)
 values(j.board_id,j.task_id,j.file_name,j.mime,j.size_bytes,j.drive_file_id,j.user_id)
 on conflict(drive_file_id) do update set file_name=excluded.file_name returning id into a;
 update public.upload_jobs set status='done',lease_until=null,last_error=null where id=job;
 return a;
end $$;
create function public.backend_renew(queue text,message_id bigint,job uuid,lease uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare n integer;
begin
 if queue='drive_uploads' then update public.upload_jobs set lease_until=now()+interval '60 seconds' where id=job and lease_token=lease and status='uploading';
 elsif queue='email_invites' then update public.invitations set lease_until=now()+interval '60 seconds' where id=job and lease_token=lease and delivered_at is null;
 else return false; end if;
 get diagnostics n=row_count;
 if n=0 then return false; end if;
 perform pgmq.set_vt(queue,message_id,60); return true;
end $$;
create function public.backend_oauth_state(actor uuid,workspace uuid,state_hash text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.backend_access(actor,null,workspace,true) then raise exception 'Owner required'; end if;
 insert into public.oauth_states(user_id,workspace_id,state_hash,expires_at) values(actor,workspace,state_hash,now()+interval '10 minutes');
end $$;
create function public.backend_consume_state(hash text) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.oauth_states;
begin
 update public.oauth_states set used_at=now() where state_hash=hash and used_at is null and expires_at>now() returning * into s;
 if s.id is null or not public.backend_access(s.user_id,null,s.workspace_id,true) then raise exception 'Invalid OAuth state'; end if;
 return to_jsonb(s);
end $$;
create function public.backend_connect_drive(actor uuid,workspace uuid,refresh_token text) returns void language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
 if not public.backend_access(actor,null,workspace,true) then raise exception 'Owner required'; end if;
 select drive_secret_id into sid from public.workspaces where id=workspace for update;
 if refresh_token<>'' then sid=public.backend_store_secret(refresh_token,sid); end if;
 if sid is null then raise exception 'Google did not return a refresh token; reconnect with consent'; end if;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 update public.workspaces set drive_secret_id=sid where id=workspace;
 perform public.enqueue('background_tasks',jsonb_build_object('type','drive_folder','workspace_id',workspace,'actor_id',actor));
end $$;
create function public.shared_profiles(b uuid) returns table(id uuid,full_name text) language sql stable security definer set search_path='' as $$
 select p.id,p.full_name from public.profiles p where private.is_board_member(b) and
 (p.id in(select user_id from public.board_members where board_id=b) or p.id in(select w.owner_id from public.workspaces w join public.boards x on x.workspace_id=w.id where x.id=b))
$$;
create function public.backend_worker_authorized(provided text) returns boolean language sql security definer set search_path='' as $$
 select length(provided)>=32 and exists(select 1 from vault.decrypted_secrets where name='worksh_worker_secret' and extensions.digest(decrypted_secret,'sha256')=extensions.digest(provided,'sha256'))
$$;
select vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'worksh_worker_secret','WORKSH internal scheduler authentication');
revoke all on function public.shared_profiles(uuid) from public,anon;
grant execute on function public.shared_profiles(uuid) to authenticated;
do $$ declare f record; begin
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'backend_%' loop
 execute format('revoke all on function %s from public,anon,authenticated',f.sig);
 execute format('grant execute on function %s to service_role',f.sig);
 end loop;
end $$;
commit;
