begin;
create table public.task_assignees (
 id uuid primary key default gen_random_uuid(),
 board_id uuid not null references public.boards(id) on delete cascade,
 task_id uuid not null,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
 created_at timestamptz not null default now(),
 foreign key(board_id,task_id) references public.tasks(board_id,id) on delete cascade,
 unique(task_id,user_id)
);
create index task_assignees_board_task_idx on public.task_assignees(board_id,task_id);
create index task_assignees_user_idx on public.task_assignees(user_id);
create index task_assignees_creator_idx on public.task_assignees(created_by);
alter table public.task_assignees enable row level security;
create function private.task_person_allowed(b uuid,p uuid) returns boolean language sql stable security definer set search_path='' as $$
select private.is_board_member(b) and exists(select 1 from public.boards x join public.workspaces w on w.id=x.workspace_id where x.id=b and (w.owner_id=p or exists(select 1 from public.board_members m where m.board_id=b and m.user_id=p)))
$$;
revoke all on function private.task_person_allowed(uuid,uuid) from public,anon;
grant execute on function private.task_person_allowed(uuid,uuid) to authenticated;
create policy task_assignees_read on public.task_assignees for select to authenticated using(private.is_board_member(board_id));
create policy task_assignees_add on public.task_assignees for insert to authenticated with check(private.is_board_editor(board_id) and private.task_person_allowed(board_id,user_id));
-- Removing a responsibility edits the assignment; task deletion remains owner-only.
create policy task_assignees_remove on public.task_assignees for delete to authenticated using(private.is_board_editor(board_id));
grant select,delete on public.task_assignees to authenticated;
grant insert(board_id,task_id,user_id) on public.task_assignees to authenticated;
create trigger history after insert or delete on public.task_assignees for each row execute function private.audit_row_change();
create function public.cooperative_tasks() returns boolean language sql immutable set search_path='' as $$select true$$;
revoke all on function public.cooperative_tasks() from public,anon;
grant execute on function public.cooperative_tasks() to authenticated;
create function public.set_task_assignees(task uuid,people uuid[],version timestamptz default null) returns jsonb language plpgsql security invoker set search_path='' as $$
declare b uuid; stamp timestamptz; person uuid;
begin
 select board_id into b from public.tasks where id=task;
 if b is null or not private.is_board_editor(b) then raise exception 'Sem permissão para editar os responsáveis.' using errcode='42501';end if;
 if people is null or cardinality(people)>100 or exists(select 1 from unnest(people) p where p is null or not private.task_person_allowed(b,p)) then raise exception 'Selecione somente participantes do quadro.' using errcode='42501';end if;
 if exists(select 1 from public.tasks t cross join lateral jsonb_array_elements(t.checklist) c cross join lateral jsonb_array_elements_text(coalesce(c->'assignees','[]'::jsonb)) u where t.id=task and not(u::uuid=any(people))) then raise exception 'Reatribua os itens do checklist antes de remover esta pessoa.';end if;
 update public.tasks set assignee_id=people[1] where id=task and (version is null or updated_at=version) returning updated_at into stamp;
 if stamp is null then raise exception 'Tarefa alterada por outra pessoa. Atualize a página.' using errcode='40001';end if;
 delete from public.task_assignees where task_id=task and not(user_id=any(people));
 foreach person in array people loop
  insert into public.task_assignees(board_id,task_id,user_id) values(b,task,person) on conflict(task_id,user_id) do nothing;
 end loop;
 return jsonb_build_object('id',task,'updated_at',stamp);
end$$;
revoke all on function public.set_task_assignees(uuid,uuid[],timestamptz) from public,anon;
grant execute on function public.set_task_assignees(uuid,uuid[],timestamptz) to authenticated;
create function private.validate_checklist_people() returns trigger language plpgsql set search_path='' as $$
declare item jsonb; person text;
begin
 for item in select * from jsonb_array_elements(new.checklist) loop
  if item?'assignees' then
   if jsonb_typeof(item->'assignees')<>'array' or jsonb_array_length(item->'assignees')>100 then raise exception 'Responsáveis do checklist inválidos';end if;
   for person in select * from jsonb_array_elements_text(item->'assignees') loop
    if person is null or not private.task_person_allowed(new.board_id,person::uuid) then raise exception 'Responsável fora do quadro' using errcode='42501';end if;
   end loop;
  end if;
  if item?'percent' and (jsonb_typeof(item->'percent')<>'number' or (item->>'percent')::numeric<0 or (item->>'percent')::numeric>100) then raise exception 'Percentual inválido';end if;
  if item?'status' and item->>'status' not in ('todo','progress','blocked','done','canceled') then raise exception 'Status inválido';end if;
  if nullif(item->>'due','') is not null then perform (item->>'due')::date;end if;
 end loop;
 return new;
end$$;
revoke all on function private.validate_checklist_people() from public,anon,authenticated,service_role;
create trigger validate_checklist_people before insert or update of checklist on public.tasks for each row execute function private.validate_checklist_people();
create or replace function public.apply_changes(changes jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare c jsonb; tbl text; op text; v jsonb; allowed text[]; cols text; assigns text; result jsonb; output jsonb='[]'; rid uuid; people uuid[];
begin
 if not private.ready() then raise exception 'Troque sua senha antes de continuar.' using errcode='42501'; end if;
 if jsonb_typeof(changes)<>'array' or jsonb_array_length(changes)>100 or octet_length(changes::text)>262144 then raise exception 'Lote inválido'; end if;
 for c in select * from jsonb_array_elements(changes) loop
  tbl=c->>'table';op=c->>'op';v=c->'values';rid=(c->>'id')::uuid;people=null;
  if tbl='tasks' and op in ('insert','update') and v?'assignee_ids' then
   if jsonb_typeof(v->'assignee_ids')<>'array' or jsonb_array_length(v->'assignee_ids')>100 then raise exception 'Lista de responsáveis inválida';end if;
   select coalesce(array_agg(x::uuid),'{}'::uuid[]) into people from jsonb_array_elements_text(v->'assignee_ids') x;v=v-'assignee_ids';
  end if;
  if op='workspace_create' and tbl='workspaces' then
   perform public.create_workspace(v->>'name',rid);
   select jsonb_build_object('id',id,'updated_at',updated_at) into result from public.workspaces where id=rid;
  else
   if tbl not in ('profiles','workspaces','boards','groups','tasks','comments','board_settings') or op not in ('insert','update','delete') then raise exception 'Operação inválida'; end if;
   if op='delete' then
    execute format('delete from public.%I where id=$1 and ($2 is null or updated_at=$2) returning jsonb_build_object(''id'',id,''updated_at'',updated_at)',tbl)
     into result using rid,(c->>'version')::timestamptz;
   else
    allowed=case tbl
     when 'profiles' then array['full_name','phone','job','theme','avatar_path']
     when 'workspaces' then array['name','description','modules','company']
     when 'boards' then array['name','description']
     when 'groups' then array['name','position']
     when 'tasks' then array['group_id','title','description','link_url','status','position','due','priority','checklist','assignee_id','start_date','custom_values']
     when 'comments' then array['content']
     when 'board_settings' then array['key','value'] end;
    if op='insert' then
     if tbl in ('profiles','workspaces') then raise exception 'Inserção restrita'; end if;
     allowed=allowed||array['id']||case tbl when 'boards' then array['workspace_id','created_by'] when 'tasks' then array['board_id','created_by'] when 'comments' then array['board_id','task_id','author_id'] else array['board_id'] end;
    end if;
    if jsonb_typeof(v)<>'object' or v='{}'::jsonb or exists(select 1 from jsonb_object_keys(v) k where not k=any(allowed)) then raise exception 'Campos inválidos'; end if;
    select string_agg(format('%I',k),',' order by k),string_agg(format('%I=r.%I',k,k),',' order by k) into cols,assigns from jsonb_object_keys(v) k;
    if op='insert' then
     execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I,$1) r returning jsonb_build_object(''id'',id,''updated_at'',updated_at)',tbl,cols,cols,tbl) into result using v;
    else
     execute format('update public.%I t set %s from jsonb_populate_record(null::public.%I,$1) r where t.id=$2 and ($3 is null or t.updated_at=$3) returning jsonb_build_object(''id'',t.id,''updated_at'',t.updated_at)',tbl,assigns,tbl)
      into result using v,rid,(c->>'version')::timestamptz;
    end if;
   end if;
  end if;
  if result is null then raise exception 'Registro alterado por outra pessoa ou acesso removido. Atualize a página.' using errcode='40001'; end if;
  if people is not null then result=public.set_task_assignees((result->>'id')::uuid,people,(result->>'updated_at')::timestamptz);end if;
  output=output||jsonb_build_array(jsonb_build_object('table',tbl,'id',result->>'id','updated_at',result->>'updated_at'));
 end loop;
 return output;
end $$;
revoke all on function public.apply_changes(jsonb) from public,anon;
grant execute on function public.apply_changes(jsonb) to authenticated;

create or replace function public.workspace_counts(w uuid) returns jsonb language sql stable security invoker set search_path='' as $$
 with visible as (select t.* from public.tasks t join public.boards b on b.id=t.board_id where b.workspace_id=w),
 assigned as(select v.id,a.user_id person from visible v join public.task_assignees a on a.task_id=v.id union select id,assignee_id from visible where assignee_id is not null union select v.id,null::uuid from visible v where v.assignee_id is null and not exists(select 1 from public.task_assignees a where a.task_id=v.id)),
 people as(select coalesce(person::text,'') person,count(*) n from assigned group by person)
 select jsonb_build_object('total',count(*),'progress',count(*) filter(where status='progress'),'done',count(*) filter(where status='done'),
 'overdue',count(*) filter(where due<current_date and status not in ('done','canceled')),'todo',count(*) filter(where status='todo'),'blocked',count(*) filter(where status='blocked'),
 'canceled',count(*) filter(where status='canceled'),'people',(select coalesce(jsonb_object_agg(person,n),'{}') from people)) from visible
$$;
revoke all on function public.workspace_counts(uuid) from public,anon;
grant execute on function public.workspace_counts(uuid) to authenticated;
commit;
