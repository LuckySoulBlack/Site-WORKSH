import {signedAvatars} from './profile-photos.js';
import {page} from './boards.js';
import {call} from './supabase-client.js';
export {renderHistory} from './history-view.js?v=20261023.9';
export async function history(board_id,cursor){
 // Compatible with the database before and after author snapshots are installed.
 const rows=await page('audit_events','*',{board_id},cursor,50);
 const profiles=(window.WorkshBoardFeatures||rows.some(row=>row.actor_id&&!row.actor_name))?await call(window.WorkshBoardFeatures?'board_people':'shared_profiles',{b:board_id}).catch(()=>[]):[];
 await signedAvatars(profiles);
 const names=new Map(profiles.map(p=>[p.id,p.full_name])),photos=new Map(profiles.map(p=>[p.id,p.avatar_url]));
 return rows.map(row=>({...row,actor_avatar:photos.get(row.actor_id)||null,actor_name:row.actor_name||names.get(row.actor_id)||null}));
}
