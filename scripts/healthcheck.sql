select name,default_version,installed_version from pg_available_extensions where name in ('pgmq','pg_cron','pg_net','supabase_vault','pgcrypto','uuid-ossp');
select schemaname,tablename,rowsecurity from pg_tables where schemaname in ('public','private');
select 'email_invites' as queue,count(*) as pending from pgmq.q_email_invites union all select 'drive_uploads',count(*) from pgmq.q_drive_uploads union all select 'background_tasks',count(*) from pgmq.q_background_tasks;
select status,count(*) from public.upload_jobs group by status;
select count(*) as failed_invites from public.invitations where attempts>=5 and delivered_at is null;
select relname,n_live_tup as estimated_rows,pg_size_pretty(pg_total_relation_size(relid)) as size from pg_stat_user_tables where schemaname in ('public','private','pgmq') order by pg_total_relation_size(relid) desc;
select pg_size_pretty(pg_database_size(current_database())) as database_size;
select jobname,schedule,active from cron.job where jobname='worksh-queues';
select exists(select 1 from vault.decrypted_secrets where name='worksh_scheduler_enabled' and decrypted_secret='true') as scheduler_enabled;
