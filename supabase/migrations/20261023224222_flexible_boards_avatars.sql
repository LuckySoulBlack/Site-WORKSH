begin;
alter table public.profiles add column avatar_path text check(avatar_path is null or avatar_path like id::text||'/%');
alter table public.tasks add column start_date date,add column custom_values jsonb not null default '{}'::jsonb check(jsonb_typeof(custom_values)='object' and octet_length(custom_values::text)<=32768);
alter table public.tasks add constraint tasks_date_range check(start_date is null or due is null or start_date<=due);
grant update(avatar_path) on public.profiles to authenticated;
grant insert(start_date,custom_values),update(start_date,custom_values) on public.tasks to authenticated;
create function public.board_features() returns boolean language sql immutable as $$select true$$;
revoke all on function public.board_features() from public,anon;
grant execute on function public.board_features() to authenticated;
create function private.board_people(b uuid) returns table(id uuid,full_name text,avatar_path text)
language sql stable security definer set search_path='' as $$
select p.id,p.full_name,p.avatar_path from public.profiles p where private.is_board_member(b) and
(p.id in(select user_id from public.board_members where board_id=b) or p.id in(select w.owner_id from public.workspaces w join public.boards x on x.workspace_id=w.id where x.id=b))
$$;
revoke all on function private.board_people(uuid) from public,anon;
grant execute on function private.board_people(uuid) to authenticated;
create function public.board_people(b uuid) returns table(id uuid,full_name text,avatar_path text)
language sql stable security invoker set search_path='' as $$select * from private.board_people(b)$$;
revoke all on function public.board_people(uuid) from public,anon;
grant execute on function public.board_people(uuid) to authenticated;
-- Profile photos are private application identity assets; board attachments remain on owner's Drive.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-photos','profile-photos',false,1048576,array['image/jpeg','image/png','image/webp']);
create function private.can_read_avatar(object_name text) returns boolean language sql stable security definer set search_path='' as $$
select private.ready() and exists(select 1 from public.profiles p where p.avatar_path=object_name and
(p.id=auth.uid() or exists(select 1 from public.boards b where private.is_board_member(b.id) and
(p.id in(select user_id from public.board_members where board_id=b.id) or p.id in(select owner_id from public.workspaces where id=b.workspace_id)))))
$$;
revoke all on function private.can_read_avatar(text) from public,anon;
grant execute on function private.can_read_avatar(text) to authenticated;
create policy worksh_avatar_read on storage.objects for select to authenticated using(bucket_id='profile-photos' and private.ready() and ((storage.foldername(name))[1]=(select auth.uid())::text or private.can_read_avatar(name)));
create policy worksh_avatar_insert on storage.objects for insert to authenticated with check(bucket_id='profile-photos' and private.ready() and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy worksh_avatar_update on storage.objects for update to authenticated using(bucket_id='profile-photos' and private.ready() and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='profile-photos' and private.ready() and (storage.foldername(name))[1]=(select auth.uid())::text);
create or replace function public.apply_changes(changes jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
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
  output=output||jsonb_build_array(jsonb_build_object('table',tbl,'id',result->>'id','updated_at',result->>'updated_at'));
 end loop;
 return output;
end $$;
revoke all on function public.apply_changes(jsonb) from public,anon;
grant execute on function public.apply_changes(jsonb) to authenticated;

-- Validate configurable schemas and typed values on the server, independently of UI.
create function private.validate_flexible_board() returns trigger language plpgsql security definer set search_path='' as $$
declare c jsonb; v jsonb; cols jsonb; kind text; identifier text;
begin
 if tg_table_name='board_settings' then
  if new.key<>'columns' then return new;end if;
  cols=new.value->'columns';
  if jsonb_typeof(cols) is distinct from 'array' or jsonb_array_length(cols)>40 then raise exception 'Colunas inválidas';end if;
  if (select count(*) from jsonb_array_elements(cols))<>(select count(distinct x->>'id') from jsonb_array_elements(cols) x) then raise exception 'Identificadores de coluna duplicados';end if;
  for c in select * from jsonb_array_elements(cols) loop
   if coalesce(c->>'id','')!~'^[a-z][a-z0-9_]{0,70}$' or length(coalesce(c->>'name','')) not between 1 and 100 or coalesce(c->>'type','') not in ('text','number','currency','percent','date','person','status','link','checkbox','dropdown','files','extract','doc','formula','boards','timeline','priority') then raise exception 'Modelo de coluna inválido';end if;
   if c->>'type'='formula' and length(coalesce(c->>'expression','')) not between 1 and 500 then raise exception 'Expressão inválida';end if;
   if c?'options' and (jsonb_typeof(c->'options')<>'array' or jsonb_array_length(c->'options')>30) then raise exception 'Opções inválidas';end if;
  end loop;
  return new;
 end if;
 select value->'columns' into cols from public.board_settings where board_id=new.board_id and key='columns';
 for c in select * from jsonb_array_elements(coalesce(cols,'[]'::jsonb)) loop
  identifier=c->>'id';kind=c->>'type';v=new.custom_values->identifier;
  if v is null or v='null'::jsonb or v='""'::jsonb then continue;end if;
  if kind in ('number','currency','percent') and jsonb_typeof(v)<>'number' then raise exception 'Valor numérico inválido';end if;
  if kind='percent' and ((v#>>'{}')::numeric<0 or (v#>>'{}')::numeric>100) then raise exception 'Percentual deve estar entre 0 e 100';end if;
  if kind='checkbox' and jsonb_typeof(v)<>'boolean' then raise exception 'Confirmação inválida';end if;
  if kind in ('text','doc','extract','date','link','person','boards','status','priority','dropdown') and jsonb_typeof(v)<>'string' then raise exception 'Texto inválido';end if;
  if kind in ('text','doc','extract') and length(v#>>'{}')>12000 then raise exception 'Texto muito longo';end if;
  if kind='status' and (v#>>'{}') not in ('todo','progress','blocked','done') then raise exception 'Status inválido';end if;
  if kind='priority' and (v#>>'{}') not in ('low','normal','high','urgent') then raise exception 'Prioridade inválida';end if;
  if kind='date' then perform (v#>>'{}')::date;end if;
  if kind='person' and not exists(select 1 from public.boards b join public.workspaces w on w.id=b.workspace_id where b.id=new.board_id and (w.owner_id=(v#>>'{}')::uuid or exists(select 1 from public.board_members m where m.board_id=b.id and m.user_id=(v#>>'{}')::uuid))) then raise exception 'Pessoa fora do quadro';end if;
  if kind='boards' and not private.is_board_member((v#>>'{}')::uuid) then raise exception 'Quadro não autorizado';end if;
  if kind='timeline' then
   if jsonb_typeof(v)<>'object' then raise exception 'Cronograma inválido';end if;
   if nullif(v->>'start','') is not null then perform (v->>'start')::date;end if;
   if nullif(v->>'end','') is not null then perform (v->>'end')::date;end if;
   if nullif(v->>'start','')::date>nullif(v->>'end','')::date then raise exception 'Período inválido';end if;
  end if;
 end loop;
 return new;
end$$;
revoke all on function private.validate_flexible_board() from public,anon,authenticated,service_role;
create trigger validate_flexible_columns before insert or update on public.board_settings for each row execute function private.validate_flexible_board();
create trigger validate_flexible_cells before insert or update of custom_values on public.tasks for each row execute function private.validate_flexible_board();
commit;
