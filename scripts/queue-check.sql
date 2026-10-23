-- Database job/lease test only; no file bytes or external provider calls. Rollback.
begin;
select set_config('test.queue_user',gen_random_uuid()::text,true);
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values(current_setting('test.queue_user')::uuid,'worksh-queue-'||current_setting('test.queue_user')||'@example.invalid',now(),'{}');
update private.account_security set must_change_password=false where user_id=current_setting('test.queue_user')::uuid;
select set_config('request.jwt.claim.sub',current_setting('test.queue_user'),true);
set local role authenticated;
select set_config('test.queue_workspace',public.create_workspace('QA queue workspace')::text,true);
insert into public.boards(workspace_id,name,created_by) values(current_setting('test.queue_workspace')::uuid,'QA queue board',auth.uid());
select set_config('test.queue_board',(select id::text from public.boards where workspace_id=current_setting('test.queue_workspace')::uuid),true);
reset role;
update public.workspaces set drive_secret_id=vault.create_secret('disposable-not-a-real-google-token'),drive_folder_id='disposable-folder' where id=current_setting('test.queue_workspace')::uuid;
select set_config('test.storage_path',current_setting('test.queue_user')||'/'||current_setting('test.queue_board')||'/'||gen_random_uuid(),true);
insert into storage.objects(bucket_id,name,owner_id,metadata) values('uploads-temp',current_setting('test.storage_path'),current_setting('test.queue_user'),'{"size":32,"mimetype":"image/png"}');
set local role authenticated;
select set_config('test.upload_job',public.enfileirar_upload(current_setting('test.storage_path'),'QA.png','image/png',32,current_setting('test.queue_board')::uuid)::text,true);
do $$ declare j uuid;begin
 j=public.enfileirar_upload(current_setting('test.storage_path'),'QA.png','image/png',32,current_setting('test.queue_board')::uuid);
 if j::text<>current_setting('test.upload_job') then raise exception 'Upload enqueue not idempotent';end if;
end $$;
reset role;
do $$ declare j jsonb;m jsonb;lease uuid;begin
 m=public.dequeue('drive_uploads',10,60);
 if jsonb_array_length(m)<>1 then raise exception 'Duplicate queue message';end if;
 j=public.backend_claim_upload(current_setting('test.upload_job')::uuid);
 if j is null then raise exception 'Claim failed';end if;
 lease=(j->>'lease_token')::uuid;
 if public.backend_claim_upload(current_setting('test.upload_job')::uuid) is not null then raise exception 'Concurrent lease acquired';end if;
 if not public.backend_renew('drive_uploads',(m->0->>'msg_id')::bigint,current_setting('test.upload_job')::uuid,lease) then raise exception 'Lease renewal failed';end if;
 update public.upload_jobs set drive_file_id='qa-drive-'||id where id=current_setting('test.upload_job')::uuid;
 perform public.backend_finish_upload(current_setting('test.upload_job')::uuid,lease);
 if public.backend_claim_upload(current_setting('test.upload_job')::uuid) is not null then raise exception 'Completed upload reclaimed';end if;
 if (select count(*) from public.attachments where board_id=current_setting('test.queue_board')::uuid)<>1 then raise exception 'Attachment not created exactly once';end if;
 perform public.ack('drive_uploads',(m->0->>'msg_id')::bigint);
end $$;
select 'PASS: enqueue idempotency, batch, exclusive lease, heartbeat, finalization and ack' as result;
rollback;
