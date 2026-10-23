begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('company-logos','company-logos',false,1048576,array['image/png','image/jpeg','image/webp']);
create function private.company_asset_access(object_name text,editing boolean default false) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.workspaces w where w.id::text=(storage.foldername(object_name))[1] and
(case when editing then private.is_workspace_owner(w.id) else private.workspace_visible(w.id) end))
$$;
revoke all on function private.company_asset_access(text,boolean) from public,anon;
grant execute on function private.company_asset_access(text,boolean) to authenticated;
create policy company_logo_read on storage.objects for select to authenticated using(bucket_id='company-logos' and private.company_asset_access(name,false));
create policy company_logo_insert on storage.objects for insert to authenticated with check(bucket_id='company-logos' and private.company_asset_access(name,true));
create policy company_logo_update on storage.objects for update to authenticated using(bucket_id='company-logos' and private.company_asset_access(name,true)) with check(bucket_id='company-logos' and private.company_asset_access(name,true));

create table private.project_shares(
 id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces(id) on delete cascade,
 board_id uuid not null,owner_id uuid not null references auth.users(id),token_hash text not null unique check(length(token_hash)=64),
 view_type text not null check(view_type in ('table','kanban','gantt')),include_people boolean not null default false,
 expires_at timestamptz not null,revoked_at timestamptz,created_at timestamptz not null default now(),
 foreign key(workspace_id,board_id) references public.boards(workspace_id,id) on delete cascade
);
alter table private.project_shares enable row level security;
revoke all on private.project_shares from public,anon,authenticated;
create index project_shares_board_idx on private.project_shares(board_id,created_at);
create index project_shares_workspace_board_idx on private.project_shares(workspace_id,board_id);
create index project_shares_owner_idx on private.project_shares(owner_id);

create function private.create_project_share(board uuid,view_type text,include_people boolean default false,days integer default 7) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w uuid;token text;s private.project_shares;
begin
 select workspace_id into w from public.boards where id=board;
 if not coalesce(private.is_workspace_owner(w),false) then raise insufficient_privilege;end if;
 if view_type not in ('table','kanban','gantt') or days not between 1 and 30 or days is null then raise exception 'Configuração inválida';end if;
 if (select count(*) from private.project_shares where board_id=board and revoked_at is null and expires_at>now())>=20 then raise exception 'Revogue um dos links ativos antes de criar outro.';end if;
 if (select count(*) from (select id from public.tasks where board_id=board limit 5001) t)>5000 then raise exception 'Projeto excede o limite de 5000 tarefas para esta visualização externa.';end if;
 token=encode(extensions.gen_random_bytes(32),'hex');
 insert into private.project_shares(workspace_id,board_id,owner_id,token_hash,view_type,include_people,expires_at)
 values(w,board,auth.uid(),encode(extensions.digest(token,'sha256'),'hex'),view_type,coalesce(include_people,false),now()+days*interval '1 day') returning * into s;
 return jsonb_build_object('id',s.id,'token',token,'expires_at',s.expires_at);
end$$;
create function private.list_project_shares(board uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.owns_board(board) or not private.ready() then raise insufficient_privilege;end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'view_type',s.view_type,'include_people',s.include_people,'expires_at',s.expires_at,'revoked_at',s.revoked_at,'created_at',s.created_at) order by s.created_at desc),'[]') from private.project_shares s where s.board_id=board);
end$$;
create function private.revoke_project_share(share_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare w uuid;
begin
 select workspace_id into w from private.project_shares where id=share_id;
 if not coalesce(private.is_workspace_owner(w),false) then raise insufficient_privilege;end if;
 update private.project_shares set revoked_at=coalesce(revoked_at,now()) where id=share_id;return true;
end$$;
create function public.create_project_share(board uuid,view_type text,include_people boolean default false,days integer default 7) returns jsonb language sql security invoker set search_path='' as $$select private.create_project_share(board,view_type,include_people,days)$$;
create function public.list_project_shares(board uuid) returns jsonb language sql security invoker set search_path='' as $$select private.list_project_shares(board)$$;
create function public.revoke_project_share(share_id uuid) returns boolean language sql security invoker set search_path='' as $$select private.revoke_project_share(share_id)$$;
revoke all on function private.create_project_share(uuid,text,boolean,integer),private.list_project_shares(uuid),private.revoke_project_share(uuid),public.create_project_share(uuid,text,boolean,integer),public.list_project_shares(uuid),public.revoke_project_share(uuid) from public,anon;
grant execute on function private.create_project_share(uuid,text,boolean,integer),private.list_project_shares(uuid),private.revoke_project_share(uuid),public.create_project_share(uuid,text,boolean,integer),public.list_project_shares(uuid),public.revoke_project_share(uuid) to authenticated;

-- Deliberately limited read capability. Never returns internal documents, contacts, tokens or files.
create function private.read_shared_project(token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare s private.project_shares;result jsonb;
begin
 if token is null or token!~'^[0-9a-f]{64}$' then raise exception 'Link inválido, expirado ou revogado.' using errcode='42501';end if;
 select * into s from private.project_shares where token_hash=encode(extensions.digest(token,'sha256'),'hex') and revoked_at is null and expires_at>now();
 if not found or not exists(select 1 from private.account_security a where a.user_id=s.owner_id and not a.must_change_password and not a.is_blocked) then raise exception 'Link inválido, expirado ou revogado.' using errcode='42501';end if;
 if (select count(*) from (select id from public.tasks where board_id=s.board_id limit 5001) t)>5000 then raise exception 'A visualização externa excedeu o limite de tarefas.';end if;
 select jsonb_build_object('title',b.name,'companyName',coalesce(w.company->>'name',''),'view',s.view_type,'includePeople',s.include_people,'generatedAt',now(),'expiresAt',s.expires_at,'live',true,
 'tasks',coalesce((select jsonb_agg(jsonb_build_object('title',t.title,'status',t.status,'start_date',t.start_date,'due',t.due)||case when s.include_people then jsonb_build_object('assignee',(select p.full_name from public.profiles p where p.id=t.assignee_id)) else '{}'::jsonb end order by t.position,t.created_at,t.id) from public.tasks t where t.board_id=b.id),'[]'))
 into result from public.boards b join public.workspaces w on w.id=b.workspace_id where b.id=s.board_id and w.owner_id=s.owner_id;
 if result is null then raise exception 'Link inválido, expirado ou revogado.' using errcode='42501';end if;return result;
end$$;
revoke all on function private.read_shared_project(text) from public,anon,authenticated,service_role;
-- The public definer wrapper delegates to the token gate without granting anon access to the private schema.
create function public.read_shared_project(token text) returns jsonb language sql security definer set search_path='' as $$select private.read_shared_project(token)$$;
revoke all on function public.read_shared_project(text) from public;
grant execute on function public.read_shared_project(text) to anon,authenticated;
create function private.audit_project_share() returns trigger language plpgsql security definer set search_path='' as $$
declare n jsonb; o jsonb;begin
 n=to_jsonb(new)-'token_hash';if tg_op='UPDATE' then o=to_jsonb(old)-'token_hash';end if;
 insert into public.audit_events(table_name,record_id,action,old_data,new_data,actor_id,workspace_id,board_id,workspace_ref,board_ref)
 values('project_shares',new.id,tg_op,o,n,auth.uid(),new.workspace_id,new.board_id,new.workspace_id,new.board_id);return null;
end$$;
revoke all on function private.audit_project_share() from public,anon,authenticated,service_role;
create trigger audit_project_share after insert or update of revoked_at on private.project_shares for each row execute function private.audit_project_share();
create function private.validate_company_identity() returns trigger language plpgsql set search_path='' as $$
begin
 if new.company?'logo_url' then raise exception 'A logo deve ser salva como arquivo, não como URL temporária.';end if;
 if nullif(new.company->>'logo_path','') is not null and new.company->>'logo_path' not like new.id::text||'/%' then raise exception 'Logo fora do ambiente da empresa.';end if;
 if new.company?'accent' and coalesce(new.company->>'accent','')!~'^#[0-9a-fA-F]{6}$' then raise exception 'Cor inválida.';end if;
 return new;
end$$;
revoke all on function private.validate_company_identity() from public,anon,authenticated,service_role;
create trigger validate_company_identity before insert or update of company on public.workspaces for each row execute function private.validate_company_identity();
commit;
