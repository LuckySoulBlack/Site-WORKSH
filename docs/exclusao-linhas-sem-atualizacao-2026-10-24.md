# Exclusão de linhas sem atualizações

Ao marcar as caixas de seleção, o frontend consulta a elegibilidade no servidor e mostra Excluir linha(s) para as selecionadas permitidas. Existe confirmação antes da exclusão e uma nova conferência ao confirmar. A gravação aguarda o lote atômico apply_changes; falhas não anunciam sucesso.

Todos os perfis com edição no quadro podem excluir linhas sem atualizações. Acesso somente de leitura e pessoas de outro quadro não ganham exclusão. Proprietários mantêm a exclusão de linhas com atualizações.

Linha sem atualizações: status A fazer, timestamps de criação/alteração iguais, nenhum comentário ou anexo, nenhuma execução no checklist, nenhum UPDATE significativo no histórico e nenhum histórico de comentário, arquivo ou atribuição de equipe. O registro de criação por si só não impede a exclusão; atualizações técnicas sem mudança de conteúdo são ignoradas no histórico. Histórico preexistente é consultado com índices específicos.

O Supabase aplica uma policy RLS adicional e um trigger antes da exclusão para reconferir a regra com a linha bloqueada, protegendo contra mudanças concorrentes. Cascatas autorizadas pelo proprietário continuam funcionando. Nenhuma linha real foi excluída durante a implantação.

Migration: delete_unupdated_rows, versão remota 20261024052910, arquivo 20261024052633. Testes locais: editor exclui linha intacta, linhas alteradas e comentadas ficam protegidas, leitor/externo não excluem, proprietário continua excluindo ambiente/quadro por cascata. Integrações Google Drive/WhatsApp continuam pendentes, sem ativação nesta entrega.
