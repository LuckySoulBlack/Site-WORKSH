# WORKSH — configurações de perfis

Entrega de 23/10/2026. Frontend local; sem push para GitHub.

## Onde acessar
Configurações → Perfis e acessos, disponível somente para Admin. O botão superior Configurações de acesso abre diretamente essa seção.

- Admin: convida pessoas para a plataforma, promove Usuário/Convidado para Admin, ajusta perfis, cadastra contas, libera e bloqueia acessos. Não ganha acesso automático a workspaces de outros proprietários.
- Usuário: cria seus workspaces e administra os painéis, arquivos e convidados dos ambientes que possui.
- Convidado: visualiza e edita somente os painéis autorizados. Não cria workspace e não exclui registros.

A tela permite busca por nome/e-mail, seleção de perfil e Salvar perfil, cadastro sem e-mail e convite para a plataforma. Os perfis fixos têm suas regras garantidas pelo backend. As mudanças de perfil são registradas em auditoria privada.

## Proteções
Novas contas começam como Convidado no servidor; somente o fluxo autorizado do Admin libera o perfil Usuário ou Admin. Usuários existentes foram preservados. Ninguém pode alterar seu próprio perfil administrativo pela tela; outro Admin precisa fazer a alteração. O último administrador é preservado. Proprietários não podem virar Convidado enquanto possuem workspaces. Workspaces não ficam visíveis ao Admin por causa de seu perfil global.

## Convites para a plataforma
A operação de convite gera uma senha provisória no servidor, guarda a entrega criptografada no Vault, cria ou reconhece a conta, libera o perfil Usuário e envia pelo Resend. Retentativas reutilizam a mesma entrega; contas existentes não têm a senha redefinida. O segredo temporário é removido após a confirmação do envio. A troca da senha inicial continua obrigatória. Convites não associam a pessoa ao workspace do remetente.

Bloqueio externo atual: RESEND_API_KEY, RESEND_FROM_EMAIL e APP_URL precisam estar configurados no servidor com domínio/remetente autorizado. A tela verifica essa disponibilidade e informa a pendência. O teste confirmou que o pedido de envio retorna indisponível antes de criar uma conta quando a integração falta; nenhum convite real foi enviado. A entrega por e-mail ainda não foi testada de ponta a ponta.

## Exclusões
Ambiente: selecione o ambiente e abra Configurações → Ambiente → Excluir ambiente. A interface exige manter pelo menos um ambiente.
Quadro: abra o quadro → Editar quadro → Excluir quadro.
Somente o proprietário pode excluir. O backend bloqueia a remoção de quadros/ambientes com anexos ou trabalhos de upload pendentes até resolver os arquivos. Nenhum ambiente ou quadro real foi excluído durante esta entrega.

## Google Drive
Botão Conectar meu Google Drive em Configurações → Integrações, além do atalho Conectar Drive. O proprietário concede OAuth explicitamente antes do primeiro upload. A aplicação cria uma pasta por workspace no Drive do proprietário e usa acesso drive.file. OAuth Google ainda não foi configurado, portanto a autorização e uploads reais seguem pendentes.

Textos, dados das tabelas, links e histórico são persistidos no Supabase. Somente arquivos anexados são armazenados no Google Drive do proprietário; os metadados dos arquivos ficam no Supabase. Não houve mudança para armazenar todo o banco no Drive.

## Validações
- Restrições de Convidado, criação de workspace por Usuário e promoção para Admin: testes SQL com rollback aprovados.
- Alteração de perfil de proprietário para Convidado bloqueada.
- RPCs de serviço inacessíveis ao cliente comum.
- Convite criptografado, limpeza de segredo e supressão de duplicata: testes transacionais aprovados.
- Suites RLS, bloqueio/liberação, filas e preservação de dados locais aprovadas.
- API de Admin autenticada e detecção do e-mail pendente aprovadas.
- Sintaxe JS e compilação da função Edge aprovadas.
- Conta descartável de teste removida; contas reais preservadas.
