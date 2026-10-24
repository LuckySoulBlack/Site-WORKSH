import {readTaskAssignees} from './task-assignees.js';
import {page} from './boards.js';
async function all(table,columns,board_id){let result=[],cursor=null;for(let i=0;i<51;i++){const rows=await page(table,columns,{board_id},cursor,100);result.push(...rows);if(result.length>5000)throw Error('O limite desta exportação é de 5000 registros por tipo.');if(rows.length<100)return result;cursor=rows.at(-1);}throw Error('Não foi possível concluir a exportação.');}
export async function fetchExportProject(ui,boardId,includePeople){
 const [tasks,groups]=await Promise.all([all('tasks','id,title,status,due,assignee_id,group_id,created_at'+(window.WorkshBoardFeatures?',start_date':''),boardId),all('groups','id,name,created_at',boardId)]);
 const snapshot=ui.snapshot(),workspace=snapshot.workspaces.find(w=>w.boards.some(b=>b.id===boardId)),board=workspace?.boards.find(b=>b.id===boardId);if(!board)throw Error('Quadro não encontrado.');
 const names=new Map(groups.map(g=>[g.id,g.name])),assignments=includePeople&&window.WorkshCooperativeTasks?await readTaskAssignees(tasks.map(t=>t.id)):[];
 return {title:board.name,tasks:tasks.map(t=>({title:t.title,group:names.get(t.group_id)||'Sem grupo',status:t.status,start_date:t.start_date,due:t.due,...(includePeople?{assignee:[...new Set([t.assignee_id,...assignments.filter(a=>a.task_id===t.id).map(a=>a.user_id)].filter(Boolean))].map(id=>workspace.people.find(p=>p.id===id)?.name||'Participante').join(', ')||null}:{})}))};
}
