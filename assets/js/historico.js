import {page} from './boards.js';
import {call} from './supabase-client.js';
export {renderHistory} from './history-view.js?v=20261023.7';
export async function history(board_id,cursor){
 // Compatible with the database before and after author snapshots are installed.
 const rows=await page('audit_events','*',{board_id},cursor,50);
 const profiles=rows.some(row=>row.actor_id&&!row.actor_name)?await call('shared_profiles',{b:board_id}).catch(()=>[]):[];
 const names=new Map(profiles.map(p=>[p.id,p.full_name]));
 return rows.map(row=>({...row,actor_name:row.actor_name||names.get(row.actor_id)||null}));
}
