import assert from 'node:assert/strict';import {buildProjectHTML,renderProject} from '../assets/js/project-render.js';
const p={title:'Projeto <script>alert(1)</script>',companyName:'Empresa Teste',includePeople:false,tasks:[{title:'Tarefa <img src=x>',status:'progress',start_date:'2026-10-23',due:'2026-10-25',assignee:'PRIVATE PERSON'}]};
for(const view of ['table','gantt','kanban']){const h=buildProjectHTML(p,view);assert.ok(h.includes('&lt;script&gt;'));assert.ok(!h.includes('PRIVATE PERSON'));assert.ok(!h.includes('<script>'));assert.ok(h.includes('Content-Security-Policy'));assert.ok(!h.includes('supabase'));assert.ok(h.includes('não recebe atualizações automáticas'));}
assert.ok(renderProject({...p,live:true},'kanban').includes('Atualizações consultadas'));
assert.ok(buildProjectHTML({...p,logo:'javascript:alert(1)'},'table').indexOf('javascript:')<0);
console.log('PASS: standalone HTML table/Kanban/Gantt, escaped untrusted text, no backend credentials, safe logo and static/live labels.');
