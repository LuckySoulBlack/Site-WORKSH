# Responsáveis cooperativos e fotos

Fotos dos responsáveis ampliadas para 48 px nas tabelas, 40 px no checklist, 38 px no Gantt e foto de perfil no cabeçalho para 44 px. Seleção de equipe com caixas de marcação, foto e nome.

Cada tarefa pode ter várias pessoas do próprio quadro. O primeiro responsável continua no campo assignee_id para compatibilidade; os vínculos adicionais são armazenados na tabela task_assignees. A gravação passa por uma única transação apply_changes, com verificação de versão, validação de membros e histórico. Filtros, indicadores de responsável, CSV e HTML exportado consideram todos os responsáveis.

Cada item de checklist tem seleção múltipla de responsáveis do quadro. Atribuir alguém ao item inclui essa pessoa na equipe da tarefa. Remover alguém que ainda tem itens atribuídos exige reatribuir esses itens antes. Itens legados são preservados e continuam funcionando.

Supabase: migration cooperative_task_assignees aplicada como 20261024005150, arquivo de origem 20261024004514. Nova tabela com UUID, quatro chaves estrangeiras, unicidade tarefa/pessoa, índices, RLS e auditoria. O vínculo da tarefa com o quadro é protegido por chave estrangeira composta. Excluir uma responsabilidade equivale a editar a equipe; a exclusão da tarefa continua restrita ao proprietário. Nenhuma tarefa ou cadastro real foi editado durante a implantação, e não houve importação ou limpeza de dados.

Verificação local: editor pode atribuir duas pessoas; pessoa externa e leitor são bloqueados; falha reverte a transação inteira; checklist com pessoa fora do quadro é rejeitado; remoção exige reatribuição; convidado não exclui tarefa; exclusão pelo dono remove vínculos por FK. Repositório envia a equipe completa em uma única requisição atômica. Prévia isolada confirmou persistência de duas pessoas e distribuição dos itens após recarregar. Consulta remota confirmou RLS, políticas e quatro FKs; o teste visual não utilizou a sessão real de usuário.
