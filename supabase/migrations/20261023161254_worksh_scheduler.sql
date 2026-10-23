begin;
create extension if not exists pg_cron;
create extension if not exists pg_net;
create function private.dispatch_queues() returns void language plpgsql security definer set search_path='' as $$
declare q text; pending boolean; key text; enabled text;
begin
 select decrypted_secret into enabled from vault.decrypted_secrets where name='worksh_scheduler_enabled';
 if enabled is distinct from 'true' then return; end if;
 select decrypted_secret into key from vault.decrypted_secrets where name='worksh_worker_secret';
 if key is null then return; end if;
 foreach q in array array['email_invites','drive_uploads','background_tasks'] loop
 execute format('select exists(select 1 from pgmq.%I where vt<=now())','q_'||q) into pending;
 if pending then perform net.http_post(
 url:='https://zazkecvrjmtbvmylxgij.supabase.co/functions/v1/queue-worker',
 headers:=jsonb_build_object('Content-Type','application/json','X-Worker-Secret',key),
 body:=jsonb_build_object('queue',q),timeout_milliseconds:=120000); end if;
 end loop;
 delete from cron.job_run_details where end_time<now()-interval '7 days';
 delete from public.oauth_states where expires_at<now()-interval '1 day';
end $$;
revoke all on function private.dispatch_queues() from public,anon,authenticated;
select vault.create_secret('false','worksh_scheduler_enabled','Enable only after configuring external integrations');
select cron.schedule('worksh-queues','* * * * *','select private.dispatch_queues()');
commit;
