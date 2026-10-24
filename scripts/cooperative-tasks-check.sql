-- Run after the fixture setup in flexible-boards-check.sql, inside its transaction.
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000002',true);
select public.apply_changes('[{"table":"tasks","op":"update","id":"aaaaaaaa-0000-4000-8000-000000000007","values":{"assignee_id":"aaaaaaaa-0000-4000-8000-000000000001","assignee_ids":["aaaaaaaa-0000-4000-8000-000000000001","aaaaaaaa-0000-4000-8000-000000000002"]}}]');
do $$begin
 if (select count(*) from public.task_assignees)<>2 then raise exception 'Missing cooperators';end if;
 if (public.workspace_counts('aaaaaaaa-0000-4000-8000-000000000005')->'people'->>'aaaaaaaa-0000-4000-8000-000000000002')::int<>1 then raise exception 'Missing cooperator analytics';end if;
 begin perform public.apply_changes('[{"table":"tasks","op":"update","id":"aaaaaaaa-0000-4000-8000-000000000007","values":{"title":"Must roll back","assignee_id":"aaaaaaaa-0000-4000-8000-000000000004","assignee_ids":["aaaaaaaa-0000-4000-8000-000000000004"]}}]');raise exception using errcode='P0002',message='Outsider assignment accepted';exception when insufficient_privilege or raise_exception then null;end;
 if (select title from public.tasks limit 1)<>'Task' then raise exception 'Assignment failure was not atomic';end if;
end$$;
select public.apply_changes('[{"table":"tasks","op":"update","id":"aaaaaaaa-0000-4000-8000-000000000007","values":{"checklist":[{"id":"item-1","text":"Cooperative item","done":false,"status":"progress","percent":50,"due":"2026-11-06","assignees":["aaaaaaaa-0000-4000-8000-000000000002"]}]}}]');
do $$begin
 begin perform public.set_task_assignees('aaaaaaaa-0000-4000-8000-000000000007',array['aaaaaaaa-0000-4000-8000-000000000001']::uuid[]);raise exception using errcode='P0002',message='Checklist responsibility lost';exception when sqlstate 'P0001' then null;end;
 begin update public.tasks set checklist='[{"text":"Bad","assignees":["aaaaaaaa-0000-4000-8000-000000000004"]}]';raise exception 'Outside checklist assignee accepted';exception when insufficient_privilege then null;end;
end$$;
do $$declare n integer;begin delete from public.tasks;get diagnostics n=row_count;if n<>0 then raise exception 'Guest deleted task';end if;end$$;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000003',true);
do $$begin
 if (select count(*) from public.task_assignees)<>2 then raise exception 'Reader missing visible team';end if;
 begin perform public.set_task_assignees('aaaaaaaa-0000-4000-8000-000000000007','{}'::uuid[]);raise exception 'Reader edited assignments';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000004',true);
do $$begin if exists(select 1 from public.task_assignees) then raise exception 'Assignments leaked';end if;end$$;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000001',true);
delete from public.tasks;
do $$begin if exists(select 1 from public.task_assignees) then raise exception 'Assignment cascade failed';end if;end$$;
rollback;
