# Cronograma e entrega

Início passa a Cronograma (intervalo de início/fim), e Prazo passa a Entrega. Os IDs start_date e due são mantidos: o fim do cronograma e a entrega representam a mesma data. Nomes antigos em configurações de colunas são normalizados apenas na exibição, preservando os dados.

Datas são editadas em controles compactos dentro da linha e confirmadas em uma única operação por Aplicar. Eventos intermediários de digitação não persistem nem redesenham a tabela. A gravação é aguardada, com bloqueio de envio repetido e controles temporariamente desativados. Períodos invertidos ou incompletos são rejeitados antes de alterar o estado. O Gantt consome os mesmos campos; o CSV também inclui o intervalo. A entrega pode ser limpa sem apagar o início.

Não houve migrations ou alterações diretas de dados no Supabase nesta atualização. Permissões de edição continuam limitadas por UI e RLS. O frontend legado permanece compatível, mantendo IDs e conteúdo.

Validação: testes de edição atômica, ano incompleto, período invertido, envio duplicado, datas personalizadas independentes, exportação, Gantt e compatibilidade. Na prévia isolada foi digitado o intervalo 01/11/2026–08/11/2026 sem interrupção, aplicado e recarregado; entrega sincronizada com 08/11/2026. Testes não alteraram dados reais.
