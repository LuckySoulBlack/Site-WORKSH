import {invoke} from './supabase-client.js';
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const labels={admin:'Admin',user:'Usuário',guest:'Convidado'};
export function setupUserAdmin(identity,ui){
 window.WorkshAccountRole=identity.profile_role||'guest';
 const fail=e=>ui.message(e.message||'Não foi possível concluir.');
 if(!identity.is_admin)return {mount(){}};
 const button=document.createElement('button');button.className='top-button';button.textContent='Configurações de acesso';button.id='userAdmin';document.querySelector('.top-right').append(button);
 let generation=0;
 function mount(){
  if(ui.current().page!=='settings')return;
  if(ui.current().workspace&&!document.querySelector('[data-action="settings-tab"][data-id="access"][aria-current="page"]'))return;
  let root=document.getElementById('platformSettings');if(root)return;
  root=document.createElement('section');root.id='platformSettings';root.className='platform-settings';document.getElementById('main').append(root);
  root.innerHTML='<p class="settings-eyebrow">ADMINISTRAÇÃO DA PLATAFORMA</p><h2>Perfis, usuários e convites</h2><p>Controle quem administra a WORKSH, quem cria seus próprios workspaces e quem participa de ambientes compartilhados.</p><div class="profile-rules"><article><strong>Admin</strong><p>Convida usuários, altera perfis e libera ou bloqueia contas.</p></article><article><strong>Usuário</strong><p>Cria seus workspaces e controla os convidados de cada painel.</p></article><article><strong>Convidado</strong><p>Navega e edita somente os painéis autorizados. Não cria workspace.</p></article></div><div class="settings-access-actions"><button class="button primary" id="invitePlatformUser">Convidar usuário</button><button class="button" id="createPlatformUser">Cadastrar sem e-mail</button><label>Buscar pessoas<input type="search" id="platformUserSearch" placeholder="Nome ou e-mail"></label></div><p role="status" id="platformEmailState">Verificando envio de convites…</p><div id="platformUserList" class="user-admin-table" aria-live="polite">Carregando usuários…</div>';
  root.querySelector('#invitePlatformUser').onclick=()=>inviteForm();root.querySelector('#createPlatformUser').onclick=()=>createForm();
  load(root).catch(fail);
 }
 async function load(root){
  const seq=++generation;const [users,caps]=await Promise.all([invoke('admin-users',{action:'list'}),invoke('admin-users',{action:'capabilities'})]);
  if(seq!==generation||!root.isConnected)return;
  root.querySelector('#platformEmailState').textContent=caps.email_ready?'Envio de convites disponível.':'Envio por e-mail pendente: configure o remetente e a chave do Resend no servidor. Você já pode cadastrar contas e ajustar perfis nesta tela.';
  const render=()=>{
   const search=root.querySelector('#platformUserSearch').value.trim().toLowerCase();const filtered=users.filter(u=>(u.name+' '+u.email).toLowerCase().includes(search));
   root.querySelector('#platformUserList').innerHTML=`<table><thead><tr><th>Pessoa</th><th>Perfil</th><th>Acesso</th><th>Ações</th></tr></thead><tbody>${filtered.map(u=>`<tr><td><strong>${esc(u.name)}</strong><small>${esc(u.email)}</small></td><td><label class="sr-only" for="role-${esc(u.id)}">Perfil de ${esc(u.email)}</label><select id="role-${esc(u.id)}" data-role-for="${esc(u.id)}" ${u.id===identity.user.id?'disabled':''}>${Object.entries(labels).map(([v,l])=>`<option value="${v}" ${u.profile_role===v?'selected':''}>${l}</option>`).join('')}</select></td><td><span class="user-state ${u.is_blocked?'blocked':'active'}">${u.is_blocked?'Bloqueado':'Liberado'}</span>${u.must_change_password?'<small>Troca de senha pendente</small>':''}</td><td><div class="settings-row-actions"><button type="button" class="button" data-save-role="${esc(u.id)}" ${u.id===identity.user.id?'disabled':''}>Salvar perfil</button>${u.is_admin?'<small>Admin protegido</small>':`<button type="button" class="button" data-access-user="${esc(u.id)}" data-access-action="${u.is_blocked?'release':'block'}">${u.is_blocked?'Liberar':'Bloquear'}</button>`}</div></td></tr>`).join('')||'<tr><td colspan="4">Nenhuma pessoa encontrada.</td></tr>'}</tbody></table>`;
   root.querySelectorAll('[data-save-role]').forEach(b=>b.onclick=()=>run(b,async()=>{const role=root.querySelector(`[data-role-for="${b.dataset.saveRole}"]`).value;await invoke('admin-users',{action:'set-role',user_id:b.dataset.saveRole,role});await load(root);ui.message('Perfil atualizado.');}));
   root.querySelectorAll('[data-access-user]').forEach(b=>b.onclick=()=>run(b,async()=>{await invoke('admin-users',{action:b.dataset.accessAction,user_id:b.dataset.accessUser});await load(root);ui.message('Acesso atualizado.');}));
  };
  root.querySelector('#platformUserSearch').oninput=render;render();
 }
 async function run(button,fn){button.disabled=true;try{await fn();}catch(e){fail(e);}finally{if(button.isConnected)button.disabled=false;}}
 function inviteForm(){ui.editor('Convidar para a WORKSH','<p>A pessoa terá perfil Usuário e poderá criar seus próprios workspaces, sem entrar automaticamente nos seus painéis.</p><label>Nome<input name="name" maxlength="200" required></label><label>E-mail<input name="email" type="email" required></label><p>O envio depende do Resend configurado. A senha inicial será gerada no servidor e deverá ser trocada no primeiro acesso.</p>',async f=>run(document.getElementById('saveButton'),async()=>{await invoke('admin-users',{action:'invite',email:f.get('email'),name:f.get('name')});ui.close();ui.message('Convite enviado.');const root=document.getElementById('platformSettings');if(root)await load(root);}), 'Enviar convite');}
 function createForm(){ui.editor('Cadastrar usuário','<label>Nome<input name="name" required maxlength="200"></label><label>E-mail<input name="email" type="email" required autocomplete="off"></label><label>Senha inicial<input name="password" type="password" autocomplete="new-password" minlength="12" maxlength="128" required></label><p>O perfil inicial será Usuário. A pessoa poderá criar seus workspaces depois de trocar a senha. Você poderá alterar o perfil nesta tela.</p>',async f=>run(document.getElementById('saveButton'),async()=>{await invoke('admin-users',{action:'create',name:f.get('name'),email:f.get('email'),password:f.get('password')});ui.close();ui.message('Usuário cadastrado.');const root=document.getElementById('platformSettings');if(root)await load(root);}), 'Criar usuário');}
 button.onclick=()=>{ui.openSettings();mount();};
 return {mount};
}
