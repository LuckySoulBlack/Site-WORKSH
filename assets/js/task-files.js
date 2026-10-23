import {client,unwrap,invoke} from './supabase-client.js';
import {upload,watchJob,download,mimes} from './upload.js';
import {canEdit} from './permissions.js';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export function setupTaskFiles(repo,ui){
 window.WorkshTaskFiles=async taskId=>{try{
  const {board,workspace}=ui.current();if(!board?.tasks.some(t=>t.id===taskId))return;
  const owner=repo.role(workspace)==='owner',editable=canEdit(repo.role(workspace),repo.members.get(board.id));
  const rows=await unwrap(client().from('attachments').select('id,file_name,size_bytes').eq('board_id',board.id).eq('task_id',taskId).order('created_at',{ascending:false}).limit(50));
  ui.editor('Arquivos da tarefa',`<label>Enviar ao Drive do proprietário · até 5 MB<input id="taskFile" type="file" accept="${mimes.join(',')}" ${editable?'':'disabled'}></label><div class="task-file-list">${rows.map(row=>`<p><button type="button" class="button" data-task-download="${row.id}">${esc(row.file_name)}</button>${owner?` <button type="button" class="button danger" data-task-remove="${row.id}">Remover</button>`:''}</p>`).join('')||'<p>Nenhum arquivo nesta tarefa.</p>'}</div>`,()=>ui.close(),'Fechar');
  document.getElementById('taskFile').onchange=async event=>{try{
   const file=event.target.files?.[0];if(!file)return;event.target.disabled=true;
   const id=await upload(file,board.id,taskId),controller=new AbortController();document.getElementById('editor').addEventListener('close',()=>controller.abort(),{once:true});
   ui.message('Arquivo recebido. Enviando ao Drive.');
   const job=await watchJob(id,j=>ui.message(j.status==='done'?'Arquivo salvo no Drive.':j.last_error||'Processando arquivo...'),controller.signal);
   if(job?.status==='done'&&!controller.signal.aborted)await window.WorkshTaskFiles(taskId);
  }catch(e){ui.message(e.message);event.target.disabled=false;}};
  document.querySelectorAll('[data-task-download]').forEach(button=>button.onclick=()=>download(button.dataset.taskDownload,rows.find(r=>r.id===button.dataset.taskDownload).file_name).catch(e=>ui.message(e.message)));
  document.querySelectorAll('[data-task-remove]').forEach(button=>button.onclick=async()=>{try{await invoke('file-access',{attachment_id:button.dataset.taskRemove,action:'delete'});ui.close();ui.message('Remoção enfileirada para a lixeira do Drive.');}catch(e){ui.message(e.message);}});
 }catch(e){ui.message(e.message);}};
}
