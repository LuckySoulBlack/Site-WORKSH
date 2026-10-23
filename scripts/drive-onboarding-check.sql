begin;
select set_config('test.owner',gen_random_uuid()::text,true);
select set_config('test.guest',gen_random_uuid()::text,true);
insert into auth.users(id,email,raw_user_meta_data) values(current_setting('test.owner')::uuid,'drive-owner-qa@example.invalid','{}'),(current_setting('test.guest')::uuid,'drive-guest-qa@example.invalid','{}');
update private.account_security set must_change_password=false,account_type=case when user_id=current_setting('test.owner')::uuid then 'user' else 'guest' end where user_id in(current_setting('test.owner')::uuid,current_setting('test.guest')::uuid);
select set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
set local role authenticated;
do $$begin
 if not (public.account_status()->>'drive_required')::boolean then raise exception 'Owner onboarding not required'; end if;
 begin perform public.create_workspace('Must fail before Drive');raise exception 'Workspace bypassed Drive';exception when insufficient_privilege then null;end;
 if has_function_privilege('authenticated','public.backend_owner_drive(uuid,text,jsonb)','execute') then raise exception 'Credential service exposed';end if;
end $$;
reset role;
select public.backend_oauth_state(current_setting('test.owner')::uuid,null,repeat('a',64));
select public.backend_consume_state(repeat('a',64));
do $$begin
 begin perform public.backend_consume_state(repeat('a',64));raise exception 'OAuth state replayed';exception when raise_exception then if sqlerrm='OAuth state replayed' then raise;end if;end;
end $$;
select public.backend_owner_drive(current_setting('test.owner')::uuid,'prepare',jsonb_build_object('subject','google-qa-subject','email','owner@example.invalid','root_id','root-qa','refresh_token','disposable-fixture'));
select public.backend_owner_drive(current_setting('test.owner')::uuid,'finish','{"root_id":"root-qa"}');
set local role authenticated;
select set_config('test.ws1',public.create_workspace('Drive QA first')::text,true);
select set_config('test.ws2',public.create_workspace('Drive QA second')::text,true);
do $$begin if not (public.account_status()->>'drive_connected')::boolean then raise exception 'Drive not connected';end if;if has_column_privilege('authenticated','public.workspaces','drive_secret_id','select') then raise exception 'Secret reference exposed';end if;end $$;
reset role;
do $$declare a uuid;b uuid;begin
 select drive_secret_id into a from public.workspaces where id=current_setting('test.ws1')::uuid;select drive_secret_id into b from public.workspaces where id=current_setting('test.ws2')::uuid;
 if a is null or a<>b then raise exception 'Workspace credentials not shared';end if;
end $$;
do $$begin
 begin perform public.backend_owner_drive(current_setting('test.owner')::uuid,'prepare','{"subject":"another-account","email":"different@example.invalid","root_id":"root-other","refresh_token":"ignored"}');raise exception 'Google account silently replaced';exception when raise_exception then if sqlerrm='Google account silently replaced' then raise;end if;end;
end $$;
insert into public.boards(workspace_id,name,created_by) values(current_setting('test.ws1')::uuid,'Board Drive QA',current_setting('test.owner')::uuid);
select set_config('test.drive_board',(select id::text from public.boards where workspace_id=current_setting('test.ws1')::uuid),true);
do $$declare a jsonb;b jsonb;begin
 a:=public.backend_owner_drive(current_setting('test.owner')::uuid,'board_folder',jsonb_build_object('board_id',current_setting('test.drive_board')));
 if a->>'folder_id' is not null then raise exception 'Unknown folder unexpectedly exists';end if;
 a:=public.backend_owner_drive(current_setting('test.owner')::uuid,'board_folder',jsonb_build_object('board_id',current_setting('test.drive_board'),'folder_id','board-folder-qa'));
 b:=public.backend_owner_drive(current_setting('test.owner')::uuid,'board_folder',jsonb_build_object('board_id',current_setting('test.drive_board'),'folder_id','second-folder-qa'));
 if a->>'folder_id'<>b->>'folder_id' then raise exception 'Board folder duplicated';end if;
end $$;
select public.backend_owner_drive(current_setting('test.owner')::uuid,'invalidate');
set local role authenticated;
do $$begin
 if not exists(select 1 from public.workspaces where id=current_setting('test.ws1')::uuid) then raise exception 'Existing workspace hidden';end if;
 begin perform public.create_workspace('Revoked must fail');raise exception 'Revoked Drive allowed creation';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.guest'),true);
do $$begin
 if (public.account_status()->>'drive_required')::boolean then raise exception 'Guest incorrectly requires own Drive';end if;
 begin perform public.create_workspace('Guest cannot own');raise exception 'Guest created workspace';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: owner onboarding, single-use OAuth, shared credentials across workspaces, reconnect gate, account binding, service isolation and guest exemption' result;
