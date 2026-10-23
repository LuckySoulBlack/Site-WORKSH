begin;
create function public.backend_queue_pending(queue text) returns boolean language plpgsql security definer set search_path='' as $$
declare result boolean;
begin
 if queue not in ('email_invites','drive_uploads','background_tasks') then raise exception 'Invalid queue';end if;
 execute format('select exists(select 1 from pgmq.%I where vt<=now())','q_'||queue) into result;
 return result;
end $$;
revoke all on function public.backend_queue_pending(text) from public,anon,authenticated;
grant execute on function public.backend_queue_pending(text) to service_role;
commit;
