insert into public.tasks(id,board_id,title,created_by) values
('aaaaaaaa-0000-4000-8000-000000000008','aaaaaaaa-0000-4000-8000-000000000006','Alterada','aaaaaaaa-0000-4000-8000-000000000001'),
('aaaaaaaa-0000-4000-8000-000000000009','aaaaaaaa-0000-4000-8000-000000000006','Com comentário','aaaaaaaa-0000-4000-8000-000000000001'),
('aaaaaaaa-0000-4000-8000-000000000010','aaaaaaaa-0000-4000-8000-000000000006','Rascunho','aaaaaaaa-0000-4000-8000-000000000001');
update public.tasks set title='Título alterado' where id='aaaaaaaa-0000-4000-8000-000000000008';
insert into public.comments(board_id,task_id,author_id,content) values('aaaaaaaa-0000-4000-8000-000000000006','aaaaaaaa-0000-4000-8000-000000000009','aaaaaaaa-0000-4000-8000-000000000001','Preservar');
set local role authenticated;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000002',true);
do $$declare n integer;begin
 if (select count(*) from public.deletable_task_rows(array['aaaaaaaa-0000-4000-8000-000000000007','aaaaaaaa-0000-4000-8000-000000000008','aaaaaaaa-0000-4000-8000-000000000009']::uuid[]))<>1 then raise exception 'Wrong eligibility';end if;
 delete from public.tasks where id='aaaaaaaa-0000-4000-8000-000000000007';get diagnostics n=row_count;if n<>1 then raise exception 'Editor cannot delete untouched row';end if;
 delete from public.tasks where id in('aaaaaaaa-0000-4000-8000-000000000008','aaaaaaaa-0000-4000-8000-000000000009');get diagnostics n=row_count;if n<>0 then raise exception 'Protected rows deleted';end if;
end$$;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000003',true);
do $$declare n integer;begin delete from public.tasks where id='aaaaaaaa-0000-4000-8000-000000000010';get diagnostics n=row_count;if n<>0 then raise exception 'Read-only user deleted row';end if;end$$;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000004',true);
do $$begin if exists(select 1 from public.deletable_task_rows(array['aaaaaaaa-0000-4000-8000-000000000010']::uuid[])) then raise exception 'Outsider can delete';end if;end$$;
select set_config('request.jwt.claim.sub','aaaaaaaa-0000-4000-8000-000000000001',true);
delete from public.boards where id='aaaaaaaa-0000-4000-8000-000000000006';
do $$begin if exists(select 1 from public.tasks) then raise exception 'Owner cascade broken';end if;end$$;
rollback;
