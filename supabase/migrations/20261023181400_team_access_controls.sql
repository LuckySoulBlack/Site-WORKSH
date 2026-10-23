begin;
create policy no_client_access on private.user_access_events for all to anon,authenticated using(false) with check(false);
alter policy profile_read on public.profiles using(id=(select auth.uid()) and (select private.ready()));
alter policy profile_edit on public.profiles using(id=(select auth.uid()) and (select private.ready())) with check(id=(select auth.uid()) and (select private.ready()));
create function private.add_team_member(board uuid,email_address text,editable boolean default true) returns void language plpgsql security definer set search_path='' as $$
declare ws uuid;target uuid; pending boolean;
begin
 if not private.owns_board(board) then raise insufficient_privilege; end if;
 select workspace_id into strict ws from public.boards where id=board;
 select u.id,s.must_change_password into target,pending from auth.users u join private.account_security s on s.user_id=u.id where lower(u.email)=lower(btrim(email_address)) and not s.is_blocked;
 if target is null then raise exception 'Conta indisponível. Cadastre o usuário antes de liberar o painel.'; end if;
 if exists(select 1 from public.workspaces where id=ws and owner_id=target) then return; end if;
 insert into public.workspace_members(workspace_id,user_id,role,must_change_password,invited_by) values(ws,target,'member',pending,auth.uid()) on conflict(workspace_id,user_id) do nothing;
 perform private.grant_board_access(board,target,editable);
end $$;
revoke all on function private.add_team_member(uuid,text,boolean) from public,anon;
grant execute on function private.add_team_member(uuid,text,boolean) to authenticated;
create function public.add_team_member(board uuid,email_address text,editable boolean default true) returns void language sql security invoker set search_path='' as $$select private.add_team_member(board,email_address,editable)$$;
revoke all on function public.add_team_member(uuid,text,boolean) from public,anon;
grant execute on function public.add_team_member(uuid,text,boolean) to authenticated;
commit;
