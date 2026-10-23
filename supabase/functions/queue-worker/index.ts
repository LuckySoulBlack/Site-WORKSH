import {admin,body,handler,HttpError,requireEnv,rpc,worker} from '../_shared/core.ts';
import {emailJob,folderJob,uploadJob} from '../_shared/jobs.ts';
Deno.serve(handler(async req=>{
 const db=admin();await worker(req,db);const {queue}=await body(req);
 if(!['email_invites','drive_uploads','background_tasks'].includes(queue))throw new HttpError(400,'Fila inválida.');
 if(!await rpc(db,'backend_queue_pending',{queue}))return new Response(null,{status:204});
 if(queue==='email_invites')requireEnv('RESEND_API_KEY','RESEND_FROM_EMAIL','APP_URL');else requireEnv('GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET');
 const messages=await rpc(db,'dequeue',{queue,qty:10,vt:60});if(!messages.length)return new Response(null,{status:204});
 let processed=0,failed=0;const start=Date.now();
 for(const m of messages){if(Date.now()-start>100000)break;
 try{if(queue==='email_invites')await emailJob(db,m.message.invitation_id);else if(queue==='drive_uploads')await uploadJob(db,m.message.upload_job_id,m.msg_id);else await folderJob(db,m.message);
 await rpc(db,'ack',{queue,msg_id:m.msg_id});processed++;
 }catch{await rpc(db,'fail',{queue,msg_id:m.msg_id});failed++;}}
 return {processed,failed};
}));
