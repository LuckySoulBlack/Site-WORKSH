import {signedAvatars} from './profile-photos.js';
import {client,unwrap,call} from './supabase-client.js';
import {workspaceColumns,page,taskColumns} from './boards.js';
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const tableRows=d=>{
 const out={boards:[],groups:[],tasks:[],comments:[]};
 for(const w of d.workspaces)for(const b of w.boards){out.boards.push({id:b.id,workspace_id:w.id,name:b.name,description:b.description||'',created_by:b.created_by||d.user_id,_version:b.updated_at||null});
 for(const [position,g] of b.groups.entries())out.groups.push({id:g.id,board_id:b.id,name:g.name,position,_version:g.updated_at||null});
 for(const [position,t]of b.tasks.entries()){out.tasks.push({id:t.id,board_id:b.id,group_id:t.group||null,title:t.title,description:t.description||'',link_url:t.link_url||null,status:t.status,position,created_by:t.created_by||d.user_id,due:t.due||null,priority:t.priority||'normal',checklist:t.checklist||[],assignee_id:t.person||null,...(window.WorkshBoardFeatures?{start_date:t.start_date||null,custom_values:t.custom_values||{}}:{}),_version:t.updated_at||null});
 for(const c of t.comments||[])out.comments.push({id:c.id,board_id:b.id,task_id:t.id,author_id:c.author_id||d.user_id,content:c.text,_version:c.updated_at||null});}}
 return out;
};
export class RemoteRepository {
 constructor(identity,ui){this.identity=identity;this.ui=ui;this.baseline=null;this.busy=false;this.loaded=new Set();this.cursors=new Map();this.members=new Map();}
 async load(){
 window.WorkshBoardFeatures=await call('board_features').catch(()=>false);
 const [workspaces,boards,profiles]=await Promise.all([
 page('workspaces',workspaceColumns,{},null,100),page('boards','id,workspace_id,name,description,created_by,created_at,updated_at',{},null,100),
 unwrap(client().from('profiles').select(window.WorkshBoardFeatures?'id,full_name,phone,job,theme,avatar_path':'id,full_name,phone,job,theme').eq('id',this.identity.id).single())]);
 await signedAvatars([profiles]);
 const data={version:1,user_id:this.identity.id,profile:{avatar_path:profiles.avatar_path,avatar_url:profiles.avatar_url,name:profiles.full_name,email:this.identity.email,phone:profiles.phone,job:profiles.job,theme:profiles.theme},company:{},connections:{},workspaces:workspaces.map(w=>({...w,modules:w.modules||[],people:[],activity:[],boards:boards.filter(b=>b.workspace_id===w.id).map(b=>({...b,groups:[],tasks:[]}))}))};
 this.loaded.clear();this.cursors.clear();if(data.workspaces[0])data.workspaces[0]._counts=await call('workspace_counts',{w:data.workspaces[0].id});this.baseline=structuredClone(data);this.ui.load(data);return data;
 }
 async loadBoard(id,more=false){
 if(this.busy)throw Error('Aguarde a gravação atual.');
 const data=this.ui.snapshot(),board=data.workspaces.flatMap(w=>w.boards).find(b=>b.id===id);if(!board)return;
 if(this.loaded.has(id)&&!more)return;
 const filters={board_id:id}; const [tasks,groups,comments,members,names,settings]=await Promise.all([
 page('tasks',taskColumns+(window.WorkshBoardFeatures?',start_date,custom_values':''),filters,more?this.cursors.get(id):null,20),
 unwrap(client().from('groups').select('id,name,position,board_id,updated_at').eq('board_id',id).order('position').limit(1000)),
 page('comments','id,board_id,task_id,author_id,content,created_at,updated_at',filters,null,100),
 unwrap(client().from('board_members').select('user_id,board_id,can_edit').eq('board_id',id)),call(window.WorkshBoardFeatures?'board_people':'shared_profiles',{b:id}),unwrap(client().from('board_settings').select('id,key,value,updated_at').eq('board_id',id).eq('key','columns'))]);
 await signedAvatars(names);board._columnSetting=settings[0]||null;if(settings[0])board.columns=settings[0].value.columns;
 this.members.set(id,members.find(x=>x.user_id===this.identity.id));
 const mapped=tasks.map(t=>({...t,group:t.group_id,person:t.assignee_id||'',due:t.due||'',comments:comments.filter(c=>c.task_id===t.id).map(c=>({...c,text:c.content,date:c.created_at}))}));
 board.tasks=more?[...board.tasks,...mapped.filter(t=>!board.tasks.some(x=>x.id===t.id))]:mapped;board.groups=groups;
 board._hasMore=tasks.length===20;this.cursors.set(id,tasks.at(-1)||null);
 const w=data.workspaces.find(w=>w.boards.some(b=>b.id===id));const people=new Map(w.people.map(p=>[p.id,p]));names.forEach(p=>people.set(p.id,{id:p.id,name:p.full_name||'Participante',avatar_path:p.avatar_path,avatar_url:p.avatar_url,email:'',role:p.id===w.owner_id?'Proprietário':'Membro'}));w.people=[...people.values()];
 this.loaded.add(id);this.baseline=structuredClone(data);this.ui.load(data,{board:id});
 }
 role(workspace){return workspace?.owner_id===this.identity.id?'owner':'member';}
 async save(snapshot){
 if(this.busy)throw Error('Aguarde a gravação atual.');this.busy=true;document.documentElement.dataset.saving='true';
 const before=this.baseline,next=structuredClone(snapshot),changes=[];next.user_id=this.identity.id;
 try{
 const p=next.profile,bp=before.profile;
 if(!same(p,bp))changes.push({table:'profiles',op:'update',id:this.identity.id,values:{full_name:p.name,phone:p.phone,job:p.job,theme:p.theme,...(window.WorkshBoardFeatures?{avatar_path:p.avatar_path||null}:{})}});
 for(const w of next.workspaces){
 const old=before.workspaces.find(x=>x.id===w.id);
 if(!old){changes.push({table:'workspaces',op:'workspace_create',id:w.id,values:{name:w.name}});w.owner_id=this.identity.id;}
 const values={name:w.name,description:w.description||'',modules:w.modules,company:w.id===this.ui.current().workspace?.id?next.company:(w.company||{})};
 const previous=old?{name:old.name,description:old.description||'',modules:old.modules,company:old.company||{}}:null;
 if(this.role(w)==='owner'&&!same(values,previous)){changes.push({table:'workspaces',op:'update',id:w.id,version:old?.updated_at||null,values});w.company=values.company;}}
 const a=tableRows(before),b=tableRows(next);
 const mutable={boards:['name','description'],groups:['name','position'],tasks:['group_id','title','description','link_url','status','position','due','priority','checklist','assignee_id',...(window.WorkshBoardFeatures?['start_date','custom_values']:[])],comments:['content']};
 for(const table of ['boards','groups','tasks','comments'])for(const row of b[table]){
 const old=a[table].find(x=>x.id===row.id);
 if(!old){const {_version,...values}=row;changes.push({table,op:'insert',values});}
 else {const values={};for(const key of mutable[table])if(!same(row[key],old[key]))values[key]=row[key];if(Object.keys(values).length)changes.push({table,op:'update',id:row.id,version:old._version,values});}}
 for(const table of ['comments','tasks','groups','boards'])for(const row of a[table].filter(row=>!b[table].some(x=>x.id===row.id)))changes.push({table,op:'delete',id:row.id,version:row._version});
 for(const w of before.workspaces.filter(w=>!next.workspaces.some(x=>x.id===w.id)))changes.push({table:'workspaces',op:'delete',id:w.id,version:w.updated_at||null});
 for(const w of next.workspaces)for(const board of w.boards){const previous=before.workspaces.flatMap(w=>w.boards).find(b=>b.id===board.id);if(board.columns&&!same(board.columns,previous?.columns)){const setting=previous?._columnSetting;const id=setting?.id||crypto.randomUUID();board._columnSetting={id,key:'columns',value:{columns:board.columns}};changes.push(setting?{table:'board_settings',op:'update',id,version:setting.updated_at,values:{value:{columns:board.columns}}}:{table:'board_settings',op:'insert',values:{id,board_id:board.id,key:'columns',value:{columns:board.columns}}});}}
 if(changes.length>100)throw Error('Edite no máximo 100 registros por operação.');
 const results=changes.length?await call('apply_changes',{changes}):[];
 for(const r of results){let target;
 if(r.table==='workspaces')target=next.workspaces.find(x=>x.id===r.id);
 else if(r.table==='boards')target=next.workspaces.flatMap(w=>w.boards).find(x=>x.id===r.id);
 else if(r.table==='groups')target=next.workspaces.flatMap(w=>w.boards).flatMap(b=>b.groups).find(x=>x.id===r.id);
 else if(r.table==='tasks')target=next.workspaces.flatMap(w=>w.boards).flatMap(b=>b.tasks).find(x=>x.id===r.id);
 else if(r.table==='comments')target=next.workspaces.flatMap(w=>w.boards).flatMap(b=>b.tasks).flatMap(t=>t.comments).find(x=>x.id===r.id);
 if(r.table==='board_settings')target=next.workspaces.flatMap(w=>w.boards).map(b=>b._columnSetting).find(s=>s?.id===r.id);
 if(target)target.updated_at=r.updated_at;
 }
 const current=next.workspaces.find(w=>w.id===this.ui.current().workspace?.id);if(current)current._counts=await call('workspace_counts',{w:current.id});
 this.baseline=next;this.ui.load(next);this.ui.markSaved();
 }catch(e){await this.load();throw e;}finally{this.busy=false;delete document.documentElement.dataset.saving;}
 }
}
