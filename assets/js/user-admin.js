import {invoke} from './supabase-client.js';
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function setupUserAdmin(identity,ui){
 if(!identity.is_admin)return;
 const button=document.createElement('button');button.className='top-button';button.textContent='Usuários e acessos';button.id='userAdmin';document.querySelector('.top-right').append(button);
 const showError=e=>ui.message(e.message||'Não foi possível concluir.');
 async function open(){
  const users=await invoke('admin-users',{action:'list'});
  ui.editor('Usuários e acessos',`<p>Gerencie as contas da empresa. O acesso aos painéis é definido separadamente pelo proprietário de cada workspace.</p><div class="user-admin-table"><table><thead><tr><th>Pessoa</th><th>Perfil</th><th>Acesso</th><th>Ação</th></tr></thead><tbody>${users.map(u=>`<tr><td><strong>${esc(u.name)}</strong><small>${esc(u.email)}</small></td><td>${u.is_admin?'Administrador':'Membro da equipe'}</td><td><span class="user-state ${u.is_blocked?'blocked':'active'}">${u.is_blocked?'Bloqueado':'Liberado'}</span>${u.must_change_password?'<small>Troca de senha pendente</small>':''}</td><td>${u.is_admin?'<small>Protegido</small>':`<button type="button" class="button" data-user-id="${esc(u.id)}" data-user-action="${u.is_blocked?'release':'block'}">${u.is_blocked?'Liberar':'Bloquear'}</button>`}</td></tr>`).join('')}</tbody></table></div><button type="button" class="button primary" id="addCompanyUser">Cadastrar usuário</button>`,async()=>ui.close(),'Concluir');
  document.querySelectorAll('[data-user-action]').forEach(b=>b.onclick=async()=>{b.disabled=true;try{await invoke('admin-users',{action:b.dataset.userAction,user_id:b.dataset.userId});await open();ui.message('Acesso atualizado.');}catch(e){showError(e);}finally{b.disabled=false;}});
  document.getElementById('addCompanyUser').onclick=()=>ui.editor('Cadastrar usuário da empresa','<label>Nome<input name="name" autocomplete="off" required maxlength="200"></label><label>E-mail<input name="email" type="email" autocomplete="off" required></label><label>Senha inicial<input name="password" type="password" autocomplete="new-password" minlength="12" maxlength="128" required></label><p>A conta será criada como membro da equipe, com troca obrigatória de senha. Conceda acesso aos painéis em Acessos. O envio de e-mail ainda não está configurado.</p>',async f=>{const save=document.getElementById('saveButton');save.disabled=true;try{await invoke('admin-users',{action:'create',name:f.get('name'),email:f.get('email'),password:f.get('password')});await open();ui.message('Usuário criado.');}catch(e){showError(e);}finally{save.disabled=false;}},'Criar usuário');
 }
 button.onclick=()=>open().catch(showError);
}
