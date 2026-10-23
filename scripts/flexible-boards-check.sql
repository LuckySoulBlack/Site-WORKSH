begin;
insert into auth.users(id,email) values ('aaaaaaaa-0000-4000-8000-000000000001','owner@example.invalid'),('aaaaaaaa-0000-4000-8000-000000000002','editor@example.invalid'),('aaaaaaaa-0000-4000-8000-000000000003','reader@example.invalid'),('aaaaaaaa-0000-4000-8000-000000000004','outsider@example.invalid');
update private.account_security set must_change_password=false;
insert into public.workspaces(id,name,owner_id) values('aaaaaaaa-0000-4000-8000-000000000005','Test','aaaaaaaa-0000-4000-8000-000000000001');
insert into public.boards(id,workspace_id,name,created_by) values('aaaaaaaa-0000-4000-8000-000000000006','aaaaaaaa-0000-4000-8000-000000000005','Board','aaaaaaaa-0000-4000-8000-000000000001');
insert into public.workspace_members(workspace_id,user_id,must_change_password) values('aaaaaaaa-0000-4000-8000-000000000005','aaaaaaaa-0000-4000-8000-000000000002',false),('aaaaaaaa-0000-4000-8000-000000000005','aaaaaaaa-0000-4000-8000-000000000003',false);
insert into public.board_members(workspace_id,board_id,user_id,can_edit,granted_by) values('aaaaaaaa-0000-4000-8000-000000000005','aaaaaaaa-0000-4000-8000-000000000006','aaaaaaaa-0000-4000-8000-000000000002',true,'aaaaaaaa-0000-4000-8000-000000000001'),('aaaaaaaa-0000-4000-8000-000000000005','aaaaaaaa-0000-4000-8000-000000000006','aaaaaaaa-0000-4000-8000-000000000003',false,'aaaaaaaa-0000-4000-8000-000000000001');
insert into public.tasks(id,board_id,title,created_by) values('aaaaaaaa-0000-4000-8000-000000000007','aaaaaaaa-0000-4000-8000-000000000006','Task','aaaaaaaa-0000-4000-8000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000002',true);
select public.apply_changes('[{"table":"tasks","op":"update","id":"aaaaaaaa-0000-4000-8000-000000000007","values":{"start_date":"2026-10-23","custom_values":{"c_hours":12}}}]'::jsonb);
insert into public.board_settings(board_id,key,value) values('aaaaaaaa-0000-4000-8000-000000000006','columns','{"columns":[{"id":"c_hours","name":"Hours","type":"number"}]}');
do $$begin
 begin update public.tasks set custom_values='{"c_hours":"invalid"}';raise exception using errcode='P0002',message='Invalid numeric cell accepted';exception when sqlstate 'P0001' then null;end;
 begin insert into public.board_settings(board_id,key,value) select board_id,'columns','{"columns":[{"id":"bad-id","name":"Bad","type":"number"}]}' from public.tasks limit 1 on conflict(board_id,key) do update set value=excluded.value;raise exception using errcode='P0002',message='Invalid column accepted';exception when sqlstate 'P0001' then null;end;
end$$;
update public.profiles set avatar_path='aaaaaaaa-0000-4000-8000-000000000002/avatar.webp' where id='aaaaaaaa-0000-4000-8000-000000000002';
insert into storage.objects(bucket_id,name) values('profile-photos','aaaaaaaa-0000-4000-8000-000000000002/avatar.webp');
do $$declare affected integer;begin
 delete from public.tasks where id='aaaaaaaa-0000-4000-8000-000000000007';get diagnostics affected=row_count;if affected<>0 then raise exception 'Guest deleted task';end if;
 begin insert into storage.objects(bucket_id,name) values('profile-photos','aaaaaaaa-0000-4000-8000-000000000001/avatar.webp');raise exception 'Forged avatar allowed';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000003',true);
do $$declare n integer;begin
 update public.tasks set custom_values='{"c_hours":20}' where id='aaaaaaaa-0000-4000-8000-000000000007';get diagnostics n=row_count;if n<>0 then raise exception 'Reader changed cell';end if;
 if (select count(*) from storage.objects)<>1 then raise exception 'Reader missing authorized avatar';end if;
end$$;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000004',true);
do $$begin
 if exists(select 1 from public.tasks) or exists(select 1 from public.board_people('aaaaaaaa-0000-4000-8000-000000000006')) or exists(select 1 from storage.objects) then raise exception 'Tenant information leaked';end if;
end$$;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000001',true);
do $$declare n integer;begin delete from public.tasks where id='aaaaaaaa-0000-4000-8000-000000000007';get diagnostics n=row_count;if n<>1 then raise exception 'Owner cannot delete';end if;end$$;
rollback;
