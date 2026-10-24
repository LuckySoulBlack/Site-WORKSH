import vm from 'node:vm';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
let connected=false,html='',settingsTab;
const input={disabled:false},settings={};
const query={select(){return this},eq(){return this},order(){return this},limit(){return Promise.resolve([])},single(){return Promise.resolve({drive_folder_id:connected?'folder':null})}};
const context={window:{},client:()=>({from:()=>query}),unwrap:async p=>await p,canEdit:()=>true,mimes:['image/png'],document:{getElementById:id=>id==='taskFile'?input:html.includes('openDriveSettings')?settings:null,querySelectorAll:()=>[]}};
vm.createContext(context);vm.runInContext(readFileSync('assets/js/task-files.js','utf8').replace(/^import .*;\r?\n/gm,'').replace('export function','function'),context);
context.setupTaskFiles({role:()=> 'owner',members:new Map()},{current:()=>({workspace:{id:'w'},board:{id:'b',tasks:[{id:'t'}]}}),editor:(_t,content)=>html=content,close(){},openSettings:tab=>settingsTab=tab,message:message=>{throw Error(message)}});
await context.window.WorkshTaskFiles('t');assert.ok(html.includes('Google Drive pendente'));assert.ok(html.includes('id="taskFile"')&&html.includes(' disabled'));settings.onclick();assert.equal(settingsTab,'integrations');
connected=true;await context.window.WorkshTaskFiles('t');assert.ok(!html.includes('Google Drive pendente'));assert.ok(!html.includes(' disabled'));
const app=readFileSync('assets/js/app.js','utf8');assert.ok(app.includes('id="teamMemberSelect"'));assert.ok(!app.includes('data-cloud="files"'));assert.ok(!app.includes('data-cloud="drive"'));assert.ok(!app.includes('teamMemberEmail'));
console.log('PASS: upload disabled until owner folder exists, settings shortcut targets integrations, registered-person selector and duplicate toolbar controls removed. Network mocked.');

