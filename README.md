# WORKSH — V4 consolidada para teste local

## Arquivos
- `index.html`: páginas e seções do site.
- `style.css`: todos os estilos, incluindo Plataforma, Como funciona, Connect e animações.
- `script.js`: todas as interações, navegação, demonstrações e carrosséis.
- `assets/logo.svg`: símbolo vetorial WORKSH.

Não há `v4.css` nem `v4.js`: todos os seus estilos e comportamentos foram integrados aos nomes de arquivo originais.

## Teste local
Na pasta destes arquivos: `python -m http.server 8765`. Acesse `http://127.0.0.1:8765/` e force atualização com Ctrl+Shift+R.

As demonstrações são ilustrativas. O acesso real ao Workspace depende de configurar `WORKSPACE_URL` em `script.js` e da aplicação futura.

**Atenção**: se estiver substituindo versão antiga, exclua `v4.css` e `v4.js` obsoletos para evitar confusão. Nenhuma alteração foi enviada ao GitHub.
