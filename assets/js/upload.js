import {client,unwrap,call,invoke,user} from './supabase-client.js';
export const mimes=['application/pdf','image/png','image/jpeg','image/webp','text/plain','text/csv','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'];
export async function upload(file,board_id,task_id=null){
 if(file.size<1||file.size>5242880||!mimes.includes(file.type))throw Error('Use arquivo de até 5 MB em formato permitido.');
 const b=await unwrap(client().from('boards').select('workspace_id').eq('id',board_id).single());
 const w=await unwrap(client().from('workspaces').select('drive_folder_id').eq('id',b.workspace_id).single());
 if(!w.drive_folder_id)throw Error('O proprietário precisa conectar o Google Drive antes do primeiro upload.');
 const me=await user();const path=`${me.id}/${board_id}/${crypto.randomUUID()}`;
 await unwrap(client().storage.from('uploads-temp').upload(path,file,{contentType:file.type,upsert:false}));
 return call('enfileirar_upload',{storage_path:path,file_name:file.name,mime:file.type,size_bytes:file.size,board_id,task_id});
}
export async function watchJob(id,onChange,signal){for(let i=0;i<40&&!signal?.aborted;i++){const job=await unwrap(client().from('upload_jobs').select('id,status,last_error,drive_file_id').eq('id',id).single());onChange(job);if(['done','dead'].includes(job.status))return job;await new Promise(r=>setTimeout(r,5000));}return null;}
export async function download(id,name){const {data}=await client().auth.getSession();if(!data.session)throw Error('Entre na sua conta.');const c=window.WORKSH_CONFIG;const response=await fetch(c.SUPABASE_URL+'/functions/v1/file-access',{method:'POST',headers:{Authorization:'Bearer '+data.session.access_token,apikey:c.SUPABASE_ANON_KEY,'Content-Type':'application/json'},body:JSON.stringify({attachment_id:id})});if(!response.ok)throw Error('Não foi possível acessar o arquivo.');const blob=await response.blob();const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
