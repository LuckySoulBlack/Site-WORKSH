import {call,invoke} from './supabase-client.js';
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export async function connectOwnerDrive(){const result=await invoke('google-oauth-start',{});const url=new URL(result.url);if(url.origin!=='https://accounts.google.com')throw Error('Não foi possível iniciar a autorização.');location.assign(url.toString());}
export function setupDriveOnboarding(identity,ui){
 const guest=identity.profile_role==='guest';window.WorkshAccountDriveRequired=!guest&&!!identity.drive_required;let force=false;
 const result=new URLSearchParams(location.hash.slice(1)).get('drive');
 const messages={connected:'Google Drive conectado à sua conta.',cancelled:'Autorização cancelada. Nenhuma nova conexão foi concluída.',invalid:'A autorização expirou. Tente conectar novamente.',permissions:'Autorize o acesso aos arquivos da WORKSH para continuar.',identity:'Não foi possível confirmar sua conta Google.',different_account:'Reconecte a mesma conta Google para preservar o acesso aos seus arquivos.',existing_files:'Esta conta Google não tem acesso às pastas existentes do workspace.',failed:'Não foi possível concluir a conexão. Tente novamente.'};
 if(result){ui.message(messages[result]||'Confira a conexão com seu Google Drive.');window.history.replaceState(null,'',location.pathname+location.search);}
 async function verify(){const state=await call('owner_drive_status');if(state.connected){location.reload();return;}ui.message(state.status==='reconnect_required'?'Sua autorização precisa ser renovada.':'A autorização do Google Drive ainda não foi concluída.');}
 function bind(root){root.querySelector('[data-connect-owner-drive]').onclick=async e=>{const b=e.currentTarget;b.disabled=true;const note=root.querySelector('[role="status"]');try{await connectOwnerDrive();}catch(error){if(note)note.textContent=error.message;else ui.message(error.message);b.disabled=false;}};const check=root.querySelector('[data-check-owner-drive]');if(check)check.onclick=()=>verify().catch(e=>ui.message(e.message));}
 function show(){force=true;render();}
 function render(){
  if(guest)return;
  const driveButton=document.querySelector('#main .integration-card [data-action="edit-integration"][data-id="drive"]');if(driveButton){const card=driveButton.closest('.integration-card');const state=card.querySelector('.connection-status');if(state)state.textContent=identity.drive_connected?'Conectado: '+(identity.drive_email||'sua conta Google'):'Conexão pendente';const connect=card.querySelector('button:not([data-action])');if(connect&&identity.drive_connected)connect.textContent='Reconectar meu Google Drive';}
  if(!identity.drive_required)return;
  const main=document.getElementById('main'),existing=ui.snapshot().workspaces.length>0;
  if((!existing||force)&&ui.current().page!=='settings'){
   main.innerHTML=`<section class="drive-onboarding"><img src="assets/logo.svg" alt="WORKSH" width="64" height="64"><p class="drive-steps">1. Sua conta &nbsp; 2. Sua senha &nbsp; <strong>3. Seu Google Drive</strong></p><h1>Seu trabalho, no seu Drive.</h1><p>Conecte a conta Google que você quer usar para os arquivos da WORKSH. Uma única autorização será utilizada em todos os seus workspaces.</p><div class="drive-folder-preview"><strong>WORKSH</strong><span>↳ Seus workspaces</span><span>　↳ Quadros e arquivos da equipe</span></div><button class="button primary" data-connect-owner-drive>Conectar meu Google Drive</button><button class="button" data-check-owner-drive>Já autorizei, verificar conexão</button>${existing?'<button class="button" id="driveViewExisting">Ver ambientes existentes</button>':''}<p role="status">${esc(result&&result!=='connected'?messages[result]:'Você escolherá sua conta e autorizará o acesso na tela do Google.')}</p><small>A WORKSH não recebe sua senha Google. Convidados usam o armazenamento do proprietário. Textos e tabelas continuam no banco da plataforma.</small></section>`;
   bind(main);if(existing)main.querySelector('#driveViewExisting').onclick=()=>{force=false;window.WorkshRemote.load();};return;
  }
  if(!document.getElementById('drivePendingBanner')){
   const banner=document.createElement('section');banner.id='drivePendingBanner';banner.className='drive-pending-banner';banner.innerHTML='<div><strong>Conecte seu Google Drive</strong><p>Seus ambientes existentes foram preservados. Para criar novos workspaces e usar arquivos, conecte o Drive da sua conta.</p></div><button class="button primary" data-connect-owner-drive>Conectar Drive</button>';main.prepend(banner);bind(banner);
  }
 }
 return {render,show,required:!guest&&!!identity.drive_required};
}
