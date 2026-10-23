# Integração WORKSH / Supabase

Projeto: `zazkecvrjmtbvmylxgij`. O frontend continua em HTML/CSS/JS.

| Ponto existente | Integração | Comportamento |
|---|---|---|
| `index.html`, `workspace.html`, fim do head | `config.js`, SDK vendorizado, `assets/js/app.js` | Carregamento do cliente e autenticação; layout preservado |
| `script.js`, submit de `workspaceLogin` | `auth.js` | E-mail/senha reais; credenciais incorretas não abrem a conta |
| `workspace.js`, `persist` | `RemoteRepository.save` | Grava diferenças em lote transacional via apply_changes; conflito de versão reverte o lote |
| `workspace.js`, `render` e `WorkshUI` | Ponte de dados e callbacks | Reutiliza formulários, tabelas, Kanban, calendário e temas |
| Criação do primeiro ambiente | RPC `create_workspace` | Owner vem da sessão; vínculo owner é criado na mesma transação |
| Abertura do board | `loadBoard` | Leitura autorizada pelo banco; tarefas em páginas de 20 |
| Visão geral / indicadores | RPC invoker `workspace_counts` | Totais de todas as tarefas visíveis; não dependem da página carregada |
| Histórico do painel | `historico.js` | Cursor composto de data e ID; membro vê eventos em que é o autor |
| Convites | `convidar.js` → `invite-member` | Worker provisiona conta quando necessário; conta existente mantém senha |
| Troca obrigatória | `change-password.js` → Edge `change-password` | Atualiza Auth e somente então libera flag no banco |
| Arquivos | `upload.js` | Storage privado temporário → job → Drive do owner; cliente acompanha jobs |
| Download | `file-access` | Backend verifica RLS; token Google não sai do servidor |
| Botão Importar dados locais | `scripts/migrate-localstorage.js` | Prévia, confirmação e importação explícita; nenhuma remoção local |

## Dados locais

A chave original é `worksh.workspace.v1`. Ela nunca é gravada pelo modo conectado.
Sessões Auth usam `worksh.auth.v1`, independente do backup local. O convite fica
temporariamente em `sessionStorage` até sua aceitação e é removido da URL.

| Campo local | Destino |
|---|---|
| workspaces[].name / description / modules | workspaces |
| company | workspaces.company do proprietário |
| boards[] | boards, com FK workspace_id |
| groups[] | groups, com FK board_id |
| tasks[].group | tasks.group_id, com FK composta de board |
| tasks[].title / description / status / due / priority / checklist | tasks |
| tasks[].comments[].text | comments.content |
| people[] / tasks[].person | Permanecem no backup; pessoas locais não são identidades autenticadas |
| activity[] | Permanece no backup; não é importado como auditoria autenticada |

IDs de importação são UUIDs determinísticos específicos do owner. Repetições não
duplicam registros; importação não sobrescreve registros já existentes. Datas de
auditoria e autores históricos não são forjados a partir do backup local.
O seed gerado contém dados pessoais: revisar e manter fora do repositório público.

## Decisões de segurança que corrigem o prompt original

- `complete_password_change` é exclusiva do backend. Chamar uma RPC livre após
  `auth.updateUser` não provaria a troca e permitiria liberar a própria conta.
- O bloqueio global fica em `private.account_security`; campos por membership
  são atualizados pelo backend. Um convite novo não altera a senha de outra conta.
- Implementações privilegiadas ficam em `private`, com wrappers públicos invoker,
  search_path vazio, grants explícitos e verificação da identidade.
- Leitura de board depende do acesso, não de `can_edit`; leitura continua possível
  para um participante sem permissão de editar.
- Attachments não aceitam Drive IDs inventados pelo navegador. Worker cria os
  metadados; remoção de arquivo passa pelo backend e pela fila.
- OAuth precisa trocar o código imediatamente no callback. Criação da pasta e
  operações de arquivo são processadas na fila.
- Fila carrega IDs, nunca arquivo Base64, senha ou link. Dados de entrega sensíveis
  ficam temporariamente no Vault e são removidos após envio/expiração.
- Google recebe IDs reservados antes do upload. Repetição consulta o mesmo ID;
  leases e heartbeat evitam duplicidade entre workers concorrentes.
- O worker autentica a chave interna do Vault; callback usa state. Endpoints de
  usuário exigem JWT na plataforma e `auth.getUser` no handler.
- A publicação no GitHub Pages não precisa mudar de hospedagem.

## Paginação e uso

Tarefas: 20 por página, carregadas por board. Histórico: 50 por página. Metadados
iniciais são limitados a 100 workspaces/boards, grupos a 1000 por board e comentários
a 100 por leitura de board. As funções de paginação em `boards.js` permitem carregar
páginas seguintes; estas cotas de interface precisam ser ampliadas caso o uso atinja
esse volume. Totais dos indicadores são calculados no banco com RLS.

CSV exporta as tarefas atualmente carregadas/filtradas. Nenhum dado local é
automaticamente distribuído a convidados.
