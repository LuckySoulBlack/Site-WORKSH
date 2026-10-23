# WORKSH — estado da entrega em 23/10/2026

Projeto Supabase: zazkecvrjmtbvmylxgij. Frontend HTML/CSS/JS preservado.

## Aplicado no Supabase

- 12 migrations, com arquivos locais alinhados às versões do histórico remoto.
- 14 tabelas públicas, todas com RLS, e private.account_security com RLS.
- Chaves estrangeiras e índices; nenhuma FK sem índice segundo o advisor final.
- 3 filas pgmq; bucket privado uploads-temp com limite de 5 MB.
- Cron de filas instalado e suspenso pelo flag protegido no Vault.
- Cron diário de limpeza de estados, segredos de entrega expirados e logs internos.
- 7 Edge Functions ativas: change-password, invite-member, queue-worker,
  drive-worker, google-oauth-start, google-oauth-callback e file-access.
- Segredo interno do worker gerado no Vault; nenhuma chave administrativa no frontend.

## Implementado no frontend local

- Login real e primeira troca de senha controlada pelo backend.
- Workspace com owner; boards e registros visíveis conforme RLS.
- Criação/edição de dados em uma RPC transacional; versão evita sobrescrever alteração concorrente.
- Perfil, empresa, tarefas, comentários, checklist, prioridades, prazos e links.
- Indicadores calculados no banco sob RLS e tarefas paginadas por board.
- Histórico com eventos antes/depois e identificação do autor.
- Convites, controles de leitura/edição e revogação de acesso por board.
- Upload temporário, acompanhamento de job, download autenticado e remoção pelo owner.
- Prévia e importação explícita do localStorage, UUIDs determinísticos e seed opcional.
- Temas claro/escuro e componentes existentes preservados.

## Verificado

| Teste | Resultado |
|---|---|
| Bootstrap schema+segurança em PostgreSQL local | 14 tabelas públicas, 14 com RLS |
| Owner / membro / externo / senha pendente / anônimo | PASS em banco real, com rollback |
| Board oculto / exclusão de membro / revogação | PASS |
| RPCs de fila e liberação da senha inacessíveis ao cliente | PASS |
| Lote transacional / conflito de versão / whitelist de campos | PASS |
| Job de upload repetido / lease exclusivo / heartbeat / finalização / ack | PASS, sem acessar Google |
| Auth real: dados bloqueados com senha pendente | PASS |
| Auth real: chamada direta não libera flag | PASS |
| Auth real: senha curta rejeitada / troca pelo backend / novo login | PASS |
| Interface: login, workspace, quadro, tarefa, checklist, comentário e status | PASS com conta descartável |
| Interface: histórico mostra criação e alteração do registro | PASS |
| Worker autenticado com fila vazia | HTTP 204 |
| Requisições sem autenticação | HTTP 401 |
| Chave inválida do worker e origem CORS não permitida | HTTP 403 |
| Preflight da origem local permitida | HTTP 204 |
| Importação: IDs, relacionamentos, escape SQL, não remoção local | PASS |
| TypeScript das 7 funções / sintaxe JS | PASS |

Fixtures SQL fizeram rollback. Conta, sessões e registros do teste de interface/API
foram removidos depois da validação; não existe senha padrão. Dados reais do navegador
não foram importados, apagados ou substituídos.

## Bloqueios reais para operação completa

Você informou que Resend e Google ainda não foram configurados. Código pronto e
publicado não significa integração externa validada: faltam domínio/remetente/API key
do Resend e cliente/consentimento OAuth Google. Entrega real de convites e upload real
ao Drive aguardam essas etapas. O scheduler de filas continua suspenso.

Também é necessário configurar Site URL/redirects do Auth e confirmar o provedor de
e-mail/SMTP para cadastro público e recuperação de acesso. Criar a primeira conta real
é uma ação do proprietário; credenciais não são geradas ou enviadas pelo chat.

A última consulta ao advisor de segurança retornou zero alertas. Durante a validação
com usuário de teste apareceu aviso de proteção contra senhas vazadas desativada.
Esse recurso é Pro ou superior, conforme
https://supabase.com/docs/guides/auth/password-security . O backend exige pelo menos
12 caracteres. Não foi feita mudança de plano nem habilitada essa proteção paga.

Índices sem uso são informativos em instalação nova; foram mantidos para FKs e RLS.
Filas mortas e integrações revogadas exigem inspeção operacional; os healthchecks
identificam esses estados sem expor credenciais. Não existe promessa de exatamente
uma execução externa sob qualquer falha: IDs estáveis e idempotência permitem reconciliar.

## Limites atuais da interface

Leitura inicial de metadados: 100 workspaces/boards; 1000 grupos e 100 comentários
por abertura de board. Tarefas e histórico têm paginação ativa. Os endpoints de
paginação são reutilizáveis; ampliar os controles desses metadados antes de ultrapassar
esses volumes. CSV considera a seleção carregada. Limites não ampliam permissões.

## Publicação e continuidade

Não houve push ao GitHub nem alteração da publicação GitHub Pages. A prévia local
está em http://127.0.0.1:8765/workspace.html . Revisar e configurar integrações antes
da publicação do frontend. Procedimento de ativação/rollback: deploy-supabase.md.

Checkpoint: todas as seis partes têm arquivos implementados. Banco e funções foram
implantados e as partes independentes de serviços externos foram testadas. Ativação
de e-mail/Drive e homologação com contas reais continuam pendentes das configurações.
