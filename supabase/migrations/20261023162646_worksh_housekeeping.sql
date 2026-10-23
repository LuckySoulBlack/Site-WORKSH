begin;
alter table public.profiles add constraint profile_lengths check(length(full_name)<=200 and length(phone)<=50 and length(job)<=200);
alter table public.workspaces add constraint workspace_description_length check(length(description)<=5000);
alter table public.workspaces add constraint workspace_modules_valid check(modules<@array['kanban','calendar','people','reports','activity']::text[]);
alter table public.boards add constraint board_description_length check(length(description)<=5000);
alter table public.tasks add constraint task_description_length check(length(description)<=10000);
alter table public.tasks add constraint task_link_valid check(link_url is null or (length(link_url)<=2048 and link_url~*'^https?://'));

-- Daily credential hygiene is independent of integration activation.
create function private.cleanup_security() returns void language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
 for sid in select delivery_secret_id from public.invitations where delivery_secret_id is not null and (expires_at<now() or revoked_at is not null) for update loop
 update public.invitations set delivery_secret_id=null where delivery_secret_id=sid;
 delete from vault.secrets where id=sid;
 end loop;
 delete from public.oauth_states where expires_at<now()-interval '1 day';
 delete from cron.job_run_details where end_time<now()-interval '7 days';
end $$;
revoke all on function private.cleanup_security() from public,anon,authenticated;
select cron.schedule('worksh-security-cleanup','23 3 * * *','select private.cleanup_security()');

-- Public API never needs pg_net execution. Extension objects live in net,
-- although pg_net itself is not relocatable; the advisor's namespace warning is documented.
revoke usage on schema net from public,anon,authenticated;
revoke execute on all functions in schema net from public,anon,authenticated;
create function public.backend_delete_attachment(actor uuid,attachment uuid) returns void language plpgsql security definer set search_path='' as $$
declare b uuid;
begin
 select board_id into b from public.attachments where id=attachment;
 if b is null then return; end if;
 if not public.backend_access(actor,b,null,true) then raise exception 'Owner required'; end if;
 perform set_config('request.jwt.claim.sub',actor::text,true);
 delete from public.attachments where id=attachment;
end $$;
revoke all on function public.backend_delete_attachment(uuid,uuid) from public,anon,authenticated;
grant execute on function public.backend_delete_attachment(uuid,uuid) to service_role;
create function private.protect_file_container() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if (tg_table_name='boards' and (exists(select 1 from public.attachments where board_id=old.id) or exists(select 1 from public.upload_jobs where board_id=old.id and status in ('pending','uploading','failed'))))
 or (tg_table_name='workspaces' and (exists(select 1 from public.attachments a join public.boards b on b.id=a.board_id where b.workspace_id=old.id) or exists(select 1 from public.upload_jobs where workspace_id=old.id and status in ('pending','uploading','failed')))) then
 raise exception 'Remova os anexos e conclua os uploads antes de excluir este ambiente ou painel.';
 end if;
 return old;
end $$;
revoke all on function private.protect_file_container() from public,anon,authenticated;
create trigger protect_files before delete on public.boards for each row execute function private.protect_file_container();
create trigger protect_files before delete on public.workspaces for each row execute function private.protect_file_container();
create function public.workspace_counts(w uuid) returns jsonb language sql stable security invoker set search_path='' as $$
 with visible as (select t.* from public.tasks t join public.boards b on b.id=t.board_id where b.workspace_id=w),
 people as(select coalesce(assignee_id::text,'') person,count(*) n from visible group by assignee_id)
 select jsonb_build_object('total',count(*),'progress',count(*) filter(where status='progress'),'done',count(*) filter(where status='done'),
 'overdue',count(*) filter(where due<current_date and status<>'done'),'todo',count(*) filter(where status='todo'),'blocked',count(*) filter(where status='blocked'),
 'people',(select coalesce(jsonb_object_agg(person,n),'{}') from people)) from visible
$$;
revoke all on function public.workspace_counts(uuid) from public,anon;
grant execute on function public.workspace_counts(uuid) to authenticated;
commit;
