import {client,unwrap} from './supabase-client.js';
export async function signedCompanyLogos(workspaces){
 const paths=[...new Set(workspaces.map(w=>w.company?.logo_path).filter(Boolean))];if(!paths.length)return;
 const {data,error}=await client().storage.from('company-logos').createSignedUrls(paths,3600);if(error)return;
 const urls=new Map(data.map(p=>[p.path,p.signedUrl]));workspaces.forEach(w=>{if(w.company?.logo_path)w.company.logo_url=urls.get(w.company.logo_path)||'';});
}
export function setupCompanyAssets(repo,ui){window.WorkshUploadCompanyLogo=async file=>{
 if(repo.role(ui.current().workspace)!=='owner')throw Error('Somente o dono altera a logo da empresa.');
 if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>10485760)throw Error('Use JPG, PNG ou WebP de até 10 MB.');
 const image=await createImageBitmap(file),canvas=document.createElement('canvas');canvas.width=512;canvas.height=256;
 const scale=Math.min(512/image.width,256/image.height),w=image.width*scale,h=image.height*scale;canvas.getContext('2d').drawImage(image,(512-w)/2,(256-h)/2,w,h);image.close();
 const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',.88));if(!blob)throw Error('Imagem inválida.');
 const path=ui.current().workspace.id+'/logo.webp';
 await unwrap(client().storage.from('company-logos').upload(path,blob,{contentType:'image/webp',upsert:true,cacheControl:'0'}));
 const item={company:{logo_path:path}};await signedCompanyLogos([item]);return item.company;
};}
