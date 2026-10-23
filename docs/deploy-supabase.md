# Entrega e ativação

## 1. Banco

As migrations já aplicadas neste projeto são registradas no Supabase. Os nomes locais
foram alinhados ao histórico real, disponível em `docs/migrations-aplicadas.json`.
Não reaplicar no projeto existente. Para outro banco vazio, executar os arquivos
em ordem de versão. Schema e RLS estão juntos na primeira migration. O agendador
inicia desativado para as filas; a limpeza interna de estados/segredos expirados
funciona diariamente.

Executar `scripts/rls-check.sql`: cria fixtures e faz rollback de toda a transação.
Executar `scripts/healthcheck.sql` para inventário, volume de filas, dead jobs e tamanho.

## 2. Auth e primeira conta

Dashboard → Authentication → URL Configuration:

- Site URL: `https://luckysoulblack.github.io/Site-WORKSH/`.
- Redirects: `https://luckysoulblack.github.io/Site-WORKSH/workspace.html` e
  `http://127.0.0.1:8765/workspace.html` durante os testes.
- Revisar limite de senha, confirmação de e-mail e limites de envio antes de liberar
  cadastro público. O serviço padrão de e-mail do Auth tem restrições; configurar
  SMTP próprio se forem necessários cadastros arbitrários com confirmação.

O owner cria sua conta pela tela inicial do workspace ou pelo dashboard Auth. A
primeira conexão pede nova senha antes de liberar dados. Nenhum usuário real foi
criado automaticamente e não existe senha padrão. A conta descartável de QA é removida
após a verificação.

## 3. Edge Functions

Publicadas: change-password, invite-member, queue-worker, drive-worker,
google-oauth-start, google-oauth-callback, file-access.

Reimplantar pelos arquivos locais e configuração em supabase/config.toml. As funções
de usuário exigem JWT; os workers validam X-Worker-Secret; OAuth callback valida state.
O SDK está fixado em 2.118.0 e `deno.lock` registra as dependências.
Free aplica os limites de runtime da plataforma; campos fictícios de memória/timeout
não foram adicionados ao TOML. Requisições externas têm timeout e o lote para de
iniciar trabalhos após 100 segundos; visibilidade é 60 segundos com renovação.

## 4. Serviços externos — pendentes

Você informou que Resend e Google ainda não foram configurados. No dashboard:

- Resend: verificar domínio e remetente; criar API key com permissão de envio.
- Google Cloud: habilitar Drive API; criar OAuth Web; configurar consentimento.
- Redirect Google exato:
  `https://zazkecvrjmtbvmylxgij.supabase.co/functions/v1/google-oauth-callback`.
- Escopo: `https://www.googleapis.com/auth/drive.file`, acesso offline.
- Em OAuth Testing, cadastrar usuários de teste; revisar validade dos refresh tokens
  e publicação do consentimento antes de operação contínua.

Edge Functions → Secrets:

- `RESEND_API_KEY`
- `RESEND_FROM_EMAIL`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URI` com o callback acima
- `APP_URL=https://luckysoulblack.github.io/Site-WORKSH/`
- `ALLOWED_ORIGINS=https://luckysoulblack.github.io,http://127.0.0.1:8765,http://localhost:8765`

SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_SERVICE_ROLE_KEY são fornecidas pelo
ambiente Edge. Não colocá-las todas no config.js: somente URL e chave pública.
A chave interna do worker foi gerada no Vault; não precisa ser enviada pelo chat.

Após configurar e testar os serviços, no Vault editar `worksh_scheduler_enabled`
de `false` para `true`. Não ativar antes: o cron está preparado para chamar Edge
somente quando houver mensagens visíveis, mas integrações ainda precisam das credenciais.

## 5. Testes de ativação

- Criar workspace e board com conta do owner.
- Convidar e-mail de teste controlado; confirmar entrega real.
- Entrar com senha provisória; verificar bloqueio direto pela API até a troca.
- Aceitar convite; convidado vê apenas o board autorizado.
- Editar tarefa; verificar ator e alterações no histórico.
- Convidar usuário existente; sua senha não muda.
- Owner conecta Google; aguardar criação da pasta pelo worker.
- Upload permitido de até 5 MB chega ao Drive; repetir job não cria outro arquivo.
- Download via backend funciona; remover acesso impede novo download.
- Remoção de anexos vai para a lixeira do Drive e remove metadados apenas pelo backend.

## 6. Frontend e rollback

A prévia local usa Supabase. Nenhum push foi feito ao GitHub nesta entrega.
Antes de publicar, aprovar a prévia e concluir os testes reais das integrações.

- Frontend: `config.js → enabled: false` restaura o modo local preservado.
- Workers: Vault → `worksh_scheduler_enabled=false` suspende disparos de filas.
- Edge: reimplantar versão anterior; negar acesso mantém dados protegidos.
- Banco: preferir migration corretiva; não executar DROP em produção como rollback.
- Importação: arquivos e IDs determinísticos permitem identificar os registros;
  nenhuma remoção em massa é executada automaticamente.

## Observações operacionais

Não há fila acessível ao navegador. Auditoria é imutável para usuários. RLS permanece
habilitada inclusive nos objetos privados; anon não recebe acesso aos dados.

O pg_net foi reinstalado sob o namespace extensions, com a fila HTTP vazia e o agendador suspenso. Acesso a net permanece revogado para clientes. Índices sem uso são esperados em banco novo; não removê-los antes de uso representativo.

Retenção de auditoria não foi reduzida automaticamente. Acompanhar tamanho do banco.
Antes de uso intenso de anexos, validar a rotina diária de limpeza (até 100 temporários por execução, mais de 24 horas e sem job ativo) e os jobs
dead; remoção bem-sucedida apaga o temporário e o worker retoma limpeza após retries.

Durante a validação com usuário de teste, o advisor do Auth apontou proteção contra senhas vazadas desativada. A consulta final, após remover as fixtures, retornou zero alertas.
Esse recurso é disponibilizado pelo Supabase no plano Pro ou superior:
https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
O endpoint de troca do WORKSH exige pelo menos 12 caracteres; isso não substitui
uma consulta a senhas vazadas. Nenhum plano foi contratado ou alterado.
