begin;
create extension if not exists pgmq;
select pgmq.create('email_invites');
select pgmq.create('drive_uploads');
select pgmq.create('background_tasks');
revoke all on schema pgmq from public,anon,authenticated;
alter table public.invitations add column invitee_id uuid references auth.users(id) on delete restrict;
alter table public.invitations add column delivery_secret_id uuid references vault.secrets(id) on delete restrict;
alter table public.invitations add column delivered_at timestamptz;
create index invitations_invitee_idx on public.invitations(invitee_id);
create index invitations_delivery_idx on public.invitations(delivery_secret_id);
alter table public.upload_jobs add column lease_until timestamptz;
alter table public.upload_jobs add column lease_token uuid;
alter table public.upload_jobs add column task_id uuid;
alter table public.upload_jobs add constraint upload_task_fk foreign key(board_id,task_id) references public.tasks(board_id,id) on delete set null(task_id);
create index upload_jobs_task_idx on public.upload_jobs(task_id);

create function public.account_status() returns jsonb language sql security definer set search_path='' as $$
 select jsonb_build_object('must_change_password',coalesce((select must_change_password from private.account_security where user_id=auth.uid()),true),'user_id',auth.uid())
$$;
create function public.complete_password_change(actor uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 -- Service-only: Edge must first verify the user's JWT and successfully update Auth password.
 if actor is null then raise exception 'Missing actor'; end if;
 update private.account_security set must_change_password=false,updated_at=now() where user_id=actor;
 update public.workspace_members set must_change_password=false where user_id=actor;
end $$;

create function public.create_workspace(workspace_name text) returns uuid language plpgsql security definer set search_path='' as $$
declare w uuid;
begin
 if not private.ready() then raise exception 'Password change required' using errcode='42501'; end if;
 insert into public.workspaces(name,owner_id) values(workspace_name,auth.uid()) returning id into w;
 insert into public.workspace_members(workspace_id,user_id,role,must_change_password,invited_by) values(w,auth.uid(),'owner',false,auth.uid());
 return w;
end $$;
create function public.grant_board_access(board_id uuid,user_id uuid,can_edit boolean default true) returns void language plpgsql security definer set search_path='' as $$
declare w uuid;
begin
 if not private.owns_board(board_id) then raise exception 'Owner required' using errcode='42501'; end if;
 select workspace_id into w from public.boards where id=board_id;
 if not exists(select 1 from public.workspace_members m where m.workspace_id=w and m.user_id=grant_board_access.user_id) then raise exception 'Member must accept invitation first'; end if;
 insert into public.board_members(workspace_id,board_id,user_id,can_edit,granted_by) values(w,board_id,user_id,can_edit,auth.uid())
 on conflict on constraint board_members_board_id_user_id_key do update set can_edit=excluded.can_edit;
end $$;
create function public.revoke_board_access(board_id uuid,user_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.owns_board(board_id) then raise exception 'Owner required' using errcode='42501'; end if;
 delete from public.board_members m where m.board_id=revoke_board_access.board_id and m.user_id=revoke_board_access.user_id;
end $$;

create function public.enqueue(queue text,payload jsonb) returns bigint language plpgsql security definer set search_path='' as $$
begin
 if queue not in ('email_invites','drive_uploads','background_tasks') or octet_length(payload::text)>4096 then raise exception 'Invalid queue payload'; end if;
 return pgmq.send(queue,payload);
end $$;
create function public.dequeue(queue text,qty integer default 10,vt integer default 60) returns jsonb language plpgsql security definer set search_path='' as $$
declare r jsonb;
begin
 if queue not in ('email_invites','drive_uploads','background_tasks') or qty not between 1 and 10 or vt<>60 then raise exception 'Invalid queue request'; end if;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]') into r from pgmq.read(queue,vt,qty) x;
 return r;
end $$;
create function public.ack(queue text,msg_id bigint) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if queue not in ('email_invites','drive_uploads','background_tasks') then raise exception 'Invalid queue'; end if;
 return pgmq.delete(queue,msg_id);
end $$;
create function public.fail(queue text,msg_id bigint) returns void language plpgsql security definer set search_path='' as $$
declare n integer; p jsonb;
begin
 if queue not in ('email_invites','drive_uploads','background_tasks') then raise exception 'Invalid queue'; end if;
 execute format('select read_ct,message from pgmq.%I where msg_id=$1','q_'||queue) into n,p using msg_id;
 if n>=5 then
  perform pgmq.archive(queue,msg_id);
  if queue='drive_uploads' then update public.upload_jobs set status='dead',last_error='Retry limit reached',attempts=n where id=(p->>'upload_job_id')::uuid and status<>'done'; end if;
 else perform pgmq.set_vt(queue,msg_id,least(900,60*power(2,coalesce(n,1))::integer)); end if;
end $$;

create function public.invite_to_board(board_id uuid,email text) returns uuid language plpgsql security definer set search_path='' as $$
declare w uuid; iid uuid; token text; sid uuid; e text;
begin
 if not private.owns_board(board_id) then raise exception 'Owner required' using errcode='42501'; end if;
 e=lower(btrim(email));
 if e !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Invalid email'; end if;
 select workspace_id into w from public.boards where id=board_id;
 perform pg_advisory_xact_lock(hashtextextended(board_id::text||e,0));
 select id into iid from public.invitations i where i.board_id=invite_to_board.board_id and i.email=e and i.accepted_at is null and i.revoked_at is null and i.expires_at>now();
 if iid is not null then return iid; end if;
 if (select count(*) from public.invitations where invited_by=auth.uid() and created_at>now()-interval '1 hour')>=30 then raise exception 'Invitation limit reached'; end if;
 token=encode(extensions.gen_random_bytes(32),'hex');
 sid=vault.create_secret(jsonb_build_object('token',token)::text);
 insert into public.invitations(token_hash,email,workspace_id,board_id,invited_by,expires_at,delivery_secret_id)
 values(encode(extensions.digest(token,'sha256'),'hex'),e,w,board_id,auth.uid(),now()+interval '48 hours',sid) returning id into iid;
 perform public.enqueue('email_invites',jsonb_build_object('invitation_id',iid));
 return iid;
end $$;

create function public.accept_invitation(token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.invitations; e text;
begin
 if not private.ready() then raise exception 'Password change required' using errcode='42501'; end if;
 select email into e from auth.users where id=auth.uid() and email_confirmed_at is not null;
 select * into i from public.invitations where token_hash=encode(extensions.digest(token,'sha256'),'hex') for update;
 if i.id is null or i.email<>lower(coalesce(e,'')) or i.revoked_at is not null or i.expires_at<=now() then raise exception 'Invalid invitation' using errcode='42501'; end if;
 if i.accepted_at is not null then return jsonb_build_object('workspace_id',i.workspace_id,'board_id',i.board_id); end if;
 if not exists(select 1 from public.workspaces where id=i.workspace_id and owner_id=i.invited_by) then raise exception 'Invitation no longer authorized'; end if;
 insert into public.workspace_members(workspace_id,user_id,role,must_change_password,invited_by) values(i.workspace_id,auth.uid(),'member',false,i.invited_by) on conflict(workspace_id,user_id) do nothing;
 if i.board_id is not null then
 insert into public.board_members(workspace_id,board_id,user_id,granted_by) values(i.workspace_id,i.board_id,auth.uid(),i.invited_by) on conflict(board_id,user_id) do nothing;
 end if;
 update public.invitations set accepted_at=now(),invitee_id=auth.uid() where id=i.id;
 return jsonb_build_object('workspace_id',i.workspace_id,'board_id',i.board_id);
end $$;

create function public.enfileirar_upload(storage_path text,file_name text,mime text,size_bytes bigint,board_id uuid,task_id uuid default null) returns uuid language plpgsql security definer set search_path='' as $$
declare w uuid; o uuid; j uuid;
begin
 if not private.is_board_editor(board_id) then raise exception 'Editor required' using errcode='42501'; end if;
 if size_bytes not between 1 and 5242880 or mime not in ('application/pdf','image/png','image/jpeg','image/webp','text/plain','text/csv','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') then raise exception 'Invalid file'; end if;
 if split_part(storage_path,'/',1)<>auth.uid()::text or split_part(storage_path,'/',2)<>board_id::text then raise exception 'Invalid path' using errcode='42501'; end if;
 if not exists(select 1 from storage.objects s where s.bucket_id='uploads-temp' and s.name=storage_path and s.owner_id=auth.uid()::text and (s.metadata->>'size')::bigint=size_bytes) then raise exception 'Stored file not found or invalid size'; end if;
 select b.workspace_id,wk.owner_id into w,o from public.boards b join public.workspaces wk on wk.id=b.workspace_id where b.id=board_id and wk.drive_secret_id is not null;
 if w is null then raise exception 'Owner must connect Google Drive'; end if;
 insert into public.upload_jobs(workspace_id,owner_id,board_id,user_id,storage_path,file_name,mime,size_bytes,task_id)
 values(w,o,board_id,auth.uid(),storage_path,file_name,mime,size_bytes,task_id) on conflict(storage_path) do nothing returning id into j;
 if j is null then select id into j from public.upload_jobs u where u.storage_path=enfileirar_upload.storage_path and u.user_id=auth.uid(); return j; end if;
 perform public.enqueue('drive_uploads',jsonb_build_object('upload_job_id',j)); return j;
end $$;

create function public.backend_secret(secret_id uuid) returns text language sql security definer set search_path='' as $$
 select decrypted_secret from vault.decrypted_secrets where id=secret_id
$$;
create function public.backend_store_secret(secret_text text,secret_id uuid default null) returns uuid language plpgsql security definer set search_path='' as $$
begin
 if secret_id is null then return vault.create_secret(secret_text); end if;
 perform vault.update_secret(secret_id,secret_text); return secret_id;
end $$;
create function public.backend_find_user(email_address text) returns uuid language sql security definer set search_path='' as $$
 select id from auth.users where lower(email)=lower(btrim(email_address)) limit 1
$$;
create function public.backend_access(actor uuid,board uuid default null,workspace uuid default null,owner_only boolean default false) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if actor is null then return false; end if;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 if board is not null then return case when owner_only then private.owns_board(board) else private.is_board_editor(board) end; end if;
 return private.is_workspace_owner(workspace);
end $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('uploads-temp','uploads-temp',false,5242880,array['application/pdf','image/png','image/jpeg','image/webp','text/plain','text/csv','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']);
create policy worksh_temp_insert on storage.objects for insert to authenticated with check(bucket_id='uploads-temp' and (storage.foldername(name))[1]=(select auth.uid())::text and private.is_board_editor(((storage.foldername(name))[2])::uuid));
-- No client overwrite/delete: prevents replacing a file after a job has been authorized.
create policy worksh_temp_read on storage.objects for select to authenticated using(bucket_id='uploads-temp' and owner_id=(select auth.uid())::text and private.is_board_member(((storage.foldername(name))[2])::uuid));

revoke all on function public.account_status(),public.create_workspace(text),public.grant_board_access(uuid,uuid,boolean),public.revoke_board_access(uuid,uuid),public.invite_to_board(uuid,text),public.accept_invitation(text),public.enfileirar_upload(text,text,text,bigint,uuid,uuid) from public,anon;
grant execute on function public.account_status(),public.create_workspace(text),public.grant_board_access(uuid,uuid,boolean),public.revoke_board_access(uuid,uuid),public.invite_to_board(uuid,text),public.accept_invitation(text),public.enfileirar_upload(text,text,text,bigint,uuid,uuid) to authenticated;
revoke all on function public.complete_password_change(uuid),public.enqueue(text,jsonb),public.dequeue(text,integer,integer),public.ack(text,bigint),public.fail(text,bigint),public.backend_secret(uuid),public.backend_store_secret(text,uuid),public.backend_find_user(text),public.backend_access(uuid,uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.complete_password_change(uuid),public.enqueue(text,jsonb),public.dequeue(text,integer,integer),public.ack(text,bigint),public.fail(text,bigint),public.backend_secret(uuid),public.backend_store_secret(text,uuid),public.backend_find_user(text),public.backend_access(uuid,uuid,uuid,boolean) to service_role;
commit;
