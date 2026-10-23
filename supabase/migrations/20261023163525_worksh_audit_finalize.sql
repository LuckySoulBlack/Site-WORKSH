begin;
-- Safe on this new installation: no HTTP work is pending and scheduler is disabled.
do $$ begin
 if exists(select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname='pg_net' and n.nspname='public') then
  if exists(select 1 from net.http_request_queue) then raise exception 'HTTP queue must be empty before extension relocation';end if;
  drop extension pg_net;
  create extension pg_net with schema extensions;
 end if;
end $$;
revoke usage on schema net from public,anon,authenticated;
revoke execute on all functions in schema net from public,anon,authenticated;

create or replace function private.audit_row_change() returns trigger language plpgsql security definer set search_path='' as $$
declare r jsonb; w uuid; b uuid; uid uuid; oldsafe jsonb; newsafe jsonb;
 hidden text[]=array['drive_secret_id','must_change_password','token_hash','delivery_secret_id','state_hash','lease_token'];
begin
 r=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 uid=auth.uid();
 if uid is null then
  uid=coalesce((r->>'user_id')::uuid,(r->>'invited_by')::uuid,(r->>'owner_id')::uuid);
 end if;
 b=case when tg_table_name='boards' then (r->>'id')::uuid else (r->>'board_id')::uuid end;
 w=case when tg_table_name='workspaces' then (r->>'id')::uuid else (r->>'workspace_id')::uuid end;
 if w is null and b is not null then select workspace_id into w from public.boards where id=b;end if;
 if w is null then return null;end if;
 if tg_op<>'INSERT' then oldsafe=to_jsonb(old)-hidden;end if;
 if tg_op<>'DELETE' then newsafe=to_jsonb(new)-hidden;end if;
 insert into public.audit_events(table_name,record_id,action,old_data,new_data,actor_id,workspace_id,board_id,workspace_ref,board_ref)
 values(tg_table_name,(r->>'id')::uuid,tg_op,oldsafe,newsafe,uid,
 (select id from public.workspaces where id=w),(select id from public.boards where id=b),w,b);
 return null;
end $$;
create trigger history after insert or update or delete on public.invitations for each row execute function private.audit_row_change();
create trigger history after insert or update or delete on public.upload_jobs for each row execute function private.audit_row_change();
create trigger history after insert or update or delete on public.oauth_states for each row execute function private.audit_row_change();
commit;
