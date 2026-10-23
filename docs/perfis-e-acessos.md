# WORKSH — perfis e acesso da equipe

Implementado em 23/10/2026. Frontend mantido em HTML/CSS/JS; alterações locais, sem publicação no GitHub.

## Contas reais
- lucas@worksh.com.br: administrador de usuários e proprietário do workspace WORKSH.
- lucas.noliveira@shopee.com: membro da equipe.
- adriana.sousa@shopee.com: membro da equipe.

As três contas estão liberadas e exigem troca da senha inicial no primeiro acesso. As senhas fornecidas não fazem parte dos arquivos do projeto nem deste relatório. Os logins foram verificados na API de autenticação.

O workspace WORKSH contém o painel Equipe WORKSH e um grupo Atividades da equipe. Os dois membros têm edição nesse painel. Outros painéis dependem de concessão explícita do proprietário; exclusões continuam restritas ao proprietário.

## Administração
Após a troca de senha, a conta administradora encontra Usuários e acessos no topo do workspace. Pode cadastrar membros, bloquear e liberar contas. Administradores protegidos não podem ser bloqueados pelo painel. O bloqueio é conferido no banco, inclusive para tokens de sessão já emitidos. A conta bloqueada ainda pode autenticar no provedor Auth, mas o site informa o bloqueio e os dados ficam inacessíveis; liberar preserva suas permissões anteriores.

O proprietário pode usar Acessos dentro de um painel para adicionar pelo e-mail uma conta existente, alterar edição/leitura e remover acesso. Cadastrar uma conta não concede acesso automático a todos os painéis. A gestão global registra criação, bloqueio e liberação em histórico privado.

## Salvar no Chrome
O login oferece Salvar usuário e senha no Chrome. Quando marcado e a autenticação tem sucesso, usa a API de credenciais do navegador quando disponível, com alternativa ao fluxo nativo de salvamento. O e-mail pode ser lembrado no navegador; nenhuma senha é salva no localStorage. A oferta de salvar depende do Chrome, de suas preferências e do contexto HTTPS/localhost. O navegador interno do Codex não comprova a interface do gerenciador de senhas do Chrome.

## Verificação
- Logins das três contas reais: aprovados; troca obrigatória e perfis confirmados.
- Testes transacionais de bloquear/liberar: aprovados; bloqueado sem acesso a boards e perfil; membro sem administração nem autopromoção; administrador protegido.
- Suite existente de RLS: aprovada com rollback, sem alterar as contas reais.
- JS validado e Edge Function admin-users validada com Deno.
- Dados locais anteriores preservados; nenhum e-mail enviado. Resend e Google OAuth ainda aguardam configuração externa.

## Backend
Duas migrations incrementais: user_administration e team_access_controls. Função admin-users ativa: ações comuns verificam JWT com Auth e conferem administrador ativo no banco; provisionamento operacional aceita apenas o segredo de worker protegido no Vault, não aceita conceder perfil administrador e nunca substitui senha existente. Atribuição inicial de administrador feita pelo operador autorizado diretamente no banco.

A tabela privada de auditoria tem RLS e negação explícita a clientes; RPC administrativo restrito a service_role. Perfil administrador não amplia a visibilidade dos dados de outros workspaces.

A tela de administração foi validada no navegador com conta descartável, removida ao final. A captura gestao-perfis-validada.png inclui essa conta de teste e não representa uma quarta conta permanente.
