import { createClient } from 'npm:@supabase/supabase-js@2.118.0';

export const env = (name: string) => Deno.env.get(name) || '';
export const admin = () => createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false, autoRefreshToken: false } });
export type DB = ReturnType<typeof admin>;
export class HttpError extends Error { constructor(public status: number, message: string) { super(message); } }
export function requireEnv(...names: string[]) { if (names.some(n => !env(n))) throw new HttpError(503, 'Integração ainda não configurada.'); }
export async function rpc(db: DB, name: string, args: Record<string, unknown> = {}) {
 const {data,error}=await db.rpc(name,args); if(error) throw new HttpError(error.code==='42501'?403:400,'Operação não autorizada ou dados inválidos.'); return data;
}
export async function actor(req: Request) {
 const token=req.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');
 if(!token) throw new HttpError(401,'Entre na sua conta.');
 const db=admin(); const {data,error}=await db.auth.getUser(token);
 if(error || !data.user) throw new HttpError(401,'Sessão inválida.');
 const userClient=createClient(env('SUPABASE_URL'),env('SUPABASE_ANON_KEY'),{global:{headers:{Authorization:`Bearer ${token}`}},auth:{persistSession:false}});
 return {db,user:data.user,client:userClient};
}
export async function body(req: Request) {
 if(req.method!=='POST') throw new HttpError(405,'Método inválido.');
 const raw=await req.text(); if(raw.length>16384) throw new HttpError(413,'Solicitação muito grande.');
 try{return JSON.parse(raw);}catch{throw new HttpError(400,'JSON inválido.');}
}
export function handler(fn:(req:Request)=>Promise<Response|unknown>) {
 return async(req:Request)=>{
 const origin=req.headers.get('Origin');
 const allowed=(env('ALLOWED_ORIGINS')||'https://luckysoulblack.github.io,http://127.0.0.1:8765,http://localhost:8765').split(',').map(x=>x.trim());
 const headers=new Headers({'Vary':'Origin','Cache-Control':'no-store','Referrer-Policy':'no-referrer','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,GET,OPTIONS'});
 if(origin && !allowed.includes(origin))return new Response('Origem não autorizada',{status:403});
 if(origin)headers.set('Access-Control-Allow-Origin',origin);
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 try {
 const result=await fn(req);
 if(result instanceof Response){for(const [k,v] of headers)result.headers.set(k,v);return result;}
 headers.set('Content-Type','application/json');return new Response(JSON.stringify(result),{headers});
 }catch(e){headers.set('Content-Type','application/json');return new Response(JSON.stringify({ok:false,error:e instanceof HttpError?e.message:'Falha temporária. Tente novamente.'}),{status:e instanceof HttpError?e.status:503,headers});}
 };
}
export async function owner(db:DB,user:string,workspace?:string,board?:string) {
 if(!await rpc(db,'backend_access',{actor:user,workspace:workspace||null,board:board||null,owner_only:true}))throw new HttpError(403,'Somente o proprietário pode executar esta ação.');
}
export async function worker(req:Request,db:DB) {
 const key=req.headers.get('X-Worker-Secret');if(!key)throw new HttpError(401,'Credencial do worker ausente.');
 if(!await rpc(db,'backend_worker_authorized',{provided:key}))throw new HttpError(403,'Credencial do worker inválida.');
}
export async function sha(text:string) {return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text)))).map(x=>x.toString(16).padStart(2,'0')).join('');}
export const random = () => Array.from(crypto.getRandomValues(new Uint8Array(32))).map(x=>x.toString(16).padStart(2,'0')).join('');
export async function external(url:string,options:RequestInit={}) {
 const res=await fetch(url,{...options,signal:AbortSignal.timeout(40000)});
 if(!res.ok){await res.body?.cancel();throw new Error('External service failed');}return res;
}
export async function googleToken(db:DB,workspace:Record<string,unknown>) {
 requireEnv('GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET');
 const secret=await rpc(db,'backend_secret',{secret_id:workspace.drive_secret_id});
 if(!secret)throw new HttpError(409,'O proprietário precisa conectar o Google Drive.');
 const response=await external('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({client_id:env('GOOGLE_CLIENT_ID'),client_secret:env('GOOGLE_CLIENT_SECRET'),refresh_token:secret,grant_type:'refresh_token'})});
 return (await response.json()).access_token as string;
}
