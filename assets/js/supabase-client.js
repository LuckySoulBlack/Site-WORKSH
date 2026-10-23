let instance;
export function client() {
 if(!instance){const c=window.WORKSH_CONFIG;if(!c?.enabled||!window.supabase?.createClient)throw Error('Conexão indisponível. Recarregue a página.');instance=window.supabase.createClient(c.SUPABASE_URL,c.SUPABASE_ANON_KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,flowType:'pkce',storageKey:'worksh.auth.v1'}});}
 return instance;
}
export async function unwrap(request){const {data,error}=await request;if(error)throw Error(error.message||'Não foi possível concluir a operação.');return data;}
export async function call(name,args={}){return unwrap(client().rpc(name,args));}
export async function invoke(name,body={}){const {data,error}=await client().functions.invoke(name,{body});if(error){if(error.context instanceof Response){const payload=await error.context.json().catch(()=>null);throw Error(payload?.error||'Serviço indisponível.');}throw Error('Serviço indisponível.');}return data;}
export async function user(){const {data,error}=await client().auth.getUser();if(error||!data.user)throw Error('Entre na sua conta para continuar.');return data.user;}
