# Identidade da empresa e compartilhamento de projetos

## Interface local

- Tipo de coluna renomeado para Documentos, sem nome de marca.
- Ambientes/quadros agrupados na barra lateral com cor própria; nome e logo identificam a empresa. Navegação geral mantém o visual WORKSH.
- Configurações > Empresa permite escolher a cor e enviar JPG/PNG/WebP até 10 MB. A logo é ajustada proporcionalmente em WebP 512x256; sem corte da marca. Logo e demais campos são salvos juntos pelo botão Salvar.
- Logo aparece na identificação do espaço e na ficha da empresa. Cor respeita os modos claro/escuro.
- Metadados da empresa ficam no workspace; URLs assinadas de logo não são gravadas no banco. Arquivo em bucket privado company-logos com até 1 MB por objeto; escrita somente do owner e leitura de participantes autorizados do ambiente. Anexos de trabalho continuam no Drive.

## HTML para enviar

Botão Compartilhar / HTML no quadro, com seleção Gantt, Kanban ou Tabela. Arquivo autossuficiente (estilo e logo incorporados), sem scripts, sem credenciais e sem conexão com o banco. Dados: todas as tarefas do quadro, status, datas e nomes de responsáveis somente se a pessoa marcar essa opção. Não inclui comentários, documentos internos, links de referência, dados customizados ou arquivos. No modo remoto, consulta todas as páginas antes de gerar (limite explícito 5000 tarefas), sem exportar só a página carregada ou os filtros visuais.

Cada arquivo é uma cópia no momento da geração. Não atualiza automaticamente e não pode ser revogado depois de enviado. A exportação não envia e-mail nem publica os dados por conta própria.

## Link de acompanhamento

Implementação preparada em project-share.html + migration 20261023232659_company_logos_public_project_views.sql, ainda não aplicada remotamente.

Somente owner cria, lista ou revoga links. Validade 1/7/30 dias, no máximo 20 links ativos por quadro e até 5000 tarefas na visualização. Token aleatório de 256 bits, somente SHA-256 no banco; token em fragmento da URL para não ir no endereço de requisição do HTML. Lista administrativa não devolve token nem hash. O token é uma autorização: qualquer pessoa que tenha o endereço acessa a projeção permitida enquanto válido.

Tabela privada com UUID, FKs, RLS, índices de relacionamentos e acesso direto negado. Endpoints de owner verificam propriedade e conta liberada. Endpoint público é um wrapper SECURITY DEFINER intencional, de search_path vazio, que delega a uma função privada com verificação do token. Não libera SELECT nas tabelas privadas ou de trabalho para anon.

Resposta pública contém apenas título do quadro, nome da empresa, título/status/datas das tarefas e responsáveis se autorizados. Logo privada, e-mails, comentários, documentos, custom_values, IDs internos, arquivos e credenciais não são retornados. Links expiram, podem ser revogados e deixam de consultar se o owner estiver bloqueado ou em troca obrigatória de senha. Criação e revogação geram histórico sem token/hash.

Visualizador só de leitura, atualização manual ou automática a cada minuto enquanto a aba estiver visível. Atualização automática desliga após erro. Revogação bloqueia novas consultas; não recolhe informações já vistas ou copiadas. Fotos/arquivos não são expostos pelo compartilhamento.

## Validação realizada

- Testes SQL em PGlite com pgcrypto real; Auth e API Storage simulados. Editor não cria link nem altera logo; owner cria/revoga, anon acessa somente a projeção do quadro escolhido, atualização de tarefa aparece em nova consulta, nomes ficam fora por padrão e entram somente no opt-in, lista não revela token/hash, expiração/revogação/bloqueio impedem leitura.
- Testes de renderização para Gantt/Kanban/Tabela, escape HTML, rejeição de logo insegura, ausência de nomes sem autorização e indicação estático/atualizado.
- Navegador na prévia isolada: nome e cor da empresa salvos; logo PNG de exemplo enviada e convertida; 3 arquivos HTML realmente baixados (Gantt, Kanban, Tabela). Arquivos conferidos: logo incorporada, sem nomes não autorizados, sem documento interno ou credencial.
- Regressão local das colunas, permissões, fórmulas e histórico passou. Sem mudança em dados reais, sem envio de mensagens e sem publicação no GitHub.

## Ativação pendente

Reautenticar o acesso Supabase e aplicar migrations pendentes em ordem; depois validar Auth, Storage, RLS/advisors e o visualizador com contas e banco reais. Só então publicar project-share.html e frontend compatível. A prévia local já gera HTML; nela Criar link informa a ativação pendente, sem simular um link público real. Os arquivos de exemplo e a logo são fictícios.
