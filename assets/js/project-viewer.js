import {projectCSS,renderProject} from './project-render.js?v=20261023.15';
const style=document.createElement('style');style.textContent=projectCSS;document.head.append(style);
const status=document.getElementById('projectStatus'),content=document.getElementById('sharedProject'),token=location.hash.slice(1);
let running=false,stopped=false;
const cfg=window.WORKSH_CONFIG,connection=cfg?.enabled&&window.supabase?window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_ANON_KEY,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}}):null;
async function refresh(){if(running||stopped||document.hidden)return;running=true;try{
 if(!connection||!/^[a-f0-9]{64}$/.test(token))throw Error('Link inválido ou indisponível.');
 const {data,error}=await connection.rpc('read_shared_project',{token});if(error)throw Error(error.code==='42501'?'Link inválido, expirado ou revogado.':'Não foi possível atualizar. Tente novamente.');
 content.innerHTML=renderProject(data,data.view);status.textContent='Acompanhamento em modo leitura. Atualizado em '+new Date().toLocaleTimeString('pt-BR');
 }catch(e){status.textContent=e.message;content.innerHTML='';document.getElementById('autoRefresh').checked=false;}finally{running=false;}}
document.getElementById('refreshProject').onclick=refresh;
setInterval(()=>{if(document.getElementById('autoRefresh').checked)refresh();},60000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});
window.addEventListener('pagehide',()=>stopped=true);
refresh();
