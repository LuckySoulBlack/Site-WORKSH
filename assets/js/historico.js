import {page} from './boards.js';
export const history=(board_id,cursor)=>page('audit_events','id,table_name,record_id,action,old_data,new_data,actor_id,workspace_id,board_id,created_at',{board_id},cursor,50);
