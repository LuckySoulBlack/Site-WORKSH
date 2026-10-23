begin;
-- Add the task group label to the already authorized shared-project projection.
create or replace function private.read_shared_project(token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare s private.project_shares;result jsonb;
begin
 if token is null or token!~'^[0-9a-f]{64}$' then raise exception 'Link inválido, expirado ou revogado.' using errcode='42501';end if;
 select * into s from private.project_shares where token_hash=encode(extensions.digest(token,'sha256'),'hex') and revoked_at is null and expires_at>now();
 if not found or not exists(select 1 from private.account_security a where a.user_id=s.owner_id and not a.must_change_password and not a.is_blocked) then raise exception 'Link inválido, expirado ou revogado.' using errcode='42501';end if;
 if (select count(*) from (select id from public.tasks where board_id=s.board_id limit 5001) t)>5000 then raise exception 'A visualização externa excedeu o limite de tarefas.';end if;
 select jsonb_build_object('title',b.name,'companyName',coalesce(w.company->>'name',''),'view',s.view_type,'includePeople',s.include_people,'generatedAt',now(),'expiresAt',s.expires_at,'live',true,
 'tasks',coalesce((select jsonb_agg(jsonb_build_object('title',t.title,'group',coalesce((select g.name from public.groups g where g.id=t.group_id and g.board_id=t.board_id),'Sem grupo'),'status',t.status,'start_date',t.start_date,'due',t.due)||case when s.include_people then jsonb_build_object('assignee',(select p.full_name from public.profiles p where p.id=t.assignee_id)) else '{}'::jsonb end order by t.position,t.created_at,t.id) from public.tasks t where t.board_id=b.id),'[]'))
 into result from public.boards b join public.workspaces w on w.id=b.workspace_id where b.id=s.board_id and w.owner_id=s.owner_id;
 if result is null then raise exception 'Link inválido, expirado ou revogado.' using errcode='42501';end if;return result;
end$$;
commit;
