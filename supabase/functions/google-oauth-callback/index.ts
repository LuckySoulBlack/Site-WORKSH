import {admin,env,external,handler,HttpError,requireEnv,rpc,sha} from '../_shared/core.ts';
Deno.serve(handler(async req=>{
 requireEnv('GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET','GOOGLE_REDIRECT_URI','APP_URL');
 const url=new URL(req.url);const code=url.searchParams.get('code'),state=url.searchParams.get('state');
 if(!code||!state)throw new HttpError(400,'Autorização cancelada ou inválida.');
 const db=admin();const saved=await rpc(db,'backend_consume_state',{hash:await sha(state)});
 const result=await external('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({code,client_id:env('GOOGLE_CLIENT_ID'),client_secret:env('GOOGLE_CLIENT_SECRET'),redirect_uri:env('GOOGLE_REDIRECT_URI'),grant_type:'authorization_code'})});
 const token=await result.json();
 await rpc(db,'backend_connect_drive',{actor:saved.user_id,workspace:saved.workspace_id,refresh_token:token.refresh_token||''});
 return new Response(null,{status:303,headers:{Location:new URL('workspace.html#drive=connected',env('APP_URL').replace(/\/?$/,'/')).toString()}});
}));
