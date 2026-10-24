# Publicação do frontend — 23/10/2026

Autorização: publicar a versão revisada no GitHub preservando os dados existentes. Imagens/prints nos cartões e no HTML ficam para o próximo ajuste.

## Escopo

Publicar arquivos do site na branch main e acompanhar o deploy automático do GitHub Pages. Não executar migrations, comandos de reset, seeds, importação de localStorage ou deploy de Edge Functions. Nenhuma alteração direta no projeto Supabase nesta publicação.

O repositório não contém .github/workflows executando alterações do banco. O histórico de Actions consultado mostra builds/deploys do Pages. A integração automática GitHub–Supabase não foi configurada nesta sessão.

## Compatibilidade

O frontend detecta board_features e usa as colunas antigas quando a função ainda não existe. Tabelas existentes continuam carregando; criação de colunas personalizadas, fotos, logo remota, novo onboarding do Drive e links dinâmicos permanecem dependentes da ativação do backend. Exportação HTML, layout do Gantt, contexto do Kanban e ajustes visuais não exigem alterar os registros existentes.

Teste scripts/legacy-backend-check.mjs: backend simulado sem migrations pendentes; carregar ambiente e quadro gera zero gravações. Uma edição explícita de título envia apenas o campo título da tarefa, preservando IDs e demais conteúdos. Testes de renderização, calendário, fórmulas, histórico e sintaxe passaram. Verificação de credenciais nos arquivos versionados passou.

As migrations e fontes de funções ficam versionadas para implantação futura; armazenar esses arquivos no GitHub não executa SQL no banco.
