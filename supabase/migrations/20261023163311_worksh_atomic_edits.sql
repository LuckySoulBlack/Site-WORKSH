begin;
create function public.apply_changes(changes jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare c jsonb; tbl text; op text; v jsonb; allowed text[]; cols text; assigns text; result jsonb; output jsonb='[]'; rid uuid;
begin
 if not private.ready() then raise exception 'Troque sua senha antes de continuar.' using errcode='42501'; end if;
 if jsonb_typeof(changes)<>'array' or jsonb_array_length(changes)>100 or octet_length(changes::text)>262144 then raise exception 'Lote inválido'; end if;
 for c in select * from jsonb_array_elements(changes) loop
  tbl=c->>'table';op=c->>'op';v=c->'values';rid=(c->>'id')::uuid;
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
     when 'profiles' then array['full_name','phone','job','theme']
     when 'workspaces' then array['name','description','modules','company']
     when 'boards' then array['name','description']
     when 'groups' then array['name','position']
     when 'tasks' then array['group_id','title','description','link_url','status','position','due','priority','checklist','assignee_id']
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
  output=output||jsonb_build_array(jsonb_build_object('table',tbl,'id',result->>'id','updated_at',result->>'updated_at'));
 end loop;
 return output;
end $$;
revoke all on function public.apply_changes(jsonb) from public,anon;
grant execute on function public.apply_changes(jsonb) to authenticated;
commit;
