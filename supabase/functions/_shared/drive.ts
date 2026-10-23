import {external} from './core.ts';
export async function newDriveId(token:string){const r=await external('https://www.googleapis.com/drive/v3/files/generateIds?count=1&space=drive&type=files',{headers:{Authorization:`Bearer ${token}`}});return (await r.json()).ids[0] as string;}
export async function driveFile(token:string,id:string){const r=await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(id)}?fields=id,mimeType,parents,trashed`,{headers:{Authorization:`Bearer ${token}`},signal:AbortSignal.timeout(20000)});if(r.status===404){await r.body?.cancel();return null;}if(!r.ok){await r.body?.cancel();throw Error('Drive unavailable');}return await r.json();}
export async function ensureFolder(token:string,id:string,name:string,parent?:string){
 const existing=await driveFile(token,id);
 if(existing){if(existing.trashed||existing.mimeType!=='application/vnd.google-apps.folder')throw Error('Folder unavailable');
  if(parent&&!existing.parents?.includes(parent)){const q=new URLSearchParams({addParents:parent,fields:'id'});if(existing.parents?.length)q.set('removeParents',existing.parents.join(','));const r=await external(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(id)}?${q}`,{method:'PATCH',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:'{}'});await r.body?.cancel();}return;
 }
 const r=await fetch('https://www.googleapis.com/drive/v3/files',{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({id,name,mimeType:'application/vnd.google-apps.folder',...(parent?{parents:[parent]}:{})}),signal:AbortSignal.timeout(20000)});
 if(!r.ok){await r.body?.cancel();const reconciled=await driveFile(token,id);if(!reconciled||reconciled.trashed)throw Error('Folder creation failed');}else await r.body?.cancel();
}
