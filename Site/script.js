/* WORKSH — configurações de publicação.
   Preencha WORKSPACE_URL com o endereço HTTPS do aplicativo quando estiver ativo.
   Exemplo: const WORKSPACE_URL = 'https://app.worksh.com.br';
   Até lá, o modal informa que o ambiente está em preparação.
*/
const WORKSPACE_URL = '';
const CONTACT_EMAIL = '';

const modal = document.getElementById('workspaceModal');
const closeButton = document.getElementById('closeModal');
const workspaceLink = document.getElementById('workspaceLink');
const pending = document.getElementById('workspacePending');
const menuButton = document.getElementById('menuToggle');
const mobileNav = document.getElementById('mobileNav');
let previousFocus = null;

function configuredWorkspaceUrl() {
  try {
    if (!WORKSPACE_URL.trim()) return null;
    const url = new URL(WORKSPACE_URL);
    return url.protocol === 'https:' || (url.protocol === 'http:' && url.hostname === 'localhost') ? url.href : null;
  } catch { return null; }
}
function openWorkspace() {
  previousFocus = document.activeElement;
  const url = configuredWorkspaceUrl();
  workspaceLink.hidden = !url;
  pending.hidden = !!url;
  if (url) workspaceLink.href = url;
  modal.hidden = false;
  document.body.classList.add('modal-open');
  closeButton.focus();
}
function closeWorkspace() {
  modal.hidden = true;
  document.body.classList.remove('modal-open');
  previousFocus?.focus();
}
document.querySelectorAll('[data-open-workspace]').forEach(button => button.addEventListener('click', openWorkspace));
closeButton.addEventListener('click', closeWorkspace);
modal.addEventListener('click', event => { if (event.target === modal) closeWorkspace(); });
document.addEventListener('keydown', event => {
  if (modal.hidden) return;
  if (event.key === 'Escape') closeWorkspace();
  if (event.key === 'Tab') {
    const focusable = [...modal.querySelectorAll('button:not([disabled]), a:not([hidden])')].filter(el => !el.hidden);
    const first = focusable[0], last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  }
});
function closeMenu() { mobileNav.hidden = true; menuButton.setAttribute('aria-expanded','false'); menuButton.setAttribute('aria-label','Abrir menu'); }
menuButton.addEventListener('click', () => { const open = mobileNav.hidden; mobileNav.hidden = !open; menuButton.setAttribute('aria-expanded',String(open)); menuButton.setAttribute('aria-label',open?'Fechar menu':'Abrir menu'); });
mobileNav.querySelectorAll('a,button').forEach(el => el.addEventListener('click',closeMenu));
window.addEventListener('resize', () => { if (window.innerWidth > 800) closeMenu(); });
document.getElementById('year').textContent = new Date().getFullYear();
const reveals = document.querySelectorAll('.reveal');
if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => entries.forEach(entry => { if (entry.isIntersecting) { entry.target.classList.add('visible'); observer.unobserve(entry.target); } }),{threshold:.08,rootMargin:'0px 0px -20px 0px'});
  reveals.forEach(el=>observer.observe(el));
} else reveals.forEach(el=>el.classList.add('visible'));
const emailLink = document.querySelector('[data-placeholder-email]');
if (CONTACT_EMAIL.trim()) emailLink.href = 'mailto:' + encodeURIComponent(CONTACT_EMAIL.trim()) + '?subject=' + encodeURIComponent('Quero conhecer a WORKSH');
else { emailLink.href = '#'; emailLink.addEventListener('click',e=>{ e.preventDefault(); openWorkspace(); }); emailLink.textContent='Conheça o ambiente ↗'; }
