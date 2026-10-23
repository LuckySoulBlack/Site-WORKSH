-- Disposable fixtures are rolled back. No invitations are delivered.
begin;
select set_config('test.owner',gen_random_uuid()::text,true);
select set_config('test.member',gen_random_uuid()::text,true);
select set_config('test.other',gen_random_uuid()::text,true);
select set_config('test.pending',gen_random_uuid()::text,true);
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
select current_setting('test.'||x)::uuid,'worksh-qa-'||current_setting('test.'||x)||'@example.invalid',now(),'{}'::jsonb
from unnest(array['owner','member','other','pending']) x;
update private.account_security set must_change_password=false where user_id in(current_setting('test.owner')::uuid,current_setting('test.member')::uuid,current_setting('test.other')::uuid);
select set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
set local role authenticated;
select set_config('test.workspace',public.create_workspace('QA isolated workspace')::text,true);
insert into public.boards(workspace_id,name,created_by) values(current_setting('test.workspace')::uuid,'QA allowed',auth.uid()),(current_setting('test.workspace')::uuid,'QA hidden',auth.uid());
select set_config('test.board',(select id::text from public.boards where name='QA allowed'),true);
select set_config('test.hidden',(select id::text from public.boards where name='QA hidden'),true);
select set_config('test.invitation',public.invite_to_board(current_setting('test.board')::uuid,'qa-invite@example.invalid')::text,true);
reset role;
insert into public.workspace_members(workspace_id,user_id,must_change_password,invited_by)
select current_setting('test.workspace')::uuid,current_setting('test.'||x)::uuid,false,current_setting('test.owner')::uuid from unnest(array['member','pending']) x;
select set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
set local role authenticated;
select public.grant_board_access(current_setting('test.board')::uuid,current_setting('test.member')::uuid,true);
select public.grant_board_access(current_setting('test.board')::uuid,current_setting('test.pending')::uuid,true);
select set_config('request.jwt.claim.sub',current_setting('test.member'),true);
do $$ begin
 if (select count(*) from public.boards)<>1 then raise exception 'Board isolation failed'; end if;
 insert into public.tasks(board_id,title,created_by) values(current_setting('test.board')::uuid,'QA task',auth.uid());
 update public.tasks set title='QA updated' where title='QA task';
 delete from public.tasks where title='QA updated';
 if not exists(select 1 from public.tasks where title='QA updated') then raise exception 'Member deletion allowed'; end if;
 begin update public.workspace_members set must_change_password=false;raise exception 'Password flag bypass';exception when insufficient_privilege then null;end;
 begin perform public.complete_password_change(auth.uid());raise exception 'Backend RPC exposed';exception when insufficient_privilege then null;end;
 begin perform public.enqueue('email_invites','{}');raise exception 'Queue exposed';exception when insufficient_privilege then null;end;
 begin insert into public.tasks(board_id,title,created_by) values(current_setting('test.hidden')::uuid,'Forbidden',auth.uid());raise exception 'Hidden board write allowed';exception when insufficient_privilege then null;end;
 if (select count(*) from public.audit_events)<>2 then raise exception 'History visibility failed';end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.other'),true);
do $$ begin if exists(select 1 from public.boards) then raise exception 'Other user can see boards';end if;end $$;
select set_config('request.jwt.claim.sub',current_setting('test.pending'),true);
do $$ begin if exists(select 1 from public.tasks) then raise exception 'Pending password bypass';end if;end $$;
select set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
do $$ begin
 delete from public.tasks where title='QA updated';
 if exists(select 1 from public.tasks where title='QA updated') then raise exception 'Owner deletion failed';end if;
end $$;
select public.revoke_board_access(current_setting('test.board')::uuid,current_setting('test.member')::uuid);
do $$ declare x uuid=gen_random_uuid(); begin
 perform public.apply_changes(jsonb_build_array(jsonb_build_object('table','tasks','op','insert','values',jsonb_build_object('id',x,'board_id',current_setting('test.board'),'title','QA atomic','created_by',auth.uid()))));
 begin
  perform public.apply_changes(jsonb_build_array(
   jsonb_build_object('table','tasks','op','update','id',x,'values',jsonb_build_object('title','Should roll back')),
   jsonb_build_object('table','boards','op','update','id',current_setting('test.board'),'version','2000-01-01T00:00:00Z','values',jsonb_build_object('name','Conflict'))));
  raise exception 'Stale write accepted';
 exception when serialization_failure then null;
 end;
 if not exists(select 1 from public.tasks where id=x and title='QA atomic') then raise exception 'Batch rollback failed';end if;
 begin
  perform public.apply_changes(jsonb_build_array(jsonb_build_object('table','workspaces','op','update','id',current_setting('test.workspace'),'values',jsonb_build_object('owner_id',auth.uid()))));
  raise exception 'Invalid field accepted';
 exception when raise_exception then if sqlerrm='Invalid field accepted' then raise;end if;
 end;
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.member'),true);
do $$ begin if exists(select 1 from public.boards) then raise exception 'Revocation failed';end if;end $$;
reset role;
set local role anon;
do $$ begin
 begin perform 1 from public.tasks;raise exception 'Anonymous read allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: owner/member/outsider/pending/anonymous, board isolation, revoke, history, queue and password flag protections' as result;
rollback;
