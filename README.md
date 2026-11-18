# 2 na Fronteiras

Sistema para controlar compras no Paraguai, custo real dos produtos, clientes, vendas parceladas e contas a receber.

- **Site:** publicado pelo GitHub Pages a partir deste repositório.
- **Banco, login e fotos:** Supabase (estrutura em `supabase.sql`).
- **Tela:** `index.html` (HTML, CSS e JavaScript puro, sem compilação).
- **Configuração:** `config.js` (endereço e chave pública da Supabase).

## Segurança
- Só entra quem tem login **e** está na tabela `membros` (Row Level Security em todas as tabelas).
- Cadastro público desligado na Supabase: os logins são criados pelo responsável.
- A chave em `config.js` é a pública (anon/publishable). A chave secreta nunca vai para este repositório.
- Nenhum dado de cliente fica no repositório.

## Liberar uma pessoa
1. Supabase > Authentication > Users > **Add user** (a pessoa define a senha ou usa "Esqueci minha senha").
2. Supabase > SQL Editor: `insert into public.membros (email, nome) values ('email@exemplo.com', 'Nome');`
