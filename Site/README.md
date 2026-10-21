# WORKSH — Site institucional

Site responsivo em HTML, CSS e JavaScript estático, preparado para GitHub Pages. Não exige compilação, banco de dados nem dependências npm.

## Conteúdo
- `index.html`: landing page completa, com seções e modal de Workspace.
- `style.css`: visual responsivo, cores e animações.
- `script.js`: modal, navegação móvel, animações e configurações.
- `assets/logo.svg`: símbolo vetorial com quatro nós e arco inferior esquerdo **laranja**.

## Publicação no GitHub Pages
1. Crie um repositório (por exemplo `worksh-site`) na sua conta GitHub.
2. Envie **os arquivos da pasta** para a raiz do repositório (o `index.html` deve aparecer na raiz).
3. Vá em **Settings → Pages**.
4. Em **Build and deployment**, selecione **Deploy from a branch**; escolha `main` e `/ (root)`; clique em **Save**.
5. Aguarde o deploy indicado em **Actions** ou **Pages**. O endereço ficará no formato `https://SEUUSUARIO.github.io/worksh-site/`.
6. Para domínio personalizado, siga as instruções de DNS do GitHub Pages; habilite HTTPS após validação do domínio.

## Conectar o ambiente de trabalho
Em `script.js`, troque:

```js
const WORKSPACE_URL = '';
```

por, por exemplo:

```js
const WORKSPACE_URL = 'https://app.seudominio.com.br';
```

Até configurar essa URL, o botão **Entrar no Workspace** abre um modal explicando que o ambiente está em preparação. Ele **não** autentica usuários; o controle de acesso deve ser feito com autenticação e autorização adequadas no app de destino.

Para definir contato por e-mail, configure também `CONTACT_EMAIL` no `script.js`. Sem e-mail, o botão secundário do contato abre o modal de Workspace e não exibe endereço fictício.

## Identidade
Marca: **WORKSH**. Slogan: **Organize. Conecte. Conquiste.** Fontes: Poppins e Inter (Google Fonts; há fallback local). A plataforma ilustrada é conceitual; confirme funcionalidades implementadas antes de anunciar disponibilidade comercial.
