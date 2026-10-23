const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const entities={boards:'o quadro',groups:'o grupo',tasks:'a tarefa',comments:'o comentário',board_members:'o acesso ao quadro',workspace_members:'o acesso ao ambiente',workspaces:'o ambiente',attachments:'o arquivo',board_settings:'as configurações do quadro',invitations:'o convite',upload_jobs:'o envio de arquivo',oauth_states:'a autorização de conexão'};
const fields={name:'Nome',title:'Título',description:'Descrição',content:'Comentário',status:'Situação',priority:'Prioridade',due:'Prazo',link_url:'Link',can_edit:'Permissão de edição',position:'Ordem',checklist:'Checklist',modules:'Funcionalidades'};
const values={todo:'A fazer',progress:'Em andamento',blocked:'Bloqueado',done:'Concluído',normal:'Normal',high:'Alta',low:'Baixa',urgent:'Urgente'};
function valueText(value){if(value===null||value===undefined||value==='')return 'Não informado';if(typeof value==='boolean')return value?'Sim':'Não';if(typeof value==='object')return Array.isArray(value)?`${value.length} item(ns)`:'Informações atualizadas';return values[value]||String(value);}
export function renderHistory(rows,{userId,profile={},people=[]}={}){
 const names=new Map(people.map(p=>[p.id,p.name||p.full_name]));
 return rows.map(row=>{
  const actor=row.actor_name||(row.actor_id===userId?(profile.name||profile.email):names.get(row.actor_id))||(row.actor_id?'Participante não identificado':'Sistema');
  const initials=actor.trim().split(/\s+/).slice(0,2).map(p=>p[0]).join('').toUpperCase();
  const old=row.old_data||{},next=row.new_data||{},record=row.action==='DELETE'?old:next;
  const label=record.title||record.name||record.filename||record.file_name;
  const verb={INSERT:'Criou',UPDATE:'Atualizou',DELETE:'Excluiu'}[row.action]||'Alterou';
  const changes=row.action==='UPDATE'?Object.entries(fields).filter(([key])=>JSON.stringify(old[key])!==JSON.stringify(next[key])&&(key in old||key in next)).map(([key,label])=>`<li><strong>${esc(label)}</strong><span><del>${esc(valueText(old[key]))}</del><span aria-hidden="true"> → </span><ins>${esc(valueText(next[key]))}</ins></span></li>`).join(''):'';
  const date=new Date(row.created_at),valid=!Number.isNaN(date.valueOf());
  return `<article class="activity-item history-event"><div class="history-author"><span class="avatar" aria-hidden="true">${esc(initials)}</span><div><strong>${esc(actor)}</strong><time${valid?` datetime="${esc(date.toISOString())}"`:''}>${valid?esc(date.toLocaleString('pt-BR')):'Data não disponível'}</time></div></div><p class="history-action">${esc(verb)} ${esc(entities[row.table_name]||'o registro')}${label?` <strong>“${esc(label)}”</strong>`:''}.</p>${changes?`<ul class="history-changes">${changes}</ul>`:''}<details class="history-technical"><summary>Detalhes do registro</summary><pre>${esc(JSON.stringify({autor:actor,identificador_do_autor:row.actor_id,antes:row.old_data,depois:row.new_data},null,2))}</pre></details></article>`;
 }).join('')||'<p>Nenhuma alteração visível.</p>';
}
