import {admin,actor,body,handler,worker,rpc,HttpError} from '../_shared/core.ts';
Deno.serve(handler(async req=>{
 const input=await body(req);
 // Operator-only provisioning uses the existing Vault-backed worker credential.
 // It cannot grant administrator rights or replace an existing password.
 if(input.action==='provision'){
  const db=admin();await worker(req,db);
  const email=String(input.email||'').trim().toLowerCase();
  if(!email.includes('@')||String(input.password||'').length<12)throw new HttpError(400,'E-mail e senha inicial de pelo menos 12 caracteres necessários.');
  const existing=await rpc(db,'backend_find_user',{email_address:email});
  if(existing)return {id:existing,existing:true};
  const {data,error}=await db.auth.admin.createUser({email,password:input.password,email_confirm:true,user_metadata:{full_name:String(input.name||email)}});
  if(error)throw new HttpError(400,'Não foi possível criar a conta.');
  return {id:data.user.id,created:true};
 }
 const {db,user}=await actor(req);
 await rpc(db,'backend_manage_users',{actor:user.id,operation:'authorize'});
 if(input.action==='list')return await rpc(db,'backend_manage_users',{actor:user.id,operation:'list'});
 if(input.action==='create'){
  const email=String(input.email||'').trim().toLowerCase();
  if(!email.includes('@')||String(input.password||'').length<12)throw new HttpError(400,'Informe e-mail e senha inicial com pelo menos 12 caracteres.');
  if(await rpc(db,'backend_find_user',{email_address:email}))throw new HttpError(409,'Este e-mail já possui uma conta.');
  const {data,error}=await db.auth.admin.createUser({email,password:input.password,email_confirm:true,user_metadata:{full_name:String(input.name||email)}});
  if(error)throw new HttpError(400,'Não foi possível criar a conta.');
  await rpc(db,'backend_manage_users',{actor:user.id,operation:'created',target:data.user.id});
  return {id:data.user.id,created:true};
 }
 if(input.action==='block'||input.action==='release')return await rpc(db,'backend_manage_users',{actor:user.id,operation:input.action,target:input.user_id});
 throw new HttpError(400,'Operação inválida.');
}));
