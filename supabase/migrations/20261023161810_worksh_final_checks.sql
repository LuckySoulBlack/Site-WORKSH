begin;
create index tasks_board_group_idx on public.tasks(board_id,group_id);
create index upload_jobs_board_task_idx on public.upload_jobs(board_id,task_id);

-- Privileged implementations live outside the exposed API schema.
-- Public RPCs are invoker wrappers; each private implementation still validates auth.uid().
alter function public.account_status() set schema private;
alter function public.create_workspace(text,uuid) set schema private;
alter function public.grant_board_access(uuid,uuid,boolean) set schema private;
alter function public.revoke_board_access(uuid,uuid) set schema private;
alter function public.invite_to_board(uuid,text) set schema private;
alter function public.accept_invitation(text) set schema private;
alter function public.enfileirar_upload(text,text,text,bigint,uuid,uuid) set schema private;
alter function public.shared_profiles(uuid) set schema private;
create function public.account_status() returns jsonb language sql security invoker set search_path='' as $$select private.account_status()$$;
create function public.create_workspace(workspace_name text,workspace_id uuid default null) returns uuid language sql security invoker set search_path='' as $$select private.create_workspace(workspace_name,workspace_id)$$;
create function public.grant_board_access(board_id uuid,user_id uuid,can_edit boolean default true) returns void language sql security invoker set search_path='' as $$select private.grant_board_access(board_id,user_id,can_edit)$$;
create function public.revoke_board_access(board_id uuid,user_id uuid) returns void language sql security invoker set search_path='' as $$select private.revoke_board_access(board_id,user_id)$$;
create function public.invite_to_board(board_id uuid,email text) returns uuid language sql security invoker set search_path='' as $$select private.invite_to_board(board_id,email)$$;
create function public.accept_invitation(token text) returns jsonb language sql security invoker set search_path='' as $$select private.accept_invitation(token)$$;
create function public.enfileirar_upload(storage_path text,file_name text,mime text,size_bytes bigint,board_id uuid,task_id uuid default null) returns uuid language sql security invoker set search_path='' as $$select private.enfileirar_upload(storage_path,file_name,mime,size_bytes,board_id,task_id)$$;
create function public.shared_profiles(b uuid) returns table(id uuid,full_name text) language sql security invoker set search_path='' as $$select * from private.shared_profiles(b)$$;
revoke all on function public.account_status(),public.create_workspace(text,uuid),public.grant_board_access(uuid,uuid,boolean),public.revoke_board_access(uuid,uuid),public.invite_to_board(uuid,text),public.accept_invitation(text),public.enfileirar_upload(text,text,text,bigint,uuid,uuid),public.shared_profiles(uuid) from public,anon;
grant execute on function public.account_status(),public.create_workspace(text,uuid),public.grant_board_access(uuid,uuid,boolean),public.revoke_board_access(uuid,uuid),public.invite_to_board(uuid,text),public.accept_invitation(text),public.enfileirar_upload(text,text,text,bigint,uuid,uuid),public.shared_profiles(uuid) to authenticated;
commit;
