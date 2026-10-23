# Quadros flexíveis, Gantt e fotos de perfil

## Entrega local

- Edição na linha: título, responsável, status, prioridade e datas. Criação de tarefa com Enter na linha do grupo. Detalhes completos ficam no Kanban; calendário e Gantt levam à edição na tabela.
- Checklist abre diálogo pequeno próprio.
- Seletor pesquisável com ativação das colunas nativas e criação de colunas tipadas. Limite 40 por quadro, independentemente do grupo. Ocultar campos nativos preserva valores.
- Tipos: texto, número, percentual, moeda, data, pessoa, status, link, confirmação, lista suspensa, prioridade, cronograma, arquivos, documento, fórmula, vínculo com quadro e extração de informações.
- Fórmulas: operações + - * /, parênteses, referências {Nome da coluna} e funções SUM, AVG, MIN, MAX, ROUND. Sem eval, sem acesso a JavaScript, sem dependências entre fórmulas nesta versão. Não replica todas as funções proprietárias do monday.
- Documentos: editor de texto por tarefa e coluna, até 12 mil caracteres; sem colaboração simultânea de texto ou editor rico nesta versão.
- Conectar quadros: referência a um quadro visível para a pessoa e botão para abri-lo; não concede acesso, não espelha dados e não relaciona automaticamente itens de outro quadro.
- Cronograma: início e fim, refletidos no Gantt. Gantt respeita filtros e paginação das tarefas carregadas; sem dependências entre tarefas e sem arrastar barras nesta versão.
- Arquivos: lista e upload por tarefa, reaproveitando filas, autorização e Drive do owner; colunas de arquivos da mesma tarefa compartilham a lista de anexos.
- Extração: TXT/CSV até 1 MB, leitura local, texto resultante editável. PDFs, imagens, OCR e análise semântica por IA ainda não implementados: aguardam definição/configuração do provedor. Nenhum envio a serviço de IA é feito.
- Foto: todos os perfis podem enviar JPG/PNG/WebP até 10 MB, recortado no centro e convertido em WebP 256x256 no navegador. Imagens ficam em bucket privado profile-photos (até 1 MB por objeto); banco guarda apenas caminho. Anexos de trabalho continuam no Google Drive. URLs de leitura duram 1 hora e são renovadas ao recarregar o perfil/quadro; iniciais continuam como alternativa.
- Foto e nome aparecem no cabeçalho, perfil, pessoas, responsável na tabela, Kanban, Gantt e histórico de participantes ainda acessíveis. Não foi ampliado o acesso do admin a fotos de pessoas de outros tenants.

## Persistência e segurança

Migration: 20261023224222_flexible_boards_avatars.sql, ainda não aplicada remotamente. Novas colunas ficam em board_settings; células tipadas em tasks.custom_values com limites de tamanho e validação no servidor. Referências de pessoa e quadro são verificadas no servidor. Mantidos IDs/FKs e políticas RLS existentes. Valores customizados são JSON tipado, sem indexação GIN desnecessária (não são usados em filtros no servidor nesta entrega).

A operação apply_changes permanece SECURITY INVOKER e atômica com controle de versão. Configuração do quadro e tarefas seguem as mesmas permissões de editor; convidado leitor não grava e somente owner exclui. Fotos: gravação apenas no próprio diretório e leitura por participantes autorizados, sem tornar o bucket público. Configurar bucket não depende de OAuth do Google, permitindo foto ao convidado.

Capacidade board_features detectada antes de pedir campos novos: sem migration, o quadro antigo continua utilizável e tentativas de recursos novos informam a atualização pendente.

## Revisão executada

- Sintaxe de JS e verificação de diff.
- PostgreSQL local PGlite: migrations base + campos frontend + nova migration; Storage/Auth simulados. Editor cria coluna/edita célula, leitor não grava, estranho não vê tarefas/pessoas/fotos, convidado não exclui, owner exclui. Validação de número e definição inválida; fotos não podem ser gravadas no diretório de outra pessoa.
- Fórmulas: operações, referências, precedência, funções, divisão por zero e rejeição de comandos/injeção.
- Navegador em porta isolada 8766, dados fictícios: seletor e pesquisa, busca de tarefas, edição percentual na célula, tarefa com Enter, checklist, Gantt com responsáveis, cálculo de fórmula, documento salvo/reaberto, Kanban com formulário completo, calendário, modo escuro e campo de foto no perfil.
- Regressão local do histórico e fluxo do Drive pelos scripts existentes. Não é um teste real de e-mail, OAuth, Supabase Storage ou Google Drive.
- Link monday fornecido abriu login no navegador disponível; comparação visual baseada nas capturas do usuário.

## Pendências reais antes de publicar

1. Reautenticar conexão MCP Supabase: tentativa desta revisão falhou ao renovar OAuth.
2. Aplicar migrations pendentes em ordem (Drive, identificação do histórico, quadros/fotos), validar RLS e Storage no projeto real.
3. Concluir OAuth/secrets Google e ativação dos workers antes do teste real de anexos. Resend ainda depende de domínio/remetente para convites reais.
4. Definir provedor e configurar análise por IA se desejada para Extrair informações.
5. Testar com owner, editor e leitor reais e só então publicar o lote de alterações autorizado.

Dados reais e localStorage do ambiente principal não foram modificados pelos testes. Nenhum push nesta entrega.
