begin;
create or replace function private.validate_flexible_board() returns trigger language plpgsql security definer set search_path='' as $$
declare c jsonb; v jsonb; cols jsonb; kind text; identifier text;
begin
 if tg_table_name='board_settings' then
  if new.key<>'columns' then return new;end if;
  cols=new.value->'columns';
  if jsonb_typeof(cols) is distinct from 'array' then raise exception 'Colunas inválidas';end if;
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
  if kind='status' and (v#>>'{}') not in ('todo','progress','blocked','done','canceled') then raise exception 'Status inválido';end if;
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
commit;
