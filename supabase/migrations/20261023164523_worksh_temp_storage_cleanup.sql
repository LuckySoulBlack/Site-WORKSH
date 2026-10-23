begin;
create function public.backend_expired_uploads() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(name),'[]') from (
 select s.name from storage.objects s left join public.upload_jobs j on j.storage_path=s.name
 where s.bucket_id='uploads-temp' and s.created_at<now()-interval '24 hours'
 and (j.id is null or j.status in ('done','dead')) order by s.created_at limit 100) x
$$;
revoke all on function public.backend_expired_uploads() from public,anon,authenticated;
grant execute on function public.backend_expired_uploads() to service_role;
create or replace function private.cleanup_security() returns void language plpgsql security definer set search_path='' as $$
declare sid uuid; q text;
begin
 for sid in select delivery_secret_id from public.invitations where delivery_secret_id is not null and (expires_at<now() or revoked_at is not null) for update loop
 update public.invitations set delivery_secret_id=null where delivery_secret_id=sid;
 delete from vault.secrets where id=sid;
 end loop;
 delete from public.oauth_states where expires_at<now()-interval '1 day';
 delete from cron.job_run_details where end_time<now()-interval '7 days';
 foreach q in array array['email_invites','drive_uploads','background_tasks'] loop
 execute format('delete from pgmq.%I where archived_at<now()-interval ''30 days''','a_'||q);
 end loop;
 if exists(select 1 from vault.decrypted_secrets where name='worksh_scheduler_enabled' and decrypted_secret='true') then
 perform public.enqueue('background_tasks','{"type":"cleanup_storage"}'::jsonb);
 end if;
end $$;
commit;
