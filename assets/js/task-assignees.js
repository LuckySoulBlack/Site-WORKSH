import {client,unwrap} from './supabase-client.js';
export async function readTaskAssignees(ids){
 const result=[];for(let start=0;start<ids.length;start+=50){const batch=ids.slice(start,start+50);for(let offset=0;offset<=5000;offset+=1000){const rows=await unwrap(client().from('task_assignees').select('task_id,user_id').in('task_id',batch).order('task_id').order('user_id').range(offset,offset+999));result.push(...rows);if(rows.length<1000)break;if(offset===5000)throw Error('Não foi possível carregar todos os responsáveis.');}}
 return result;
}
