# WORKSH — Google Drive obrigatório no cadastro

Data: 23/10/2026. Implementação local preparada; ainda não aplicada no Supabase nem publicada no GitHub.

## Fluxo implementado
Após trocar a senha inicial, Admin e Usuário conectam a própria conta Google antes de criar workspaces. Convidado não precisa conectar Drive e continua restrito aos painéis autorizados. Contas existentes conservam a visualização dos ambientes e recebem um aviso de conexão pendente; criar novos ambientes exige a conexão no servidor.

Uma autorização por proprietário atende todos os seus workspaces. A estrutura é WORKSH → workspace → quadro → arquivos. O Gmail pode ser diferente do e-mail de login na plataforma. Uma conexão já vinculada exige reconectar a mesma identidade Google para preservar os arquivos.

## Backend preparado
Migration pendente: supabase/migrations/20261023220710_account_drive_onboarding.sql.

- Conexão privada por usuário, com segredo no Vault, identidade Google, pasta principal e estados pending/connected/reconnect_required.
- RLS e negação de acesso direto para clientes em todas as novas tabelas; índices de chaves estrangeiras e auditoria privada sem tokens.
- Trigger impede criar workspace sem conexão ativa e vincula o mesmo segredo do proprietário a todos os novos ambientes.
- State OAuth válido por 10 minutos, de uso único, independente de um workspace já existir.
- Callback confirma identidade/e-mail Google, escopo concedido e acesso às pastas antigas antes de concluir o vínculo.
- Cancelamento, expiração e falta de permissões retornam mensagens sem tokens no endereço de retorno da aplicação.
- Invalid grant na renovação marca necessidade de reconexão, sem apagar tabelas ou anexos.
- Criação idempotente de pastas por workspace e quadro, reaproveitando IDs em novas tentativas; upload do convidado resolve a conexão do proprietário pelo banco.
- Leituras de arquivos usam a conexão do proprietário; o cliente não escolhe qual segredo será usado.
- Endereços e segredos reais não foram gravados no código.

## Validação concluída
Teste local em PostgreSQL/PGlite: exigência de conexão para criar ambiente, exceção para convidado, OAuth sem workspace inicial e proteção contra reutilização do state, compartilhamento da mesma conexão entre dois ambientes, bloqueio após revogação sem esconder ambientes existentes, vínculo com a mesma conta Google e pastas idempotentes por quadro. Vault e fila foram simulados no teste local; não houve autorização nem upload real para o Google.

Compilação Deno das funções OAuth, workers, acesso a arquivos e administração aprovada. Sintaxe JS e teste de preservação/importação de dados locais aprovados. A tela foi renderizada em uma prévia isolada com identidade fictícia, não com uma autorização real de Drive. Nenhuma conta ou dado de produção foi alterado.

## Google Cloud
Projeto WORKSH criado e confirmado: linear-arcadia-512522-a7.
Google Drive API ativada e status Ativado confirmado no painel.
O usuário concluiu a identificação e a concordância da configuração OAuth. Cliente Web WORKSH - Google Drive preparado para criação pelo usuário:
- Origem: https://luckysoulblack.github.io
- Retorno: https://zazkecvrjmtbvmylxgij.supabase.co/functions/v1/google-oauth-callback
- Escopos necessários em Acesso a dados: openid, e-mail Google e https://www.googleapis.com/auth/drive.file.
- Cliente, segredo, usuários de teste e revisão de publicação ainda precisam ser confirmados; nenhuma credencial foi capturada pela IA.

## Ativação restante — ordem
1. Usuário conclui Criar no Google e guarda o segredo fora do repositório. Declarar os escopos e incluir a conta escolhida em Usuários de teste enquanto o aplicativo estiver em Testing.
2. Recuperar a autenticação do Supabase. O MCP atual falha ao renovar OAuth; o painel ainda estava no login na última conferência.
3. Configurar GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI e APP_URL no ambiente protegido das Edge Functions. GOOGLE_REDIRECT_URI deve ser o retorno acima; APP_URL deve ser https://luckysoulblack.github.io/Site-WORKSH/.
4. Aplicar a migration por ferramenta de migration autenticada, sem resetar banco ou importar dados locais. Registrar a versão real retornada em docs/migrations-aplicadas.json; ela não foi marcada como aplicada nesta entrega.
5. Fazer deploy de TODAS as Edge Functions que importam _shared/core.ts, incluindo OAuth, workers, file-access, change-password, invite-member e admin-users; o helper de Drive mudou.
6. Revisar e habilitar worksh_scheduler_enabled no Vault após os provedores necessários estarem configurados. A criação de pastas e o envio de arquivos dependem do processamento da fila; não basta somente o consentimento OAuth.
7. Validar RLS/advisors e suites transacionais com as novas fixtures de Drive. Publicar frontend somente depois do backend compatível.
8. Testar cadastro real: trocar senha, autorizar conta Google, criar dois workspaces e um quadro, enviar um arquivo pequeno, confirmar a pasta no Drive correto, testar upload por convidado e confirmar que ele não cria workspace nem exclui registros.

## Limites e preservação
O novo fluxo não está ativo no site público enquanto a migration e as funções não forem implantadas. Nenhum reset, exclusão ou importação de localStorage foi executado. Textos, links, tabelas e histórico continuam no Supabase; arquivos anexados ficam no Drive do proprietário. A ligação automática GitHub↔Supabase também permanece pendente da autenticação do painel.
