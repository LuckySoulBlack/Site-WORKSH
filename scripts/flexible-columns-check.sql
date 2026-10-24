-- Run inside the editable-member fixture of flexible-boards-check.sql after inserting the column setting.
update public.board_settings set value=jsonb_build_object('columns',(value->'columns')||(select jsonb_agg(jsonb_build_object('id','c_test_'||n,'name','Column '||n,'type','percent','source','checklist')) from generate_series(1,60) n)) where key='columns';
do $$begin if (select jsonb_array_length(value->'columns') from public.board_settings where key='columns')<>61 then raise exception 'Columns truncated';end if;end$$;
