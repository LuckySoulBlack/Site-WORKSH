import {admin,env,external,handler,requireEnv,rpc,sha} from '../_shared/core.ts';
import {driveFile,ensureFolder,newDriveId} from '../_shared/drive.ts';
Deno.serve(handler(async req=>{
 requireEnv('GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET','GOOGLE_REDIRECT_URI','APP_URL');
 const redirect=(status:string)=>new Response(null,{status:303,headers:{Location:new URL('workspace.html#drive='+status,env('APP_URL').replace(/\/?$/,'/')).toString()}});
 const url=new URL(req.url),state=url.searchParams.get('state');if(!state)return redirect('invalid');
 const db=admin();let saved;
 try{saved=await rpc(db,'backend_consume_state',{hash:await sha(state)});}catch{return redirect('invalid');}
 if(url.searchParams.get('error'))return redirect('cancelled');
 const code=url.searchParams.get('code');if(!code)return redirect('invalid');
 try{
 const result=await external('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({code,client_id:env('GOOGLE_CLIENT_ID'),client_secret:env('GOOGLE_CLIENT_SECRET'),redirect_uri:env('GOOGLE_REDIRECT_URI'),grant_type:'authorization_code'})});
 const token=await result.json();if(!String(token.scope||'').split(' ').includes('https://www.googleapis.com/auth/drive.file'))return redirect('permissions');
 const info=await external('https://www.googleapis.com/oauth2/v3/userinfo',{headers:{Authorization:`Bearer ${token.access_token}`}});const identity=await info.json();
 if(!identity.sub||!identity.email||identity.email_verified!==true)return redirect('identity');
 const prior=await rpc(db,'backend_owner_drive',{actor:saved.user_id,operation:'get'});
 if(prior&&prior.google_subject!==identity.sub)return redirect('different_account');
 const containers=await rpc(db,'backend_owner_drive',{actor:saved.user_id,operation:'containers'});
 for(const w of containers){const folder=await driveFile(token.access_token,w.folder_id);if(!folder||folder.trashed)return redirect('existing_files');}
 const proposed=prior?.root_folder_id||await newDriveId(token.access_token);
 const connection=await rpc(db,'backend_owner_drive',{actor:saved.user_id,operation:'prepare',payload:{subject:identity.sub,email:identity.email,root_id:proposed,refresh_token:token.refresh_token||''}});
 await ensureFolder(token.access_token,connection.root_folder_id,'WORKSH');
 await rpc(db,'backend_owner_drive',{actor:saved.user_id,operation:'finish',payload:{root_id:connection.root_folder_id}});
 return redirect('connected');
 }catch{return redirect('failed');}
}));
