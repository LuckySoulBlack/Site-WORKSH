# Histórico com identificação do autor

A tela destaca nome, iniciais, data/hora e ação em português. Atualizações mostram campos conhecidos antes/depois. Dados completos e identificadores ficam recolhidos em Detalhes do registro. A paginação de 50 registros e a política RLS existente foram preservadas.

## Compatibilidade e implantação

Frontend funciona com a estrutura atual: consulta perfis autorizados pelo RPC shared_profiles uma vez por página quando necessário, sem consultas globais de usuários. Nome do próprio perfil e participantes carregados são alternativas. Se a identidade não puder ser resolvida, mostra Participante não identificado; não inventa autoria.

Aplicar migration 20261023223613_audit_author_identity.sql após as migrations anteriores quando o acesso Supabase estiver reautenticado. Ela adiciona snapshot actor_name preenchido pelo servidor; não altera permissões de leitura e não concede escrita de auditoria ao navegador. Nomes de eventos antigos são preenchidos a partir do perfil atual, sem alegar reconstrução do nome original. Eventos novos preservam o nome mesmo após renomeação e perda da referência ao usuário. A migration não corrige atribuições incorretas já existentes no actor_id original.

## Validação

- scripts/history-view-check.mjs: identificação, fallback, autor removido, tradução e escape HTML.
- scripts/history-author-check.sql: snapshot, renomeação, referência removida e ausência de permissão de falsificar histórico.
- Teste SQL executado em PostgreSQL local PGlite com schema base e Auth/Vault simulados; não executado em produção.
- Prévia visual usa dados fictícios. Nenhum histórico real foi alterado.

## Estado

Ajuste local, sem push. Migration preparada, não aplicada no projeto remoto. A última tentativa de acesso remoto falhou na renovação OAuth do MCP; requer reconexão. Ajustes anteriores do Google Drive foram preservados.
