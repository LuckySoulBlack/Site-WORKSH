import {client,call,user} from './supabase-client.js';
export async function login(email,password){const {error}=await client().auth.signInWithPassword({email,password});if(error)throw Error('E-mail ou senha inválidos.');const state=await call('account_status');if(state.is_blocked){await client().auth.signOut();throw Error('Seu acesso está bloqueado. Procure o administrador.');}return state;}
export async function logout(){await client().auth.signOut();location.assign('index.html');}
export async function session(){const identity=await user();const status=await call('account_status');return {user:identity,...status};}
export async function signup(email,password,name){const {error}=await client().auth.signUp({email,password,options:{emailRedirectTo:new URL('workspace.html',location.href).toString(),data:{full_name:name}}});if(error)throw Error(error.message);return {message:'Confira seu e-mail para confirmar o cadastro e depois entre na sua conta.'};}
