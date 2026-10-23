import {invoke} from './supabase-client.js';
export async function changePassword(password){if(password.length<12||password.length>128)throw Error('Use de 12 a 128 caracteres.');await invoke('change-password',{password});}
