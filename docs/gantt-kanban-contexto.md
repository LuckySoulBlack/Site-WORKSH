# Revisão do cronograma e contexto dos cartões

## Gantt

Escala com mês/ano, datas e dias da semana alinhados à mesma coordenada usada pelas barras. Finais de semana e data de referência destacados; linha vertical vermelha tracejada cruza o cronograma. Janela exibida corresponde ao cabeçalho real. Escala se adapta ao tamanho do projeto, com rolagem horizontal para manter os rótulos legíveis.

No workspace, a referência é hoje no navegador. No HTML estático, é a data de geração do arquivo no horário de São Paulo, indicada na legenda. O arquivo não atualiza seu corte depois de enviado. Na visualização de link, a referência muda quando os dados são consultados novamente. Se a referência estiver fora do período do projeto, a legenda informa isso sem inventar uma posição na escala.

A linha mostra tempo de calendário. Não representa percentual real executado; cores das barras continuam representando o status.

## Kanban

Cada cartão mostra projeto, grupo/etapa, título, responsável com iniciais e datas. Sem pessoa atribuída, aparece Sem responsável. Na opção de ocultar responsáveis, aparece Responsáveis não compartilhados e os nomes não são incorporados ao HTML.

Novas exportações e novos links deixam Mostrar responsáveis marcado por padrão, conforme pedido. O usuário pode desmarcar antes de gerar. Links antigos conservam a configuração já escolhida; não foram ampliados silenciosamente.

Exportação remota carrega tarefas e grupos de todas as páginas autorizadas (limite 5000 por tipo). Contexto de grupo na resposta pública foi preparado na migration 20261023235010_shared_project_group_context.sql, ainda não aplicada remotamente. Mantém verificação de token, validade, revogação, conta liberada e o recorte de dados da implementação anterior.

## Validação

- scripts/timeline-check.mjs: alinhamento matemático das datas/barras/corte, ano bissexto, data inválida, referência fora do intervalo, projeto vazio e períodos longos.
- scripts/project-render-check.mjs: cabeçalho, linha de referência, projeto/grupo, nomes incluídos e ocultos, escape HTML e arquivo autossuficiente sem credenciais.
- scripts/project-sharing-check.sql executado em PostgreSQL local PGlite com pgcrypto: grupo correto, proteção contra outro tenant, nomes conforme escolha, expiração/revogação/bloqueio. Auth e API Storage simulados; sem execução remota.
- Navegador: Gantt do workspace, nomes marcados no compartilhamento e download real dos 3 HTMLs. Exemplos locais atualizados sem alterar dados reais.

Alterações locais. Sem push; ativação do link atualizado depende das migrations e da validação no Supabase real.
