import {actor,body,external,googleToken,handler,HttpError,owner,rpc} from '../_shared/core.ts';
Deno.serve(handler(async req=>{
 const {db,client,user}=await actor(req);const {attachment_id,action}=await body(req);
 const {data:a,error}=await client.from('attachments').select('id,board_id,file_name,mime,drive_file_id').eq('id',attachment_id).single();
 if(error||!a)throw new HttpError(403,'Arquivo não autorizado.');
 if(action==='delete'){await owner(db,user.id,undefined,a.board_id);await rpc(db,'enqueue',{queue:'background_tasks',payload:{type:'delete_attachment',attachment_id,actor_id:user.id}});return {ok:true,queued:true};}
 const {data:b}=await db.from('boards').select('workspace_id').eq('id',a.board_id).single();
 const {data:w}=await db.from('workspaces').select('owner_id').eq('id',b?.workspace_id).single();
 const token=await googleToken(db,w||{});const file=await external(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(a.drive_file_id)}?alt=media`,{headers:{Authorization:`Bearer ${token}`}});
 return new Response(file.body,{headers:{'Content-Type':a.mime,'Content-Disposition':`attachment; filename*=UTF-8''${encodeURIComponent(a.file_name)}`,'X-Content-Type-Options':'nosniff'}});
}));
