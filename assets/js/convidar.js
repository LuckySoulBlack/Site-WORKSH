import {invoke,call} from './supabase-client.js';
export const invite=(board_id,email)=>invoke('invite-member',{board_id,email});
export const accept=token=>call('accept_invitation',{token});
export const grant=(board_id,user_id,can_edit=true)=>call('grant_board_access',{board_id,user_id,can_edit});
export const revoke=(board_id,user_id)=>call('revoke_board_access',{board_id,user_id});
