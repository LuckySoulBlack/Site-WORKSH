export const canDelete = role => role==='owner';
export const canView = (role,member) => role==='owner'||Boolean(member);
export const canEdit = (role,member) => role==='owner'||Boolean(member?.can_edit);
