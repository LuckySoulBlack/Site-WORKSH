begin;
insert into auth.users(id,email,raw_user_meta_data) values ('aaaaaaaa-1111-4111-8111-111111111111','history-test@example.invalid','{"full_name":"Lucas Teste"}');
insert into public.audit_events(table_name,record_id,action,actor_id,workspace_ref) values ('tasks',gen_random_uuid(),'UPDATE','aaaaaaaa-1111-4111-8111-111111111111',gen_random_uuid());
update public.profiles set full_name='Outro nome' where id='aaaaaaaa-1111-4111-8111-111111111111';
do $$begin
 if not exists(select 1 from public.audit_events where actor_name='Lucas Teste') then raise exception 'Author snapshot lost on rename';end if;
 if has_table_privilege('authenticated','public.audit_events','INSERT') or has_table_privilege('authenticated','public.audit_events','UPDATE') then raise exception 'Client can forge audit';end if;
 if has_function_privilege('authenticated','private.capture_audit_actor_name()','EXECUTE') then raise exception 'Private function exposed';end if;
end$$;
-- Simulate the existing actor FK ON DELETE SET NULL action without deleting fixtures owned elsewhere.
update public.audit_events set actor_id=null where actor_id='aaaaaaaa-1111-4111-8111-111111111111';
do $$begin if not exists(select 1 from public.audit_events where actor_id is null and actor_name='Lucas Teste') then raise exception 'Name lost after actor removal';end if;end$$;
rollback;
