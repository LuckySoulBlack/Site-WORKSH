// Browser module. Reading/previewing never writes to Supabase or deletes local data.
import {call,client,unwrap,user} from '../assets/js/supabase-client.js';
const key='worksh.workspace.v1';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const literal=v=>v==null?'null':"'"+String(v).replace(/'/g,"''")+"'";
async function mapped(owner,type,id){const a=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(`WORKSH-import-v1:${owner}:${type}:${id}`))).slice(0,16);a[6]=(a[6]&15)|128;a[8]=(a[8]&63)|128;const h=[...a].map(x=>x.toString(16).padStart(2,'0')).join('');return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20)}`;}
export async function preview(owner){
 if(!uuid.test(owner))throw Error('Owner inválido.');const raw=localStorage.getItem(key);if(!raw)throw Error('Nenhum dado local encontrado.');if(raw.length>5242880)throw Error('Backup local excede 5 MB.');
 const source=JSON.parse(raw);if(source.version!==1||!Array.isArray(source.workspaces))throw Error('Backup incompatível.');
 const rows={workspaces:[],workspace_members:[],boards:[],groups:[],tasks:[],comments:[],board_settings:[]};
 let people=0,activities=0;
 for(const w of source.workspaces){const wid=await mapped(owner,'workspace',w.id);rows.workspaces.push({id:wid,name:w.name,description:w.description||'',owner_id:owner,modules:w.modules||[],company:source.company||{}});rows.workspace_members.push({workspace_id:wid,user_id:owner,role:'owner',must_change_password:false,invited_by:owner});people+=(w.people||[]).length;activities+=(w.activity||[]).length;
 for(const b of w.boards||[]){const bid=await mapped(owner,'board',b.id);rows.boards.push({id:bid,workspace_id:wid,name:b.name,description:b.description||'',created_by:owner});
 for(const [position,g]of (b.groups||[]).entries())rows.groups.push({id:await mapped(owner,'group',g.id),board_id:bid,name:g.name,position});
 for(const [position,t]of (b.tasks||[]).entries()){const tid=await mapped(owner,'task',t.id);rows.tasks.push({id:tid,board_id:bid,group_id:t.group?await mapped(owner,'group',t.group):null,title:t.title,description:t.description||'',status:t.status||'todo',priority:t.priority||'normal',due:t.due||null,checklist:t.checklist||[],position,created_by:owner});
 for(const c of t.comments||[])rows.comments.push({id:await mapped(owner,'comment',c.id||c.date+':'+c.text),board_id:bid,task_id:tid,author_id:owner,content:c.text});}
 // People remain in the original local backup; they are never distributed to boards.
 }}
 return {rows,counts:Object.fromEntries(Object.entries(rows).map(([t,r])=>[t,r.length])),warning:`${people} cadastros locais não concedem acesso. ${activities} eventos locais não serão importados como auditoria autenticada. Responsáveis antigos devem ser atribuídos após os convites.`};
}
export function seedSQL(plan){const lines=['-- Revisar antes de executar; contém dados pessoais do backup. Não publicar.','begin;'];
 for(const [table,rows]of Object.entries(plan.rows))for(const row of rows){const columns=Object.keys(row);const values=columns.map(k=>{const v=row[k];if(typeof v==='boolean')return String(v);if(typeof v==='number')return String(v);if(Array.isArray(v)&&k==='modules')return `ARRAY[${v.map(literal).join(',')}]::text[]`;if(v&&typeof v==='object')return literal(JSON.stringify(v))+'::jsonb';return literal(v);});lines.push(`insert into public.${table} (${columns.join(',')}) values (${values.join(',')}) on conflict do nothing;`);}lines.push('commit;');return lines.join('\n');}
export async function importConfirmed(plan){
 const me=await user();if(plan.rows.workspaces.some(w=>w.owner_id!==me.id))throw Error('Owner do plano não corresponde à sessão.');
 // Each request uses the user JWT and RLS. Existing deterministic IDs make retries safe.
 for(const w of plan.rows.workspaces){const existing=await unwrap(client().from('workspaces').select('id').eq('id',w.id));if(!existing.length)await call('create_workspace',{workspace_name:w.name,workspace_id:w.id});await unwrap(client().from('workspaces').update({description:w.description,modules:w.modules,company:w.company}).eq('id',w.id));}
 for(const table of ['boards','groups','tasks','comments','board_settings']){
 for(let i=0;i<plan.rows[table].length;i+=50){const batch=plan.rows[table].slice(i,i+50);const existing=await unwrap(client().from(table).select('id').in('id',batch.map(r=>r.id)));const found=new Set(existing.map(r=>r.id));const pending=batch.filter(r=>!found.has(r.id));if(pending.length)await unwrap(client().from(table).insert(pending));}}
 return plan.counts;
}
