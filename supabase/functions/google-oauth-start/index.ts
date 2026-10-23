import {actor,body,env,handler,owner,random,requireEnv,rpc,sha} from '../_shared/core.ts';
Deno.serve(handler(async req=>{
 requireEnv('GOOGLE_CLIENT_ID','GOOGLE_REDIRECT_URI');
 const {db,user}=await actor(req); const {workspace_id}=await body(req);
 await owner(db,user.id,workspace_id);const state=random();
 await rpc(db,'backend_oauth_state',{actor:user.id,workspace:workspace_id,state_hash:await sha(state)});
 const url=new URL('https://accounts.google.com/o/oauth2/v2/auth');
 url.search=new URLSearchParams({client_id:env('GOOGLE_CLIENT_ID'),redirect_uri:env('GOOGLE_REDIRECT_URI'),response_type:'code',scope:'https://www.googleapis.com/auth/drive.file',access_type:'offline',prompt:'consent',state}).toString();
 return {ok:true,url:url.toString()};
}));
