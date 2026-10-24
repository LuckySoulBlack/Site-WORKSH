import {buildProjectHTML,escapeHTML as esc} from './project-render.js?v=20261023.16';
async function embeddedLogo(url){
 if(!url)return null;if(/^data:image\/(png|webp|jpeg);base64,/i.test(url))return url;
 try{const response=await fetch(url);if(!response.ok)return null;const blob=await response.blob();if(blob.size>1048576||!['image/png','image/jpeg','image/webp'].includes(blob.type))return null;return await new Promise(resolve=>{const r=new FileReader();r.onload=()=>resolve(r.result);r.onerror=()=>resolve(null);r.readAsDataURL(blob);});}catch{return null;}
}
export function setupProjectExport(ui,services={}){
 const show=async()=>{try{
  const {board,workspace}=ui.current();if(!board){ui.message('Abra um quadro para compartilhar o projeto.');return;}
  const owner=!window.WorkshRemote||workspace.owner_id===window.WorkshRemote.identity.id;
  ui.editor('Compartilhar projeto',`<label>Visualização<select name="view"><option value="gantt">Gantt</option><option value="kanban">Kanban</option><option value="table">Tabela</option></select></label><label class="checklist-row"><input name="people" type="checkbox" checked>Mostrar responsáveis (desmarque para ocultar)</label><p>Compartilha o projeto, as etapas, os títulos das tarefas, status e datas. Documentos, comentários, contatos e anexos ficam de fora.</p><h3>Arquivo HTML</h3><p>Uma cópia para enviar ou abrir sem login. Não recebe atualizações automáticas.</p>${owner?'<hr><h3>Link de acompanhamento</h3><label>Validade<select id="shareDays"><option value="1">1 dia</option><option value="7" selected>7 dias</option><option value="30">30 dias</option></select></label><p>Qualquer pessoa com o link poderá ver os dados selecionados enquanto estiver válido. Você pode revogar o acesso.</p><button id="createProjectShare" type="button" class="button">Criar link de leitura</button><div id="projectShareResult" role="status"></div><div id="existingProjectShares"></div>':'<p>Somente o dono pode criar um link externo de acompanhamento.</p>'}`,async fd=>{
   try{
    const includePeople=fd.has('people'),snapshot=ui.snapshot(),dto=services.fetchProject?await services.fetchProject(board.id,includePeople):{title:board.name,tasks:board.tasks.map(t=>({title:t.title,group:board.groups.find(g=>g.id===t.group)?.name||'Sem grupo',status:t.status,start_date:t.start_date||null,due:t.due||null,...(includePeople?{assignee:[...new Set([t.person,...(t.assignees||[])].filter(Boolean))].map(id=>workspace.people.find(p=>p.id===id)?.name||'Participante').join(', ')||null}:{})}))};
    Object.assign(dto,{companyName:snapshot.company.name||'',includePeople,generatedAt:new Date().toISOString(),logo:await embeddedLogo(snapshot.company.logo_url)});
    const html=buildProjectHTML(dto,String(fd.get('view'))),url=URL.createObjectURL(new Blob([html],{type:'text/html;charset=utf-8'})),a=document.createElement('a');a.href=url;a.download='projeto-'+String(fd.get('view'))+'.html';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);ui.close();ui.message('HTML gerado com o quadro completo.');
   }catch(e){ui.message(e.message);}
  },'Baixar HTML');
  if(!owner)return;
  const output=document.getElementById('projectShareResult'),list=document.getElementById('existingProjectShares');
  const refresh=async()=>{if(!services.listShares)return;const rows=await services.listShares(board.id);list.innerHTML=rows.map(r=>`<p>${esc({gantt:'Gantt',kanban:'Kanban',table:'Tabela'}[r.view_type])} · ${r.revoked_at?'Revogado':'Válido até '+esc(new Date(r.expires_at).toLocaleString('pt-BR'))}${!r.revoked_at?` <button type="button" class="button" data-revoke-share="${r.id}">Revogar</button>`:''}</p>`).join('');list.querySelectorAll('[data-revoke-share]').forEach(b=>b.onclick=async()=>{try{await services.revokeShare(b.dataset.revokeShare);output.textContent='Link revogado. A cópia que alguém já baixou não pode ser recolhida.';await refresh();}catch(e){ui.message(e.message);}});};
  document.getElementById('createProjectShare').onclick=async()=>{try{
   if(!services.createShare){output.textContent='O link atualizado depende da ativação no Supabase. Você já pode baixar o HTML para validar.';return;}
   const form=document.getElementById('editForm'),button=document.getElementById('createProjectShare');button.disabled=true;
   try{const result=await services.createShare(board.id,form.querySelector('[name="view"]').value,form.querySelector('[name="people"]').checked,Number(document.getElementById('shareDays').value));const url=new URL('project-share.html',location.href);url.hash=result.token;output.innerHTML=`<label>Link de leitura<input readonly value="${esc(url.href)}" aria-label="Link de leitura"></label><p>Copie este endereço. Ele é a autorização de acesso e só será exibido agora.</p>`;await refresh();}finally{button.disabled=false;}
  }catch(e){ui.message(e.message);}};
  try{await refresh();}catch{output.textContent='O acompanhamento por link ainda precisa ser ativado. Você já pode gerar o HTML.';}
 }catch(e){ui.message(e.message);}};
 return {mount(){if(ui.current().page!=='board'||!ui.current().board||document.getElementById('exportProjectButton'))return;const toolbar=document.querySelector('.toolbar');if(toolbar){const b=document.createElement('button');b.id='exportProjectButton';b.className='button';b.textContent='Compartilhar / HTML';b.onclick=show;toolbar.append(b);}},show};
}
