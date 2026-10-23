import {DB,env,external,googleToken,HttpError,random,requireEnv,rpc} from './core.ts';
export async function emailJob(db:DB,id:string) {
 requireEnv('RESEND_API_KEY','RESEND_FROM_EMAIL','APP_URL');
 const i=await rpc(db,'backend_claim_invite',{invitation:id});
 if(!i){const {data}=await db.from('invitations').select('delivered_at,revoked_at,expires_at,attempts').eq('id',id).maybeSingle();if(data&&!data.delivered_at&&!data.revoked_at&&new Date(data.expires_at).getTime()>Date.now()&&data.attempts<5)throw new Error('Invitation lease busy');return;}
 let payload=JSON.parse(await rpc(db,'backend_secret',{secret_id:i.delivery_secret_id}));
 let userId=await rpc(db,'backend_find_user',{email_address:i.email});
 if(!userId){
 if(!payload.password){payload.password='Ws!'+random();await rpc(db,'backend_store_secret',{secret_text:JSON.stringify(payload),secret_id:i.delivery_secret_id});}
 const created=await db.auth.admin.createUser({email:i.email,password:payload.password,email_confirm:true});
 if(created.error){userId=await rpc(db,'backend_find_user',{email_address:i.email});if(!userId)throw new Error('User provisioning failed');delete payload.password;}
 else userId=created.data.user.id;
 const {error}=await db.from('invitations').update({invitee_id:userId}).eq('id',id).eq('lease_token',i.lease_token);if(error)throw error;
 }else if(i.invitee_id!==userId){delete payload.password;}
 const link=new URL('workspace.html',env('APP_URL').replace(/\/?$/,'/'));link.hash='invite='+payload.token;
 const text=`Você recebeu um convite para a WORKSH.\n\nAcesse: ${link}\n\nE-mail: ${i.email}\n${payload.password?`Senha provisória: ${payload.password}\nTroque sua senha ao entrar pela primeira vez.\n`:'Entre com sua senha atual.\n'}\nO convite expira em 48 horas. Se não reconhece este convite, ignore esta mensagem.`;
 await external('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${env('RESEND_API_KEY')}`,'Content-Type':'application/json','Idempotency-Key':`worksh-invite-${id}`},body:JSON.stringify({from:env('RESEND_FROM_EMAIL'),to:[i.email],subject:'Seu convite para a WORKSH',text})});
 await rpc(db,'backend_finish_invite',{invitation:id,lease:i.lease_token,invitee:userId});
}
async function workspaceRow(db:DB,id:string){const {data,error}=await db.from('workspaces').select('id,owner_id,drive_folder_id,drive_secret_id').eq('id',id).single();if(error||!data)throw new Error('Workspace unavailable');return data;}
async function newDriveId(token:string) {const r=await external('https://www.googleapis.com/drive/v3/files/generateIds?count=1&space=drive&type=files',{headers:{Authorization:`Bearer ${token}`}});return (await r.json()).ids[0] as string;}
async function driveExists(token:string,id:string){const r=await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(id)}?fields=id,trashed`,{headers:{Authorization:`Bearer ${token}`},signal:AbortSignal.timeout(20000)});if(r.status===404){await r.body?.cancel();return false;}if(!r.ok){await r.body?.cancel();throw new Error('Drive unavailable');}const f=await r.json();if(f.trashed)throw new Error('Drive file was removed');return true;}
export async function folderJob(db:DB,p:Record<string,string>){
 if(p.type==='cleanup_storage'){
 const names=await rpc(db,'backend_expired_uploads');if(names.length){const {error}=await db.storage.from('uploads-temp').remove(names);if(error)throw error;}return;
 }
 requireEnv('GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET');
 if(p.type==='delete_attachment'){
 const {data:a}=await db.from('attachments').select('board_id,drive_file_id').eq('id',p.attachment_id).maybeSingle();if(!a)return;
 if(!await rpc(db,'backend_access',{actor:p.actor_id,board:a.board_id,workspace:null,owner_only:true}))return;
 const {data:b}=await db.from('boards').select('workspace_id').eq('id',a.board_id).single();if(!b)throw new Error('Board missing');
 const w=await workspaceRow(db,b.workspace_id);const token=await googleToken(db,w);
 const res=await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(a.drive_file_id)}`,{method:'PATCH',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({trashed:true}),signal:AbortSignal.timeout(30000)});
 if(!res.ok&&res.status!==404){await res.body?.cancel();throw new Error('Drive removal failed');}await res.body?.cancel();
 await rpc(db,'backend_delete_attachment',{actor:p.actor_id,attachment:p.attachment_id});return;
 }
 if(p.type!=='drive_folder')throw new Error('Unsupported job');
 if(!await rpc(db,'backend_access',{actor:p.actor_id,workspace:p.workspace_id,board:null,owner_only:true}))return;
 let w=await workspaceRow(db,p.workspace_id);const token=await googleToken(db,w);
 if(!w.drive_folder_id){const id=await newDriveId(token);const {error}=await db.from('workspaces').update({drive_folder_id:id}).eq('id',w.id).is('drive_folder_id',null);if(error)throw error;w=await workspaceRow(db,w.id);}
 if(await driveExists(token,w.drive_folder_id))return;
 const r=await fetch('https://www.googleapis.com/drive/v3/files',{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({id:w.drive_folder_id,name:'WORKSH — '+w.id,mimeType:'application/vnd.google-apps.folder'}),signal:AbortSignal.timeout(30000)});
 if(!r.ok && !await driveExists(token,w.drive_folder_id)){await r.body?.cancel();throw new Error('Folder creation failed');}await r.body?.cancel();
}
export async function uploadJob(db:DB,id:string,messageId?:number){
 requireEnv('GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET');
 const j=await rpc(db,'backend_claim_upload',{job:id});if(!j){const {data}=await db.from('upload_jobs').select('status,storage_path').eq('id',id).maybeSingle();if(data?.status==='done'){const {error}=await db.storage.from('uploads-temp').remove([data.storage_path]);if(error)throw error;return;}if(data&&data.status!=='dead')throw new Error('Upload lease busy');return;}
 let leaseLost=false;
 const timer=messageId===undefined?null:setInterval(()=>{rpc(db,'backend_renew',{queue:'drive_uploads',message_id:messageId,job:id,lease:j.lease_token}).then(ok=>{if(!ok)leaseLost=true;}).catch(()=>{leaseLost=true;});},20000);
 try{
 const w=await workspaceRow(db,j.workspace_id);if(!w.drive_folder_id)throw new Error('Drive folder pending');const token=await googleToken(db,w);
 let driveId=j.drive_file_id;
 if(!driveId){driveId=await newDriveId(token);const {error}=await db.from('upload_jobs').update({drive_file_id:driveId}).eq('id',id).eq('lease_token',j.lease_token);if(error)throw error;}
 if(!await driveExists(token,driveId)){
 const storageURL=env('SUPABASE_URL')+'/storage/v1/object/authenticated/uploads-temp/'+j.storage_path.split('/').map(encodeURIComponent).join('/');
 const source=await external(storageURL,{headers:{Authorization:`Bearer ${env('SUPABASE_SERVICE_ROLE_KEY')}`,apikey:env('SUPABASE_SERVICE_ROLE_KEY')}});
 if(Number(source.headers.get('content-length'))!==Number(j.size_bytes)){await source.body?.cancel();throw new Error('Invalid stored size');}
 const init=await external('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id',{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json','X-Upload-Content-Type':j.mime,'X-Upload-Content-Length':String(j.size_bytes)},body:JSON.stringify({id:driveId,name:j.file_name,parents:[w.drive_folder_id]})});
 const target=init.headers.get('Location');await init.body?.cancel();if(!target||new URL(target).hostname!=='www.googleapis.com'){await source.body?.cancel();throw new Error('Invalid upload session');}
 const uploaded=await external(target,{method:'PUT',headers:{'Content-Type':j.mime,'Content-Length':String(j.size_bytes)},body:source.body});await uploaded.body?.cancel();
 }
 if(leaseLost)throw new Error('Lease lost');
 await rpc(db,'backend_finish_upload',{job:id,lease:j.lease_token});
 const {error}=await db.storage.from('uploads-temp').remove([j.storage_path]);if(error)throw error;
 }catch(e){await db.from('upload_jobs').update({status:'failed',last_error:'Upload temporariamente indisponível. Nova tentativa agendada.',lease_until:null}).eq('id',id).eq('lease_token',j.lease_token).neq('status','done');throw e;}finally{if(timer)clearInterval(timer);}
}
