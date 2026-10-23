-- WORKSH / Parte 1 de 6 / projeto zazkecvrjmtbvmylxgij.
-- Somente preparação: aplicar junto da Parte 2, antes de conceder acesso ao cliente.
-- Instaladas: supabase_vault 0.3.1, pgcrypto 1.3, uuid-ossp 1.1.
-- Disponíveis: pgmq 1.5.1, pg_cron 1.6.4, pg_net 0.20.4; supa_audit ausente.
-- Origem publicada: https://luckysoulblack.github.io
begin;

-- Perfil associado à identidade Supabase Auth.
create table public.profiles (
 id uuid primary key references auth.users(id) on delete restrict,
 full_name text not null default '',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

-- Workspace com proprietário único e referência privada ao segredo do Drive.
create table public.workspaces (
 id uuid primary key default gen_random_uuid(),
 name text not null check (length(btrim(name)) between 1 and 200),
 owner_id uuid not null references auth.users(id) on delete restrict,
 drive_folder_id text,
 drive_secret_id uuid references vault.secrets(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(id, owner_id)
);
create index workspaces_owner_idx on public.workspaces(owner_id);
create index workspaces_secret_idx on public.workspaces(drive_secret_id) where drive_secret_id is not null;

-- Participação no workspace; flags de segurança serão protegidas na Parte 2.
create table public.workspace_members (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete restrict,
 role text not null default 'member' check (role in ('owner','member')),
 must_change_password boolean not null default true,
 invited_by uuid references auth.users(id) on delete restrict,
 joined_at timestamptz not null default now(),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(workspace_id,user_id)
);
create index workspace_members_user_idx on public.workspace_members(user_id);
create index workspace_members_inviter_idx on public.workspace_members(invited_by);
create unique index workspace_members_one_owner_idx on public.workspace_members(workspace_id) where role='owner';
-- workspaces.owner_id é a fonte de verdade; sincronização do papel owner entra na Parte 2/3.

-- Board pertence a exatamente um workspace.
create table public.boards (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 name text not null check (length(btrim(name)) between 1 and 200),
 description text not null default '',
 created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(workspace_id,id)
);
create index boards_creator_idx on public.boards(created_by);
create index boards_page_idx on public.boards(workspace_id,created_at,id);

-- Acesso explícito ao board exige participação no mesmo workspace.
create table public.board_members (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null,
 board_id uuid not null,
 user_id uuid not null,
 can_edit boolean not null default true,
 granted_by uuid not null references auth.users(id) on delete restrict,
 granted_at timestamptz not null default now(),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 foreign key(workspace_id,board_id) references public.boards(workspace_id,id) on delete cascade,
 foreign key(workspace_id,user_id) references public.workspace_members(workspace_id,user_id) on delete cascade,
 unique(board_id,user_id)
);
create index board_members_user_idx on public.board_members(user_id);
create index board_members_workspace_user_idx on public.board_members(workspace_id,user_id);
create index board_members_workspace_board_idx on public.board_members(workspace_id,board_id);
create index board_members_granter_idx on public.board_members(granted_by);

-- Grupo de organização restrito ao respectivo board.
create table public.groups (
 id uuid primary key default gen_random_uuid(),
 board_id uuid not null references public.boards(id) on delete cascade,
 name text not null check(length(btrim(name)) between 1 and 200),
 position bigint not null default 0,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(board_id,id)
);
create index groups_position_idx on public.groups(board_id,position,id);

-- Tarefa cujo grupo opcional deve pertencer ao mesmo board.
create table public.tasks (
 id uuid primary key default gen_random_uuid(),
 board_id uuid not null references public.boards(id) on delete cascade,
 group_id uuid,
 title text not null check(length(btrim(title)) between 1 and 500),
 description text not null default '',
 link_url text,
 status text not null default 'todo' check(status in ('todo','progress','blocked','done')),
 position bigint not null default 0,
 created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 foreign key(board_id,group_id) references public.groups(board_id,id) on delete set null (group_id),
 unique(board_id,id)
);
create index tasks_status_idx on public.tasks(board_id,status,created_at,id);
create index tasks_page_idx on public.tasks(board_id,created_at,id);
create index tasks_group_idx on public.tasks(group_id);
create index tasks_creator_idx on public.tasks(created_by);

-- Comentário vinculado a uma tarefa do mesmo board.
create table public.comments (
 id uuid primary key default gen_random_uuid(),
 board_id uuid not null,
 task_id uuid not null,
 author_id uuid not null references auth.users(id) on delete restrict,
 content text not null check(length(btrim(content)) between 1 and 10000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 foreign key(board_id,task_id) references public.tasks(board_id,id) on delete cascade
);
create index comments_task_idx on public.comments(task_id,created_at,id);
create index comments_board_task_idx on public.comments(board_id,task_id);
create index comments_author_idx on public.comments(author_id);

-- Configurações por chave, sem credenciais ou regras de autorização.
create table public.board_settings (
 id uuid primary key default gen_random_uuid(),
 board_id uuid not null references public.boards(id) on delete cascade,
 key text not null check(length(btrim(key)) between 1 and 100),
 value jsonb not null default '{}'::jsonb check(octet_length(value::text)<=65536),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(board_id,key)
);

-- Metadados de arquivo no Drive; nenhum conteúdo binário fica no banco.
create table public.attachments (
 id uuid primary key default gen_random_uuid(),
 board_id uuid not null references public.boards(id) on delete cascade,
 task_id uuid,
 file_name text not null check(length(btrim(file_name)) between 1 and 255),
 mime text not null,
 size_bytes bigint not null check(size_bytes between 1 and 5242880),
 drive_file_id text not null unique,
 uploaded_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 foreign key(board_id,task_id) references public.tasks(board_id,id) on delete set null (task_id)
);
create index attachments_task_idx on public.attachments(task_id);
create index attachments_board_idx on public.attachments(board_id,task_id);
create index attachments_uploader_idx on public.attachments(uploaded_by);

-- Convite guarda somente hash do token e destino autorizado.
create table public.invitations (
 id uuid primary key default gen_random_uuid(),
 token_hash text not null unique,
 email text not null check(email=lower(btrim(email)) and length(email) between 3 and 320),
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 board_id uuid,
 invited_by uuid not null references auth.users(id) on delete restrict,
 expires_at timestamptz not null,
 accepted_at timestamptz,
 revoked_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check(expires_at>created_at),
 foreign key(workspace_id,board_id) references public.boards(workspace_id,id) on delete cascade
);
create index invitations_email_idx on public.invitations(email);
create index invitations_workspace_board_idx on public.invitations(workspace_id,board_id);
create index invitations_inviter_idx on public.invitations(invited_by);

-- Job de upload contém referência temporária e estado durável para repetição segura.
create table public.upload_jobs (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null,
 owner_id uuid not null,
 board_id uuid not null,
 user_id uuid not null references auth.users(id) on delete restrict,
 storage_path text not null unique,
 file_name text not null check(length(btrim(file_name)) between 1 and 255),
 mime text not null,
 size_bytes bigint not null check(size_bytes between 1 and 5242880),
 status text not null default 'pending' check(status in ('pending','uploading','done','failed','dead')),
 attempts integer not null default 0 check(attempts>=0),
 last_error text,
 drive_file_id text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 foreign key(workspace_id,owner_id) references public.workspaces(id,owner_id) on delete cascade,
 foreign key(workspace_id,board_id) references public.boards(workspace_id,id) on delete cascade
);
create index upload_jobs_status_idx on public.upload_jobs(status,created_at,id);
create index upload_jobs_user_idx on public.upload_jobs(user_id,created_at,id);
create index upload_jobs_owner_idx on public.upload_jobs(owner_id);
create index upload_jobs_workspace_owner_idx on public.upload_jobs(workspace_id,owner_id);
create index upload_jobs_workspace_board_idx on public.upload_jobs(workspace_id,board_id);

-- Histórico preserva identidade do registro removido e snapshots sem segredos.
create table public.audit_events (
 id bigserial primary key,
 table_name text not null,
 record_id uuid not null,
 action text not null check(action in ('INSERT','UPDATE','DELETE')),
 old_data jsonb,
 new_data jsonb,
 actor_id uuid references auth.users(id) on delete set null,
 workspace_id uuid references public.workspaces(id) on delete set null,
 board_id uuid references public.boards(id) on delete set null,
 workspace_ref uuid not null,
 board_ref uuid,
 created_at timestamptz not null default now()
);
-- record_id/workspace_ref/board_ref são identidades históricas imutáveis, sem FK destrutiva.
-- A Parte 2 deriva referências; cliente não escreve nem lê histórico de tenant removido.
create index audit_events_workspace_idx on public.audit_events(workspace_id,created_at,id);
create index audit_events_board_idx on public.audit_events(board_id,created_at,id);
create index audit_events_actor_idx on public.audit_events(actor_id);

-- Estado OAuth de uso único vinculado à identidade e ao workspace solicitante.
create table public.oauth_states (
 id uuid primary key default gen_random_uuid(),
 state_hash text not null unique,
 user_id uuid not null references auth.users(id) on delete restrict,
 workspace_id uuid not null references public.workspaces(id) on delete cascade,
 expires_at timestamptz not null,
 used_at timestamptz,
 created_at timestamptz not null default now(),
 check(expires_at>created_at)
);
create index oauth_states_user_idx on public.oauth_states(user_id);
create index oauth_states_workspace_idx on public.oauth_states(workspace_id);
create index oauth_states_expiry_idx on public.oauth_states(expires_at);

-- Sem RLS nesta parte: negar privilégios até a Parte 2 conceder acesso seguro.
revoke all on table public.profiles, public.workspaces, public.workspace_members,
 public.boards, public.board_members, public.groups, public.tasks, public.comments,
 public.board_settings, public.attachments, public.invitations, public.upload_jobs,
 public.audit_events, public.oauth_states from public, anon, authenticated;
revoke all on sequence public.audit_events_id_seq from public, anon, authenticated;
commit;

-- CHECKPOINT: arquivo entregue: supabase/migrations/001_schema.sql.
-- Fora propositalmente: RLS, policies, helpers SECURITY DEFINER, triggers, RPCs.
-- Não aplicado ao Supabase; frontend e localStorage preservados.
-- Próxima parte: PARTE 2 — RLS, Policies, Helpers e Triggers.

begin;
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;
create table private.account_security (
 user_id uuid primary key references auth.users(id) on delete cascade,
 must_change_password boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table private.account_security enable row level security;
revoke all on private.account_security from public, anon, authenticated;

create function private.ready() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from private.account_security where user_id=auth.uid() and not must_change_password)
$$;
create function private.is_workspace_owner(ws uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.ready() and exists(select 1 from public.workspaces where id=ws and owner_id=auth.uid())
$$;
create function private.is_board_member(b uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.ready() and exists(select 1 from public.boards x where x.id=b and
 (private.is_workspace_owner(x.workspace_id) or exists(select 1 from public.board_members m
 join public.workspace_members w on w.workspace_id=m.workspace_id and w.user_id=m.user_id
 where m.board_id=x.id and m.user_id=auth.uid() and not w.must_change_password)))
$$;
create function private.is_board_editor(b uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.is_board_member(b) and exists(select 1 from public.boards x where x.id=b and
 (private.is_workspace_owner(x.workspace_id) or exists(select 1 from public.board_members m where m.board_id=b and m.user_id=auth.uid() and m.can_edit)))
$$;
create function private.owns_board(b uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.boards where id=b and private.is_workspace_owner(workspace_id))
$$;
create function private.workspace_visible(ws uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.ready() and (private.is_workspace_owner(ws) or exists(select 1 from public.workspace_members where workspace_id=ws and user_id=auth.uid() and not must_change_password))
$$;
revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.ready(),private.is_workspace_owner(uuid),private.is_board_member(uuid),private.is_board_editor(uuid),private.owns_board(uuid),private.workspace_visible(uuid) to authenticated;

create function private.new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id,full_name) values(new.id, left(coalesce(new.raw_user_meta_data->>'full_name',''),200));
 insert into private.account_security(user_id) values(new.id);
 return new;
end $$;
create trigger worksh_new_user after insert on auth.users for each row execute function private.new_user();
insert into public.profiles(id) select id from auth.users on conflict do nothing;
insert into private.account_security(user_id) select id from auth.users on conflict do nothing;

create function private.guard_row() returns trigger language plpgsql set search_path='' as $$
declare o jsonb; n jsonb; k text;
begin
 if tg_op='UPDATE' then
  o=to_jsonb(old); n=to_jsonb(new);
  foreach k in array array['id','workspace_id','board_id','owner_id','created_by','author_id','uploaded_by','user_id','granted_by','invited_by','created_at'] loop
   if o->k is distinct from n->k then raise exception 'Immutable field: %',k using errcode='42501'; end if;
  end loop;
  if tg_table_name='workspace_members' and (o->'must_change_password' is distinct from n->'must_change_password')
   and current_user <> 'postgres' then raise exception 'Password state is backend controlled' using errcode='42501'; end if;
 end if;
 new.updated_at=now(); return new;
end $$;

create function private.audit_row_change() returns trigger language plpgsql security definer set search_path='' as $$
declare r jsonb; w uuid; b uuid; uid uuid; oldsafe jsonb; newsafe jsonb;
begin
 r=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 uid=auth.uid();
 b=case when tg_table_name='boards' then (r->>'id')::uuid else (r->>'board_id')::uuid end;
 w=case when tg_table_name='workspaces' then (r->>'id')::uuid else (r->>'workspace_id')::uuid end;
 if w is null and b is not null then select workspace_id into w from public.boards where id=b; end if;
 -- Cascaded children whose board was deleted have a parent deletion snapshot already recorded.
 if w is null then return null; end if;
 if tg_op<>'INSERT' then oldsafe=to_jsonb(old)-array['drive_secret_id','must_change_password']; end if;
 if tg_op<>'DELETE' then newsafe=to_jsonb(new)-array['drive_secret_id','must_change_password']; end if;
 insert into public.audit_events(table_name,record_id,action,old_data,new_data,actor_id,workspace_id,board_id,workspace_ref,board_ref)
 values(tg_table_name,(r->>'id')::uuid,tg_op,oldsafe,newsafe,uid,
 (select id from public.workspaces where id=w),(select id from public.boards where id=b),w,b);
 return null;
end $$;

do $$ declare t text; begin
 foreach t in array array['profiles','workspaces','workspace_members','boards','board_members','groups','tasks','comments','board_settings','attachments','invitations','upload_jobs','audit_events','oauth_states'] loop
  execute format('alter table public.%I enable row level security',t);
  if t not in ('audit_events','oauth_states') then execute format('create trigger guard_update before insert or update on public.%I for each row execute function private.guard_row()',t); end if;
 end loop;
 foreach t in array array['workspaces','workspace_members','boards','board_members','groups','tasks','comments','board_settings','attachments'] loop
  execute format('create trigger history after insert or update or delete on public.%I for each row execute function private.audit_row_change()',t);
 end loop;
end $$;

grant select on public.profiles,public.workspace_members,public.boards,public.board_members,public.groups,public.tasks,public.comments,public.board_settings,public.attachments,public.upload_jobs,public.audit_events to authenticated;
grant select(id,name,owner_id,drive_folder_id,created_at,updated_at) on public.workspaces to authenticated;
grant update(full_name) on public.profiles to authenticated;
create policy profile_read on public.profiles for select to authenticated using(id=(select auth.uid()));
create policy profile_edit on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy workspace_read on public.workspaces for select to authenticated using(private.workspace_visible(id));
create policy workspace_edit on public.workspaces for update to authenticated using(private.is_workspace_owner(id)) with check(private.is_workspace_owner(id));
create policy workspace_delete on public.workspaces for delete to authenticated using(private.is_workspace_owner(id));
grant update(name),delete on public.workspaces to authenticated;
create policy membership_read on public.workspace_members for select to authenticated using(user_id=(select auth.uid()) or private.is_workspace_owner(workspace_id));
create policy board_members_read on public.board_members for select to authenticated using(user_id=(select auth.uid()) or private.is_workspace_owner(workspace_id));
create policy board_read on public.boards for select to authenticated using(private.is_board_member(id));
create policy board_insert on public.boards for insert to authenticated with check(private.is_workspace_owner(workspace_id) and created_by=(select auth.uid()));
create policy board_update on public.boards for update to authenticated using(private.is_board_editor(id)) with check(private.is_board_editor(id));
create policy board_delete on public.boards for delete to authenticated using(private.owns_board(id));
grant insert(id,workspace_id,name,description,created_by),update(name,description),delete on public.boards to authenticated;
do $$ declare t text; begin
 foreach t in array array['groups','tasks','comments','board_settings','attachments'] loop
 execute format('create policy content_read on public.%I for select to authenticated using(private.is_board_member(board_id))',t);
 execute format('create policy content_insert on public.%I for insert to authenticated with check(private.is_board_editor(board_id))',t);
 execute format('create policy content_update on public.%I for update to authenticated using(private.is_board_editor(board_id)) with check(private.is_board_editor(board_id))',t);
 execute format('create policy content_delete on public.%I for delete to authenticated using(private.owns_board(board_id))',t);
 end loop;
end $$;
-- Attachment mutations only through worker/owner deletion endpoint, never forged Drive IDs.
grant insert(id,board_id,name,position),update(name,position),delete on public.groups to authenticated;
grant insert(id,board_id,group_id,title,description,link_url,status,position,created_by),update(group_id,title,description,link_url,status,position),delete on public.tasks to authenticated;
grant insert(id,board_id,task_id,author_id,content),update(content),delete on public.comments to authenticated;
grant insert(id,board_id,key,value),update(value),delete on public.board_settings to authenticated;
create policy task_actor on public.tasks as restrictive for insert to authenticated with check(created_by=(select auth.uid()));
create policy comment_actor on public.comments as restrictive for insert to authenticated with check(author_id=(select auth.uid()));
create policy job_read on public.upload_jobs for select to authenticated using(private.is_workspace_owner(workspace_id) or (user_id=(select auth.uid()) and private.is_board_member(board_id)));
create policy invitation_read on public.invitations for select to authenticated using(private.is_workspace_owner(workspace_id));
grant select(id,email,workspace_id,board_id,invited_by,expires_at,accepted_at,revoked_at,created_at,updated_at) on public.invitations to authenticated;
create policy audit_read on public.audit_events for select to authenticated using(private.is_workspace_owner(workspace_id) or (private.is_board_member(board_id) and actor_id=(select auth.uid())));
grant all on all tables in schema public to service_role;
grant usage,select on sequence public.audit_events_id_seq to service_role;
revoke all on function private.new_user(),private.guard_row(),private.audit_row_change() from public,anon,authenticated;
commit;

