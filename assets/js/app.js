import {setupCompanyAssets} from './company-assets.js?v=20261024.2';
import {setupProjectExport} from './project-export.js?v=20261024.2';
import {fetchExportProject} from './project-data.js?v=20261024.2';
import {setupTaskFiles} from './task-files.js?v=20261024.4';
import {setupProfilePhotos} from './profile-photos.js?v=20261024.2';
import {setupDriveOnboarding,connectOwnerDrive} from './drive-onboarding.js?v=20261023.6';
import {setupUserAdmin} from './user-admin.js?v=20261023.6';
import {client,unwrap,invoke,call} from './supabase-client.js';
import {login,logout,session,signup} from './auth.js';
import {changePassword} from './change-password.js';
import {RemoteRepository} from './remote-repository.js?v=20261024.2';
import {history,renderHistory} from './historico.js?v=20261024.2';
import {invite,accept,revoke,grant} from './convidar.js';
import {upload,watchJob,download,mimes} from './upload.js';
import {canDelete,canEdit} from './permissions.js';
import {preview,seedSQL,importConfirmed} from '../../scripts/migrate-localstorage.js';
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const ui=window.WorkshUI;
function status(message){if(ui)ui.message(message);else {const p=document.getElementById('loginStatus');if(p){p.hidden=false;p.textContent=message;}}}
async function attempt(fn){try{return await fn();}catch(e){status(e.message||'Não foi possível concluir.');}}
function editor(title,fields,fn,save='Salvar'){ui.editor(title,fields,async fd=>{await attempt(async()=>{await fn(fd);ui.close();});},save);}
function passwordScreen(email){const main=document.getElementById('main');main.innerHTML='<div class="account-card"><h1>Defina sua nova senha</h1><p>Atualize a senha para liberar seus painéis.</p><form id="cloudPassword"><label>E-mail<input name="username" autocomplete="username" type="email" value="'+esc(email)+'" readonly></label><label>Nova senha<input name="password" type="password" autocomplete="new-password" minlength="12" maxlength="128" required></label><label>Confirme a senha<input name="confirm" type="password" autocomplete="new-password" minlength="12" required></label><button class="button primary">Atualizar senha</button><p role="status"></p></form></div>';document.getElementById('sidebar').innerHTML='';
 const form=document.getElementById('cloudPassword');form.addEventListener('submit',e=>{e.preventDefault();attempt(async()=>{const f=new FormData(form);if(f.get('password')!==f.get('confirm'))throw Error('As senhas precisam ser iguais.');form.querySelector('button').disabled=true;try{await changePassword(String(f.get('password')));location.reload();}finally{form.querySelector('button').disabled=false;}});});}
async function begin(){
 if(!window.WORKSH_CONFIG?.enabled)return;
 const incoming=new URLSearchParams(location.hash.slice(1)).get('invite');
 if(incoming){sessionStorage.setItem('worksh.pendingInvite',incoming);historyReplace();}
 const form=document.getElementById('workspaceLogin');
 if(form){const savedEmail=localStorage.getItem('worksh.savedEmail');if(savedEmail){document.getElementById('loginEmail').value=savedEmail;document.getElementById('saveChromeLogin').checked=true;}form.addEventListener('submit',e=>{e.preventDefault();e.stopImmediatePropagation();attempt(async()=>{const button=form.querySelector('[type=submit]');button.disabled=true;try{const email=document.getElementById('loginEmail').value.trim(),password=document.getElementById('loginPassword').value;await login(email,password);if(document.getElementById('saveChromeLogin').checked){localStorage.setItem('worksh.savedEmail',email);if(window.PasswordCredential&&navigator.credentials)await navigator.credentials.store(new PasswordCredential({id:email,password,name:email})).catch(()=>{});}else localStorage.removeItem('worksh.savedEmail');location.assign('workspace.html');}finally{button.disabled=false;}});},true);return;}
 if(!ui)return;
 document.querySelector('.local-badge').textContent='● Sessão protegida';
 let identity;try{identity=await session();}catch{ui.loading('<h1>Entre na sua conta</h1><p>Acesse pela página inicial para abrir seus workspaces.</p><a class="button primary" href="index.html">Entrar</a><button class="button" id="cloudSignup">Criar conta</button>');document.getElementById('cloudSignup').onclick=()=>editor('Criar conta','<label>Nome<input name="name" required></label><label>E-mail<input name="email" type="email" required></label><label>Senha<input name="password" type="password" minlength="12" required></label>',async f=>{const result=await signup(f.get('email'),f.get('password'),f.get('name'));status(result.message);});return;}
 const toolbar=document.createElement('div');toolbar.className='cloud-controls';toolbar.innerHTML='<button class="top-button" id="cloudRefresh">Atualizar</button><button class="top-button" id="cloudLogout">Sair</button>';document.querySelector('.top-right').append(toolbar);document.getElementById('cloudLogout').onclick=()=>attempt(logout);
 if(identity.is_blocked){ui.loading('<h1>Acesso bloqueado</h1><p>Procure o administrador da sua empresa para liberar sua conta.</p>');return;}
 if(identity.must_change_password){passwordScreen(identity.user.email);return;}
 const userAdmin=setupUserAdmin(identity,ui);const driveOnboarding=setupDriveOnboarding(identity,ui);
 const token=sessionStorage.getItem('worksh.pendingInvite');if(token){await accept(token);sessionStorage.removeItem('worksh.pendingInvite');}
 const repo=new RemoteRepository(identity.user,ui);window.WorkshRemote=repo;
 document.getElementById('cloudRefresh').onclick=()=>attempt(async()=>{const id=ui.current().board?.id;await repo.load();if(id)await repo.loadBoard(id);});
 await repo.load();window.WorkshEligibleRows=async ids=>(await call('deletable_task_rows',{task_ids:ids})).map(row=>row.id);setupCompanyAssets(repo,ui);const projectExport=setupProjectExport(ui,{fetchProject:(boardId,includePeople)=>fetchExportProject(ui,boardId,includePeople),createShare:(board,view_type,include_people,days)=>call('create_project_share',{board,view_type,include_people,days}),listShares:board=>call('list_project_shares',{board}),revokeShare:share_id=>call('revoke_project_share',{share_id})});setupProfilePhotos(repo,ui);setupTaskFiles(repo,ui);setupImport(repo);ui.onRender=()=>{decorate(repo);projectExport.mount();userAdmin?.mount();driveOnboarding.render();};ui.onEditor=(title,fields)=>{if(/^(Documento|Checklist|Responsáveis|Extrair informações) — /.test(title)&&!canEdit(repo.role(ui.current().workspace),repo.members.get(ui.current().board?.id))){fields.querySelectorAll('input,textarea,select').forEach(el=>el.disabled=true);document.getElementById('saveButton').disabled=true;}if(title==='Meu perfil'){const email=fields.querySelector('[name="email"]');if(email)email.readOnly=true;}fields.querySelectorAll('.inline-note').forEach(n=>{if(n.textContent.includes('Perfil local'))n.remove();});};decorate(repo);projectExport.mount();userAdmin?.mount();driveOnboarding.render();
 for(const eventName of ['change','submit'])document.addEventListener(eventName,event=>{if(repo.busy){event.preventDefault();event.stopImmediatePropagation();status('Aguarde a gravação atual.');}},true);
 document.addEventListener('click',event=>{
 const target=event.target.closest('[data-action]');if(!target)return;const a=target.dataset.action,id=target.dataset.id;
 if(repo.busy && !['close','export'].includes(a)){event.preventDefault();event.stopImmediatePropagation();status('Aguarde a gravação atual.');return;}
 if(a==='new-workspace'&&driveOnboarding.required){event.preventDefault();event.stopImmediatePropagation();driveOnboarding.show();return;}
 if(a==='new-workspace'&&window.WorkshAccountRole==='guest'){event.preventDefault();event.stopImmediatePropagation();status('Convidados acessam somente os ambientes compartilhados.');return;}
 if(a==='board'){event.preventDefault();event.stopImmediatePropagation();attempt(()=>repo.loadBoard(id).then(()=>ui.openBoard(id)));return;}
 if(a==='new-task'&&!ui.current().board?.groups.length){event.preventDefault();event.stopImmediatePropagation();status('Crie um grupo antes da primeira tarefa.');return;}
 if(['new-person','new-guest','edit-person','delete-person','edit-integration','import','undo'].includes(a)){
 event.preventDefault();event.stopImmediatePropagation();if(['new-person','new-guest'].includes(a))showInvite(repo);else status('Use os controles de acesso e integração do painel conectado.');return;}
 if(a==='page'&&id==='activity'){event.preventDefault();event.stopImmediatePropagation();showHistory(repo);return;}
 if(a?.startsWith('delete-')&&!canDelete(repo.role(ui.current().workspace))){event.preventDefault();event.stopImmediatePropagation();status('Somente o proprietário pode excluir.');}
 },true);
}
function historyReplace(){window.history.replaceState(null,'',location.pathname+location.search);}
function showInvite(repo){const {board,workspace}=ui.current();if(!board||!canDelete(repo.role(workspace))){status('Abra um painel do qual você é proprietário para convidar.');return;}editor('Convidar para '+board.name,'<label>E-mail<input type="email" name="email" required></label>',async f=>{await invite(board.id,f.get('email'));status('Convite enfileirado para envio.');},'Convidar');}
async function showHistory(repo){const board=ui.current().board;if(!board){status('Abra um painel para consultar o histórico.');return;}let cursor=null;const render=async()=>{const rows=await history(board.id,cursor);ui.editor('Histórico — '+board.name,renderHistory(rows,{userId:repo.identity.id,profile:ui.snapshot().profile,people:ui.current().workspace?.people||[]}),()=>{if(rows.length===50){cursor=rows.at(-1);attempt(render);}else ui.close();},rows.length===50?'Próxima página':'Fechar');};await attempt(render);}
function decorate(repo){
 const {workspace,board}=ui.current();document.querySelectorAll('[data-action="new-workspace"]').forEach(b=>b.hidden=window.WorkshAccountRole==='guest');if(!workspace)return;
 if(window.WorkshAccountRole==='guest')document.querySelectorAll('[data-action="page"][data-id="people"],[data-action="page"][data-id="reports"]').forEach(b=>b.hidden=true);
 window.WorkshCanRemoveColumns=repo.role(workspace)==='owner';
 const role=repo.role(workspace),editable=board?canEdit(role,repo.members.get(board.id)):role==='owner';
 const badge=document.querySelector('.local-badge');if(badge)badge.textContent='● Sincronizado';
 document.querySelectorAll('[data-action^="delete-"]').forEach(b=>{b.hidden=!canDelete(role);});
 document.querySelectorAll('[data-action="edit-workspace"],[data-action="rename-workspace"],[data-action="new-board"],[data-action="edit-company"]').forEach(b=>{b.hidden=role!=='owner';});
 document.querySelectorAll('[data-action="cell-assignees"], [data-task], [data-date-task] input, [data-date-task] button, [data-quick-group] input, [data-action="add-column"], [data-action="checklist"], [data-action="new-task"], [data-action="new-group"], [data-action="edit-group"]').forEach(b=>{b.disabled=!editable;});
 if(ui.current().page==='settings'){document.querySelectorAll('.inline-note').forEach(n=>{if(n.textContent.includes('Perfil local nesta etapa'))n.remove();});const drive=document.querySelector('[data-action="edit-integration"][data-id="drive"]');if(drive&&window.WorkshAccountRole!=='guest'){drive.hidden=true;const connect=document.createElement('button');connect.className='button primary';connect.textContent='Conectar meu Google Drive';drive.after(connect);connect.onclick=()=>attempt(async()=>{await connectOwnerDrive();});}return;}
 if(!document.getElementById('cloudTools')){const bar=document.createElement('div');bar.id='cloudTools';bar.className='toolbar';bar.innerHTML='<button class="button" data-cloud="invite">Convidar</button><button class="button" data-cloud="access">Acessos</button><button class="button" data-cloud="history">Histórico do painel</button><button class="button" data-cloud="more">Mais tarefas</button>';document.getElementById('main').prepend(bar);
 bar.onclick=e=>attempt(async()=>{const {board,workspace}=ui.current(),role=repo.role(workspace);const action=e.target.dataset.cloud;if(action==='invite')showInvite(repo);if(action==='history')await showHistory(repo);if(action==='access'){await showBoardAccess(repo);return;}if(action==='more'&&board)await repo.loadBoard(board.id,true);

 });}
 const bar=document.getElementById('cloudTools');bar.querySelector('[data-cloud="invite"]').hidden=role!=='owner';bar.querySelector('[data-cloud="access"]').hidden=role!=='owner';bar.querySelector('[data-cloud="more"]').hidden=!board?._hasMore;

}
begin().catch(e=>{if(ui)ui.loading('<h1>Não foi possível conectar</h1><p>'+esc(e.message)+'</p><button class="button" onclick="location.reload()">Tentar novamente</button>');else status(e.message);});

function setupImport(repo){if(window.WorkshAccountRole==='guest'||window.WorkshAccountDriveRequired)return;
 if(!document.getElementById('cloudImport')){const button=document.createElement('button');button.id='cloudImport';button.className='top-button';button.textContent='Importar dados locais';document.querySelector('.top-right').append(button);button.onclick=()=>attempt(async()=>{const plan=await preview(repo.identity.id);ui.editor('Importar dados deste navegador',`<p>${esc(plan.warning)}</p><pre>${esc(JSON.stringify(plan.counts,null,2))}</pre><p>Uma cópia será criada na sua conta. Os dados do navegador serão mantidos.</p><button type="button" class="button" id="cloudSeed">Baixar seed.sql</button>`,async()=>{await importConfirmed(plan);await repo.load();status('Importação concluída. Dados locais preservados.');},'Confirmar importação');document.getElementById('cloudSeed').onclick=()=>{const blob=new Blob([seedSQL(plan)],{type:'text/plain'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='worksh-seed.sql';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};});}
}

async function showBoardAccess(repo){
 const {board,workspace}=ui.current();if(!board||repo.role(workspace)!=='owner')throw Error('Abra um painel do qual você é proprietário.');
 const members=await unwrap(client().from('board_members').select('user_id,can_edit').eq('board_id',board.id));
 const registered=window.WorkshAccountRole==='admin'?await invoke('admin-users',{action:'list'}):workspace.people||[];
 const available=registered.filter(person=>person.id!==workspace.owner_id&&person.id!==repo.identity.id&&!person.is_blocked&&!members.some(member=>member.user_id===person.id)&&person.email);
 const personName=id=>{const person=registered.find(p=>p.id===id)||workspace.people.find(p=>p.id===id);return person?.name||person?.email||'Participante cadastrado';};
 ui.editor('Acessos ao painel',`<label>Selecionar pessoa cadastrada<select id="teamMemberSelect"><option value="">Selecione uma pessoa</option>${available.map(p=>`<option value="${esc(p.id)}">${esc(p.name||p.email)} · ${esc(p.email)}</option>`).join('')}</select></label><label>Permissão<select id="teamMemberPermission"><option value="edit">Pode editar</option><option value="read">Somente leitura</option></select></label><button type="button" class="button primary" id="addTeamMember" ${available.length?'':'disabled'}>Adicionar ao painel</button>${available.length?'':'<p>Nenhuma outra pessoa cadastrada disponível para sua conta.</p>'}<p role="alert" id="boardAccessError" hidden></p><div>${members.map(m=>`<div class="member-row"><span>${esc(personName(m.user_id))}</span><button type="button" class="button" data-access-toggle="${esc(m.user_id)}">${m.can_edit?'Permitir só leitura':'Permitir edição'}</button><button type="button" class="button" data-access-remove="${esc(m.user_id)}">Remover acesso</button></div>`).join('')||'<p>Nenhum membro neste painel.</p>'}</div>`,()=>true,'Fechar');
 const run=async(button,action)=>{button.disabled=true;try{await action();await repo.loadBoard(board.id);ui.close();await showBoardAccess(repo);}catch(e){const note=document.getElementById('boardAccessError');if(note){note.hidden=false;note.textContent=e.message;}button.disabled=false;}};
 document.getElementById('addTeamMember').onclick=e=>run(e.currentTarget,async()=>{const person=available.find(p=>p.id===document.getElementById('teamMemberSelect').value);if(!person)throw Error('Selecione uma pessoa cadastrada.');await call('add_team_member',{board:board.id,email_address:person.email,editable:document.getElementById('teamMemberPermission').value==='edit'});});
 document.querySelectorAll('[data-access-toggle]').forEach(b=>b.onclick=()=>run(b,()=>grant(board.id,b.dataset.accessToggle,!members.find(m=>m.user_id===b.dataset.accessToggle).can_edit)));
 document.querySelectorAll('[data-access-remove]').forEach(b=>b.onclick=()=>run(b,()=>revoke(board.id,b.dataset.accessRemove)));
}
