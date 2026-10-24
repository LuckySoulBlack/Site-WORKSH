# Grupos, prioridades, checklists e colunas

Prioridades: baixa em verde, normal em azul, alta em âmbar e urgente em vermelho, com contraste nos temas claro e escuro. Cores aplicadas às células, cards e editor da tarefa.

Grupos são recolhíveis; o primeiro abre por padrão e os demais ficam recolhidos. Preferência de expansão fica nesta sessão do navegador, sem alterar o banco. A tabela usa colunas proporcionais, textos maiores e rolagem horizontal dentro de cada grupo. Seleção e título da tarefa ficam fixos à esquerda.

Checklist: botão + na linha e nos cards abre itens com título, entrega, status e percentual. Concluir define 100%; os itens antigos são compatíveis e preservados. O salvamento aguarda a resposta remota, conserva IDs e atributos adicionais dos itens e registra a alteração pelo fluxo normal de auditoria. A coluna opcional Execução do checklist calcula a média simples dos itens, podendo ser referenciada por fórmulas e exportada em CSV. Exemplos: 50% e 100% resultam em 75%; checklist vazio resulta em 0%.

Removidos o corte visual e a rejeição por quantidade de 40 colunas. Permanecem validação de IDs únicos, tipos, permissões e o limite de 64 KB das configurações no banco. O frontend avisa antes de ultrapassar aproximadamente 60 KB de configuração. Não se promete capacidade infinita de armazenamento. Os valores de cada tarefa continuam sujeitos a 32 KB e os checklists a 16 KB.

Supabase: migration flexible_column_count aplicada como 20261024004127 (arquivo 20261024004036). Alterou somente a função validadora para retirar a contagem fixa; não editou nem excluiu dados dos usuários, não alterou RLS, índices ou chaves.

Verificação: 61 colunas aceitas em teste local de RLS com editor/leitor/externo e proprietário; 65 colunas retornadas sem truncamento no frontend; checklist legado, metadados preservados, percentual médio, duplicidade de envio e valores inválidos. Prévia isolada confirmou persistência da entrega/status/percentual após recarregar, coluna calculada em 75% e grupos recolhidos preservados. Nenhum teste gravou dados reais dos clientes.
