# Foto de perfil e status Cancelado

A foto é enviada ao clicar em Salvar, com os demais campos. O formulário aguarda a persistência, impede envio duplicado e mantém o erro visível sem fechar em caso de falha. Imagens são recortadas para 256×256 e convertidas para WebP; não há base64 no banco. O bucket profile-photos é privado, com escrita restrita ao próprio usuário e leitura autorizada por participação no quadro.

Ativado no projeto zazkecvrjmtbvmylxgij: flexible_boards_avatars (20261024001208), canceled_task_status (20261024001411), pin_board_features_search_path (20261024001522). O manifesto registra a versão real e a versão do arquivo de origem, pois o MCP gera seu próprio horário. Não aplicar novamente arquivos já identificados pelo nome no histórico remoto.

A primeira migration também ativa os campos e validadores de colunas flexíveis já presentes no frontend. Não foram aplicadas as pendências de Drive, identidade do histórico ou compartilhamento público. Nenhum registro de usuário, tarefa ou workspace foi editado ou excluído para esta implantação.

Cancelado é aceito no status da tarefa e em colunas personalizadas de status, filtros, Kanban, Gantt, histórico e HTML exportado. Não entra em pendências nem atrasos; o registro é preservado.

Verificação: testes locais de RLS (editor/leitor/externo, proprietário e fotos privadas); teste do formulário aguardando Salvar, falha e envio duplicado; compatibilidade com banco legado; exportações, fórmulas, histórico e cronograma. Prévia isolada confirma foto e status persistindo após recarregar. Consulta remota confirma bucket privado, três políticas de Storage, campo do perfil e constraint Cancelado. Upload completo usando uma sessão real do usuário ainda depende da validação dele; não acessamos sua senha ou alteramos sua foto real em teste.
