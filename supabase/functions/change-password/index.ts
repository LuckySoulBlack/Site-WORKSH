import {actor,body,handler,HttpError,rpc} from '../_shared/core.ts';
Deno.serve(handler(async req=>{
 const {db,user}=await actor(req);const {password}=await body(req);
 if(typeof password!=='string'||password.length<12||password.length>128)throw new HttpError(400,'Use uma senha de 12 a 128 caracteres.');
 const {error}=await db.auth.admin.updateUserById(user.id,{password});
 if(error)throw new HttpError(400,'A senha não atende aos requisitos ou já foi utilizada.');
 await rpc(db,'complete_password_change',{actor:user.id});
 return {ok:true};
}));
