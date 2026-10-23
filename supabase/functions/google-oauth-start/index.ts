import {actor,body,env,handler,HttpError,random,rpc,sha} from '../_shared/core.ts';
Deno.serve(handler(async req=>{
 const {db,user}=await actor(req);await body(req);
 if(!env('GOOGLE_CLIENT_ID')||!env('GOOGLE_CLIENT_SECRET')||!env('GOOGLE_REDIRECT_URI')||!env('APP_URL'))throw new HttpError(503,'A conexão com o Google Drive ainda precisa ser ativada pelo administrador.');
 const state=random();await rpc(db,'backend_oauth_state',{actor:user.id,workspace:null,state_hash:await sha(state)});
 const url=new URL('https://accounts.google.com/o/oauth2/v2/auth');
 url.search=new URLSearchParams({client_id:env('GOOGLE_CLIENT_ID'),redirect_uri:env('GOOGLE_REDIRECT_URI'),response_type:'code',scope:'openid email https://www.googleapis.com/auth/drive.file',access_type:'offline',prompt:'consent select_account',state}).toString();
 return {ok:true,url:url.toString()};
}));
