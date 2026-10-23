import {client,unwrap,call} from './supabase-client.js';
export const workspaceColumns='id,name,owner_id,description,modules,company,drive_folder_id,created_at,updated_at';
export const taskColumns='id,board_id,group_id,title,description,link_url,status,position,created_by,created_at,updated_at,due,priority,checklist,assignee_id';
export async function page(table,columns,filters={},cursor=null,size=20){
 let q=client().from(table).select(columns);for(const [k,v]of Object.entries(filters))q=q.eq(k,v);
 if(cursor){if(!/^\d{4}-\d{2}-\d{2}T/.test(cursor.created_at)||!/^[\da-f-]+$/i.test(String(cursor.id)))throw Error('Cursor inválido.');q=q.or(`created_at.gt.${cursor.created_at},and(created_at.eq.${cursor.created_at},id.gt.${cursor.id})`);}
 return unwrap(q.order('created_at').order('id').limit(Math.min(100,size)));
}
export const listBoards=(workspace_id,cursor)=>page('boards','id,workspace_id,name,description,created_by,created_at,updated_at',{workspace_id},cursor);
export const listTasks=(board_id,cursor)=>page('tasks',taskColumns,{board_id},cursor);
export const listComments=(board_id,cursor)=>page('comments','id,board_id,task_id,author_id,content,created_at,updated_at',{board_id},cursor);
export async function boardAccess(board_id){return {members:await unwrap(client().from('board_members').select('user_id,can_edit,board_id').eq('board_id',board_id)),profiles:await call('shared_profiles',{b:board_id})};}
