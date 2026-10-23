begin;
do $$ declare definition text;begin
 definition=pg_get_functiondef('private.enfileirar_upload(text,text,text,bigint,uuid,uuid)'::regprocedure);
 if position('on conflict(storage_path)' in definition)=0 then raise exception 'Expected upload function version not found';end if;
 execute replace(definition,'on conflict(storage_path)','on conflict on constraint upload_jobs_storage_path_key');
end $$;
commit;
