import {client,unwrap} from './supabase-client.js';
export async function signedAvatars(people){
 const paths=[...new Set(people.map(p=>p.avatar_path).filter(Boolean))];if(!paths.length)return;
 const {data,error}=await client().storage.from('profile-photos').createSignedUrls(paths,3600);
 if(error)return;const urls=new Map(data.map(p=>[p.path,p.signedUrl]));
 people.forEach(p=>p.avatar_url=urls.get(p.avatar_path)||'');
}
export function setupProfilePhotos(repo,ui){
 document.addEventListener('change',async event=>{
  if(event.target.id!=='profilePhoto')return;
  const file=event.target.files?.[0];if(!file)return;
  if(!window.WorkshBoardFeatures){ui.message('O envio de foto depende da atualização do banco.');return;}
  if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>10*1024*1024){ui.message('Escolha uma imagem JPG, PNG ou WebP de até 10 MB.');return;}
  try{
   const bitmap=await createImageBitmap(file),canvas=document.createElement('canvas');canvas.width=canvas.height=256;
   const size=Math.min(bitmap.width,bitmap.height);canvas.getContext('2d').drawImage(bitmap,(bitmap.width-size)/2,(bitmap.height-size)/2,size,size,0,0,256,256);bitmap.close();
   const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',.85));if(!blob)throw Error('Não foi possível preparar a imagem.');
   const path=repo.identity.id+'/avatar.webp';
   await unwrap(client().storage.from('profile-photos').upload(path,blob,{upsert:true,contentType:'image/webp',cacheControl:'0'}));
   const next=ui.snapshot();next.profile.avatar_path=path;const item={avatar_path:path};await signedAvatars([item]);next.profile.avatar_url=item.avatar_url;
   next.workspaces.forEach(w=>w.people.forEach(p=>{if(p.id===repo.identity.id){p.avatar_path=path;p.avatar_url=item.avatar_url;}}));
   await repo.save(next);ui.close();ui.message('Foto de perfil atualizada.');
  }catch(e){ui.message(e.message||'Não foi possível salvar a foto.');}
 });
}
