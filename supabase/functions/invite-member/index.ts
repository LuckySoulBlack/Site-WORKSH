import {actor,body,handler,owner,requireEnv,rpc} from '../_shared/core.ts';
Deno.serve(handler(async req=>{
 requireEnv('RESEND_API_KEY','RESEND_FROM_EMAIL','APP_URL');
 const {db,user,client}=await actor(req); const {board_id,email}=await body(req);
 await owner(db,user.id,undefined,board_id);
 const invitation_id=await rpc(client,'invite_to_board',{board_id,email});
 return {ok:true,invitation_id};
}));
