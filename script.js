/* WORKSH — configurações de publicação.
   Preencha WORKSPACE_URL com o endereço HTTPS do aplicativo quando estiver ativo.
   Exemplo: const WORKSPACE_URL = 'https://app.worksh.com.br';
   Até lá, o modal informa que o ambiente está em preparação.
*/
const WORKSPACE_URL = '';
const CONTACT_EMAIL = '';

const modal = document.getElementById('workspaceModal');
const closeButton = document.getElementById('closeModal');
const loginForm = document.getElementById('workspaceLogin');
const loginPassword = document.getElementById('loginPassword');
const loginStatus = document.getElementById('loginStatus');
const togglePassword = document.getElementById('togglePassword');
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
  loginStatus.hidden = true;
  modal.hidden = false;
  document.body.classList.add('modal-open');
  document.getElementById('loginEmail').focus();
}
function closeWorkspace() {
  modal.hidden = true;
  loginForm.reset();
  loginPassword.type = 'password';
  togglePassword.textContent = 'Mostrar';
  togglePassword.setAttribute('aria-label', 'Mostrar senha');
  togglePassword.setAttribute('aria-pressed', 'false');
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
    const focusable = [...modal.querySelectorAll('button:not([disabled]), input:not([disabled]), a[href]')].filter(el => !el.hidden && el.getClientRects().length);
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

// Interactive product preview; all data below is illustrative.
const previewPanel = document.querySelector('.hero-visual');
const scene = document.createElement('div');
scene.className = 'workspace-scene';
while (previewPanel.firstChild) scene.append(previewPanel.firstChild);
previewPanel.append(scene);
const motionPreference=matchMedia('(prefers-reduced-motion: reduce)');
const finePointer=matchMedia('(hover: hover) and (pointer: fine)');
let targetX=4, targetY=-7, currentX=4, currentY=-7;
let previewFrame=0;
let previewOnScreen=false;
function animatePreview(){
 currentX+=(targetX-currentX)*.065;
 currentY+=(targetY-currentY)*.065;
 scene.style.setProperty('--rx',currentX+'deg');
 scene.style.setProperty('--ry',currentY+'deg');
 if(Math.abs(targetX-currentX)+Math.abs(targetY-currentY)>.01){previewFrame=requestAnimationFrame(animatePreview);}
 else previewFrame=0;
}
function updatePreviewTarget(x,y){
 targetX=x;targetY=y;
 if(!previewFrame)previewFrame=requestAnimationFrame(animatePreview);
}
function syncPreviewMotion(){
 previewPanel.classList.toggle('motion-paused',motionPreference.matches);
 if(motionPreference.matches){cancelAnimationFrame(previewFrame);previewFrame=0;scene.style.removeProperty('--rx');scene.style.removeProperty('--ry');}
}
motionPreference.addEventListener('change',syncPreviewMotion);
previewPanel.addEventListener('pointermove',event=>{
 if(motionPreference.matches||!finePointer.matches||event.target.closest('button, .mini-board'))return;
 const rect=previewPanel.getBoundingClientRect();
 const x=Math.max(0,Math.min(1,(event.clientX-rect.left)/rect.width));
 const y=Math.max(0,Math.min(1,(event.clientY-rect.top)/rect.height));
 updatePreviewTarget(4-(y-.5)*10,-7+(x-.5)*14);
});
previewPanel.addEventListener('pointerleave',()=>{if(!motionPreference.matches)updatePreviewTarget(4,-7);});
const previewVisibility=new IntersectionObserver(entries=>{
 previewOnScreen=entries[0].isIntersecting;
 previewPanel.classList.toggle('preview-offscreen',!previewOnScreen);
},{threshold:0});
previewVisibility.observe(previewPanel);
syncPreviewMotion();

/* WORKSH V3 — interações de descoberta */
(() => {
  const stage = document.getElementById('viewStage');
  const buttons = Array.from(document.querySelectorAll('[data-view]'));
  const views = {
    kanban: `<div class="v3-board"><div class="v3-lane"><strong>Planejado</strong><div class="v3-task">Mapear etapas</div><div class="v3-task">Validar escopo</div></div><div class="v3-lane"><strong>Em andamento</strong><div class="v3-task">Interface web</div></div><div class="v3-lane"><strong>Entregue</strong><div class="v3-task">Identidade</div></div></div>`,
    table: `<table class="v3-table"><thead><tr><th>Tarefa</th><th>Status</th><th>Equipe</th></tr></thead><tbody><tr><td>Interface web</td><td>Andamento</td><td>Produto</td></tr><tr><td>Identidade</td><td>Concluído</td><td>Design</td></tr><tr><td>Validação</td><td>Planejado</td><td>Operações</td></tr></tbody></table>`,
    timeline: `<div class="v3-timeline"><div>Produto<i style="width:84%"></i></div><div>Design<i style="width:100%"></i></div><div>Testes<i style="width:58%"></i></div></div>`
  };
  function selectView(view) {
    if (!stage || !views[view]) return;
    stage.innerHTML = views[view];
    stage.style.animation = 'none';
    void stage.offsetWidth;
    stage.style.animation = '';
    buttons.forEach(button => {
      const active = button.dataset.view === view;
      button.classList.toggle('active', active);
      button.setAttribute('aria-pressed', String(active));
    });
  }
  buttons.forEach(button => button.addEventListener('click', () => selectView(button.dataset.view)));
  selectView('kanban');

  const modules=[
    {name:"Workspaces",heading:"Cada área tem seu próprio espaço.",desc:"Equipes com seus projetos, membros e permissões.",color:"#3B82F6",kind:"workspaces"},
    {name:"Boards",heading:"Organize do seu jeito.",desc:"Campos, responsáveis, status e tarefas em quadros configuráveis.",color:"#8B5CF6",kind:"boards"},
    {name:"Visualizações",heading:"Um projeto. Múltiplas perspectivas.",desc:"Veja a mesma informação no Kanban, em tabelas ou cronogramas.",color:"#22C55E",kind:"views"},
    {name:"Data Studio",heading:"Dados que fazem sentido.",desc:"Importação com layout definido e cálculos automáticos.",color:"#F59E0B",kind:"data"},
    {name:"Reports",heading:"Resultados claros.",desc:"Indicadores, relatórios e exportações em vários formatos.",color:"#22C55E",kind:"reports"},
    {name:"Connect",heading:"Tudo se conecta.",desc:"APIs documentadas, webhooks e autenticação apropriada.",color:"#8B5CF6",kind:"connect"}
  ];
  const templates={
    workspaces:'<div class="ws-demo-grid"><span>Produto</span><span>Operações</span><span>Design</span><span>Tecnologia</span></div>',
    boards:'<div class="ws-demo-board"><div><b>Planejado</b><em>Pesquisa</em><em>Escopo</em></div><div><b>Em andamento</b><em>Interface</em></div><div><b>Concluído</b><em>Marca</em></div></div>',
    views:'<div class="ws-demo-chart"><small>Kanban　/　Tabela　/　Timeline</small><p>Design <i style="width:77%"></i></p><p>Desenvolvimento <i style="width:59%"></i></p><p>Testes <i style="width:34%"></i></p></div>',
    data:'<div class="ws-demo-data"><b>Campo</b><b>Valor</b><span>Quantidade</span><span>120</span><span>Preço</span><span>R$ 85</span><strong>∑ Total = 10.200</strong></div>',
    reports:'<div class="ws-demo-reports"><span style="height:38%"></span><span style="height:66%"></span><span style="height:50%"></span><span style="height:88%"></span><span style="height:73%"></span></div>',
    connect:'<div class="ws-demo-connect"><span>REST API</span><span>OAuth</span><img src="assets/logo.svg" alt=""><span>Webhooks</span><span>GitHub</span></div>'
  };
  const panel=document.getElementById("modulePanel");
  const count=document.getElementById("moduleCount");
  const dots=document.getElementById("moduleDots");
  const play=document.getElementById("modulePlay");
  const host=document.querySelector(".module-shell");
  if(!panel||!count||!dots||!host)return;
  let index=0,timer=0,paused=false;
  const reduced=window.matchMedia("(prefers-reduced-motion: reduce)");
  const dotButtons=modules.map((m,i)=>{
    const button=document.createElement("button");
    button.type="button";
    button.setAttribute("aria-label","Ver "+m.name);
    button.addEventListener("click",()=>{render(i);restart();});
    dots.appendChild(button);
    return button;
  });
  function render(next){
    index=(next+modules.length)%modules.length;
    const m=modules[index];
    host.style.setProperty("--module-accent",m.color);
    panel.innerHTML='<div class="module-copy"><span class="number">MÓDULO '+String(index+1).padStart(2,"0")+' · '+m.name.toUpperCase()+'</span><h3>'+m.heading+'</h3><p>'+m.desc+'</p><span class="demo-note">Demonstração conceitual</span></div><div class="module-shot"><div class="ws-demo-shell"><div class="ws-demo-header">WORKSH / '+m.name+'</div>'+templates[m.kind]+'</div></div>';
    count.textContent=String(index+1).padStart(2,"0")+" / 06";
    dotButtons.forEach((b,i)=>{b.classList.toggle("active",i===index);b.setAttribute("aria-pressed",String(i===index));});
  }
  function stop(){window.clearInterval(timer);timer=0;}
  function restart(){
    stop();
    if(paused||reduced.matches||document.hidden)return;
    timer=window.setInterval(()=>render(index+1),7000);
  }
  document.getElementById("modPrev")?.addEventListener("click",()=>{render(index-1);restart();});
  document.getElementById("modNext")?.addEventListener("click",()=>{render(index+1);restart();});
  play?.addEventListener("click",()=>{paused=!paused;play.textContent=paused?"Reproduzir rotação":"Pausar rotação";play.setAttribute("aria-pressed",String(paused));restart();});
  host.addEventListener("mouseenter",stop);
  host.addEventListener("mouseleave",restart);
  host.addEventListener("focusin",stop);
  host.addEventListener("focusout",e=>{if(!host.contains(e.relatedTarget))restart();});
  document.addEventListener("visibilitychange",restart);
  if("IntersectionObserver" in window)new IntersectionObserver(es=>{if(es[0].isIntersecting)restart();else stop();},{threshold:.15}).observe(host);
  render(0);restart();
})();


/* WORKSH V3.2 — carrossel de valores */
(() => {
  const slides = Array.from(document.querySelectorAll('[data-value-slide]'));
  const dotsWrap = document.getElementById('valueDots');
  if (!slides.length || !dotsWrap) return;
  let current = 0;
  let timer = null;
  const dots = slides.map((_, index) => {
    const dot = document.createElement('button');
    dot.type = 'button';
    dot.setAttribute('aria-label', `Ver valor ${index + 1}`);
    dot.addEventListener('click', () => { show(index); reset(); });
    dotsWrap.appendChild(dot);
    return dot;
  });
  function render() {
    slides.forEach((slide, index) => {
      slide.classList.remove('is-active', 'is-prev', 'is-next', 'is-hidden');
      if (index === current) slide.classList.add('is-active');
      else if (index === (current - 1 + slides.length) % slides.length) slide.classList.add('is-prev');
      else if (index === (current + 1) % slides.length) slide.classList.add('is-next');
      else slide.classList.add('is-hidden');
    });
    dots.forEach((dot, index) => {
      dot.classList.toggle('active', index === current);
      dot.setAttribute('aria-pressed', String(index === current));
    });
  }
  function show(index) {
    current = (index + slides.length) % slides.length;
    render();
  }
  function next(){ show(current + 1); }
  function prev(){ show(current - 1); }
  function autoplay(){
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    timer = window.setInterval(next, 3200);
  }
  function reset(){ if (timer) clearInterval(timer); autoplay(); }
  document.querySelector('.value-nav.next')?.addEventListener('click', () => { next(); reset(); });
  document.querySelector('.value-nav.prev')?.addEventListener('click', () => { prev(); reset(); });
  const host = document.querySelector('.values-carousel');
  host?.addEventListener('mouseenter', () => timer && clearInterval(timer));
  host?.addEventListener('mouseleave', autoplay);
  render();
  autoplay();
})();

/* WORKSH V4 — demos de interação, sem servidor e sem dados reais */
(() => {
 const chips=[...document.querySelectorAll('[data-ws]')];
 const insight=document.getElementById('workspaceInsight');
 const labels={produto:'Produto — 8 participantes · 3 quadros',operacoes:'Operações — 14 participantes · 6 quadros',marketing:'Marketing — 5 participantes · 2 quadros'};
 chips.forEach(b=>b.addEventListener('click',()=>{chips.forEach(x=>x.classList.toggle('active',x===b));if(insight)insight.textContent=labels[b.dataset.ws];}));
 const add=document.getElementById('v4AddField'), custom=document.getElementById('v4CustomField');
 add?.addEventListener('click',()=>{custom.hidden=!custom.hidden;add.textContent=custom.hidden?'+ Adicionar campo':'− Remover campo';});
 const board=document.getElementById('v4DragBoard'),task=board?.querySelector('.v4-draggable');
 const moveTask=(target)=>{const lane=board.querySelector(`[data-lane="${target}"]`);if(!lane)return;lane.appendChild(task);board.querySelectorAll('.v4-empty').forEach(n=>n.hidden=n.parentElement.contains(task));};
 task?.addEventListener('click',()=>moveTask(task.closest('[data-lane]').dataset.lane==='todo'?'done':'todo'));
 task?.addEventListener('dragstart',e=>{e.dataTransfer.setData('text/plain','task');e.dataTransfer.effectAllowed='move';});
 board?.querySelectorAll('[data-lane]').forEach(lane=>{lane.addEventListener('dragover',e=>{e.preventDefault();lane.classList.add('drop-target')});lane.addEventListener('dragleave',()=>lane.classList.remove('drop-target'));lane.addEventListener('drop',e=>{e.preventDefault();lane.classList.remove('drop-target');moveTask(lane.dataset.lane)})});
})();

// Interface ready for authentication integration; no credentials are sent or stored.
togglePassword.addEventListener('click', () => {
 const visible = loginPassword.type === 'password';
 loginPassword.type = visible ? 'text' : 'password';
 togglePassword.textContent = visible ? 'Ocultar' : 'Mostrar';
 togglePassword.setAttribute('aria-label', visible ? 'Ocultar senha' : 'Mostrar senha');
 togglePassword.setAttribute('aria-pressed', String(visible));
});
loginForm.addEventListener('submit', event => {
 event.preventDefault();
 loginForm.reset();
 window.location.assign('workspace.html');
});