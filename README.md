# WORKSH — V4 consolidada para teste local

## Arquivos
- `index.html`: páginas e seções do site.
- `style.css`: todos os estilos, incluindo Plataforma, Como funciona, Connect e animações.
- `script.js`: todas as interações, navegação, demonstrações e carrosséis.
- `assets/logo.svg`: símbolo vetorial WORKSH.

Não há `v4.css` nem `v4.js`: todos os seus estilos e comportamentos foram integrados aos nomes de arquivo originais.

## Teste local
Na pasta destes arquivos: `python -m http.server 8765`. Acesse `http://127.0.0.1:8765/` e force atualização com Ctrl+Shift+R.

As demonstrações da landing page são ilustrativas. O workspace usa a configuração de conexão em `config.js`.

**Atenção**: se estiver substituindo versão antiga, exclua `v4.css` e `v4.js` obsoletos para evitar confusão. Nenhuma alteração foi enviada ao GitHub.

## Workspace com Supabase

O frontend HTML/CSS/JS foi preservado. `config.js` ativa a conexão ao projeto
`zazkecvrjmtbvmylxgij` com chave pública. Segredos ficam em Edge/Vault.

- Login real, troca obrigatória controlada pelo backend e RLS por workspace/board.
- Tarefas, comentários, checklist, prioridades, prazos, empresa e perfil persistem no banco.
- Owner administra acesso e exclusão; convidado só acessa os boards autorizados.
- Histórico é alimentado por triggers; alterações em lote são transacionais, com controle de versão.
- Importação local é explícita e não apaga `worksh.workspace.v1`.
- Resend e Google Drive aguardam credenciais e testes reais dos respectivos serviços.
- Agendador instalado, com processamento de filas suspenso no Vault até essa configuração.

Leia [deploy e ativação](docs/deploy-supabase.md), [mapeamento](docs/mapeamento-worksh.md)
e [estado da entrega](docs/entrega.md). O histórico remoto das migrations está em
`docs/migrations-aplicadas.json`; os nomes locais correspondem às versões aplicadas.

### Verificação

- `node scripts/import-check.mjs` valida o plano de importação sem acessar dados reais.
- `scripts/rls-check.sql` verifica isolamento/permissões/transações e faz rollback.
- `scripts/queue-check.sql` verifica idempotência/leases e faz rollback.
- `scripts/healthcheck.sql` consulta métricas e configurações sem revelar segredos.

Para voltar ao protótipo local, usar `enabled: false` em `config.js`.
A publicação do site continua dependendo da revisão e do envio ao GitHub.

Gestão de contas da equipe: [perfis e acessos](docs/perfis-e-acessos.md).
