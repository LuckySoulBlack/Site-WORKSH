begin;
select set_config('test.admin',gen_random_uuid()::text,true);
select set_config('test.guest',gen_random_uuid()::text,true);
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) select current_setting('test.'||x)::uuid,'role-qa-'||current_setting('test.'||x)||'@example.invalid',now(),'{}'::jsonb from unnest(array['admin','guest']) x;
update private.account_security set must_change_password=false where user_id in(current_setting('test.admin')::uuid,current_setting('test.guest')::uuid);
update private.account_security set is_admin=true,account_type='user' where user_id=current_setting('test.admin')::uuid;
select set_config('request.jwt.claim.sub',current_setting('test.guest'),true);
set local role authenticated;
do $$ begin
 if public.account_status()->>'profile_role'<>'guest' then raise exception 'New identity must be guest'; end if;
 begin perform public.create_workspace('Guest forbidden');raise exception 'Guest created workspace'; exception when insufficient_privilege then null; end;
 if has_function_privilege('authenticated','public.backend_platform_invite(uuid,text,text,uuid,uuid,uuid)','execute') then raise exception 'Invite service exposed'; end if;
end $$;
reset role;
select private.manage_users(current_setting('test.admin')::uuid,'role_user',current_setting('test.guest')::uuid);
set local role authenticated;
select set_config('test.ws',public.create_workspace('Profile QA workspace')::text,true);
reset role;
do $$ begin
 begin perform private.manage_users(current_setting('test.admin')::uuid,'role_guest',current_setting('test.guest')::uuid);raise exception 'Owner became guest'; exception when raise_exception then if sqlerrm='Owner became guest' then raise; end if; end;
end $$;
select private.manage_users(current_setting('test.admin')::uuid,'role_admin',current_setting('test.guest')::uuid);
do $$ declare r jsonb; s uuid; begin
 r:=private.platform_invite(current_setting('test.admin')::uuid,'platform-qa@example.invalid','disposable-test-secret');s:=(r->>'secret_id')::uuid;
 if not exists(select 1 from vault.secrets where id=s) then raise exception 'Missing encrypted delivery'; end if;
 perform private.platform_invite(current_setting('test.admin')::uuid,'platform-qa@example.invalid','',(r->>'id')::uuid,(r->>'lease_token')::uuid,current_setting('test.guest')::uuid);
 if exists(select 1 from vault.secrets where id=s) then raise exception 'Delivery secret not cleaned'; end if;
 if (private.platform_invite(current_setting('test.admin')::uuid,'platform-qa@example.invalid','ignored')->>'already_sent')::boolean is not true then raise exception 'Duplicate invitation not suppressed'; end if;
end $$;
rollback;
select 'PASS: guest restrictions, owner permissions, admin promotion, service isolation, encrypted invite cleanup and dedup' result;
