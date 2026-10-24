begin;
create index audit_task_updates_lookup_idx on public.audit_events(record_id) where table_name='tasks' and action='UPDATE';
create index audit_task_children_lookup_idx on public.audit_events((coalesce(new_data->>'task_id',old_data->>'task_id'))) where table_name in ('comments','attachments','task_assignees');
create function private.can_delete_unupdated_task(target uuid) returns boolean language sql volatile security definer set search_path='' as $$
select exists(select 1 from public.tasks t where t.id=target and private.is_board_editor(t.board_id)
 and t.status='todo' and t.updated_at=t.created_at
 and not exists(select 1 from jsonb_array_elements(t.checklist) c where coalesce((c->>'done')::boolean,false) or coalesce((c->>'percent')::numeric,0)>0 or coalesce(c->>'status','todo')<>'todo')
 and not exists(select 1 from public.comments c where c.task_id=t.id)
 and not exists(select 1 from public.attachments a where a.task_id=t.id)
 and not exists(select 1 from public.audit_events a where a.record_id=t.id and a.table_name='tasks' and a.action='UPDATE' and (a.old_data-'updated_at') is distinct from (a.new_data-'updated_at'))
 and not exists(select 1 from public.audit_events a where coalesce(a.new_data->>'task_id',a.old_data->>'task_id')=t.id::text and a.table_name in ('comments','attachments','task_assignees')))
$$;
revoke all on function private.can_delete_unupdated_task(uuid) from public,anon;
grant execute on function private.can_delete_unupdated_task(uuid) to authenticated;
create policy unupdated_task_delete on public.tasks for delete to authenticated using(private.can_delete_unupdated_task(id));
create function private.guard_unupdated_task_delete() returns trigger language plpgsql set search_path='' as $$
begin
 if not exists(select 1 from public.boards where id=old.board_id) then return old;end if;
 if not private.owns_board(old.board_id) and not private.can_delete_unupdated_task(old.id) then raise exception 'Esta linha tem atualizações ou seu acesso mudou. Somente o proprietário pode excluí-la.' using errcode='42501';end if;
 return old;
end$$;
revoke all on function private.guard_unupdated_task_delete() from public,anon,authenticated,service_role;
create trigger guard_unupdated_task_delete before delete on public.tasks for each row execute function private.guard_unupdated_task_delete();
create function public.deletable_task_rows(task_ids uuid[]) returns table(id uuid) language plpgsql security invoker set search_path='' as $$
begin
 if cardinality(task_ids)>100 then raise exception 'Selecione até 100 linhas.';end if;
 return query select t.id from public.tasks t where t.id=any(task_ids) and (private.owns_board(t.board_id) or private.can_delete_unupdated_task(t.id));
end$$;
revoke all on function public.deletable_task_rows(uuid[]) from public,anon;
grant execute on function public.deletable_task_rows(uuid[]) to authenticated;
commit;
