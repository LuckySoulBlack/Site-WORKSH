import {admin,actor,body,handler,worker,rpc,HttpError,env,requireEnv,random,external} from '../_shared/core.ts';
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
 if(input.action==='capabilities')return {email_ready:!!(env('RESEND_API_KEY')&&env('RESEND_FROM_EMAIL')&&env('APP_URL'))};
 if(input.action==='set-role'){if(!['admin','user','guest'].includes(input.role))throw new HttpError(400,'Perfil inválido.');return await rpc(db,'backend_manage_users',{actor:user.id,operation:'role_'+input.role,target:input.user_id});}
 if(input.action==='invite'){
  requireEnv('RESEND_API_KEY','RESEND_FROM_EMAIL','APP_URL');
  const email=String(input.email||'').trim().toLowerCase();
  const record=await rpc(db,'backend_platform_invite',{actor:user.id,email_address:email,initial_secret:'Ws!'+random()});
  if(record.already_sent)return {ok:true,already_sent:true};
  const password=await rpc(db,'backend_secret',{secret_id:record.secret_id});
  let id=await rpc(db,'backend_find_user',{email_address:email});let initial=false;
  if(!id){const {data,error}=await db.auth.admin.createUser({email,password,email_confirm:true,app_metadata:{worksh_platform_invitation:record.id},user_metadata:{full_name:String(input.name||email)}});if(error)throw new HttpError(400,'Não foi possível criar a conta. Tente reenviar em um minuto.');id=data.user.id;initial=true;}
  // A retry recognizes the user created with this invitation's initial password.
  if(!initial){const probe=await db.auth.admin.getUserById(id);initial=probe.data.user?.app_metadata?.worksh_platform_invitation===record.id&&!probe.data.user?.last_sign_in_at;}
  const users=await rpc(db,'backend_manage_users',{actor:user.id,operation:'list'});
  const account=users.find((u:{id:string;profile_role:string;is_blocked:boolean})=>u.id===id);if(account?.is_blocked)throw new HttpError(403,'Libere a conta antes de convidar.');
  if(account?.profile_role==='guest')await rpc(db,'backend_manage_users',{actor:user.id,operation:'role_user',target:id});
  const link=new URL('index.html',env('APP_URL').replace(/\/?$/,'/'));
  await external('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${env('RESEND_API_KEY')}`,'Content-Type':'application/json','Idempotency-Key':`worksh-platform-${record.id}`},body:JSON.stringify({from:env('RESEND_FROM_EMAIL'),to:[email],subject:'Seu acesso à WORKSH',text:`Você foi convidado para criar seu próprio workspace na WORKSH.\nAcesse: ${link}\nE-mail: ${email}\n${initial?'Senha provisória: '+password+'\nDefina uma nova senha na primeira entrada.':'Entre com sua senha atual.'}\nSeus workspaces serão separados dos ambientes de quem enviou o convite.`})});
  await rpc(db,'backend_platform_invite',{actor:user.id,email_address:email,initial_secret:'',invitation:record.id,lease:record.lease_token,invitee:id});
  return {ok:true};
 }
 if(input.action==='list')return await rpc(db,'backend_manage_users',{actor:user.id,operation:'list'});
 if(input.action==='create'){
  const email=String(input.email||'').trim().toLowerCase();
  if(!email.includes('@')||String(input.password||'').length<12)throw new HttpError(400,'Informe e-mail e senha inicial com pelo menos 12 caracteres.');
  if(await rpc(db,'backend_find_user',{email_address:email}))throw new HttpError(409,'Este e-mail já possui uma conta.');
  const {data,error}=await db.auth.admin.createUser({email,password:input.password,email_confirm:true,user_metadata:{full_name:String(input.name||email)}});
  if(error)throw new HttpError(400,'Não foi possível criar a conta.');
  await rpc(db,'backend_manage_users',{actor:user.id,operation:'created',target:data.user.id});
  await rpc(db,'backend_manage_users',{actor:user.id,operation:'role_user',target:data.user.id});
  return {id:data.user.id,created:true};
 }
 if(input.action==='block'||input.action==='release')return await rpc(db,'backend_manage_users',{actor:user.id,operation:input.action,target:input.user_id});
 throw new HttpError(400,'Operação inválida.');
}));
