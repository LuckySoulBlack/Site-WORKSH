import {client,unwrap} from './supabase-client.js';
export async function signedAvatars(people){
 const paths=[...new Set(people.map(p=>p.avatar_path).filter(Boolean))];if(!paths.length)return;
 const {data,error}=await client().storage.from('profile-photos').createSignedUrls(paths,3600);
 if(error)return;const urls=new Map(data.map(p=>[p.path,p.signedUrl]));
 people.forEach(p=>p.avatar_url=urls.get(p.avatar_path)||'');
}
export function setupProfilePhotos(repo){
 window.WorkshUploadProfilePhoto=async file=>{
  if(!window.WorkshBoardFeatures)throw Error('O envio de foto ainda não está disponível. Recarregue a página e tente novamente.');
  if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>10*1024*1024)throw Error('Escolha uma imagem JPG, PNG ou WebP de até 10 MB.');
  const bitmap=await createImageBitmap(file),canvas=document.createElement('canvas');canvas.width=canvas.height=256;
  try{const size=Math.min(bitmap.width,bitmap.height);canvas.getContext('2d').drawImage(bitmap,(bitmap.width-size)/2,(bitmap.height-size)/2,size,size,0,0,256,256);}finally{bitmap.close();}
  const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',.85));if(!blob)throw Error('Não foi possível preparar a imagem.');
  const path=repo.identity.id+'/avatar.webp';
  await unwrap(client().storage.from('profile-photos').upload(path,blob,{upsert:true,contentType:'image/webp',cacheControl:'0'}));
  const signed=await unwrap(client().storage.from('profile-photos').createSignedUrl(path,3600));
  if(!signed?.signedUrl)throw Error('Não foi possível confirmar a foto. Tente salvar novamente.');
  const url=new URL(signed.signedUrl);url.searchParams.set('v',crypto.randomUUID());
  return {avatar_path:path,avatar_url:url.href};
 };
}
